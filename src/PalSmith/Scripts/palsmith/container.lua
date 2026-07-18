-- PalSmith native container adapter: a uniform ItemHandler over a placed storage
-- building's UPalItemContainer. This is the "itemHandler" component contract that
-- pipes/warehouses move items through (AE2 Storage-Bus pattern: adapt an external
-- native inventory into the framework via one interface).
--
-- Reads (GetItemStackCount/Num/Get + slot GetItemId().StaticId/GetStackCount) are
-- safe. WRITES go through UPalItemSlot:UpdateItem_ServerInternal, which the
-- knowledge base warns can corrupt saves on the current PalSchema/build pair —
-- gated behind M.WRITES_ENABLED and to be tested only in a throwaway world.
local core = require("palsmith.core")

local M = {}

M.WRITES_ENABLED = false  -- flip on only in a throwaway world (Task: container writes)

-- weak actor -> UPalItemContainer cache
local containerCache = setmetatable({}, { __mode = "k" })

-- Resolve the UPalItemContainer for a placed chest/storage actor.
-- Confirmed path (Pal.hpp CXXHeaderDump + in-game CONTDIAG):
--   actor:GetModel()                       -> UPalMapObjectModel
--        :GetConcreteModel(true)           -> UPalMapObjectItemChestModel  (bIsForce arg REQUIRED)
--        :GetItemContainerModule()         -> UPalMapObjectItemContainerModule
--        :GetContainer()                   -> UPalItemContainer
-- The concrete model itself has no GetItemContainer(); the container lives on the
-- item-container MODULE (also reachable via .TargetContainer / TryGetContainer()).
-- Fallbacks kept for other storage model shapes.
local function concreteModel(actor)
    local ok, m = pcall(function() return actor:GetModel():GetConcreteModel(true) end)
    if ok and m and m:IsValid() then return m end
    return nil
end

local function resolveContainer(actor)
    if containerCache[actor] then return containerCache[actor] end
    local found = nil
    local tries = {
        -- primary: concrete model -> item-container module -> container
        function() return concreteModel(actor):GetItemContainerModule():GetContainer() end,
        -- property fallback on the module
        function() return concreteModel(actor):GetItemContainerModule().TargetContainer end,
        -- access-interface fallback
        function() return concreteModel(actor):GetItemContainerAccess():GetItemContainer() end,
    }
    for _, fn in ipairs(tries) do
        local ok, c = pcall(fn)
        if ok and c and c.IsValid and c:IsValid() then found = c; break end
    end
    if found then containerCache[actor] = found end
    return found
end

-- Get the FName static id string of a slot (via FPalItemId.StaticId).
local function slotItemId(slot)
    local ok, s = pcall(function() return slot:GetItemId().StaticId:ToString() end)
    if ok and s and #s > 0 then return s end
    return nil
end

-- One-shot diagnostic: log how to reach a placed chest's UPalItemContainer, so we
-- can nail the exact accessor path on this game version. Call from onLoad once.
local diagnosed = {}
function M.diagnose(actor, tag)
    if not actor or diagnosed[tag or "x"] then return end
    diagnosed[tag or "x"] = true
    local function probe(name, fn)
        local ok, v = pcall(fn)
        local desc = "nil"
        if ok and v then
            local okn, cls = pcall(function() return v:GetClass():GetFullName() end)
            desc = okn and tostring(cls) or "valid(no class)"
        elseif not ok then desc = "err:" .. tostring(v):sub(1, 60) end
        core.log("CONTDIAG " .. (tag or "") .. " " .. name .. " -> " .. desc)
    end
    probe("concrete(true)", function() return actor:GetModel():GetConcreteModel(true) end)
    probe("concrete:GetItemContainerModule()", function() return actor:GetModel():GetConcreteModel(true):GetItemContainerModule() end)
    probe("module:GetContainer()", function() return actor:GetModel():GetConcreteModel(true):GetItemContainerModule():GetContainer() end)
    probe("module.TargetContainer", function() return actor:GetModel():GetConcreteModel(true):GetItemContainerModule().TargetContainer end)
    -- confirm reads work end-to-end on this container
    local ok, n = pcall(function()
        return actor:GetModel():GetConcreteModel(true):GetItemContainerModule():GetContainer():Num()
    end)
    core.log("CONTDIAG " .. (tag or "") .. " container:Num() -> " .. (ok and tostring(n) or "err"))
end

-- ---- ItemHandler handle ----
local Handle = {}
Handle.__index = Handle

function M.fromActor(actor)
    if not (actor and actor:IsValid()) then return nil, "invalid actor" end
    local c = resolveContainer(actor)
    if not c then return nil, "no UPalItemContainer on actor" end
    return setmetatable({ _c = c, _actor = actor }, Handle)
end

-- also allow wrapping a raw container directly (tests / manager lookups)
function M.wrap(container)
    if not (container and container.IsValid and container:IsValid()) then return nil, "invalid container" end
    return setmetatable({ _c = container }, Handle)
end

function Handle:isValid()
    return self._c and self._c:IsValid()
end

function Handle:raw() return self._c end

-- number of a given item id across the container.
function Handle:count(itemId)
    local n = 0
    local ok = pcall(function() n = self._c:GetItemStackCount(FName(itemId)) end)
    if ok and n then return n end
    -- fallback: sum over slots
    n = 0
    for _, e in ipairs(self:list()) do if e.id == itemId then n = n + e.count end end
    return n
end

-- { {id, count, slot}, ... } for non-empty slots.
function Handle:list()
    local out = {}
    local num = 0
    pcall(function() num = self._c:Num() end)
    for i = 0, (num or 0) - 1 do
        pcall(function()
            local slot = self._c:Get(i)
            if slot and slot:IsValid() and not slot:IsEmpty() then
                local id = slotItemId(slot)
                local cnt = slot:GetStackCount()
                if id and cnt and cnt > 0 then
                    table.insert(out, { id = id, count = cnt, slot = i })
                end
            end
        end)
    end
    return out
end

-- Total free capacity is hard to compute generically; expose "has any space"
-- heuristically by checking for an empty slot or a non-full matching stack.
function Handle:hasSpace(itemId)
    local num = 0
    pcall(function() num = self._c:Num() end)
    for i = 0, (num or 0) - 1 do
        local space = false
        pcall(function()
            local slot = self._c:Get(i)
            if slot and slot:IsValid() then
                if slot:IsEmpty() then space = true
                elseif itemId and slotItemId(slot) == itemId and slot:GetStackCount() < slot:GetMaxStack() then
                    space = true
                end
            end
        end)
        if space then return true end
    end
    return false
end

-- ---- writes (gated; see Task container writes) ----
-- insert up to `count` of itemId; returns inserted amount (0 if writes disabled).
function Handle:insert(itemId, count)
    if not M.WRITES_ENABLED then return 0 end
    return M._insertImpl(self, itemId, count)
end

-- extract up to `count` of itemId; returns extracted amount (0 if writes disabled).
function Handle:extract(itemId, count)
    if not M.WRITES_ENABLED then return 0 end
    return M._extractImpl(self, itemId, count)
end

-- write impls live in a separate section so the gate above is unmistakable.
-- Filled in by the container-writes task; safe no-ops until then.
function M._insertImpl(handle, itemId, count) return 0 end
function M._extractImpl(handle, itemId, count) return 0 end

return M
