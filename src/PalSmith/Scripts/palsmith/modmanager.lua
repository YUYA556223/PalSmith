-- PalSmith Mod Manager: two-pane UI built from the game's own widgets.
--   left  = independently scrollable, clickable mod list (native menu buttons)
--   right = independently scrollable metadata for the selected mod
-- Toggling a mod enables/disables it (applies on next game start).
--
-- Mod kinds:
--   lua  -> ue4ss/Mods/<Name>/ , enabled.txt present/absent
--   pack -> ue4ss/Mods/PalSchema/mods/<Name>/ vs .../mods_disabled/<Name>/
local core   = require("palsmith.core")
local json   = require("palsmith.json")
local nui    = require("palsmith.nativeui")

local M = {}

-- ---- filesystem ----
local function modsDir()
    local here = debug.getinfo(1, "S").source:match("@?(.*[\\/])") or ""
    return here .. "..\\..\\..\\"
end

local function sh(cmd)
    local ok, res = pcall(function()
        local p = io.popen(cmd .. " 2>nul"); if not p then return "" end
        local out = p:read("*a"); p:close(); return out or ""
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
    local f = io.open(path, "rb"); if f then f:close(); return true end; return false
end

local function readJsonc(path)
    local text = core.readFile(path); if not text then return nil end
    local v = json.decode(text); return v
end

function M.scan()
    local base = modsDir()
    local mods = {}
    local skip = { PalSmith = true, PalSchema = true, shared = true, BPModLoaderMod = true, Keybinds = true }
    for _, name in ipairs(listDirs(base)) do
        if not skip[name] and fileExists(base .. name .. "\\Scripts\\main.lua") then
            table.insert(mods, { kind = "lua", name = name,
                enabled = fileExists(base .. name .. "\\enabled.txt"), path = base .. name })
        end
    end
    local psA = base .. "PalSchema\\mods\\"
    local psD = base .. "PalSchema\\mods_disabled\\"
    for _, name in ipairs(listDirs(psA)) do
        table.insert(mods, { kind = "pack", name = name, enabled = true, path = psA .. name })
    end
    for _, name in ipairs(listDirs(psD)) do
        table.insert(mods, { kind = "pack", name = name, enabled = false, path = psD .. name })
    end
    table.sort(mods, function(a, b)
        if a.kind ~= b.kind then return a.kind < b.kind end
        return a.name < b.name
    end)
    return mods
end

-- Metadata for the detail pane. Packs read palsmith/pack.jsonc + counts.
local function metaLines(mod)
    local lines = {}
    local function add(k, v) if v ~= nil and v ~= "" then table.insert(lines, { k = k, v = tostring(v) }) end end
    add("Name", mod.name)
    add("Type", mod.kind == "pack" and "PalSchema content pack" or "UE4SS Lua mod")
    add("Status", mod.enabled and "Enabled" or "Disabled")
    if mod.kind == "pack" then
        local m = readJsonc(mod.path .. "\\palsmith\\pack.jsonc")
        if m then
            add("Pack id", m.id)
            add("Version", m.version)
            add("Requires PalSmith", m.requiresSmith)
            if type(m.authors) == "table" then add("Authors", table.concat(m.authors, ", ")) end
            add("Homepage", m.homepage)
        else
            add("PalSmith pack", "no (plain PalSchema data)")
        end
        local beh = readJsonc(mod.path .. "\\palsmith\\behaviors.jsonc")
        if type(beh) == "table" then
            local n = 0; for k in pairs(beh) do if k:sub(1, 1) ~= "$" then n = n + 1 end end
            add("Behaviors", n)
        end
        local msh = readJsonc(mod.path .. "\\palsmith\\meshes.jsonc")
        if type(msh) == "table" then
            local n = 0; for k in pairs(msh) do if k:sub(1, 1) ~= "$" then n = n + 1 end end
            add("Runtime meshes", n)
        end
    end
    add("Folder", mod.path)
    return lines
end

function M.toggle(mod)
    local base = modsDir()
    if mod.kind == "lua" then
        local flag = mod.path .. "\\enabled.txt"
        if mod.enabled then sh('del /q "' .. flag .. '"'); return true, false
        else sh('type nul > "' .. flag .. '"'); return true, true end
    elseif mod.kind == "pack" then
        local active = base .. "PalSchema\\mods\\" .. mod.name
        local disabled = base .. "PalSchema\\mods_disabled\\" .. mod.name
        sh('if not exist "' .. base .. 'PalSchema\\mods_disabled" mkdir "' .. base .. 'PalSchema\\mods_disabled"')
        if mod.enabled then sh('move /y "' .. active .. '" "' .. disabled .. '"'); return true, false
        else sh('move /y "' .. disabled .. '" "' .. active .. '"'); return true, true end
    end
    return false, "unknown kind"
end

-- ---- colours ----
local COL = {
    accent = { 0.98, 0.80, 0.38, 1 }, cream = { 0.96, 0.93, 0.86, 1 },
    muted = { 0.72, 0.68, 0.60, 1 }, on = { 0.55, 0.85, 0.50, 1 },
    off = { 0.80, 0.55, 0.45, 1 }, key = { 0.85, 0.72, 0.50, 1 },
}

-- ---- panel state ----
local panel = nil     -- { widget, tree, leftV, rightV, pc }
local mods = {}
local selected = 1

local function findOwner()
    for _, c in ipairs({ "PalPlayerController", "PlayerController" }) do
        local pc = FindFirstOf(c); if pc and pc:IsValid() then return pc end
    end
    local gi = FindFirstOf("GameInstance"); if gi and gi:IsValid() then return gi end
    return nil
end

local function buildFrame()
    local pc = findOwner()
    if not pc then return nil, "no owner" end
    local w = nui.construct("/Script/UMG.UserWidget", pc)
    pcall(function() w:SetPlayerContext(pc) end)
    local tree = w.WidgetTree
    if not (tree and tree:IsValid()) then
        tree = nui.construct("/Script/UMG.WidgetTree", w); w.WidgetTree = tree
    end
    pcall(function() w:SetVisibility(0) end)

    -- Fullscreen overlay: dim (dark, near-opaque) fills the screen; the panel
    -- fills the dim with margins so it reads as a proper menu, not a small popup.
    local dim = nui.border(tree, { 0.02, 0.02, 0.03, 0.86 })
    tree.RootWidget = dim
    local pnl = nui.border(tree, { 0.10, 0.09, 0.08, 0.98 })
    pcall(function() pnl:SetPadding({ Left = 90, Top = 54, Right = 90, Bottom = 54 }) end)
    pcall(function() dim:SetContent(pnl) end) -- content fills the border -> fullscreen

    local rootV = nui.vbox(tree); pcall(function() pnl:SetContent(rootV) end)
    nui.addV(rootV, nui.text(tree, "PalSmith  \u{2014}  Mod Manager", 30, COL.accent), 2)
    nui.addV(rootV, nui.text(tree, "Click a mod on the left; toggle it on the right. Changes apply after restart.", 14, COL.muted), 2)

    -- Alignment enums: EHorizontalAlignment Fill=0 Left=1 Center=2 Right=3;
    -- EVerticalAlignment Fill=0 Top=1 Center=2 Bottom=3; ESlateSizeRule Fill=1.
    local panes = nui.hbox(tree)
    local paneSlot = nui.addV(rootV, panes, 18)
    pcall(function() paneSlot:SetHorizontalAlignment(0) end)              -- Fill width
    pcall(function() paneSlot:SetSize({ SizeRule = 1, Value = 1.0 }) end) -- Fill vertically

    -- left: scrollable mod list (40% width)
    local leftScroll = nui.scrollBox(tree)
    local leftV = nui.vbox(tree); nui.addScroll(leftScroll, leftV)
    local ls = nui.addH(panes, leftScroll)
    pcall(function() ls:SetSize({ SizeRule = 1, Value = 0.4 }) end)
    pcall(function() ls:SetVerticalAlignment(0) end)                 -- Fill height

    -- right: scrollable detail (60% width)
    local rightScroll = nui.scrollBox(tree)
    local rightV = nui.vbox(tree); nui.addScroll(rightScroll, rightV)
    local rs = nui.addH(panes, rightScroll)
    pcall(function() rs:SetSize({ SizeRule = 1, Value = 0.6 }) end)
    pcall(function() rs:SetVerticalAlignment(0) end)
    pcall(function() rs:SetPadding({ Left = 40, Top = 0, Right = 0, Bottom = 0 }) end)

    return { widget = w, tree = tree, leftV = leftV, rightV = rightV, pc = pc }
end

local function clearBox(vbox)
    pcall(function() vbox:ClearChildren() end)
end

local renderRight -- fwd

local function renderLeft()
    if not panel then return end
    clearBox(panel.leftV)
    for i, mod in ipairs(mods) do
        local mark = mod.enabled and "\u{25CF}  " or "\u{25CB}  " -- filled/hollow dot
        local rowColor = mod.enabled and COL.cream or COL.muted
        local row = nui.clickableRow(panel.tree, panel.pc, mark .. mod.name, function()
            selected = i
            renderRight()
        end, { size = 18, color = rowColor })
        if row then nui.addV(panel.leftV, row, 1) end
    end
    if #mods == 0 then
        nui.addV(panel.leftV, nui.text(panel.tree, "(no mods found)", 14, COL.off), 2)
    end
end

renderRight = function()
    if not panel then return end
    clearBox(panel.rightV)
    local mod = mods[selected]
    if not mod then return end
    nui.addV(panel.rightV, nui.text(panel.tree, mod.name, 22, COL.accent), 2)
    for _, line in ipairs(metaLines(mod)) do
        -- key in a fixed-width SizeBox so the values line up in a column
        local ksize = nui.sizeBox(panel.tree, 170, nil)
        pcall(function() ksize:SetContent(nui.text(panel.tree, line.k, 14, COL.key)) end)
        local row = nui.hbox(panel.tree)
        nui.addH(row, ksize)
        nui.addH(row, nui.text(panel.tree, line.v, 14, COL.cream))
        nui.addV(panel.rightV, row, 2)
    end
    -- toggle button (same left-aligned native row style)
    local label = mod.enabled and "\u{2716}  Disable this mod" or "\u{2714}  Enable this mod"
    local tcolor = mod.enabled and COL.off or COL.on
    local tbtn = nui.clickableRow(panel.tree, panel.pc, label, function()
        local ok = M.toggle(mod)
        if ok then
            mods = M.scan()
            renderLeft(); renderRight()
        end
    end, { size = 19, color = tcolor })
    if tbtn then nui.addV(panel.rightV, tbtn, 14) end
    nui.addV(panel.rightV, nui.text(panel.tree, "(change applies after you restart the game)", 11, COL.muted), 6)
end

function M.isOpen() return panel ~= nil and panel.widget and panel.widget:IsValid() end

function M.open()
    local p, err = buildFrame()
    if not p then core.err("mod manager: " .. tostring(err)); return end
    panel = p
    mods = M.scan()
    selected = math.min(selected, math.max(#mods, 1))
    renderLeft(); renderRight()
    pcall(function() panel.widget:AddToViewport(1000) end)
    core.log("mod manager opened (" .. #mods .. " mods)")
end

function M.close()
    if panel and panel.widget then pcall(function() panel.widget:RemoveFromParent() end) end
    panel = nil
end

function M.toggleWindow()
    if M.isOpen() then M.close() else M.open() end
end

-- kept for the F9 fallback path; number keys are unused in the two-pane UI
function M.activate() end

return M
