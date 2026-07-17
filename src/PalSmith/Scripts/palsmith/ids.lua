-- PalSmith ID resolution.
--
-- Content packs use namespaced ids: "packid:name". In the game's DataTables the
-- corresponding row FName is "<packid>_<name>" (PalSchema rows are global, so the
-- pack id prefix is what prevents collisions between packs).
--
-- Ids WITHOUT a colon are treated as literal game ids ("Wood", "BlueSkyDragon"),
-- so vanilla content can be referenced anywhere a namespaced id is accepted.
local core = require("palsmith.core")

local M = {}

local VALID = "^[%w_]+$"

-- "packid:name" -> "packid_name"; "Literal" -> "Literal".
-- Returns resolved string, or nil + error.
function M.resolve(id)
    if type(id) ~= "string" or #id == 0 then return nil, "id must be a non-empty string" end
    local pack, name = id:match("^([^:]+):(.+)$")
    if not pack then return id end -- literal game id
    if not pack:match(VALID) then return nil, "invalid pack id '" .. pack .. "' (letters/digits/_ only)" end
    if not name:match(VALID) then return nil, "invalid name '" .. name .. "' (letters/digits/_ only)" end
    return pack .. "_" .. name
end

-- KEY OWNERSHIP: a pack may only ATTACH behaviors/meshes to ids in its own
-- namespace, or to literal ids. (The id a behavior is keyed on.)
function M.checkOwnership(id, packId)
    local pack = id:match("^([^:]+):")
    if pack and pack ~= packId then
        return false, string.format("'%s' declares an id in namespace '%s' (pack is '%s')", id, pack, packId)
    end
    return true
end

-- VALUE REFERENCE / IMPORT: an id MENTIONED inside args (e.g. give_item.item =
-- "otherpack:Thing"). Allowed only for the pack's own namespace, a literal id,
-- or a namespace the pack declared as a dependency. `declaredDeps` is a set-like
-- table (namespace -> anything) built from depends ∪ recommends. Soft (warning).
function M.checkImport(refId, packId, declaredDeps)
    if type(refId) ~= "string" then return true end
    local ns = refId:match("^([^:]+):")
    if not ns then return true end                 -- literal id
    if ns == packId then return true end           -- own namespace
    if declaredDeps and declaredDeps[ns] then return true end
    return false, string.format("references '%s' but does not declare a dependency on '%s'", refId, ns)
end

-- Reverse mapping for display: "packid_name" -> "packid:name".
-- Preferred form: pass the idregistry (has an authoritative `reverse` map, O(1),
-- unambiguous). Legacy form: pass a set of known pack ids (best-effort,
-- longest-prefix wins to reduce the `_`-in-name ambiguity).
function M.display(fname, source)
    if type(source) == "table" and source.reverse then
        local exact = source.reverse[fname]
        if exact then return exact end
        source = source._knownPacks or nil -- optional fallback set on the registry
    end
    if type(source) == "table" then
        local bestPack, bestLen = nil, -1
        for pack in pairs(source) do
            local prefix = pack .. "_"
            if #pack > bestLen and fname:sub(1, #prefix) == prefix then
                bestPack, bestLen = pack, #pack
            end
        end
        if bestPack then return bestPack .. ":" .. fname:sub(#bestPack + 2) end
    end
    return fname
end

return M
