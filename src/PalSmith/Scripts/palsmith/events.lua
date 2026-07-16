-- PalSmith event layer: hooks verified game functions and dispatches behaviors.
--
-- Verified hooks (see __knowledges / deprecated/poc V2+V3, 2026-07-16):
--   onUse      PalItemUseProcessor:UseItemToCharacter_ServerInternal (param1.ID = FName)
--   onPlace    PalNetworkPlayerComponent:RequestBuild_ToServer (param1 = FName BuildObjectId)
--   onLoad*    PalPlayerRecordData:OnCompleteBuild_ServerInternal (also fires on world load)
--   onInteract PalBuildObject:OnBeginInteractBuilding (self = building actor)
--
-- Design notes baked in from V3: interact fires for building<->building overlaps
-- (filter: other must be a PalCharacter) and repeats rapidly (debounce).
local core     = require("palsmith.core")
local registry = require("palsmith.registry")
local actions  = require("palsmith.actions")
local mesh     = require("palsmith.mesh")

local M = { hooksRegistered = 0, hooksTotal = 0 }

local INTERACT_DEBOUNCE_SEC = 1.0
local lastInteract = {} -- "<actorName>" -> os.clock()

local cooldowns = {} -- "<id>/<event>" -> os.clock()

local function get(param) return param:get() end

local function cooldownOk(id, event, actionList)
    -- honor the largest cooldownSec declared on any action of this list
    local cd = 0
    for _, a in ipairs(actionList) do
        if type(a.cooldownSec) == "number" and a.cooldownSec > cd then cd = a.cooldownSec end
    end
    if cd <= 0 then return true end
    local key = id .. "/" .. event
    local now = os.clock()
    if cooldowns[key] and (now - cooldowns[key]) < cd then return false end
    cooldowns[key] = now
    return true
end

local function dispatch(event, fnameStr, ctx)
    local actionList, packId = registry.behaviorFor(fnameStr, event)
    if not actionList then return end
    if not cooldownOk(fnameStr, event, actionList) then return end
    ctx.id = fnameStr
    ctx.event = event
    ctx.pack = packId
    ctx.packDir = registry.packs[packId] and registry.packs[packId].dir or ""
    core.log(string.format("%s -> %s (pack %s)", event, fnameStr, tostring(packId)))
    actions.run(actionList, ctx)
end

local function tryHook(path, fn)
    M.hooksTotal = M.hooksTotal + 1
    local ok, err = pcall(RegisterHook, path, fn)
    if ok then
        M.hooksRegistered = M.hooksRegistered + 1
    else
        core.warn("hook unavailable (feature disabled): " .. path .. " -> " .. tostring(err))
    end
end

function M.install()
    -- onUse ------------------------------------------------------------
    tryHook("/Script/Pal.PalItemUseProcessor:UseItemToCharacter_ServerInternal", function(self, itemData, targetId)
        local ok, err = pcall(function()
            local id = get(itemData).ID:ToString()
            dispatch("onUse", id, { player = FindFirstOf("PalPlayerCharacter") })
        end)
        if not ok then core.err("onUse handler: " .. tostring(err)) end
    end)

    -- onPlace (build request carries the id) -----------------------------
    tryHook("/Script/Pal.PalNetworkPlayerComponent:RequestBuild_ToServer", function(self, buildObjectId)
        local ok, err = pcall(function()
            local id = get(buildObjectId):ToString()
            dispatch("onPlace", id, { player = FindFirstOf("PalPlayerCharacter") })
        end)
        if not ok then core.err("onPlace handler: " .. tostring(err)) end
    end)

    -- onInteract (self = building actor) --------------------------------
    tryHook("/Script/Pal.PalBuildObject:OnBeginInteractBuilding", function(self, other)
        local ok, err = pcall(function()
            local building = get(self)
            local otherActor = get(other)
            -- filter: only care about characters (V3: buildings interact with each other)
            local charClass = StaticFindObject("/Script/Pal.PalCharacter")
            if not (otherActor and otherActor:IsValid()) then return end
            if charClass and charClass:IsValid() and not otherActor:IsA(charClass) then return end

            local actorName = building:GetFullName()
            local now = os.clock()
            if lastInteract[actorName] and (now - lastInteract[actorName]) < INTERACT_DEBOUNCE_SEC then return end
            lastInteract[actorName] = now

            -- identify the building id from its class name: BP_BuildObject_<Id>_C
            local cls = building:GetClass():GetFullName()
            local id = cls:match("BP_BuildObject_([%w_]+)_C") or cls
            local ctx = { player = otherActor, actor = building }
            dispatch("onInteract", id, ctx)

            -- lazy mesh attach: reused blueprints can't be told apart by class,
            -- so custom ids resolved via the build tables attach on first touch
            local meshDef = registry.meshFor(id)
            if meshDef then mesh.attachOnce(building, meshDef) end
        end)
        if not ok then core.err("onInteract handler: " .. tostring(err)) end
    end)

    -- onLoad / build complete: mesh re-apply trigger ----------------------
    tryHook("/Script/Pal.PalPlayerRecordData:OnCompleteBuild_ServerInternal", function(self, model)
        local ok, err = pcall(function()
            local m = get(model)
            local id = m.BuildObjectId:ToString()
            local meshDef = registry.meshFor(id)
            if not meshDef then return end
            -- try known accessors to reach the spawned actor from the model
            local actor = nil
            for _, getterName in ipairs({ "GetMapObject", "GetActor" }) do
                local okA, a = pcall(function() return m[getterName](m) end)
                if okA and a and a.IsValid and a:IsValid() then actor = a; break end
            end
            if not actor then
                local okF, f = pcall(function() return m.MapObject end)
                if okF and f and f.IsValid and f:IsValid() then actor = f end
            end
            if actor then
                mesh.attachOnce(actor, meshDef)
            else
                core.warn("mesh: could not resolve actor from MapObjectModel for " .. id ..
                    " (will attach on first interact instead)")
            end
        end)
        if not ok then core.err("onLoad handler: " .. tostring(err)) end
    end)

    core.log(string.format("events installed: %d/%d hooks active", M.hooksRegistered, M.hooksTotal))
end

return M
