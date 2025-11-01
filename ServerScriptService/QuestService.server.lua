--[[
    QuestService.server.lua
    Purpose: Manage daily and weekly quest progress and reward claims.
    API:
        QuestService.recordAction(player, action, amount)
        RemoteFunction/Events handled internally for quest data.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config", 5):WaitForChild("GameConfig", 5))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
local RollResult = Remotes:WaitForChild("RollResult", 5)
local QuestClaimRequest = Remotes:WaitForChild("QuestClaimRequest", 5)

local QuestService = {}
QuestService.__index = QuestService

local actionMap = {
    roll = function(quest, amount, context)
        if quest.id == "daily_roll_10" then
            return amount
        end
        return 0
    end,
    fuse = function(quest, amount)
        if quest.id == "daily_fuse_3" then
            return amount
        end
        return 0
    end,
    rarity = function(quest, amount, context)
        if quest.id == "weekly_sr" and context and (context.rarity == "Super Rare" or context.rarity == "Ultra Rare") then
            return 1
        end
        return 0
    end,
}

local function log(message)
    print("📜 Quest " .. message)
end

local function resetQuests(profile)
    local now = os.time()
    local config = GameConfig.getQuestConfig()
    if now - (profile.quests.lastReset.daily or 0) >= 60 * 60 * 24 then
        profile.quests.daily = {}
        profile.quests.lastReset.daily = now
    end
    if now - (profile.quests.lastReset.weekly or 0) >= 60 * 60 * 24 * 7 then
        profile.quests.weekly = {}
        profile.quests.lastReset.weekly = now
    end
end

function QuestService.recordAction(player, action, amount, context)
    amount = amount or 1
    PlayerDataService:Update(player, function(profile)
        profile.quests = profile.quests or { daily = {}, weekly = {}, lastReset = { daily = 0, weekly = 0 } }
        resetQuests(profile)
        local config = GameConfig.getQuestConfig()
        local function progressList(listName, templates)
            profile.quests[listName] = profile.quests[listName] or {}
            for _, quest in ipairs(templates) do
                local handler = actionMap[action]
                if handler then
                    local gain = handler(quest, amount, context)
                    if gain > 0 then
                        local state = profile.quests[listName][quest.id] or { progress = 0, claimed = false }
                        if not state.claimed then
                            state.progress = math.min(quest.target, state.progress + gain)
                            profile.quests[listName][quest.id] = state
                            if state.progress >= quest.target then
                                RollResult:FireClient(player, { type = "quest", questId = quest.id, ready = true })
                            end
                        end
                    end
                end
            end
        end
        progressList("daily", config.daily)
        progressList("weekly", config.weekly)
        return true
    end)
end

function QuestService.claim(player, questType, questId)
    local config = GameConfig.getQuestConfig()
    local templates = questType == "daily" and config.daily or config.weekly
    PlayerDataService:Update(player, function(profile)
        resetQuests(profile)
        local stateTable = profile.quests[questType]
        if not stateTable then
            return false
        end
        local state = stateTable[questId]
        if not state or state.claimed or state.progress < (function()
            for _, q in ipairs(templates) do
                if q.id == questId then
                    return q.target
                end
            end
            return math.huge
        end)() then
            return false
        end
        state.claimed = true
        for _, q in ipairs(templates) do
            if q.id == questId then
                if q.reward.coins then
                    profile.currency.coins += q.reward.coins
                end
                if q.reward.gems then
                    profile.currency.gems += q.reward.gems
                end
                if q.reward.shards then
                    profile.tempShards = (profile.tempShards or 0) + q.reward.shards
                end
                if q.reward.boosters then
                    for boosterType, count in pairs(q.reward.boosters) do
                        profile.boosters = profile.boosters or {}
                        local current = profile.boosters[boosterType] or {}
                        current.expiresAt = os.time() + (GameConfig.getEconomy().boosterDurations[boosterType] or 0)
                        profile.boosters[boosterType] = current
                    end
                end
                RollResult:FireClient(player, { type = "questClaim", questId = questId, reward = q.reward })
                log(string.format("%s claimed quest %s", player.Name, questId))
                break
            end
        end
        return true
    end)
end

Players.PlayerAdded:Connect(function(player)
    PlayerDataService:Update(player, function(profile)
        profile.quests = profile.quests or { daily = {}, weekly = {}, lastReset = { daily = 0, weekly = 0 } }
        resetQuests(profile)
        return false
    end)
end)

QuestClaimRequest.OnServerEvent:Connect(function(player, questType, questId)
    if typeof(player) ~= "Instance" or player.Parent ~= Players then
        return
    end
    if questType ~= "daily" and questType ~= "weekly" then
        return
    end
    QuestService.claim(player, questType, questId)
end)

return QuestService
