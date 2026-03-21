# Codebase Structure

**Analysis Date:** 2026-03-21

## Directory Layout

```
roblox-obby/
├── src/                            # Main source code
│   ├── server/                     # Server-side managers and logic
│   ├── client/                     # Client-side controllers and UI
│   │   └── UI/                     # UI panel modules
│   ├── shared/                     # Shared types, config, utilities
│   │   └── __tests__/              # Unit tests for shared modules
│   └── loading/                    # Loading screen (ReplicatedFirst)
├── scripts/                        # Testing and utility scripts
├── default.project.json            # Rojo project configuration (src→game mapping)
├── test.project.json               # Test runner configuration
├── wally.toml                      # Wally package manager config
├── wally.lock                      # Wally dependency lock file
├── aftman.toml                     # Aftman toolchain config (luau, rojo versions)
├── .gitignore                      # Git ignore patterns
└── .planning/
    └── codebase/                   # Analysis documents (this directory)
```

## Directory Purposes

**src/server/**
- Purpose: Server-side game logic, state authority, manager coordination
- Contains: Managers for matches, currency, classes, items, spectators, leaderboards, shops
- Key files: GameManager.luau (orchestrator), MatchManager.luau (races), CurrencyManager.luau (progression)
- Pattern: Each manager is a standalone module with new() constructor and instance methods

**src/client/**
- Purpose: Client-side gameplay, input, visual effects
- Contains: Controllers (FlyController, UltimateSkillController), managers (SoundManager, ItemEffects), UI orchestration
- Key files: init.client.luau (entry point), MainUI.luau (UI coordinator), SoundManager.luau (audio), ItemEffects.luau (screen effects)

**src/client/UI/**
- Purpose: Individual UI panel implementations
- Contains: 23 UI modules for different game screens
- Key files: MainUI.luau (master controller), ShopUI.luau, ClassSelectionUI.luau, LeaderboardUI.luau
- Pattern: Each panel has new(parent, callbacks?) constructor and show()/hide() methods

**src/shared/**
- Purpose: Shared definitions, configuration, business logic
- Contains: Type definitions, game config, utilities, enums
- Key files:
  - Types.luau (PlayerData, StageData, GameState, CurrencyManagerLike)
  - Config.luau (game parameters, stage counts, timing)
  - ClassTypes.luau (class definitions with abilities)
  - ItemTypes.luau (item definitions with effects)
  - RemoteRegistry.luau (centralized remote access)
  - ThemeConfig.luau (colors, style helpers)
  - Logger.luau (logging utility)
  - GamePassLogic.luau (gamepass ID constants and verification)
  - StageInfo.luau (stage template definitions)

**src/shared/__tests__/**
- Purpose: Unit tests for shared modules
- Contains: Jest-based test files (.spec.luau)
- Key files: ItemTypes.spec.luau, GamePassLogic.spec.luau, ClassTypes.spec.luau, StageInfo.spec.luau

**src/loading/**
- Purpose: Pre-game loading screen
- Contains: Single init.client.luau that runs in ReplicatedFirst
- Key features: Progress bar, asset preloading, random tips rotation, fade-out animation

**scripts/**
- Purpose: Development and test utilities
- Contains: run-tests.server.luau (Jest runner)

## Key File Locations

**Entry Points:**
- `src/server/init.server.luau`: Server initialization, GameManager creation, shutdown handler
- `src/client/init.client.luau`: Client initialization, MainUI creation, event setup, update log logic
- `src/loading/init.client.luau`: Loading screen (ReplicatedFirst, runs first)

**Configuration:**
- `src/shared/Config.luau`: Game parameters (stage counts, timing, features, update log)
- `src/shared/ThemeConfig.luau`: UI colors and style constants
- `default.project.json`: Rojo tree mapping (defines src→game location)
- `wally.toml`: Package dependencies

**Core Logic:**
- `src/server/GameManager.luau`: Main server orchestrator
- `src/server/MatchManager.luau`: Race/match coordination
- `src/server/CurrencyManager.luau`: Player progression, DataStore
- `src/server/MapManager.luau`: Stage generation
- `src/client/UI/MainUI.luau`: Client UI orchestrator

**Testing:**
- `src/shared/__tests__/ItemTypes.spec.luau`: Item system tests
- `src/shared/__tests__/GamePassLogic.spec.luau`: GamePass logic tests
- `src/shared/__tests__/ClassTypes.spec.luau`: Class system tests
- `src/shared/__tests__/StageInfo.spec.luau`: Stage definitions tests
- `src/shared/jest.config.luau`: Jest configuration
- `scripts/run-tests.server.luau`: Test runner entry point

## Naming Conventions

**Files:**
- Manager files: `[System]Manager.luau` (e.g., GameManager.luau, CurrencyManager.luau)
- UI files: `[PanelName]UI.luau` (e.g., ShopUI.luau, LeaderboardUI.luau)
- Entry files: `init.server.luau`, `init.client.luau`
- Test files: `[Module].spec.luau` (e.g., ItemTypes.spec.luau)
- Controllers: `[Name]Controller.luau` (e.g., FlyController.luau)

**Directories:**
- Lowercase with no spaces: `src/`, `server/`, `client/`, `shared/`
- Special directories: `UI/` (uppercase), `__tests__/` (dunder pattern for Jest discovery)

**Modules/Types:**
- PascalCase for types and classes: `GameManager`, `MatchManager`, `PlayerData`
- camelCase for functions: `new()`, `show()`, `hide()`, `onTouched()`
- UPPER_CASE for constants: `DEFAULT_CLASS`, `MAX_PLAYERS`

## Where to Add New Code

**New Feature (e.g., new match type):**
- Primary code: `src/server/` - Create new manager or extend existing (e.g., src/server/MyFeatureManager.luau)
- Client handler: `src/client/` - Create controller if input/effects needed
- UI panel: `src/client/UI/MyFeatureUI.luau` - Create panel and register in MainUI
- Configuration: Add parameters to `src/shared/Config.luau`
- Tests: Add `.spec.luau` file in `src/shared/__tests__/`
- Remotes: Register new RemoteEvent in `default.project.json` > Remotes folder
- Call server logic from client by firing remote, server broadcasts results to all/specific players

**New Component/Module:**
- Implementation: `src/client/UI/[ComponentName]UI.luau` for UI, or `src/server/[System]Manager.luau` for server logic
- Pattern: Create module with new() constructor returning self
- Export types if module is used by other systems

**Utilities:**
- Shared helpers: `src/shared/[Name].luau` (e.g., Logger.luau, RemoteRegistry.luau)
- Client-only utilities: `src/client/[Name].luau` (e.g., TweenHelper.luau)
- Server-only utilities: `src/server/[Name].luau` (e.g., DataStoreHelper.luau)

## Special Directories

**ReplicatedStorage.Remotes:**
- Purpose: All client↔server communication via RemoteEvents
- Generated: No (defined in default.project.json)
- Committed: Yes (tree structure in JSON)
- Pattern: Each RemoteEvent corresponds to one game action
- 70+ remotes defined (StartGame, UseItem, UpdateScore, BuyShopItem, etc.)

**ReplicatedStorage.Shared:**
- Purpose: Shared code accessible to both server and client
- Generated: No (maps to src/shared)
- Committed: Yes (source code)
- Pattern: No circular dependencies, safe to require from anywhere

**Workspace.Stages:**
- Purpose: Runtime container for generated stage instances during races
- Generated: Yes (created by MapManager at runtime)
- Committed: No (generated per-match)
- Pattern: MapManager:generateStages() creates stage instances here

**Workspace.Lobby:**
- Purpose: Persistent lobby area where players spawn
- Generated: No (defined in default.project.json)
- Committed: Yes (static geometry)
- Contains: SelectionZone (triggers match start), ShopZone, FallFloor, paths, hedges

**StarterPlayer.StarterPlayerScripts.Client:**
- Purpose: Client-side entry point
- Generated: No (maps to src/client)
- Committed: Yes (source code)
- Pattern: Rojo maps this folder to StarterPlayer hierarchy

**ServerScriptService.Server:**
- Purpose: Server-side entry point
- Generated: No (maps to src/server)
- Committed: Yes (source code)
- Pattern: Rojo maps this folder to ServerScriptService hierarchy

**ReplicatedFirst.Loading:**
- Purpose: Loading screen (runs before game initializes)
- Generated: No (maps to src/loading)
- Committed: Yes (source code)
- Pattern: Single init.client.luau that preloads assets and displays progress

---

*Structure analysis: 2026-03-21*
