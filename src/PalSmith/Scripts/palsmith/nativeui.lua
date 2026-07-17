-- PalSmith native UI kit
-- =======================
-- Build in-game UI from Palworld's OWN widgets + native UMG, entirely in Lua
-- (no cooked WidgetBlueprints, no Unreal Engine). This module is meant to be a
-- reusable toolkit: other PalSmith code (and other mods, via require) can create
-- native-looking menus without knowing the widget-construction details.
--
-- Two families of helpers:
--   * native UMG primitives  - vbox/hbox/scrollBox/border/sizeBox/text
--   * Palworld game widgets   - menuButton (clones the title button), and the
--                               generic cloneGameWidget() for any BP widget path
--
-- Discovered game UI asset paths are collected in M.PATHS so users have one place
-- to look. Add more as you find them (dump the title/HUD trees with a probe).
local core   = require("palsmith.core")
local clicks = require("palsmith.clicks")

local M = {}

-- Known Palworld UI asset/class paths (verified 2026-07-17 from the title menu).
M.PATHS = {
    menuButton      = "/Game/Pal/Blueprint/UI/UserInterface/Title/WBP_Title_MenuButton.WBP_Title_MenuButton_C",
    palTextBlock    = "/Game/Pal/Blueprint/UI/PalTextBlock/BP_PalTextBlock.BP_PalTextBlock_C",
    invisibleButton = "/Game/Pal/Blueprint/UI/System/Style/WBP_PalInvisibleButton.WBP_PalInvisibleButton_C",
    -- names of widgets INSIDE WBP_Title_MenuButton (used to set label / catch click)
    menuButtonLabel = "Test_Content",
    menuButtonClick = "WBP_PalInvisibleButton",
    menuButtonInner = "HorizontalBox_0",
}

-- Slate alignment enums, named so callers don't memorize integers.
M.HALIGN = { FILL = 0, LEFT = 1, CENTER = 2, RIGHT = 3 }
M.VALIGN = { FILL = 0, TOP = 1, CENTER = 2, BOTTOM = 3 }
M.SIZE   = { AUTO = 0, FILL = 1 }

-- ---- low-level construction ----
local function classOf(path)
    local c = StaticFindObject(path)
    if not (c and c:IsValid()) then error("class not found: " .. path) end
    return c
end

-- Construct a native/engine object (e.g. "/Script/UMG.VerticalBox").
function M.construct(path, outer)
    local o = StaticConstructObject(classOf(path), outer)
    if not (o and o:IsValid()) then error("construct failed: " .. path) end
    return o
end

