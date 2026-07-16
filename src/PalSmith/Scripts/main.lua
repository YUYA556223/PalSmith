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

local core     = require("palsmith.core")
local registry = require("palsmith.registry")
local events   = require("palsmith.events")

core.log("PalSmith v" .. core.VERSION .. " starting")

-- Content packs live inside PalSchema's mods dir (Mods/PalSmith/Scripts -> Mods/PalSchema/mods).
local packsDir = thisDir .. "..\\..\\PalSchema\\mods\\"

local ok, err = pcall(function()
    registry.loadAll(packsDir)
    events.install()
end)
if not ok then
    core.err("startup failed: " .. tostring(err))
else
    core.log("ready")
end

-- Public API for other Lua mods:
--   local palsmith = require("palsmith.api")
_G.PalSmith = {
    version = core.VERSION,
    registerAction = require("palsmith.actions").register,
    resolveId = require("palsmith.ids").resolve,
}
