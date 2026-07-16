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

-- Validates that a namespaced id belongs to the given pack (used when loading
-- a pack's behavior declarations - a pack may only declare behaviors for its
-- own namespace or literal ids it explicitly opts into with "!").
function M.checkOwnership(id, packId)
    local pack = id:match("^([^:]+):")
    if pack and pack ~= packId then
        return false, string.format("'%s' declares an id in namespace '%s' (pack is '%s')", id, pack, packId)
    end
    return true
end

-- Best-effort reverse mapping for display: "packid_name" -> "packid:name"
-- given a set of known pack ids.
function M.display(fname, knownPacks)
    for pack in pairs(knownPacks or {}) do
        local prefix = pack .. "_"
        if fname:sub(1, #prefix) == prefix then
            return pack .. ":" .. fname:sub(#prefix + 1)
        end
    end
    return fname
end

return M
