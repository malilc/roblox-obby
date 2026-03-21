# Phase 2: Large Modal Scaling - Research

**Researched:** 2026-03-21
**Domain:** UIScale-based responsive scaling for 5 large modals (780x580) with UIStroke compensation and ScrollingFrame fixes
**Confidence:** HIGH

## Summary

Phase 2 applies the ResponsiveScale module (built in Phase 1) to the 5 largest modals: ShopUI, ClassSelectionUI, TitleCollectionUI, TutorialUI, and DailyBonusUI. The core integration pattern is established and proven -- `ResponsiveScale.applyToFrame(frame, 780, 580)` -- but Phase 2 introduces three new technical challenges that Phase 1 did not face: UIStroke thickness becoming disproportionate under UIScale, ScrollingFrame CanvasSize calculations breaking under UIScale, and DailyBonusUI's dynamic panel creation pattern requiring per-show scaling.

The UIStroke problem is well-documented on the Roblox DevForum: when UIScale shrinks a frame, UIStroke.Thickness does NOT proportionally shrink with it in FixedSize mode (the default). The stroke appears visually thicker relative to the scaled-down content. The compensation approach is to manually multiply each stroke's thickness by the scale factor (e.g., `originalThickness * scale`). This must be done recursively across all descendants and re-applied on viewport change. The ScrollingFrame problem is that `AbsoluteContentSize` reports values already affected by UIScale, but `CanvasSize` is interpreted in the unscaled coordinate space. The fix is to divide `AbsoluteContentSize.Y` by `UIScale.Scale` before setting CanvasSize, or to calculate canvas size from known item counts and dimensions.

**Primary recommendation:** Extend ResponsiveScale with a `compensateStrokes(frame, scale)` helper that recursively finds UIStroke instances, stores their original thicknesses, and adjusts them proportionally. For ScrollingFrames, replace AbsoluteContentSize-based CanvasSize with pre-calculated values based on item count and cell size.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Compensate UIStroke thickness proportionally with scale factor -- stroke.Thickness * scale so borders stay visually correct at smaller sizes
- **D-02:** Add `compensateStrokes(frame, scale)` helper in ResponsiveScale module -- traverses children, adjusts all UIStroke instances automatically
- **D-03:** Helper must store original thickness values and update on viewport change (same lifecycle as UIScale tracking)
- **D-04:** Manual CanvasSize calculation -- do NOT rely on AutomaticCanvasSize under UIScale (known Roblox bug)
- **D-05:** Calculate canvas from content count x item size, set CanvasSize explicitly
- **D-06:** Affected modals: ShopUI (3 ScrollingFrames), ClassSelectionUI (2), TitleCollectionUI (1)
- **D-07:** Call applyToFrame() inside showCalendar() after frame creation -- each time the modal opens, it gets fresh scaling
- **D-08:** ResponsiveScale's existing orphan cleanup (reverse iteration in _updateAll) handles stale entries when DailyBonusUI destroys its frame
- **D-09:** Same opt-in pattern: `ResponsiveScale.applyToFrame(frame, 780, 580)` per modal
- **D-10:** Each modal stores design size as local constants at top of file
- **D-11:** No changes to ResponsiveScale.init() or MainUI.luau initialization -- already running from Phase 1

### Claude's Discretion
- How to traverse frame children for UIStroke (recursive vs flat, performance considerations)
- Whether stroke compensation needs debouncing on viewport change
- Exact manual CanvasSize formulas per ScrollingFrame (depends on grid layout vs list layout)
- Execution order of the 5 modals (which to tackle first)
- TutorialUI is simplest (no scroll, no dynamic) -- may be good first target for validation

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MODAL-01 | ShopUI scales down on mobile screens | applyToFrame integration + 3 ScrollingFrame CanvasSize fixes + 12 UIStroke compensations + AbsoluteSize fix at line 1460 |
| MODAL-02 | ClassSelectionUI scales down on mobile screens | applyToFrame integration + 2 ScrollingFrame fixes (1 uses AutomaticCanvasSize) + 7 UIStroke compensations |
| MODAL-03 | TitleCollectionUI scales down on mobile screens | applyToFrame integration + 1 ScrollingFrame CanvasSize fix + 8 UIStroke compensations |
| MODAL-04 | TutorialUI scales down on mobile screens | applyToFrame integration + 4 UIStroke compensations (simplest target) |
| MODAL-05 | DailyBonusUI scales down on mobile screens | applyToFrame inside showCalendar() + UIStroke compensations + DailyBonusUI creates own ScreenGui per show |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ResponsiveScale.luau | Phase 1 (current) | Centralized scale computation and UIScale management | Already built and validated in Phase 1; extend with compensateStrokes |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ThemeConfig.luau | Current | STROKE_THIN/MED/BOLD constants (1.5/2.5/4) | Reference for original stroke thickness values |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual stroke compensation | UIStroke ScaledSize mode | ScaledSize has its own bugs with UIScale (DevForum March 2026). Manual is more reliable and predictable. |
| Manual CanvasSize | AutomaticCanvasSize | AutomaticCanvasSize is broken under UIScale (documented Roblox engine bug). Manual is the only reliable approach. |

