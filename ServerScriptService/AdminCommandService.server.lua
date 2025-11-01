--[[
    AdminCommandService.server.lua
    Purpose: Provide simple dev utilities for testing (grant currency, force rarity, reset data).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
local AdminCommand = Remotes:WaitForChild("AdminCommand", 5)
local RollResult = Remotes:WaitForChild("RollResult", 5)

local ALLOWED_USER_IDS = { 0 } -- replace with studio testers

local function isAllowed(player)
    for _, userId in ipairs(ALLOWED_USER_IDS) do
        if userId == 0 or player.UserId == userId then
            return true
        end
    end
    return false
end

local AdminCommandService = {}

local function grantCurrency(targetPlayer, currency, amount)
    PlayerDataService:Update(targetPlayer, function(profile)
        profile.currency[currency] = (profile.currency[currency] or 0) + amount
        return true
    end)
    RollResult:FireClient(targetPlayer, { type = "admin", message = string.format("Granted %d %s", amount, currency) })
end

local function resetData(targetPlayer)
    PlayerDataService:Update(targetPlayer, function(profile)
        for key in pairs(profile.inventory) do
            profile.inventory[key] = nil
        end
        profile.currency.coins = 5000
        profile.currency.gems = 120
        profile.pity.Standard = { pullsSinceSR = 0, pullsSinceUR = 0 }
        profile.pity.Limited = { pullsSinceSR = 0, pullsSinceUR = 0 }
        profile.stats.totalRolls = 0
        profile.stats.totalSuperRare = 0
        profile.stats.bestRarity = "Common"
        return true
    end)
    LeaderboardService.updatePower(targetPlayer)
end

local function forceRarity(targetPlayer, bannerName, rarity)
    -- Not true RNG override, but adds a card from the rarity pool for testing
    local GameConfig = require(ReplicatedStorage.Config.GameConfig)
    local CardCatalog = require(ReplicatedStorage.Config.CardCatalog)
    local banner = GameConfig.getActiveBanner(bannerName)
    if not banner then
        return
    end
    local poolId = banner.cardPools[rarity]
    if not poolId then
        return
    end
    local cards = CardCatalog.getCardsForPool(poolId)
    if #cards == 0 then
        return
    end
    local cardId = cards[math.random(#cards)].id
    PlayerDataService:Update(targetPlayer, function(profile)
        InventoryService.applyAddToProfile(profile, cardId)
        return true
    end)
    LeaderboardService.updatePower(targetPlayer)
    RollResult:FireClient(targetPlayer, { type = "admin", message = "Granted card " .. cardId })
end

AdminCommand.OnServerEvent:Connect(function(player, command, ...)
    if not isAllowed(player) then
        return
    end
    local args = { ... }
    if command == "grant" then
        local targetName, currency, amount = args[1], args[2], tonumber(args[3]) or 0
        local target = Players:FindFirstChild(targetName)
        if target and currency and amount > 0 then
            grantCurrency(target, currency, amount)
        end
    elseif command == "reset" then
        local targetName = args[1]
        local target = Players:FindFirstChild(targetName)
        if target then
            resetData(target)
        end
    elseif command == "force" then
        local targetName, bannerName, rarity = args[1], args[2], args[3]
        local target = Players:FindFirstChild(targetName)
        if target and bannerName and rarity then
            forceRarity(target, bannerName, rarity)
        end
    end
end)

return AdminCommandService
