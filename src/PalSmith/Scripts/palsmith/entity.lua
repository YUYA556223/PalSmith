-- PalSmith entity framework: the OOP-like "machine" layer.
--
-- Consumers (trusted companion Lua mods) call PalSmith.defineEntity{...} with
-- lifecycle FUNCTIONS. An "entity" is a BlockEntity analog: persistent per-
-- instance state bound to a placed building at a quantized world position, with
-- a lifecycle (onPlace/onLoad/onTick/onInteract/onRemove).
--
-- Dispatch keys on ACTOR/POSITION, never on the class name, because reused
-- vanilla BPs share a class name (BP_BuildObject_WorkBench_C) — see events.lua.
local core    = require("palsmith.core")
local ids     = require("palsmith.ids")
local spatial = require("palsmith.spatial")
local store   = require("palsmith.store")

local M = {
    defs       = {},   -- entityId -> def
    byBuildId  = {},   -- resolvedBuildId -> def
    instances  = {},   -- key -> instance
    tickList   = {},   -- array of instances with an onTick
    observers  = { add = {}, remove = {} },
    topologyVersion = 0,
}
-- weak actor -> instance map (actors are engine objects; don't keep them alive)
M.instancesByActor = setmetatable({}, { __mode = "k" })

local MISS_THRESHOLD = 3  -- consecutive scans an instance may be unseen before removal

-- ---- persistence (per-world file) ----
local worldCache = nil    -- { version, entities = { key -> record } }
local worldDirty = false

local function worldKey()
    return "entities_" .. spatial.saveId()
end

local function loadWorld()
    if worldCache then return worldCache end
    local data = store.get(worldKey())
    if type(data) ~= "table" or type(data.entities) ~= "table" then
        data = { version = 1, entities = {} }
    end
    worldCache = data
    return worldCache
end

function M.flushWorld()
    if not worldCache or not worldDirty then return end
    store.setAndFlush(worldKey(), worldCache)
    worldDirty = false
end

function M.isDirty() return worldDirty end

-- ---- observers (network.lua subscribes here later) ----
function M.on(kind, fn)
    if M.observers[kind] then table.insert(M.observers[kind], fn) end
end
local function fire(kind, instance)
    for _, fn in ipairs(M.observers[kind] or {}) do pcall(fn, instance) end
end

-- ---- definition ----
-- validate + register an entity definition.
function M.defineEntity(spec)
    assert(type(spec) == "table", "defineEntity requires a table")
    local id = spec.id
    assert(type(id) == "string" and #id > 0, "defineEntity: 'id' required")
    for _, k in ipairs({ "onPlace", "onLoad", "onTick", "onInteract", "onRemove" }) do
        assert(spec[k] == nil or type(spec[k]) == "function", "defineEntity: '" .. k .. "' must be a function")
    end
    local tickInterval = spec.tickInterval or 1
    assert(type(tickInterval) == "number" and tickInterval >= 1 and tickInterval % 1 == 0,
        "defineEntity: 'tickInterval' must be a positive integer")

    local buildIds = spec.buildIds or { id }
    local resolved = {}
    for _, bid in ipairs(buildIds) do
        local r, err = ids.resolve(bid)
        if not r then error("defineEntity: bad buildId '" .. tostring(bid) .. "': " .. tostring(err)) end
        table.insert(resolved, r)
    end

    local def = {
        id = id,
        buildIds = resolved,
        tickInterval = tickInterval,
        gridCm = spec.gridCm or spatial.GRID_CM,
        defaultState = spec.defaultState,
        components = spec.components or {},
        mesh = spec.mesh,
        displayName = spec.displayName or id,
        onPlace = spec.onPlace, onLoad = spec.onLoad, onTick = spec.onTick,
        onInteract = spec.onInteract, onRemove = spec.onRemove,
    }
    if M.defs[id] then core.warn("entity '" .. id .. "' redefined (last wins)") end
    M.defs[id] = def
    for _, r in ipairs(resolved) do
        if M.byBuildId[r] and M.byBuildId[r] ~= def then
            core.warn("buildId '" .. r .. "' rebound to entity '" .. id .. "'")
        end
        M.byBuildId[r] = def
    end
    core.log(string.format("entity '%s' defined (builds: %s)", id, table.concat(resolved, ",")))
    return def
end

function M.getEntity(id) return M.defs[id] end
function M.instanceForActor(actor) return M.instancesByActor[actor] end
function M.instanceAt(key) return M.instances[key] end

-- ---- instance object ----
local function makeInstance(def, buildId, actor, pos, state, key)
    local inst
    inst = {
        id = def.id, def = def, key = key, buildId = buildId,
        pos = pos, cell = spatial.cellOf(pos, def.gridCm),
        actor = actor, state = state or {}, components = {},
        missingStreak = 0,
        setDirty = function(self) worldDirty = true; local rec = loadWorld().entities[self.key]
            if rec then rec.state = self.state end end,
        save = function(self) self:setDirty(); M.flushWorld() end,
        getComponent = function(self, name)
            local components = require("palsmith.components")
            return components.get(self, name)
        end,
        openMenu = function(self, opts)
            local entityui = require("palsmith.entityui")
            return entityui.open(self, opts)
        end,
        isValid = function(self) return self.actor and self.actor:IsValid() end,
    }
    return inst
end

-- write/refresh the persisted record for an instance
local function persist(inst)
    local w = loadWorld()
    w.entities[inst.key] = { buildId = inst.buildId, pos = inst.pos, state = inst.state, altKeys = {} }
    worldDirty = true
end

-- register a live instance: index, components, mesh, tick set, observers.
function M.addInstance(inst)
    M.instances[inst.key] = inst
    if inst.actor then M.instancesByActor[inst.actor] = inst end
    spatial.indexAdd(inst)
    -- components
    pcall(function() require("palsmith.components").attach(inst) end)
    -- mesh (optional inline)
    if inst.def.mesh and inst.actor then
        pcall(function() require("palsmith.mesh").attachOnce(inst.actor, inst.def.mesh) end)
    end
    if inst.def.onTick then table.insert(M.tickList, inst) end
    M.topologyVersion = M.topologyVersion + 1
    fire("add", inst)
end

function M.removeInstance(key, reason)
    local inst = M.instances[key]
    if not inst then return end
    if inst.def.onRemove then
        pcall(inst.def.onRemove, inst, { event = "onRemove", reason = reason or "missing" })
    end
    fire("remove", inst)
    spatial.indexRemove(inst)
    if inst.actor then M.instancesByActor[inst.actor] = nil end
    -- drop from tick list (swap-remove)
    for i = #M.tickList, 1, -1 do
        if M.tickList[i] == inst then table.remove(M.tickList, i); break end
    end
    M.instances[key] = nil
    M.topologyVersion = M.topologyVersion + 1
    -- delete persisted record only on genuine removal (not world-left)
    if reason ~= "world_left" then
        loadWorld().entities[key] = nil
        worldDirty = true
    end
end

-- ---- placement intent (from events.onPlace) ----
M.pending = {}  -- array of { buildId, pos, player, ts }
M.placeObservers = {}  -- fn(buildId, pos, player) for EVERY placement (any build id)

-- Observe every build placement (for diagnostics / discovery). Exposed as
-- PalSmith.onPlace. Fires for all build ids, not just registered entities.
function M.onPlace(fn) table.insert(M.placeObservers, fn) end

function M.onPlaceRequest(resolvedBuildId, pos, player)
    for _, fn in ipairs(M.placeObservers) do pcall(fn, resolvedBuildId, pos, player) end
    if not M.byBuildId[resolvedBuildId] then return end
    table.insert(M.pending, { buildId = resolvedBuildId, pos = pos, player = player })
    -- keep it small
    while #M.pending > 16 do table.remove(M.pending, 1) end
end

local function popPendingNear(buildId, pos)
    if not pos then return nil end
    local best, bestI, bestD = nil, nil, math.huge
    for i, p in ipairs(M.pending) do
        if p.buildId == buildId and p.pos then
            local d = spatial.dist2(pos, p.pos)
            if d < bestD and d <= (300 * 300) then best, bestI, bestD = p, i, d end
        end
    end
    if bestI then table.remove(M.pending, bestI) end
    return best
end

-- ---- reconstruction scan (crash-safe; runs post-worldReady via ticker) ----
-- resolveBuildId(actor): 3-tier. 1) class-name BP_BuildObject_<Id>_C direct map;
-- 2) actor's MapObjectModel.BuildObjectId (safe post-worldReady); 3) caller uses
-- a persisted record's buildId at the cell (handled in scan via position match).
local function resolveBuildId(actor)
    -- tier 1: class name
    local ok, cls = pcall(function() return actor:GetClass():GetFullName() end)
    if ok and cls then
        local nm = cls:match("BP_BuildObject_([%w_]+)_C")
        if nm and M.byBuildId[nm] then return nm end
    end
    -- tier 2: model.BuildObjectId
    local ok2, bid = pcall(function()
        local m = actor.MapObjectModel or (actor.GetModel and actor:GetModel())
        if m and m:IsValid() then return m.BuildObjectId:ToString() end
    end)
    if ok2 and bid and M.byBuildId[bid] then return bid end
    return nil
