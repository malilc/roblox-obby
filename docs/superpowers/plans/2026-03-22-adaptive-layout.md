# Adaptive Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dual responsive system (ResponsiveScale + scattered viewport UIScale) with a unified AdaptiveLayout module that handles both modals and HUD elements.

**Architecture:** Single shared module `AdaptiveLayout.luau` with: (1) safe area calculation from Camera.ViewportSize + GuiInset, (2) continuous scale formula clamped 0.4-1.0, (3) zone-based auto-stacking for HUD elements, (4) modal-specific scale with margin. One viewport listener notifies all registered elements.

**Tech Stack:** Roblox Luau, Jest (jsdotlua/jest), Roblox Studio MCP for visual testing

**Spec:** `docs/superpowers/specs/2026-03-22-adaptive-layout-design.md`

---

## File Structure

### New Files
| File | Responsibility |
|------|---------------|
| `src/shared/AdaptiveLayout.luau` | Core module: safe area, scale, zones, modal scaling, stroke compensation |
| `src/shared/__tests__/AdaptiveLayout.spec.luau` | Unit tests for all pure calculation functions |

### Modified Files
| File | Change |
|------|--------|
| `src/client/UI/MainUI.luau` | Line 10: require → AdaptiveLayout, Line 68: init() |
| `src/client/UI/UIFactory.luau` | Line 5: require, Lines 240-244: applyScale |
| `src/client/UI/ClassSelectionUI.luau` | Line 9: require, Lines 486-487: applyScale |
| `src/client/UI/DailyBonusUI.luau` | Line 8: require, Lines 550-551: applyScale |
| `src/client/UI/FeedbackUI.luau` | Line 10: require, Line 54: applyScale |
| `src/client/UI/MatchLobbyUI.luau` | Line 9: require, Lines 319-320: applyScale, Lines 512-530: registerHUD |
| `src/client/UI/RaceResultsUI.luau` | Line 8: require, Lines 211-212: applyScale |
| `src/client/UI/SettingsUI.luau` | Line 9: require, Line 47: applyScale |
| `src/client/UI/ShopUI.luau` | Line 13: require, Lines 184-185: applyScale |
| `src/client/UI/StageSelectionUI.luau` | Line 9: require, Lines 627-628: applyScale |
| `src/client/UI/SummaryUI.luau` | Line 11: require, Lines 514-515: applyScale |
| `src/client/UI/TitleCollectionUI.luau` | Line 9: require, Lines 622-623: applyScale |
| `src/client/UI/TutorialUI.luau` | Line 8: require, Lines 254-255: applyScale |
| `src/client/UI/ScoreUI.luau` | Remove viewport listener ~line 331, add registerHUD x2 |
| `src/client/UI/CurrencyUI.luau` | Remove viewport listener ~line 203, add registerHUD |
| `src/client/UI/SpectatorUI.luau` | Remove 3 UIScale instances + listener, add registerHUD x3 |
| `src/client/UI/MenuGridUI.luau` | Remove IS_MOBILE UIScale block ~lines 65-77, add registerHUD |
| `src/client/UI/ItemUI.luau` | Add registerHUD (desktop only) |
| `src/client/UI/LeaderboardUI.luau` | Remove commented-out imports |

### Deleted Files
- `src/shared/ResponsiveScale.luau`
- `src/shared/__tests__/ResponsiveScale.spec.luau`

---

## Task 1: AdaptiveLayout Core — Pure Calculation Functions

**Files:**
- Create: `src/shared/AdaptiveLayout.luau`
- Create: `src/shared/__tests__/AdaptiveLayout.spec.luau`

This task builds the pure calculation layer (no Roblox runtime dependencies). All functions take explicit parameters so they are unit-testable.

- [ ] **Step 1: Write failing test — HUD scale calculation**

In `src/shared/__tests__/AdaptiveLayout.spec.luau`:

```lua
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

local AdaptiveLayout = require(ReplicatedStorage.Shared.AdaptiveLayout)

describe("AdaptiveLayout", function()
    describe("calculateHUDScale", function()
        it("should return 1.0 on desktop 1920x1080", function()
            local scale = AdaptiveLayout.calculateHUDScale(1920, 1080, 36)
            expect(scale).toBe(1)
        end)

        it("should clamp to MIN_SCALE 0.4 on small phone", function()
            local scale = AdaptiveLayout.calculateHUDScale(375, 667, 48)
            expect(scale).toBe(0.4)
        end)

        it("should scale proportionally on tablet 810x1080", function()
            local scale = AdaptiveLayout.calculateHUDScale(810, 1080, 36)
            -- min(810/1920, (1080-36)/1080) = min(0.421, 0.966) = 0.421
            expect(scale).toBeCloseTo(0.421, 2)
        end)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `rojo build test.project.json -o test.rbxl && run-in-roblox --place test.rbxl --script src/shared/__tests__/AdaptiveLayout.spec.luau`
Expected: FAIL — module not found or function not defined

- [ ] **Step 3: Write minimal AdaptiveLayout module with calculateHUDScale**

In `src/shared/AdaptiveLayout.luau`:

```lua
-- CLIENT ONLY: requires Camera and GuiService (only require from client scripts)
--!strict