## Architecture Patterns

### ResponsiveScale Module Extension

The module needs two new capabilities:

1. **`compensateStrokes(frame, scale)`** -- recursive UIStroke thickness adjustment
2. **Stroke tracking in `_updateAll()`** -- re-compensate on viewport change

### Pattern 1: UIStroke Compensation via compensateStrokes

**What:** Recursively traverse a frame's descendants, find all UIStroke instances, store their original thickness, and set `thickness = original * scale`.

**When to use:** Called after `applyToFrame()` for any frame containing UIStroke instances.

**Design decisions:**
- Use `:GetDescendants()` for recursive traversal (flat array, performant for UI hierarchies of 50-200 elements)
- Store original thicknesses in a side table keyed by UIStroke instance, NOT on the UIStroke itself (Roblox does not support custom attributes on UIStroke reliably for this purpose)
- Track the frame+strokes mapping alongside the existing UIScale tracking so `_updateAll()` can recompute on viewport change
- No debouncing needed -- `_updateAll()` already has `task.wait()` one-frame yield which is sufficient

**Example:**
```lua
-- In ResponsiveScale.luau

-- Storage for original stroke thicknesses
local trackedStrokes: {{ frame: GuiObject, strokes: {{ stroke: UIStroke, originalThickness: number }} }} = {}

function ResponsiveScale.compensateStrokes(frame: GuiObject, scale: number)
    local strokeEntries = {}
    for _, desc in ipairs(frame:GetDescendants()) do
        if desc:IsA("UIStroke") then
            table.insert(strokeEntries, {
                stroke = desc,
                originalThickness = desc.Thickness,
            })
            desc.Thickness = desc.Thickness * scale
        end
    end
    table.insert(trackedStrokes, {
        frame = frame,
        strokes = strokeEntries,
    })
end

-- In _updateAll(), after updating UIScale:
for i = #trackedStrokes, 1, -1 do
    local entry = trackedStrokes[i]
    if entry.frame.Parent then
        local scale = -- get current scale for this frame's design dimensions
        for _, strokeEntry in ipairs(entry.strokes) do
            if strokeEntry.stroke.Parent then
                strokeEntry.stroke.Thickness = strokeEntry.originalThickness * scale
            end
        end
    else
        table.remove(trackedStrokes, i)
    end
end
```

### Pattern 2: Manual CanvasSize Calculation

**What:** Replace AbsoluteContentSize-based CanvasSize with pre-calculated values based on known content dimensions.

**When to use:** For every ScrollingFrame inside a UIScale-affected parent.

**Per-modal formulas:**

**ShopUI Items tab (UIGridLayout):**
```lua
-- Grid: CellSize 225x270, CellPadding 14x14, 3 columns in 736px width
-- CanvasSize = rows * (cellH + padY) + topPadding
local itemCount = countItems()
local cols = 3
local rows = math.ceil(itemCount / cols)
local canvasH = rows * (270 + 14) + 5 -- +5 for top padding
content.CanvasSize = UDim2.new(0, 0, 0, canvasH)
```

**ShopUI Classes tab:** Static CanvasSize of 520 -- already hardcoded, no change needed.

**ShopUI GamePass tab (UIGridLayout):**
```lua
-- Offset 68 + gridLayout content + 20 padding
-- Already has fallback: content.CanvasSize = UDim2.new(0, 0, 0, 430)
-- Replace AbsoluteContentSize listener with static calculation
local passCount = countGamePasses()
local cols = 3
local rows = math.ceil(passCount / cols)
local canvasH = 68 + rows * (310 + 14) + 20
content.CanvasSize = UDim2.new(0, 0, 0, canvasH)
```

