-- PalSmith component / capability lookup. Named, typed, optional-safe interfaces
-- attachable to entities and discoverable by (target, name). Modeled on Forge
-- capabilities / Fabric BlockApiLookup — the key interop primitive so pipes can
-- query a neighbour's "itemHandler" without importing the machine mod.
local core      = require("palsmith.core")
local container = require("palsmith.container")

local M = {}

local factories = {}  -- kind -> factory(instance, spec) -> component|nil

function M.registerFactory(kind, factory)
    assert(type(kind) == "string" and type(factory) == "function")
    factories[kind] = factory
end

-- built-in: a native chest wrapped as an itemHandler.
M.registerFactory("nativeContainer", function(instance, spec)
    if not instance.actor then return nil end
    local h = container.fromActor(instance.actor)
    return h
end)

-- attach all components declared on an instance's def.
function M.attach(instance)
    for name, spec in pairs(instance.def.components or {}) do
        local kind = (type(spec) == "table" and spec.kind) or spec
        local factory = factories[kind]
        if not factory then
            core.warn(string.format("entity '%s': unknown component kind '%s'", instance.id, tostring(kind)))
        else
            local ok, comp = pcall(factory, instance, spec)
            if ok and comp then instance.components[name] = comp
            elseif not ok then core.warn("component '" .. name .. "' factory failed: " .. tostring(comp)) end
        end
    end
end

-- get(target, name) -> component | nil. `target` may be an entity instance or a
-- raw actor. Always returns nil (never throws) when absent. For a raw actor with
-- no registered instance, itemHandler is adapted on the fly (any chest works).
function M.get(target, name)
    if type(target) ~= "table" then return nil end
    -- entity instance?
    if target.components then
        local c = target.components[name]
        if c then return c end
        -- lazily (re)build a nativeContainer if the def declares one but it wasn't ready at attach
        if name == "itemHandler" and target.actor then
            local h = container.fromActor(target.actor)
            if h then target.components[name] = h; return h end
        end
        return nil
    end
    -- raw actor: adapt on the fly for itemHandler
    if name == "itemHandler" and target.IsValid then
        local entity = require("palsmith.entity")
        local inst = entity.instanceForActor(target)
        if inst then return M.get(inst, name) end
        local h = container.fromActor(target)
        if h then return h end
    end
    return nil
end

return M
