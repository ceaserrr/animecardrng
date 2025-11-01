--[[
    PlayerDataService.server.lua
    Purpose: Load, save, and expose player profile data with migration support.
    API:
        PlayerDataService:GetProfile(player) -> table
        PlayerDataService:Update(player, callback)
        PlayerDataService:Flush(player)
        PlayerDataService:AwardCurrency(player, currencyType, amount)
    Example:
        local DataService = require(ServerScriptService:WaitForChild("PlayerDataService"))
        local profile = DataService:GetProfile(player)
]]
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Config", 5):WaitForChild("GameConfig", 5))
local TableUtils = require(ReplicatedStorage:WaitForChild("Shared", 5):WaitForChild("TableUtils", 5))
local MathUtils = require(ReplicatedStorage:WaitForChild("Shared", 5):WaitForChild("MathUtils", 5))

local PROFILE_VERSION = 1
local DATASTORE_NAME = "AuraCollector_Profile_v1"
local SAVE_INTERVAL = 60
local MAX_RETRIES = 5
local RETRY_BACKOFF = 3

local ProfileCache = {}
local DirtyProfiles = {}

local ProfileStore = DataStoreService:GetDataStore(DATASTORE_NAME)

local PlayerDataService = {}
PlayerDataService.__index = PlayerDataService

local defaultProfile = {
    version = PROFILE_VERSION,
    createdAt = os.time(),
    lastSeen = os.time(),
    currency = { coins = 5000, gems = 120 },
    pity = {
        Standard = { pullsSinceSR = 0, pullsSinceUR = 0 },
        Limited = { pullsSinceSR = 0, pullsSinceUR = 0 },
    },
    inventory = {},
    equipped = { aura = nil },
    stats = { totalRolls = 0, bestRarity = "Common", totalPower = 0, totalSuperRare = 0 },
    boosters = {},
    cooldowns = {
        freeRoll = {
            Standard = 0,
            Limited = 0,
        },
    },
    quests = {
        daily = {},
        weekly = {},
        lastReset = { daily = 0, weekly = 0 },
    },
    achievements = {},
}

local function log(tag, message)
    print(string.format("%s %s", tag, message))
end

local function deepCopyDefault()
    return TableUtils.deepCopy(defaultProfile)
end

local function migrate(profile)
    if not profile.version then
        profile.version = 0
    end
    if profile.version < PROFILE_VERSION then
        -- In future versions migrate fields here
        profile.version = PROFILE_VERSION
    end
    return profile
end

local function safeKey(player)
    return "player_" .. player.UserId
end

local function loadProfile(player)
    local key = safeKey(player)
    local success, data
    for attempt = 1, MAX_RETRIES do
        success, data = pcall(ProfileStore.GetAsync, ProfileStore, key)
        if success then
            break
        end
        warn(string.format("⚠️ Warn PlayerDataService load attempt %d failed for %s: %s", attempt, player.Name, tostring(data)))
        task.wait(RETRY_BACKOFF * attempt)
    end
    if not success then
        return nil
    end
    if not data then
        data = deepCopyDefault()
        data.createdAt = os.time()
    else
        data = migrate(data)
    end
    data.lastSeen = os.time()
    return data
end

local function saveProfile(userId, profile)
    if not profile then
        return
    end
    profile.lastSeen = os.time()
    local key = "player_" .. userId
    local success, err
    for attempt = 1, MAX_RETRIES do
        success, err = pcall(ProfileStore.UpdateAsync, ProfileStore, key, function()
            return TableUtils.deepCopy(profile)
        end)
        if success then
            break
        end
        warn(string.format("⚠️ Warn PlayerDataService save attempt %d failed for %d: %s", attempt, userId, tostring(err)))
        task.wait(RETRY_BACKOFF * attempt)
    end
    if success then
        log("💾 Save", string.format("Saved profile for %d", userId))
    end
end

function PlayerDataService:GetProfile(player)
    local profile = ProfileCache[player]
    if profile then
        return TableUtils.deepCopy(profile)
    end
    profile = loadProfile(player)
    if not profile then
        return nil
    end
    ProfileCache[player] = profile
    DirtyProfiles[player] = false
    log("🟢 Load", string.format("Profile loaded for %s", player.Name))
    return TableUtils.deepCopy(profile)
end

function PlayerDataService:Update(player, transform)
    local profile = ProfileCache[player]
    if not profile then
        profile = self:GetProfile(player)
    end
    if not profile then
        return nil
    end
    local updated = transform(profile)
    if updated ~= false then
        DirtyProfiles[player] = true
    end
    return TableUtils.deepCopy(profile)
end

function PlayerDataService:Flush(player)
    local profile = ProfileCache[player]
    if not profile then
        return
    end
    if DirtyProfiles[player] then
        saveProfile(player.UserId, profile)
        DirtyProfiles[player] = false
    end
end

function PlayerDataService:AwardCurrency(player, currencyType, amount)
    if amount <= 0 then
        return false
    end
    return self:Update(player, function(profile)
        local cap = GameConfig.getEconomy().currencyCaps[currencyType]
        profile.currency[currencyType] = MathUtils and MathUtils.clamp(profile.currency[currencyType] + amount, 0, cap) or profile.currency[currencyType] + amount
        return true
    end)
end

function PlayerDataService:GetReadOnly(player)
    local profile = ProfileCache[player]
    if not profile then
        return self:GetProfile(player)
    end
    return TableUtils.deepCopy(profile)
end

local dataServiceSingleton = setmetatable({}, PlayerDataService)

local function autosaveLoop()
    while task.wait(SAVE_INTERVAL) do
        for player, dirty in pairs(DirtyProfiles) do
            if dirty then
                dataServiceSingleton:Flush(player)
            end
        end
    end
end

task.spawn(autosaveLoop)

Players.PlayerAdded:Connect(function(player)
    dataServiceSingleton:GetProfile(player)
end)

local function release(player)
    dataServiceSingleton:Flush(player)
    ProfileCache[player] = nil
    DirtyProfiles[player] = nil
end

Players.PlayerRemoving:Connect(release)

game:BindToClose(function()
    for player, _ in pairs(ProfileCache) do
        release(player)
    end
end)

return dataServiceSingleton
