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
local ticker     = require("palsmith.ticker")
local components = require("palsmith.components")

core.log("PalSmith v" .. core.VERSION .. " starting")

-- Content packs live inside PalSchema's mods dir (Mods/PalSmith/Scripts -> Mods/PalSchema/mods).
local packsDir = thisDir .. "..\\..\\PalSchema\\mods\\"

local ok, err = pcall(function()
    -- three-phase pipeline: discover -> resolve -> load (see registry.lua)
    registry.loadAll(packsDir)
    events.install()
    events.startReadyWatch()
    ticker.start()          -- central tick: entity scan + onTick + batched flush
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

-- Public API for other Lua mods (companion mods like PalLogistics call these).
local actions = require("palsmith.actions")
local entity  = require("palsmith.entity")
_G.PalSmith = {
    version = core.VERSION,
    -- actions
    registerHandler = actions.registerHandler,     -- ("ns:name", fn(args, ctx))
    registerAction = actions.register,             -- DEPRECATED alias -> smith:name
    -- entity framework (the OOP-like extension API)
    defineEntity = entity.defineEntity,            -- { id, onPlace, onLoad, onTick, onInteract, onRemove, ... }
    getEntity = entity.getEntity,
    onEntity = entity.on,                          -- ("add"|"remove", fn(instance))
    onPlace = entity.onPlace,                      -- fn(buildId, pos, player) for ANY placement (diagnostics)
    registerComponent = components.registerFactory,-- (kind, factory(instance,spec)->component)
    getComponent = components.get,                 -- (target, name) -> component | nil
    -- misc
    resolveId = require("palsmith.ids").resolve,
    spatial = require("palsmith.spatial"),         -- neighbors/keys for consumers
    registry = registry,                           -- read-only: status/loadOrder/packs
    entity = entity,                               -- read-only: instances/instanceForActor
}

-- Load trusted extension scripts INTO this VM (companion mods like PalLogistics).
-- Must run after _G.PalSmith is set so extensions see the API.
pcall(function() require("palsmith.extloader").loadAll(thisDir) end)
