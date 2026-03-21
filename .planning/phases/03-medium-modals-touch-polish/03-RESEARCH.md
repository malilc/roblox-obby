# Phase 3: Medium Modals + Touch + Polish - Research

**Researched:** 2026-03-21
**Domain:** Roblox UI scaling (medium modals), touch target sizing, safe area compliance, scale-in animation
**Confidence:** HIGH

## Summary

Phase 3 applies the proven ResponsiveScale infrastructure (Phase 1-2) to 4 medium modals, adds touch target enforcement for mobile, verifies safe area compliance, and introduces scale-in animation polish. The modal scaling work is mechanical -- the same `applyToFrame` + `compensateStrokes` pattern proven across 9 modals in Phase 1-2. The new work is in three areas: (1) ensuring buttons remain tappable at scaled sizes, (2) verifying ScreenInsets/safe area behavior, and (3) adding UIScale-based tween animation on show.

The ScreenGui already uses `IgnoreGuiInset = false` and no explicit `ScreenInsets` (defaults to `CoreUISafeInsets`), which means modals are already protected from notch/Dynamic Island. TOUCH-03 is primarily a verification task rather than an implementation task. Touch targets are the most design-sensitive concern: several buttons (notably MatchLobbyUI close at 40x40, StageSelectionUI clear at 110x35, joinBtn at 90x28) will shrink below 44px effective hit area at mobile scale factors. The recommended approach is invisible hit area expansion frames.

**Primary recommendation:** Apply modal scaling in complexity order (RaceResultsUI, SummaryUI, MatchLobbyUI, StageSelectionUI), add invisible hit area frames for undersized touch targets, verify CoreUISafeInsets default covers notch/Dynamic Island, and implement UIScale-based scale-in tween (0.8 to target) globally in ResponsiveScale or per-modal show() methods.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Same opt-in pattern: `ResponsiveScale.applyToFrame(frame, designW, designH)` per modal
- **D-02:** Each modal stores design size as local constants at top of file
- **D-03:** `compensateStrokes()` already available in ResponsiveScale -- call after applyToFrame
- **D-04:** ScrollingFrames (MatchLobbyUI playerList, RaceResultsUI resultsFrame) use manual CanvasSize -- no AutomaticCanvasSize under UIScale

