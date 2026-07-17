-- PalSmith UI toolkit: build UMG panels from Lua at runtime (no cooked widgets,
-- no Unreal Engine). Verified pattern from V6 (2026-07-17).
--
-- A bare UUserWidget has no WidgetTree, so we construct one and assign it before
-- populating. All construction happens on the game thread (callers use
-- ExecuteInGameThread). Every builder pcall-guards and logs on failure.
local core = require("palsmith.core")

local M = {}

-- {r,g,b,a} array -> FLinearColor-shaped table.
local function unpackColor(c)
    return { R = c[1], G = c[2], B = c[3], A = c[4] or 1.0 }
end

local function cls(path)
    local c = StaticFindObject(path)
    if not (c and c:IsValid()) then error("class not found: " .. path) end
    return c
end

local function make(path, outer)
    local o = StaticConstructObject(cls(path), outer)
    if not (o and o:IsValid()) then error("construct failed: " .. path) end
    return o
end

-- A Panel wraps a UUserWidget + its root VerticalBox and offers helpers to add
-- rows. It is the unit callers keep a handle to (for close/rebuild).
local Panel = {}
Panel.__index = Panel

function M.newPanel(opts)
    opts = opts or {}
    local pc = FindFirstOf("PalPlayerController")
    if not (pc and pc:IsValid()) then return nil, "no PalPlayerController" end

    local self = setmetatable({ rows = {} }, Panel)
    local ok, err = pcall(function()
        local w = make("/Script/UMG.UserWidget", pc)
        pcall(function() w:SetPlayerContext(pc) end)
        local tree = w.WidgetTree
        if not (tree and tree:IsValid()) then
            tree = make("/Script/UMG.WidgetTree", w)
            w.WidgetTree = tree
        end

        -- Border (background) -> VerticalBox (rows)
        local border = make("/Script/UMG.Border", tree)
        pcall(function()
            border:SetBrushColor(unpackColor(opts.bg or { 0.03, 0.03, 0.06, 0.92 }))
        end)
        local vbox = make("/Script/UMG.VerticalBox", tree)
        pcall(function() border:SetContent(vbox) end)
        tree.RootWidget = border

        self.widget = w
        self.tree = tree
        self.vbox = vbox
    end)
    if not ok then return nil, err end
    return self
end

local function styleText(tb, size, color)
    pcall(function() tb:SetColorAndOpacity({ SpecifiedColor = unpackColor(color), ColorUseRule = 0 }) end)
    pcall(function()
        local font = tb.Font
        font.Size = size
        tb.Font = font
    end)
end

-- Add a text row; returns the TextBlock so callers can mutate it later.
function Panel:addText(text, size, color)
    local tb
    local ok, err = pcall(function()
        tb = make("/Script/UMG.TextBlock", self.tree)
        tb:SetText(FText(tostring(text)))
        styleText(tb, size or 16, color or { 0.9, 0.9, 0.95, 1.0 })
        self.vbox:AddChildToVerticalBox(tb)
    end)
    if not ok then core.warn("ui addText: " .. tostring(err)); return nil end
    table.insert(self.rows, tb)
    return tb
end

-- Add a horizontal row of text cells (label + state). Returns the HorizontalBox.
-- v0.1 has no real buttons (click wiring from Lua is fiddly); toggling is driven
-- by number keys mapped to visible rows instead.
function Panel:addRow(cells)
    local hbox
    local ok, err = pcall(function()
        hbox = make("/Script/UMG.HorizontalBox", self.tree)
        for _, cell in ipairs(cells) do
            local tb = make("/Script/UMG.TextBlock", self.tree)
            tb:SetText(FText(tostring(cell.text)))
            styleText(tb, cell.size or 15, cell.color or { 0.9, 0.9, 0.95, 1.0 })
            local slot = hbox:AddChildToHorizontalBox(tb)
            pcall(function() slot:SetPadding({ Left = 0, Top = 2, Right = 24, Bottom = 2 }) end)
        end
        self.vbox:AddChildToVerticalBox(hbox)
    end)
    if not ok then core.warn("ui addRow: " .. tostring(err)); return nil end
    table.insert(self.rows, hbox)
    return hbox
end

function Panel:clear()
    pcall(function() self.vbox:ClearChildren() end)
    self.rows = {}
end

function Panel:show()
    pcall(function() self.widget:AddToViewport(1000) end)
end

function Panel:close()
    pcall(function() self.widget:RemoveFromParent() end)
end

function Panel:isValid()
    return self.widget and self.widget:IsValid()
end

return M
