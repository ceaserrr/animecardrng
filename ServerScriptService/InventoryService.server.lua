--[[
    InventoryService.server.lua
    Purpose: Manage inventory mutations (add, fuse, equip, lock) on the server.
    API:
        InventoryService:addCard(player, cardId) -> result table
        InventoryService:equipAura(player, cardId) -> boolean
        InventoryService:fuseCard(player, cardId) -> result table
        InventoryService:getInventory(player) -> table copy
    Example:
        local result = InventoryService:addCard(player, "aura_ember_glow")
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableUtils = require(ReplicatedStorage:WaitForChild("Shared", 5):WaitForChild("TableUtils", 5))
local GameConfig = require(ReplicatedStorage:WaitForChild("Config", 5):WaitForChild("GameConfig", 5))
local CardCatalog = require(ReplicatedStorage:WaitForChild("Config", 5):WaitForChild("CardCatalog", 5))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
local GetInventoryRemote = Remotes:WaitForChild("GetInventory", 5)
local UpgradeRequest = Remotes:WaitForChild("UpgradeRequest", 5)
local RollResultRemote = Remotes:WaitForChild("RollResult", 5)

local InventoryService = {}
InventoryService.__index = InventoryService

local DOUBLE_SHARDS_EVENT = "DOUBLE_SHARDS"

local function log(message)
    print("🧩 Inventory " .. message)
end

local function calculateTotalPower(profile)
    local total = 0
    for cardId, cardState in pairs(profile.inventory) do
        total += CardCatalog.calculatePower(cardId, cardState.level)
    end
    profile.stats.totalPower = total
    return total
end

local function getShardMultiplier(profile)
    local multiplier = 1
    if GameConfig.flags.DOUBLE_SHARDS_WEEKEND then
        multiplier += 1
    end
    local boosters = profile.boosters or {}
    local shardBoost = boosters.shards
    if shardBoost and shardBoost.expiresAt and shardBoost.expiresAt > os.time() then
        multiplier += 1
    end
    return multiplier
end

local function applyAdd(profile, cardDef)
    local inv = profile.inventory
    local cardId = cardDef.id
    local entry = inv[cardId]
    local shardsGranted = 0
    local isNew = false
    local shardReward = GameConfig.getEconomy().duplicateShardRewards[cardDef.rarity] or 0
    local multiplier = getShardMultiplier(profile)
    if not entry then
        entry = {
            count = 1,
            level = 1,
            shards = 0,
            locked = false,
        }
        inv[cardId] = entry
        isNew = true
    else
        entry.count += 1
        shardsGranted = math.floor(shardReward * multiplier)
        entry.shards += shardsGranted
    end
    profile.stats.totalRolls += 1
    if cardDef.rarity == "Super Rare" or cardDef.rarity == "Ultra Rare" then
        profile.stats.totalSuperRare = (profile.stats.totalSuperRare or 0) + 1
    end
    if cardDef.rarity == "Ultra Rare" then
        profile.stats.bestRarity = "Ultra Rare"
    elseif cardDef.rarity == "Super Rare" and profile.stats.bestRarity ~= "Ultra Rare" then
        profile.stats.bestRarity = "Super Rare"
    elseif cardDef.rarity == "Rare" and profile.stats.bestRarity == "Common" then
        profile.stats.bestRarity = "Rare"
    end
    calculateTotalPower(profile)
    return {
        cardId = cardId,
        isNew = isNew,
        shardsGranted = shardsGranted,
        count = entry.count,
        level = entry.level,
        rarity = cardDef.rarity,
        basePower = cardDef.basePower,
    }
end

function InventoryService:getInventory(player)
    local profile = PlayerDataService:GetReadOnly(player)
    if not profile then
        return {}
    end
    return TableUtils.deepCopy(profile.inventory)
end

function InventoryService:addCard(player, cardId)
    local cardDef = CardCatalog.getCard(cardId)
    if not cardDef then
        return nil
    end
    local result
    PlayerDataService:Update(player, function(profile)
        result = applyAdd(profile, cardDef)
        return true
    end)
    LeaderboardService.updatePower(player)
    return result
end

function InventoryService.applyAddToProfile(profile, cardId)
    local cardDef = CardCatalog.getCard(cardId)
    if not cardDef then
        return nil
    end
    return applyAdd(profile, cardDef)
end

local function getFuseCost(cardDef, level)
    local economy = GameConfig.getEconomy()
    local rarityConfig = economy.fuseCosts[cardDef.rarity]
    if not rarityConfig then
        return { coins = 0, shards = 0 }
    end
    local targetLevel = level + 1
    local coinsCost = rarityConfig.baseCoins * targetLevel
    local shardsCost = rarityConfig.shardCost * targetLevel
    return { coins = coinsCost, shards = shardsCost }
end

function InventoryService:fuseCard(player, cardId)
    local cardDef = CardCatalog.getCard(cardId)
    if not cardDef then
        return false, "unknown_card"
    end
    local success = false
    local message = ""
    local fuseResult
    PlayerDataService:Update(player, function(profile)
        local entry = profile.inventory[cardId]
        if not entry then
            message = "not_owned"
            return false
        end
        if entry.level >= cardDef.maxLevel then
            message = "max_level"
            return false
        end
        if entry.locked then
            message = "locked"
            return false
        end
        local cost = getFuseCost(cardDef, entry.level)
        if profile.currency.coins < cost.coins then
            message = "not_enough_coins"
            return false
        end
        if entry.shards < cost.shards then
            message = "not_enough_shards"
            return false
        end
        profile.currency.coins -= cost.coins
        entry.shards -= cost.shards
        entry.level += 1
        calculateTotalPower(profile)
        success = true
        fuseResult = {
            cardId = cardId,
            level = entry.level,
            shards = entry.shards,
            coins = profile.currency.coins,
        }
        return true
    end)
    if success then
        log(string.format("Fused %s for %s", cardId, player.Name))
        QuestService.recordAction(player, "fuse", 1)
    end
    return success, message, fuseResult
end

function InventoryService:equipAura(player, cardId)
    local cardDef = CardCatalog.getCard(cardId)
    if not cardDef then
        return false
    end
    local success = false
    PlayerDataService:Update(player, function(profile)
        local entry = profile.inventory[cardId]
        if not entry then
            return false
        end
        profile.equipped.aura = cardId
        success = true
        return true
    end)
    return success
end

function InventoryService:setLock(player, cardId, locked)
    PlayerDataService:Update(player, function(profile)
        local entry = profile.inventory[cardId]
        if not entry then
            return false
        end
        entry.locked = locked and true or false
        return true
    end)
end

GetInventoryRemote.OnServerInvoke = function(player)
    return InventoryService:getInventory(player)
end

UpgradeRequest.OnServerEvent:Connect(function(player, action, cardId)
    if action == "fuse" then
        local success, reason, result = InventoryService:fuseCard(player, cardId)
        RollResultRemote:FireClient(player, {
            type = "fuse",
            success = success,
            reason = reason,
            result = result,
        })
    elseif action == "equip" then
        local success = InventoryService:equipAura(player, cardId)
        RollResultRemote:FireClient(player, {
            type = "equip",
            success = success,
            cardId = cardId,
        })
    elseif action == "lock" then
        InventoryService:setLock(player, cardId, true)
    elseif action == "unlock" then
        InventoryService:setLock(player, cardId, false)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    -- nothing additional
end)

return InventoryService