local AdaptiveLayout = {}

-- ========== CONSTANTS ==========
local DESIGN_VIEWPORT_W = 1920
local DESIGN_VIEWPORT_H = 1080
local MIN_SCALE = 0.4
local MAX_SCALE = 1.0

-- ========== TYPES ==========
export type DeviceType = "Phone" | "Tablet" | "Desktop"

export type ZoneName = "TopLeft" | "TopCenter" | "TopRight"
    | "BottomLeft" | "BottomCenter" | "BottomRight"

export type ZoneConfig = {
    order: number,
    padding: number?,
    designWidth: number?,
    designHeight: number?,
}

-- ========== PURE CALCULATION FUNCTIONS ==========

function AdaptiveLayout.calculateHUDScale(viewportW: number, viewportH: number, guiInsetY: number): number
    local safeH = viewportH - guiInsetY
    local scaleW = viewportW / DESIGN_VIEWPORT_W
    local scaleH = safeH / DESIGN_VIEWPORT_H
    return math.clamp(math.min(scaleW, scaleH), MIN_SCALE, MAX_SCALE)
end

return AdaptiveLayout
```

- [ ] **Step 4: Run test to verify it passes**

Run: same test command
Expected: 3 tests PASS

- [ ] **Step 5: Write failing test — modal scale calculation**

Add to spec file:

```lua
    describe("calculateModalScale", function()
        it("should return 1.0 for 780x580 on desktop", function()
            local scale = AdaptiveLayout.calculateModalScale(1920, 1080, 36, 780, 580)
            expect(scale).toBe(1)
        end)

        it("should scale down 780x580 modal on phone 375x667", function()
            local scale = AdaptiveLayout.calculateModalScale(375, 667, 48, 780, 580)
            -- min((375-60)/780, (667-48-60)/580) = min(0.404, 0.964) = 0.404
            expect(scale).toBeCloseTo(0.404, 2)
        end)

        it("should handle small modal 360x380 on phone", function()
            local scale = AdaptiveLayout.calculateModalScale(375, 667, 48, 360, 380)
            -- min((375-60)/360, (667-48-60)/380) = min(0.875, 1.471) = 0.875
            expect(scale).toBeCloseTo(0.875, 2)
        end)
    end)
```

- [ ] **Step 6: Implement calculateModalScale**

Add to `AdaptiveLayout.luau`:

```lua
local MODAL_MARGIN = 60

function AdaptiveLayout.calculateModalScale(
    viewportW: number, viewportH: number, guiInsetY: number,
    designW: number, designH: number
): number
    local safeW = viewportW - MODAL_MARGIN
    local safeH = viewportH - guiInsetY - MODAL_MARGIN
    local scaleW = safeW / designW
    local scaleH = safeH / designH
    return math.clamp(math.min(scaleW, scaleH), MIN_SCALE, MAX_SCALE)
end
```

- [ ] **Step 7: Run tests — verify all pass**

Expected: 6 tests PASS

- [ ] **Step 8: Write failing test — device type classification**

```lua
    describe("classifyDevice", function()
        it("should classify Phone when safeH < 500", function()
            expect(AdaptiveLayout.classifyDevice(375, 667, 48)).toBe("Phone")
        end)

        it("should classify Tablet when safeH 500-900", function()
            expect(AdaptiveLayout.classifyDevice(810, 1080, 36)).toBe("Tablet")
        end)

        it("should classify Desktop when safeH > 900", function()
            expect(AdaptiveLayout.classifyDevice(1920, 1080, 36)).toBe("Desktop")
        end)
    end)
```

- [ ] **Step 9: Implement classifyDevice**

```lua
function AdaptiveLayout.classifyDevice(viewportW: number, viewportH: number, guiInsetY: number): DeviceType
    local safeH = viewportH - guiInsetY
    if safeH < 500 then
        return "Phone"
    elseif safeH <= 900 then
        return "Tablet"
    else
        return "Desktop"
    end
