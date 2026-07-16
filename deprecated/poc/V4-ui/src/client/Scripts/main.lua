-- PalSmith V4 probe : load a cooked WidgetBlueprint from a mod pak, open it as
-- an in-game menu, and receive button clicks in Lua. Press F11 to toggle.
-- Requires PalSmithUI_P.pak (see ../../README.md Part B) in Pal/Content/Paks/~mods.
-- All logs are prefixed [SmithV4].

local WIDGET_CLASS_PATH = "/Game/Mods/PalSmithUI/WBP_SmithMenu.WBP_SmithMenu_C"

local function log(msg) print("[SmithV4] " .. tostring(msg) .. "\n") end

local menu = nil          -- current widget instance (nil = closed)
local clickHooked = false

local function stage(name, fn)
    local ok, res = pcall(fn)
    log((ok and "OK   " or "FAIL ") .. name .. (ok and "" or (" -> " .. tostring(res))))
    return ok and (res == nil and true or res) or nil
end

local function hookClicks()
    if clickHooked then return end
    -- BP function paths become hookable once the class is loaded.
    local ok, err = pcall(function()
        RegisterHook(WIDGET_CLASS_PATH:gsub("%.WBP_SmithMenu_C$", ".WBP_SmithMenu_C:EntryClicked"),
            function(self, EntryId)
                local okId, id = pcall(function() return EntryId:get():ToString() end)
                log("CLICKED id=" .. (okId and tostring(id) or "<unreadable>"))
            end)
    end)
    clickHooked = ok
    log((ok and "hooked" or ("hook failed -> " .. tostring(err))) .. ": EntryClicked")
end

local function openMenu()
    log("=== F11: opening menu ===")

    local widgetClass = stage("STAGE1 LoadAsset widget class", function()
        local c = LoadAsset(WIDGET_CLASS_PATH)
        assert(c and c:IsValid(), "LoadAsset returned invalid (is PalSmithUI_P.pak in ~mods?)")
        return c
    end)
    if not widgetClass then return end

    local pc = stage("STAGE2 find player controller", function()
        local p = FindFirstOf("PalPlayerController")
        assert(p and p:IsValid(), "no PalPlayerController")
        return p
    end)
    if not pc then return end

    local widget = stage("STAGE3 WidgetBlueprintLibrary.Create", function()
        local lib = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
        assert(lib and lib:IsValid(), "WidgetBlueprintLibrary not found")
        local w = lib:Create(pc, widgetClass, pc)
        assert(w and w:IsValid(), "Create returned invalid widget")
        return w
    end)
    if not widget then return end

    stage("STAGE4 AddToViewport + SetTitle", function()
        widget:AddToViewport(100)
        widget:SetTitle(FText("PalSmith V4"))
    end)

    hookClicks()
    menu = widget
    log("=== menu open (click Entry A/B/C, F11 to close) ===")
end

local function closeMenu()
    stage("close menu", function()
        menu:RemoveFromParent()
    end)
    menu = nil
end

RegisterKeyBind(Key.F11, function()
    ExecuteInGameThread(function()
        local ok, err = pcall(function()
            if menu and menu:IsValid() then closeMenu() else openMenu() end
        end)
        if not ok then log("toggle error: " .. tostring(err)) end
    end)
end)

log("V4 probe ready: put PalSmithUI_P.pak in ~mods, then press F11 in-world")
