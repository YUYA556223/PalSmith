-- PalSmith V2 probe : discover which function fires when a player USES an item,
-- and whether the StaticItemId is recoverable from the hook parameters.
-- Style follows AdminCommands. All logs are prefixed [SmithV2].
--
-- Usage: fill CANDIDATES with function paths found via CXXHeaderDump / Live View
-- (grep Pal.hpp for UseItem|UseFood|Consume|RequestUse), start the game/server,
-- use items in-game, then check UE4SS.log for "FIRED:" lines.

local function log(msg) print("[SmithV2] " .. tostring(msg) .. "\n") end

-- Candidate function paths, extracted from the client CXXHeaderDump (2026-07-16).
-- The prime target is UPalItemUseProcessor:UseItemToCharacter_ServerInternal —
-- server-authoritative AND carries UPalStaticItemDataBase* directly in its params.
local CANDIDATES = {
    "/Script/Pal.PalItemUseProcessor:UseItemToCharacter_ServerInternal",
    "/Script/Pal.PalPlayerController:RequestUseItemToCharacter_ToServer",
    "/Script/Pal.PalPlayerController:RequestUseItemToCharacter",
    "/Script/Pal.PalItemSlot:RequestUseToCharacter",
    "/Script/Pal.PalWeaponBase:RequestConsumeItem",
}

-- Dump one hook parameter: RemoteUnrealParam needs :get(); show type and best-effort
-- value. Every sub-step gets its own pcall so one bad accessor can't hide the rest,
-- and failures carry the actual error text for diagnosis.
local function describeParam(i, p)
    local v = p
    local okGet, got = pcall(function() return p:get() end)
    if okGet then v = got end
    local t = type(v)
    if t ~= "userdata" then
        return string.format("#%d %s %s", i, t, tostring(v))
    end
    local okName, name = pcall(function() return v:GetFullName() end)
    if okName then
        -- UObject: also try a few likely item-id fields
        local extra = ""
        local okId, id = pcall(function() return v.ID:ToString() end)
        if okId then extra = " ID=" .. tostring(id) end
        return string.format("#%d object %s%s", i, name, extra)
    end
    local okStr, s = pcall(function() return v:ToString() end)
    if okStr then return string.format("#%d userdata %s", i, tostring(s)) end
    return string.format("#%d userdata (GetFullName: %s)", i, tostring(name))
end

local registered = 0
for _, path in ipairs(CANDIDATES) do
    local ok, err = pcall(function()
        RegisterHook(path, function(self, ...)
            log("FIRED: " .. path)
            local args = { ... }
            for i, p in ipairs(args) do
                log("  param " .. describeParam(i, p))
            end
            local okSelf, selfName = pcall(function() return self:get():GetFullName() end)
            if okSelf then log("  self  " .. tostring(selfName)) end
        end)
    end)
    if ok then
        registered = registered + 1
        log("registered hook: " .. path)
    else
        log("SKIP (not found): " .. path .. " -> " .. tostring(err))
    end
end

log(string.format("probe ready: %d/%d candidate hooks registered. Use items in-game now.",
    registered, #CANDIDATES))