**ClassSelectionUI Left list (UIListLayout + AutomaticCanvasSize):**
```lua
-- CRITICAL: AutomaticCanvasSize = Enum.AutomaticSize.Y is BROKEN under UIScale
-- Replace with manual calculation
classListFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
local classCount = #self:getOrderedClassIds()
local canvasH = classCount * (72 + 4) + 8 -- item height 72 + padding 4 + top/bottom padding 8
classListFrame.CanvasSize = UDim2.new(0, 0, 0, canvasH)
```

**ClassSelectionUI Detail panel:** Static CanvasSize of 340 -- already hardcoded, no change needed.

**TitleCollectionUI List (UIListLayout + AbsoluteContentSize listener):**
```lua
-- Current code: layout.AbsoluteContentSize.Y + 12
-- Under UIScale, AbsoluteContentSize is already scaled, causing double-scaling
-- Fix: divide by UIScale.Scale
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local uiScale = self.container:FindFirstChildOfClass("UIScale")
    local scale = uiScale and uiScale.Scale or 1
    self.listFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y / scale + 12)
end)
```

### Pattern 3: Per-Modal Integration (established in Phase 1)

**What:** Require ResponsiveScale, define design size constants, call applyToFrame on the root frame.

**Example (TutorialUI -- simplest):**
```lua
local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)

local PANEL_W = 780
local PANEL_H = 580

-- In createUI(), after panel creation:
ResponsiveScale.applyToFrame(self.panel, PANEL_W, PANEL_H)
ResponsiveScale.compensateStrokes(self.panel, ResponsiveScale._getViewportScale(PANEL_W, PANEL_H))
```

### Pattern 4: DailyBonusUI Dynamic Creation

**What:** Apply scaling inside showCalendar() after panel is created, not in constructor.

**Key detail:** DailyBonusUI creates its own ScreenGui (`modalGui`) with `DisplayOrder = 100` each time showCalendar() is called. The panel is parented to this new ScreenGui, not to `self.parent`. UIScale must be applied to `panel` inside this ScreenGui.

**Example:**
```lua
-- Inside showCalendar(), after panel creation (line ~172):
panel.Parent = modalGui

local uiScale = ResponsiveScale.applyToFrame(panel, PANEL_W, PANEL_H)
ResponsiveScale.compensateStrokes(panel, uiScale.Scale)
```

### Pattern 5: ShopUI AbsoluteSize Fix

**What:** ShopUI line 1460-1462 reads `card.AbsoluteSize.Y` and `card.AbsoluteSize.X` for gacha animation positioning. Under UIScale, AbsoluteSize reports the SCALED value. The fallback values (`containerH < 50 then containerH = 230`) already handle zero-size cases, but the AbsoluteSize values will be wrong when UIScale is active.

**Fix:** Divide AbsoluteSize by UIScale.Scale:
```lua
local uiScale = self.mainFrame:FindFirstChildOfClass("UIScale")
local scaleFactor = uiScale and uiScale.Scale or 1
local containerH = card.AbsoluteSize.Y / scaleFactor
if containerH < 50 then containerH = 230 end
local containerW = card.AbsoluteSize.X / scaleFactor
if containerW < 100 then containerW = 550 end
```

### Recommended Execution Order

1. **TutorialUI** -- simplest (336 lines, no scroll, 4 UIStrokes). Validates compensateStrokes helper works.
2. **DailyBonusUI** -- medium complexity (650 lines, no scroll, dynamic creation). Validates dynamic pattern.
3. **TitleCollectionUI** -- first ScrollingFrame target (1251 lines, 1 scroll, 8 UIStrokes). Validates CanvasSize fix.
4. **ClassSelectionUI** -- AutomaticCanvasSize target (1752 lines, 2 scrolls, 7 UIStrokes). Validates AutomaticCanvasSize replacement.
5. **ShopUI** -- most complex (1901 lines, 3 scrolls, 12 UIStrokes, AbsoluteSize fix). Final boss.

