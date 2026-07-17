-- PalSmith dependency resolver. PURE (only depends on semver) so it can be unit
-- tested without any UE globals.
--
-- Input:  manifests = { packId -> normalizedManifest }  (from manifest.lua)
--         opts      = { smithVersion = "0.2.0", manifestFormat = 2 }
-- Output: { order = {packId,...},          -- topological, survivors only
--           status = { packId -> { state, reasons={...}, loadIndex=nil } } }
--
-- state values:
--   loaded            passes all hard checks (may still carry soft warnings)
--   incompatible      requiresSmith / formatVersion not satisfied
--   missing-dep       a `depends` target is absent
--   version-conflict  a `depends` target is present but out of range
--   broken            a `breaks` target is present and in range
--   cycle             part of a dependency cycle
--   cascade-disabled  depends (transitively) on a pack that failed
--   conflict          soft: a `conflicts` target is present (still loaded)
local semver = require("palsmith.semver")

local M = {}

local HARD_FAIL = {
    incompatible = true, ["missing-dep"] = true, ["version-conflict"] = true,
    broken = true, cycle = true, ["cascade-disabled"] = true,
    error = true, duplicate = true,
}

local function addReason(st, msg)
    table.insert(st.reasons, msg)
end

function M.resolve(manifests, opts)
    opts = opts or {}
    local smithVersion = opts.smithVersion or "0.0.0"
    local manifestFormat = opts.manifestFormat or 2

    local status = {}
    for id in pairs(manifests) do
        status[id] = { state = "loaded", reasons = {}, loadIndex = nil }
    end

    -- Pre-seed statuses provided by the caller (e.g. discovery-time errors /
    -- duplicates) so they participate in cascade + are never resurrected.
    if opts.preStatus then
        for id, st in pairs(opts.preStatus) do
            status[id] = { state = st.state, reasons = { table.unpack and table.unpack(st.reasons or {}) or nil }, loadIndex = nil }
            -- copy reasons robustly (table.unpack may be unpack on 5.1)
            status[id].reasons = {}
            for _, r in ipairs(st.reasons or {}) do table.insert(status[id].reasons, r) end
        end
    end

    -- 1) formatVersion + requiresSmith (per-pack, independent)
    for id, m in pairs(manifests) do
        local st = status[id]
        if st.state == "loaded" then
            if (m.formatVersion or 1) > manifestFormat then
                st.state = "incompatible"
                addReason(st, string.format("pack manifest format %d; this PalSmith understands %d",
                    m.formatVersion, manifestFormat))
            elseif not semver.satisfies(smithVersion, m.requiresSmith) then
                st.state = "incompatible"
                addReason(st, string.format("needs PalSmith %s (have %s)", m.requiresSmith, smithVersion))
            end
        end
    end

    -- 2) breaks (hard) — a present, in-range broken pack disables THIS pack
    for id, m in pairs(manifests) do
        local st = status[id]
        if st.state == "loaded" then
            for ns, range in pairs(m.breaks or {}) do
                local other = manifests[ns]
                if other and semver.satisfies(other.version, range) then
                    st.state = "broken"
                    addReason(st, string.format("breaks with %s %s (found %s)", ns, range, other.version))
                end
            end
        end
    end

    -- 3) depends (hard): missing / version-conflict
    for id, m in pairs(manifests) do
        local st = status[id]
        if st.state == "loaded" then
            for ns, range in pairs(m.depends or {}) do
                local other = manifests[ns]
                if not other then
                    st.state = "missing-dep"
                    addReason(st, string.format("missing dependency: %s (%s)", ns, range))
                elseif not semver.satisfies(other.version, range) then
                    st.state = "version-conflict"
                    addReason(st, string.format("requires %s %s, found %s", ns, range, other.version))
                end
            end
        end
    end

    -- 4) conflicts (soft): flag but stay loaded
    for id, m in pairs(manifests) do
        local st = status[id]
        if st.state == "loaded" then
            for ns, range in pairs(m.conflicts or {}) do
                local other = manifests[ns]
                if other and semver.satisfies(other.version, range) then
                    if st.state == "loaded" then st.state = "conflict" end
                    addReason(st, string.format("conflicts with %s %s (found %s)", ns, range, other.version))
                end
            end
        end
    end

    -- 5) recommends (soft): warn only
    for id, m in pairs(manifests) do
        local st = status[id]
        if st.state == "loaded" or st.state == "conflict" then
            for ns, range in pairs(m.recommends or {}) do
                local other = manifests[ns]
                if not other then
                    addReason(st, string.format("recommends %s (%s), not installed", ns, range))
                elseif not semver.satisfies(other.version, range) then
                    addReason(st, string.format("recommends %s %s, found %s", ns, range, other.version))
                end
            end
        end
    end

    local function isOk(id)
        local s = status[id].state
        return s == "loaded" or s == "conflict"
    end

    -- 6) cascade-disable: if a depends-target failed hard, this pack fails too.
    --    Iterate to a fixpoint.
    local changed = true
    while changed do
        changed = false
        for id, m in pairs(manifests) do
            if isOk(id) then
                for ns in pairs(m.depends or {}) do
                    local dep = manifests[ns]
                    if dep and not isOk(ns) and HARD_FAIL[status[ns].state] then
                        status[id].state = "cascade-disabled"
                        addReason(status[id], string.format("depends on '%s' which failed (%s)", ns, status[ns].state))
                        changed = true
                        break
                    end
                end
            end
        end
    end

    -- 7) topological sort (Kahn) over OK packs, edges dep -> dependent.
    local indeg, adj = {}, {}
    for id in pairs(manifests) do if isOk(id) then indeg[id] = 0; adj[id] = {} end end
    for id, m in pairs(manifests) do
        if isOk(id) then
            for ns in pairs(m.depends or {}) do
                if isOk(ns) then
                    table.insert(adj[ns], id)
                    indeg[id] = indeg[id] + 1
                end
            end
        end
    end

    -- deterministic: process zero-indegree nodes in alphabetical order
    local order = {}
    local function collectZero()
        local zeros = {}
        for id, d in pairs(indeg) do if d == 0 then table.insert(zeros, id) end end
        table.sort(zeros)
        return zeros
    end
    local remaining = 0
    for _ in pairs(indeg) do remaining = remaining + 1 end
    while true do
        local zeros = collectZero()
        if #zeros == 0 then break end
        for _, id in ipairs(zeros) do
            table.insert(order, id)
            indeg[id] = nil
            remaining = remaining - 1
            for _, nxt in ipairs(adj[id]) do
                if indeg[nxt] then indeg[nxt] = indeg[nxt] - 1 end
            end
        end
    end

    -- 8) whatever remains with indeg>0 is in a cycle
    if remaining > 0 then
        local inCycle = {}
        for id in pairs(indeg) do inCycle[id] = true end
        -- extract one concrete cycle path for the message via DFS
        local function findCycle()
            local visiting, stack = {}, {}
            local function dfs(node)
                visiting[node] = true; table.insert(stack, node)
                for ns in pairs(manifests[node].depends or {}) do
                    if inCycle[ns] then
                        if visiting[ns] then
                            local path = { ns }
                            for i = #stack, 1, -1 do
                                table.insert(path, 1, stack[i])
                                if stack[i] == ns then break end
                            end
                            return path
                        end
                        local r = dfs(ns)
                        if r then return r end
                    end
                end
                visiting[node] = nil; table.remove(stack)
                return nil
            end
            for id in pairs(inCycle) do
                local r = dfs(id); if r then return r end
            end
            return nil
        end
        local path = findCycle()
        local pathStr = path and table.concat(path, " -> ") or "(cycle)"
        for id in pairs(inCycle) do
            status[id].state = "cycle"
            addReason(status[id], "dependency cycle: " .. pathStr)
        end
    end

    -- assign load indices along the resolved order
    for i, id in ipairs(order) do status[id].loadIndex = i end

    return { order = order, status = status }
end

return M
