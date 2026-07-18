-- PalSmith catalog dumper. Extracts the game's data — every DataTable's row
-- names (item ids, build-object ids, pal ids, recipes, ...) — into JSON files
-- under <Mods>/PalSmith/catalog/. A community reference AND how PalSmith learns
-- concrete ids (e.g. the vanilla chest build id) on any game version.
--
-- Row names come from UDataTable:GetRowNames() (verified present in the header
-- dump). DataTables are discovered by enumerating all loaded UDataTable objects.
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

local function rowNames(dt)
    local out = {}
    local ok, arr = pcall(function() return dt:GetRowNames() end)
    if not ok or not arr then return out end
    pcall(function()
        arr:ForEach(function(_, elem)
            local nm = elem:get():ToString()
            if nm and #nm > 0 then table.insert(out, nm) end
        end)
    end)
    -- fallback: index access if ForEach unavailable
    if #out == 0 then
        pcall(function()
            for i = 1, arr:GetArrayNum() do
                local nm = arr[i]:ToString()
                if nm and #nm > 0 then table.insert(out, nm) end
            end
        end)
    end
    table.sort(out)
    return out
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
            local name = dt:GetName()
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
