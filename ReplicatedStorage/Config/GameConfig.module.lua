--[[
    GameConfig.module.lua
    Purpose: Central tunable configuration for banners, pity, live flags, and economy numbers.
    API:
        local GameConfig = require(path.to.GameConfig)
        GameConfig.getActiveBanner("Standard") -> banner table
        GameConfig.getRollCost(bannerName, rollCount) -> { currency = "coins"|"gems", amount = number }
        GameConfig.getFreeRollCooldown(bannerName) -> seconds
        GameConfig.flags.LOG_ANALYTICS -> boolean
    Example:
        local config = require(GameConfig)
        local banner = config.getActiveBanner("Limited")
        if banner then
            print(banner.displayName, banner.cards)
        end
]]
local GameConfig = {}

local BANNERS = {
    Standard = {
        bannerId = "standard_core",
        displayName = "Standard Fusion",
        currencyType = "coins",
        rollCost = { single = 1000, multi = 9000 },
        freeCooldownSeconds = 2 * 60 * 60,
        pity = {
            soft = {
                srStart = 20,
                srIncrease = 0.005,
                urStart = 60,
                urIncrease = 0.001,
            },
            hard = {
                sr = 30,
                ur = 100,
            },
        },
        baseWeights = {
            Common = 70,
            Rare = 25,
            ["Super Rare"] = 4,
            ["Ultra Rare"] = 1,
        },
        cardPools = {
            Common = "core_common",
            Rare = "core_rare",
            ["Super Rare"] = "core_sr",
            ["Ultra Rare"] = "core_ur",
        },
        boostedSets = {
            "Nebula",
            "Prism",
        },
    },
    Limited = {
        bannerId = "limited_radiant",
        displayName = "Radiant Convergence",
        currencyType = "gems",
        rollCost = { single = 60, multi = 540 },
        freeCooldownSeconds = 60 * 60 * 6,
        pity = {
            soft = {
                srStart = 15,
                srIncrease = 0.0075,
                urStart = 45,
                urIncrease = 0.0015,
            },
            hard = {
                sr = 25,
                ur = 80,
            },
        },
        baseWeights = {
            Common = 60,
            Rare = 28,
            ["Super Rare"] = 8,
            ["Ultra Rare"] = 4,
        },
        cardPools = {
            Common = "limited_common",
            Rare = "limited_rare",
            ["Super Rare"] = "limited_sr",
            ["Ultra Rare"] = "limited_ur",
        },
        boostedSets = {
            "Radiant",
            "Mythos",
        },
    },
}

local FLAGS = {
    LOG_ANALYTICS = true,
    DOUBLE_SHARDS_WEEKEND = false,
    LIMITED_ACTIVE = true,
    BANNER_ROTATION_SECONDS = 4 * 60 * 60,
}

local ECONOMY = {
    currencyCaps = {
        coins = 9999999,
        gems = 99999,
    },
    duplicateShardRewards = {
        Common = 1,
        Rare = 5,
        ["Super Rare"] = 20,
        ["Ultra Rare"] = 100,
    },
    fuseCosts = {
        Common = { baseCoins = 500, shardCost = 5 },
        Rare = { baseCoins = 1500, shardCost = 15 },
        ["Super Rare"] = { baseCoins = 5000, shardCost = 60 },
        ["Ultra Rare"] = { baseCoins = 15000, shardCost = 200 },
    },
    levelPowerGrowth = {
        Common = 1.15,
        Rare = 1.2,
        ["Super Rare"] = 1.3,
        ["Ultra Rare"] = 1.4,
    },
    maxLuckBoost = 0.1,
    boosterDurations = {
        luck = 30 * 60,
        shards = 60 * 60,
    },
    shop = {
        gems = {
            { id = 101, name = "Gem Pouch", amount = 120, priceRobux = 49 },
            { id = 102, name = "Gem Stack", amount = 650, priceRobux = 249 },
            { id = 103, name = "Gem Trove", amount = 1500, priceRobux = 499 },
        },
        bundles = {
            {
                id = 201,
                name = "Starter Spark Pack",
                priceGems = 300,
                contents = {
                    coins = 15000,
                    shards = 30,
                    boosters = { luck = 1 },
                },
            },
            {
                id = 202,
                name = "Radiant Ascend",
                priceGems = 800,
                contents = {
                    coins = 60000,
                    shards = 100,
                    boosters = { shards = 1 },
                },
            },
        },
        boosts = {
            {
                id = 301,
                name = "Luck Charm 30m",
                priceGems = 120,
                type = "luck",
                duration = 30 * 60,
            },
            {
                id = 302,
                name = "Double Shards 1h",
                priceGems = 200,
                type = "shards",
                duration = 60 * 60,
            },
        },
    },
}

local QUESTS = {
    daily = {
        {
            id = "daily_roll_10",
            text = "Roll 10 times",
            target = 10,
            reward = { coins = 5000, shards = 5 },
        },
        {
            id = "daily_fuse_3",
            text = "Fuse 3 times",
            target = 3,
            reward = { coins = 3000 },
        },
    },
    weekly = {
        {
            id = "weekly_sr",
            text = "Pull 5 Super Rare cards",
            target = 5,
            reward = { gems = 120, shards = 20 },
        },
        {
            id = "weekly_playtime",
            text = "Play for 180 minutes",
            target = 180 * 60,
            reward = { coins = 8000, boosters = { luck = 1 } },
        },
    },
}

local ACHIEVEMENTS = {
    {
        id = "achv_first_roll",
        text = "First Roll!",
        target = 1,
        stat = "totalRolls",
        reward = { coins = 1000 },
        badgeId = 0, -- TODO: replace with actual badge ID
    },
    {
        id = "achv_sr_hunter",
        text = "Pull 50 Super Rares",
        target = 50,
        stat = "totalSuperRare",
        reward = { gems = 250, boosters = { luck = 1 } },
        badgeId = 0,
    },
    {
        id = "achv_powerhouse",
        text = "Reach 10000 total power",
        target = 10000,
        stat = "totalPower",
        reward = { gems = 500 },
        badgeId = 0,
    },
}

GameConfig.flags = FLAGS
GameConfig.banners = BANNERS
GameConfig.economy = ECONOMY
GameConfig.quests = QUESTS
GameConfig.achievements = ACHIEVEMENTS

function GameConfig.getActiveBanner(bannerName)
    local banner = BANNERS[bannerName]
    if bannerName == "Limited" and not FLAGS.LIMITED_ACTIVE then
        return nil
    end
    return banner
end

function GameConfig.getRollCost(bannerName, rollCount)
    local banner = GameConfig.getActiveBanner(bannerName)
    if not banner then
        return nil
    end
    local cost = rollCount == 10 and banner.rollCost.multi or banner.rollCost.single
    return {
        currency = banner.currencyType,
        amount = cost,
    }
end

function GameConfig.getFreeRollCooldown(bannerName)
    local banner = GameConfig.getActiveBanner(bannerName)
    return banner and banner.freeCooldownSeconds or math.huge
end

function GameConfig.getPityConfig(bannerName)
    local banner = GameConfig.getActiveBanner(bannerName)
    return banner and banner.pity or nil
end

function GameConfig.getEconomy()
    return ECONOMY
end

function GameConfig.getShop()
    return ECONOMY.shop
end

function GameConfig.getQuestConfig()
    return QUESTS
end

function GameConfig.getAchievementConfig()
    return ACHIEVEMENTS
end

return GameConfig
