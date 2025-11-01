# Aura Collector (Card RNG) - Developer Guide

## 1. Setup & Run
1. **Clone or sync** this repository into your Roblox Studio project (Rojo or manual import).
2. In Studio, open the command bar and run the contents of `BootstrapScript.lua`. The script will:
   - Create all required folders, remotes, ModuleScripts, Scripts, and ScreenGuis.
   - Populate source code for every script listed in this repo.
   - Build responsive UI frames, buttons, and templates under `StarterGui`.
3. Press **Play** in Studio. The `ServerScriptService/ServerMain` script requires every service module and wires remotes automatically.
4. Test rolling, inventory, shop, quests, and achievements using the UI or the dev commands outlined below.

## 2. Project Structure
```
ReplicatedStorage
  ├─ Config
  │   ├─ GameConfig.module.lua
  │   └─ CardCatalog.module.lua
  ├─ Remotes (auto-created via bootstrap)
  └─ Shared
      ├─ TableUtils.module.lua
      └─ MathUtils.module.lua
ServerScriptService
  ├─ ServerMain.server.lua
  ├─ PlayerDataService.server.lua
  ├─ InventoryService.server.lua
  ├─ RollService.server.lua
  ├─ EconomyService.server.lua
  ├─ QuestService.server.lua
  ├─ AchievementService.server.lua
  ├─ LeaderboardService.server.lua
  ├─ LiveOpsService.server.lua
  └─ AdminCommandService.server.lua
StarterPlayer
  └─ StarterPlayerScripts
      └─ ClientUIController.client.lua
StarterGui (UI created by bootstrap)
  ├─ MainUI (Roll panel)
  ├─ InventoryUI
  ├─ ShopUI
  ├─ QuestsUI
  ├─ AchievementsUI
  └─ SettingsUI
```

## 3. Key Systems
- **GameConfig**: Central knobs (banner odds, pity, economy, boosters, quests, achievements). Toggle LiveOps flags or set new banner pools here.
- **CardCatalog**: 38 sample auras across Common/Rare/Super Rare/Ultra Rare, each with weights, base power, and set tags.
- **PlayerDataService**: DataStore-backed profile management (versioned schema, autosave, migration-ready).
- **RollService**: Server-authoritative gacha logic, rate limiting, pity (soft + hard), free rolls, analytics logs, and quest/achievement hooks.
- **InventoryService**: Add/fuse/equip/lock cards; shard calculations, booster bonuses, total power tracking, leaderboard syncing.
- **EconomyService**: Shop data, dev product stubs, boosters, bundle handling.
- **Quest & Achievement Services**: Daily/weekly quests with reset timers, lifetime milestones with optional badges.
- **LeaderboardService**: OrderedDataStore submissions for total power and high rarity pull recency.
- **LiveOpsService**: MessagingService broadcast helper for future banner swaps.
- **AdminCommandService**: Developer-only utilities (grant currency, force rarity, reset data).
- **ClientUIController**: Mobile-friendly UI wiring; handles roll requests, inventory updates, quest claim routing, and cooldown timers.

## 4. Sample Content
`CardCatalog.module.lua` defines 38 original aura cards with the following structure:
```lua
{
    id = "aura_ember_glow",
    displayName = "Ember Glow",
    rarity = "Common",
    weight = 12,
    basePower = 120,
    maxLevel = 10,
    iconImageId = "rbxassetid://12345601", -- replace with production asset id
    auraVFX = { color = Color3.fromRGB(255, 140, 80), particles = "rbxassetid://10932100" },
    sets = { "Blaze", "Forge" },
}
```
- **Rarity distribution**: 10 Common, 10 Rare, 10 Super Rare, 8 Ultra Rare.
- **Set tags**: Every card has at least two (e.g., `"Nebula"`, `"Prism"`, `"Guardian"`) enabling collection bonuses later.
- **Banners**: `GameConfig` ships with `Standard` and `Limited` banners using different pools and pity thresholds.

## 5. Dev/Test Utilities
- `ServerScriptService/AdminCommandService` exposes the `Remotes/AdminCommand` event. Add Roblox user IDs to `ALLOWED_USER_IDS` before use.
- Commands:
  - `AdminCommand:FireServer("grant", targetPlayerName, "coins"|"gems", amount)` – award currency.
  - `AdminCommand:FireServer("reset", targetPlayerName)` – reset inventory/pity.
  - `AdminCommand:FireServer("force", targetPlayerName, bannerName, rarity)` – grant a random card of the requested rarity from the banner pool.
