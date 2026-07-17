-- PalSmith extension loader. UE4SS gives every Lua mod its OWN Lua state, and
-- shared variables can't carry functions/tables — so a companion mod can't call
-- PalSmith's API across the VM boundary. Instead, PalSmith loads trusted
-- extension scripts INTO ITS OWN VM (the KubeJS model): they run with _G.PalSmith
-- and the palsmith.* modules directly available, and register into the same
-- registry that the ticker/events use.
--
-- Extensions live under <Mods>/PalSmith/extensions/. Each top-level .lua file, or
-- each subfolder's init.lua, is dofile'd once. This is a deliberate, trusted
-- location (the user installs extensions here) — arbitrary PalSchema data packs
-- still cannot ship Lua.
local core = require("palsmith.core")

local M = {}

-- List *.lua files directly under a dir (Windows dir /b), plus <sub>/init.lua.
local function listLua(dir)
    local files = {}
    local ok = pcall(function()
        local p = io.popen('dir "' .. dir .. '" /b 2>nul')
        if not p then return end
        for line in p:lines() do
            line = line:gsub("[\r\n]", "")
            if line:match("%.lua$") then
                table.insert(files, dir .. line)
            elseif line ~= "" and not line:match("%.") then
                -- possible subfolder with an init.lua
                local init = dir .. line .. "\\init.lua"
                if core.exists(init) then table.insert(files, init) end
            end
        end
        p:close()
    end)
    if not ok then core.warn("extloader: listing failed for " .. dir) end
    return files
end

-- Load every extension. `scriptsDir` = .../Mods/PalSmith/Scripts (so extensions
-- resolve to .../Mods/PalSmith/extensions). Adds the extensions dir to
-- package.path so an extension can `require` its own sibling modules.
function M.loadAll(scriptsDir)
    local extDir = scriptsDir .. "..\\extensions\\"
    package.path = extDir .. "?.lua;" .. extDir .. "?\\init.lua;" .. package.path
    local files = listLua(extDir)
    if #files == 0 then core.log("extloader: no extensions in " .. extDir); return end
    local n = 0
    for _, path in ipairs(files) do
        local chunk, lerr = loadfile(path)
        if not chunk then
            core.err("extension load error (" .. path .. "): " .. tostring(lerr))
        else
            local ok, rerr = pcall(chunk)
            if ok then n = n + 1; core.log("extension loaded: " .. path)
            else core.err("extension run error (" .. path .. "): " .. tostring(rerr)) end
        end
    end
    core.log(string.format("extloader: %d extension(s) loaded", n))
end

return M
