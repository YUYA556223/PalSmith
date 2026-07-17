-- PalSmith entity menu: a Lua-native UMG panel bound to a placed entity, showing
-- its itemHandler contents (and state summary). Reuses nativeui + clicks and the
-- findOwner() PlayerController pattern from modmanager. Slice scope = read-only
-- display + Refresh/Close, single active panel keyed by instance.key.
local core = require("palsmith.core")
local nui  = require("palsmith.nativeui")

local M = {}

local COL = {
    accent = { 0.98, 0.80, 0.38, 1 }, cream = { 0.96, 0.93, 0.86, 1 },
    muted  = { 0.72, 0.68, 0.60, 1 }, key = { 0.85, 0.72, 0.50, 1 },
}

local panel = nil  -- { widget, tree, listV, pc, instanceKey }

local function findOwner()
    for _, c in ipairs({ "PalPlayerController", "PlayerController" }) do
        local pc = FindFirstOf(c); if pc and pc:IsValid() then return pc end
    end
    local gi = FindFirstOf("GameInstance"); if gi and gi:IsValid() then return gi end
    return nil
end

local function renderList(inst)
    if not panel then return end
    pcall(function() panel.listV:ClearChildren() end)
    local ih = inst:getComponent("itemHandler")
    if not ih then
        nui.addV(panel.listV, nui.text(panel.tree, "(no inventory)", 14, COL.muted), 2)
        return
    end
    local list = ih:list()
    if #list == 0 then
        nui.addV(panel.listV, nui.text(panel.tree, "(empty)", 14, COL.muted), 2)
    end
    for _, e in ipairs(list) do
        local row = nui.hbox(panel.tree)
        local ksize = nui.sizeBox(panel.tree, 220, nil)
        pcall(function() ksize:SetContent(nui.text(panel.tree, e.id, 15, COL.cream)) end)
        nui.addH(row, ksize)
        nui.addH(row, nui.text(panel.tree, "x " .. tostring(e.count), 15, COL.accent))
        nui.addV(panel.listV, row, 2)
    end
end

function M.open(inst, opts)
    if not inst then return end
    -- toggle if already open for this instance
    if panel and panel.widget and panel.widget:IsValid() then
        M.close()
        if panel and panel.instanceKey == inst.key then return end
    end

    local pc = findOwner()
    if not pc then core.err("entityui: no owner"); return end

    local built = {}
    local ok, err = pcall(function()
        local w = nui.construct("/Script/UMG.UserWidget", pc)
        pcall(function() w:SetPlayerContext(pc) end)
        local tree = w.WidgetTree
        if not (tree and tree:IsValid()) then
            tree = nui.construct("/Script/UMG.WidgetTree", w); w.WidgetTree = tree
        end
        pcall(function() w:SetVisibility(0) end)

        local dim = nui.border(tree, { 0.02, 0.02, 0.03, 0.72 })
        tree.RootWidget = dim
        local pnl = nui.border(tree, { 0.11, 0.10, 0.08, 0.98 })
        pcall(function() pnl:SetHorizontalAlignment(2) end)
        pcall(function() pnl:SetVerticalAlignment(2) end)
        pcall(function() pnl:SetPadding({ Left = 36, Top = 26, Right = 36, Bottom = 26 }) end)
        pcall(function() dim:SetContent(pnl) end)

        local rootV = nui.vbox(tree); pcall(function() pnl:SetContent(rootV) end)
        nui.addV(rootV, nui.text(tree, inst.def.displayName or inst.id, 24, COL.accent), 2)
        nui.addV(rootV, nui.text(tree, "@ " .. inst.key, 11, COL.muted), 2)

        local size = nui.sizeBox(tree, 520, 420)
        local scroll = nui.scrollBox(tree); pcall(function() size:SetContent(scroll) end)
        local listV = nui.vbox(tree); nui.addScroll(scroll, listV)
        nui.addV(rootV, size, 10)

        built = { widget = w, tree = tree, listV = listV, pc = pc, instanceKey = inst.key }
        panel = built

        local refresh = nui.clickableRow(tree, pc, "\u{21BB}  Refresh", function()
            local live = require("palsmith.entity").instanceAt(inst.key)
            if live then renderList(live) end
        end, { size = 17, color = COL.cream })
        if refresh then nui.addV(rootV, refresh, 12) end
        local closeBtn = nui.clickableRow(tree, pc, "\u{2716}  Close", function() M.close() end,
            { size = 17, color = COL.muted })
        if closeBtn then nui.addV(rootV, closeBtn, 2) end
    end)
    if not ok then core.err("entityui build: " .. tostring(err)); panel = nil; return end

    renderList(inst)
    pcall(function() panel.widget:AddToViewport(1000) end)
    core.log("entity menu opened: " .. inst.key)
end

function M.close()
    if panel and panel.widget then pcall(function() panel.widget:RemoveFromParent() end) end
    panel = nil
end

return M
