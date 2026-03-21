-------------------------------------------------------------------------------
-- json.lua  –  Minimal JSON decoder / encoder for LÖVE2D projects
-- Supports: objects, arrays, strings, numbers, booleans, null
-------------------------------------------------------------------------------

local json = {}

-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------
local function skipWhitespace(str, pos)
    return str:match("^%s*()", pos)
end

local function decodeString(str, pos)
    -- pos should point to the opening quote
    pos = pos + 1 -- skip "
    local result = {}
    while pos <= #str do
        local c = str:sub(pos, pos)
        if c == '"' then
            return table.concat(result), pos + 1
        elseif c == '\\' then
            pos = pos + 1
            local esc = str:sub(pos, pos)
            if esc == '"' then
                result[#result + 1] = '"'
            elseif esc == '\\' then
                result[#result + 1] = '\\'
            elseif esc == '/' then
                result[#result + 1] = '/'
            elseif esc == 'b' then
                result[#result + 1] = '\b'
            elseif esc == 'f' then
                result[#result + 1] = '\f'
            elseif esc == 'n' then
                result[#result + 1] = '\n'
            elseif esc == 'r' then
                result[#result + 1] = '\r'
            elseif esc == 't' then
                result[#result + 1] = '\t'
            elseif esc == 'u' then
                local hex = str:sub(pos + 1, pos + 4)
                result[#result + 1] = string.char(tonumber(hex, 16))
                pos = pos + 4
            end
            pos = pos + 1
        else
            result[#result + 1] = c
            pos = pos + 1
        end
    end
    error("Unterminated string")
end

local decodeValue -- forward declaration

local function decodeArray(str, pos)
    pos = pos + 1 -- skip [
    local arr = {}
    pos = skipWhitespace(str, pos)
    if str:sub(pos, pos) == ']' then
        return arr, pos + 1
    end
    while true do
        local val
        val, pos = decodeValue(str, pos)
        arr[#arr + 1] = val
        pos = skipWhitespace(str, pos)
        local c = str:sub(pos, pos)
        if c == ']' then
            return arr, pos + 1
        elseif c == ',' then
            pos = skipWhitespace(str, pos + 1)
        else
            error("Expected ',' or ']' in array at position " .. pos)
        end
    end
end

local function decodeObject(str, pos)
    pos = pos + 1 -- skip {
    local obj = {}
    pos = skipWhitespace(str, pos)
    if str:sub(pos, pos) == '}' then
        return obj, pos + 1
    end
    while true do
        pos = skipWhitespace(str, pos)
        if str:sub(pos, pos) ~= '"' then
            error("Expected string key at position " .. pos)
        end
        local key
        key, pos = decodeString(str, pos)
        pos = skipWhitespace(str, pos)
        if str:sub(pos, pos) ~= ':' then
            error("Expected ':' at position " .. pos)
        end
        pos = skipWhitespace(str, pos + 1)
        local val
        val, pos = decodeValue(str, pos)
        obj[key] = val
        pos = skipWhitespace(str, pos)
        local c = str:sub(pos, pos)
        if c == '}' then
            return obj, pos + 1
        elseif c == ',' then
            pos = skipWhitespace(str, pos + 1)
        else
            error("Expected ',' or '}' in object at position " .. pos)
        end
    end
end

decodeValue = function(str, pos)
    pos = skipWhitespace(str, pos)
    local c = str:sub(pos, pos)

    if c == '"' then
        return decodeString(str, pos)
    elseif c == '{' then
        return decodeObject(str, pos)
    elseif c == '[' then
        return decodeArray(str, pos)
    elseif c == 't' then
        if str:sub(pos, pos + 3) == "true" then
            return true, pos + 4
        end
    elseif c == 'f' then
        if str:sub(pos, pos + 4) == "false" then
            return false, pos + 5
        end
    elseif c == 'n' then
        if str:sub(pos, pos + 3) == "null" then
            return nil, pos + 4
        end
    else
        -- Number
        local numStr = str:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
        if numStr then
            return tonumber(numStr), pos + #numStr
        end
    end
    error("Unexpected character at position " .. pos .. ": '" .. c .. "'")
end

function json.decode(str)
    if not str or str == "" then return nil end
    local val, _ = decodeValue(str, 1)
    return val
end

-------------------------------------------------------------------------------
-- Encode (re-export the existing toLua-style formatter as JSON)
-------------------------------------------------------------------------------
local function encodeValue(value)
    if value == nil then return "null" end
    local t = type(value)
    if t == "string" then
        return string.format("%q", value)
    elseif t == "number" or t == "boolean" then
        return tostring(value)
    elseif t == "table" then
        -- Detect array vs object
        local isArray = true
        local i = 1
        for k, _ in pairs(value) do
            if k ~= i then
                isArray = false; break
            end
            i = i + 1
        end
        local parts = {}
        if isArray then
            for _, v in ipairs(value) do
                parts[#parts + 1] = encodeValue(v)
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, v in pairs(value) do
                parts[#parts + 1] = string.format("%q", tostring(k)) .. ":" .. encodeValue(v)
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

function json.encode(value)
    return encodeValue(value)
end

return json
