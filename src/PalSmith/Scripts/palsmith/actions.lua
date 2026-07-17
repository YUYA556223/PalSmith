-- PalSmith action handlers + the {handler, args} behavior grammar.
--
-- New entry shape (v0.2):
--   { "handler": "smith:give_item", "args": { "item": "Wood", "count": 1 },
--     "when": { "chance": 0.5 }, "cooldownSec": 30 }
-- Legacy shape (v0.1, still accepted via the shim in normalize()):
--   { "action": "give_item", "item": "Wood", "count": 1, "cooldownSec": 30 }
--
-- Handlers are namespaced: "smith:*" are builtins. A handler receives (args, ctx)
-- where ctx = { id, event, player, actor, pack, packDir }. Server-authoritative
-- where the underlying game call is (see __knowledges).
local core = require("palsmith.core")
local ids  = require("palsmith.ids")
local mesh = require("palsmith.mesh")

local M = {}
local handlers = {}   -- "ns:name" -> fn(args, ctx)

local function palUtility() return StaticFindObject("/Script/Pal.Default__PalUtility") end
local function firstPlayer()
    local p = FindFirstOf("PalPlayerCharacter")
    if p and p:IsValid() then return p end
    return nil
end

-- ---- builtin handlers (smith:) ----
handlers["smith:announce"] = function(args, ctx)
    local util = palUtility()
    local target = ctx.player or firstPlayer()
    assert(util and util:IsValid(), "PalUtility not found")
    assert(target and target:IsValid(), "no target player for announce")
    util:SendSystemAnnounce(target, core.template(args.text or "", ctx))
end

handlers["smith:give_item"] = function(args, ctx)
    local itemId = assert(ids.resolve(assert(args.item, "give_item needs 'item'")))
    local count = args.count or 1
    local player = ctx.player or firstPlayer()
    assert(player and player:IsValid(), "no target player for give_item")
    local util = palUtility()
    local ps = util:GetPlayerStateByPlayer(player)
    assert(ps and ps:IsValid(), "no PlayerState")
    local inv = ps:GetInventoryData()
    assert(inv and inv:IsValid(), "no InventoryData")
    inv:AddItem_ServerInternal(FName(itemId), count, false, 0.0)
end

handlers["smith:spawn_pal"] = function(args, ctx)
    local cm = FindFirstOf("PalCheatManager")
    assert(cm and cm:IsValid(), "PalCheatManager not available (server: needs CheatManagerEnabler)")
    cm:SpawnMonsterForPlayer(FName(assert(args.pal, "spawn_pal needs 'pal'")), args.count or 1, args.level or 1)
end

handlers["smith:spawn_mesh"] = function(args, ctx)
    local target = ctx.actor or ctx.player or firstPlayer()
    assert(target and target:IsValid(), "no target actor for spawn_mesh")
    assert(args.model, "spawn_mesh needs 'model'")
    mesh.attach(target, {
        model = ctx.packDir .. "palsmith\\" .. args.model:gsub("/", "\\"),
        scale = args.scale, offset = args.offset,
    })
end

-- ---- normalization / back-compat shim ----
local deprecatedWarned = {}
local ARGS_SKIP = { action = true, cooldownSec = true, when = true }

-- Translate a raw behaviors list into normalized entries:
--   { handler="ns:name", args={...}, when=table|nil, cooldownSec=number|nil }
-- Legacy flat entries ({action,...}) become {handler="smith:"..action, args=rest}
-- with a one-time deprecation warning per pack. Returns the normalized list.
function M.normalize(rawList, packId)
    local out = {}
    for _, e in ipairs(rawList or {}) do
        if type(e) ~= "table" then
            core.warn("pack '" .. tostring(packId) .. "': behavior entry is not an object; skipped")
        elseif e.handler ~= nil then
            -- new shape
            local h = e.handler
            if not (type(h) == "string" and h:match("^[%w_]+:[%w_]+$")) then
                core.warn("pack '" .. tostring(packId) .. "': invalid handler '" .. tostring(h) .. "'; skipped")
            else
                table.insert(out, {
                    handler = h,
                    args = type(e.args) == "table" and e.args or {},
                    when = e.when,
                    cooldownSec = e.cooldownSec,
                })
            end
        elseif e.action ~= nil then
            -- legacy flat shape -> lift args, move cooldownSec/when to entry level
            if not deprecatedWarned[packId] then
                deprecatedWarned[packId] = true
                core.warn("pack '" .. tostring(packId) ..
                    "': behaviors use the deprecated {action,...} shape; migrate to {handler,args}")
            end
            local args = {}
            for k, v in pairs(e) do if not ARGS_SKIP[k] then args[k] = v end end
            table.insert(out, {
                handler = "smith:" .. tostring(e.action),
                args = args,
                when = e.when,
                cooldownSec = e.cooldownSec,
            })
        else
            core.warn("pack '" .. tostring(packId) .. "': behavior entry has neither 'handler' nor 'action'; skipped")
        end
    end
    return out
end

-- Report which handler names an entry list references but that aren't registered
-- (used at load time so packs fail loudly rather than at dispatch). Returns a
-- list of missing handler names.
function M.missingHandlers(entryList)
    local missing, seen = {}, {}
    for _, e in ipairs(entryList or {}) do
        if e.handler and not handlers[e.handler] and not seen[e.handler] then
            seen[e.handler] = true
            table.insert(missing, e.handler)
        end
    end
    return missing
end

-- ---- when-predicate evaluation ----
local function passesWhen(when)
    if type(when) ~= "table" then return true end
    if when.chance ~= nil then
        -- deterministic-free RNG; math.random is available at runtime
        local ok, r = pcall(math.random)
        if ok and r > (tonumber(when.chance) or 1) then return false end
    end
    return true
end

-- ---- dispatch ----
-- Run one NORMALIZED entry list. Each entry is pcall-isolated (fail-soft).
function M.run(entryList, ctx)
    for i, e in ipairs(entryList) do
        if passesWhen(e.when) then
            local handler = handlers[e.handler]
            if not handler then
                core.err(string.format("unknown handler '%s' (#%d on %s)", tostring(e.handler), i, ctx.id))
            else
                local ok, err = pcall(handler, e.args or {}, ctx)
                if not ok then
                    core.err(string.format("handler '%s' failed (#%d on %s): %s", e.handler, i, ctx.id, tostring(err)))
                end
            end
        end
    end
end

-- ---- registration API ----
-- Register a namespaced handler ("ns:name" -> fn(args, ctx)).
function M.registerHandler(name, fn)
    assert(type(name) == "string" and name:match("^[%w_]+:[%w_]+$"), "handler name must be 'ns:name'")
    assert(type(fn) == "function", "handler must be a function")
    if handlers[name] then core.warn("handler '" .. name .. "' overridden") end
    handlers[name] = fn
end

-- Deprecated alias: bare action name -> smith:<name>. Keeps old external Lua mods
-- that called PalSmith.registerAction working.
function M.register(name, fn)
    assert(type(name) == "string" and type(fn) == "function")
    core.warn("PalSmith.registerAction is deprecated; use registerHandler('smith:" .. name .. "', fn)")
    M.registerHandler("smith:" .. name, fn)
end

function M.hasHandler(name) return handlers[name] ~= nil end

return M
