-- PalSmith catalog dumper. Extracts the game's data — every DataTable's row
-- names (item ids, build-object ids, pal ids, recipes, ...) — into JSON files
-- under <Mods>/PalSmith/catalog/. A community reference AND how PalSmith learns
-- concrete ids (e.g. the vanilla chest build id) on any game version.
--
-- Row names come from UDataTable:GetRowNames(), falling back to the
-- BlueprintCallable UDataTableFunctionLibrary:GetDataTableRowNames (more reliably
-- reflected). DataTables are discovered by enumerating all loaded UDataTable objects.
local core = require("palsmith.core")
local json = require("palsmith.json")

local M = {}

-- Interesting tables to also mirror under friendly names (best-effort match).
local FRIENDLY = {
    item   = "ItemDataTable",
    build  = "BuildObjectDataTable",
    pal    = "MonsterParameter",
    tech   = "TechnologyRecipeUnlock",
}

local function catalogDir()
    local here = debug.getinfo(1, "S").source:match("@?(.*[\\/])") or ""
    return here .. "..\\..\\catalog\\"
end

-- Turn one FName-ish element (FName, RemoteUnrealParam wrapper, or string) into a
-- clean string, or nil. Unwraps :get() wrappers and drops empty / "None".
local function fnameToString(v)
    if v == nil then return nil end
    if type(v) == "userdata" then
        local okg, inner = pcall(function() return v.get and v:get() end)
        if okg and inner ~= nil then v = inner end
    end
    local ok, s = pcall(function()
        if type(v) == "userdata" and v.ToString then return v:ToString() end
        return tostring(v)
    end)
    if ok and s and #s > 0 and s ~= "None" then return s end
    return nil
end

-- Extract a UE4SS TArray<FName> into a sorted, de-duped Lua array of strings.
-- Tries ForEach then indexed access (both 1-based [i] and 0-based Get(i-1)).
local function arrayToStrings(arr)
    local out, seen = {}, {}
    if arr == nil then return out end
    local function add(v)
        local s = fnameToString(v)
        if s and not seen[s] then seen[s] = true; out[#out + 1] = s end
    end
    pcall(function()
        if arr.ForEach then arr:ForEach(function(_, elem) add(elem) end) end
    end)
    if #out == 0 then
        pcall(function()
            local n = 0
            if arr.GetArrayNum then n = arr:GetArrayNum()
            elseif type(arr) == "table" then n = #arr end
            for i = 1, n do
                local got = false
                pcall(function() if arr[i] ~= nil then add(arr[i]); got = true end end)
                if not got then pcall(function() add(arr:Get(i - 1)) end) end
            end
        end)
    end
    table.sort(out)
    return out
end

-- Row names of a UDataTable. UDataTable:GetRowNames() is a native method not
-- always reflected; the BlueprintCallable UDataTableFunctionLibrary is reliable.
local dtLib = nil
local diagShown = false
local function diagOnce(dt, arr1, arr2)
    if diagShown then return end
    diagShown = true
    local function shape(arr)
        if arr == nil then return "nil" end
        local t = type(arr)
        local num = "?"
        pcall(function() num = arr.GetArrayNum and tostring(arr:GetArrayNum()) or ("#=" .. tostring(#arr)) end)
        local hasFE = "no"; pcall(function() if arr.ForEach then hasFE = "yes" end end)
        return t .. " num=" .. num .. " ForEach=" .. hasFE
    end
    core.log("CATDIAG dtLib=" .. tostring(dtLib and true or false)
        .. " | GetRowNames -> " .. shape(arr1)
        .. " | LibRowNames -> " .. shape(arr2))
end

local function rowNames(dt)
    -- path 1: direct method
    local arr1
    do local ok, a = pcall(function() return dt:GetRowNames() end); if ok then arr1 = a end end
    -- path 2: DataTableFunctionLibrary:GetDataTableRowNames(dt, out). UE4SS may
    -- return the out-array OR fill a passed-in table in place — try both.
    if dtLib == nil then
        dtLib = StaticFindObject("/Script/Engine.Default__DataTableFunctionLibrary") or false
    end
    local arr2, outTbl = nil, {}
    if dtLib then
        local ok2, a2 = pcall(function() return dtLib:GetDataTableRowNames(dt, outTbl) end)
        if ok2 then arr2 = a2 end
    end
    diagOnce(dt, arr1, arr2)
    for _, cand in ipairs({ arr1, arr2, outTbl }) do
        local r = arrayToStrings(cand)
        if #r > 0 then return r end
    end
    return {}
end

-- Object name. UE4SS exposes GetFName():ToString() reliably; plain GetName() is
-- not always bound on these objects (it throws "attempt to call a nil value"),
-- which silently killed the whole dump before — hence the GetFName-first order.
local function objName(o)
    local ok, n = pcall(function() return o:GetFName():ToString() end)
    if ok and n and #n > 0 then return n end
    ok, n = pcall(function() return o:GetName() end)
    if ok and n and #n > 0 then return n end
    return nil
end

-- Dump every loaded UDataTable's row names. Returns a summary table.
function M.dumpDataTables()
    local dir = catalogDir()
    core.log("catalog: dumping DataTables to " .. dir .. "datatables\\ ...")
    core.ensureDir(dir)
    core.ensureDir(dir .. "datatables\\")

    local okFind, all = pcall(FindAllOf, "DataTable")
    if not okFind or type(all) ~= "table" then
        core.warn("catalog: FindAllOf(DataTable) failed (" .. tostring(all) .. ")")
        return nil
    end
    core.log("catalog: found " .. #all .. " DataTable objects")

    local index = {}
    local friendly = {}
    for _, dt in ipairs(all) do
        pcall(function()
            if not (dt and dt:IsValid()) then return end
            local name = objName(dt)
            if not name or #name == 0 then return end
            local names = rowNames(dt)
            if #names == 0 then return end
            core.writeFile(dir .. "datatables\\" .. name .. ".json",
                json.encode({ table = name, count = #names, rows = names }))
            index[name] = #names
            for key, needle in pairs(FRIENDLY) do
                if name:find(needle, 1, true) then friendly[key] = { table = name, count = #names } end
            end
        end)
    end

    core.writeFile(dir .. "index.json", json.encode({ tables = index, friendly = friendly }))
    local n = 0; for _ in pairs(index) do n = n + 1 end
    core.log(string.format("catalog: dumped %d datatables -> %sdatatables\\", n, dir))
    return { count = n, friendly = friendly }
end

-- Convenience: log the build-object ids (so the chest id is visible immediately).
function M.logBuildIds()
    local dir = catalogDir()
    local text = core.readFile(dir .. "index.json")
    local idx = text and json.decode(text)
    if idx and idx.friendly and idx.friendly.build then
        core.log("catalog: build table = " .. idx.friendly.build.table ..
            " (" .. idx.friendly.build.count .. " rows) — see catalog\\datatables\\")
    end
end

return M
