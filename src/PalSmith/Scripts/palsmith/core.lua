-- PalSmith core: logging, file helpers, tiny utilities.
local M = {}

M.VERSION = "0.2.0"
-- Highest pack.jsonc formatVersion this runtime understands. A pack declaring a
-- higher formatVersion is treated as incompatible (parser gate, distinct from
-- the requiresSmith feature gate).
M.MANIFEST_FORMAT = 2

function M.log(msg)  print("[PalSmith] " .. tostring(msg) .. "\n") end
function M.warn(msg) print("[PalSmith][warn] " .. tostring(msg) .. "\n") end
function M.err(msg)  print("[PalSmith][ERROR] " .. tostring(msg) .. "\n") end

-- Directory of the running script (with trailing separator).
function M.scriptDir()
    local src = debug.getinfo(2, "S").source
    return src:match("@?(.*[\\/])") or ""
end

function M.readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

function M.exists(path)
    local f = io.open(path, "rb")
    if f then f:close(); return true end
    return false
end

-- Ensure a Windows directory exists (mkdir -p equivalent). Same idiom already
-- used in modmanager.toggle. Returns true on success (or if it already exists).
function M.ensureDir(dir)
    local ok = pcall(function()
        os.execute('if not exist "' .. dir .. '" mkdir "' .. dir .. '" 2>nul')
    end)
    return ok and M.exists(dir)
end

-- Atomic-ish write: write to <path>.tmp then rename over <path> so a crash mid-
-- write can't leave a truncated file. Returns ok, err.
function M.writeFile(path, text)
    local tmp = path .. ".tmp"
    local f, oerr = io.open(tmp, "wb")
    if not f then return false, "open failed: " .. tostring(oerr) end
    local ok, werr = pcall(function()
        f:write(text)
        f:close()
    end)
    if not ok then pcall(function() f:close() end); return false, "write failed: " .. tostring(werr) end
    -- Windows os.rename fails if the destination exists; remove it first.
    os.remove(path)
    local rok, rerr = os.rename(tmp, path)
    if not rok then
        -- fall back to a direct write if rename is unavailable
        local f2 = io.open(path, "wb")
        if not f2 then return false, "rename failed: " .. tostring(rerr) end
        f2:write(text); f2:close()
        os.remove(tmp)
    end
    return true
end

-- List subdirectory names of `path` (Windows). Returns {} on failure.
function M.listDirs(path)
    local out = {}
    local ok = pcall(function()
        local p = io.popen('dir "' .. path .. '" /b /ad 2>nul')
        if not p then return end
        for line in p:lines() do
            line = line:gsub("[\r\n]", "")
            if #line > 0 then table.insert(out, line) end
        end
        p:close()
    end)
    if not ok then M.warn("listDirs failed for " .. path) end
    return out
end

-- Shallow merge b into a (b wins), returns a.
function M.merge(a, b)
    for k, v in pairs(b or {}) do a[k] = v end
    return a
end

-- "{id}" style template substitution.
function M.template(text, vars)
    return (tostring(text):gsub("{(%w+)}", function(k)
        local v = vars[k]
        return v ~= nil and tostring(v) or ("{" .. k .. "}")
    end))
end

return M
