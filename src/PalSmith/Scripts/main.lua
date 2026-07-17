-- PalSmith runtime v0.1 - content framework for Palworld.
-- https://github.com/YUYA556223/PalSmith
--
-- Runs as a UE4SS Lua mod next to PalSchema. PalSchema owns the data tables
-- (items/recipes/buildings/resources); PalSmith adds namespaced ids, declarative
-- behaviors (onUse/onPlace/onInteract) and runtime meshes on top.
--
-- Install layout:
--   ue4ss/Mods/PalSmith/Scripts/main.lua        <- this file
--   ue4ss/Mods/PalSmith/Scripts/palsmith/*.lua  <- modules
--   ue4ss/Mods/PalSchema/mods/<Pack>/palsmith/  <- content packs (see docs)

-- Make require() resolve our modules relative to this Scripts dir.
local thisDir = debug.getinfo(1, "S").source:match("@?(.*[\\/])") or ""
package.path = thisDir .. "?.lua;" .. thisDir .. "?\\init.lua;" .. package.path

local core       = require("palsmith.core")
local registry   = require("palsmith.registry")
local events     = require("palsmith.events")
local modmanager = require("palsmith.modmanager")
local titlemenu  = require("palsmith.titlemenu")

core.log("PalSmith v" .. core.VERSION .. " starting")

-- Content packs live inside PalSchema's mods dir (Mods/PalSmith/Scripts -> Mods/PalSchema/mods).
local packsDir = thisDir .. "..\\..\\PalSchema\\mods\\"

local ok, err = pcall(function()
    registry.loadAll(packsDir)
    events.install()
    events.startReadyWatch()
end)
if not ok then
    core.err("startup failed: " .. tostring(err))
else
    core.log("ready")
end

-- Title-menu integration: a native "PalSmith" entry that opens the Mod Manager.
-- This is the primary entry point; the F9 keybind below is a fallback.
pcall(function()
    titlemenu.addEntry("PalSmith", function()
        pcall(modmanager.toggleWindow)
    end)
    titlemenu.start()
end)

-- Mod Manager UI. Open/close with F9; while open, number keys 1..9 toggle a mod.
-- (F7 avoided: it collides with media/volume keys on some systems.)
local function bindKeys()
    pcall(RegisterKeyBind, Key.F9, function()
        ExecuteInGameThread(function()
            local okk, e = pcall(modmanager.toggleWindow)
            if not okk then core.err("mod manager toggle: " .. tostring(e)) end
        end)
    end)
    -- Number-key enum names vary; probe each and log which actually bound.
    local numberKeys = {
        { "1", Key.ONE }, { "2", Key.TWO }, { "3", Key.THREE }, { "4", Key.FOUR },
        { "5", Key.FIVE }, { "6", Key.SIX }, { "7", Key.SEVEN }, { "8", Key.EIGHT },
        { "9", Key.NINE },
    }
    local bound = {}
    for i, pair in ipairs(numberKeys) do
        local label, key = pair[1], pair[2]
        local ok = false
        if key ~= nil then
            ok = pcall(RegisterKeyBind, key, function()
                core.log("number key " .. label .. " fired")
                ExecuteInGameThread(function() pcall(modmanager.activate, i) end)
            end)
        end
        table.insert(bound, label .. (ok and "+" or "-"))
    end
    core.log("mod manager keys bound: F9 open; numbers " .. table.concat(bound, " "))
end
pcall(bindKeys)

-- Public API for other Lua mods:
--   local palsmith = require("palsmith.api")
_G.PalSmith = {
    version = core.VERSION,
    registerAction = require("palsmith.actions").register,
    resolveId = require("palsmith.ids").resolve,
}
