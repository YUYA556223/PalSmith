-- PalSmith V1 probe : dump the blueprint class paths of built structures.
-- Build a few objects in-world (workbench, campfire, chest...), then press F10.
-- Each unique class full name is logged as [SmithV1] — these are exactly the
-- values V1's buildings JSON needs for BlueprintClassSoft (existing-BP reuse).

local function log(msg) print("[SmithV1] " .. tostring(msg) .. "\n") end

RegisterKeyBind(Key.F10, function()
    ExecuteInGameThread(function()
        local ok, err = pcall(function()
            local objs = FindAllOf("PalBuildObject") or {}
            log("=== F10: " .. tostring(#objs) .. " PalBuildObject instances ===")
            local seen = {}
            for _, o in ipairs(objs) do
                local okC, cls = pcall(function() return o:GetClass():GetFullName() end)
                if okC and not seen[cls] then
                    seen[cls] = true
                    log("class: " .. cls)
                end
            end
            log("=== done ===")
        end)
        if not ok then log("error: " .. tostring(err)) end
    end)
end)

log("V1 probe ready: build structures, then press F10 to dump their class paths")
