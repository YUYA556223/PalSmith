-- PalSmith semver: parse / compare / range matching. Pure Lua, no deps.
--
-- Range grammar (a pragmatic semver subset):
--   range      := orClause ('||' orClause)*          -- OR
--   orClause   := comparator (WS comparator)*        -- AND (space-separated)
--   comparator := op? partial
--   op         := '>=' | '<=' | '>' | '<' | '=' | '^' | '~'
--   partial    := N | N.N | N.N.N  with wildcards 'x' | 'X' | '*'
--
-- Desugaring (must stay stable — packs depend on these):
--   bare "0.1"  (no op, no wildcard) -> ">=0.1.0"   [preserves legacy requiresSmith meaning]
--   "1.2.x"/"1.2.*"                  -> ">=1.2.0 <1.3.0"    (explicit wildcard = bounded)
--   "1.x"/"1.*"                      -> ">=1.0.0 <2.0.0"
--   "^1.2.3" -> ">=1.2.3 <2.0.0";  "^0.2.3" -> ">=0.2.3 <0.3.0";  "^0.0.3" -> ">=0.0.3 <0.0.4"
--   "~1.2.3" -> ">=1.2.3 <1.3.0";  "~1.2" -> ">=1.2.0 <1.3.0"
--   "*" / ""  -> match anything
local M = {}

-- ---- version parsing ----
-- Returns { major, minor, patch, pre=nil|string, raw } or nil, err.
function M.parse(s)
    if type(s) == "table" then return s end
    if type(s) ~= "string" then return nil, "version must be a string" end
    local v = s:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^[vV]", "")
    local core, pre = v:match("^([^%-]+)%-?(.*)$")
    if not core then return nil, "bad version '" .. s .. "'" end
    local nums = {}
    for n in core:gmatch("[^%.]+") do
        local d = tonumber(n)
        if not d or d % 1 ~= 0 or d < 0 then return nil, "bad version component in '" .. s .. "'" end
        table.insert(nums, d)
    end
    if #nums == 0 or #nums > 3 then return nil, "bad version '" .. s .. "'" end
    return {
        major = nums[1] or 0, minor = nums[2] or 0, patch = nums[3] or 0,
        pre = (pre ~= "" and pre) or nil, raw = s,
    }
end

-- ---- comparison ----
-- -1 | 0 | 1. Accepts strings or parsed tables. A release outranks a prerelease
-- of the same core (1.0.0 > 1.0.0-rc); prerelease strings compared lexically.
function M.compare(a, b)
    a = M.parse(a); b = M.parse(b)
    if not a or not b then return 0 end
    for _, k in ipairs({ "major", "minor", "patch" }) do
        if a[k] ~= b[k] then return a[k] < b[k] and -1 or 1 end
    end
    if a.pre == b.pre then return 0 end
    if a.pre == nil then return 1 end   -- release > prerelease
    if b.pre == nil then return -1 end
    if a.pre < b.pre then return -1 else return 1 end
end

function M.max(list)
    local best = nil
    for _, v in ipairs(list or {}) do
        if not best or M.compare(v, best) > 0 then best = v end
    end
    return best
end

-- ---- range parsing ----
local function ver(major, minor, patch, pre)
    return { major = major, minor = minor, patch = patch, pre = pre }
end

