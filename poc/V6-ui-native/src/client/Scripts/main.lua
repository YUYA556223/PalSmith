-- PalSmith V6 probe : build and show a UMG panel entirely from Lua (no cooked
-- WidgetBlueprint, no UE5). Press F7 in-world. Staged logging like V5.
--
-- Approach: StaticConstructObject the native UMG classes (UserWidget, VerticalBox,
-- TextBlock), wire WidgetTree.RootWidget by reflection (UE4SS can touch protected
-- UPROPs), then AddToViewport. If this works, PalSmith UI never needs Unreal.

local function log(msg) print("[SmithV6] " .. tostring(msg) .. "\n") end

local widget = nil

local function stage(name, fn)
    local ok, res = pcall(fn)
    log((ok and "OK   " or "FAIL ") .. name .. (ok and "" or (" -> " .. tostring(res))))
    return ok and (res == nil and true or res) or nil
end

-- Construct a UObject of the given class path, owned by `outer`.
local function construct(classPath, outer)
    local cls = StaticFindObject(classPath)
    assert(cls and cls:IsValid(), "class not found: " .. classPath)
    local obj = StaticConstructObject(cls, outer)
    assert(obj and obj:IsValid(), "construct failed: " .. classPath)
    return obj
end

local function buildUI()
    log("=== F7: building Lua-native UMG ===")

    local pc = stage("STAGE1 player controller", function()
        local p = FindFirstOf("PalPlayerController")
        assert(p and p:IsValid(), "no PalPlayerController")
        return p
    end)
    if not pc then return end

    local w = stage("STAGE2 construct UUserWidget", function()
        -- CreateWidget-style: WidgetBlueprintLibrary.Create needs a class asset;
        -- instead construct a bare UserWidget and populate its tree ourselves.
        local uw = construct("/Script/UMG.UserWidget", pc)
        -- some engine builds need Rename into the transient package + an owning PC
        pcall(function() uw:SetPlayerContext(pc) end)
        return uw
    end)
    if not w then return end

    local root = stage("STAGE3 widget tree + root VerticalBox", function()
        local tree = w.WidgetTree
        assert(tree and tree:IsValid(), "WidgetTree not accessible")
        local vbox = construct("/Script/UMG.VerticalBox", tree)
        tree.RootWidget = vbox
        return vbox
    end)
    if not root then return end

    stage("STAGE4 add TextBlock children", function()
        local tree = w.WidgetTree
        for i, text in ipairs({ "PalSmith UI test", "Row A", "Row B" }) do
            local tb = construct("/Script/UMG.TextBlock", tree)
            tb:SetText(FText(text))
            root:AddChildToVerticalBox(tb)
        end
    end)

    stage("STAGE5 AddToViewport", function()
        w:AddToViewport(1000)
    end)

    widget = w
    log("=== done (look for text on screen; F7 again to rebuild) ===")
end

RegisterKeyBind(Key.F7, function()
    ExecuteInGameThread(function()
        if widget and widget:IsValid() then
            pcall(function() widget:RemoveFromParent() end)
            widget = nil
            log("closed")
        else
            local ok, err = pcall(buildUI)
            if not ok then log("buildUI error: " .. tostring(err)) end
        end
    end)
end)

log("V6 probe ready: press F7 in-world to build a Lua-native UMG panel")