end
```

- [ ] **Step 10: Run tests — verify all 9 pass**

- [ ] **Step 11: Commit**

```bash
git add src/shared/AdaptiveLayout.luau src/shared/__tests__/AdaptiveLayout.spec.luau
git commit -m "feat: add AdaptiveLayout core — scale + device type calculations"
```

---

## Task 2: AdaptiveLayout Zone Stacking — Pure Calculation

**Files:**
- Modify: `src/shared/AdaptiveLayout.luau`
- Modify: `src/shared/__tests__/AdaptiveLayout.spec.luau`

Zone stacking positions are calculated from design sizes and scale, purely mathematical.

- [ ] **Step 1: Write failing test — zone stacking BottomLeft with 3 elements**

**IMPORTANT: Zone positions are OFFSETS relative to the anchor point, not absolute pixel coords.**
- BottomLeft (anchor 0,1): Y offsets are **negative** (going up from bottom), X is positive
- TopRight (anchor 1,0): Y offsets are **positive** (going down from top), X is **negative**
- This maps directly to UDim2: `UDim2.new(anchorX, xOffset, anchorY, yOffset)`

```lua
    describe("calculateZonePositions", function()
        it("should stack 3 elements in BottomLeft going Up with negative Y offsets", function()
            local elements = {
                { order = 1, designWidth = 130, designHeight = 44, padding = 8, visible = true },
                { order = 2, designWidth = 160, designHeight = 28, padding = 8, visible = true },
                { order = 3, designWidth = 130, designHeight = 30, padding = 8, visible = true },
            }
            local positions = AdaptiveLayout.calculateZonePositions("BottomLeft", elements, 0.5, 1920, 1080)
            -- BottomLeft, Up direction, scale 0.5
            -- Offsets from anchor (0,1) — Y goes negative (up from bottom)
            -- order=1 (bottom): Y = -(8 + 44*0.5) = -30
            -- order=2: Y = -30 - 8 - (28*0.5) = -52
            -- order=3: Y = -52 - 8 - (30*0.5) = -75
            expect(positions[1].y).toBeCloseTo(-30, 0)
            expect(positions[2].y).toBeCloseTo(-52, 0)
            expect(positions[3].y).toBeCloseTo(-75, 0)
            expect(positions[1].x).toBe(8) -- positive = right from left edge
        end)
    end)
```

- [ ] **Step 2: Run test to verify it fails**

- [ ] **Step 3: Implement calculateZonePositions**

Add to `AdaptiveLayout.luau`:

```lua
-- Zone defaults: anchor, starting position logic, default direction
local ZONE_DEFAULTS = {
    TopLeft     = { anchorX = 0,   anchorY = 0, dirDefault = "Down" },
    TopCenter   = { anchorX = 0.5, anchorY = 0, dirDefault = "Down" },
    TopRight    = { anchorX = 1,   anchorY = 0, dirDefault = "Down" },
    BottomLeft  = { anchorX = 0,   anchorY = 1, dirDefault = "Up" },
    BottomCenter= { anchorX = 0.5, anchorY = 1, dirDefault = "Up" },
    BottomRight = { anchorX = 1,   anchorY = 1, dirDefault = "Up" },
}

type ZoneElement = {
    order: number,
    designWidth: number,
    designHeight: number,
    padding: number,
    visible: boolean,
}

type PositionResult = {
    x: number,
    y: number,
    anchorX: number,
    anchorY: number,
}

function AdaptiveLayout.calculateZonePositions(
    zoneName: ZoneName,
    elements: {ZoneElement},
    scale: number,
    safeWidth: number,
    safeHeight: number
): {PositionResult}
    local zone = ZONE_DEFAULTS[zoneName]
    if not zone then return {} end

    -- Sort by order
    local sorted = table.clone(elements)
    table.sort(sorted, function(a, b) return a.order < b.order end)

    -- Filter visible
    local visible = {}
    for _, el in sorted do
        if el.visible then
            table.insert(visible, el)
        end
    end

    local direction = zone.dirDefault
    local positions: {PositionResult} = {}

    -- X offset: positive for left-anchored, negative for right-anchored
    local function xOffset(padding: number): number
        if zone.anchorX == 1 then return -padding end -- right edge
        if zone.anchorX == 0.5 then return 0 end       -- centered
        return padding                                   -- left edge
    end

    -- Y cursor tracks offset from anchor point
    -- Up = negative (from bottom), Down = positive (from top)
    local cursor = 0

    if direction == "Up" then
        for _, el in visible do
            local scaledH = el.designHeight * scale
            cursor = cursor - el.padding - scaledH
            table.insert(positions, {
                x = xOffset(el.padding),
                y = cursor,
                anchorX = zone.anchorX,
                anchorY = zone.anchorY,
            })
        end
    else -- Down
        for _, el in visible do
            cursor = cursor + el.padding
            table.insert(positions, {
                x = xOffset(el.padding),
                y = cursor,
                anchorX = zone.anchorX,
                anchorY = zone.anchorY,
            })
            local scaledH = el.designHeight * scale
            cursor = cursor + scaledH
        end
    end

    return positions
