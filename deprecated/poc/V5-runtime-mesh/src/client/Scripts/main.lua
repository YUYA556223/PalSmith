-- PalSmith V5 probe : spawn a runtime-generated cube (ProceduralMeshComponent)
-- next to the player, via pure reflection calls (no ABI dependency).
-- Press F9 in-world. Each stage logs success/failure as [SmithV5].
--
-- API chain (verified present in CXXHeaderDump 2026-07-16):
--   AActor:AddComponentByClass -> UProceduralMeshComponent:CreateMeshSection

local function log(msg) print("[SmithV5] " .. tostring(msg) .. "\n") end

-- 1m cube: 8 vertices, 12 triangles (both windings emitted so it's visible
-- regardless of facing; good enough for a probe).
local S = 100.0
local VERTS = {
    {X=0,Y=0,Z=0}, {X=S,Y=0,Z=0}, {X=S,Y=S,Z=0}, {X=0,Y=S,Z=0},
    {X=0,Y=0,Z=S}, {X=S,Y=0,Z=S}, {X=S,Y=S,Z=S}, {X=0,Y=S,Z=S},
}
local QUADS = {
    {1,2,3,4}, {5,8,7,6}, {1,5,6,2}, {2,6,7,3}, {3,7,8,4}, {4,8,5,1},
}
local TRIS = {}
for _, q in ipairs(QUADS) do
    local a, b, c, d = q[1]-1, q[2]-1, q[3]-1, q[4]-1
    -- one winding...
    table.insert(TRIS, a); table.insert(TRIS, b); table.insert(TRIS, c)
    table.insert(TRIS, a); table.insert(TRIS, c); table.insert(TRIS, d)
    -- ...and the reverse, so the face renders from both sides
    table.insert(TRIS, c); table.insert(TRIS, b); table.insert(TRIS, a)
    table.insert(TRIS, d); table.insert(TRIS, c); table.insert(TRIS, a)
end

local spawnCount = 0

local function stage(name, fn)
    local ok, res = pcall(fn)
    log((ok and "OK   " or "FAIL ") .. name .. (ok and "" or (" -> " .. tostring(res))))
    return ok and (res == nil and true or res) or nil
end

local function spawnCube()
    log("=== F9 pressed: attempting runtime cube ===")

    local pmcClass = stage("STAGE1 find ProceduralMeshComponent class", function()
        local c = StaticFindObject("/Script/ProceduralMeshComponent.ProceduralMeshComponent")
        assert(c and c:IsValid(), "class not found")
        return c
    end)
    if not pmcClass then return end

    local pawn = stage("STAGE2 find player pawn", function()
        local p = FindFirstOf("PalPlayerCharacter")
        assert(p and p:IsValid(), "no PalPlayerCharacter")
        return p
    end)
    if not pawn then return end

    local comp = stage("STAGE3 AddComponentByClass", function()
        -- bManualAttachment=false attaches to the actor root with RelativeTransform.
        local c = pawn:AddComponentByClass(pmcClass, false, {}, false)
        assert(c and c:IsValid(), "returned invalid component")
        return c
    end)
    if not comp then return end

    stage("STAGE4 CreateMeshSection", function()
        -- empty arrays for normals/UVs/colors/tangents; collision enabled
        comp:CreateMeshSection(0, VERTS, TRIS, {}, {}, {}, {}, true)
    end)

    stage("STAGE5 offset placement", function()
        spawnCount = spawnCount + 1
        -- put the cube in front-ish of the player, stacking successive cubes
        comp:K2_SetRelativeLocation({X=250.0 + spawnCount * 50.0, Y=0.0, Z=0.0}, false, {}, false)
    end)

    -- An empty {} transform in AddComponentByClass may zero-initialize the
    -- relative scale, which makes the mesh invisible. Force sane values.
    stage("STAGE6 force scale/visibility", function()
        comp:SetWorldScale3D({X=1.0, Y=1.0, Z=1.0})
        comp:SetHiddenInGame(false, false)
        comp:SetVisibility(true, true)
    end)

    stage("STAGE7 diagnostics", function()
        local s = comp.RelativeScale3D
        log(string.format("  comp=%s scale=(%.2f,%.2f,%.2f) visible=%s",
            comp:GetFullName(), s.X, s.Y, s.Z, tostring(comp.bVisible)))
    end)

    log("=== done (check world around the player) ===")
end

RegisterKeyBind(Key.F9, function()
    ExecuteInGameThread(function()
        local ok, err = pcall(spawnCube)
        if not ok then log("spawnCube error: " .. tostring(err)) end
    end)
end)

log("V5 probe ready: press F9 in-world to spawn a runtime cube")
