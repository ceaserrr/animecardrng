--[[
    RollService.server.lua
    Purpose: Handle roll requests, pity logic, and server authoritative RNG.
    API: (event-based)
        RemoteEvent RollRequest expects (bannerName: string, rollCount: number)
        RemoteEvent RollResult returns table with summary
    Example:
        RollRequest.OnServerEvent -> RollService handles.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config", 5):WaitForChild("GameConfig", 5))
local CardCatalog = require(ReplicatedStorage:WaitForChild("Config", 5):WaitForChild("CardCatalog", 5))
local MathUtils = require(ReplicatedStorage:WaitForChild("Shared", 5):WaitForChild("MathUtils", 5))
local TableUtils = require(ReplicatedStorage:WaitForChild("Shared", 5):WaitForChild("TableUtils", 5))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
local RollRequest = Remotes:WaitForChild("RollRequest", 5)
local RollResult = Remotes:WaitForChild("RollResult", 5)
local GetProfile = Remotes:WaitForChild("GetProfile", 5)

local RATE_LIMIT_PER_SEC = 3
local RATE_LIMIT_BURST = 5
local TOKEN_REPLENISH_INTERVAL = 1 / RATE_LIMIT_PER_SEC

local rateBuckets = {}

local rng = Random.new()

local function log(message)
    print("🎲 Roll " .. message)
end

local function getBucket(player)
    local bucket = rateBuckets[player]
    if not bucket then
        bucket = {
            tokens = RATE_LIMIT_BURST,
            last = tick(),
        }
        rateBuckets[player] = bucket
    end
    local now = tick()
    local delta = now - bucket.last
    local refill = math.floor(delta / TOKEN_REPLENISH_INTERVAL)
    if refill > 0 then
        bucket.tokens = math.min(RATE_LIMIT_BURST, bucket.tokens + refill)
        bucket.last = now
    end
    return bucket
end

local function getLuckBoost(profile)
    local boosters = profile.boosters or {}
    local luck = boosters.luck
    if luck and luck.expiresAt and luck.expiresAt > os.time() then
        return math.clamp(luck.magnitude or 0.05, 0, GameConfig.getEconomy().maxLuckBoost)
    end
    return 0
end

local function chooseRarity(bannerName, profile, pityState)
    local banner = GameConfig.getActiveBanner(bannerName)
    local pityConfig = GameConfig.getPityConfig(bannerName)
    local weights = TableUtils.deepCopy(banner.baseWeights)
    -- Hard pity check
    if pityState.pullsSinceUR + 1 >= pityConfig.hard.ur then
        return "Ultra Rare", true
    elseif pityState.pullsSinceSR + 1 >= pityConfig.hard.sr then
        return "Super Rare", true
    end
    -- Soft pity adjustments
    if pityState.pullsSinceSR >= pityConfig.soft.srStart then
        local extraRolls = pityState.pullsSinceSR - pityConfig.soft.srStart + 1
        weights["Super Rare"] += extraRolls * (pityConfig.soft.srIncrease * 100)
    end
    if pityState.pullsSinceUR >= pityConfig.soft.urStart then
        local extraRolls = pityState.pullsSinceUR - pityConfig.soft.urStart + 1
        weights["Ultra Rare"] += extraRolls * (pityConfig.soft.urIncrease * 100)
    end
    local luckBoost = getLuckBoost(profile)
    if luckBoost > 0 then
        weights["Super Rare"] *= (1 + luckBoost)
        weights["Ultra Rare"] *= (1 + luckBoost)
    end
    local weightedList = {}
    for rarity, weight in pairs(weights) do
        table.insert(weightedList, { weight = weight, value = rarity })
    end
    local rarity = MathUtils.weightedChoice(weightedList, rng)
    return rarity or "Common", false
end

local function chooseCard(banner, rarity)
    local poolId = banner.cardPools[rarity]
    local cards = CardCatalog.getCardsForPool(poolId)
    local weighted = {}
    for _, card in ipairs(cards) do
        table.insert(weighted, { weight = card.weight, value = card.id })
    end
    return MathUtils.weightedChoice(weighted, rng)
end

local function adjustPity(profile, bannerName, rarity)
    local pity = profile.pity[bannerName]
    if not pity then
        pity = { pullsSinceSR = 0, pullsSinceUR = 0 }
        profile.pity[bannerName] = pity
    end
    if rarity == "Super Rare" or rarity == "Ultra Rare" then
        pity.pullsSinceSR = 0
    else
        pity.pullsSinceSR += 1
    end
    if rarity == "Ultra Rare" then
        pity.pullsSinceUR = 0
    else
        pity.pullsSinceUR += 1
    end
end

local function ensureProfileDefaults(profile)
    profile.cooldowns = profile.cooldowns or { freeRoll = { Standard = 0, Limited = 0 } }
    profile.cooldowns.freeRoll = profile.cooldowns.freeRoll or { Standard = 0, Limited = 0 }
    profile.pity.Standard = profile.pity.Standard or { pullsSinceSR = 0, pullsSinceUR = 0 }
    profile.pity.Limited = profile.pity.Limited or { pullsSinceSR = 0, pullsSinceUR = 0 }
    profile.inventory = profile.inventory or {}
    profile.stats = profile.stats or { totalRolls = 0, bestRarity = "Common", totalPower = 0, totalSuperRare = 0 }
end

local function processRoll(player, bannerName, rollCount)
    local summary = {
        banner = bannerName,
        rolls = {},
        cost = nil,
        freeRollUsed = false,
    }
    local success = false
    PlayerDataService:Update(player, function(profile)
        ensureProfileDefaults(profile)
        local banner = GameConfig.getActiveBanner(bannerName)
        if not banner then
            return false
        end
        rollCount = rollCount == 10 and 10 or 1
        local cost = GameConfig.getRollCost(bannerName, rollCount)
        local now = os.time()
        local freeReady = profile.cooldowns.freeRoll[bannerName] and profile.cooldowns.freeRoll[bannerName] <= now
        summary.freeRollUsed = freeReady and rollCount == 1
        if summary.freeRollUsed then
            -- ok
        else
            if not cost then
                return false
            end
            local currencyBalance = profile.currency[cost.currency]
            if currencyBalance < cost.amount then
                summary.error = "insufficient_currency"
                return false
            end
            profile.currency[cost.currency] -= cost.amount
            summary.cost = { currency = cost.currency, amount = cost.amount }
        end
        if rollCount == 1 then
            profile.cooldowns.freeRoll[bannerName] = now + GameConfig.getFreeRollCooldown(bannerName)
        end
        for i = 1, rollCount do
            local pityState = profile.pity[bannerName]
            local rarity, hardPity = chooseRarity(bannerName, profile, pityState)
            local cardId = chooseCard(banner, rarity)
            if not cardId then
                summary.error = "no_card"
                return false
            end
            local reward = InventoryService.applyAddToProfile(profile, cardId)
            adjustPity(profile, bannerName, rarity)
            table.insert(summary.rolls, {
                cardId = cardId,
                rarity = rarity,
                hardPity = hardPity,
                reward = reward,
            })
        end
        success = true
        return true
    end)
    return success, summary
end

local function handleRoll(player, bannerName, rollCount)
    local bucket = getBucket(player)
    if bucket.tokens <= 0 then
        return
    end
    bucket.tokens -= 1
    local success, summary = processRoll(player, bannerName, rollCount)
    if success then
        log(string.format("%s rolled %d on %s", player.Name, #summary.rolls, bannerName))
        QuestService.recordAction(player, "roll", #summary.rolls)
        for _, roll in ipairs(summary.rolls) do
            QuestService.recordAction(player, "rarity", 1, { rarity = roll.rarity })
            LeaderboardService.updateRarity(player, roll.rarity)
        end
        AchievementService.evaluate(player)
        LeaderboardService.updatePower(player)
        RollResult:FireClient(player, {
            type = "roll",
            summary = summary,
        })
    else
        RollResult:FireClient(player, {
            type = "roll",
            success = false,
            error = summary and summary.error,
        })
    end
end

RollRequest.OnServerEvent:Connect(function(player, bannerName, rollCount)
    if typeof(player) ~= "Instance" or player.Parent ~= Players then
        return
    end
    if type(bannerName) ~= "string" then
        return
    end
    if type(rollCount) ~= "number" then
        rollCount = 1
    end
    handleRoll(player, bannerName, rollCount)
end)

GetProfile.OnServerInvoke = function(player)
    return PlayerDataService:GetReadOnly(player)
end

Players.PlayerRemoving:Connect(function(player)
    rateBuckets[player] = nil
end)

return true
