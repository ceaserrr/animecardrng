--[[
    LiveOpsService.server.lua
    Purpose: React to GameConfig flags, rotate banners, broadcast updates.
]]
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config", 5):WaitForChild("GameConfig", 5))

local CHANNEL = "AuraCollector_LiveOps"

local LiveOpsService = {}
LiveOpsService.__index = LiveOpsService

local function log(message)
    print("📣 LiveOps " .. message)
end

local function publish(eventName, payload)
    local success, err = pcall(MessagingService.PublishAsync, MessagingService, CHANNEL, {
        event = eventName,
        payload = payload,
        timestamp = os.time(),
    })
    if not success then
        warn("⚠️ Warn liveops publish failed: " .. tostring(err))
    end
end

function LiveOpsService.broadcastBanner(bannerName)
    publish("banner", { banner = bannerName })
    log("Broadcast banner update for " .. bannerName)
end

return LiveOpsService
