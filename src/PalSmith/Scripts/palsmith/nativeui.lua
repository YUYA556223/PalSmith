-- PalSmith native UI kit: build panels from Palworld's own widgets + native UMG.
-- Reuses the game's menu button (WBP_Title_MenuButton) for clickable rows so
-- everything looks native. Text uses native UMG TextBlock (styleable). Scrolling
-- uses native UMG ScrollBox (two independent ones for a master/detail layout).
local core   = require("palsmith.core")
local clicks = require("palsmith.clicks")

local M = {}

local BTN_CLASS = "/Game/Pal/Blueprint/UI/UserInterface/Title/WBP_Title_MenuButton.WBP_Title_MenuButton_C"

-- ---- low-level construction ----
local function classOf(path)
    local c = StaticFindObject(path)
    if not (c and c:IsValid()) then error("class not found: " .. path) end
    return c
end

function M.construct(path, outer)
    local o = StaticConstructObject(classOf(path), outer)
    if not (o and o:IsValid()) then error("construct failed: " .. path) end
    return o
end

function M.widgetName(w)
    local ok, n = pcall(function() return w:GetFName():ToString() end)
    if ok and n and #n > 0 then return tostring(n) end
    local full = ""
    pcall(function() full = w:GetFullName() end)
    return full:match("[%.:]([%w_]+)$") or full or "?"
end

-- Depth-first search for a descendant widget by name (handles nested UserWidgets).
function M.findByName(w, name, depth)
    if not (w and w:IsValid()) or (depth or 0) > 14 then return nil end
    if M.widgetName(w) == name then return w end
    local found
    pcall(function()
        local tree = w.WidgetTree
        if tree and tree:IsValid() then
            local root = tree.RootWidget
            if root and root:IsValid() then found = M.findByName(root, name, (depth or 0) + 2) end
        end
    end)
    if found then return found end
    local n = 0
    pcall(function() n = w:GetChildrenCount() end)
    for i = 0, (n or 0) - 1 do
        local child
        pcall(function() child = w:GetChildAt(i) end)
        if child then
            local r = M.findByName(child, name, (depth or 0) + 1)
            if r then return r end
        end
    end
    if (n or 0) == 0 then
        local content
        pcall(function() content = w:GetContent() end)
        if content and content:IsValid() then return M.findByName(content, name, (depth or 0) + 1) end
    end
    return nil
end

local function color(c) return { R = c[1], G = c[2], B = c[3], A = c[4] or 1.0 } end

-- ---- widget factories (outer = the WidgetTree that owns the panel) ----
function M.vbox(tree) return M.construct("/Script/UMG.VerticalBox", tree) end
function M.hbox(tree) return M.construct("/Script/UMG.HorizontalBox", tree) end
function M.scrollBox(tree) return M.construct("/Script/UMG.ScrollBox", tree) end

function M.border(tree, rgba)
    local b = M.construct("/Script/UMG.Border", tree)
    pcall(function() b:SetBrushColor(color(rgba or { 0.13, 0.11, 0.09, 0.97 })) end)
    return b
end

function M.sizeBox(tree, w, h)
    local s = M.construct("/Script/UMG.SizeBox", tree)
    if w then pcall(function() s:SetWidthOverride(w) end) end
    if h then pcall(function() s:SetHeightOverride(h) end) end
    return s
end

function M.text(tree, str, size, rgba)
    local t = M.construct("/Script/UMG.TextBlock", tree)
    pcall(function() t:SetText(FText(tostring(str))) end)
    pcall(function() t:SetColorAndOpacity({ SpecifiedColor = color(rgba or { 0.95, 0.93, 0.86, 1 }), ColorUseRule = 0 }) end)
    pcall(function()
        local f = t.Font; f.Size = size or 16; t.Font = f
    end)
    return t
end

-- Clone the game's title menu button as a clickable row. Returns the button
-- widget; registers `onClick` via the shared click router.
function M.menuButton(tree, pc, label, onClick)
    local lib = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    local btnClass = StaticFindObject(BTN_CLASS)
    if not (lib and lib:IsValid() and btnClass and btnClass:IsValid() and pc) then
        return nil, "menu button prerequisites missing"
    end
    local btn = lib:Create(pc, btnClass, pc)
    if not (btn and btn:IsValid()) then return nil, "Create failed" end
    local lbl = M.findByName(btn, "Test_Content")
    if lbl and lbl:IsValid() then pcall(function() lbl:SetText(FText(label)) end) end
    local inv = M.findByName(btn, "WBP_PalInvisibleButton")
    if inv then clicks.register(inv, onClick) end
    return btn, inv
end

-- ---- slot helpers ----
function M.addV(vbox, child, padTop)
    local slot = vbox:AddChildToVerticalBox(child)
    pcall(function() slot:SetPadding({ Left = 0, Top = padTop or 2, Right = 0, Bottom = padTop or 2 }) end)
    pcall(function() slot:SetHorizontalAlignment(1) end) -- HAlign_Left
    return slot
end

function M.addH(hbox, child)
    return hbox:AddChildToHorizontalBox(child)
end

function M.addScroll(scroll, child)
    return scroll:AddChild(child)
end

return M