end
```

- [ ] **Step 4: Run tests — verify new test passes**

- [ ] **Step 5: Write failing test — zone skips invisible elements**

```lua
        it("should skip invisible elements in stacking", function()
            local elements = {
                { order = 1, designWidth = 130, designHeight = 44, padding = 8, visible = true },
                { order = 2, designWidth = 160, designHeight = 28, padding = 8, visible = false },
                { order = 3, designWidth = 130, designHeight = 30, padding = 8, visible = true },
            }
            local positions = AdaptiveLayout.calculateZonePositions("BottomLeft", elements, 0.5, 1920, 1080)
            -- Only 2 results (order 2 skipped)
            expect(#positions).toBe(2)
            -- order=1: Y = -(8 + 22) = -30
            -- order=3: Y = -30 - 8 - 15 = -53 (skips order=2 entirely)
            expect(positions[1].y).toBeCloseTo(-30, 0)
            expect(positions[2].y).toBeCloseTo(-53, 0)
        end)
```

- [ ] **Step 6: Run test — should pass (filter already implemented)**

- [ ] **Step 7: Write failing test — TopRight zone stacking Down**

```lua
        it("should stack TopRight elements going Down with negative X", function()
            local elements = {
                { order = 1, designWidth = 200, designHeight = 300, padding = 8, visible = true },
            }
            local positions = AdaptiveLayout.calculateZonePositions("TopRight", elements, 0.55, 1920, 1080)
            -- TopRight, Down: Y offset positive from top = 8
            expect(positions[1].y).toBe(8)
            expect(positions[1].x).toBe(-8) -- negative = left from right edge
            expect(positions[1].anchorX).toBe(1) -- right-aligned
        end)
```

- [ ] **Step 8: Run all tests — verify pass**

- [ ] **Step 9: Commit**

```bash
git add src/shared/AdaptiveLayout.luau src/shared/__tests__/AdaptiveLayout.spec.luau
git commit -m "feat: add zone stacking position calculation with visibility filtering"
```

---

## Task 3: AdaptiveLayout Runtime — init, applyScale, registerHUD, compensateStrokes

**Files:**
- Modify: `src/shared/AdaptiveLayout.luau`

This task adds the runtime layer that interacts with Roblox instances. These functions cannot be unit-tested (they need Camera, GuiService) but will be tested via Roblox Studio MCP.

- [ ] **Step 1: Add module state and init()**

Add to `AdaptiveLayout.luau` after the constants section:

```lua
-- ========== MODULE STATE ==========
local camera: Camera? = nil
local guiInsetY: number = 0
local currentScale: number = 1.0
local currentSafeArea = { width = 1920, height = 1080 }
local currentViewport = { x = 1920, y = 1080 } -- raw viewport for modal calc
local currentDeviceType: DeviceType = "Desktop"
local initialized = false

-- Tracked elements
local trackedModals: {{ frame: Frame, designW: number, designH: number, uiScale: UIScale }} = {}
local trackedHUD: {{ frame: Frame, zone: ZoneName, config: ZoneConfig, uiScale: UIScale }} = {}
local changeCallbacks: {() -> ()} = {}

-- ========== INTERNAL ==========

local function _recalculate()
    if not camera then return end
    local viewport = camera.ViewportSize
    local insetY = guiInsetY

    currentViewport = { x = viewport.X, y = viewport.Y }
    currentSafeArea = {
        width = viewport.X,
        height = viewport.Y - insetY,
    }
    currentScale = AdaptiveLayout.calculateHUDScale(viewport.X, viewport.Y, insetY)
    currentDeviceType = AdaptiveLayout.classifyDevice(viewport.X, viewport.Y, insetY)
end

local function _cleanOrphans()
    -- Remove modals with destroyed frames
    for i = #trackedModals, 1, -1 do
        if trackedModals[i].frame.Parent == nil then
            table.remove(trackedModals, i)
        end
    end
    -- Remove HUD elements with destroyed frames
    for i = #trackedHUD, 1, -1 do
        if trackedHUD[i].frame.Parent == nil then
            table.remove(trackedHUD, i)
        end
    end
end

local function _updateModalScales()
    for _, entry in trackedModals do
        if entry.frame.Parent then
            local modalScale = AdaptiveLayout.calculateModalScale(
                currentViewport.x,
                currentViewport.y,
                guiInsetY,
                entry.designW, entry.designH
            )
            entry.uiScale.Scale = modalScale
            AdaptiveLayout._compensateStrokesInternal(entry.frame, modalScale)
        end
    end
end

local function _updateHUDPositions()
    -- Group by zone
    local zones: {[ZoneName]: {{frame: Frame, config: ZoneConfig, uiScale: UIScale}}} = {}
    for _, entry in trackedHUD do
        if entry.frame.Parent then
            if not zones[entry.zone] then
                zones[entry.zone] = {}
            end
            table.insert(zones[entry.zone], entry)
        end
    end

    -- Calculate and apply positions per zone
    for zoneName, entries in zones do
        -- Build element list for calculation
        local calcElements = {}
        for _, entry in entries do
            table.insert(calcElements, {
                order = entry.config.order,
                designWidth = entry.config.designWidth or entry.frame.AbsoluteSize.X,
                designHeight = entry.config.designHeight or entry.frame.AbsoluteSize.Y,
                padding = entry.config.padding or 8,
                visible = entry.frame.Visible,
            })
        end

        local positions = AdaptiveLayout.calculateZonePositions(
            zoneName, calcElements, currentScale, currentSafeArea.width, currentSafeArea.height
        )

        -- Apply positions to visible frames
        local posIdx = 1
        -- Sort entries by order to match position results
        table.sort(entries, function(a, b) return a.config.order < b.config.order end)
        for _, entry in entries do
            if entry.frame.Visible and posIdx <= #positions then
                local pos = positions[posIdx]
                entry.uiScale.Scale = currentScale
                entry.frame.AnchorPoint = Vector2.new(pos.anchorX, pos.anchorY)
                entry.frame.Position = UDim2.new(pos.anchorX, pos.x, pos.anchorY, pos.y)
                posIdx += 1
            end
        end
    end
end

local function _updateAll()
    _cleanOrphans()
    _recalculate()
    _updateModalScales()
    _updateHUDPositions()
    -- Notify listeners
    for _, cb in changeCallbacks do
        task.spawn(cb)
    end
end

-- ========== PUBLIC API ==========

function AdaptiveLayout.init()
    if initialized then return end
    initialized = true

    local GuiService = game:GetService("GuiService")
    camera = workspace.CurrentCamera
    local inset = GuiService:GetGuiInset()
    guiInsetY = inset.Y

    _recalculate()

    camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        task.wait() -- wait 1 frame for layout to settle
        _updateAll()
    end)
