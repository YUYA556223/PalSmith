-- PalSmith Mod Manager: list installed mods and toggle them enabled/disabled.
-- Changes apply on the next game start (UE4SS/PalSchema load mods at startup).
--
-- Two mod kinds:
--   UE4SS Lua mods   -> <Win64>/ue4ss/Mods/<Name>/ , toggled by enabled.txt
--   PalSchema packs  -> <Win64>/ue4ss/Mods/PalSchema/mods/<Name>/ , toggled by
--                       moving to/from a sibling "mods_disabled" folder
--
-- The UI is number-key driven (1..9 toggle the Nth row) - no clickable buttons,
-- which keeps it fully Lua-constructed (see ui.lua).
local core = require("palsmith.core")
local ui   = require("palsmith.ui")

local M = {}

-- Resolve the ue4ss/Mods dir from this script's location:
-- <Mods>/PalSmith/Scripts/palsmith/ -> up 3 -> <Mods>
local function modsDir()
    local here = debug.getinfo(1, "S").source:match("@?(.*[\\/])") or ""
    return here .. "..\\..\\..\\"
end

-- Windows helpers via shell (io.popen), pcall-guarded.
local function sh(cmd)
    local ok, res = pcall(function()
        local p = io.popen(cmd .. " 2>nul")
        if not p then return "" end
        local out = p:read("*a"); p:close()
        return out or ""
    end)
    return ok and res or ""
end

local function listDirs(path)
    local out = {}
    for line in sh('dir "' .. path .. '" /b /ad'):gmatch("[^\r\n]+") do
        if #line > 0 then table.insert(out, line) end
    end
    return out
end

local function fileExists(path)
    local f = io.open(path, "rb")
    if f then f:close(); return true end
    return false
end

-- Build the mod inventory. Returns an array of { kind, name, enabled, path }.
function M.scan()
    local base = modsDir()
    local mods = {}

    -- UE4SS Lua mods: any folder with a Scripts/ dir (skip our own framework bits
    -- and PalSchema itself, which is managed as a dependency, not user content).
    local skip = { PalSmith = true, PalSchema = true, shared = true, BPModLoaderMod = true,
                   Keybinds = true }
    for _, name in ipairs(listDirs(base)) do
        if not skip[name] and fileExists(base .. name .. "\\Scripts\\main.lua") then
            local enabled = fileExists(base .. name .. "\\enabled.txt")
            table.insert(mods, { kind = "lua", name = name, enabled = enabled,
                                 path = base .. name })
        end
    end

    -- PalSchema packs
    local psActive = base .. "PalSchema\\mods\\"
    local psDisabled = base .. "PalSchema\\mods_disabled\\"
    for _, name in ipairs(listDirs(psActive)) do
        table.insert(mods, { kind = "pack", name = name, enabled = true,
                             path = psActive .. name })
    end
    for _, name in ipairs(listDirs(psDisabled)) do
        table.insert(mods, { kind = "pack", name = name, enabled = false,
                             path = psDisabled .. name })
    end

    table.sort(mods, function(a, b)
        if a.kind ~= b.kind then return a.kind < b.kind end
        return a.name < b.name
    end)
    return mods
end

-- Toggle one mod. Returns true, newState or false, error.
function M.toggle(mod)
    local base = modsDir()
    if mod.kind == "lua" then
        local flag = mod.path .. "\\enabled.txt"
        if mod.enabled then
            sh('del /q "' .. flag .. '"')
            return true, false
        else
            sh('type nul > "' .. flag .. '"')
            return true, true
        end
    elseif mod.kind == "pack" then
        local active = base .. "PalSchema\\mods\\" .. mod.name
        local disabled = base .. "PalSchema\\mods_disabled\\" .. mod.name
        sh('if not exist "' .. base .. 'PalSchema\\mods_disabled" mkdir "' .. base .. 'PalSchema\\mods_disabled"')
        if mod.enabled then
            sh('move /y "' .. active .. '" "' .. disabled .. '"')
            return true, false
        else
            sh('move /y "' .. disabled .. '" "' .. active .. '"')
            return true, true
        end
    end
    return false, "unknown kind"
end

-- ---- UI ----
local panel = nil
local current = {} -- displayed mods, index-aligned with number keys

local function render()
    if not (panel and panel:isValid()) then return end
    panel:clear()
    panel:addText("PalSmith Mod Manager", 22, { 1.0, 0.85, 0.4, 1.0 })
    panel:addText("Press 1-9 to toggle. Changes apply after restart.", 12, { 0.6, 0.65, 0.75, 1.0 })
    current = M.scan()
    for i, mod in ipairs(current) do
        local num = i <= 9 and tostring(i) or "-"
        local state = mod.enabled and "[ON ]" or "[off]"
        local color = mod.enabled and { 0.5, 0.9, 0.5, 1.0 } or { 0.6, 0.6, 0.65, 1.0 }
        panel:addRow({
            { text = num .. ".", size = 15, color = { 0.7, 0.75, 0.85, 1.0 } },
            { text = state, size = 15, color = color },
            { text = mod.name, size = 15, color = { 0.9, 0.9, 0.95, 1.0 } },
            { text = "(" .. mod.kind .. ")", size = 12, color = { 0.5, 0.55, 0.65, 1.0 } },
        })
    end
    if #current == 0 then
        panel:addText("(no toggleable mods found)", 14, { 0.7, 0.5, 0.5, 1.0 })
    end
end

function M.isOpen() return panel ~= nil and panel:isValid() end

function M.open()
    local p, err = ui.newPanel()
    if not p then core.err("mod manager: " .. tostring(err)); return end
    panel = p
    render()
    panel:show()
    core.log("mod manager opened")
end

function M.close()
    if panel then panel:close(); panel = nil end
end

function M.toggleWindow()
    if M.isOpen() then M.close() else M.open() end
end

-- Called by number keys 1..9 while the window is open.
function M.activate(index)
    if not M.isOpen() then return end
    local mod = current[index]
    if not mod then return end
    local ok, res = M.toggle(mod)
    if ok then
        core.log(string.format("toggled %s '%s' -> %s", mod.kind, mod.name, res and "ON" or "off"))
        render() -- re-scan reflects the change immediately
    else
        core.err("toggle failed: " .. tostring(res))
    end
end

return M