end

local function actorPos(actor)
    local ok, loc = pcall(function()
        return actor.K2_GetActorLocation and actor:K2_GetActorLocation() or actor:GetActorLocation()
    end)
    if not ok or not loc then return nil end
    local p = { x = loc.X, y = loc.Y, z = loc.Z }
    if (p.x == 0 and p.y == 0 and p.z == 0) then return nil end -- not-ready sentinel
    return p
end

-- one reconstruction pass. Called by the ticker on a cadence.
function M.scan()
    local okFind, actors = pcall(FindAllOf, "PalBuildObject")
    if not okFind or type(actors) ~= "table" then return end
    local matched = {}

    for _, actor in ipairs(actors) do
        local ok = pcall(function()
            if not (actor and actor:IsValid()) then return end
            local pos = actorPos(actor)
            if not pos then return end -- not ready; retried next scan

            local buildId = resolveBuildId(actor)
            -- tier 3: position match against a persisted record for any of our builds
            if not buildId then
                for _, def in pairs(M.defs) do
                    for _, bid in ipairs(def.buildIds) do
                        local k = spatial.keyOf(bid, spatial.cellOf(pos, def.gridCm))
                        if loadWorld().entities[k] then buildId = bid; break end
                    end
                    if buildId then break end
                end
            end
            if not buildId then return end
            local def = M.byBuildId[buildId]
            if not def then return end

            local cell = spatial.cellOf(pos, def.gridCm)
            local key = spatial.keyOf(buildId, cell)
            matched[key] = true

            local inst = M.instances[key]
            if inst then
                inst.actor = actor; inst.pos = pos
                M.instancesByActor[actor] = inst
                inst.missingStreak = 0
                return
            end

            local rec = loadWorld().entities[key]
            local pend = popPendingNear(buildId, pos)
            local state
            if rec then state = rec.state or {}
            elseif def.defaultState then local oks, s = pcall(def.defaultState); state = oks and s or {}
            else state = {} end

            inst = makeInstance(def, buildId, actor, pos, state, key)
            if not rec then persist(inst) end
            M.addInstance(inst)

            if not rec and pend and def.onPlace then
                pcall(def.onPlace, inst, { event = "onPlace", player = pend.player, actor = actor, pos = pos, buildId = buildId, firstSeen = true })
            end
            if def.onLoad then
                pcall(def.onLoad, inst, { event = "onLoad", actor = actor, pos = pos, reconstructed = (rec ~= nil) })
            end
        end)
        if not ok then core.warn("entity.scan: actor pass failed") end
    end

    -- removal sweep
    for key, inst in pairs(M.instances) do
        if not matched[key] then
            inst.missingStreak = (inst.missingStreak or 0) + 1
            if inst.missingStreak >= MISS_THRESHOLD then
                M.removeInstance(key, "missing")
            end
        end
    end
end

-- called by ticker on worldReady true->false: drop live instances, keep records.
function M.onWorldLeft()
    M.flushWorld()
    local keys = {}
    for k in pairs(M.instances) do keys[#keys + 1] = k end
    for _, k in ipairs(keys) do M.removeInstance(k, "world_left") end
    M.instancesByActor = setmetatable({}, { __mode = "k" })
    spatial.indexReset()
    worldCache = nil  -- re-read on next world (saveId may differ)
    spatial.resetSaveId()
end

return M
