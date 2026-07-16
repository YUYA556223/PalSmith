-- PalSmith V3 probe : verify onPlace / onInteract hookability for buildings.
-- Passive - just place a building and interact with one in-game, then check
-- UE4SS.log for [SmithV3] lines. Candidates resolved from CXXHeaderDump.

local function log(msg) print("[SmithV3] " .. tostring(msg) .. "\n") end

local function fname(v)
    local ok, s = pcall(function() return v:get():ToString() end)
    return ok and tostring(s) or "<unreadable>"
end

local function objName(v)
    local ok, s = pcall(function() return v:get():GetFullName() end)
    return ok and tostring(s) or "<unreadable>"
end

local HOOKS = {
    {
        path = "/Script/Pal.PalNetworkPlayerComponent:RequestBuild_ToServer",
        onFire = function(self, ...)
            local p = { ... }
            log("FIRED RequestBuild_ToServer BuildObjectId=" .. fname(p[1]))
        end,
    },
    {
        path = "/Script/Pal.PalPlayerRecordData:OnCompleteBuild_ServerInternal",
        onFire = function(self, ...)
            local p = { ... }
            local model = p[1]
            local id = "<n/a>"
            pcall(function() id = model:get().BuildObjectId:ToString() end)
            log("FIRED OnCompleteBuild_ServerInternal model=" .. objName(model) .. " BuildObjectId=" .. tostring(id))
        end,
    },
    {
        path = "/Script/Pal.PalBuildObject:OnBeginInteractBuilding",
        onFire = function(self, ...)
            local p = { ... }
            local okSelf, selfName = pcall(function() return self:get():GetFullName() end)
            log("FIRED OnBeginInteractBuilding building=" .. (okSelf and tostring(selfName) or "?") ..
                " other=" .. objName(p[1]))
        end,
    },
}

local registered = 0
for _, h in ipairs(HOOKS) do
    local ok, err = pcall(function() RegisterHook(h.path, h.onFire) end)
    if ok then
        registered = registered + 1
        log("registered hook: " .. h.path)
    else
        log("SKIP (not found): " .. h.path .. " -> " .. tostring(err))
    end
end

log(string.format("probe ready: %d/%d hooks registered. Place a building and interact with one.",
    registered, #HOOKS))
