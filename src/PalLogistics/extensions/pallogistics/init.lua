-- PalLogistics — a LogisticsPipes-style logistics mod, built as a PalSmith
-- EXTENSION (loaded into PalSmith's Lua VM by the extension loader, so _G.PalSmith
-- and the framework API are available directly; no separate UE4SS mod / VM).
--
-- Install: this folder -> <Mods>/PalSmith/extensions/pallogistics/
-- Ships alongside the PalSchema data pack "PalLogisticsPack" (the Pipe building).
local PalSmith = _G.PalSmith
local function log(m) print("[PalLogistics] " .. tostring(m) .. "\n") end

if not (PalSmith and PalSmith.defineEntity) then
    log("ERROR: loaded without PalSmith API"); return
end
log("PalLogistics starting on PalSmith v" .. tostring(PalSmith.version))

-- Discovery diagnostic: log every build placement so the real vanilla chest
-- build id on this game version is revealed; add it to CHEST_BUILD_IDS below.
PalSmith.onPlace(function(buildId, pos)
    log(string.format("placed build id='%s' at %s", tostring(buildId),
        pos and string.format("(%.0f,%.0f,%.0f)", pos.x, pos.y, pos.z) or "?"))
end)

-- ---- Warehouse: wraps a placed native chest as a logistics endpoint ----
local CHEST_BUILD_IDS = {
    "ItemChest", "ItemChest_02", "ItemChest_03", "WoodChest", "DisplayCharacter_Box",
}
PalSmith.defineEntity{
    id = "logi:Warehouse",
    buildIds = CHEST_BUILD_IDS,
    displayName = "Warehouse",
    tickInterval = 4,
    components = { itemHandler = { kind = "nativeContainer" } },
    onLoad = function(self) log("warehouse online @ " .. self.key) end,
    -- NOTE: no onInteract=openMenu — a vanilla chest already has its own native
    -- UI, and overlaying ours hijacks/blocks it. The warehouse's value here is
    -- the itemHandler (for pipes) + passive onTick. A dedicated entity-menu demo
    -- belongs on a NON-chest machine (which has no native UI).
    onTick = function(self)
        local ih = self:getComponent("itemHandler"); if not ih then return end
        local n = ih:count("Wood")
        if n ~= (self.state.lastWood or -1) then
            self.state.lastWood = n; self:setDirty()
            log(string.format("warehouse %s: Wood=%d", self.key, n))
        end
    end,
}
log("Warehouse registered (adopts: " .. table.concat(CHEST_BUILD_IDS, ", ") .. ")")

-- ---- Transport Pipe: point-to-point local push between adjacent itemHandlers --
local spatial = PalSmith.spatial
local RADIUS_CM, MOVE_PER_TICK = 250, 10
PalSmith.defineEntity{
    id = "logi:Pipe",
    displayName = "Transport Pipe",
    tickInterval = 2,
    gridCm = 50,
    onLoad = function(self) log("pipe online @ " .. self.key) end,
    onTick = function(self)
        if not (self.actor and self.actor:IsValid()) then return end
        local neigh = spatial.neighbors(self.pos, RADIUS_CM, self)
        if #neigh < 2 then return end
        local src
        for _, n in ipairs(neigh) do
            local ih = PalSmith.getComponent(n, "itemHandler")
            if ih and #ih:list() > 0 then src = { inst = n, ih = ih }; break end
        end
        if not src then return end
        local dst
        for _, n in ipairs(neigh) do
            if n ~= src.inst then
                local ih = PalSmith.getComponent(n, "itemHandler")
                if ih and ih:hasSpace() then dst = { ih = ih }; break end
            end
        end
        if not dst then return end
        local first = src.ih:list()[1]; if not first then return end
        local got = src.ih:extract(first.id, MOVE_PER_TICK)
        if got > 0 then
            local put = dst.ih:insert(first.id, got)
            if put < got then src.ih:insert(first.id, got - put) end
            log(string.format("pipe %s moved %d %s", self.key, put, first.id))
        else
            log(string.format("pipe %s: would move %s (writes disabled)", self.key, first.id))
        end
    end,
}
log("Pipe registered — PalLogistics ready")
