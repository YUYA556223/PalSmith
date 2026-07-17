-- PalSmith persistence store: simple JSON key/value files under the PalSmith Mods
-- dir. Used now for the id snapshot (F8 uninstall safety net); the per-world /
-- per-player KV store for cooldowns/currency is a later phase (needs a verified
-- world/player key).
--
-- Each key is its own file: <Mods>/PalSmith/state/<key>.json
local core = require("palsmith.core")
local json = require("palsmith.json")

local M = {}

-- Base dir resolved from this module's path: .../Mods/PalSmith/Scripts/palsmith/
-- -> up 2 -> .../Mods/PalSmith/ , then /state/.
local function stateDir()
    local here = debug.getinfo(1, "S").source:match("@?(.*[\\/])") or ""
    return here .. "..\\..\\state\\"
end

local cache = {}

local function pathFor(key)
    return stateDir() .. key .. ".json"
end

-- Read a key -> value (decoded), or nil.
function M.get(key)
    if cache[key] ~= nil then return cache[key] end
    local text = core.readFile(pathFor(key))
    if not text then return nil end
    local v = json.decode(text)
    cache[key] = v
    return v
end

-- Set a key in memory (call flush() or use setAndFlush to persist).
function M.set(key, value)
    cache[key] = value
end

function M.flush(key)
    local dir = stateDir()
    core.ensureDir(dir)
    local keys = key and { key } or {}
    if not key then for k in pairs(cache) do table.insert(keys, k) end end
    local okAll = true
    for _, k in ipairs(keys) do
        local text, eerr = json.encode(cache[k])
        if not text then
            core.warn("store: encode failed for '" .. k .. "': " .. tostring(eerr)); okAll = false
        else
            local ok, werr = core.writeFile(pathFor(k), text)
            if not ok then core.warn("store: write failed for '" .. k .. "': " .. tostring(werr)); okAll = false end
        end
    end
    return okAll
end

function M.setAndFlush(key, value)
    M.set(key, value)
    return M.flush(key)
end

return M