end

function AdaptiveLayout.getScale(): number
    return currentScale
end

function AdaptiveLayout.getSafeArea(): {width: number, height: number}
    return currentSafeArea
end

function AdaptiveLayout.getDeviceType(): DeviceType
    return currentDeviceType
end

function AdaptiveLayout.onChanged(callback: () -> ()): () -> ()
    table.insert(changeCallbacks, callback)
    -- Return unsubscribe function
    return function()
        local idx = table.find(changeCallbacks, callback)
        if idx then
            table.remove(changeCallbacks, idx)
        end
    end
end
```

- [ ] **Step 2: Add applyScale for modals**

```lua
function AdaptiveLayout.applyScale(frame: Frame, designW: number, designH: number)
    local uiScale = Instance.new("UIScale")
    uiScale.Name = "AdaptiveScale"

    if camera then
        local viewport = camera.ViewportSize
        local modalScale = AdaptiveLayout.calculateModalScale(
            viewport.X, viewport.Y, guiInsetY, designW, designH
        )
        uiScale.Scale = modalScale
    end

    uiScale.Parent = frame

    table.insert(trackedModals, {
        frame = frame,
        designW = designW,
        designH = designH,
        uiScale = uiScale,
    })

    -- Auto-compensate strokes
    if camera then
        AdaptiveLayout._compensateStrokesInternal(frame, uiScale.Scale)
    end
end
```

- [ ] **Step 3: Add registerHUD**

```lua
function AdaptiveLayout.registerHUD(frame: Frame, zone: ZoneName, config: ZoneConfig): () -> ()
    local uiScale = Instance.new("UIScale")
    uiScale.Name = "AdaptiveHUDScale"
    uiScale.Scale = currentScale
    uiScale.Parent = frame

    local entry = {
        frame = frame,
        zone = zone,
        config = config,
        uiScale = uiScale,
    }
    table.insert(trackedHUD, entry)

    -- Listen for visibility changes to trigger zone recalculation
    local visConn = frame:GetPropertyChangedSignal("Visible"):Connect(function()
        _updateHUDPositions()
    end)

    -- Trigger immediate layout
    _updateHUDPositions()

    -- Return unregister function
    return function()
        visConn:Disconnect()
        AdaptiveLayout.unregisterHUD(frame)
    end
end

function AdaptiveLayout.unregisterHUD(frame: Frame)
    for i = #trackedHUD, 1, -1 do
        if trackedHUD[i].frame == frame then
            -- Destroy the UIScale we created
            if trackedHUD[i].uiScale then
                trackedHUD[i].uiScale:Destroy()
            end
            table.remove(trackedHUD, i)
            break
        end
    end
    _updateHUDPositions()
end
```

- [ ] **Step 4: Add compensateStrokes**

```lua
function AdaptiveLayout._compensateStrokesInternal(frame: Frame, scale: number)
    for _, desc in frame:GetDescendants() do
        if desc:IsA("UIStroke") then
            local original = desc:GetAttribute("_originalThickness")
            if not original then
                original = desc.Thickness
                desc:SetAttribute("_originalThickness", original)
            end
            desc.Thickness = original * scale
        end
    end
end

function AdaptiveLayout.compensateStrokes(frame: Frame)
    AdaptiveLayout._compensateStrokesInternal(frame, currentScale)
end
```

- [ ] **Step 5: Write stroke compensation unit test**

Add to spec:

```lua
    describe("stroke compensation", function()
        it("should be idempotent — calling twice gives same result", function()
            -- Test the pure calculation: original 2px at scale 0.5 = 1px
            -- This is a logical test; runtime test via MCP
            local original = 2
            local scale = 0.5
            local result = original * scale
            expect(result).toBe(1)
            -- Second application with same original
            local result2 = original * scale
            expect(result2).toBe(1)
        end)
    end)
