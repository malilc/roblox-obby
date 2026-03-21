# Coding Conventions

**Analysis Date:** 2026-03-21

## Naming Patterns

**Files:**
- PascalCase for module/manager files: `GameManager.luau`, `MatchManager.luau`, `CurrencyManager.luau`
- camelCase for utility/helper files: `run-tests.server.luau`
- Suffixes for lifecycle files: `.server.luau`, `.client.luau`, `init.luau`
- Test files use `.spec.luau` suffix: `GamePassLogic.spec.luau`, `ClassTypes.spec.luau`

**Functions:**
- camelCase for function names: `getClass()`, `calculateStats()`, `loadAsync()`, `saveAsync()`
- Getter pattern: `get*` prefix for accessors: `getDataStore()`, `getClass()`, `getCoinMultiplier()`
- Setter pattern: `set*` prefix for mutators: `setEquippedClass()`, `setActiveTitle()`
- Pure logic predicates: `is*` prefix: `isValidPassId()`, `hasGamePass()`, `isRateLimited()`
- Constructor: `new()` method for creating instances with metatables
- Private functions: Prefix with underscore when internal: `local function formatMessage(...)`

**Variables:**
- camelCase for local and instance variables: `self.playerStates`, `self.respawnCooldowns`
- UPPER_SNAKE_CASE for constants: `MAX_RETRIES`, `RETRY_DELAY_BASE`, `SCHEMA_VERSION`
- Descriptive boolean prefixes: `isPlaying`, `hasSeenTutorial`, `dismissedPromoVersion`
- Collections use plural nouns: `players`, `rooms`, `connections`, `datastores`

**Types:**
- PascalCase for exported type names: `ClassDefinition`, `ItemDefinition`, `PlayerData`, `MatchRoom`
- Suffix with `Data` or `State` for data structures: `ClassMasteryData`, `PlayerCurrencyData`
- Suffix with `Snapshot` for readonly copies: `ClassMasterySnapshot`, `TitleSnapshot`, `MasteryRewardSnapshot`
- Union types use pipe syntax: `"Lobby" | "Playing" | "Finished" | "Spectating"`
- Interface-like types use `Like` suffix: `CurrencyManagerLike` (for cross-reference contracts)

## Code Style

**Formatting:**
- 4 spaces for indentation (no tabs)
- Opening braces on same line: `function GameManager.new()`
- Blank lines separate logical sections
- Comments precede code blocks they describe

**Linting:**
- Type annotations required on all exports and public functions
- Use `--` for single-line comments
- Use local functions for private utilities
- No global functions; all code in modules/classes

**Comments Style:**
- Thai language comments common in code (describing game mechanics in Thai)
- Comments precede sections they describe
- Example: `-- ========== COMMON ITEMS (พบบ่อย) ==========` (separator style)
- Comments describe WHY not WHAT when non-obvious

## Import Organization

**Order:**
1. Roblox services: `game:GetService()` calls
2. ReplicatedStorage modules: `require(ReplicatedStorage.Shared.*)`
3. Local modules: `require(script.Parent.*)`
4. Config/Logger last among dependencies

**Path Aliases:**
- `ReplicatedStorage.Shared` for shared modules
- `ReplicatedStorage.DevPackages` for test dependencies
- No path aliasing used; explicit full paths required

**Example Pattern:**
```luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapManager = require(script.Parent.MapManager)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Logger)
```

## Error Handling

**Patterns:**
- `pcall` for exception handling: `local success, result = pcall(function() ... end)`
- Return `(boolean, value?)` tuples for async operations: `DataStoreHelper.loadAsync(name, key)` returns `(success: boolean, data: any?)`
- Nil returns for "not found": `getClass("Invalid")` returns `nil` rather than error
- Logger.warn for non-fatal errors with context tag: `Logger.warn("DataStoreHelper", "Failed to get DataStore:", name)`
- Return defaults instead of throwing: `getMasteryMaxLevel()` returns `1` minimum, never fails

**Retry Logic:**
- Exponential backoff with base 1 second: `RETRY_DELAY_BASE * (2 ^ (attempt - 1))`
- MAX_RETRIES constant for configurable attempts
- Log each attempt for debugging
- Return false/nil after all retries exhausted

## Logging

**Framework:** Logger.luau custom implementation (not console)

**Levels:**
- `Logger.Level.DEBUG` = 1
- `Logger.Level.INFO` = 2
- `Logger.Level.WARN` = 3
- `Logger.Level.ERROR` = 4
- `Logger.Level.NONE` = 5

**Patterns:**
- All log calls include tag (first param): `Logger.debug("MatchManager", "Room created", roomId)`
- Tags are module/component names for filtering
- Format: `formatMessage(tag, ...)` creates `[tag] arg1 arg2 arg3` output
- Config.Debug.Enabled controls log level (auto-configured in Logger.luau)

**When to Log:**
- Async operation failures: store operations, remote calls
- Invalid input received: bad passId, unknown class
- State transitions: player joined, game started
- DEBUG level for detailed tracing (only in debug builds)

## Comments

**When to Comment:**
- Complex business logic that isn't self-evident
- Non-obvious design decisions (e.g., "we use numeric gamePassId lookup because...")
- Thai language acceptable and common for game mechanic explanations
- Section headers use separator style with comment blocks

**JSDoc/TSDoc:**
- Not used in this codebase
- Type annotations serve documentation purpose
- Comments describe behavior instead

**Example:**
```luau
-- Pure ownership check: return true only if passesMap[passId] == true
function GamePassLogic.hasGamePass(passesMap: {[string]: boolean}?, passId: string): boolean
	if not passesMap then return false end
	return passesMap[passId] == true
end
```

## Function Design

**Size:**
- Prefer small functions (10-50 lines)
- Complex logic extracted to separate functions
- Managers may be longer (100+ lines) if well-organized

**Parameters:**
- Type all parameters: `function load(key: string, retries: number?)`
- Use optional `?` for defaultable params
- Pass tables for multiple related params: `GamePassLogic.resolveOwnership({ savedPasses, apiResults, debugEnabled })`

**Return Values:**
- Type return values: `function load(): (boolean, any?)`
- Multiple returns use tuples: `local speed, jump = ClassTypes.calculateStats(...)`
- Single nil return for "not found": not an error state

**Example Function:**
```luau
-- Calculate modified stats based on class modifiers
function ClassTypes.calculateStats(classId: string, baseWalkSpeed: number, baseJumpPower: number): (number, number)
	local classDef = ClassTypes.Classes[classId]
	if not classDef then
		return baseWalkSpeed, baseJumpPower
	end

	local modifiedWalkSpeed = baseWalkSpeed * classDef.walkSpeedMod
	local modifiedJumpPower = baseJumpPower * classDef.jumpPowerMod

	return modifiedWalkSpeed, modifiedJumpPower
end
```

## Module Design

**Exports:**
- `export type SomeType = {...}` at top level for public types
- Functions exported without `export` keyword (implicit)
- Module returns table with all public functions: `return ClassTypes`
- Metatables for class-like behavior: `setmetatable({}, Manager)` with `__index = Manager`

**Barrel Files:**
- Not used; each file is self-contained module
- No intermediate index files

**Initialization Pattern:**
- Constructor function: `Manager.new()` returns initialized instance
- Setup methods called separately: `manager:setup()` or `manager:setupRemotes()`
- All state on `self` metatabled instance

---

*Convention analysis: 2026-03-21*
