# Testing Patterns

**Analysis Date:** 2026-03-21

## Test Framework

**Runner:**
- Jest (Lua implementation via DevPackages.Jest)
- Version: unspecified in package manifests
- Config: `src/shared/jest.config.luau`

**Assertion Library:**
- Jest expect API (JestGlobals.expect)
- Custom matchers: `toBe()`, `toBeNil()`, `toBeDefined()`, `toBeCloseTo()`, `toBeGreaterThan()`

**Run Commands:**
```bash
run-in-roblox --load test.project.json  # Run all tests (uses scripts/run-tests.server.luau)
```

**Test Execution:**
- Entry point: `scripts/run-tests.server.luau`
- Loads Jest from DevPackages
- Runs tests in Roblox environment via `Jest.runCLI()`
- Exits with code 0 on success, 1 on failure (if ProcessService available)

## Test File Organization

**Location:**
- Co-located with source modules in `__tests__` subdirectory
- `src/shared/__tests__/` contains all unit tests

**Naming:**
- `.spec.luau` suffix: `GamePassLogic.spec.luau`, `ClassTypes.spec.luau`
- Matches source module name for easy location

**File Structure:**
```
src/shared/
├── GamePassLogic.luau
├── __tests__/
│   ├── GamePassLogic.spec.luau
│   ├── ClassTypes.spec.luau
│   ├── ItemTypes.spec.luau
│   ├── StageInfo.spec.luau
│   └── jest.config.luau
```

## Test Structure

**Suite Organization:**
```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

local ModuleToTest = require(ReplicatedStorage.Shared.ModuleToTest)

describe("ModuleName", function()
	describe("functionName", function()
		it("should do something when condition X", function()
			-- Arrange
			local input = ...

			-- Act
			local result = ModuleToTest.functionName(input)

			-- Assert
			expect(result).toBe(expectedValue)
		end)
	end)
end)
```

**Patterns:**
- Nested `describe()` blocks organize tests by function
- Each function gets its own describe block with multiple `it()` specs
- Test name starts with "should": "should return true for valid id"
- AAA pattern: Arrange → Act → Assert (comments help readability)

**Example Test Suite (GamePassLogic.spec.luau):**
- 45 unit tests across 6 function suites (isValidPassId, getPassIdByGamePassId, hasGamePass, resolveOwnership, getCoinMultiplier, getXPMultiplier, getMaxItemSlots, isRateLimited)
- Tests cover happy paths, edge cases, nil handling, boundary conditions
- No setup/teardown functions needed (pure functions tested in isolation)

## Mocking

**Framework:**
- No explicit mocking framework used (not needed for pure functions)
- Pure business logic modules tested directly without mocks
- Config module auto-loaded and available to tests

**Patterns:**
- Pass data structures directly as parameters
- No external service mocking (no async operations in tested modules)
- Test uses real Config.GamePasses for lookups
- Example from GamePassLogic tests:
```luau
it("should find DoubleCoin from numeric id", function()
	expect(GamePassLogic.getPassIdByGamePassId(1740745787)).toBe("DoubleCoin")
end)
```

**What to Mock:**
- Not applicable; test pure functions with table parameters
- Config is loaded naturally (not mocked)

**What NOT to Mock:**
- Don't mock Config or other shared modules
- Don't mock the functions being tested
- Avoid mocks for pure business logic

## Fixtures and Factories

**Test Data:**
- Inline test data in each test case
- Pass literal tables as parameters:
```luau
it("should return true with DoubleCoin", function()
	expect(GamePassLogic.getCoinMultiplier({ DoubleCoin = true })).toBe(2)
end)
```

**Location:**
- No centralized fixtures directory
- Test data defined in test files where used
- Data kept small (single tables, simple values)

**Pattern for Complex Data:**
```luau
it("should handle mixed scenario with 4 passes", function()
	local result = GamePassLogic.resolveOwnership({
		savedPasses = {
			DoubleCoin = true,
			VIP = false,
			ExtraSlot = false,
			DoubleXP = true,
		},
		apiResults = {
			DoubleCoin = true,
			VIP = true,
			ExtraSlot = true,
		},
		debugEnabled = true,
	})
	expect(result.DoubleCoin).toBe(true)
end)
```

