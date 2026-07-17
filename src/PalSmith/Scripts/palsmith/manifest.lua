-- PalSmith manifest loader: read + normalize + validate one pack.jsonc into a
-- canonical v2 manifest. All legacy-format handling lives here so the rest of the
-- runtime only ever sees the normalized shape.
--
-- Normalized manifest shape:
--   { id, name, version, versionParsed, requiresSmith(range string),
--     depends={ns->range}, recommends={...}, conflicts={...}, breaks={...},
--     provides={"ns:Name",...}|nil, authors={...}, homepage, formatVersion,
--     dir, folderName, warnings={...} }
local core   = require("palsmith.core")
local json   = require("palsmith.json")
local semver = require("palsmith.semver")

local M = {}

local ID_PAT = "^[%w_]+$"

local function isMap(t) return type(t) == "table" and not (t[1] ~= nil) end

-- Normalize a dependency table: accepts { ns = "range", ... }. Returns map, err.
local function normDepMap(v, field, selfId, warnings)
    local out = {}
    if v == nil then return out end
    if type(v) ~= "table" or not isMap(v) then
        return nil, field .. " must be an object of packId -> version-range"
    end
    for ns, range in pairs(v) do
        if type(ns) ~= "string" or not ns:match(ID_PAT) then
            return nil, field .. " has invalid pack id '" .. tostring(ns) .. "'"
        end
        if ns == selfId then
            return nil, field .. " refers to the pack's own id '" .. ns .. "'"
        end
        if type(range) ~= "string" then range = "*" end
        if not semver.parseRange(range) then
            table.insert(warnings, field .. "." .. ns .. ": unparseable range '" .. tostring(range) .. "', treating as '*'")
            range = "*"
        end
        out[ns] = range
    end
    return out
end

-- Load and normalize `<dir>/palsmith/pack.jsonc`. Returns manifest, err.
-- err ~= nil means the pack can't participate (malformed); manifest.warnings
-- carries non-fatal issues.
function M.load(dir, folderName)
    local path = dir .. "palsmith\\pack.jsonc"
    local text = core.readFile(path)
    if not text then return nil end -- no palsmith/ -> not our pack (caller skips silently)

    local raw, jerr = json.decode(text)
    if raw == nil then
        return nil, "pack.jsonc: " .. tostring(jerr or "empty")
    end
    if type(raw) ~= "table" then return nil, "pack.jsonc: top-level must be an object" end

    local warnings = {}

    -- id (required)
    if type(raw.id) ~= "string" or not raw.id:match(ID_PAT) then
        return nil, "pack.jsonc: 'id' is required (letters/digits/_ only)"
    end
    local id = raw.id

    -- formatVersion (parser gate)
    local fmt = raw.formatVersion
    if fmt ~= nil and (type(fmt) ~= "number" or fmt % 1 ~= 0 or fmt < 1) then
        return nil, "pack.jsonc: 'formatVersion' must be a positive integer"
    end
    fmt = fmt or 1

    -- version
    local version = raw.version or "0.0.0"
    if not semver.parse(version) then
        table.insert(warnings, "version '" .. tostring(version) .. "' is not semver; treating as 0.0.0")
        version = "0.0.0"
    end

    -- requiresSmith (range; legacy plain "0.1" is already a valid min-range)
    local requiresSmith = raw.requiresSmith or "*"
    if type(requiresSmith) ~= "string" or not semver.parseRange(requiresSmith) then
        table.insert(warnings, "requiresSmith '" .. tostring(raw.requiresSmith) .. "' unparseable; treating as '*'")
        requiresSmith = "*"
    end

    -- dependency maps
    local depends, e1 = normDepMap(raw.depends, "depends", id, warnings)
    if not depends then return nil, "pack.jsonc: " .. e1 end
    local recommends, e2 = normDepMap(raw.recommends, "recommends", id, warnings)
    if not recommends then return nil, "pack.jsonc: " .. e2 end
    local conflicts, e3 = normDepMap(raw.conflicts, "conflicts", id, warnings)
    if not conflicts then return nil, "pack.jsonc: " .. e3 end
    local breaks, e4 = normDepMap(raw.breaks, "breaks", id, warnings)
    if not breaks then return nil, "pack.jsonc: " .. e4 end

    -- legacy `dependencies: ["a","b"]` -> fold into depends (depends wins)
    if raw.dependencies ~= nil then
        if type(raw.dependencies) ~= "table" then
            return nil, "pack.jsonc: legacy 'dependencies' must be an array"
        end
        if next(depends) ~= nil then
            table.insert(warnings, "both legacy 'dependencies' and 'depends' present; using 'depends'")
        else
            for _, ns in ipairs(raw.dependencies) do
                if type(ns) == "string" and ns:match(ID_PAT) and ns ~= id then
                    depends[ns] = "*"
                end
            end
            table.insert(warnings, "legacy 'dependencies' array used; migrate to 'depends' (map of id -> range)")
        end
    end

    -- provides (optional)
    local provides = nil
    if raw.provides ~= nil then
        if type(raw.provides) ~= "table" then
            return nil, "pack.jsonc: 'provides' must be an array of 'ns:Name' ids"
        end
        provides = {}
        for _, p in ipairs(raw.provides) do
            if type(p) == "string" then table.insert(provides, p) end
        end
    end

    return {
        id = id,
        name = raw.name or folderName,
        version = version,
        versionParsed = semver.parse(version),
        requiresSmith = requiresSmith,
        depends = depends,
        recommends = recommends,
        conflicts = conflicts,
        breaks = breaks,
        provides = provides,
        authors = raw.authors,
        homepage = raw.homepage,
        formatVersion = fmt,
        dir = dir,
        folderName = folderName,
        warnings = warnings,
    }
end

return M