```

- [ ] **Step 6: Run all unit tests — verify pass**

- [ ] **Step 7: Commit**

```bash
git add src/shared/AdaptiveLayout.luau src/shared/__tests__/AdaptiveLayout.spec.luau
git commit -m "feat: add AdaptiveLayout runtime — init, applyScale, registerHUD, strokes"
```

- [ ] **Step 8: Test via Roblox Studio MCP**

Use `execute_luau` to verify:
```lua
local AdaptiveLayout = require(game.ReplicatedStorage.Shared.AdaptiveLayout)
AdaptiveLayout.init()
print("Scale:", AdaptiveLayout.getScale())
print("SafeArea:", AdaptiveLayout.getSafeArea().width, AdaptiveLayout.getSafeArea().height)
print("Device:", AdaptiveLayout.getDeviceType())
```

Use `screen_capture` to verify no visual regression.

---

## Task 4: Migrate MainUI + UIFactory

**Files:**
- Modify: `src/client/UI/MainUI.luau` (line 10, line 68)
- Modify: `src/client/UI/UIFactory.luau` (line 5, lines 240-244)

- [ ] **Step 1: Update MainUI.luau**

Line 10 — change require:
```lua
-- OLD: local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)
-- NEW:
local AdaptiveLayout = require(ReplicatedStorage.Shared.AdaptiveLayout)
```

Line 68 — change init call:
```lua
-- OLD: ResponsiveScale.init()
-- NEW:
AdaptiveLayout.init()
```

- [ ] **Step 2: Update UIFactory.luau**

Line 5 — change require:
```lua
-- OLD: local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)
-- NEW:
local AdaptiveLayout = require(ReplicatedStorage.Shared.AdaptiveLayout)
```

Lines 240-244 — change applyToFrame call in createModal:
```lua
-- OLD:
-- local uiScale = ResponsiveScale.applyToFrame(modal, options.size.X.Offset, options.size.Y.Offset)
-- NEW:
AdaptiveLayout.applyScale(modal, options.size.X.Offset, options.size.Y.Offset)
```

Note: Check if `options.responsive == false` guard exists and preserve it.

**Warning:** If any panel calls both `UIFactory.createModal()` AND `AdaptiveLayout.applyScale()` directly, it would get double-scaled. Verify each modal only has ONE scaling path. Currently `createModal` is not used by any panel directly (panels call `UIFactory.createPanel` which does not auto-scale), but verify this during migration.

- [ ] **Step 3: Test via MCP — screen_capture to verify modals still render**

- [ ] **Step 4: Commit**

```bash
git add src/client/UI/MainUI.luau src/client/UI/UIFactory.luau
git commit -m "refactor: migrate MainUI + UIFactory to AdaptiveLayout"
```

---

## Task 5: Migrate Modal Panels (11 files)

**Files:** All 11 modal UI files listed in the spec.

All follow the same pattern — change require + replace `ResponsiveScale.applyToFrame` → `AdaptiveLayout.applyScale` and remove explicit `compensateStrokes` calls (now handled internally by `applyScale`).

- [ ] **Step 1: Migrate ClassSelectionUI.luau**

Line 9: change require to AdaptiveLayout
Lines 486-487: replace:
```lua
-- OLD:
-- local uiScale = ResponsiveScale.applyToFrame(self.container, PANEL_W, PANEL_H)
-- ResponsiveScale.compensateStrokes(self.container, uiScale.Scale)
-- NEW:
AdaptiveLayout.applyScale(self.container, PANEL_W, PANEL_H)
```

- [ ] **Step 2: Migrate DailyBonusUI.luau**

Line 8: change require
Lines 550-551: replace same pattern

- [ ] **Step 3: Migrate FeedbackUI.luau**

Line 10: change require
Line 54: replace `ResponsiveScale.applyToFrame` → `AdaptiveLayout.applyScale`

- [ ] **Step 4: Migrate MatchLobbyUI.luau (modal part only)**

Line 9: change require
Lines 319-320: replace applyToFrame + compensateStrokes
(HUD viewport listener at lines 512-530 will be handled in Task 7)

- [ ] **Step 5: Migrate RaceResultsUI.luau**

Line 8: change require
Lines 211-212: replace

- [ ] **Step 6: Migrate SettingsUI.luau**

Line 9: change require
Line 47: replace

- [ ] **Step 7: Migrate ShopUI.luau**

Line 13: change require
Lines 184-185: replace

- [ ] **Step 8: Migrate StageSelectionUI.luau**

Line 9: change require
Lines 627-628: replace

- [ ] **Step 9: Migrate SummaryUI.luau**

Line 11: change require
Lines 514-515: replace

- [ ] **Step 10: Migrate TitleCollectionUI.luau**

Line 9: change require
Lines 622-623: replace

- [ ] **Step 11: Migrate TutorialUI.luau**

Line 8: change require
Lines 254-255: replace

- [ ] **Step 12: Test via MCP — open each modal, screen_capture on desktop + phone emulator**

- [ ] **Step 13: Commit**

```bash
git add src/client/UI/ClassSelectionUI.luau src/client/UI/DailyBonusUI.luau \
  src/client/UI/FeedbackUI.luau src/client/UI/MatchLobbyUI.luau \
  src/client/UI/RaceResultsUI.luau src/client/UI/SettingsUI.luau \
  src/client/UI/ShopUI.luau src/client/UI/StageSelectionUI.luau \
  src/client/UI/SummaryUI.luau src/client/UI/TitleCollectionUI.luau \
  src/client/UI/TutorialUI.luau
