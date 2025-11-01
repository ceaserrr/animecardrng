--[[
    TableUtils.module.lua
    Purpose: Utility helpers for table cloning and formatting.
    API:
        TableUtils.deepCopy(tbl)
        TableUtils.prettyPrint(tbl)
        TableUtils.merge(destination, source)
    Example:
        local copy = TableUtils.deepCopy(original)
]]
local TableUtils = {}

local function _deepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for key, innerValue in pairs(value) do
        copy[_deepCopy(key, seen)] = _deepCopy(innerValue, seen)
    end
    return copy
end

function TableUtils.deepCopy(tbl)
    return _deepCopy(tbl, {})
end

function TableUtils.prettyPrint(tbl, indent)
    indent = indent or 0
    local pad = string.rep(" ", indent)
    if type(tbl) ~= "table" then
        return tostring(tbl)
    end
    local parts = {"{"}
    for key, value in pairs(tbl) do
        local keyStr = string.format("%s[%s] = ", pad .. "  ", tostring(key))
        if type(value) == "table" then
            table.insert(parts, keyStr .. TableUtils.prettyPrint(value, indent + 2))
        else
            table.insert(parts, keyStr .. tostring(value))
        end
    end
    table.insert(parts, pad .. "}")
    return table.concat(parts, "\n")
end

function TableUtils.merge(destination, source)
    for key, value in pairs(source) do
        destination[key] = value
    end
    return destination
end

return TableUtils