- Logs follow emoji tags (`🎲 Roll`, `🧩 Inventory`, `💾 Save`, `📜 Quest`, `🏆 Achv`, `🛍️ Shop`, `📣 LiveOps`, `⚠️ Warn`).

## 6. Testing Plan & Acceptance Criteria
Run these checks each release:
1. **Gacha flow**
   - Trigger single and multi rolls on both banners.
   - Validate currency deductions, pity increments, free roll cooldown, and duplicate shard gains.
2. **Inventory/Upgrades**
   - Fuse cards at different rarities; verify shard/coin costs and level cap behavior.
   - Equip/lock toggles prevent unwanted fuses.
3. **Persistence**
   - Rejoin after rolls/fuses to confirm inventory, pity, boosters, cooldowns, and quests persist.
4. **Quests & Achievements**
   - Complete daily/weekly objectives, claim rewards, and ensure achievements fire once.
5. **Leaderboards**
   - Inspect OrderedDataStore values (Studio console) for power and rarity timestamps.
6. **Shop & Economy**
   - Purchase bundles/boosts; confirm boosters update profile and timers.
7. **Admin Commands**
   - Use grant/reset/force to simulate edge cases (pity threshold, high rarity guarantee).
8. **Anti-exploit**
   - Spam roll remote >3 times/sec, confirm server throttles.
   - Send invalid banner name/card IDs; ensure server ignores.
9. **UX**
   - Test on phone emulator + gamepad navigation (default Roblox UI selection works via large button hitboxes).
   - Verify colorblind-safe rarity labels (text + color).

Release gates:
- No DataStore errors in output during 10-minute test session.
- Pity guarantees at 30 (SR) / 100 (UR) trigger in forced stress tests.
- Free roll timers count down correctly across sessions.

## 7. Adding Content & LiveOps
- **New cards**: Append to `CardCatalog.cards`, assign weights, set tags, and reference in appropriate pools.
- **Banner rotation**: Update `GameConfig.banners` pools/flags; toggle `GameConfig.flags.LIMITED_ACTIVE` or call `LiveOpsService.broadcastBanner` for live swaps.
- **Economy tuning**: Adjust `GameConfig.getEconomy()` values for roll costs, shard rewards, booster durations, and currency caps.
- **Events**: Flip `GameConfig.flags.DOUBLE_SHARDS_WEEKEND` or extend the `flags` table with new toggles. Client checks these via `GameConfig`.

## 8. Troubleshooting
- **Infinite yield warnings**: All `WaitForChild` calls use timeouts (5s). If UI assets renamed, rerun `BootstrapScript.lua`.
- **DataStore limits**: Retries/backoff already implemented. For testing without quotas, use Studio API Services + mock data (set `RunService:IsStudio()` and skip saves if desired).
- **UI missing/duplicated**: Delete affected ScreenGui in `StarterGui` and rerun the bootstrap script to rebuild.
- **Pity not resetting**: Confirm achievements/dev commands aren’t forcing cards outside normal flow, then inspect `profile.pity` via command line.

## 9. Roadmap (Prioritized)
1. **Trading Hub** – Secure trading session flow with escrow, confirmations, and cooldowns.
2. **Clans/Guilds** – Shared quests, clan power leaderboard, clan shop boosts.
3. **Co-op Events** – Rotating boss raids granting exclusive cards and shards.
4. **Seasonal Battle Pass** – Tiered rewards, premium track, quest integrations.
5. **Cosmetics Shop** – Avatar accessories + aura recolors purchasable with premium currency.
6. **Live A/B Testing** – Config flags + per-server variants for rates/economy.
7. **Showcase Scene** – Dedicated UI chamber previewing equipped aura with photo mode.
8. **Screenshot Mode** – Hide HUD, pose character, apply rarity sticker overlays.

## 10. Assumptions
- Dev product IDs and badge IDs are placeholders; replace with production IDs before publishing.
- Image/particle asset IDs are sample placeholders; swap for approved assets.
- MessagingService requires publish permissions; disable broadcasts if not available.

Happy building! 🎴
