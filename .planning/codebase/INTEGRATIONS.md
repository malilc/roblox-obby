# External Integrations

**Analysis Date:** 2026-03-21

## APIs & External Services

**Discord Webhooks:**
- Feedback system sends user feedback to Discord via three category-specific webhooks (Bug, Suggestion, Other)
  - SDK/Client: HttpService (native Roblox service)
  - Auth: Webhook URLs stored in `Config.Feedback.WebhookUrls`
  - File: `src/server/FeedbackManager.luau`
  - Payload format: Discord embeds with category color, player info, timestamp

**Roblox In-Game Services:**
- No external third-party APIs integrated
- All game logic uses native Roblox services

## Data Storage

**Databases:**
- Roblox DataStoreService (built-in key-value store)
  - DataStore name: `ObbyGameData_v1`
  - Connection: Native service via `game:GetService("DataStoreService")`
  - Client: Custom wrapper `DataStoreHelper.luau` with retry logic (3 retries, exponential backoff)
  - File: `src/server/DataStoreHelper.luau`

**Ordered DataStores (for leaderboards):**
- `GemLeaderboard` - Tracks total gems earned by player
- `WinLeaderboard` - Tracks race wins by player
- Retrieved via `DataStoreService:GetOrderedDataStore()`
- File: `src/server/LeaderboardManager.luau`

**Player Data Keys:**
- Format: `Player_{UserId}` where UserId is Roblox user ID
- Schema version tracking: `_schemaVersion = 1` added to all saved data for future migration support
- File: `src/server/DataStoreHelper.luau` line 177-179

**File Storage:**
- Not used - all data persisted via DataStore

**Caching:**
- DataStore instances cached in module scope in `DataStoreHelper`
  - Variable: `datastores` (regular stores) and `orderedDatastores` (ordered stores)
  - Prevents multiple instantiation of same store

## Authentication & Identity

**Auth Provider:**
- Custom - Uses native Roblox player authentication
- Players authenticated by Roblox platform before joining

**Player Identity:**
- Roblox UserId as primary identifier
- Player.UserId used for all data lookups
- Player.Name and Player.DisplayName for UI display
- File: `src/server/DataStoreHelper.luau` line 177-179

## In-Game Monetization

**Game Passes (Roblox Marketplace):**
- MarketplaceService integration for game pass purchases
- 4 active game passes with Roblox IDs:
  - `DoubleCoin` (ID: 1740745787) - 99 Robux - 2x coin multiplier
  - `VIP` (ID: 1741108491) - 199 Robux - 1.5x coins + 1.5x XP + badge + chat tag
  - `ExtraSlot` (ID: 1740769746) - 149 Robux - 3rd item slot
  - `DoubleXP` (ID: 1753504703) - 149 Robux - 2x mastery XP
- Files:
  - `src/server/ShopManager.luau` - Purchase handling, ownership checks, event listeners
  - `src/client/UI/ShopUI.luau` - Purchase prompts
  - `src/shared/GamePassLogic.luau` - Shared game pass utilities
- Service: `MarketplaceService:PromptGamePassPurchase()` and `UserOwnsGamePassAsync()`
- Cache: Per-player game pass ownership cached in `ShopManager.playerGamePasses`

**Currency System (In-Game):**
- Coins - Earned in matches, spent on items and classes
- Gems - Premium currency earned in matches, spent on gacha pulls

## Monitoring & Observability

**Error Tracking:**
- Custom logger module `Logger.luau`
- Logs written to studio output/server logs
- No external error tracking service

**Logs:**
- Info, warn, and error levels
- Logged for all major operations: initialization, purchases, data saves
- File: `src/shared/Logger.luau`

## CI/CD & Deployment

**Hosting:**
- Roblox platform (published place/game)

**CI Pipeline:**
- None detected - development workflow appears manual

**Testing:**
- Jest tests run via `run-in-roblox` tool
- Test execution: `npm run test` or equivalent (via scripts/run-tests.server.luau)

## Environment Configuration

**Required env vars:**
- None - all configuration in `Config.luau` shared module

**Secrets location:**
- Discord webhook URLs stored in `Config.Feedback.WebhookUrls`
- File: `src/shared/Config.luau` lines 313-322
- WARNING: Webhook URLs are currently hardcoded in source (should use environment variables in production)

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- Discord webhooks for feedback categories:
  - Bug reports webhook
  - Suggestions webhook
  - General feedback webhook
- Triggered by player feedback submission via `SendFeedback` RemoteEvent
- File: `src/server/FeedbackManager.luau`

## Roblox Native Services Used

The following Roblox services are integrated throughout the codebase:

**Server Services:**
- `DataStoreService` - Player data persistence
- `HttpService` - Discord webhook integration
- `Players` - Player management and lifecycle events
- `RunService` - Frame-based timing for map animations and item effects
- `SoundService` - Sound group management
- `MarketplaceService` - Game pass purchases and ownership checks

**Client Services:**
- `UserInputService` - Keyboard and touch input
- `RunService` - Rendering and frame timing
- `MarketplaceService` - Game pass UI prompts

**Shared Services:**
- `ReplicatedStorage` - Shared code and RemoteEvents

---

*Integration audit: 2026-03-21*
