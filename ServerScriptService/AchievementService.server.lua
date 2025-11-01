--[[
    AchievementService.server.lua
    Purpose: Track lifetime achievements and award rewards/badges.
    API:
        AchievementService.evaluate(player)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BadgeService = game:GetService("BadgeService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config", 5):WaitForChild("GameConfig", 5))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
local RollResult = Remotes:WaitForChild("RollResult", 5)

local AchievementService = {}
AchievementService.__index = AchievementService

local function log(message)
    print("🏆 Achv " .. message)
end

function AchievementService.evaluate(player)
    PlayerDataService:Update(player, function(profile)
        profile.achievements = profile.achievements or {}
        for _, template in ipairs(GameConfig.getAchievementConfig()) do
            local current = profile.achievements[template.id]
            if not current or not current.completed then
                local statValue = profile.stats[template.stat] or 0
                if statValue >= template.target then
                    profile.achievements[template.id] = { completed = true, timestamp = os.time() }
                    if template.reward.coins then
                        profile.currency.coins += template.reward.coins
                    end
                    if template.reward.gems then
                        profile.currency.gems += template.reward.gems
                    end
                    if template.reward.shards then
                        profile.tempShards = (profile.tempShards or 0) + template.reward.shards
                    end
                    if template.reward.boosters then
                        for boosterType, count in pairs(template.reward.boosters) do
                            profile.boosters = profile.boosters or {}
                            local currentBoost = profile.boosters[boosterType] or {}
                            currentBoost.expiresAt = os.time() + (GameConfig.getEconomy().boosterDurations[boosterType] or 0)
                            profile.boosters[boosterType] = currentBoost
                        end
                    end
                    if template.badgeId and template.badgeId ~= 0 then
                        pcall(function()
                            BadgeService:AwardBadge(player.UserId, template.badgeId)
                        end)
                    end
                    RollResult:FireClient(player, { type = "achievement", achievementId = template.id })
                    log(string.format("%s completed achievement %s", player.Name, template.id))
                end
            end
        end
        return true
    end)
end

Players.PlayerAdded:Connect(function(player)
    AchievementService.evaluate(player)
end)

return AchievementService