### Claude's Discretion
- Touch target enforcement strategy (TOUCH-01, TOUCH-02): how to ensure 44px+ effective hit area on Close/Buy/Equip/Confirm buttons at scaled sizes -- invisible hit area frames, minimum size overrides, or padding approach
- Safe area / notch handling (TOUCH-03): whether to use CoreUISafeInsets API, ScreenInsets, or hardcoded safe margins to prevent modal clipping behind notch/Dynamic Island
- Scale-in animation (POLISH-01): TweenService approach for 0.8 to target scale on show -- duration, easing style, whether to apply to all modals globally or Phase 3 modals only
- Centering verification (POLISH-02): how to confirm modals stay centered after scaling on all screen sizes
- Execution order of the 4 modals -- which to tackle first based on complexity
- ScrollingFrame CanvasSize formulas for MatchLobbyUI and RaceResultsUI

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MODAL-06 | StageSelectionUI (580x480) scales down on mobile screens | Same applyToFrame pattern; fix Position bug (uses offset + AnchorPoint); 1 UIStroke on container; no ScrollingFrame |
| MODAL-07 | SummaryUI (400x600) scales down on mobile screens | applyToFrame pattern; already has scale-in animation via Size tween (needs conversion to UIScale tween); 1 UIStroke; dynamic panelHeight (600 or 660) |
| MODAL-08 | MatchLobbyUI (400x500) scales down on mobile screens | applyToFrame pattern; 1 UIStroke on container; 1 ScrollingFrame (playerList, CanvasSize = #players * 40); close button 40x40 needs touch target expansion |
| MODAL-09 | RaceResultsUI (450x500) scales down on mobile screens | applyToFrame pattern; 2 UIStrokes (container + title text); 1 ScrollingFrame (resultsFrame, CanvasSize = #results * 58); simplest modal |
| TOUCH-01 | Close buttons remain tappable (44px+ hit area) at scaled sizes | MatchLobbyUI closeBtn 40x40 already borderline; at scale 0.7 = 28px effective. Invisible hit area frame recommended |
| TOUCH-02 | Action buttons remain tappable at scaled sizes | StageSelectionUI clearBtn 110x35 (height 35), joinBtn 90x28 (height 28!); others 170x50 or 180x44+ are fine at typical scales |
| TOUCH-03 | ScreenInsets/CoreUISafeInsets verified -- no notch/Dynamic Island clipping | ScreenGui defaults to CoreUISafeInsets already. Verification task only -- no code changes expected |
| POLISH-01 | Modals animate scale on show (tween from 0.8 to target scale) | TweenService:Create on UIScale.Scale property; SummaryUI already has scale-in via Size tween (needs conversion); others use Position tween |
| POLISH-02 | Modals remain centered after scaling on all screen sizes | All 4 modals use AnchorPoint(0.5,0.5); UIScale scales from AnchorPoint, so centering is maintained. StageSelectionUI Position bug must be fixed |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ResponsiveScale.luau | N/A (project module) | UIScale management, viewport tracking, stroke compensation | Proven on 9 modals in Phase 1-2, same pattern for Phase 3 |
| TweenService | Roblox built-in | UIScale.Scale animation for show/hide polish | Native Roblox service, already used in all 4 target modals |
| GuiService | Roblox built-in | GetGuiInset for scale calculation | Already used by ResponsiveScale |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ThemeConfig.luau | N/A (project module) | STROKE_MED, STROKE_BOLD, STROKE_THIN constants | Referenced by all 4 modals for UIStroke thickness values |

## Architecture Patterns

### Integration Pattern (proven in Phase 1-2)
```
-- At top of modal file
local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)
local PANEL_W = 450
local PANEL_H = 500

-- In constructor (createUI), after frame fully built
local uiScale = ResponsiveScale.applyToFrame(self.container, PANEL_W, PANEL_H)
ResponsiveScale.compensateStrokes(self.container, uiScale.Scale)
```

### Pattern 1: Touch Target Expansion (Invisible Hit Area)
**What:** Wrap small buttons in a transparent TextButton sized to 44px+ minimum, acting as the actual tap target
**When to use:** When a visible button's effective size at mobile scale drops below 44px
**Example:**
```lua
-- For a 40x40 close button that scales to ~28px at 0.7 scale:
-- The visible button remains 40x40 for aesthetics
-- Add invisible hit area frame around it
local hitArea = Instance.new("TextButton")
hitArea.Name = "CloseHitArea"
hitArea.Size = UDim2.new(0, 60, 0, 60)  -- 60px * 0.7 = 42px (close to 44), or use 64 for safety
hitArea.Position = UDim2.new(0.5, 0, 0.5, 0)
hitArea.AnchorPoint = Vector2.new(0.5, 0.5)
hitArea.BackgroundTransparency = 1
hitArea.Text = ""
hitArea.Parent = closeBtn  -- parent to the visible button
-- Move the click handler to hitArea instead of closeBtn
```

Alternative approach (simpler, recommended):
```lua
-- Just make the button bigger and let UIScale handle the rest
-- 44px / MIN_SCALE(0.5) = 88px minimum design-time size for guaranteed mobile tap
-- 44px / 0.7 (typical mobile) = 63px minimum design-time size for typical mobile
closeBtn.Size = UDim2.new(0, 64, 0, 64)  -- ensures 44px+ at scales >= 0.7
```

### Pattern 2: UIScale-Based Scale-In Animation
**What:** Tween UIScale.Scale from 0.8*target to target on show, creating a smooth pop-in
**When to use:** On modal show() for visual polish
**Example:**
```lua
-- Source: Roblox TweenService docs + UIScale API
function Modal:show()
    self.container.Visible = true
    local uiScale = self.container:FindFirstChildOfClass("UIScale")
    if uiScale then
        local targetScale = uiScale.Scale
        uiScale.Scale = targetScale * 0.8
        TweenService:Create(uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Scale = targetScale
        }):Play()
    end
end
```

### Pattern 3: ScrollingFrame CanvasSize Under UIScale
**What:** Set CanvasSize explicitly based on content count, not AutomaticCanvasSize
**When to use:** Any ScrollingFrame inside a UIScale-affected hierarchy
**Example:**
```lua
-- RaceResultsUI: each result entry is 50px + 8px padding
self.resultsFrame.CanvasSize = UDim2.new(0, 0, 0, #data.results * 58)

-- MatchLobbyUI: each player entry uses 40px height
self.playerList.CanvasSize = UDim2.new(0, 0, 0, #playerNames * 40)
```
Note: These modals already use manual CanvasSize. No changes needed to the CanvasSize values themselves -- UIScale handles visual scaling. The CanvasSize values are in design-space pixels, which is correct.

### Anti-Patterns to Avoid
- **Animating Frame.Size for scale-in after UIScale is applied:** SummaryUI currently tweens Size from (0,0) to (400,panelHeight). With UIScale attached, this causes a double-scale effect. Must convert to UIScale.Scale tween instead.
- **Using Position offsets with AnchorPoint for centering:** StageSelectionUI uses `Position = UDim2.new(0.5, -290, 0.5, -240)` with `AnchorPoint(0.5, 0.5)` which creates incorrect centering (the offset is redundant and wrong with AnchorPoint). Fix to `Position = UDim2.new(0.5, 0, 0.5, 0)`.
- **Adding AutomaticCanvasSize to ScrollingFrames under UIScale:** Known Roblox bug. Both MatchLobbyUI and RaceResultsUI already use manual CanvasSize -- do not change this.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Viewport-aware scaling | Custom per-modal scale math | `ResponsiveScale.applyToFrame()` | Already built, tested, handles viewport changes |
| UIStroke thickness compensation | Manual stroke adjustment per modal | `ResponsiveScale.compensateStrokes()` | Already built, idempotent, handles viewport changes |
| Safe area/notch handling | Custom inset calculations or hardcoded margins | ScreenGui default `CoreUISafeInsets` | Already the default behavior; Roblox handles device-specific insets |
| Scale animation | Custom render-step loop for scale changes | `TweenService:Create(uiScale, ...)` | TweenService handles interpolation, easing, and cleanup |

## Common Pitfalls

### Pitfall 1: SummaryUI Size-Based Animation Conflict
**What goes wrong:** SummaryUI currently animates `mainFrame.Size` from (0,0) to (400,panelHeight) in show(). When UIScale is attached, this creates a jarring double-scale because UIScale multiplies the rendered size. The Size tween would fight with UIScale.
**Why it happens:** The animation was written before UIScale existed. Size-based "scale" animation is incompatible with UIScale-based scaling.
**How to avoid:** Convert SummaryUI's show() animation from Size tween to UIScale.Scale tween. Set frame to full design size immediately, then animate UIScale from 0.8*target to target. Similarly convert hide() from Size shrink to UIScale animation.
**Warning signs:** Modal appears tiny and grows twice, or flickers between sizes.

### Pitfall 2: StageSelectionUI Position Bug
**What goes wrong:** StageSelectionUI sets `Position = UDim2.new(0.5, -290, 0.5, -240)` with `AnchorPoint = Vector2.new(0.5, 0.5)`. With AnchorPoint(0.5,0.5), the offset (-290, -240) shifts the modal off-center. The show() method corrects this by resetting Position to (0.5, 0, 0.5, 0).
**Why it happens:** Original code was written without AnchorPoint (using manual offset centering), then AnchorPoint was added without removing the offset.
**How to avoid:** Fix createUI to use `Position = UDim2.new(0.5, 0, 0.5, 0)` and remove the manual offset. This also ensures UIScale scales from the true center.
**Warning signs:** Modal appears off-center on first frame before show() animation runs.

### Pitfall 3: Touch Targets Too Small After Scaling
**What goes wrong:** Buttons that are borderline at design size become untappable on mobile. MatchLobbyUI close button (40x40) at scale 0.7 = 28px effective. StageSelectionUI joinBtn (90x28 height) at scale 0.7 = ~20px effective height.
**Why it happens:** Design-time sizes target desktop; UIScale shrinks everything proportionally including buttons.
**How to avoid:** Audit every button, calculate effective size at worst-case mobile scale (~0.7 for these modals). Expand any button whose effective dimension drops below 44px.
**Warning signs:** Buttons hard to tap on mobile testing; users tapping wrong elements.

### Pitfall 4: RaceResultsUI Winner Celebration Stroke Animation
**What goes wrong:** `playWinnerCelebration()` animates the container's UIStroke thickness directly using TweenService, tweening to `Theme.STROKE_BOLD * 1.5` and back. After `compensateStrokes()` adjusts thickness for scale, this celebration will use the wrong absolute values.
**Why it happens:** The celebration was written assuming constant stroke thickness. `compensateStrokes()` changes the stored thickness, but the celebration hardcodes `Theme.STROKE_BOLD * 1.5`.
**How to avoid:** Update celebration to use scaled values: `strokeEntry.originalThickness * scale * 1.5` or query the current compensated thickness and multiply.
**Warning signs:** Border glow effect looks too thick or too thin on mobile.

### Pitfall 5: SummaryUI Dynamic Panel Height
**What goes wrong:** SummaryUI dynamically changes panel height between 600 and 660 based on gamepass upsell content. The design size passed to `applyToFrame` must match the maximum possible height, or the taller variant won't scale correctly.
**Why it happens:** `applyToFrame` is called once at construction with fixed dimensions, but the modal changes height at show time.
**How to avoid:** Use 660 (the maximum) as the design height for scale calculation. The 600px variant will still render correctly -- it just won't use the full available space, but it remains within bounds.
**Warning signs:** Modal clips at bottom when gamepass upsell is shown.

## Code Examples

### Example 1: RaceResultsUI Integration (simplest modal)
```lua
-- At top of file, after Theme require
local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)
local PANEL_W = 450
local PANEL_H = 500

-- In createUI(), after all children created, before close button click handler
local uiScale = ResponsiveScale.applyToFrame(container, PANEL_W, PANEL_H)
ResponsiveScale.compensateStrokes(container, uiScale.Scale)
self.uiScale = uiScale  -- store for animation use

-- In show(), add scale-in animation
function RaceResultsUI:show()
    self.isVisible = true
    self.overlay.BackgroundTransparency = 1
    self.overlay.Visible = true
    TweenService:Create(self.overlay, TweenInfo.new(0.25), {
        BackgroundTransparency = 0.55
    }):Play()

    self.container.Visible = true
    -- Scale-in animation (POLISH-01)
    local targetScale = self.uiScale.Scale
    self.uiScale.Scale = targetScale * 0.8
    TweenService:Create(self.uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Scale = targetScale
    }):Play()
end
```

### Example 2: MatchLobbyUI Close Button Touch Target Expansion
```lua
-- Current: closeBtn.Size = UDim2.new(0, 40, 0, 40)
-- At scale 0.7: 28px effective -- too small

-- Option A (recommended): Increase design-time size
closeBtn.Size = UDim2.new(0, 48, 0, 48)  -- 48 * 0.7 = 33.6px, marginal
-- Better:
closeBtn.Size = UDim2.new(0, 56, 0, 56)  -- 56 * 0.7 = 39.2px, borderline
-- Even better for guaranteed compliance:
closeBtn.Size = UDim2.new(0, 64, 0, 64)  -- 64 * 0.7 = 44.8px, meets target

-- Option B: Invisible hit area (if visual size must stay 40x40)
-- Make the visible button non-interactive
closeBtn.Active = false
-- Add larger invisible button as sibling
local closeHitArea = Instance.new("TextButton")
closeHitArea.Size = UDim2.new(0, 64, 0, 64)
closeHitArea.Position = closeBtn.Position
closeHitArea.AnchorPoint = closeBtn.AnchorPoint
closeHitArea.BackgroundTransparency = 1
closeHitArea.Text = ""
closeHitArea.Parent = header  -- same parent as closeBtn
closeHitArea.MouseButton1Click:Connect(function()
    -- original handler
end)
```

### Example 3: SummaryUI Animation Conversion
```lua
-- BEFORE (Size-based animation -- incompatible with UIScale):
self.mainFrame.Size = UDim2.new(0, 0, 0, 0)
self.mainFrame.Visible = true
TweenService:Create(self.mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
    Size = UDim2.new(0, 400, 0, panelHeight)
}):Play()

-- AFTER (UIScale-based animation -- compatible):
self.mainFrame.Size = UDim2.new(0, 400, 0, panelHeight)  -- set full size immediately
self.mainFrame.Visible = true
local targetScale = self.uiScale.Scale
self.uiScale.Scale = targetScale * 0.8
TweenService:Create(self.uiScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Scale = targetScale
}):Play()

-- HIDE (convert Size shrink to UIScale shrink):
-- BEFORE:
TweenService:Create(self.mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
    Size = UDim2.new(0, 0, 0, 0)
}):Play()
-- AFTER:
local currentScale = self.uiScale.Scale
TweenService:Create(self.uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
    Scale = currentScale * 0.8
}):Play()
-- Restore scale after hide for next show
task.delay(0.3, function()
    self.uiScale.Scale = ResponsiveScale._getViewportScale(PANEL_W, PANEL_H)
    self.mainFrame.Visible = false
end)
```

## Button Size Audit (Touch Target Analysis)

All buttons across the 4 target modals, with effective sizes at typical mobile scale:

### RaceResultsUI (scale ~0.74 at 414px viewport with 450px design width)
| Button | Design Size | Effective @ 0.74 | Status |
|--------|-------------|-------------------|--------|
| Continue (closeBtn) | 180x45 | 133x33 | Height borderline -- increase to 180x50 |

### SummaryUI (scale ~0.84 at 414px viewport with 400px design width)
| Button | Design Size | Effective @ 0.84 | Status |
|--------|-------------|-------------------|--------|
| OK button | 180x44 | 151x37 | Height borderline -- increase to 180x52 |
| Gamepass upsell buttons | varies x 40 | varies x 34 | Height borderline |

### MatchLobbyUI (scale ~0.84 at 414px viewport with 400px design width)
| Button | Design Size | Effective @ 0.84 | Status |
|--------|-------------|-------------------|--------|
| Close (X) | 40x40 | 34x34 | FAIL -- expand to 56x56 |
| Leave | 0.48 scale x 50 | ~161x42 | Borderline -- increase buttonsFrame height to 56 |
| Start Match | 0.48 scale x 50 | ~161x42 | Borderline -- increase buttonsFrame height to 56 |

### StageSelectionUI (scale ~0.58 at 414px viewport with 580px design width)
| Button | Design Size | Effective @ 0.58 | Status |
|--------|-------------|-------------------|--------|
| Stage buttons | 100x105 | 58x61 | OK |
| Clear | 110x35 | 64x20 | Height FAIL -- increase to 110x48 |
| Random | 170x50 | 99x29 | Height borderline -- increase to 170x56 |
| Start | 170x50 | 99x29 | Height borderline -- increase to 170x56 |
| Join room | 90x28 | 52x16 | Height FAIL -- increase to 90x48 |
| Tabs | (scale-based) | varies | Check actual rendered size |

**Key finding:** StageSelectionUI is the most aggressive scaler (0.58 for 580px design on 414px screen). Several buttons need height increases. The simplest fix is increasing design-time button heights -- this does not affect desktop appearance significantly (buttons just become slightly taller).

## Safe Area Analysis (TOUCH-03)

**Finding:** The main ScreenGui (`ObbyGameUI`) is created with `IgnoreGuiInset = false` and no explicit `ScreenInsets` property set. The Roblox default for `ScreenInsets` is `CoreUISafeInsets`.

**What CoreUISafeInsets does:** Automatically insets all descendant GUI objects to be clear of:
- The Roblox top bar buttons
- Device camera notch (iPhone notch, Dynamic Island)
- Any other screen cutouts

**Conclusion:** No code changes needed for TOUCH-03. The existing default behavior already handles notch/Dynamic Island avoidance. Verification involves confirming this on a physical device or emulator, not writing new code.

**Verification approach:** Add a comment in the codebase documenting that `CoreUISafeInsets` is the active behavior and that this was verified for Phase 3. Optionally, make the setting explicit: `screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets` for clarity.

## Execution Order Recommendation

1. **RaceResultsUI** (450 lines) -- Simplest modal. 1 ScrollingFrame with existing manual CanvasSize. 2 UIStrokes. Clear show/hide pattern. Good validation target. Winner celebration stroke animation needs adjustment.
2. **MatchLobbyUI** (973 lines) -- Medium complexity. 1 ScrollingFrame with existing manual CanvasSize. 1 UIStroke on container. Close button touch target needs expansion (40x40 too small).
3. **SummaryUI** (1122 lines) -- Medium-high complexity. No ScrollingFrame but dynamic panel height (600/660). Size-based animation must be converted to UIScale-based. 1 UIStroke.
4. **StageSelectionUI** (1083 lines) -- Most complex. No ScrollingFrame. Multiple small buttons needing touch target expansion. Position bug needs fixing. Tabs + voting + countdown logic.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Size-based show animation (tween Size from 0 to design) | UIScale.Scale-based animation (tween Scale from 0.8 to target) | Phase 3 (now) | SummaryUI's animation must be converted |
| IgnoreGuiInset for safe area control | ScreenInsets enum (CoreUISafeInsets/DeviceSafeInsets/None) | Roblox 2023+ | ScreenInsets is the modern API; IgnoreGuiInset still works but is less granular |
| Manual Position offset centering | AnchorPoint(0.5,0.5) + Position(0.5,0,0.5,0) | Standard since AnchorPoint API | StageSelectionUI uses hybrid (both); needs cleanup |

## Open Questions

1. **RaceResultsUI winner celebration stroke values**
   - What we know: `playWinnerCelebration()` tweens UIStroke to `Theme.STROKE_BOLD * 1.5` which is an absolute design-time value
   - What's unclear: Whether the celebration should use scale-compensated values or if it looks fine with absolute values since it's a visual effect (intentionally thicker)
   - Recommendation: Use compensated values for consistency: `originalThickness * scale * 1.5`

2. **SummaryUI dynamic panel height with applyToFrame**
   - What we know: Panel height changes between 600 and 660 based on gamepass upsell
   - What's unclear: Whether applyToFrame should use 600 or 660 as the design height
   - Recommendation: Use 660 (maximum). The 600 variant will have slightly more margin, which is fine. The scale factor will be slightly more conservative but guarantees no clipping.

3. **Scale-in animation scope -- Phase 3 modals only or all modals?**
   - What we know: POLISH-01 says "modals animate scale on show". Phase 1-2 modals don't currently have scale-in animation.
   - What's unclear: Whether to retroactively add animation to Phase 1-2 modals
   - Recommendation: Add to Phase 3 modals only. Phase 1-2 modals already work and their show() methods were not designed for it. Can be added later as a quick task if desired.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | jsdotlua/jest@3.10.0 (Luau Jest) |
| Config file | `test.project.json` (Rojo test config) |
| Quick run command | `run-in-roblox --place test.rbxl --script scripts/run-tests.server.luau` |
| Full suite command | `run-in-roblox --place test.rbxl --script scripts/run-tests.server.luau` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MODAL-06 | StageSelectionUI scales at 414px viewport | unit (calculateScale) | Existing test covers scale calc | Covered by ResponsiveScale.spec.luau |
| MODAL-07 | SummaryUI scales at 414px viewport | unit (calculateScale) | Existing test covers scale calc | Covered by ResponsiveScale.spec.luau |
| MODAL-08 | MatchLobbyUI scales at 414px viewport | unit (calculateScale) | Existing test covers scale calc | Covered by ResponsiveScale.spec.luau |
| MODAL-09 | RaceResultsUI scales at 414px viewport | unit (calculateScale) | Existing test covers scale calc | Covered by ResponsiveScale.spec.luau |
| TOUCH-01 | Close buttons 44px+ effective hit area | manual-only | Visual inspection in Roblox Studio device emulator | N/A |
| TOUCH-02 | Action buttons 44px+ effective at scaled size | manual-only | Visual inspection in Roblox Studio device emulator | N/A |
| TOUCH-03 | No notch/Dynamic Island clipping | manual-only | Device emulator with iPhone 14 Pro frame | N/A |
| POLISH-01 | Scale-in animation on show | manual-only | Visual verification of tween behavior | N/A |
| POLISH-02 | Modals centered after scaling | unit (calculateScale + AnchorPoint) | Verify AnchorPoint(0.5,0.5) + Position(0.5,0,0.5,0) in code | Code review |

### Sampling Rate
- **Per task commit:** Code review of integration pattern (applyToFrame + compensateStrokes call present)
- **Per wave merge:** Visual inspection of all 4 modals in Roblox Studio device emulator (iPhone SE frame)
- **Phase gate:** All modals fit 414px viewport, buttons tappable, animation smooth

### Wave 0 Gaps
None -- existing test infrastructure (ResponsiveScale.spec.luau) covers the pure scale calculation. Touch target and animation requirements are manual-verification-only (no feasible automated test for visual tween behavior in Roblox).

## Sources

### Primary (HIGH confidence)
- `src/shared/ResponsiveScale.luau` -- Current module implementation with applyToFrame, compensateStrokes, _updateAll
- `src/shared/__tests__/ResponsiveScale.spec.luau` -- Existing test patterns for scale calculation and stroke compensation
- `src/client/UI/RaceResultsUI.luau` -- Full file read, 450 lines, all structure understood
- `src/client/UI/MatchLobbyUI.luau` -- Partial read (createUI, buttons, show/hide, ScrollingFrame)
- `src/client/UI/SummaryUI.luau` -- Partial read (createUI, OK button, show/hide animation)
- `src/client/UI/StageSelectionUI.luau` -- Partial read (createUI, buttons, show/hide, Position bug)
- [Roblox ScreenInsets enum documentation](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets) -- CoreUISafeInsets behavior confirmed
- [Roblox ScreenGui.ScreenInsets property documentation](https://create.roblox.com/docs/reference/engine/classes/ScreenGui#ScreenInsets) -- Default is CoreUISafeInsets confirmed

### Secondary (MEDIUM confidence)
- [Roblox TweenService documentation](https://create.roblox.com/docs/reference/engine/classes/TweenService) -- UIScale.Scale is a tweenable property
- [Industry touch target guidelines (W3C/Apple/Google)](https://blog.logrocket.com/ux-design/all-accessible-touch-target-sizes/) -- 44px minimum standard

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- same ResponsiveScale pattern used 9 times in Phase 1-2
- Architecture: HIGH -- direct code inspection of all 4 target modals
- Pitfalls: HIGH -- identified through code analysis (SummaryUI Size animation, StageSelectionUI Position bug, RaceResultsUI stroke celebration, touch target sizes calculated from actual button dimensions and scale factors)
- Touch/Safe area: HIGH -- verified ScreenGui defaults and Roblox API docs

**Research date:** 2026-03-21
**Valid until:** 2026-04-21 (stable Roblox APIs, project-specific patterns)
