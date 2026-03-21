<!-- GSD:project-start source:PROJECT.md -->
## Project

**Responsive UI Overhaul**

A focused fix to make all modal/popup UI panels in the Roblox obby game scale properly on mobile phone screens. The game has 23 UI panels with fixed pixel sizes (e.g., 780x580) that overflow and get cut off on small screens. This project adds viewport-aware scaling so modals shrink to fit any screen while keeping their existing layout intact.

**Core Value:** Every modal must be fully visible and usable on both desktop and mobile phone screens — no content cut off, no overflow.

### Constraints

- **Tech stack**: Roblox Luau, all UI created via code (no .rbxm GUI files)
- **Approach**: UIScale-based shrinking only — no layout changes, no content reflow
- **Compatibility**: Must work on both desktop and mobile (phone) Roblox clients
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Luau (Roblox dialect of Lua) - Game logic, server/client scripts, shared modules
- Lua - Test framework and utilities
## Runtime
- Roblox Studio (development)
- Roblox Client & Server (production)
- Rojo 7.7.0-rc.1 - Project syncing and file-to-place compilation
- Wally 0.3.2 - Package manager for Roblox dependencies
## Frameworks
- None (native Roblox API)
- Jest 3.10.0 (jsdotlua/jest) - Luau unit test framework
- Jest Globals 3.10.0 (jsdotlua/jest-globals) - Test globals and assertions
- Rojo 7.7.0-rc.1 - Project syncing
- Aftman - Toolchain manager for version-locked tools
- Run-in-Roblox 0.3.0 - Test execution in Roblox environment
## Key Dependencies
- jsdotlua/jest@3.10.0 - Complete test framework with mocking, snapshots, assertions
- jsdotlua/luau-polyfill@1.2.7 - Polyfill for JS-like standard library (collections, strings, timers)
- jsdotlua/promise@3.5.2 - Promise implementation for async operations
- jsdotlua/chalk@0.2.1 - Terminal color output
- jsdotlua/luau-regexp@0.2.1 - Regular expression support
- jsdotlua/console@1.2.7 - Console utilities
- jsdotlua/collections@1.2.7 - Collection utilities (tables, sets, maps)
## Configuration
- Development configuration via `Config.lua` shared module
- Debug mode toggleable in Config (Debug.Enabled flag)
- Testing mode flag for match timing (Match.IsTestingMode)
- `default.project.json` - Main Rojo configuration for game place
- `test.project.json` - Test-specific Rojo configuration
- `aftman.toml` - Tool version pinning (Rojo, Wally, run-in-roblox)
- `wally.toml` - Package manifest and dev-dependency declarations
- `wally.lock` - Lockfile for reproducible builds (auto-generated)
## Project Structure
## Platform Requirements
- Roblox Studio (latest compatible with Rojo 7.7.0-rc.1)
- Aftman (for tool installation/management)
- Text editor with Luau syntax support
- Roblox platform (published place/game)
- No external servers required (self-contained game)
## Luau Type Strictness
- Function signatures with parameter types
- Table type definitions via `:: {[key]: Type}` syntax
- Optional types via `?` operator
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- PascalCase for module/manager files: `GameManager.luau`, `MatchManager.luau`, `CurrencyManager.luau`
- camelCase for utility/helper files: `run-tests.server.luau`
- Suffixes for lifecycle files: `.server.luau`, `.client.luau`, `init.luau`
- Test files use `.spec.luau` suffix: `GamePassLogic.spec.luau`, `ClassTypes.spec.luau`
- camelCase for function names: `getClass()`, `calculateStats()`, `loadAsync()`, `saveAsync()`
- Getter pattern: `get*` prefix for accessors: `getDataStore()`, `getClass()`, `getCoinMultiplier()`
- Setter pattern: `set*` prefix for mutators: `setEquippedClass()`, `setActiveTitle()`
- Pure logic predicates: `is*` prefix: `isValidPassId()`, `hasGamePass()`, `isRateLimited()`
- Constructor: `new()` method for creating instances with metatables
- Private functions: Prefix with underscore when internal: `local function formatMessage(...)`
- camelCase for local and instance variables: `self.playerStates`, `self.respawnCooldowns`
- UPPER_SNAKE_CASE for constants: `MAX_RETRIES`, `RETRY_DELAY_BASE`, `SCHEMA_VERSION`
- Descriptive boolean prefixes: `isPlaying`, `hasSeenTutorial`, `dismissedPromoVersion`
- Collections use plural nouns: `players`, `rooms`, `connections`, `datastores`
- PascalCase for exported type names: `ClassDefinition`, `ItemDefinition`, `PlayerData`, `MatchRoom`
- Suffix with `Data` or `State` for data structures: `ClassMasteryData`, `PlayerCurrencyData`
- Suffix with `Snapshot` for readonly copies: `ClassMasterySnapshot`, `TitleSnapshot`, `MasteryRewardSnapshot`
- Union types use pipe syntax: `"Lobby" | "Playing" | "Finished" | "Spectating"`
- Interface-like types use `Like` suffix: `CurrencyManagerLike` (for cross-reference contracts)
## Code Style
- 4 spaces for indentation (no tabs)
- Opening braces on same line: `function GameManager.new()`
- Blank lines separate logical sections
- Comments precede code blocks they describe
- Type annotations required on all exports and public functions
- Use `--` for single-line comments
- Use local functions for private utilities
- No global functions; all code in modules/classes
- Thai language comments common in code (describing game mechanics in Thai)
- Comments precede sections they describe
- Example: `-- ========== COMMON ITEMS (พบบ่อย) ==========` (separator style)
- Comments describe WHY not WHAT when non-obvious
## Import Organization
- `ReplicatedStorage.Shared` for shared modules
- `ReplicatedStorage.DevPackages` for test dependencies
- No path aliasing used; explicit full paths required
## Error Handling
- `pcall` for exception handling: `local success, result = pcall(function() ... end)`
- Return `(boolean, value?)` tuples for async operations: `DataStoreHelper.loadAsync(name, key)` returns `(success: boolean, data: any?)`
- Nil returns for "not found": `getClass("Invalid")` returns `nil` rather than error
- Logger.warn for non-fatal errors with context tag: `Logger.warn("DataStoreHelper", "Failed to get DataStore:", name)`
- Return defaults instead of throwing: `getMasteryMaxLevel()` returns `1` minimum, never fails
- Exponential backoff with base 1 second: `RETRY_DELAY_BASE * (2 ^ (attempt - 1))`
- MAX_RETRIES constant for configurable attempts
- Log each attempt for debugging
- Return false/nil after all retries exhausted
## Logging
- `Logger.Level.DEBUG` = 1
- `Logger.Level.INFO` = 2
- `Logger.Level.WARN` = 3
- `Logger.Level.ERROR` = 4
- `Logger.Level.NONE` = 5
- All log calls include tag (first param): `Logger.debug("MatchManager", "Room created", roomId)`
- Tags are module/component names for filtering
- Format: `formatMessage(tag, ...)` creates `[tag] arg1 arg2 arg3` output
- Config.Debug.Enabled controls log level (auto-configured in Logger.luau)
- Async operation failures: store operations, remote calls
- Invalid input received: bad passId, unknown class
- State transitions: player joined, game started
- DEBUG level for detailed tracing (only in debug builds)
## Comments
- Complex business logic that isn't self-evident
- Non-obvious design decisions (e.g., "we use numeric gamePassId lookup because...")
- Thai language acceptable and common for game mechanic explanations
- Section headers use separator style with comment blocks
- Not used in this codebase
- Type annotations serve documentation purpose
- Comments describe behavior instead
## Function Design
- Prefer small functions (10-50 lines)
- Complex logic extracted to separate functions
- Managers may be longer (100+ lines) if well-organized
- Type all parameters: `function load(key: string, retries: number?)`
- Use optional `?` for defaultable params
- Pass tables for multiple related params: `GamePassLogic.resolveOwnership({ savedPasses, apiResults, debugEnabled })`
- Type return values: `function load(): (boolean, any?)`
- Multiple returns use tuples: `local speed, jump = ClassTypes.calculateStats(...)`
- Single nil return for "not found": not an error state
## Module Design
- `export type SomeType = {...}` at top level for public types
- Functions exported without `export` keyword (implicit)
- Module returns table with all public functions: `return ClassTypes`
- Metatables for class-like behavior: `setmetatable({}, Manager)` with `__index = Manager`
- Not used; each file is self-contained module
- No intermediate index files
- Constructor function: `Manager.new()` returns initialized instance
- Setup methods called separately: `manager:setup()` or `manager:setupRemotes()`
- All state on `self` metatabled instance
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- Remotes-based server-client communication (ReplicatedStorage.Remotes)
- Manager pattern for server-side systems (GameManager coordinates sub-managers)
- State synchronization through RemoteEvents
- Client-side UI/UX isolation from server logic
- Shared type definitions and utilities in shared directory
## Layers
- Purpose: Game loop, state authority, player progression, match coordination
- Location: `src/server/`
- Contains: Core managers (GameManager, MatchManager, CurrencyManager, etc.), data persistence
- Depends on: ReplicatedStorage.Shared, Roblox services (Players, DataStore, etc.)
- Used by: Client via Remotes
- Purpose: UI rendering, input handling, visual effects, sound management
- Location: `src/client/`
- Contains: UI modules, controllers (FlyController, UltimateSkillController), effects
- Depends on: Server via Remotes, shared types/config, Roblox services
- Used by: Players
- Purpose: Centralized type definitions, configuration, business logic utilities
- Location: `src/shared/`
- Contains: Types.luau, Config.luau, Logger, RemoteRegistry, ClassTypes, ItemTypes, GamePassLogic, StageInfo
- Depends on: None (no circular dependencies)
- Used by: Both server and client
- Purpose: Pre-game asset preloading and visual feedback
- Location: `src/loading/init.client.luau` (runs in ReplicatedFirst)
- Contains: Loading screen UI, asset preload with progress bar
- Depends on: ThemeConfig for colors
- Used by: Before game fully loads
## Data Flow
- **Server**: GameManager.playerStates tracks "Lobby" | "Playing" | "Finished" | "Spectating"
- **Server**: MatchManager.rooms tracks all active races
- **Client**: MainUI tracks which panels are visible
- **Shared**: Config provides read-only game parameters
## Key Abstractions
- Purpose: Central coordinator for all game systems
- Examples: `src/server/GameManager.luau`
- Pattern: Creates and delegates to specialized managers (MatchManager, ClassManager, ItemManager, etc.)
- Purpose: Manages matchmaking, race rooms, stage voting, race progress
- Examples: `src/server/MatchManager.luau`
- Pattern: Maintains MatchRoom objects, handles remote events
- Purpose: Manages player currency, gems, class unlocks, mastery progression, titles
- Examples: `src/server/CurrencyManager.luau`
- Pattern: Persists to DataStore, exposes check/spend/earn functions
- Purpose: Generates random stage sequences from StageTemplates
- Examples: `src/server/MapManager.luau`
- Pattern: Creates stage instances, manages stage lifecycle
- Purpose: Detects player interaction with lobby selection zone
- Examples: `src/server/SelectionZoneManager.luau`
- Pattern: Listens to physics/touch events, triggers UI events
- Purpose: Orchestrates all client UI panels (Shop, Leaderboard, Classes, Settings, etc.)
- Examples: `src/client/UI/MainUI.luau`
- Pattern: Creates UI components, manages visibility/mutual exclusion, coordinates callbacks
- Purpose: Centralized remote access with caching
- Examples: `src/shared/RemoteRegistry.luau`
- Pattern: .get(name) returns cached RemoteEvent, avoids repeated lookups
- Purpose: Centralized color/style definitions and helper functions
- Examples: `src/shared/ThemeConfig.luau`
- Pattern: Provides Color3 constants and applyCorner/applyStroke/applyPadding helpers
## Entry Points
- Location: `src/server/init.server.luau`
- Triggers: Server starts
- Responsibilities: Initializes GameManager, sets up SoundGroup, binds DataStore save on shutdown
- Location: `src/client/init.client.luau`
- Triggers: Player joins (after character creation)
- Responsibilities: Initializes MainUI, ItemEffects, SoundManager, UltimateSkillController, sets up remotes, camera snapshots
- Location: `src/loading/init.client.luau`
- Triggers: Game loads (ReplicatedFirst priority)
- Responsibilities: Shows loading screen with progress bar, preloads assets, waits for character
## Error Handling
- Logger.warn() for non-critical issues (missing remotes, nil checks)
- Logger.error() for critical failures (DataStore fails)
- Graceful degradation: Features disabled if dependencies unavailable
- Timeout-based fallbacks (e.g., UpdateLog popup has 5-second timeout)
- Remote failures caught via RemoteRegistry.get() returning nil
## Cross-Cutting Concerns
- Implementation: `src/shared/Logger.luau` with .info(), .warn(), .error() methods
- Usage: Every manager logs state changes, remotes, errors
- Accessibility: Require at top of file: `local Logger = require(ReplicatedStorage.Shared.Logger)`
- Implementation: Inline checks in remote handlers
- Patterns: canAfford() before spend, isClassUnlocked() before equip, max bounds checks
- Location: Validation in handler functions (CurrencyManager, ClassManager, etc.)
- Implementation: Roblox UserId implicit (only server-trusted)
- Pattern: Remote handlers assume player parameter is authentic
- Additional: GamePass verification via MarketplaceService:UserOwnsGamePass()
- Folder: ReplicatedStorage.Remotes
- Pattern: One RemoteEvent per game action
- Examples: StartGame, UseItem, BuyShopItem, SelectClass, VoteStages
- Client→Server: Fire with player action (player implicit)
- Server→Client: Fire to specific player with data
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
