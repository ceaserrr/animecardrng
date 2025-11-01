--[[
    MathUtils.module.lua
    Purpose: RNG helpers and math utilities for gacha calculations.
    API:
        MathUtils.weightedChoice(weightedList)
        MathUtils.clamp(value, min, max)
        MathUtils.round(num, precision)
    Example:
        local cardId = MathUtils.weightedChoice({ { weight = 70, value = "Common" } })
]]
local MathUtils = {}

function MathUtils.clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    elseif value > maxValue then
        return maxValue
    end
    return value
end

function MathUtils.round(num, precision)
    precision = precision or 0
    local mult = 10 ^ precision
    return math.floor(num * mult + 0.5) / mult
end

function MathUtils.weightedChoice(weightedList, rng)
    rng = rng or Random.new()
    local totalWeight = 0
    for _, entry in ipairs(weightedList) do
        totalWeight += entry.weight
    end
    if totalWeight <= 0 then
        return nil
    end
    local pivot = rng:NextNumber(0, totalWeight)
    local accum = 0
    for _, entry in ipairs(weightedList) do
        accum += entry.weight
        if pivot <= accum then
            return entry.value
        end
    end
    return weightedList[#weightedList] and weightedList[#weightedList].value or nil
end

return MathUtils
