--[[
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
