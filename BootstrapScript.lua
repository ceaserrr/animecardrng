--[[
    BootstrapScript.lua
    Purpose: Command bar script to create instances, UI, and populate source code.
]]
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ServerScriptService = game:GetService('ServerScriptService')
local StarterPlayer = game:GetService('StarterPlayer')
local StarterGui = game:GetService('StarterGui')

local SOURCE_MAP = {
    ['ReplicatedStorage/Config/GameConfig.module.lua'] = [=[--[[
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
]=],
    ['ReplicatedStorage/Config/CardCatalog.module.lua'] = [=[--[[
    CardCatalog.module.lua
    Purpose: Defines all card/aura definitions, rarity pools, and helper utilities.
    API:
        local Catalog = require(CardCatalog)
        Catalog.getCard("card_id") -> table
        Catalog.getCardsForPool(poolId) -> array
        Catalog.getRarity(cardId) -> rarity
        Catalog.calculatePower(cardId, level) -> number
    Example:
        local cards = Catalog.getCardsForPool("core_sr")
        local randomCard = cards[math.random(#cards)]
]]
local MathUtils = require(script.Parent.Parent.Shared.MathUtils)
local TableUtils = require(script.Parent.Parent.Shared.TableUtils)

local CardCatalog = {}

local cards = {
    {
        id = "aura_ember_glow",
        displayName = "Ember Glow",
        rarity = "Common",
        weight = 12,
        basePower = 120,
        maxLevel = 10,
        iconImageId = "rbxassetid://12345601", -- TODO: replace placeholder
        auraVFX = { color = Color3.fromRGB(255, 140, 80), particles = "rbxassetid://10932100" },
        sets = { "Blaze", "Forge" },
    },
    {
        id = "aura_spring_whisper",
        displayName = "Spring Whisper",
        rarity = "Common",
        weight = 11,
        basePower = 110,
        maxLevel = 10,
        iconImageId = "rbxassetid://12345602",
        auraVFX = { color = Color3.fromRGB(80, 200, 120), particles = "rbxassetid://10932101" },
        sets = { "Bloom", "Serenity" },
    },
    {
        id = "aura_cobalt_flash",
        displayName = "Cobalt Flash",
        rarity = "Common",
        weight = 12,
        basePower = 130,
        maxLevel = 10,
        iconImageId = "rbxassetid://12345603",
        auraVFX = { color = Color3.fromRGB(60, 150, 255), particles = "rbxassetid://10932102" },
        sets = { "Surge", "Prism" },
    },
    {
        id = "aura_dusk_frost",
        displayName = "Dusk Frost",
        rarity = "Common",
        weight = 11,
        basePower = 125,
        maxLevel = 10,
        iconImageId = "rbxassetid://12345604",
        auraVFX = { color = Color3.fromRGB(160, 190, 255), particles = "rbxassetid://10932103" },
        sets = { "Frost", "Twilight" },
    },
    {
        id = "aura_gale_ribbon",
        displayName = "Gale Ribbon",
        rarity = "Common",
        weight = 10,
        basePower = 135,
        maxLevel = 10,
        iconImageId = "rbxassetid://12345605",
        auraVFX = { color = Color3.fromRGB(180, 220, 255), particles = "rbxassetid://10932104" },
        sets = { "Sky", "Prism" },
    },
    {
        id = "aura_sandstorm",
        displayName = "Sandstorm Veil",
        rarity = "Common",
        weight = 12,
        basePower = 115,
        maxLevel = 10,
        iconImageId = "rbxassetid://12345606",
        auraVFX = { color = Color3.fromRGB(230, 200, 150), particles = "rbxassetid://10932105" },
        sets = { "Dune", "Warden" },
    },
    {
        id = "aura_verdant_ring",
        displayName = "Verdant Ring",
        rarity = "Common",
        weight = 10,
        basePower = 140,
        maxLevel = 10,
        iconImageId = "rbxassetid://12345607",
        auraVFX = { color = Color3.fromRGB(120, 255, 160), particles = "rbxassetid://10932106" },
        sets = { "Bloom", "Guardian" },
    },
    {
        id = "aura_sonar_wave",
        displayName = "Sonar Wave",
        rarity = "Common",
        weight = 9,
        basePower = 145,
        maxLevel = 10,
        iconImageId = "rbxassetid://12345608",
        auraVFX = { color = Color3.fromRGB(80, 180, 255), particles = "rbxassetid://10932107" },
        sets = { "Abyss", "Surge" },
    },
    {
        id = "aura_emberwing",
        displayName = "Emberwing",
        rarity = "Common",
        weight = 9,
        basePower = 150,
        maxLevel = 10,
        iconImageId = "rbxassetid://12345609",
        auraVFX = { color = Color3.fromRGB(255, 120, 50), particles = "rbxassetid://10932108" },
        sets = { "Blaze", "Wing" },
    },
    {
        id = "aura_mist_motif",
        displayName = "Mist Motif",
        rarity = "Common",
        weight = 8,
        basePower = 155,
        maxLevel = 10,
        iconImageId = "rbxassetid://12345610",
        auraVFX = { color = Color3.fromRGB(200, 230, 255), particles = "rbxassetid://10932109" },
        sets = { "Twilight", "Serenity" },
    },
    {
        id = "aura_quartz_loop",
        displayName = "Quartz Loop",
        rarity = "Rare",
        weight = 6,
        basePower = 220,
        maxLevel = 15,
        iconImageId = "rbxassetid://12345611",
        auraVFX = { color = Color3.fromRGB(180, 140, 255), particles = "rbxassetid://10932110" },
        sets = { "Prism", "Warden" },
    },
    {
        id = "aura_auric_stream",
        displayName = "Auric Stream",
        rarity = "Rare",
        weight = 6,
        basePower = 230,
        maxLevel = 15,
        iconImageId = "rbxassetid://12345612",
        auraVFX = { color = Color3.fromRGB(255, 210, 100), particles = "rbxassetid://10932111" },
        sets = { "Radiant", "Forge" },
    },
    {
        id = "aura_crystal_veil",
        displayName = "Crystal Veil",
        rarity = "Rare",
        weight = 5,
        basePower = 240,
        maxLevel = 15,
        iconImageId = "rbxassetid://12345613",
        auraVFX = { color = Color3.fromRGB(120, 220, 255), particles = "rbxassetid://10932112" },
        sets = { "Prism", "Abyss" },
    },
    {
        id = "aura_blossom_dance",
        displayName = "Blossom Dance",
        rarity = "Rare",
        weight = 5,
        basePower = 235,
        maxLevel = 15,
        iconImageId = "rbxassetid://12345614",
        auraVFX = { color = Color3.fromRGB(255, 150, 200), particles = "rbxassetid://10932113" },
        sets = { "Bloom", "Serenity" },
    },
    {
        id = "aura_meteor_trail",
        displayName = "Meteor Trail",
        rarity = "Rare",
        weight = 4,
        basePower = 250,
        maxLevel = 15,
        iconImageId = "rbxassetid://12345615",
        auraVFX = { color = Color3.fromRGB(255, 120, 80), particles = "rbxassetid://10932114" },
        sets = { "Blaze", "Sky" },
    },
    {
        id = "aura_tidal_hearts",
        displayName = "Tidal Hearts",
        rarity = "Rare",
        weight = 4,
        basePower = 255,
        maxLevel = 15,
        iconImageId = "rbxassetid://12345616",
        auraVFX = { color = Color3.fromRGB(80, 200, 255), particles = "rbxassetid://10932115" },
        sets = { "Abyss", "Guardian" },
    },
    {
        id = "aura_star_ribbon",
        displayName = "Star Ribbon",
        rarity = "Rare",
        weight = 4,
        basePower = 260,
        maxLevel = 15,
        iconImageId = "rbxassetid://12345617",
        auraVFX = { color = Color3.fromRGB(200, 200, 255), particles = "rbxassetid://10932116" },
        sets = { "Celestial", "Prism" },
    },
    {
        id = "aura_night_bloom",
        displayName = "Night Bloom",
        rarity = "Rare",
        weight = 3,
        basePower = 265,
        maxLevel = 15,
        iconImageId = "rbxassetid://12345618",
        auraVFX = { color = Color3.fromRGB(150, 120, 255), particles = "rbxassetid://10932117" },
        sets = { "Twilight", "Mythos" },
    },
    {
        id = "aura_geo_pulse",
        displayName = "Geo Pulse",
        rarity = "Rare",
        weight = 3,
        basePower = 270,
        maxLevel = 15,
        iconImageId = "rbxassetid://12345619",
        auraVFX = { color = Color3.fromRGB(200, 170, 120), particles = "rbxassetid://10932118" },
        sets = { "Warden", "Forge" },
    },
    {
        id = "aura_coral_crest",
        displayName = "Coral Crest",
        rarity = "Rare",
        weight = 3,
        basePower = 275,
        maxLevel = 15,
        iconImageId = "rbxassetid://12345620",
        auraVFX = { color = Color3.fromRGB(255, 180, 160), particles = "rbxassetid://10932119" },
        sets = { "Abyss", "Bloom" },
    },
    {
        id = "aura_lumen_spire",
        displayName = "Lumen Spire",
        rarity = "Super Rare",
        weight = 1.5,
        basePower = 380,
        maxLevel = 20,
        iconImageId = "rbxassetid://12345621",
        auraVFX = { color = Color3.fromRGB(255, 240, 200), particles = "rbxassetid://10932120" },
        sets = { "Radiant", "Celestial" },
    },
    {
        id = "aura_storm_regalia",
        displayName = "Storm Regalia",
        rarity = "Super Rare",
        weight = 1.5,
        basePower = 395,
        maxLevel = 20,
        iconImageId = "rbxassetid://12345622",
        auraVFX = { color = Color3.fromRGB(120, 200, 255), particles = "rbxassetid://10932121" },
        sets = { "Sky", "Guardian" },
    },
    {
        id = "aura_void_lattice",
        displayName = "Void Lattice",
        rarity = "Super Rare",
        weight = 1.2,
        basePower = 410,
        maxLevel = 20,
        iconImageId = "rbxassetid://12345623",
        auraVFX = { color = Color3.fromRGB(90, 0, 140), particles = "rbxassetid://10932122" },
        sets = { "Abyss", "Mythos" },
    },
    {
        id = "aura_solaris_arc",
        displayName = "Solaris Arc",
        rarity = "Super Rare",
        weight = 1.1,
        basePower = 420,
        maxLevel = 20,
        iconImageId = "rbxassetid://12345624",
        auraVFX = { color = Color3.fromRGB(255, 200, 120), particles = "rbxassetid://10932123" },
        sets = { "Radiant", "Forge" },
    },
    {
        id = "aura_nebula_veil",
        displayName = "Nebula Veil",
        rarity = "Super Rare",
        weight = 1,
        basePower = 430,
        maxLevel = 20,
        iconImageId = "rbxassetid://12345625",
        auraVFX = { color = Color3.fromRGB(160, 120, 255), particles = "rbxassetid://10932124" },
        sets = { "Nebula", "Celestial" },
    },
    {
        id = "aura_tidal_ward",
        displayName = "Tidal Ward",
        rarity = "Super Rare",
        weight = 0.9,
        basePower = 440,
        maxLevel = 20,
        iconImageId = "rbxassetid://12345626",
        auraVFX = { color = Color3.fromRGB(70, 160, 230), particles = "rbxassetid://10932125" },
        sets = { "Guardian", "Abyss" },
    },
    {
        id = "aura_singularity",
        displayName = "Singularity Halo",
        rarity = "Super Rare",
        weight = 0.8,
        basePower = 455,
        maxLevel = 20,
        iconImageId = "rbxassetid://12345627",
        auraVFX = { color = Color3.fromRGB(30, 30, 80), particles = "rbxassetid://10932126" },
        sets = { "Mythos", "Void" },
    },
    {
        id = "aura_prism_break",
        displayName = "Prism Break",
        rarity = "Super Rare",
        weight = 0.7,
        basePower = 465,
        maxLevel = 20,
        iconImageId = "rbxassetid://12345628",
        auraVFX = { color = Color3.fromRGB(255, 255, 255), particles = "rbxassetid://10932127" },
        sets = { "Prism", "Radiant" },
    },
    {
        id = "aura_zenith_crown",
        displayName = "Zenith Crown",
        rarity = "Ultra Rare",
        weight = 0.25,
        basePower = 620,
        maxLevel = 25,
        iconImageId = "rbxassetid://12345629",
        auraVFX = { color = Color3.fromRGB(255, 240, 80), particles = "rbxassetid://10932128" },
        sets = { "Celestial", "Radiant" },
    },
    {
        id = "aura_lucid_torrent",
        displayName = "Lucid Torrent",
        rarity = "Ultra Rare",
        weight = 0.22,
        basePower = 640,
        maxLevel = 25,
        iconImageId = "rbxassetid://12345630",
        auraVFX = { color = Color3.fromRGB(150, 220, 255), particles = "rbxassetid://10932129" },
        sets = { "Abyss", "Mythos" },
    },
    {
        id = "aura_inferno_march",
        displayName = "Inferno March",
        rarity = "Ultra Rare",
        weight = 0.2,
        basePower = 660,
        maxLevel = 25,
        iconImageId = "rbxassetid://12345631",
        auraVFX = { color = Color3.fromRGB(255, 90, 50), particles = "rbxassetid://10932130" },
        sets = { "Blaze", "Forge" },
    },
    {
        id = "aura_eternal_bloom",
        displayName = "Eternal Bloom",
        rarity = "Ultra Rare",
        weight = 0.18,
        basePower = 675,
        maxLevel = 25,
        iconImageId = "rbxassetid://12345632",
        auraVFX = { color = Color3.fromRGB(255, 200, 220), particles = "rbxassetid://10932131" },
        sets = { "Bloom", "Serenity" },
    },
    {
        id = "aura_void_empress",
        displayName = "Void Empress",
        rarity = "Ultra Rare",
        weight = 0.15,
        basePower = 690,
        maxLevel = 25,
        iconImageId = "rbxassetid://12345633",
        auraVFX = { color = Color3.fromRGB(110, 0, 140), particles = "rbxassetid://10932132" },
        sets = { "Void", "Mythos" },
    },
    {
        id = "aura_radiant_myth",
        displayName = "Radiant Myth",
        rarity = "Ultra Rare",
        weight = 0.14,
        basePower = 705,
        maxLevel = 25,
        iconImageId = "rbxassetid://12345634",
        auraVFX = { color = Color3.fromRGB(255, 220, 170), particles = "rbxassetid://10932133" },
        sets = { "Radiant", "Mythos" },
    },
    {
        id = "aura_cosmic_lattice",
        displayName = "Cosmic Lattice",
        rarity = "Ultra Rare",
        weight = 0.12,
        basePower = 720,
        maxLevel = 25,
        iconImageId = "rbxassetid://12345635",
        auraVFX = { color = Color3.fromRGB(180, 150, 255), particles = "rbxassetid://10932134" },
        sets = { "Nebula", "Celestial" },
    },
    {
        id = "aura_spectrum_guard",
        displayName = "Spectrum Guard",
        rarity = "Ultra Rare",
        weight = 0.1,
        basePower = 740,
        maxLevel = 25,
        iconImageId = "rbxassetid://12345636",
        auraVFX = { color = Color3.fromRGB(255, 255, 180), particles = "rbxassetid://10932135" },
        sets = { "Prism", "Guardian" },
    },
    {
        id = "aura_aurora_conduit",
        displayName = "Aurora Conduit",
        rarity = "Super Rare",
        weight = 0.9,
        basePower = 450,
        maxLevel = 20,
        iconImageId = "rbxassetid://12345637",
        auraVFX = { color = Color3.fromRGB(120, 220, 255), particles = "rbxassetid://10932136" },
        sets = { "Sky", "Nebula" },
    },
    {
        id = "aura_ember_symphony",
        displayName = "Ember Symphony",
        rarity = "Super Rare",
        weight = 0.85,
        basePower = 460,
        maxLevel = 20,
        iconImageId = "rbxassetid://12345638",
        auraVFX = { color = Color3.fromRGB(255, 140, 90), particles = "rbxassetid://10932137" },
        sets = { "Blaze", "Radiant" },
    },
}

local pools = {
    core_common = {
        "aura_ember_glow",
        "aura_spring_whisper",
        "aura_cobalt_flash",
        "aura_dusk_frost",
        "aura_gale_ribbon",
        "aura_sandstorm",
        "aura_verdant_ring",
        "aura_sonar_wave",
        "aura_emberwing",
        "aura_mist_motif",
    },
    core_rare = {
        "aura_quartz_loop",
        "aura_auric_stream",
        "aura_crystal_veil",
        "aura_blossom_dance",
        "aura_meteor_trail",
        "aura_tidal_hearts",
        "aura_star_ribbon",
        "aura_night_bloom",
        "aura_geo_pulse",
        "aura_coral_crest",
    },
    core_sr = {
        "aura_lumen_spire",
        "aura_storm_regalia",
        "aura_void_lattice",
        "aura_solaris_arc",
        "aura_nebula_veil",
        "aura_tidal_ward",
        "aura_singularity",
        "aura_prism_break",
        "aura_aurora_conduit",
        "aura_ember_symphony",
    },
    core_ur = {
        "aura_zenith_crown",
        "aura_lucid_torrent",
        "aura_inferno_march",
        "aura_eternal_bloom",
        "aura_void_empress",
        "aura_radiant_myth",
        "aura_cosmic_lattice",
        "aura_spectrum_guard",
    },
    limited_common = {
        "aura_spring_whisper",
        "aura_cobalt_flash",
        "aura_verdant_ring",
        "aura_mist_motif",
    },
    limited_rare = {
        "aura_meteor_trail",
        "aura_tidal_hearts",
        "aura_star_ribbon",
        "aura_coral_crest",
    },
    limited_sr = {
        "aura_nebula_veil",
        "aura_aurora_conduit",
        "aura_ember_symphony",
    },
    limited_ur = {
        "aura_zenith_crown",
        "aura_radiant_myth",
        "aura_cosmic_lattice",
    },
}

local rarityLookup = {}
local cardById = {}

for _, card in ipairs(cards) do
    cardById[card.id] = card
    rarityLookup[card.id] = card.rarity
end

function CardCatalog.getCard(cardId)
    return cardById[cardId]
end

function CardCatalog.getCards()
    return cards
end

function CardCatalog.getCardsForPool(poolId)
    local pool = pools[poolId]
    if not pool then
        return {}
    end
    local results = {}
    for _, cardId in ipairs(pool) do
        local card = cardById[cardId]
        if card then
            table.insert(results, card)
        end
    end
    return results
end

function CardCatalog.getRarity(cardId)
    return rarityLookup[cardId]
end

function CardCatalog.getWeight(cardId)
    local card = cardById[cardId]
    return card and card.weight or 0
end

function CardCatalog.calculatePower(cardId, level)
    local card = cardById[cardId]
    if not card then
        return 0
    end
    local config = require(script.Parent.GameConfig)
    local growth = config.getEconomy().levelPowerGrowth[card.rarity] or 1
    local clampedLevel = MathUtils.clamp(level or 1, 1, card.maxLevel)
    local multiplier = growth ^ (clampedLevel - 1)
    return math.floor(card.basePower * multiplier)
end

function CardCatalog.deepCopyCard(cardId)
    local card = cardById[cardId]
    if not card then
        return nil
    end
    return TableUtils.deepCopy(card)
end

function CardCatalog.getSets(cardId)
    local card = cardById[cardId]
    return card and card.sets or {}
end

function CardCatalog.getPools()
    return TableUtils.deepCopy(pools)
end

return CardCatalog
]=],
    ['ReplicatedStorage/Shared/TableUtils.module.lua'] = [=[--[[
    TableUtils.module.lua
    Purpose: Utility helpers for table cloning and formatting.
    API:
        TableUtils.deepCopy(tbl)
        TableUtils.prettyPrint(tbl)
        TableUtils.merge(destination, source)
    Example:
        local copy = TableUtils.deepCopy(original)
]]
local TableUtils = {}

local function _deepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for key, innerValue in pairs(value) do
        copy[_deepCopy(key, seen)] = _deepCopy(innerValue, seen)
    end
    return copy
end

function TableUtils.deepCopy(tbl)
    return _deepCopy(tbl, {})
end

function TableUtils.prettyPrint(tbl, indent)
    indent = indent or 0
    local pad = string.rep(" ", indent)
    if type(tbl) ~= "table" then
        return tostring(tbl)
    end
    local parts = {"{"}
    for key, value in pairs(tbl) do
        local keyStr = string.format("%s[%s] = ", pad .. "  ", tostring(key))
        if type(value) == "table" then
            table.insert(parts, keyStr .. TableUtils.prettyPrint(value, indent + 2))
        else
            table.insert(parts, keyStr .. tostring(value))
        end
    end
    table.insert(parts, pad .. "}")
    return table.concat(parts, "\n")
end

function TableUtils.merge(destination, source)
    for key, value in pairs(source) do
        destination[key] = value
    end
    return destination
end

return TableUtils
]=],
    ['ReplicatedStorage/Shared/MathUtils.module.lua'] = [=[--[[
    MathUtils.module.lua
    Purpose: RNG helpers and math utilities for gacha calculations.
    API:
        MathUtils.weightedChoice(weightedList)
        MathUtils.clamp(value, min, max)
        MathUtils.round(num, precision)
    Example:
        local cardId = MathUtils.weightedChoice({ { weight = 70, value = "Common" } })
]]
local MathUtils = {}

function MathUtils.clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    elseif value > maxValue then
        return maxValue
    end
    return value
end

function MathUtils.round(num, precision)
    precision = precision or 0
    local mult = 10 ^ precision
    return math.floor(num * mult + 0.5) / mult
end

function MathUtils.weightedChoice(weightedList, rng)
    rng = rng or Random.new()
    local totalWeight = 0
    for _, entry in ipairs(weightedList) do
        totalWeight += entry.weight
    end
    if totalWeight <= 0 then
        return nil
    end
    local pivot = rng:NextNumber(0, totalWeight)
    local accum = 0
    for _, entry in ipairs(weightedList) do
        accum += entry.weight
        if pivot <= accum then
            return entry.value
        end
    end
    return weightedList[#weightedList] and weightedList[#weightedList].value or nil
end

return MathUtils
]=],
    ['ServerScriptService/PlayerDataService.server.lua'] = [=[--[[
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
]=],
    ['ServerScriptService/InventoryService.server.lua'] = [=[--[[
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
]=],
    ['ServerScriptService/RollService.server.lua'] = [=[--[[
    RollService.server.lua
    Purpose: Handle roll requests, pity logic, and server authoritative RNG.
    API: (event-based)
        RemoteEvent RollRequest expects (bannerName: string, rollCount: number)
        RemoteEvent RollResult returns table with summary
    Example:
        RollRequest.OnServerEvent -> RollService handles.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config", 5):WaitForChild("GameConfig", 5))
local CardCatalog = require(ReplicatedStorage:WaitForChild("Config", 5):WaitForChild("CardCatalog", 5))
local MathUtils = require(ReplicatedStorage:WaitForChild("Shared", 5):WaitForChild("MathUtils", 5))
local TableUtils = require(ReplicatedStorage:WaitForChild("Shared", 5):WaitForChild("TableUtils", 5))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))
local AchievementService = require(script.Parent:WaitForChild("AchievementService"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
local RollRequest = Remotes:WaitForChild("RollRequest", 5)
local RollResult = Remotes:WaitForChild("RollResult", 5)
local GetProfile = Remotes:WaitForChild("GetProfile", 5)

local RATE_LIMIT_PER_SEC = 3
local RATE_LIMIT_BURST = 5
local TOKEN_REPLENISH_INTERVAL = 1 / RATE_LIMIT_PER_SEC

local rateBuckets = {}

local rng = Random.new()

local function log(message)
    print("🎲 Roll " .. message)
end

local function getBucket(player)
    local bucket = rateBuckets[player]
    if not bucket then
        bucket = {
            tokens = RATE_LIMIT_BURST,
            last = tick(),
        }
        rateBuckets[player] = bucket
    end
    local now = tick()
    local delta = now - bucket.last
    local refill = math.floor(delta / TOKEN_REPLENISH_INTERVAL)
    if refill > 0 then
        bucket.tokens = math.min(RATE_LIMIT_BURST, bucket.tokens + refill)
        bucket.last = now
    end
    return bucket
end

local function getLuckBoost(profile)
    local boosters = profile.boosters or {}
    local luck = boosters.luck
    if luck and luck.expiresAt and luck.expiresAt > os.time() then
        return math.clamp(luck.magnitude or 0.05, 0, GameConfig.getEconomy().maxLuckBoost)
    end
    return 0
end

local function chooseRarity(bannerName, profile, pityState)
    local banner = GameConfig.getActiveBanner(bannerName)
    local pityConfig = GameConfig.getPityConfig(bannerName)
    local weights = TableUtils.deepCopy(banner.baseWeights)
    -- Hard pity check
    if pityState.pullsSinceUR + 1 >= pityConfig.hard.ur then
        return "Ultra Rare", true
    elseif pityState.pullsSinceSR + 1 >= pityConfig.hard.sr then
        return "Super Rare", true
    end
    -- Soft pity adjustments
    if pityState.pullsSinceSR >= pityConfig.soft.srStart then
        local extraRolls = pityState.pullsSinceSR - pityConfig.soft.srStart + 1
        weights["Super Rare"] += extraRolls * (pityConfig.soft.srIncrease * 100)
    end
    if pityState.pullsSinceUR >= pityConfig.soft.urStart then
        local extraRolls = pityState.pullsSinceUR - pityConfig.soft.urStart + 1
        weights["Ultra Rare"] += extraRolls * (pityConfig.soft.urIncrease * 100)
    end
    local luckBoost = getLuckBoost(profile)
    if luckBoost > 0 then
        weights["Super Rare"] *= (1 + luckBoost)
        weights["Ultra Rare"] *= (1 + luckBoost)
    end
    local weightedList = {}
    for rarity, weight in pairs(weights) do
        table.insert(weightedList, { weight = weight, value = rarity })
    end
    local rarity = MathUtils.weightedChoice(weightedList, rng)
    return rarity or "Common", false
end

local function chooseCard(banner, rarity)
    local poolId = banner.cardPools[rarity]
    local cards = CardCatalog.getCardsForPool(poolId)
    local weighted = {}
    for _, card in ipairs(cards) do
        table.insert(weighted, { weight = card.weight, value = card.id })
    end
    return MathUtils.weightedChoice(weighted, rng)
end

local function adjustPity(profile, bannerName, rarity)
    local pity = profile.pity[bannerName]
    if not pity then
        pity = { pullsSinceSR = 0, pullsSinceUR = 0 }
        profile.pity[bannerName] = pity
    end
    if rarity == "Super Rare" or rarity == "Ultra Rare" then
        pity.pullsSinceSR = 0
    else
        pity.pullsSinceSR += 1
    end
    if rarity == "Ultra Rare" then
        pity.pullsSinceUR = 0
    else
        pity.pullsSinceUR += 1
    end
end

local function ensureProfileDefaults(profile)
    profile.cooldowns = profile.cooldowns or { freeRoll = { Standard = 0, Limited = 0 } }
    profile.cooldowns.freeRoll = profile.cooldowns.freeRoll or { Standard = 0, Limited = 0 }
    profile.pity.Standard = profile.pity.Standard or { pullsSinceSR = 0, pullsSinceUR = 0 }
    profile.pity.Limited = profile.pity.Limited or { pullsSinceSR = 0, pullsSinceUR = 0 }
    profile.inventory = profile.inventory or {}
    profile.stats = profile.stats or { totalRolls = 0, bestRarity = "Common", totalPower = 0, totalSuperRare = 0 }
end

local function processRoll(player, bannerName, rollCount)
    local summary = {
        banner = bannerName,
        rolls = {},
        cost = nil,
        freeRollUsed = false,
    }
    local success = false
    PlayerDataService:Update(player, function(profile)
        ensureProfileDefaults(profile)
        local banner = GameConfig.getActiveBanner(bannerName)
        if not banner then
            return false
        end
        rollCount = rollCount == 10 and 10 or 1
        local cost = GameConfig.getRollCost(bannerName, rollCount)
        local now = os.time()
        local freeReady = profile.cooldowns.freeRoll[bannerName] and profile.cooldowns.freeRoll[bannerName] <= now
        summary.freeRollUsed = freeReady and rollCount == 1
        if summary.freeRollUsed then
            -- ok
        else
            if not cost then
                return false
            end
            local currencyBalance = profile.currency[cost.currency]
            if currencyBalance < cost.amount then
                summary.error = "insufficient_currency"
                return false
            end
            profile.currency[cost.currency] -= cost.amount
            summary.cost = { currency = cost.currency, amount = cost.amount }
        end
        if rollCount == 1 then
            profile.cooldowns.freeRoll[bannerName] = now + GameConfig.getFreeRollCooldown(bannerName)
        end
        for i = 1, rollCount do
            local pityState = profile.pity[bannerName]
            local rarity, hardPity = chooseRarity(bannerName, profile, pityState)
            local cardId = chooseCard(banner, rarity)
            if not cardId then
                summary.error = "no_card"
                return false
            end
            local reward = InventoryService.applyAddToProfile(profile, cardId)
            adjustPity(profile, bannerName, rarity)
            table.insert(summary.rolls, {
                cardId = cardId,
                rarity = rarity,
                hardPity = hardPity,
                reward = reward,
            })
        end
        success = true
        return true
    end)
    return success, summary
end

local function handleRoll(player, bannerName, rollCount)
    local bucket = getBucket(player)
    if bucket.tokens <= 0 then
        return
    end
    bucket.tokens -= 1
    local success, summary = processRoll(player, bannerName, rollCount)
    if success then
        log(string.format("%s rolled %d on %s", player.Name, #summary.rolls, bannerName))
        QuestService.recordAction(player, "roll", #summary.rolls)
        for _, roll in ipairs(summary.rolls) do
            QuestService.recordAction(player, "rarity", 1, { rarity = roll.rarity })
            LeaderboardService.updateRarity(player, roll.rarity)
        end
        AchievementService.evaluate(player)
        LeaderboardService.updatePower(player)
        RollResult:FireClient(player, {
            type = "roll",
            summary = summary,
        })
    else
        RollResult:FireClient(player, {
            type = "roll",
            success = false,
            error = summary and summary.error,
        })
    end
end

RollRequest.OnServerEvent:Connect(function(player, bannerName, rollCount)
    if typeof(player) ~= "Instance" or player.Parent ~= Players then
        return
    end
    if type(bannerName) ~= "string" then
        return
    end
    if type(rollCount) ~= "number" then
        rollCount = 1
    end
    handleRoll(player, bannerName, rollCount)
end)

GetProfile.OnServerInvoke = function(player)
    return PlayerDataService:GetReadOnly(player)
end

Players.PlayerRemoving:Connect(function(player)
    rateBuckets[player] = nil
end)

return true
]=],
    ['ServerScriptService/EconomyService.server.lua'] = [=[--[[
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
]=],
    ['ServerScriptService/QuestService.server.lua'] = [=[--[[
    QuestService.server.lua
    Purpose: Manage daily and weekly quest progress and reward claims.
    API:
        QuestService.recordAction(player, action, amount)
        RemoteFunction/Events handled internally for quest data.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Config", 5):WaitForChild("GameConfig", 5))
local TableUtils = require(ReplicatedStorage:WaitForChild("Shared", 5):WaitForChild("TableUtils", 5))

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
]=],
    ['ServerScriptService/AchievementService.server.lua'] = [=[--[[
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
]=],
    ['ServerScriptService/LeaderboardService.server.lua'] = [=[--[[
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
]=],
    ['ServerScriptService/LiveOpsService.server.lua'] = [=[--[[
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
]=],
    ['ServerScriptService/AdminCommandService.server.lua'] = [=[--[[
    AdminCommandService.server.lua
    Purpose: Provide simple dev utilities for testing (grant currency, force rarity, reset data).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local RollService = require(script.Parent:WaitForChild("RollService"))
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
]=],
    ['ServerScriptService/ServerMain.server.lua'] = [=[--[[
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
]=],
    ['StarterPlayer/StarterPlayerScripts/ClientUIController.client.lua'] = [=[--[[
    ClientUIController.client.lua
    Purpose: Handle UI wiring for roll, inventory, shop, quests, and settings.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local localPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
local RollRequest = Remotes:WaitForChild("RollRequest", 5)
local RollResult = Remotes:WaitForChild("RollResult", 5)
local GetInventory = Remotes:WaitForChild("GetInventory", 5)
local GetProfile = Remotes:WaitForChild("GetProfile", 5)
local GetShop = Remotes:WaitForChild("GetShop", 5)
local PurchaseRequest = Remotes:WaitForChild("PurchaseRequest", 5)
local QuestClaimRequest = Remotes:WaitForChild("QuestClaimRequest", 5)
local CardCatalog = require(ReplicatedStorage:WaitForChild("Config", 5):WaitForChild("CardCatalog", 5))

local MainUI = localPlayer:WaitForChild("PlayerGui", 5):WaitForChild("MainUI", 5)
local InventoryUI = localPlayer.PlayerGui:WaitForChild("InventoryUI", 5)
local ShopUI = localPlayer.PlayerGui:WaitForChild("ShopUI", 5)
local QuestsUI = localPlayer.PlayerGui:WaitForChild("QuestsUI", 5)
local AchievementsUI = localPlayer.PlayerGui:WaitForChild("AchievementsUI", 5)
local SettingsUI = localPlayer.PlayerGui:WaitForChild("SettingsUI", 5)

local RollPanel = MainUI:WaitForChild("RollPanel", 5)
local RollButton = RollPanel:WaitForChild("RollButton", 5)
local MultiRollButton = RollPanel:WaitForChild("MultiRollButton", 5)
local BannerSelector = RollPanel:WaitForChild("BannerSelector", 5)
local BannerInfoLabel = RollPanel:WaitForChild("BannerInfo", 5)
local ResultLabel = RollPanel:WaitForChild("ResultLabel", 5)
local FreeTimerLabel = RollPanel:WaitForChild("FreeTimer", 5)

local InventoryFrame = InventoryUI:WaitForChild("InventoryFrame", 5)
local InventoryList = InventoryFrame:WaitForChild("ItemList", 5)
local ItemTemplate = InventoryList:WaitForChild("ItemTemplate", 5)
ItemTemplate.Visible = false
local ItemDetails = InventoryFrame:WaitForChild("ItemDetails", 5)
local EquipButton = ItemDetails:WaitForChild("EquipButton", 5)
local FuseButton = ItemDetails:WaitForChild("FuseButton", 5)
local LockToggle = ItemDetails:WaitForChild("LockToggle", 5)

local ShopFrame = ShopUI:WaitForChild("ShopFrame", 5)
local ShopTabs = ShopFrame:WaitForChild("Tabs", 5)
local ShopContent = ShopFrame:WaitForChild("Content", 5)
local ShopTemplate = ShopContent:WaitForChild("ShopItemTemplate", 5)
ShopTemplate.Visible = false

local QuestsFrame = QuestsUI:WaitForChild("QuestsFrame", 5)
local QuestList = QuestsFrame:WaitForChild("QuestList", 5)
local QuestTemplate = QuestList:WaitForChild("QuestTemplate", 5)
QuestTemplate.Visible = false

local AchievementsFrame = AchievementsUI:WaitForChild("AchievementsFrame", 5)
local AchvList = AchievementsFrame:WaitForChild("AchvList", 5)
local AchvTemplate = AchvList:WaitForChild("AchvTemplate", 5)
AchvTemplate.Visible = false

local SettingsFrame = SettingsUI:WaitForChild("SettingsFrame", 5)
local SettingsTemplate = SettingsFrame:WaitForChild("SettingTemplate", 5)
SettingsTemplate.Visible = false

local currentBanner = "Standard"
local selectedItemId = nil
local inventoryState = {}

local rarityColors = {
    Common = Color3.fromRGB(120, 120, 120),
    Rare = Color3.fromRGB(70, 160, 255),
    ["Super Rare"] = Color3.fromRGB(200, 120, 255),
    ["Ultra Rare"] = Color3.fromRGB(255, 180, 60),
}

local function setButtonInteractable(button, state)
    button.AutoButtonColor = state
    button.Active = state
end

local function updateBannerInfo()
    local shop = GetShop:InvokeServer()
    BannerInfoLabel.Text = string.format("%s Banner\nStandard Cost: 1000 Coins\nLimited Cost: 60 Gems", currentBanner)
end

local function updateRollButtons(profile)
    local cost = ({
        Standard = "Coins 1k",
        Limited = "Gems 60",
    })[currentBanner] or ""
    RollButton.Text = "Roll (" .. cost .. ")"
end

local function createListEntry(template, parent)
    local clone = template:Clone()
    clone.Visible = true
    clone.Parent = parent
    return clone
end

local function clearChildren(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("GuiObject") and child ~= ItemTemplate and child ~= ShopTemplate and child ~= QuestTemplate and child ~= AchvTemplate and child ~= SettingsTemplate then
            child:Destroy()
        end
    end
end

local function populateInventory()
    local data = GetInventory:InvokeServer()
    inventoryState = data
    clearChildren(InventoryList)
    for cardId, entry in pairs(data) do
        local item = createListEntry(ItemTemplate, InventoryList)
        item.Name = cardId
        local def = CardCatalog.getCard(cardId)
        item.Title.Text = def and def.displayName or cardId
        item.Count.Text = "x" .. entry.count
        item.Level.Text = "Lv." .. entry.level
        local rarity = def and def.rarity or "Common"
        item.Rarity.Text = rarity
        item.Rarity.TextColor3 = rarityColors[rarity]
        item.MouseButton1Click:Connect(function()
            selectedItemId = cardId
            ItemDetails.CardName.Text = def and def.displayName or cardId
            ItemDetails.LevelLabel.Text = "Level " .. entry.level
            ItemDetails.CountLabel.Text = "Count " .. entry.count
            ItemDetails.ShardsLabel.Text = "Shards " .. entry.shards
        end)
    end
end

local function handleRollSummary(summary)
    local last = summary.rolls[#summary.rolls]
    if last then
        local text = string.format("Pulled: %s [%s] +%d shards", last.cardId, last.rarity, last.reward and last.reward.shardsGranted or 0)
        ResultLabel.Text = text
        ResultLabel.TextColor3 = rarityColors[last.rarity] or Color3.new(1, 1, 1)
        local flash = TweenService:Create(ResultLabel, TweenInfo.new(0.3), { TextTransparency = 0 })
        flash:Play()
    end
    populateInventory()
end

local function refreshQuests(profile)
    clearChildren(QuestList)
    local config = require(ReplicatedStorage.Config.GameConfig).getQuestConfig()
    for typeName, quests in pairs({ daily = config.daily, weekly = config.weekly }) do
        for _, quest in ipairs(quests) do
            local entry = createListEntry(QuestTemplate, QuestList)
            entry.Title.Text = quest.text .. " (" .. typeName .. ")"
            local state = profile.quests and profile.quests[typeName] and profile.quests[typeName][quest.id]
            local progress = state and state.progress or 0
            entry.Progress.Text = string.format("%d / %d", progress, quest.target)
            entry.ClaimButton.Text = state and state.claimed and "Claimed" or "Claim"
            entry.ClaimButton.AutoButtonColor = not (state and state.claimed)
            entry.ClaimButton.MouseButton1Click:Connect(function()
                if state and not state.claimed and progress >= quest.target then
                    QuestClaimRequest:FireServer(typeName, quest.id)
                end
            end)
        end
    end
end

local function refreshAchievements(profile)
    clearChildren(AchvList)
    local config = require(ReplicatedStorage.Config.GameConfig).getAchievementConfig()
    for _, achv in ipairs(config) do
        local entry = createListEntry(AchvTemplate, AchvList)
        entry.Title.Text = achv.text
        local state = profile.achievements and profile.achievements[achv.id]
        entry.Status.Text = state and state.completed and "Completed" or "In Progress"
    end
end

local function refreshUI()
    local profile = GetProfile:InvokeServer()
    if not profile then
        return
    end
    updateBannerInfo()
    updateRollButtons(profile)
    refreshQuests(profile)
    refreshAchievements(profile)
end

local function attemptRoll(count)
    setButtonInteractable(RollButton, false)
    setButtonInteractable(MultiRollButton, false)
    RollRequest:FireServer(currentBanner, count)
end

RollButton.MouseButton1Click:Connect(function()
    attemptRoll(1)
end)

MultiRollButton.MouseButton1Click:Connect(function()
    attemptRoll(10)
end)

BannerSelector.SelectionChanged.Event:Connect(function(option)
    currentBanner = option
    updateBannerInfo()
    updateRollButtons(GetProfile:InvokeServer())
end)

EquipButton.MouseButton1Click:Connect(function()
    if selectedItemId then
        local UpgradeRequest = Remotes:WaitForChild("UpgradeRequest", 5)
        UpgradeRequest:FireServer("equip", selectedItemId)
    end
end)

FuseButton.MouseButton1Click:Connect(function()
    if selectedItemId then
        local UpgradeRequest = Remotes:WaitForChild("UpgradeRequest", 5)
        UpgradeRequest:FireServer("fuse", selectedItemId)
    end
end)

LockToggle.MouseButton1Click:Connect(function()
    if selectedItemId then
        local UpgradeRequest = Remotes:WaitForChild("UpgradeRequest", 5)
        UpgradeRequest:FireServer("lock", selectedItemId)
    end
end)

RollResult.OnClientEvent:Connect(function(payload)
    if payload.type == "roll" and payload.summary then
        handleRollSummary(payload.summary)
    elseif payload.type == "fuse" then
        populateInventory()
    elseif payload.type == "equip" then
        -- optional feedback
    end
    setButtonInteractable(RollButton, true)
    setButtonInteractable(MultiRollButton, true)
    refreshUI()
end)

local function updateFreeTimer()
    while task.wait(1) do
        local profile = GetProfile:InvokeServer()
        if not profile then
            continue
        end
        local now = os.time()
        local cooldown = profile.cooldowns and profile.cooldowns.freeRoll and profile.cooldowns.freeRoll[currentBanner] or now
        local remaining = math.max(0, cooldown - now)
        if remaining == 0 then
            FreeTimerLabel.Text = "Free roll ready!"
        else
            local minutes = math.floor(remaining / 60)
            local seconds = remaining % 60
            FreeTimerLabel.Text = string.format("Free roll in %02d:%02d", minutes, seconds)
        end
    end
end

task.spawn(updateFreeTimer)

local function init()
    populateInventory()
    refreshUI()
end

init()
]=],
}

local function ensurePath(path, className)
    local segments = string.split(path, '/')
    local parent = game
    for index, segment in ipairs(segments) do
        local child = parent:FindFirstChild(segment)
        if not child then
            if index == #segments then
                child = Instance.new(className)
                child.Name = segment
                child.Parent = parent
            else
                child = Instance.new('Folder')
                child.Name = segment
                child.Parent = parent
            end
        end
        parent = child
    end
    return parent
end

local function upsertScript(path, className)
    local instance = ensurePath(path, className)
    local source = SOURCE_MAP[path]
    if source and instance:IsA('LuaSourceContainer') then
        instance.Source = source
    end
    return instance
end

local function createRemotes()
    local remotes = ensurePath('ReplicatedStorage/Remotes', 'Folder')
    local defs = {
        { class = 'RemoteEvent', name = 'RollRequest' },
        { class = 'RemoteEvent', name = 'RollResult' },
        { class = 'RemoteFunction', name = 'GetInventory' },
        { class = 'RemoteFunction', name = 'GetProfile' },
        { class = 'RemoteEvent', name = 'UpgradeRequest' },
        { class = 'RemoteFunction', name = 'GetShop' },
        { class = 'RemoteEvent', name = 'PurchaseRequest' },
        { class = 'RemoteEvent', name = 'QuestClaimRequest' },
        { class = 'RemoteEvent', name = 'AdminCommand' },
    }
    for _, def in ipairs(defs) do
        local remote = remotes:FindFirstChild(def.name)
        if not remote then
            remote = Instance.new(def.class)
            remote.Name = def.name
            remote.Parent = remotes
        end
    end
end

local function createScripts()
    upsertScript('ReplicatedStorage/Config/GameConfig', 'ModuleScript')
    upsertScript('ReplicatedStorage/Config/CardCatalog', 'ModuleScript')
    upsertScript('ReplicatedStorage/Shared/TableUtils', 'ModuleScript')
    upsertScript('ReplicatedStorage/Shared/MathUtils', 'ModuleScript')
    upsertScript('ServerScriptService/PlayerDataService', 'ModuleScript')
    upsertScript('ServerScriptService/InventoryService', 'ModuleScript')
    upsertScript('ServerScriptService/RollService', 'ModuleScript')
    upsertScript('ServerScriptService/EconomyService', 'ModuleScript')
    upsertScript('ServerScriptService/QuestService', 'ModuleScript')
    upsertScript('ServerScriptService/AchievementService', 'ModuleScript')
    upsertScript('ServerScriptService/LeaderboardService', 'ModuleScript')
    upsertScript('ServerScriptService/LiveOpsService', 'ModuleScript')
    upsertScript('ServerScriptService/AdminCommandService', 'ModuleScript')
    upsertScript('ServerScriptService/ServerMain', 'Script')
    upsertScript('StarterPlayer/StarterPlayerScripts/ClientUIController', 'LocalScript')
end

-- UI functions remain the same as previous version
local function ensureGui(name)
    local gui = StarterGui:FindFirstChild(name)
    if not gui then
        gui = Instance.new('ScreenGui')
        gui.Name = name
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.Parent = StarterGui
    end
    return gui
end

-- roll UI
local function createRollUI()
    if ensureGui('MainUI'):FindFirstChild('RollPanel') then
        return
    end
    local gui = ensureGui('MainUI')
    gui.Enabled = false
    local panel = Instance.new('Frame')
    panel.Name = 'RollPanel'
    panel.Size = UDim2.fromScale(0.55, 0.6)
    panel.Position = UDim2.fromScale(0.225, 0.2)
    panel.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
    panel.Parent = gui
    Instance.new('UICorner', panel).CornerRadius = UDim.new(0, 18)
    local padding = Instance.new('UIPadding')
    padding.PaddingTop = UDim.new(0, 24)
    padding.PaddingBottom = UDim.new(0, 24)
    padding.PaddingLeft = UDim.new(0, 24)
    padding.PaddingRight = UDim.new(0, 24)
    padding.Parent = panel
    local layout = Instance.new('UIListLayout')
    layout.Parent = panel
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 12)

    local bannerInfo = Instance.new('TextLabel')
    bannerInfo.Name = 'BannerInfo'
    bannerInfo.Size = UDim2.new(1, 0, 0, 90)
    bannerInfo.BackgroundTransparency = 1
    bannerInfo.Font = Enum.Font.GothamBlack
    bannerInfo.TextScaled = true
    bannerInfo.Text = 'Standard Banner'
    bannerInfo.TextColor3 = Color3.new(1, 1, 1)
    bannerInfo.Parent = panel

    local selector = Instance.new('TextButton')
    selector.Name = 'BannerSelector'
    selector.Size = UDim2.new(1, 0, 0, 70)
    selector.Text = 'Banner: Standard'
    selector.Font = Enum.Font.GothamSemibold
    selector.TextScaled = true
    selector.BackgroundColor3 = Color3.fromRGB(35, 45, 70)
    selector.Parent = panel
    Instance.new('UICorner', selector).CornerRadius = UDim.new(0, 12)
    local event = Instance.new('BindableEvent')
    event.Name = 'SelectionChanged'
    event.Parent = selector
    selector:SetAttribute('Current', 'Standard')
    selector.MouseButton1Click:Connect(function()
        local current = selector:GetAttribute('Current')
        local nextValue = current == 'Standard' and 'Limited' or 'Standard'
        selector:SetAttribute('Current', nextValue)
        selector.Text = 'Banner: ' .. nextValue
        event:Fire(nextValue)
    end)

    local rollButton = Instance.new('TextButton')
    rollButton.Name = 'RollButton'
    rollButton.Size = UDim2.new(1, 0, 0, 90)
    rollButton.Text = 'Roll'
    rollButton.Font = Enum.Font.GothamBold
    rollButton.TextScaled = true
    rollButton.BackgroundColor3 = Color3.fromRGB(80, 120, 255)
    rollButton.Parent = panel
    Instance.new('UICorner', rollButton).CornerRadius = UDim.new(0, 14)

    local multi = rollButton:Clone()
    multi.Name = 'MultiRollButton'
    multi.Text = 'Roll x10'
    multi.Parent = panel

    local result = Instance.new('TextLabel')
    result.Name = 'ResultLabel'
    result.Size = UDim2.new(1, 0, 0, 70)
    result.BackgroundTransparency = 1
    result.Font = Enum.Font.Gotham
    result.TextScaled = true
    result.TextColor3 = Color3.new(1, 1, 1)
    result.Text = 'Pulled: --'
    result.Parent = panel

    local timer = result:Clone()
    timer.Name = 'FreeTimer'
    timer.Text = 'Free roll in 00:00'
    timer.Parent = panel
end

local function createHudUI()
    local gui = ensureGui('HudUI')
    gui.Enabled = true
    if gui:FindFirstChild('HudFrame') then
        return
    end
    local frame = Instance.new('Frame')
    frame.Name = 'HudFrame'
    frame.Size = UDim2.new(0.9, 0, 0, 80)
    frame.Position = UDim2.new(0.05, 0, 1, -30)
    frame.AnchorPoint = Vector2.new(0, 1)
    frame.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
    frame.BackgroundTransparency = 0.2
    frame.Parent = gui
    Instance.new('UICorner', frame).CornerRadius = UDim.new(0, 14)

    local padding = Instance.new('UIPadding')
    padding.PaddingLeft = UDim.new(0, 12)
    padding.PaddingRight = UDim.new(0, 12)
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.Parent = frame

    local layout = Instance.new('UIListLayout')
    layout.Parent = frame
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 6)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center

    local buttons = {
        { name = 'RollToggle', text = 'Roll' },
        { name = 'InventoryToggle', text = 'Inventory' },
        { name = 'ShopToggle', text = 'Shop' },
        { name = 'QuestsToggle', text = 'Quests' },
        { name = 'AchievementsToggle', text = 'Achievements' },
        { name = 'SettingsToggle', text = 'Settings' },
    }

    for index, info in ipairs(buttons) do
        local button = Instance.new('TextButton')
        button.Name = info.name
        button.Size = UDim2.new(1 / #buttons, -12, 1, -16)
        button.BackgroundColor3 = Color3.fromRGB(60, 80, 140)
        button.TextColor3 = Color3.new(1, 1, 1)
        button.Text = info.text
        button.Font = Enum.Font.GothamSemibold
        button.TextScaled = true
        button.AutoButtonColor = true
        button.Parent = frame
        button.LayoutOrder = index
        Instance.new('UICorner', button).CornerRadius = UDim.new(0, 12)
    end
end

-- inventory UI
local function createInventoryUI()
    local gui = ensureGui('InventoryUI')
    gui.Enabled = false
    if gui:FindFirstChild('InventoryFrame') then
        return
    end
    local frame = Instance.new('Frame')
    frame.Name = 'InventoryFrame'
    frame.Size = UDim2.fromScale(0.92, 0.82)
    frame.Position = UDim2.fromScale(0.04, 0.09)
    frame.BackgroundColor3 = Color3.fromRGB(15, 16, 22)
    frame.Parent = gui
    Instance.new('UICorner', frame).CornerRadius = UDim.new(0, 16)

    local list = Instance.new('ScrollingFrame')
    list.Name = 'ItemList'
    list.Size = UDim2.new(0.5, -20, 1, -20)
    list.Position = UDim2.new(0, 10, 0, 10)
    list.BackgroundTransparency = 1
    list.CanvasSize = UDim2.new(0, 0, 0, 0)
    list.ScrollBarThickness = 8
    list.Parent = frame
    local layout = Instance.new('UIListLayout')
    layout.Parent = list
    layout.Padding = UDim.new(0, 6)

    local template = Instance.new('TextButton')
    template.Name = 'ItemTemplate'
    template.Size = UDim2.new(1, -8, 0, 70)
    template.BackgroundColor3 = Color3.fromRGB(35, 37, 50)
    template.Visible = false
    template.Text = ''
    template.Parent = list
    Instance.new('UICorner', template).CornerRadius = UDim.new(0, 12)
    local tLayout = Instance.new('UIListLayout')
    tLayout.Parent = template
    tLayout.FillDirection = Enum.FillDirection.Horizontal
    tLayout.Padding = UDim.new(0, 6)

    local function addLabel(name, text, size)
        local label = Instance.new('TextLabel')
        label.Name = name
        label.Size = UDim2.new(size, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamSemibold
        label.TextScaled = true
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Text = text
        label.Parent = template
    end
    addLabel('Title', 'Aura', 0.4)
    addLabel('Count', 'x1', 0.2)
    addLabel('Level', 'Lv.1', 0.2)
    addLabel('Rarity', 'Common', 0.2)

    local details = Instance.new('Frame')
    details.Name = 'ItemDetails'
    details.Size = UDim2.new(0.5, -20, 1, -20)
    details.Position = UDim2.new(0.5, 10, 0, 10)
    details.BackgroundTransparency = 1
    details.Parent = frame
    local dLayout = Instance.new('UIListLayout')
    dLayout.Parent = details
    dLayout.FillDirection = Enum.FillDirection.Vertical
    dLayout.Padding = UDim.new(0, 8)

    local function addInfoLabel(name, text)
        local label = Instance.new('TextLabel')
        label.Name = name
        label.Size = UDim2.new(1, 0, 0, 60)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBlack
        label.TextScaled = true
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Text = text
        label.Parent = details
    end
    addInfoLabel('CardName', 'Select an aura')
    addInfoLabel('LevelLabel', 'Level --')
    addInfoLabel('CountLabel', 'Count --')
    addInfoLabel('ShardsLabel', 'Shards --')

    local function addActionButton(name, text, color)
        local button = Instance.new('TextButton')
        button.Name = name
        button.Size = UDim2.new(1, 0, 0, 70)
        button.Text = text
        button.Font = Enum.Font.GothamBold
        button.TextScaled = true
        button.BackgroundColor3 = color
        button.Parent = details
        Instance.new('UICorner', button).CornerRadius = UDim.new(0, 12)
    end
    addActionButton('EquipButton', 'Equip', Color3.fromRGB(60, 200, 140))
    addActionButton('FuseButton', 'Fuse', Color3.fromRGB(255, 150, 90))
    addActionButton('LockToggle', 'Lock', Color3.fromRGB(120, 120, 140))
end

local function ensureSimpleGui(name)
    local gui = ensureGui(name)
    gui.Enabled = false
    if gui:FindFirstChild(name .. 'Frame') then
        return gui
    end
    local frame = Instance.new('Frame')
    frame.Name = name .. 'Frame'
    frame.Size = UDim2.fromScale(0.8, 0.8)
    frame.Position = UDim2.fromScale(0.1, 0.1)
    frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
    frame.Parent = gui
    Instance.new('UICorner', frame).CornerRadius = UDim.new(0, 16)
    local layout = Instance.new('UIListLayout')
    layout.Parent = frame
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.Padding = UDim.new(0, 10)

    local header = Instance.new('TextLabel')
    header.Name = name .. 'Header'
    header.Size = UDim2.new(1, 0, 0, 80)
    header.BackgroundTransparency = 1
    header.Font = Enum.Font.GothamBlack
    header.TextScaled = true
    header.TextColor3 = Color3.new(1, 1, 1)
    header.Text = name
    header.Parent = frame

    local list = Instance.new('ScrollingFrame')
    list.Name = name .. 'List'
    list.Size = UDim2.new(1, -20, 1, -100)
    list.Position = UDim2.new(0, 10, 0, 90)
    list.BackgroundTransparency = 1
    list.CanvasSize = UDim2.new(0, 0, 0, 0)
    list.Parent = frame
    local listLayout = Instance.new('UIListLayout')
    listLayout.Parent = list
    listLayout.Padding = UDim.new(0, 8)

    local template = Instance.new('Frame')
    template.Name = name == 'ShopUI' and 'ShopItemTemplate' or (name == 'QuestsUI' and 'QuestTemplate' or 'AchvTemplate')
    template.Size = UDim2.new(1, -10, 0, 80)
    template.BackgroundColor3 = Color3.fromRGB(35, 37, 50)
    template.Visible = false
    template.Parent = list
    Instance.new('UICorner', template).CornerRadius = UDim.new(0, 12)

    local title = Instance.new('TextLabel')
    title.Name = 'Title'
    title.Size = UDim2.new(0.6, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamSemibold
    title.TextScaled = true
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Text = 'Item'
    title.Parent = template

    if name == 'ShopUI' then
        local price = title:Clone()
        price.Name = 'Price'
        price.Size = UDim2.new(0.2, 0, 1, 0)
        price.Text = 'Price'
        price.Parent = template
        local button = Instance.new('TextButton')
        button.Name = 'BuyButton'
        button.Size = UDim2.new(0.2, 0, 0.8, 0)
        button.Position = UDim2.new(0.8, 0, 0.1, 0)
        button.Text = 'Buy'
        button.Font = Enum.Font.GothamBold
        button.TextScaled = true
        button.BackgroundColor3 = Color3.fromRGB(80, 120, 255)
        button.Parent = template
        Instance.new('UICorner', button).CornerRadius = UDim.new(0, 12)
    elseif name == 'QuestsUI' then
        local progress = title:Clone()
        progress.Name = 'Progress'
        progress.Size = UDim2.new(0.2, 0, 1, 0)
        progress.Text = '0/0'
        progress.Parent = template
        local claim = Instance.new('TextButton')
        claim.Name = 'ClaimButton'
        claim.Size = UDim2.new(0.2, 0, 0.8, 0)
        claim.Position = UDim2.new(0.8, 0, 0.1, 0)
        claim.Text = 'Claim'
        claim.Font = Enum.Font.GothamBold
        claim.TextScaled = true
        claim.BackgroundColor3 = Color3.fromRGB(60, 200, 140)
        claim.Parent = template
        Instance.new('UICorner', claim).CornerRadius = UDim.new(0, 12)
    else
        local status = title:Clone()
        status.Name = 'Status'
        status.Size = UDim2.new(0.4, 0, 1, 0)
        status.Text = 'Status'
        status.Parent = template
    end
    return gui
end

local function createSettingsUI()
    local gui = ensureGui('SettingsUI')
    gui.Enabled = false
    if gui:FindFirstChild('SettingsFrame') then
        return
    end
    local frame = Instance.new('Frame')
    frame.Name = 'SettingsFrame'
    frame.Size = UDim2.fromScale(0.6, 0.7)
    frame.Position = UDim2.fromScale(0.2, 0.15)
    frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
    frame.Parent = gui
    Instance.new('UICorner', frame).CornerRadius = UDim.new(0, 16)
    local layout = Instance.new('UIListLayout')
    layout.Parent = frame
    layout.Padding = UDim.new(0, 10)
    local template = Instance.new('Frame')
    template.Name = 'SettingTemplate'
    template.Size = UDim2.new(1, -20, 0, 70)
    template.Position = UDim2.new(0, 10, 0, 10)
    template.BackgroundColor3 = Color3.fromRGB(35, 37, 50)
    template.Visible = false
    template.Parent = frame
    Instance.new('UICorner', template).CornerRadius = UDim.new(0, 12)
end

local function createUI()
    createHudUI()
    createRollUI()
    createInventoryUI()
    ensureSimpleGui('ShopUI')
    ensureSimpleGui('QuestsUI')
    ensureSimpleGui('AchievementsUI')
    createSettingsUI()
end

createRemotes()
createScripts()
createUI()
print('Bootstrap complete.')
