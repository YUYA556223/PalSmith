-- PalSmith title-menu integration: inject a native-looking entry into Palworld's
-- title screen that opens the Mod Manager. Structure and click path verified in
-- V7 (2026-07-17). This makes PalSmith a genuine menu-extension platform: other
-- code can register additional entries via M.addEntry.
--
-- Title layout (from V7a):
--   PalUITitleBase.WidgetTree.RootWidget -> ... -> VerticalBox_0 (button column)
--   each entry: SizeBox_N -> WBP_Title_MenuButton (Test_Content label + CommonUI button)
local core   = require("palsmith.core")
local clicks = require("palsmith.clicks")

local M = {}

local BTN_CLASS = "/Game/Pal/Blueprint/UI/UserInterface/Title/WBP_Title_MenuButton.WBP_Title_MenuButton_C"

local entries = {}   -- { label=, onClick=, invButton= }  registered menu entries
local injected = false

local function widgetName(w)
    local ok, n = pcall(function() return w:GetFName():ToString() end)
    if ok and n and #n > 0 then return tostring(n) end
    local full = ""
    pcall(function() full = w:GetFullName() end)
    return full:match("[%.:]([%w_]+)$") or full or "?"
end

local function findByName(w, name, depth)
    if not (w and w:IsValid()) or (depth or 0) > 14 then return nil end
    if widgetName(w) == name then return w end
    local found
    pcall(function()
        local tree = w.WidgetTree
        if tree and tree:IsValid() then
            local root = tree.RootWidget
            if root and root:IsValid() then found = findByName(root, name, (depth or 0) + 2) end
        end
    end)
    if found then return found end
    local n = 0
    pcall(function() n = w:GetChildrenCount() end)
    for i = 0, (n or 0) - 1 do
        local child
        pcall(function() child = w:GetChildAt(i) end)
        if child then
            local r = findByName(child, name, (depth or 0) + 1)
            if r then return r end
        end
    end
    if (n or 0) == 0 then
        local content
        pcall(function() content = w:GetContent() end)
        if content and content:IsValid() then return findByName(content, name, (depth or 0) + 1) end
    end
    return nil
end

local function titleRoot()
    local base = FindFirstOf("PalUITitleBase")
    if not (base and base:IsValid()) then return nil end
    local root
    pcall(function() root = base.WidgetTree.RootWidget end)
    return root
end

-- Public: register a menu entry. Safe to call before the title screen exists.
function M.addEntry(label, onClick)
    table.insert(entries, { label = label, onClick = onClick })
    injected = false -- force (re)injection so new entries appear
end

-- One-time diagnostic: dump a native SizeBox + its VerticalBox slot values so we
-- can match alignment exactly. Logged once.
local dumped = false
local function dumpAlignment(root)
    if dumped then return end
    local sb = M and nil
    local sib = require("palsmith.nativeui").findByName(root, "SizeBox_4")
    if not (sib and sib:IsValid()) then return end
    dumped = true
    local function num(fn) local ok, v = pcall(fn); return ok and tostring(v) or "?" end
    core.log("ALIGN SizeBox_4 width=" .. num(function() return sib:GetWidthOverride() end)
        .. " height=" .. num(function() return sib:GetHeightOverride() end))
    pcall(function()
        local s = sib.Slot
        core.log("ALIGN slot HAlign=" .. num(function() return s.HorizontalAlignment end)
            .. " VAlign=" .. num(function() return s.VerticalAlignment end)
            .. " pad L=" .. num(function() return s.Padding.Left end)
            .. " T=" .. num(function() return s.Padding.Top end)
            .. " R=" .. num(function() return s.Padding.Right end)
            .. " B=" .. num(function() return s.Padding.Bottom end))
    end)
    -- also the VerticalBox_0 slot HAlign of a native entry's parent, if different
end

local function injectEntry(root, vbox, e)
    local lib = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    local btnClass = StaticFindObject(BTN_CLASS)
    local pc = FindFirstOf("PalPlayerController")
    if not (lib and btnClass and pc) then return false end

    local btn = lib:Create(pc, btnClass, pc)
    if not (btn and btn:IsValid()) then return false end

    local label = findByName(btn, "Test_Content")
    if label and label:IsValid() then pcall(function() label:SetText(FText(e.label)) end) end
    e.invButton = findByName(btn, "WBP_PalInvisibleButton")
    if e.invButton then clicks.register(e.invButton, e.onClick) end

    -- Match native entries: wrap in a SizeBox with the sibling's dimensions, and
    -- clone the sibling's VerticalBox slot (padding + alignment). The sibling is
    -- an existing SizeBox_N that is a direct child of VerticalBox_0.
    local sibling = findByName(root, "SizeBox_4")
    dumpAlignment(root)
    local sizeBox = StaticConstructObject(StaticFindObject("/Script/UMG.SizeBox"), vbox)
    local w, h
    if sibling and sibling:IsValid() then
        pcall(function() w = sibling:GetWidthOverride() end)
        pcall(function() h = sibling:GetHeightOverride() end)
    end
    if w and w > 0 then pcall(function() sizeBox:SetWidthOverride(w) end) end
    if h and h > 0 then pcall(function() sizeBox:SetHeightOverride(h) end) end
    pcall(function() sizeBox:SetContent(btn) end)

    local slot = vbox:AddChildToVerticalBox(sizeBox)
    -- Set alignment via BOTH setter and direct property assignment (UE4SS enum
    -- setters can silently no-op, leaving the default HAlign_Fill which centers).
    pcall(function() slot:SetHorizontalAlignment(1) end)          -- HAlign_Left
    pcall(function() slot.HorizontalAlignment = 1 end)
    pcall(function() slot:SetPadding({ Left = 0, Top = 3, Right = 0, Bottom = 3 }) end)
    pcall(function() slot.Padding = { Left = 0, Top = 3, Right = 0, Bottom = 3 } end)
    local readback = "?"
    pcall(function() readback = tostring(slot.HorizontalAlignment) end)
    core.log("title entry '" .. e.label .. "' injected (HAlign readback=" .. readback .. ")")
    return true
end

local function tryInject()
    if injected or #entries == 0 then return end
    local root = titleRoot()
    if not root then return end
    local vbox = findByName(root, "VerticalBox_0")
    if not (vbox and vbox:IsValid()) then return end

    local n = 0
    for _, e in ipairs(entries) do
        if not e.invButton then
            local ok = pcall(injectEntry, root, vbox, e)
            if ok then n = n + 1 end
        end
    end
    injected = true
    core.log("title: injected " .. n .. " entry(ies)")
end

-- Start watching for the title screen. Re-checks so entries survive menu rebuilds.
function M.start()
    clicks.install()
    local ok = pcall(function()
        LoopAsync(2000, function()
            ExecuteInGameThread(function()
                -- re-inject if the title exists but our buttons went away
                if injected then
                    local anyAlive = false
                    for _, e in ipairs(entries) do
                        if e.invButton and e.invButton:IsValid() then anyAlive = true break end
                    end
                    if not anyAlive and titleRoot() then injected = false end
                end
                pcall(tryInject)
            end)
            return false
        end)
    end)
    if not ok then core.warn("title: watcher unavailable (LoopAsync)") end
end

return M
