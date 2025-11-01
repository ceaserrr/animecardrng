--[[
    LeaderboardService.server.lua
    Purpose: Maintain OrderedDataStore leaderboards for power and weekly rarity.
]]
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local POWER_STORE = DataStoreService:GetOrderedDataStore("Aura_PowerLeaderboard")
local RARITY_STORE = DataStoreService:GetOrderedDataStore("Aura_RarityWeekly")

local LeaderboardService = {}
LeaderboardService.__index = LeaderboardService

local function log(message)
    print("🏆 Achv " .. message)
end

local function updateStore(store, key, value)
    local success, err
    for attempt = 1, 3 do
        success, err = pcall(store.SetAsync, store, key, value)
        if success then
            break
        end
        task.wait(attempt)
    end
    if not success then
        warn("⚠️ Warn leaderboard update failed: " .. tostring(err))
    end
end

function LeaderboardService.updatePower(player)
    local profile = PlayerDataService:GetReadOnly(player)
    if not profile then
        return
    end
    local totalPower = profile.stats and profile.stats.totalPower or 0
    updateStore(POWER_STORE, player.UserId, totalPower)
end

function LeaderboardService.updateRarity(player, rarity)
    if rarity ~= "Ultra Rare" and rarity ~= "Super Rare" then
        return
    end
    updateStore(RARITY_STORE, player.UserId, os.time())
end

Players.PlayerRemoving:Connect(function(player)
    LeaderboardService.updatePower(player)
end)

return LeaderboardService