### Anti-Patterns to Avoid
- **Global UIScale on ScreenGui:** Would affect HUD elements. Only apply per-modal.
- **Using AutomaticCanvasSize under UIScale:** Known Roblox engine bug. Always use manual CanvasSize.
- **Setting CanvasSize from AbsoluteContentSize without scale compensation:** AbsoluteContentSize reports scaled values; dividing by scale is required.
- **Migrating to UIStroke ScaledSize mode:** Still buggy under UIScale as of March 2026. Manual compensation with FixedSize is more reliable.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Scale computation | Custom math per modal | `ResponsiveScale.calculateScale()` | Already built and tested with 8 unit tests in Phase 1 |
| UIScale creation + tracking | Manual Instance.new per modal | `ResponsiveScale.applyToFrame()` | Handles tracking, orphan cleanup, viewport updates |
| Viewport change handling | Per-modal signal connections | `ResponsiveScale._updateAll()` (central handler) | Single connection point, already initialized in MainUI |
| UIStroke discovery | Manual per-file stroke lists | `frame:GetDescendants()` + IsA("UIStroke") filter | Recursive, catches nested strokes in sub-components |

**Key insight:** The infrastructure from Phase 1 handles 80% of the work. Phase 2 adds stroke compensation and ScrollingFrame fixes -- both are extensions of the existing module, not new systems.

## Common Pitfalls

### Pitfall 1: UIStroke Thickness Overcompensation
**What goes wrong:** Applying stroke compensation formula backwards -- dividing instead of multiplying, or multiplying where dividing is needed. The visual result is strokes that become invisibly thin or absurdly thick.
**Why it happens:** Confusion about whether UIScale already affects thickness visually or not. In FixedSize mode, UIScale DOES visually scale strokes, but the result is disproportionate (appears thicker than expected relative to content).
**How to avoid:** The user decision D-01 specifies `stroke.Thickness * scale`. This means storing the original designed thickness and multiplying by scale (0.5-1.0). At scale 0.7, a 2.5px stroke becomes 1.75px in the Thickness property. UIScale then visually renders this proportionally with the scaled content.
**Warning signs:** Strokes that look the same absolute thickness regardless of scale (compensation not applied) or strokes that vanish (wrong direction).

### Pitfall 2: Stroke Originals Not Stored Before Modification
**What goes wrong:** Reading `stroke.Thickness` AFTER a previous scale application and treating it as the "original." On viewport resize, the already-modified value gets scaled again, causing progressive drift.
**Why it happens:** The stroke's Thickness property IS the modified value after compensation. Without storing originals separately, each recalculation compounds the error.
**How to avoid:** Store original thickness at first discovery time (before any modification). On viewport change, always compute from original: `stroke.Thickness = originalThickness * newScale`.
**Warning signs:** Strokes getting progressively thinner each time the viewport changes.

### Pitfall 3: DailyBonusUI Creates Its Own ScreenGui
**What goes wrong:** Assuming DailyBonusUI's panel lives in `self.parent` (the main ScreenGui). It actually creates a fresh `modalGui` ScreenGui with `DisplayOrder = 100` each time showCalendar() runs, and parents the panel there.
**Why it happens:** DailyBonusUI is unique among all modals -- it creates and destroys a separate ScreenGui per show, not just a Frame.
**How to avoid:** Apply `ResponsiveScale.applyToFrame(panel, PANEL_W, PANEL_H)` inside showCalendar() AFTER `panel.Parent = modalGui`. The orphan cleanup in `_updateAll()` will handle cleanup when `modalGui:Destroy()` is called on close.
**Warning signs:** DailyBonusUI not scaling while other modals scale correctly.

### Pitfall 4: ScrollingFrame CanvasSize Double-Scaling
**What goes wrong:** `AbsoluteContentSize.Y` reports a value already affected by UIScale. Setting `CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)` creates a canvas that is too short (because AbsoluteContentSize was shrunk by UIScale, but CanvasSize is interpreted in unscaled space).
**Why it happens:** CanvasSize operates in the unscaled coordinate system of the ScrollingFrame, while AbsoluteContentSize reflects the visual (scaled) size.
**How to avoid:** Either (a) divide AbsoluteContentSize by UIScale.Scale, or (b) calculate canvas from known dimensions (item count * item size). Option (b) is more robust and is recommended per decision D-05.
**Warning signs:** Cannot scroll to bottom of lists on mobile, or excess empty space at bottom.

