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

-- Find an owner/outer for the widget. Works both in-world and on the title
-- screen (where there is no PalPlayerCharacter but usually a PlayerController).
local function findOwner()
    for _, cls in ipairs({ "PalPlayerController", "PlayerController" }) do
        local pc = FindFirstOf(cls)
        if pc and pc:IsValid() then return pc, cls end
    end
    -- last resort: the game instance (valid on the title screen), used only as
    -- the construction Outer; AddToViewport still targets the game viewport.
    local gi = FindFirstOf("GameInstance")
    if gi and gi:IsValid() then return gi, "GameInstance" end
    return nil, nil
end

function M.newPanel(opts)
    opts = opts or {}
    local owner, ownerKind = findOwner()
    if not owner then return nil, "no owner (PlayerController/GameInstance) found" end
    core.log("ui: owner = " .. tostring(ownerKind))

    local self = setmetatable({ rows = {} }, Panel)
    local ok, err = pcall(function()
        local w = make("/Script/UMG.UserWidget", owner)
        pcall(function() w:SetPlayerContext(owner) end)
        local tree = w.WidgetTree
        if not (tree and tree:IsValid()) then
            tree = make("/Script/UMG.WidgetTree", w)
            w.WidgetTree = tree
        end

        -- Full-screen dim layer -> centered themed panel -> VerticalBox (rows).
        local dim = make("/Script/UMG.Border", tree)
        pcall(function() dim:SetBrushColor(unpackColor({ 0.0, 0.0, 0.0, 0.55 })) end)
        pcall(function() dim:SetPadding({ Left = 0, Top = 0, Right = 0, Bottom = 0 }) end)
        tree.RootWidget = dim

        local panelBorder = make("/Script/UMG.Border", tree)
        -- warm dark brown, Palworld-ish
        pcall(function() panelBorder:SetBrushColor(unpackColor(opts.bg or { 0.13, 0.11, 0.09, 0.97 })) end)
        pcall(function() panelBorder:SetHorizontalAlignment(2) end) -- HAlign_Center
        pcall(function() panelBorder:SetVerticalAlignment(2) end)   -- VAlign_Center
        pcall(function() panelBorder:SetPadding({ Left = 40, Top = 28, Right = 40, Bottom = 28 }) end)
        pcall(function() dim:SetContent(panelBorder) end)

        local vbox = make("/Script/UMG.VerticalBox", tree)
        pcall(function() panelBorder:SetContent(vbox) end)

        -- make the whole widget receive mouse input (Visible, not hit-invisible)
        pcall(function() w:SetVisibility(0) end) -- ESlateVisibility::Visible

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
