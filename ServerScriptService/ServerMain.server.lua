--[[
    ServerMain.server.lua
    Purpose: Ensure all services are required so they initialize.
]]
local ServerScriptService = script.Parent

local function safeRequire(name)
    local module = ServerScriptService:FindFirstChild(name)
    if module then
        require(module)
    else
        warn("⚠️ Warn missing server module: " .. name)
    end
end

local modules = {
    "PlayerDataService",
    "InventoryService",
    "RollService",
    "EconomyService",
    "QuestService",
    "AchievementService",
    "LeaderboardService",
    "LiveOpsService",
    "AdminCommandService",
}

for _, name in ipairs(modules) do
    safeRequire(name)
end
