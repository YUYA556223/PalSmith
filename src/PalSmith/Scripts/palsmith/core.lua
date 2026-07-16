-- PalSmith core: logging, file helpers, tiny utilities.
local M = {}

M.VERSION = "0.1.0"

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