### Pitfall 5: ShopUI AbsoluteSize Used for Gacha Animation
**What goes wrong:** ShopUI lines 1460-1462 read `card.AbsoluteSize` to position the gacha scroll strip animation. Under UIScale, AbsoluteSize reports the scaled (smaller) values, causing the animation strip to be positioned incorrectly -- it may start or end in the wrong place.
**Why it happens:** AbsoluteSize and AbsolutePosition always reflect the visual (post-UIScale) values, not the logical design values.
**How to avoid:** Divide AbsoluteSize by UIScale.Scale before using it for layout math. The existing fallback values (containerH default 230, containerW default 550) provide a safety net but should not be relied upon.
**Warning signs:** Gacha animation appearing misaligned or clipped on mobile.

### Pitfall 6: Forgetting to Compensate Strokes Created After Initial Call
**What goes wrong:** Some modals create UIStroke instances dynamically (e.g., ShopUI gacha animation creates slideStroke instances on pull). These strokes are created AFTER `compensateStrokes()` runs and will not be compensated.
**Why it happens:** `compensateStrokes()` runs at frame creation time and captures a snapshot of current descendants.
**How to avoid:** For the gacha animation specifically (ShopUI line 1490), the stroke is inside the ScrollStrip which is inside the result card which is inside mainFrame. The UIScale visual scaling will make the strip match the rest of the content. The slideStroke thickness should be set to `originalThickness * currentScale` at creation time. This is a minor edge case -- most strokes are created during initial UI construction.
**Warning signs:** Newly created strokes appearing disproportionately thick during animations.

## Code Examples

### Complete compensateStrokes Helper
```lua
-- Storage for tracked strokes per frame
local trackedStrokes: {{
    frame: GuiObject,
    strokes: {{ stroke: UIStroke, originalThickness: number }}
}} = {}

-- Discover and compensate all UIStrokes in a frame hierarchy
function ResponsiveScale.compensateStrokes(frame: GuiObject, scale: number)
    local strokeEntries = {}
    for _, desc in ipairs(frame:GetDescendants()) do
        if desc:IsA("UIStroke") then
            table.insert(strokeEntries, {
                stroke = desc,
                originalThickness = desc.Thickness,
            })
            desc.Thickness = desc.Thickness * scale
        end
    end
    if #strokeEntries > 0 then
        table.insert(trackedStrokes, {
            frame = frame,
            strokes = strokeEntries,
        })
    end
end
```

### Updated _updateAll with Stroke Recalculation
```lua
function ResponsiveScale._updateAll()
    -- Update UIScale instances (existing Phase 1 code)
    for i = #trackedScales, 1, -1 do
        local entry = trackedScales[i]
        if entry.uiScale.Parent then
            entry.uiScale.Scale = ResponsiveScale._getViewportScale(
                entry.designWidth,
                entry.designHeight
            )
        else
            table.remove(trackedScales, i)
        end
    end

    -- Update stroke compensations
    for i = #trackedStrokes, 1, -1 do
        local entry = trackedStrokes[i]
        if entry.frame.Parent then
            -- Find the UIScale on this frame to get current scale
            local uiScale = entry.frame:FindFirstChildOfClass("UIScale")
            if uiScale then
                for _, strokeEntry in ipairs(entry.strokes) do
                    if strokeEntry.stroke.Parent then
                        strokeEntry.stroke.Thickness = strokeEntry.originalThickness * uiScale.Scale
                    end
                end
            end
        else
            table.remove(trackedStrokes, i)
        end
    end
end
```

### TutorialUI Integration (simplest example)
```lua
-- At top of file, add require:
local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)

local PANEL_W = 780
local PANEL_H = 580

-- In createUI(), after panel creation and all children added:
local uiScale = ResponsiveScale.applyToFrame(self.panel, PANEL_W, PANEL_H)
ResponsiveScale.compensateStrokes(self.panel, uiScale.Scale)
```

### DailyBonusUI Integration (dynamic pattern)
```lua
-- At top of file:
local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)

local PANEL_W = 780
local PANEL_H = 580

-- Inside showCalendar(), after all panel content created, before animations:
local uiScale = ResponsiveScale.applyToFrame(panel, PANEL_W, PANEL_H)
ResponsiveScale.compensateStrokes(panel, uiScale.Scale)

-- Orphan cleanup in _updateAll() handles cleanup when modalGui:Destroy() runs on close
```

### ShopUI CanvasSize Fix (Items tab)
```lua
-- Replace AbsoluteContentSize listener with static calculation
-- Old:
-- grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
--     content.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 15)
-- end)

-- New: calculate from known dimensions
local itemCount = countItems()
local cols = 3  -- 3 columns fit in (780-44) width with 225px cells + 14px gap
local rows = math.ceil(itemCount / cols)
content.CanvasSize = UDim2.new(0, 0, 0, rows * (270 + 14) + 5)
```

