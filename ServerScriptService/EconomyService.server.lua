--[[
    EconomyService.server.lua
    Purpose: Manage currency balances, shop purchases, dev products, and boosters.
    API: Event-based via Remotes and ProcessReceipt.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config", 5):WaitForChild("GameConfig", 5))
local TableUtils = require(ReplicatedStorage:WaitForChild("Shared", 5):WaitForChild("TableUtils", 5))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
local GetShop = Remotes:WaitForChild("GetShop", 5)
local PurchaseRequest = Remotes:WaitForChild("PurchaseRequest", 5)
local RollResult = Remotes:WaitForChild("RollResult", 5)

local DEV_PRODUCT_IDS = {
    [101] = { gems = 120 },
    [102] = { gems = 650 },
    [103] = { gems = 1500 },
}

local function log(message)
    print("🛍️ Shop " .. message)
end

local function grantBundle(profile, bundle)
    if bundle.contents.coins then
        profile.currency.coins += bundle.contents.coins
    end
    if bundle.contents.shards then
        profile.tempShards = (profile.tempShards or 0) + bundle.contents.shards
    end
    if bundle.contents.boosters then
        for boosterType, count in pairs(bundle.contents.boosters) do
            local current = profile.boosters[boosterType]
            local duration = GameConfig.getEconomy().boosterDurations[boosterType] or 0
            local magnitude = boosterType == "luck" and 0.05 or 0
            for i = 1, count do
                current = current or {}
                current.expiresAt = os.time() + duration
                current.magnitude = magnitude
            end
            profile.boosters[boosterType] = current
        end
    end
end

local function applyBoost(profile, boostDef)
    profile.boosters = profile.boosters or {}
    local current = profile.boosters[boostDef.type] or {}
    current.expiresAt = os.time() + boostDef.duration
    current.magnitude = boostDef.type == "luck" and 0.05 or current.magnitude or 0
    profile.boosters[boostDef.type] = current
end

GetShop.OnServerInvoke = function(player)
    return TableUtils.deepCopy(GameConfig.getShop())
end

PurchaseRequest.OnServerEvent:Connect(function(player, purchaseType, id)
    if typeof(player) ~= "Instance" or player.Parent ~= Players then
        return
    end
    PlayerDataService:Update(player, function(profile)
        profile.boosters = profile.boosters or {}
        if purchaseType == "bundle" then
            for _, bundle in ipairs(GameConfig.getShop().bundles) do
                if bundle.id == id then
                    if profile.currency.gems < bundle.priceGems then
                        RollResult:FireClient(player, { type = "purchase", success = false, reason = "not_enough_gems" })
                        return false
                    end
                    profile.currency.gems -= bundle.priceGems
                    grantBundle(profile, bundle)
                    RollResult:FireClient(player, { type = "purchase", success = true, item = bundle.name })
                    log(string.format("%s bought bundle %s", player.Name, bundle.name))
                    return true
                end
            end
        elseif purchaseType == "boost" then
            for _, boost in ipairs(GameConfig.getShop().boosts) do
                if boost.id == id then
                    if profile.currency.gems < boost.priceGems then
                        RollResult:FireClient(player, { type = "purchase", success = false, reason = "not_enough_gems" })
                        return false
                    end
                    profile.currency.gems -= boost.priceGems
                    applyBoost(profile, boost)
                    RollResult:FireClient(player, { type = "purchase", success = true, item = boost.name })
                    log(string.format("%s purchased boost %s", player.Name, boost.name))
                    return true
                end
            end
        end
        RollResult:FireClient(player, { type = "purchase", success = false, reason = "unknown_item" })
        return false
    end)
end)

local function processDevProduct(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    local reward = DEV_PRODUCT_IDS[receiptInfo.ProductId]
    if not reward then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    PlayerDataService:Update(player, function(profile)
        for currency, amount in pairs(reward) do
            profile.currency[currency] = (profile.currency[currency] or 0) + amount
        end
        RollResult:FireClient(player, { type = "purchase", success = true, item = "DevProduct" })
        log(string.format("%s purchased dev product %d", player.Name, receiptInfo.ProductId))
        return true
    end)
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processDevProduct

return true
