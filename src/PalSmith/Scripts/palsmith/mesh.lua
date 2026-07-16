-- PalSmith runtime meshes: Wavefront OBJ -> ProceduralMeshComponent.
--
-- Verified chain (V5, 2026-07-16): AActor:AddComponentByClass ->
-- UProceduralMeshComponent:CreateMeshSection -> SetWorldScale3D.
-- Trap: an empty {} FTransform zero-initializes the relative scale, so the
-- explicit SetWorldScale3D call is mandatory.
local core = require("palsmith.core")

local M = {}

local objCache = {} -- path -> { verts = {...}, tris = {...} }

-- Parse a (triangulated-or-not) OBJ file: v and f records only.
-- Faces with >3 vertices are fan-triangulated. Both windings are emitted so the
-- mesh is visible regardless of face orientation (probe-grade shading).
function M.parseObj(path)
    if objCache[path] then return objCache[path] end
    local text = core.readFile(path)
    if not text then return nil, "cannot read " .. path end
    local verts, tris = {}, {}
    for line in text:gmatch("[^\r\n]+") do
        local kind, rest = line:match("^(%a+)%s+(.*)$")
        if kind == "v" then
            local x, y, z = rest:match("([%-%d%.eE]+)%s+([%-%d%.eE]+)%s+([%-%d%.eE]+)")
            if x then table.insert(verts, { X = tonumber(x), Y = tonumber(y), Z = tonumber(z) }) end
        elseif kind == "f" then
            local idx = {}
            for token in rest:gmatch("%S+") do
                local vi = token:match("^(%-?%d+)")
                vi = tonumber(vi)
                if vi < 0 then vi = #verts + 1 + vi end
                table.insert(idx, vi - 1) -- OBJ is 1-based
            end
            for i = 2, #idx - 1 do
                local a, b, c = idx[1], idx[i], idx[i + 1]
                table.insert(tris, a); table.insert(tris, b); table.insert(tris, c)
                table.insert(tris, c); table.insert(tris, b); table.insert(tris, a)
            end
        end
    end
    if #verts == 0 or #tris == 0 then return nil, "no geometry in " .. path end
    local mesh = { verts = verts, tris = tris }
    objCache[path] = mesh
    return mesh
end

-- Attach a runtime mesh to an actor. def = { model, scale, offset }.
-- Returns true on success.
function M.attach(actor, def)
    local mesh, err = M.parseObj(def.model)
    if not mesh then core.err("mesh: " .. err); return false end

    local ok, aerr = pcall(function()
        local pmcClass = StaticFindObject("/Script/ProceduralMeshComponent.ProceduralMeshComponent")
        assert(pmcClass and pmcClass:IsValid(), "ProceduralMeshComponent class not found")
        local comp = actor:AddComponentByClass(pmcClass, false, {}, false)
        assert(comp and comp:IsValid(), "AddComponentByClass failed")
        comp:CreateMeshSection(0, mesh.verts, mesh.tris, {}, {}, {}, {}, true)
        local s = def.scale or 1.0
        comp:SetWorldScale3D({ X = s, Y = s, Z = s }) -- mandatory (zero-scale trap)
        local o = def.offset or {}
        comp:K2_SetRelativeLocation({ X = o.x or 0, Y = o.y or 0, Z = o.z or 0 }, false, {}, false)
    end)
    if not ok then core.err("mesh attach failed: " .. tostring(aerr)); return false end
    return true
end

-- Track actors we've already dressed so lazy re-attach doesn't stack meshes.
local dressed = setmetatable({}, { __mode = "k" })

function M.attachOnce(actor, def)
    if dressed[actor] then return true end
    if M.attach(actor, def) then
        dressed[actor] = true
        return true
    end
    return false
end

return M