### TitleCollectionUI CanvasSize Fix (with UIScale compensation)
```lua
-- Replace existing AbsoluteContentSize listener:
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local uiScaleObj = self.container:FindFirstChildOfClass("UIScale")
    local scaleFactor = uiScaleObj and uiScaleObj.Scale or 1
    self.listFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y / scaleFactor + 12)
end)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| UIStroke FixedSize only | FixedSize + ScaledSize modes | Dec 2025 | ScaledSize mode available but buggy under UIScale (March 2026 bug report). Use FixedSize + manual compensation. |
| AutomaticCanvasSize for scroll | Manual CanvasSize calculation | Known bug since 2021 | AutomaticCanvasSize under UIScale remains broken. Manual calculation is the only reliable approach. |
| No responsive scaling | UIScale-based per-modal scaling | Phase 1 (Mar 2026) | ResponsiveScale module handles scale computation, tracking, and viewport updates |

**Deprecated/outdated:**
- UIStroke ScaledSize mode under UIScale: Still has active bugs as of March 2026. Do not use for this project.
- AutomaticCanvasSize under UIScale: Broken. Always use manual CanvasSize with UIScale.

## Open Questions

1. **Gacha animation strokes created after compensateStrokes()**
   - What we know: ShopUI creates slideStroke instances dynamically during gacha pull animation (line 1490)
   - What's unclear: Whether these need per-instance compensation or if UIScale visual scaling is sufficient
   - Recommendation: Set thickness to `designedThickness * currentScale` at creation time. This is a minor code change in createGachaCards, not a systemic issue.

2. **Exact stroke compensation direction (multiply vs divide)**
   - What we know: Decision D-01 says `stroke.Thickness * scale`. At scale 0.7, a 2.5px stroke becomes 1.75px.
   - What's unclear: Whether this produces the ideal visual result or whether empirical testing will reveal a different formula is needed
   - Recommendation: Implement `originalThickness * scale` per D-01. Test visually at scale 0.55 and 1.0. Adjust direction if visual inspection reveals the wrong result. The formula may need to be `originalThickness / scale` if UIScale already shrinks the visual thickness (making it too thin) rather than leaving it unchanged (making it too thick relative to content).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | jsdotlua/jest@3.10.0 |
| Config file | test.project.json (Rojo test config) |
| Quick run command | Tests require Roblox Studio runtime via run-in-roblox |
| Full suite command | Tests require Roblox Studio runtime via run-in-roblox |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MODAL-01 | ShopUI scales on mobile | manual-only | Visual verification in Roblox Studio device emulator | N/A |
| MODAL-02 | ClassSelectionUI scales on mobile | manual-only | Visual verification in Roblox Studio device emulator | N/A |
| MODAL-03 | TitleCollectionUI scales on mobile | manual-only | Visual verification in Roblox Studio device emulator | N/A |
| MODAL-04 | TutorialUI scales on mobile | manual-only | Visual verification in Roblox Studio device emulator | N/A |
| MODAL-05 | DailyBonusUI scales on mobile | manual-only | Visual verification in Roblox Studio device emulator | N/A |
| (infra) | compensateStrokes computes correctly | unit | `ResponsiveScale.spec.luau` | Needs new tests |

### Sampling Rate
- **Per task commit:** Manual visual check in Roblox Studio device emulator at 414x736 viewport
- **Per wave merge:** Open all 5 modals at mobile viewport and verify scroll + stroke rendering
- **Phase gate:** All 5 modals fully visible and usable at 414px-wide emulated viewport

### Wave 0 Gaps
- [ ] `src/shared/__tests__/ResponsiveScale.spec.luau` -- needs new tests for `compensateStrokes` behavior
- [ ] Manual visual verification checklist: each of 5 modals at mobile viewport

## Codebase-Specific UIStroke Inventory

Exact UIStroke instance counts per modal (verified by grep):

| Modal | UIStroke Count | Locations |
|-------|---------------|-----------|
| ShopUI | 12 | mainFrame border, close btn, coin display, gem display, item cards (per item), gacha card, pull btn, game pass cards, gacha slides |
| ClassSelectionUI | 7 | container border, close btn, confirm btn, class list items (per class), indicator, name indicator, toast |
| TitleCollectionUI | 8 | container border, close btn, banner, unequip btn, search box, toast, entry cards (per entry), action btn |
| TutorialUI | 4 | help button, panel border, close btn, content frame |
| DailyBonusUI | 5 | HUD button, panel border, close btn, today card, action btn |

**Note:** Some of these (e.g., ShopUI item card strokes, ClassSelectionUI class list item strokes, TitleCollectionUI entry card strokes) are created dynamically for each item in the list. `GetDescendants()` captures all of them at the time of the call.

## Codebase-Specific ScrollingFrame Inventory

| Modal | ScrollingFrame | CanvasSize Method | Fix Required |
|-------|---------------|-------------------|-------------|
| ShopUI | ItemsContent | AbsoluteContentSize listener (line 527-529) | Replace with static calculation from item count |
| ShopUI | ClassesContent | Static `UDim2.new(0, 0, 0, 520)` (line 756) | No fix needed -- already static |
| ShopUI | GamePassContent | AbsoluteContentSize listener (line 1142-1143) + fallback 430 (line 1145) | Replace with static calculation from pass count |
| ClassSelectionUI | classListFrame | `AutomaticCanvasSize = Enum.AutomaticSize.Y` (line 395) | CRITICAL: Disable AutomaticCanvasSize, replace with manual calc |
| ClassSelectionUI | DetailContent | Static `UDim2.new(0, 0, 0, 340)` (line 624) | No fix needed -- already static |
| TitleCollectionUI | listFrame | AbsoluteContentSize listener (line 569-570) | Divide AbsoluteContentSize.Y by UIScale.Scale |

## Sources

### Primary (HIGH confidence)
- Codebase analysis: All 5 target modal files read and analyzed for UIStroke, ScrollingFrame, and integration points
- `src/shared/ResponsiveScale.luau` -- existing module architecture
- Phase 1 summary artifacts -- established integration patterns

### Secondary (MEDIUM confidence)
- [UIScale incorrectly scaling UIStroke thickness (DevForum)](https://devforum.roblox.com/t/uiscale-incorrectly-scaling-uistroke-thickness/4157250) -- Confirms UIStroke thickness bug, no official formula
- [UIStroke Improvements Full Release (DevForum, Dec 2025)](https://devforum.roblox.com/t/full-release-uistroke-improvements-scaling-offsets-and-more/3958036) -- ScaledSize mode exists but has its own bugs
- [AutomaticCanvasSize + UIListLayout + UIScale bug (DevForum)](https://devforum.roblox.com/t/automaticcanvassize-working-with-uilistlayout-and-uiscale-causes-wrong-automatic-size/1334861) -- Confirms AutomaticCanvasSize broken under UIScale, workaround: divide by scale
- [UIScale does not change CanvasSize (DevForum)](https://devforum.roblox.com/t/uiscale-does-not-change-canvassize-of-scrollingframe/1644271) -- Confirms CanvasSize operates in unscaled space
- [UIStroke same thickness guide (DevForum)](https://devforum.roblox.com/t/how-to-make-uistroke-same-thick-on-different-screen-sizes/2933858) -- Community formula: originalThickness * scale ratio
- [Scale all UIStrokes script (DevForum)](https://devforum.roblox.com/t/easily-scale-all-uistrokes-with-one-script/3585721) -- Community script: GetDescendants + IsA("UIStroke") traversal pattern

### Tertiary (LOW confidence)
- [UIScale doesn't properly scale UIStrokes with ScaledSize (DevForum, Mar 2026)](https://devforum.roblox.com/t/uiscale-doesnt-properly-scale-uistrokes-with-scaledsize/4527312) -- ScaledSize mode still buggy, validates decision to use manual compensation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- extending an existing module built in Phase 1 with proven patterns
- Architecture: HIGH -- patterns verified from codebase analysis and community solutions
- Pitfalls: HIGH -- all documented from Roblox DevForum with specific codebase line numbers
- UIStroke compensation formula: MEDIUM -- community consensus is `originalThickness * scaleRatio` but exact UIScale interaction needs empirical testing
- ScrollingFrame fixes: HIGH -- well-documented bug with clear workaround (divide by scale or use static calc)

**Research date:** 2026-03-21
**Valid until:** 2026-04-21 (stable domain -- Roblox engine UIScale bugs are longstanding)
