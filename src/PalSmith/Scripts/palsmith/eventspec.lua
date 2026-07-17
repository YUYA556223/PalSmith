-- PalSmith event spec: the single source of truth for the behavior event set.
-- registry/manifest validation and events.lua wiring both consume this, so the
-- whitelist can't drift out of sync (it used to live in two places).
--
--   dispatched = true  -> events.lua installs a hook and dispatches this event
--   dispatched = false -> RESERVED: accepted+validated in manifests/behaviors for
--                         forward-compat, but not dispatched by this runtime
--                         (a load-time warning is emitted for packs that use it)
local M = {}

M.EVENTS = {
    onUse      = { kind = "dispatch", dispatched = true },
    onPlace    = { kind = "dispatch", dispatched = true },
    onInteract = { kind = "dispatch", dispatched = true },
    onTick     = { kind = "poll",     dispatched = true }, -- dispatched by ticker.lua (poll, not a hook)
    onCraft    = { kind = "dispatch", dispatched = false }, -- reserved: hook target unverified
}

-- Is `name` a known event (dispatched or reserved)?
function M.isEvent(name) return M.EVENTS[name] ~= nil end

-- Is `name` actually dispatched by this runtime?
function M.isDispatched(name)
    local e = M.EVENTS[name]
    return e ~= nil and e.dispatched == true
end

-- Sorted list of dispatched event names (for asserting events.lua coverage).
function M.dispatchedList()
    local out = {}
    for name, e in pairs(M.EVENTS) do
        if e.dispatched then table.insert(out, name) end
    end
    table.sort(out)
    return out
end

return M