-- Instantiate a Blueprint widget by class path via WidgetBlueprintLibrary (this
-- initializes the widget's own WidgetTree, unlike StaticConstructObject). Use for
-- any WBP_/BP_ widget from the game.
function M.create(pc, classPath)
    local lib = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    local cls = StaticFindObject(classPath)
    if not (lib and lib:IsValid() and cls and cls:IsValid() and pc and pc:IsValid()) then
        return nil, "create prerequisites missing for " .. tostring(classPath)
    end
    local w = lib:Create(pc, cls, pc)
    if not (w and w:IsValid()) then return nil, "Create failed for " .. tostring(classPath) end
    return w
end

function M.widgetName(w)
    local ok, n = pcall(function() return w:GetFName():ToString() end)
    if ok and n and #n > 0 then return tostring(n) end
    local full = ""
    pcall(function() full = w:GetFullName() end)
    return full:match("[%.:]([%w_]+)$") or full or "?"
end

-- Depth-first search for a descendant widget by name (descends nested UserWidgets,
-- panel children, and single-content widgets). Returns the widget or nil.
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
M.color = color

-- ---- native UMG primitives (outer = the WidgetTree that owns the panel) ----
function M.vbox(tree) return M.construct("/Script/UMG.VerticalBox", tree) end
function M.hbox(tree) return M.construct("/Script/UMG.HorizontalBox", tree) end
function M.scrollBox(tree) return M.construct("/Script/UMG.ScrollBox", tree) end
function M.overlay(tree) return M.construct("/Script/UMG.Overlay", tree) end

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
    pcall(function() local f = t.Font; f.Size = size or 16; t.Font = f end)
    return t
end

-- ---- Palworld game widgets ----
local dumpedButton = false

-- Reach into a freshly created WBP_Title_MenuButton and force its inner content
-- to the left, so labels align regardless of the button's outer width. Also logs
-- the inner slot once for diagnosis.
local function leftAlignButtonContent(btn)
    local inner = M.findByName(btn, M.PATHS.menuButtonInner)
    if not (inner and inner:IsValid()) then return end
    if not dumpedButton then
        dumpedButton = true
        local ok, info = pcall(function()
            local slot = inner.Slot
            return slot and slot:GetClass():GetFullName() or "no-slot"
        end)
        core.log("BTNDIAG inner slot = " .. (ok and tostring(info) or "?"))
    end
    -- If the inner content sits in a CanvasPanelSlot, anchor it to the left.
    pcall(function()
        local slot = inner.Slot
        slot:SetAnchors({ Minimum = { X = 0.0, Y = 0.5 }, Maximum = { X = 0.0, Y = 0.5 } })
        slot:SetAlignment({ X = 0.0, Y = 0.5 })
    end)
end

-- Clone the game's title menu button as a clickable row. Returns (button, invBtn).
-- `onClick` is routed through the shared click router (clicks.lua).
function M.menuButton(tree, pc, label, onClick)
    local btn, err = M.create(pc, M.PATHS.menuButton)
    if not btn then return nil, err end
    local lbl = M.findByName(btn, M.PATHS.menuButtonLabel)
    if lbl and lbl:IsValid() then pcall(function() lbl:SetText(FText(label)) end) end
    leftAlignButtonContent(btn)
    local inv = M.findByName(btn, M.PATHS.menuButtonClick)
    if inv and onClick then clicks.register(inv, onClick) end
    return btn, inv
end

-- A clickable, LEFT-ALIGNED row that still looks native. The menu button provides
-- the native frame + hover + click, but its own label is blanked and a TextBlock
-- we control is overlaid on top (left-aligned). The text is hit-test invisible so
-- clicks pass through to the button beneath. Returns (rowWidget, invBtn).
function M.clickableRow(tree, pc, label, onClick, opts)
    opts = opts or {}
    local overlay = M.overlay(tree)
    -- native button underneath (blank its centered label)
    local btn, inv = M.menuButton(tree, pc, "", onClick)
    if btn then
        local bs = overlay:AddChildToOverlay(btn)
        pcall(function() bs:SetHorizontalAlignment(M.HALIGN.FILL) end)
        pcall(function() bs:SetVerticalAlignment(M.VALIGN.FILL) end)
    end
    -- our left-aligned label on top. ESlateVisibility: Visible=0 Collapsed=1
    -- Hidden=2 HitTestInvisible=3 SelfHitTestInvisible=4. Use 3 so the text
    -- shows but clicks pass through to the button beneath.
    local t = M.text(tree, label, opts.size or 18, opts.color)
    pcall(function() t:SetVisibility(3) end) -- HitTestInvisible
    local ts = overlay:AddChildToOverlay(t)
    pcall(function() ts:SetHorizontalAlignment(M.HALIGN.LEFT) end)
    pcall(function() ts:SetVerticalAlignment(M.VALIGN.CENTER) end)
    pcall(function() ts:SetPadding({ Left = opts.indent or 28, Top = 0, Right = 12, Bottom = 0 }) end)
    return overlay, inv
end

-- Generic: clone any Palworld BP widget, optionally set a label child's text and
-- wire a click. `opts = { label=, labelChild=, clickChild=, onClick= }`.
function M.cloneGameWidget(tree, pc, classPath, opts)
    opts = opts or {}
    local w, err = M.create(pc, classPath)
    if not w then return nil, err end
    if opts.label and opts.labelChild then
        local lbl = M.findByName(w, opts.labelChild)
        if lbl and lbl:IsValid() then pcall(function() lbl:SetText(FText(opts.label)) end) end
    end
    if opts.onClick and opts.clickChild then
        local c = M.findByName(w, opts.clickChild)
        if c then clicks.register(c, opts.onClick) end
    end
    return w
end

-- ---- slot helpers (return the created slot for further tweaking) ----
local dumpedSlot = false

-- Set a VerticalBoxSlot's horizontal alignment robustly: try the setter AND
-- direct property assignment (UE4SS enum-byte setters sometimes no-op), then read
-- it back once so we can see which stuck.
local function setVAlign(slot, halign)
    pcall(function() slot:SetHorizontalAlignment(halign) end)
    pcall(function() slot.HorizontalAlignment = halign end)
    if not dumpedSlot then
        dumpedSlot = true
        local ok, v = pcall(function() return slot.HorizontalAlignment end)
        core.log("SLOTDIAG after set HAlign -> " .. (ok and tostring(v) or "?"))
    end
end

function M.addV(vbox, child, padTop)
    local slot = vbox:AddChildToVerticalBox(child)
    pcall(function() slot:SetPadding({ Left = 0, Top = padTop or 2, Right = 0, Bottom = padTop or 2 }) end)
    pcall(function() slot.Padding = { Left = 0, Top = padTop or 2, Right = 0, Bottom = padTop or 2 } end)
    setVAlign(slot, M.HALIGN.LEFT)
    return slot
end

function M.addH(hbox, child) return hbox:AddChildToHorizontalBox(child) end
function M.addScroll(scroll, child) return scroll:AddChild(child) end

return M
