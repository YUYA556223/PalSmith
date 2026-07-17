-- PalSmith V7a probe : dump the title-menu widget hierarchy to a file so we can
-- learn how to inject a native-looking entry. No keybind - polls on a timer and
-- writes once when the title UI is found. Output:
--   ue4ss/Mods/PalSmithTitleProbe/title_dump.txt
local OUT = [[title_dump.txt]] -- resolved relative to CWD (Win64); see write()

local function log(m) print("[SmithV7] " .. tostring(m) .. "\n") end

local done = false

local function widgetClass(w)
    local ok, c = pcall(function() return w:GetClass():GetFullName() end)
    return ok and tostring(c) or "?"
end

local function widgetName(w)
    local ok, n = pcall(function() return w:GetName() end)
    if ok and n then return tostring(n) end
    ok, n = pcall(function() return w:GetFName():ToString() end)
    if ok and n then return tostring(n) end
    -- last segment of full name
    local full = ""
    pcall(function() full = w:GetFullName() end)
    return full:match("[%.:]([%w_]+)$") or full or "?"
end

-- Recursively describe a widget subtree. Uses GetChildrenCount/GetChildAt on
-- PanelWidget; TextBlock/Button are leaves we tag specially.
local function describe(lines, w, depth)
    if not (w and w:IsValid()) or depth > 14 then return end
    local indent = string.rep("  ", depth)
    local cls = widgetClass(w)
    local name = widgetName(w)
    local tag = ""
    if cls:find("Button") then tag = "  <BUTTON>"
    elseif cls:find("TextBlock") or cls:find("Text") then
        tag = "  <TEXT>"
        pcall(function() tag = tag .. ' "' .. w:GetText():ToString() .. '"' end)
    elseif cls:find("VerticalBox") or cls:find("HorizontalBox") or cls:find("Panel")
        or cls:find("ListView") or cls:find("ScrollBox") then tag = "  <CONTAINER>"
    elseif cls:find("WBP_") or cls:find("UserWidget") then tag = "  <USERWIDGET>" end
    table.insert(lines, string.format("%s%s : %s%s", indent, name, cls, tag))

    -- 1) if this is a UserWidget, descend into its own WidgetTree
    local isPanel = false
    pcall(function() isPanel = w:GetChildrenCount() ~= nil end)
    pcall(function()
        local tree = w.WidgetTree
        if tree and tree:IsValid() then
            local root = tree.RootWidget
            if root and root:IsValid() then
                table.insert(lines, indent .. "  [WidgetTree]")
                describe(lines, root, depth + 2)
            end
        end
    end)

    -- 2) panel children
    local n = 0
    pcall(function() n = w:GetChildrenCount() end)
    for i = 0, (n or 0) - 1 do
        local child
        local ok = pcall(function() child = w:GetChildAt(i) end)
        if ok and child then describe(lines, child, depth + 1) end
    end
    -- 3) Border/single-content
    if (n or 0) == 0 then
        pcall(function()
            local c = w:GetContent()
            if c and c:IsValid() then describe(lines, c, depth + 1) end
        end)
    end
end

local function dump(titleWidget)
    local lines = { "=== PalSmith title-menu dump ===" }
    table.insert(lines, "root: " .. widgetClass(titleWidget))
    -- WidgetTree.RootWidget is the visual root
    local root
    pcall(function() root = titleWidget.WidgetTree.RootWidget end)
    if root and root:IsValid() then
        describe(lines, root, 0)
    else
        table.insert(lines, "(no WidgetTree.RootWidget; dumping widget directly)")
        describe(lines, titleWidget, 0)
    end
    local body = table.concat(lines, "\n")
    log(body)
    local f = io.open(OUT, "w")
    if f then f:write(body); f:close(); log("wrote " .. OUT) else log("could not open " .. OUT) end
end

LoopAsync(2000, function()
    if done then return true end
    ExecuteInGameThread(function()
        if done then return end
        local t = FindFirstOf("PalUITitleBase")
        if t and t:IsValid() then
            done = true
            log("found PalUITitleBase: " .. widgetClass(t))
            pcall(dump, t)
        end
    end)
    return false
end)

log("V7a title probe ready (waiting for title screen)")
