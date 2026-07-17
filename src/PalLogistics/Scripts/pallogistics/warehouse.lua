-- PalLogistics Warehouse: wraps a placed native chest as a logistics endpoint.
-- Uses PalSmith's itemHandler component (nativeContainer). Read-only for the
-- slice: onInteract opens a contents menu; onTick logs a heartbeat + item count.
--
-- Binding: for the slice the Warehouse ADOPTS vanilla chest build ids (so no
-- custom building/BP path is needed). CHEST_BUILD_IDS lists candidates; the real
-- id for this game version is revealed by the placement diagnostic in main.lua —
-- add it here once known.
local PalSmith = _G.PalSmith
local function log(m) print("[PalLogistics] " .. tostring(m) .. "\n") end

-- Candidate vanilla chest build ids to adopt as Warehouses (extend as discovered).
local CHEST_BUILD_IDS = {
    "ItemChest", "ItemChest_02", "ItemChest_03",
    "WoodChest", "DisplayCharacter_Box",
}

PalSmith.defineEntity{
    id = "logi:Warehouse",
    buildIds = CHEST_BUILD_IDS,     -- adopt-on-sight for any of these vanilla chests
    displayName = "Warehouse",
    tickInterval = 4,               -- ~2s at 500ms base
    components = { itemHandler = { kind = "nativeContainer" } },

    onLoad = function(self)
        log("warehouse online @ " .. self.key)
    end,

    onInteract = function(self)
        self:openMenu()             -- PalSmith entity menu shows container contents
    end,

    onTick = function(self)
        local ih = self:getComponent("itemHandler")
        if not ih then return end
        local n = ih:count("Wood")
        if n ~= (self.state.lastWood or -1) then
            self.state.lastWood = n
            self:setDirty()
            log(string.format("warehouse %s: Wood=%d", self.key, n))
        end
    end,
}

log("Warehouse entity registered (adopts: " .. table.concat(CHEST_BUILD_IDS, ", ") .. ")")
