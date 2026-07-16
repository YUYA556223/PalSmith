-- PalSmith pack registry: discovers content packs and builds the behavior map.
--
-- A content pack is a normal PalSchema mod folder with an extra "palsmith/" dir:
--   <PalSchema>/mods/<PackFolder>/
--     items/ buildings/ raw/ resources/ ...   <- handled by PalSchema
--     palsmith/
--       pack.jsonc        { "id": "mypack", "name": ..., "requiresSmith": "0.1" }
--       behaviors.jsonc   { "mypack:thing": { "onUse": [ {action...} ], ... } }
--       meshes.jsonc      { "mypack:bench": { "model": "models/x.obj", ... } }
--       models/*.obj
--
-- Fail-soft: a broken pack is skipped with a specific error; others still load.
local core = require("palsmith.core")
local json = require("palsmith.json")
local ids  = require("palsmith.ids")

local M = {
    packs = {},      -- packId -> { id, name, version, dir }
    behaviors = {},  -- resolvedFName -> { pack=packId, onUse={...}, onPlace={...}, onInteract={...} }
    meshes = {},     -- resolvedFName -> { pack=packId, model=absPath, scale, offset }
}

local EVENTS = { onUse = true, onPlace = true, onInteract = true }

local function loadJsonc(path)
    local text = core.readFile(path)
    if not text then return nil end
    local value, err = json.decode(text)
    if value == nil and err then return nil, err end
    return value
end

local function loadPack(dir, folderName)
    local psDir = dir .. "palsmith\\"
    local manifest, err = loadJsonc(psDir .. "pack.jsonc")
    if manifest == nil then
        if err then return nil, "pack.jsonc: " .. err end
        return nil -- no palsmith/ folder: plain PalSchema mod, not ours
    end
    if type(manifest.id) ~= "string" or not manifest.id:match("^[%w_]+$") then
        return nil, "pack.jsonc: 'id' is required (letters/digits/_ only)"
    end
    local packId = manifest.id
    if M.packs[packId] then
        return nil, string.format("duplicate pack id '%s' (already loaded from %s)", packId, M.packs[packId].dir)
    end

    local pack = {
        id = packId,
        name = manifest.name or folderName,
        version = manifest.version or "0.0.0",
        dir = dir,
    }

    -- behaviors.jsonc
    local behaviors, berr = loadJsonc(psDir .. "behaviors.jsonc")
    if berr then return nil, "behaviors.jsonc: " .. berr end
    local count = 0
    for id, events in pairs(behaviors or {}) do
        if id:sub(1, 1) == "$" then goto continue_behaviors end -- editor keys like $schema
        if type(events) ~= "table" then
            return nil, string.format("behaviors.jsonc: '%s' must map to an object of events", id)
        end
        local ok, oerr = ids.checkOwnership(id, packId)
        if not ok then return nil, "behaviors.jsonc: " .. oerr end
        local resolved, rerr = ids.resolve(id)
        if not resolved then return nil, "behaviors.jsonc: " .. rerr end
        local entry = { pack = packId }
        for event, actions in pairs(events) do
            if not EVENTS[event] then
                return nil, string.format("behaviors.jsonc: '%s' has unknown event '%s'", id, event)
            end
            if type(actions) ~= "table" or #actions == 0 then
                return nil, string.format("behaviors.jsonc: '%s'.%s must be a non-empty array of actions", id, event)
            end
            entry[event] = actions
        end
        M.behaviors[resolved] = entry
        count = count + 1
        ::continue_behaviors::
    end

    -- meshes.jsonc
    local meshes, merr = loadJsonc(psDir .. "meshes.jsonc")
    if merr then return nil, "meshes.jsonc: " .. merr end
    local meshCount = 0
    for id, def in pairs(meshes or {}) do
        if id:sub(1, 1) == "$" then goto continue_meshes end -- editor keys like $schema
        if type(def) ~= "table" then
            return nil, string.format("meshes.jsonc: '%s' must map to an object", id)
        end
        local ok, oerr = ids.checkOwnership(id, packId)
        if not ok then return nil, "meshes.jsonc: " .. oerr end
        local resolved, rerr = ids.resolve(id)
        if not resolved then return nil, "meshes.jsonc: " .. rerr end
        if type(def.model) ~= "string" then
            return nil, string.format("meshes.jsonc: '%s' needs a 'model' path", id)
        end
        local modelPath = psDir .. def.model:gsub("/", "\\")
        if not core.exists(modelPath) then
            return nil, string.format("meshes.jsonc: '%s' model file not found: %s", id, modelPath)
        end
        M.meshes[resolved] = {
            pack = packId,
            model = modelPath,
            scale = def.scale or 1.0,
            offset = def.offset or { x = 0, y = 0, z = 0 },
        }
        meshCount = meshCount + 1
        ::continue_meshes::
    end

    M.packs[packId] = pack
    core.log(string.format("pack '%s' v%s loaded (%d behaviors, %d meshes) from %s",
        packId, pack.version, count, meshCount, folderName))
    return pack
end

-- Scan the PalSchema mods dir. Every failure is logged per-pack; loading continues.
function M.loadAll(palschemaModsDir)
    local folders = core.listDirs(palschemaModsDir)
    if #folders == 0 then
        core.warn("no pack folders found under " .. palschemaModsDir)
    end
    for _, folder in ipairs(folders) do
        local dir = palschemaModsDir .. folder .. "\\"
        local okCall, pack, err = pcall(loadPack, dir, folder)
        if not okCall then
            core.err(string.format("pack '%s' crashed while loading: %s", folder, tostring(pack)))
        elseif err then
            core.err(string.format("pack '%s' skipped: %s", folder, err))
        end
    end
    local n = 0
    for _ in pairs(M.packs) do n = n + 1 end
    core.log(string.format("registry ready: %d pack(s)", n))
end

function M.behaviorFor(fname, event)
    local entry = M.behaviors[fname]
    if entry then return entry[event], entry.pack end
    return nil
end

function M.meshFor(fname)
    return M.meshes[fname]
end

return M
