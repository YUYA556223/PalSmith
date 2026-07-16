-- Minimal JSON/JSONC decoder (pure Lua).
-- Supports: objects, arrays, strings (with escapes), numbers, true/false/null,
-- // and /* */ comments, trailing commas. Decode only - PalSmith never encodes.
local M = {}

local function stripComments(s)
    local out, i, n = {}, 1, #s
    local inStr = false
    while i <= n do
        local c = s:sub(i, i)
        if inStr then
            table.insert(out, c)
            if c == "\\" then
                table.insert(out, s:sub(i + 1, i + 1)); i = i + 1
            elseif c == '"' then
                inStr = false
            end
        elseif c == '"' then
            inStr = true; table.insert(out, c)
        elseif c == "/" and s:sub(i + 1, i + 1) == "/" then
            while i <= n and s:sub(i, i) ~= "\n" do i = i + 1 end
            table.insert(out, "\n")
        elseif c == "/" and s:sub(i + 1, i + 1) == "*" then
            i = i + 2
            while i <= n and not (s:sub(i, i) == "*" and s:sub(i + 1, i + 1) == "/") do i = i + 1 end
            i = i + 1
        else
            table.insert(out, c)
        end
        i = i + 1
    end
    return table.concat(out)
end

local ESCAPES = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

local function decode(s)
    local pos = 1

    local function err(msg)
        error(string.format("JSON error at byte %d: %s", pos, msg), 0)
    end

    local function skipWs()
        while pos <= #s do
            local c = s:sub(pos, pos)
            if c == " " or c == "\t" or c == "\n" or c == "\r" then pos = pos + 1 else break end
        end
    end

    local parseValue

    local function parseString()
        pos = pos + 1 -- opening quote
        local buf = {}
        while pos <= #s do
            local c = s:sub(pos, pos)
            if c == '"' then pos = pos + 1; return table.concat(buf) end
            if c == "\\" then
                local e = s:sub(pos + 1, pos + 1)
                if e == "u" then
                    local hex = s:sub(pos + 2, pos + 5)
                    local cp = tonumber(hex, 16) or err("bad \\u escape")
                    -- encode BMP codepoint as UTF-8 (surrogate pairs unsupported)
                    if cp < 0x80 then
                        table.insert(buf, string.char(cp))
                    elseif cp < 0x800 then
                        table.insert(buf, string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40))
                    else
                        table.insert(buf, string.char(0xE0 + math.floor(cp / 0x1000),
                            0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40))
                    end
                    pos = pos + 6
                else
                    table.insert(buf, ESCAPES[e] or err("bad escape \\" .. tostring(e)))
                    pos = pos + 2
                end
            else
                table.insert(buf, c); pos = pos + 1
            end
        end
        err("unterminated string")
    end

    local function parseNumber()
        local start = pos
        while pos <= #s and s:sub(pos, pos):match("[%d%+%-%.eE]") do pos = pos + 1 end
        return tonumber(s:sub(start, pos - 1)) or err("bad number")
    end

    local function parseObject()
        local obj = {}
        pos = pos + 1 -- {
        skipWs()
        if s:sub(pos, pos) == "}" then pos = pos + 1; return obj end
        while true do
            skipWs()
            if s:sub(pos, pos) == "}" then pos = pos + 1; return obj end -- trailing comma
            if s:sub(pos, pos) ~= '"' then err("expected key string") end
            local key = parseString()
            skipWs()
            if s:sub(pos, pos) ~= ":" then err("expected ':'") end
            pos = pos + 1
            obj[key] = parseValue()
            skipWs()
            local c = s:sub(pos, pos)
            if c == "," then pos = pos + 1
            elseif c == "}" then pos = pos + 1; return obj
            else err("expected ',' or '}'") end
        end
    end

    local function parseArray()
        local arr = {}
        pos = pos + 1 -- [
        skipWs()
        if s:sub(pos, pos) == "]" then pos = pos + 1; return arr end
        while true do
            skipWs()
            if s:sub(pos, pos) == "]" then pos = pos + 1; return arr end -- trailing comma
            table.insert(arr, parseValue())
            skipWs()
            local c = s:sub(pos, pos)
            if c == "," then pos = pos + 1
            elseif c == "]" then pos = pos + 1; return arr
            else err("expected ',' or ']'") end
        end
    end

    parseValue = function()
        skipWs()
        local c = s:sub(pos, pos)
        if c == "{" then return parseObject() end
        if c == "[" then return parseArray() end
        if c == '"' then return parseString() end
        if s:sub(pos, pos + 3) == "true" then pos = pos + 4; return true end
        if s:sub(pos, pos + 4) == "false" then pos = pos + 5; return false end
        if s:sub(pos, pos + 3) == "null" then pos = pos + 4; return nil end
        if c:match("[%d%-]") then return parseNumber() end
        err("unexpected character '" .. tostring(c) .. "'")
    end

    local v = parseValue()
    skipWs()
    return v
end

-- Returns value, or nil + error message.
function M.decode(text)
    local ok, res = pcall(decode, stripComments(text))
    if ok then return res end
    return nil, res
end

return M
