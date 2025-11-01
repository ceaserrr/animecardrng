--[[
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
local HudUI = localPlayer.PlayerGui:WaitForChild("HudUI", 5)
local HudFrame = HudUI:WaitForChild("HudFrame", 5)
local RollToggle = HudFrame:WaitForChild("RollToggle", 5)
local InventoryToggle = HudFrame:WaitForChild("InventoryToggle", 5)
local ShopToggle = HudFrame:WaitForChild("ShopToggle", 5)
local QuestsToggle = HudFrame:WaitForChild("QuestsToggle", 5)
local AchievementsToggle = HudFrame:WaitForChild("AchievementsToggle", 5)
local SettingsToggle = HudFrame:WaitForChild("SettingsToggle", 5)

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

local screens = {
    Roll = MainUI,
    Inventory = InventoryUI,
    Shop = ShopUI,
    Quests = QuestsUI,
    Achievements = AchievementsUI,
    Settings = SettingsUI,
}

for _, gui in pairs(screens) do
    gui.Enabled = false
end

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

local function toggleScreen(screenKey)
    local target = screens[screenKey]
    if not target then
        return
    end
    local shouldEnable = not target.Enabled
    for _, gui in pairs(screens) do
        gui.Enabled = false
    end
    target.Enabled = shouldEnable
    if not shouldEnable then
        return
    end
    if screenKey == "Roll" then
        refreshUI()
    elseif screenKey == "Inventory" then
        populateInventory()
    elseif screenKey == "Quests" then
        refreshUI()
    elseif screenKey == "Shop" then
        refreshUI()
    elseif screenKey == "Achievements" then
        refreshUI()
    elseif screenKey == "Settings" then
        refreshUI()
    end
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

local BannerEvent = BannerSelector:WaitForChild("SelectionChanged", 5)
BannerEvent.Event:Connect(function(option)
    currentBanner = option
    updateBannerInfo()
    updateRollButtons(GetProfile:InvokeServer())
end)

local function bindToggle(button, screenKey)
    button.MouseButton1Click:Connect(function()
        toggleScreen(screenKey)
    end)
end

bindToggle(RollToggle, "Roll")
bindToggle(InventoryToggle, "Inventory")
bindToggle(ShopToggle, "Shop")
bindToggle(QuestsToggle, "Quests")
bindToggle(AchievementsToggle, "Achievements")
bindToggle(SettingsToggle, "Settings")

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
