# Architecture

**Analysis Date:** 2026-03-21

## Pattern Overview

**Overall:** Client-Server Event-Driven Architecture with Manager-Based Organization

**Key Characteristics:**
- Remotes-based server-client communication (ReplicatedStorage.Remotes)
- Manager pattern for server-side systems (GameManager coordinates sub-managers)
- State synchronization through RemoteEvents
- Client-side UI/UX isolation from server logic
- Shared type definitions and utilities in shared directory

## Layers

**Server Layer:**
- Purpose: Game loop, state authority, player progression, match coordination
- Location: `src/server/`
- Contains: Core managers (GameManager, MatchManager, CurrencyManager, etc.), data persistence
- Depends on: ReplicatedStorage.Shared, Roblox services (Players, DataStore, etc.)
- Used by: Client via Remotes

**Client Layer:**
- Purpose: UI rendering, input handling, visual effects, sound management
- Location: `src/client/`
- Contains: UI modules, controllers (FlyController, UltimateSkillController), effects
- Depends on: Server via Remotes, shared types/config, Roblox services
- Used by: Players

**Shared Layer:**
- Purpose: Centralized type definitions, configuration, business logic utilities
- Location: `src/shared/`
- Contains: Types.luau, Config.luau, Logger, RemoteRegistry, ClassTypes, ItemTypes, GamePassLogic, StageInfo
- Depends on: None (no circular dependencies)
- Used by: Both server and client

**Loading Layer:**
- Purpose: Pre-game asset preloading and visual feedback
- Location: `src/loading/init.client.luau` (runs in ReplicatedFirst)
- Contains: Loading screen UI, asset preload with progress bar
- Depends on: ThemeConfig for colors
- Used by: Before game fully loads

## Data Flow

**Player Join Flow:**
1. Loading screen displays (`src/loading/init.client.luau` in ReplicatedFirst)
2. Client initializes (`src/client/init.client.luau`):
   - Creates MainUI with all UI components
   - Initializes ItemEffects, SoundManager
   - Sets up event handlers
3. Server initializes player:
   - GameManager.new() creates all managers
   - CurrencyManager loads/creates player data from DataStore
   - SelectionZoneManager watches for player entry
4. Player spawns in Lobby
5. UpdateLog popup shown based on version

**Match Start Flow:**
1. Player touches SelectionZone → SelectionZoneManager detects
2. Shows StageSelectionUI → Player votes on stages
3. Player creates/joins MatchRoom via CreateMatch/JoinMatch remotes
4. MatchManager creates MatchRoom or adds player to waiting room
5. Host triggers HostStartMatch → MatchManager starts race
6. MapManager generates stages in Workspace.Stages
7. All players teleported to Stage 0
8. RaceUpdate events fire continuously during race
9. Stage completion/finish triggers remote events
10. Race Summary displayed in SummaryUI
11. Player teleported back to Lobby

**Currency/Progression Flow:**
1. Player completes stage or purchases item
2. Server emits UpdateCurrency remote
3. CurrencyManager updates local PlayerCurrencyData
4. Client listens to UpdateCurrency → updates CurrencyUI
5. DataStore saves on player exit or periodic flush

**State Management:**
- **Server**: GameManager.playerStates tracks "Lobby" | "Playing" | "Finished" | "Spectating"
- **Server**: MatchManager.rooms tracks all active races
- **Client**: MainUI tracks which panels are visible
- **Shared**: Config provides read-only game parameters

## Key Abstractions

**GameManager:**
- Purpose: Central coordinator for all game systems
- Examples: `src/server/GameManager.luau`
- Pattern: Creates and delegates to specialized managers (MatchManager, ClassManager, ItemManager, etc.)

**MatchManager:**
- Purpose: Manages matchmaking, race rooms, stage voting, race progress
- Examples: `src/server/MatchManager.luau`
- Pattern: Maintains MatchRoom objects, handles remote events

**CurrencyManager:**
- Purpose: Manages player currency, gems, class unlocks, mastery progression, titles
- Examples: `src/server/CurrencyManager.luau`
- Pattern: Persists to DataStore, exposes check/spend/earn functions

**MapManager:**
- Purpose: Generates random stage sequences from StageTemplates
- Examples: `src/server/MapManager.luau`
- Pattern: Creates stage instances, manages stage lifecycle

**SelectionZoneManager:**
- Purpose: Detects player interaction with lobby selection zone
- Examples: `src/server/SelectionZoneManager.luau`
- Pattern: Listens to physics/touch events, triggers UI events

**MainUI:**
- Purpose: Orchestrates all client UI panels (Shop, Leaderboard, Classes, Settings, etc.)
- Examples: `src/client/UI/MainUI.luau`
- Pattern: Creates UI components, manages visibility/mutual exclusion, coordinates callbacks

**RemoteRegistry:**
- Purpose: Centralized remote access with caching
- Examples: `src/shared/RemoteRegistry.luau`
- Pattern: .get(name) returns cached RemoteEvent, avoids repeated lookups

**ThemeConfig:**
- Purpose: Centralized color/style definitions and helper functions
- Examples: `src/shared/ThemeConfig.luau`
- Pattern: Provides Color3 constants and applyCorner/applyStroke/applyPadding helpers

## Entry Points

**Server Entry:**
- Location: `src/server/init.server.luau`
- Triggers: Server starts
- Responsibilities: Initializes GameManager, sets up SoundGroup, binds DataStore save on shutdown

**Client Entry:**
- Location: `src/client/init.client.luau`
- Triggers: Player joins (after character creation)
- Responsibilities: Initializes MainUI, ItemEffects, SoundManager, UltimateSkillController, sets up remotes, camera snapshots

**Loading Entry:**
- Location: `src/loading/init.client.luau`
- Triggers: Game loads (ReplicatedFirst priority)
- Responsibilities: Shows loading screen with progress bar, preloads assets, waits for character

## Error Handling

**Strategy:** Silent failures with logging

**Patterns:**
- Logger.warn() for non-critical issues (missing remotes, nil checks)
- Logger.error() for critical failures (DataStore fails)
- Graceful degradation: Features disabled if dependencies unavailable
- Timeout-based fallbacks (e.g., UpdateLog popup has 5-second timeout)
- Remote failures caught via RemoteRegistry.get() returning nil

## Cross-Cutting Concerns

**Logging:**
- Implementation: `src/shared/Logger.luau` with .info(), .warn(), .error() methods
- Usage: Every manager logs state changes, remotes, errors
- Accessibility: Require at top of file: `local Logger = require(ReplicatedStorage.Shared.Logger)`

**Validation:**
- Implementation: Inline checks in remote handlers
- Patterns: canAfford() before spend, isClassUnlocked() before equip, max bounds checks
- Location: Validation in handler functions (CurrencyManager, ClassManager, etc.)

**Authentication:**
- Implementation: Roblox UserId implicit (only server-trusted)
- Pattern: Remote handlers assume player parameter is authentic
- Additional: GamePass verification via MarketplaceService:UserOwnsGamePass()

**Remotes Structure:**
- Folder: ReplicatedStorage.Remotes
- Pattern: One RemoteEvent per game action
- Examples: StartGame, UseItem, BuyShopItem, SelectClass, VoteStages
- Client→Server: Fire with player action (player implicit)
- Server→Client: Fire to specific player with data

---

*Architecture analysis: 2026-03-21*