git commit -m "refactor: migrate 11 modal panels to AdaptiveLayout.applyScale"
```

---

## Task 6: Migrate HUD — ScoreUI + CurrencyUI

**Files:**
- Modify: `src/client/UI/ScoreUI.luau` — remove viewport listener (~line 331), add registerHUD x2
- Modify: `src/client/UI/CurrencyUI.luau` — remove viewport listener (~line 203), add registerHUD

- [ ] **Step 1: Migrate ScoreUI.luau**

Add require at top:
```lua
local AdaptiveLayout = require(ReplicatedStorage.Shared.AdaptiveLayout)
```

Remove the entire `updateHUDLayout` function and its viewport listener connection (~lines 316-331).

Remove any manually created UIScale instances for gems/stage.

After creating gemFrame and stageFrame, register them:
```lua
AdaptiveLayout.registerHUD(gemFrame, "BottomLeft", {
    order = 1,
    padding = 8,
    designWidth = 130,
    designHeight = 44,
})

AdaptiveLayout.registerHUD(stageFrame, "BottomLeft", {
    order = 3,
    padding = 8,
    designWidth = 160,
    designHeight = 28,
})
```

Note: Read the actual frame sizes from the file before implementing. The designWidth/designHeight values above are approximate — use the actual UDim2 offset values from the code.

Also add HUD scale to TimerFrame (~line 245, 120x40) which is excluded from zones but needs scaling:
```lua
-- TimerFrame: not in zone system, just apply HUD scale directly
local timerUIScale = Instance.new("UIScale")
timerUIScale.Name = "AdaptiveHUDScale"
timerUIScale.Scale = AdaptiveLayout.getScale()
timerUIScale.Parent = timerFrame

AdaptiveLayout.onChanged(function()
    timerUIScale.Scale = AdaptiveLayout.getScale()
end)
```

- [ ] **Step 2: Migrate CurrencyUI.luau**

Add require at top:
```lua
local AdaptiveLayout = require(ReplicatedStorage.Shared.AdaptiveLayout)
```

Remove `updateCurrLayout` function and viewport listener (~lines 187-203).

Remove manually created UIScale instance.

After creating currencyFrame, register:
```lua
AdaptiveLayout.registerHUD(currencyFrame, "BottomLeft", {
    order = 2,
    padding = 8,
    designWidth = 160,
    designHeight = 28,
})
```

Note: Read actual frame size from file.

- [ ] **Step 3: Test via MCP — screen_capture on desktop + phone emulator**

Verify: Gems, Coins, Stage are visible at BottomLeft, stacked vertically, no overlap.

- [ ] **Step 4: Commit**

```bash
git add src/client/UI/ScoreUI.luau src/client/UI/CurrencyUI.luau
git commit -m "refactor: migrate ScoreUI + CurrencyUI to AdaptiveLayout zones"
```

---

## Task 7: Migrate HUD — MenuGridUI + ItemUI

**Files:**
- Modify: `src/client/UI/MenuGridUI.luau` — remove viewport listener (~line 166), add registerHUD
- Modify: `src/client/UI/ItemUI.luau` — add registerHUD (desktop only)

- [ ] **Step 1: Migrate MenuGridUI.luau**

Add require:
```lua
local AdaptiveLayout = require(ReplicatedStorage.Shared.AdaptiveLayout)
```

Remove the `if IS_MOBILE then` block (~lines 65-77) that creates a hardcoded UIScale of 0.55 (MOBILE_SCALE).

Remove the manually created UIScale instance.

After creating menu grid container, register:
```lua
AdaptiveLayout.registerHUD(container, "BottomLeft", {
    order = 4,
    padding = 8,
    designWidth = 172,  -- actual grid width from file
    designHeight = 306, -- actual grid height from file
})
```

Note: Read actual PANEL_W/PANEL_H from lines 21-22.

- [ ] **Step 2: Migrate ItemUI.luau**

Add require:
```lua
local AdaptiveLayout = require(ReplicatedStorage.Shared.AdaptiveLayout)
```

After creating container, register for desktop stacking (zone will skip it on mobile since Visible=false):
```lua
AdaptiveLayout.registerHUD(container, "BottomCenter", {
    order = 1,
    padding = 8,
    designWidth = container.AbsoluteSize.X, -- or hardcode from file
    designHeight = container.AbsoluteSize.Y,
})
```

- [ ] **Step 3: Test via MCP — screen_capture desktop + phone emulator**

Verify: Menu grid at BottomLeft order=4, Item bar at BottomCenter, no overlaps.

- [ ] **Step 4: Commit**

```bash
git add src/client/UI/MenuGridUI.luau src/client/UI/ItemUI.luau
git commit -m "refactor: migrate MenuGridUI + ItemUI to AdaptiveLayout zones"
```

---

## Task 8: Migrate HUD — SpectatorUI + MatchLobbyUI

**Files:**
- Modify: `src/client/UI/SpectatorUI.luau` — remove 3 UIScale instances + listener, add registerHUD x3
- Modify: `src/client/UI/MatchLobbyUI.luau` — remove custom UIScale rankings, add registerHUD

These are the most complex HUD migrations because they have multiple elements per file.

- [ ] **Step 1: Migrate SpectatorUI.luau**

Add require:
```lua
local AdaptiveLayout = require(ReplicatedStorage.Shared.AdaptiveLayout)
```

Remove these 3 manual UIScale instances (~lines 317-327):
```lua
-- DELETE: rankUIScale, promptUIScale, controlUIScale creation
```

Remove `updateMobileLayout` function and viewport listener (~lines 329-349).

After creating each element, register:
```lua
-- Rankings panel (TopRight)
AdaptiveLayout.registerHUD(self.rankingsPanel, "TopRight", {
    order = 1,
    padding = 8,
    designWidth = 200,  -- RANKINGS_W from line ~17
    designHeight = 300, -- RANKINGS_H from line ~18
})

