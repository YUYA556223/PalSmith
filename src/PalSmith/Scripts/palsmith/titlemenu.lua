-- PalSmith title-menu integration: inject a native-looking entry into Palworld's
-- title screen that opens the Mod Manager. Structure and click path verified in
-- V7 (2026-07-17). This makes PalSmith a genuine menu-extension platform: other
-- code can register additional entries via M.addEntry.
--
-- Title layout (from V7a):
--   PalUITitleBase.WidgetTree.RootWidget -> ... -> VerticalBox_0 (button column)
--   each entry: SizeBox_N -> WBP_Title_MenuButton (Test_Content label + CommonUI button)
local core = require("palsmith.core")

local M = {}

local BTN_CLASS = "/Game/Pal/Blueprint/UI/UserInterface/Title/WBP_Title_MenuButton.WBP_Title_MenuButton_C"

local entries = {}   -- { label=, onClick=, invButton= }  registered menu entries
local injected = false
local clickHooked = false

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

local function installClickHook()
    if clickHooked then return end
    local ok = pcall(function()
        RegisterHook("/Script/CommonUI.CommonButtonBase:HandleButtonClicked", function(self)
            local clicked
            local ok2 = pcall(function() clicked = self:get():GetFullName() end)
            if not ok2 then return end
            for _, e in ipairs(entries) do
                if e.invButton and e.invButton:IsValid() then
                    local okn, name = pcall(function() return e.invButton:GetFullName() end)
                    if okn and name == clicked then
                        local oke, err = pcall(e.onClick)
                        if not oke then core.err("title entry onClick: " .. tostring(err)) end
                        return
                    end
                end
            end
        end)
    end)
    clickHooked = ok
    core.log(ok and "title: click hook installed" or "title: click hook FAILED")
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

    -- match native entries: wrap in a SizeBox and copy a sibling's slot
    local sibling = findByName(root, "SizeBox_4")
    local sizeBox = StaticConstructObject(StaticFindObject("/Script/UMG.SizeBox"), vbox)
    if sibling and sibling:IsValid() then
        pcall(function() sizeBox:SetWidthOverride(sibling:GetWidthOverride()) end)
        pcall(function() sizeBox:SetHeightOverride(sibling:GetHeightOverride()) end)
    end
    pcall(function() sizeBox:SetContent(btn) end)

    local slot = vbox:AddChildToVerticalBox(sizeBox)
    pcall(function()
        local ss = sibling.Slot
        slot:SetPadding(ss.Padding)
        slot:SetHorizontalAlignment(ss.HorizontalAlignment)
        slot:SetVerticalAlignment(ss.VerticalAlignment)
    end)
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
    installClickHook()
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