-- Turn one comparator token into a list of {op, version} constraints.
local function parseComparator(tok)
    tok = tok:gsub("%s+", "")
    if tok == "" or tok == "*" then return { { op = ">=", v = ver(0, 0, 0) } } end

    local op, rest = tok:match("^(>=?|<=?|=|%^|~)(.*)$")
    -- the pattern above doesn't work with Lua classes; do it manually:
    op, rest = nil, nil
    for _, o in ipairs({ ">=", "<=", ">", "<", "=", "^", "~" }) do
        if tok:sub(1, #o) == o then op = o; rest = tok:sub(#o + 1); break end
    end
    if not op then op = ""; rest = tok end

    -- split rest into up to 3 parts, tracking wildcards
    local parts, wild = {}, false
    for p in rest:gmatch("[^%.]+") do
        if p == "x" or p == "X" or p == "*" then wild = true; table.insert(parts, "*")
        else
            local d = tonumber(p)
            if not d then return nil, "bad range token '" .. tok .. "'" end
            table.insert(parts, d)
        end
    end
    if #parts == 0 then return { { op = ">=", v = ver(0, 0, 0) } } end

    local major = parts[1]; local minor = parts[2]; local patch = parts[3]
    local hasMinor = minor ~= nil and minor ~= "*"
    local hasPatch = patch ~= nil and patch ~= "*"
    local M0 = (major ~= "*") and major or 0
    local m0 = hasMinor and minor or 0
    local p0 = hasPatch and patch or 0

    if op == "^" then
        local upper
        if M0 > 0 or not hasMinor then upper = ver(M0 + 1, 0, 0)
        elseif m0 > 0 or not hasPatch then upper = ver(0, m0 + 1, 0)
        else upper = ver(0, 0, p0 + 1) end
        return { { op = ">=", v = ver(M0, m0, p0) }, { op = "<", v = upper } }
    elseif op == "~" then
        local upper = ver(M0, m0 + 1, 0)
        return { { op = ">=", v = ver(M0, m0, p0) }, { op = "<", v = upper } }
    elseif op == ">" or op == ">=" or op == "<" or op == "<=" or op == "=" then
        return { { op = op, v = ver(M0, m0, p0) } }
    else
        -- no explicit op
        if wild or major == "*" then
            -- bounded wildcard
            if major == "*" then return { { op = ">=", v = ver(0, 0, 0) } } end
            if not hasMinor then -- "1.x" / "1"
                return { { op = ">=", v = ver(M0, 0, 0) }, { op = "<", v = ver(M0 + 1, 0, 0) } }
            end
            -- "1.2.x"
            return { { op = ">=", v = ver(M0, m0, 0) }, { op = "<", v = ver(M0, m0 + 1, 0) } }
        end
        -- bare partial with NO wildcard = min-version (legacy requiresSmith "0.1")
        return { { op = ">=", v = ver(M0, m0, p0) } }
    end
end

-- Returns an AST: { orClause, ... } where orClause = { comparator, ... }.
function M.parseRange(s)
    if type(s) == "table" then return s end
    if s == nil then s = "*" end
    if type(s) ~= "string" then return nil, "range must be a string" end
    local ast = {}
    for orPart in (s .. "||"):gmatch("(.-)||") do
        local clause = {}
        for tok in orPart:gmatch("%S+") do
            local cmps, err = parseComparator(tok)
            if not cmps then return nil, err end
            for _, c in ipairs(cmps) do table.insert(clause, c) end
        end
        if #clause == 0 then table.insert(clause, { op = ">=", v = ver(0, 0, 0) }) end
        table.insert(ast, clause)
    end
    if #ast == 0 then ast = { { { op = ">=", v = ver(0, 0, 0) } } } end
    return ast
end

local function satisfiesComparator(v, c)
    local cmp = M.compare(v, c.v)
    if c.op == ">=" then return cmp >= 0
    elseif c.op == "<=" then return cmp <= 0
    elseif c.op == ">" then return cmp > 0
    elseif c.op == "<" then return cmp < 0
    elseif c.op == "=" then return cmp == 0 end
    return false
end

-- v: version string/table; r: range string/AST. Returns bool.
function M.satisfies(v, r)
    local pv = M.parse(v)
    if not pv then return false end
    local ast, err = M.parseRange(r)
    if not ast then return false end
    for _, clause in ipairs(ast) do          -- OR over clauses
        local all = true
        for _, c in ipairs(clause) do         -- AND within a clause
            if not satisfiesComparator(pv, c) then all = false; break end
        end
        if all then return true end
    end
    return false
end

return M
