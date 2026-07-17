-- PalSmith central content-id registry. Tracks which pack owns each resolved
-- FName (game DataTable row key like "example_Potion"), detects collisions across
-- packs, and produces a snapshot for the F8 uninstall safety net.
--
-- IDs are the RESOLVED FName form ("packid_Name"), matching the keys packs author
-- by hand in items/ buildings/ and the resolved keys of behaviors/meshes.
local core = require("palsmith.core")
local json = require("palsmith.json")

local M = {}

-- Reserved top-level namespaces (handler namespace, future builtins).
local RESERVED = { smith = true, pal = true }

function M.reset()
    M.owners  = {}   -- resolvedFName -> packId
    M.reverse = {}   -- resolvedFName -> "packid:Name"
    M.byPack  = {}   -- packId -> { resolvedFName, ... }
end
M.reset()

-- Register one id for a pack. Returns ok, err. Collision (already owned by
-- another pack) or a reserved namespace prefix is an error.
function M.declare(packId, resolvedFName, namespacedId)
    local ns = namespacedId and namespacedId:match("^([^:]+):") or packId
    if RESERVED[ns] and ns ~= packId then
        return false, string.format("'%s' uses reserved namespace '%s'", namespacedId or resolvedFName, ns)
    end
    local existing = M.owners[resolvedFName]
    if existing and existing ~= packId then
        return false, string.format("id '%s' already declared by pack '%s'", resolvedFName, existing)
    end
    M.owners[resolvedFName] = packId
    if namespacedId then M.reverse[resolvedFName] = namespacedId end
    M.byPack[packId] = M.byPack[packId] or {}
    if not existing then table.insert(M.byPack[packId], resolvedFName) end
    return true
end

-- Scan a pack's authored content ids from disk. Returns a set-like table
-- { resolvedFName -> "packid:Name"|resolvedFName }. Sources:
--   items/*.jsonc top-level keys, buildings/*.jsonc top-level keys.
-- ALL top-level content keys are collected (not just "<id>_"-prefixed), so a
-- pack that ships another pack's row key (e.g. "example_Potion") is caught as a
-- collision at load time. Keys prefixed with the pack's own id get a friendly
-- "packid:Name" display form; foreign-prefixed keys map to the raw FName.
-- `provides` (if present) is authoritative; a scan mismatch is a warning.
function M.collect(manifest)
    local out, warnings = {}, {}
    local packId = manifest.id
    local prefix = packId .. "_"

    local function scanFolder(sub)
        local dir = manifest.dir .. sub .. "\\"
        -- list files (not dirs) via `dir /b`
        local ok = pcall(function()
            local p = io.popen('dir "' .. dir .. '" /b 2>nul')
            if not p then return end
            for line in p:lines() do
                line = line:gsub("[\r\n]", "")
                if line:match("%.jsonc?$") then
                    local text = core.readFile(dir .. line)
                    local data = text and json.decode(text)
                    if type(data) == "table" then
                        for key in pairs(data) do
                            if type(key) == "string" and key:sub(1, 1) ~= "$" and key:find("_") then
                                if key:sub(1, #prefix) == prefix then
                                    out[key] = packId .. ":" .. key:sub(#prefix + 1)
                                else
                                    out[key] = key -- foreign-prefixed: collision candidate
                                end
                            end
                        end
                    end
                end
            end
            p:close()
        end)
        if not ok then table.insert(warnings, "scan failed: " .. sub) end
    end

    scanFolder("items")
    scanFolder("buildings")

    -- provides overrides / augments
    if manifest.provides then
        local declared = {}
        for _, nsId in ipairs(manifest.provides) do
            local ns, name = nsId:match("^([^:]+):(.+)$")
            if ns == packId and name then
                local fname = ns .. "_" .. name
                declared[fname] = nsId
                if not out[fname] then
                    table.insert(warnings, "provides '" .. nsId .. "' not found in items/ or buildings/")
                end
            end
        end
        for fname in pairs(out) do
            if not declared[fname] then
                table.insert(warnings, "content '" .. fname .. "' found but not listed in provides")
            end
        end
        return declared, warnings
    end

    return out, warnings
end

-- Snapshot for persistence: { packId -> { resolvedFName, ... } }.
function M.snapshot()
    local snap = {}
    for pack, ids in pairs(M.byPack) do
        snap[pack] = {}
        for _, id in ipairs(ids) do table.insert(snap[pack], id) end
    end
    return snap
end

return M
