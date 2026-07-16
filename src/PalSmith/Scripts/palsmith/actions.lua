-- PalSmith standard action handlers.
--
-- Actions are the leaves of behavior declarations:
--   { "action": "announce", "text": "hi {id}" }
--   { "action": "give_item", "item": "Wood" | "mypack:thing", "count": 3 }
--   { "action": "spawn_pal", "pal": "Kitsunebi", "count": 1, "level": 5 }
--   { "action": "spawn_mesh", "model": "models/x.obj", "scale": 1, "offset": {...} }
--
-- All handlers are server-authoritative where the underlying call is (verified
-- in __knowledges). ctx = { id, event, player, actor, pack, packDir }.
local core = require("palsmith.core")
local ids  = require("palsmith.ids")
local mesh = require("palsmith.mesh")

local M = {}
local handlers = {}

local function palUtility()
    return StaticFindObject("/Script/Pal.Default__PalUtility")
end

local function firstPlayer()
    local p = FindFirstOf("PalPlayerCharacter")
    if p and p:IsValid() then return p end
    return nil
end

-- announce: system message. v0.1 targets ctx.player (or the first player).
handlers.announce = function(a, ctx)
    local util = palUtility()
    local target = ctx.player or firstPlayer()
    assert(util and util:IsValid(), "PalUtility not found")
    assert(target and target:IsValid(), "no target player for announce")
    util:SendSystemAnnounce(target, core.template(a.text or "", ctx))
end

-- give_item: verified pattern AddItem_ServerInternal via the player's inventory.
handlers.give_item = function(a, ctx)
    local itemId = assert(ids.resolve(assert(a.item, "give_item needs 'item'")))
    local count = a.count or 1
    local player = ctx.player or firstPlayer()
    assert(player and player:IsValid(), "no target player for give_item")
    local util = palUtility()
    local ps = util:GetPlayerStateByPlayer(player)
    assert(ps and ps:IsValid(), "no PlayerState")
    local inv = ps:GetInventoryData()
    assert(inv and inv:IsValid(), "no InventoryData")
    inv:AddItem_ServerInternal(FName(itemId), count, false, 0.0)
end

-- spawn_pal: verified CheatManager path (server-authoritative).
handlers.spawn_pal = function(a, ctx)
    local cm = FindFirstOf("PalCheatManager")
    assert(cm and cm:IsValid(), "PalCheatManager not available (server: needs CheatManagerEnabler)")
    cm:SpawnMonsterForPlayer(FName(assert(a.pal, "spawn_pal needs 'pal'")), a.count or 1, a.level or 1)
end

-- spawn_mesh: attach a runtime mesh to the context actor (building) or player.
handlers.spawn_mesh = function(a, ctx)
    local target = ctx.actor or ctx.player or firstPlayer()
    assert(target and target:IsValid(), "no target actor for spawn_mesh")
    assert(a.model, "spawn_mesh needs 'model'")
    local def = {
        model = ctx.packDir .. "palsmith\\" .. a.model:gsub("/", "\\"),
        scale = a.scale,
        offset = a.offset,
    }
    assert(mesh.attach(target, def), "mesh attach failed")
end

-- Run one action list. Each action is isolated; a failing action logs and
-- continues (fail-soft per F2).
function M.run(actionList, ctx)
    for i, a in ipairs(actionList) do
        local kind = a.action
        local handler = handlers[kind]
        if not handler then
            core.err(string.format("unknown action '%s' (#%d on %s)", tostring(kind), i, ctx.id))
        else
            local ok, err = pcall(handler, a, ctx)
            if not ok then
                core.err(string.format("action '%s' failed (#%d on %s): %s", kind, i, ctx.id, tostring(err)))
            end
        end
    end
end

-- Extension point: other mods can register custom actions from Lua.
function M.register(name, fn)
    assert(type(name) == "string" and type(fn) == "function")
    if handlers[name] then core.warn("action '" .. name .. "' overridden") end
    handlers[name] = fn
end

return M