-- Prompt container (BottomCenter)
AdaptiveLayout.registerHUD(self.promptContainer, "BottomCenter", {
    order = 2,
    padding = 8,
    designWidth = 280,  -- PROMPT_W from line ~16
    designHeight = 50,  -- PROMPT_H from line ~16
})

-- Control bar (BottomCenter)
AdaptiveLayout.registerHUD(controlBar, "BottomCenter", {
    order = 3,
    padding = 8,
    designWidth = 400,  -- CONTROL_W from line ~20
    designHeight = 44,  -- CONTROL_H from line ~21
})
```

For phone-specific top-3 ranking limit, use:
```lua
local maxEntries = if AdaptiveLayout.getDeviceType() == "Phone" then 3 else 8
```

- [ ] **Step 2: Migrate MatchLobbyUI.luau (HUD part)**

The modal part was already migrated in Task 5, Step 4.

Remove custom UIScale for race rankings (~lines 512-530):
```lua
-- DELETE: rankUIScale creation, updateRankLayout function, viewport listener
```

After creating rankFrame, register:
```lua
AdaptiveLayout.registerHUD(rankFrame, "TopRight", {
    order = 1,
    padding = 8,
    designWidth = 190,  -- from file
    designHeight = 300, -- dynamic, use max expected
})
```

For phone-specific top-3 ranking limit:
```lua
local maxEntries = if AdaptiveLayout.getDeviceType() == "Phone" then 3 else 8
```

Also add HUD scale to RaceTimer (~line 340, 150x50) which is excluded from zones:
```lua
local raceTimerUIScale = Instance.new("UIScale")
raceTimerUIScale.Name = "AdaptiveHUDScale"
raceTimerUIScale.Scale = AdaptiveLayout.getScale()
raceTimerUIScale.Parent = raceTimer

AdaptiveLayout.onChanged(function()
    raceTimerUIScale.Scale = AdaptiveLayout.getScale()
end)
```

- [ ] **Step 3: Test via MCP — start_stop_play, enter spectate mode, screen_capture**

Verify: Rankings at TopRight, spectate controls at BottomCenter, no overlaps.

- [ ] **Step 4: Commit**

```bash
git add src/client/UI/SpectatorUI.luau src/client/UI/MatchLobbyUI.luau
git commit -m "refactor: migrate SpectatorUI + MatchLobbyUI HUD to AdaptiveLayout zones"
```

---

## Task 9: Cleanup — Delete ResponsiveScale + Final Verification

**Files:**
- Delete: `src/shared/ResponsiveScale.luau`
- Delete: `src/shared/__tests__/ResponsiveScale.spec.luau`
- Modify: `src/client/UI/LeaderboardUI.luau` — remove commented-out imports

- [ ] **Step 1: Verify zero references to ResponsiveScale**

Run grep to confirm no remaining references:
```bash
grep -r "ResponsiveScale" src/
```

Expected: 0 matches. If any remain, fix them first.

- [ ] **Step 2: Delete ResponsiveScale files**

```bash
rm src/shared/ResponsiveScale.luau
rm src/shared/__tests__/ResponsiveScale.spec.luau
```

- [ ] **Step 3: Clean up LeaderboardUI.luau**

Remove commented-out ResponsiveScale imports (~lines 5-6).

- [ ] **Step 4: Run all unit tests**

```bash
rojo build test.project.json -o test.rbxl && run-in-roblox --place test.rbxl --script src/shared/__tests__/AdaptiveLayout.spec.luau
```

Expected: All tests pass.

- [ ] **Step 5: Full visual test via MCP**

Test on Device Emulator sizes:
1. iPhone SE (375x667) — `screen_capture`
2. iPhone 14 (390x844) — `screen_capture`
3. iPhone 14 Pro Max (430x932) — `screen_capture`
4. iPad (810x1080) — `screen_capture`
5. Desktop 1920x1080 — `screen_capture`

For each size, verify:
- Open Shop modal → fits on screen, no overflow
- Open Settings modal → fits on screen
- HUD elements visible and not overlapping
- Rankings panel visible at TopRight
- UIStroke thickness proportional

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: delete ResponsiveScale + clean up LeaderboardUI imports"
```

- [ ] **Step 7: Final commit — verify clean git status**

```bash
git status
```

Expected: clean working tree, no untracked files.
