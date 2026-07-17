-- PalSmith pack registry: three-phase loader (discover -> resolve -> load).
--
-- A content pack is a PalSchema mod folder with an extra "palsmith/" dir:
--   <PalSchema>/mods/<PackFolder>/
--     items/ buildings/ raw/ resources/ ...   <- handled by PalSchema
--     palsmith/
--       pack.jsonc        v2 manifest (id, version, requiresSmith, depends, ...)
--       behaviors.jsonc   { "mypack:thing": { "onUse": [ {handler,args}, ... ] } }
--       meshes.jsonc      { "mypack:bench": { "model": "models/x.obj", ... } }
--       models/*.obj
--
-- Phase A discover: read every pack.jsonc into M.manifests (no behaviors yet).
-- Phase B resolve:  resolver.resolve() -> load order + per-pack status.
-- Phase C load:     load behaviors/meshes IN ORDER, staged + committed atomically
--                   (fixes the v0.1 partial-registration leak) with id-collision
--                   detection against already-committed ids.
local core       = require("palsmith.core")
local json       = require("palsmith.json")
local ids        = require("palsmith.ids")
local manifest   = require("palsmith.manifest")
local resolver   = require("palsmith.resolver")
local idregistry = require("palsmith.idregistry")
local actions    = require("palsmith.actions")
local eventspec  = require("palsmith.eventspec")
local store      = require("palsmith.store")

local M = {
    manifests = {},  -- packId -> normalized manifest
    loadOrder = {},  -- { packId, ... } topological
    status    = {},  -- packId -> { state, reasons={}, loadIndex }
    byFolder  = {},  -- folderName -> packId
    packs     = {},  -- packId -> { id, name, version, dir } (committed only)
    behaviors = {},  -- resolvedFName -> { pack, onUse, onPlace, onInteract }
    meshes    = {},  -- resolvedFName -> { pack, model, scale, offset }
}

local function loadJsonc(path)
    local text = core.readFile(path)
    if not text then return nil end
    local value, err = json.decode(text)
    if value == nil and err then return nil, err end
    return value
end

local function newStatus(state, reason)
    return { state = state, reasons = reason and { reason } or {}, loadIndex = nil }
end

-- ---- Phase A: discovery ----
function M.discover(modsDir)
    M.manifests, M.byFolder = {}, {}
    local preStatus = {}                      -- discovery-time failures (dup / malformed)
    local folders = core.listDirs(modsDir)
    if #folders == 0 then core.warn("no pack folders found under " .. modsDir) end

    for _, folder in ipairs(folders) do
        local dir = modsDir .. folder .. "\\"
        local okCall, m, err = pcall(manifest.load, dir, folder)
        if not okCall then
            preStatus[folder] = newStatus("error", "pack.jsonc crashed: " .. tostring(m))
        elseif err then
            preStatus[folder] = newStatus("error", err)
        elseif m then
            if M.manifests[m.id] then
                -- duplicate id across two folders: keep the first (alphabetical), mark both
                local firstFolder = M.manifests[m.id].folderName
                preStatus[m.id] = newStatus("duplicate",
                    string.format("duplicate pack id '%s' in folders '%s' and '%s'", m.id, firstFolder, folder))
            else
                M.manifests[m.id] = m
                M.byFolder[folder] = m.id
                for _, w in ipairs(m.warnings or {}) do
                    core.warn(string.format("pack '%s': %s", m.id, w))
                end
            end
        end
        -- m == nil and no err => plain PalSchema mod (no palsmith/), skip silently
    end
    M._preStatus = preStatus
end

-- ---- Phase B: resolution ----
function M.resolve()
    local res = resolver.resolve(M.manifests, {
        smithVersion = core.VERSION,
        manifestFormat = core.MANIFEST_FORMAT,
        preStatus = M._preStatus,
    })
    M.loadOrder = res.order
    M.status = res.status
    -- fold in discovery pre-status packs (duplicates/errors) that aren't in manifests
    for id, st in pairs(M._preStatus or {}) do
        if not M.status[id] then M.status[id] = st end
    end
end

-- Stage one pack's behaviors + meshes + ids. Returns ok, err, stage.
-- stage = { behaviors={fname->entry}, meshes={fname->def}, idPairs={{fname,nsId}} }
local function stagePack(m)
    local packId = m.id
    local psDir = m.dir .. "palsmith\\"
    local stage = { behaviors = {}, meshes = {}, idPairs = {} }

    -- deps set for value-import checks (depends ∪ recommends)
    local declaredDeps = {}
    for ns in pairs(m.depends or {}) do declaredDeps[ns] = true end
    for ns in pairs(m.recommends or {}) do declaredDeps[ns] = true end

    -- content ids from items/ buildings/ (+ provides) -> owned by this pack
    local contentIds = idregistry.collect(m)
    for fname, nsId in pairs(contentIds) do
        table.insert(stage.idPairs, { fname, nsId })
    end

    -- behaviors.jsonc
    local behaviors, berr = loadJsonc(psDir .. "behaviors.jsonc")
    if berr then return false, "behaviors.jsonc: " .. berr end
    for id, events in pairs(behaviors or {}) do
        if id:sub(1, 1) ~= "$" then
            if type(events) ~= "table" then
                return false, string.format("behaviors.jsonc: '%s' must map to an object of events", id)
            end
            local ok, oerr = ids.checkOwnership(id, packId)
            if not ok then return false, "behaviors.jsonc: " .. oerr end
            local resolved, rerr = ids.resolve(id)
            if not resolved then return false, "behaviors.jsonc: " .. rerr end
            local entry = { pack = packId }
            for event, rawList in pairs(events) do
                if not eventspec.isEvent(event) then
                    return false, string.format("behaviors.jsonc: '%s' has unknown event '%s'", id, event)
                end
                if type(rawList) ~= "table" or #rawList == 0 then
                    return false, string.format("behaviors.jsonc: '%s'.%s must be a non-empty array", id, event)
                end
                local norm = actions.normalize(rawList, packId)
                -- missing handler = hard error (author typo)
                local missing = actions.missingHandlers(norm)
                if #missing > 0 then
                    return false, string.format("behaviors.jsonc: '%s'.%s uses unknown handler(s): %s",
                        id, event, table.concat(missing, ", "))
                end
                -- value-import warnings (referencing another pack's ids w/o depending)
                for _, e in ipairs(norm) do
                    for _, v in pairs(e.args or {}) do
                        if type(v) == "string" then
                            local okImp, impErr = ids.checkImport(v, packId, declaredDeps)
                            if not okImp then core.warn(string.format("pack '%s': %s", packId, impErr)) end
                        end
                    end
                end
                if not eventspec.isDispatched(event) then
                    core.warn(string.format("pack '%s': event '%s' on '%s' is reserved and not dispatched by PalSmith v%s",
                        packId, event, id, core.VERSION))
                end
                entry[event] = norm
            end
            stage.behaviors[resolved] = entry
            -- a behavior key in our namespace is also an owned id
            if id:find(":") then table.insert(stage.idPairs, { resolved, id }) end
        end
    end

    -- meshes.jsonc
    local meshes, merr = loadJsonc(psDir .. "meshes.jsonc")
    if merr then return false, "meshes.jsonc: " .. merr end
    for id, def in pairs(meshes or {}) do
        if id:sub(1, 1) ~= "$" then
            if type(def) ~= "table" then
                return false, string.format("meshes.jsonc: '%s' must map to an object", id)
            end
            local ok, oerr = ids.checkOwnership(id, packId)
            if not ok then return false, "meshes.jsonc: " .. oerr end
            local resolved, rerr = ids.resolve(id)
            if not resolved then return false, "meshes.jsonc: " .. rerr end
            if type(def.model) ~= "string" then
                return false, string.format("meshes.jsonc: '%s' needs a 'model' path", id)
            end
            local modelPath = psDir .. def.model:gsub("/", "\\")
            if not core.exists(modelPath) then
                return false, string.format("meshes.jsonc: '%s' model file not found: %s", id, modelPath)
            end
            stage.meshes[resolved] = {
                pack = packId, model = modelPath,
                scale = def.scale or 1.0, offset = def.offset or { x = 0, y = 0, z = 0 },
            }
        end
    end

    -- dry-run collision check against already-committed ids (don't mutate yet)
    for _, pair in ipairs(stage.idPairs) do
        local fname = pair[1]
        local existing = idregistry.owners[fname]
        if existing and existing ~= packId then
            return false, string.format("id collision: '%s' already owned by pack '%s'", fname, existing)
        end
    end

    return true, nil, stage
end

-- ---- Phase C: load ----
function M.load()
    local loaded = 0
    for _, packId in ipairs(M.loadOrder) do
        local m = M.manifests[packId]
        local st = M.status[packId]
        local okCall, ok, err, stage = pcall(stagePack, m)
        if not okCall then
            st.state = "error"; table.insert(st.reasons, "load crashed: " .. tostring(ok))
        elseif not ok then
            st.state = (st.state == "loaded" or st.state == "conflict") and "error" or st.state
            table.insert(st.reasons, err)
        else
            -- atomic commit
            for fname, entry in pairs(stage.behaviors) do M.behaviors[fname] = entry end
            for fname, def in pairs(stage.meshes) do M.meshes[fname] = def end
            for _, pair in ipairs(stage.idPairs) do
                idregistry.declare(packId, pair[1], pair[2])
            end
            M.packs[packId] = { id = m.id, name = m.name, version = m.version, dir = m.dir }
            loaded = loaded + 1
            local nb, nm = 0, 0
            for _ in pairs(stage.behaviors) do nb = nb + 1 end
            for _ in pairs(stage.meshes) do nm = nm + 1 end
            core.log(string.format("pack '%s' v%s loaded #%s (%d behaviors, %d meshes)",
                packId, m.version, tostring(st.loadIndex), nb, nm))
        end
    end

    -- surface non-loaded packs
    for id, st in pairs(M.status) do
        if not M.packs[id] and st.state ~= "loaded" then
            core.warn(string.format("pack '%s' inactive [%s]: %s", id, st.state,
                table.concat(st.reasons, "; ")))
        end
    end

    -- expose the known-pack set for ids.display fallback
    idregistry._knownPacks = {}
    for id in pairs(M.packs) do idregistry._knownPacks[id] = true end

    -- F8 snapshot
    pcall(function() store.setAndFlush("id_snapshot", idregistry.snapshot()) end)

    core.log(string.format("registry ready: %d pack(s) active", loaded))
end

-- Convenience: full pipeline.
function M.loadAll(modsDir)
    idregistry.reset()
    M.packs, M.behaviors, M.meshes = {}, {}, {}
    M.discover(modsDir)
    M.resolve()
    M.load()
end

-- ---- lookups (unchanged surface) ----
function M.behaviorFor(fname, event)
    local entry = M.behaviors[fname]
    if entry then return entry[event], entry.pack end
    return nil
end

function M.meshFor(fname) return M.meshes[fname] end

return M
