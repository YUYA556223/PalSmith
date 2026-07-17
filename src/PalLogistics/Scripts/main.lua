-- PalLogistics — a LogisticsPipes-style logistics mod built ON PalSmith.
-- This is the reference "companion mod": it extends PalSmith by calling its
-- OOP-like entity API (PalSmith.defineEntity). It ships no framework of its own.
--
-- Install: ue4ss/Mods/PalLogistics/  (loads after PalSmith via mods.txt order).
local thisDir = debug.getinfo(1, "S").source:match("@?(.*[\\/])") or ""
package.path = thisDir .. "?.lua;" .. thisDir .. "?\\init.lua;" .. package.path

local function log(m) print("[PalLogistics] " .. tostring(m) .. "\n") end

local function boot()
    log("PalLogistics starting on PalSmith v" .. tostring(_G.PalSmith.version))

    -- Discovery diagnostic: log every build placement so we can learn the real
    -- vanilla chest build id on this game version, then bind the Warehouse to it.
    _G.PalSmith.onPlace(function(buildId, pos, player)
        log(string.format("placed build id='%s' at %s", tostring(buildId),
            pos and string.format("(%.0f,%.0f,%.0f)", pos.x, pos.y, pos.z) or "?"))
    end)

    local ok, err = pcall(function()
        require("pallogistics.warehouse")
        require("pallogistics.pipe")
    end)
    if not ok then log("startup error: " .. tostring(err)) else log("ready") end
end

-- Load order between enabled.txt mods is undefined, so PalSmith may not be ready
-- yet. Boot immediately if it is; otherwise poll until _G.PalSmith appears.
if _G.PalSmith and _G.PalSmith.defineEntity then
    boot()
elseif type(LoopAsync) == "function" then
    local waited = 0
    LoopAsync(500, function()
        if _G.PalSmith and _G.PalSmith.defineEntity then boot(); return true end
        waited = waited + 1
        if waited >= 40 then log("ERROR: PalSmith not found after 20s; aborting."); return true end
        return false
    end)
else
    log("ERROR: PalSmith not found and no LoopAsync to wait; aborting.")
end
