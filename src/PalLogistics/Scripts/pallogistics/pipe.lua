-- PalLogistics Transport Pipe: on tick, moves items from one adjacent itemHandler
-- to another (point-to-point local push). This proves the whole stack —
-- spatial adjacency + the itemHandler component contract + container writes.
--
-- The pushOnce logic is intentionally self-contained: replacing it with the
-- routed network (network.lua/routing.lua) later changes nothing in warehouse.lua
-- or the itemHandler contract.
--
-- Requires container writes (PalSmith container.WRITES_ENABLED). Until writes are
-- verified safe on this build, the pipe is a NO-OP mover (logs intent only).
local PalSmith = _G.PalSmith
local spatial  = PalSmith.spatial
local function log(m) print("[PalLogistics] " .. tostring(m) .. "\n") end

local RADIUS_CM = 250        -- adjacency reach (~2.5 m)
local MOVE_PER_TICK = 10     -- items moved per firing

-- The Pipe reuses a vanilla BP building via a PalSchema `buildings/` def (custom
-- build id "logi_Pipe"); interact/tick route by position, so the reused BP is fine.
PalSmith.defineEntity{
    id = "logi:Pipe",
    displayName = "Transport Pipe",
    tickInterval = 2,           -- ~1s
    gridCm = 50,                -- pipes can be dense; finer identity grid

    onLoad = function(self) log("pipe online @ " .. self.key) end,

    onTick = function(self)
        if not (self.actor and self.actor:IsValid()) then return end
        -- neighbours = other registered entities within reach
        local neigh = spatial.neighbors(self.pos, RADIUS_CM, self)
        if #neigh < 2 then return end

        -- pick a source (has items) and a destination (has space), deterministic
        local src, dst
        for _, n in ipairs(neigh) do
            local ih = PalSmith.getComponent(n, "itemHandler")
            if ih and #ih:list() > 0 and not src then src = { inst = n, ih = ih } end
        end
        if not src then return end
        for _, n in ipairs(neigh) do
            if n ~= src.inst then
                local ih = PalSmith.getComponent(n, "itemHandler")
                if ih and ih:hasSpace() then dst = { inst = n, ih = ih }; break end
            end
        end
        if not dst then return end

        -- move one item type
        local first = src.ih:list()[1]
        if not first then return end
        local got = src.ih:extract(first.id, MOVE_PER_TICK)
        if got > 0 then
            local put = dst.ih:insert(first.id, got)
            if put < got then src.ih:insert(first.id, got - put) end -- return remainder
            log(string.format("pipe %s moved %d %s", self.key, put, first.id))
        else
            log(string.format("pipe %s: would move %s (writes disabled)", self.key, first.id))
        end
    end,
}

log("Pipe entity registered")
