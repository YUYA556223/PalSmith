-- PalSmith runtime v0.2 - content framework for Palworld.
-- https://github.com/YUYA556223/PalSmith
--
-- Runs as a UE4SS Lua mod next to PalSchema. PalSchema owns the data tables
-- (items/recipes/buildings/resources); PalSmith adds namespaced ids, a Fabric-
-- style dependency resolver, an id registry, declarative {handler,args} behaviors
-- (onUse/onPlace/onInteract) and runtime meshes on top.
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
    -- three-phase pipeline: discover -> resolve -> load (see registry.lua)
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

-- Mod Manager UI. Open/close with F9 (fallback; the primary entry is the title
-- menu). The two-pane UI is mouse-driven, so no number keys are bound.
pcall(function()
    RegisterKeyBind(Key.F9, function()
        ExecuteInGameThread(function()
            local okk, e = pcall(modmanager.toggleWindow)
            if not okk then core.err("mod manager toggle: " .. tostring(e)) end
        end)
    end)
    core.log("mod manager key bound: F9")
end)

-- Public API for other Lua mods.
local actions = require("palsmith.actions")
_G.PalSmith = {
    version = core.VERSION,
    registerHandler = actions.registerHandler,     -- ("ns:name", fn(args, ctx))
    registerAction = actions.register,             -- DEPRECATED alias -> smith:name
    resolveId = require("palsmith.ids").resolve,
    registry = registry,                           -- read-only: status/loadOrder/packs
}
