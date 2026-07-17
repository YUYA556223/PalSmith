-- PalSmith central tick scheduler. One LoopAsync drives everything:
--   * reconstruction scan (entity.scan) on a cadence
--   * per-instance onTick (batched by def.tickInterval)
--   * batched world-state flush
-- Reuses the events.worldReady gate (no ticking until a world is stably loaded;
-- on world-left it flushes + drops live instances via entity.onWorldLeft).
--
-- The scheduling core is factored into a pure function (M.step) so it can be
-- unit-tested without UE globals.
local core = require("palsmith.core")

local M = {
    BASE_MS      = 500,   -- 2 Hz central tick
    SCAN_EVERY   = 4,     -- run entity.scan() every N ticks once settled
    SCAN_FAST    = 1,     -- aggressive scan cadence for the first FAST_WINDOW ticks
    FAST_WINDOW  = 20,    -- ~10s of fast scanning after a world loads
    FLUSH_EVERY  = 20,    -- batched store flush cadence
    tickCount    = 0,
    ticksInWorld = 0,     -- resets each time a world becomes ready
    _wasReady    = false,
}

-- Pure scheduling decision for a tick. Given counters + flags, returns what to
-- do this tick. No side effects — unit-tested directly.
--   input:  { ready, tickCount, ticksInWorld, dirty }
--   output: { scan=bool, flush=bool }
function M.decide(inp)
    if not inp.ready then return { scan = false, flush = false } end
    local cadence = (inp.ticksInWorld < M.FAST_WINDOW) and M.SCAN_FAST or M.SCAN_EVERY
    return {
        scan  = (inp.tickCount % cadence == 0),
        flush = (inp.tickCount % M.FLUSH_EVERY == 0) and inp.dirty,
    }
end

-- Run one instance's onTick if due. Circuit-breaks after repeated failures.
local function tickInstance(inst, ctx)
    if inst.tickBroken then return end
    if not (inst.actor and inst.def.onTick) then return end
    if M.tickCount % inst.def.tickInterval ~= 0 then return end
    local ok, err = pcall(inst.def.onTick, inst, ctx)
    if not ok then
        inst.tickFails = (inst.tickFails or 0) + 1
        core.err(string.format("onTick '%s' failed: %s", inst.key, tostring(err)))
        if inst.tickFails >= 5 then
            inst.tickBroken = true
            core.warn("onTick '" .. inst.key .. "' disabled after 5 failures")
        end
    else
        inst.tickFails = 0
    end
end

function M.start()
    local events = require("palsmith.events")
    local entity = require("palsmith.entity")

    local ok = pcall(function()
        LoopAsync(M.BASE_MS, function()
            ExecuteInGameThread(function()
                local ready = events.worldReady
                -- world-left edge: flush + drop instances
                if M._wasReady and not ready then
                    pcall(entity.onWorldLeft)
                    M._wasReady = false
                    M.ticksInWorld = 0
                    return
                end
                if not ready then return end
                if not M._wasReady then M._wasReady = true; M.ticksInWorld = 0 end

                M.tickCount = M.tickCount + 1
                M.ticksInWorld = M.ticksInWorld + 1

                local plan = M.decide({
                    ready = true, tickCount = M.tickCount,
                    ticksInWorld = M.ticksInWorld, dirty = entity.isDirty(),
                })

                if plan.scan then pcall(entity.scan) end

                local ctx = { event = "onTick", now = os.clock(), tickCount = M.tickCount }
                for i = 1, #entity.tickList do
                    tickInstance(entity.tickList[i], ctx)
                end

                if plan.flush then pcall(entity.flushWorld) end
            end)
            return false  -- keep looping
        end)
    end)
    if not ok then
        core.warn("ticker: LoopAsync unavailable — onTick/scan disabled")
    else
        core.log("ticker started (" .. M.BASE_MS .. "ms)")
    end
end

return M