## Coverage

**Requirements:**
- No enforced coverage targets
- Focus on critical business logic paths
- Pure functions in shared modules prioritized

**View Coverage:**
- Not detected in codebase
- Must run via Jest output or external tools

**Current Coverage:**
- GamePassLogic: 45 tests covering 9 functions
- ClassTypes: 27 tests covering 4 functions
- ItemTypes: extensive tests (exact count TBD)
- StageInfo: extensive tests (exact count TBD)
- All critical game mechanic modules tested

## Test Types

**Unit Tests:**
- Scope: Individual pure functions (logic, calculations, lookups)
- Approach: Direct function calls with parameters, assert return values
- Examples: `GamePassLogic.getCoinMultiplier()`, `ClassTypes.calculateStats()`
- No mocking, no setup, instant execution

**Integration Tests:**
- Not used in current test suite
- Would test manager interactions (GameManager ↔ CurrencyManager)
- Not implemented (managers have side effects)

**E2E Tests:**
- Not used
- Would require full Roblox environment and game instances
- Not included in Jest test suite

## Common Patterns

**Nil and Not-Found Testing:**
```lua
it("should return nil for invalid class ID", function()
	local class = ClassTypes.getClass("FakeClass")
	expect(class).toBeNil()
end)
```

**Boolean and Predicate Testing:**
```lua
it("should return false for empty string", function()
	expect(GamePassLogic.isValidPassId("")).toBe(false)
end)

it("should return true for known pass", function()
	expect(GamePassLogic.isValidPassId("DoubleCoin")).toBe(true)
end)
```

**Edge Cases and Boundaries:**
```lua
it("should return false when exactly at cooldown boundary", function()
	expect(GamePassLogic.isRateLimited(99.5, 100, 0.5)).toBe(false)
end)

it("should return true when within cooldown", function()
	expect(GamePassLogic.isRateLimited(99.8, 100, 0.5)).toBe(true)
end)
```

**Multi-Value Returns:**
```lua
it("should apply Runner speed boost and jump penalty", function()
	local speed, jump = ClassTypes.calculateStats("Runner", 16, 50)
	expect(speed).toBeCloseTo(18.4, 1) -- 16 * 1.15
	expect(jump).toBeCloseTo(45, 1)     -- 50 * 0.90
end)
```

**Table Operations Testing:**
```lua
it("should not mutate input savedPasses table", function()
	local saved = { DoubleCoin = false }
	GamePassLogic.resolveOwnership({
		savedPasses = saved,
		apiResults = { DoubleCoin = true },
		debugEnabled = false,
	})
	-- Original table must remain unchanged
	expect(saved.DoubleCoin).toBe(false)
end)
```

**Collection Iteration Testing:**
```lua
it("should return correct class order", function()
	local ids = ClassTypes.getAllClassIds()
	expect(ids[1]).toBe("Normal")
	expect(ids[2]).toBe("Runner")
	expect(ids[3]).toBe("Jumper")
	expect(ids[4]).toBe("Tank")
end)
```

## Test Discovery

**Pattern:**
- Jest config in `src/shared/jest.config.luau`
- Test match pattern: `"**/*.spec"` (matches `*.spec.luau`)
- All tests in `src/shared/__tests__/` auto-discovered
- Run via `scripts/run-tests.server.luau` entry point

**Config File (`jest.config.luau`):**
```lua
return {
	testMatch = { "**/*.spec" },
}
```

## Assertions Available

Based on test files observed:

```lua
expect(value).toBe(expected)              -- Strict equality
expect(value).toBeNil()                   -- Null/nil check
expect(value).toBeDefined()               -- Not nil check
expect(value).toBeCloseTo(expected, deci) -- Float comparison with decimal places
expect(value).toBeGreaterThan(expected)   -- Greater than
expect(#collection).toBe(count)           -- Array length
expect(table.find(arr, val)).toBeNil()    -- Table search (returns nil if not found)
```

---

*Testing analysis: 2026-03-21*
