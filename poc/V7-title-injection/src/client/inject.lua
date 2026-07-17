-- PalSmith V7b probe : inject a native-looking "PalSmith" entry into the title
-- menu by cloning the game's own WBP_Title_MenuButton, then wire its click.
--
-- Navigation uses the tree-walk primitives proven in V7a (GetChildrenCount/
-- GetChildAt/GetContent + nested WidgetTree descent). GetWidgetFromName is NOT
-- callable on these objects (UE4SS returns a TrivialObject), so we search by name.

local BTN_CLASS = "/Game/Pal/Blueprint/UI/UserInterface/Title/WBP_Title_MenuButton.WBP_Title_MenuButton_C"

local function log(m) print("[SmithV7b] " .. tostring(m) .. "\n") end

local injected = false
local ourInvisibleButton = nil
local clickHooked = false

local function widgetName(w)
    local ok, n = pcall(function() return w:GetFName():ToString() end)
    if ok and n and #n > 0 then return tostring(n) end
    local full = ""
    pcall(function() full = w:GetFullName() end)
    return full:match("[%.:]([%w_]+)$") or full or "?"
end

-- Depth-first search for a descendant whose name matches `name`. Descends panel
-- children, single-content widgets, and nested UserWidget WidgetTrees.
local function findByName(w, name, depth)
    if not (w and w:IsValid()) or (depth or 0) > 14 then return nil end
    if widgetName(w) == name then return w end

    -- nested UserWidget tree
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
        if content and content:IsValid() then
            return findByName(content, name, (depth or 0) + 1)
        end
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

local function onClickPalSmith()
    log("PalSmith entry clicked! (runtime will open the Mod Manager here)")
end

local function hookClicks()
    if clickHooked then return end
    local ok = pcall(function()
        RegisterHook("/Script/CommonUI.CommonButtonBase:HandleButtonClicked", function(self)
            if not ourInvisibleButton then return end
            local ok2, ours = pcall(function()
                return self:get():GetFullName() == ourInvisibleButton:GetFullName()
            end)
            if ok2 and ours then onClickPalSmith() end
        end)
    end)
    clickHooked = ok
    log(ok and "click hook installed" or "click hook FAILED")
end

local function inject()
    if injected then return end
    local root = titleRoot()
    if not root then return end -- title not up yet

    local ok, err = pcall(function()
        local vbox = findByName(root, "VerticalBox_0")
        assert(vbox and vbox:IsValid(), "VerticalBox_0 not found")

        local lib = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
        assert(lib and lib:IsValid(), "WidgetBlueprintLibrary not found")
        local btnClass = StaticFindObject(BTN_CLASS)
        assert(btnClass and btnClass:IsValid(), "button class not loaded")
        local pc = FindFirstOf("PalPlayerController")
        assert(pc and pc:IsValid(), "no PlayerController")

        local btn = lib:Create(pc, btnClass, pc)
        assert(btn and btn:IsValid(), "button Create failed")

        local label = findByName(btn, "Test_Content")
        if label and label:IsValid() then
            pcall(function() label:SetText(FText("PalSmith")) end)
            log("label set on Test_Content")
        else
            log("WARN: Test_Content not found on new button")
        end

        ourInvisibleButton = findByName(btn, "WBP_PalInvisibleButton")
        log("invisible button captured: " .. tostring(ourInvisibleButton ~= nil))

        -- Existing entries are wrapped: VerticalBox_0 -> SizeBox_N -> button.
        -- Replicate that so alignment/width match the native items.
        local sibling = findByName(root, "SizeBox_4") -- the "Option" wrapper
        local sizeBox = StaticConstructObject(StaticFindObject("/Script/UMG.SizeBox"), vbox)
        if sibling and sibling:IsValid() then
            pcall(function() sizeBox:SetWidthOverride(sibling:GetWidthOverride()) end)
            pcall(function() sizeBox:SetHeightOverride(sibling:GetHeightOverride()) end)
        end
        pcall(function() sizeBox:SetContent(btn) end)

        local slot = vbox:AddChildToVerticalBox(sizeBox)
        -- copy the sibling's vertical-box slot (padding + alignment)
        pcall(function()
            local ss = sibling.Slot
            slot:SetPadding(ss.Padding)
            slot:SetHorizontalAlignment(ss.HorizontalAlignment)
            slot:SetVerticalAlignment(ss.VerticalAlignment)
        end)
        injected = true
        log("injected PalSmith button (SizeBox-wrapped) into VerticalBox_0")
    end)
    if not ok then log("inject error: " .. tostring(err)) end
end

hookClicks()
LoopAsync(2000, function()
    if injected then return true end
    ExecuteInGameThread(function() pcall(inject) end)
    return false
end)

log("V7b inject probe ready (waiting for title menu)")
