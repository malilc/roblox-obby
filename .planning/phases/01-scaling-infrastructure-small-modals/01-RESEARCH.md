# Phase 1: Scaling Infrastructure + Small Modals - Research

**Researched:** 2026-03-21
**Domain:** Roblox UIScale-based responsive scaling infrastructure + small modal integration
**Confidence:** HIGH

## Summary

Phase 1 builds the centralized ResponsiveScale module and validates it on the 4 lowest-risk modals. The technical approach is well-established: a single `UIScale` instance per modal frame, driven by a centralized module that tracks viewport changes via `Camera:GetPropertyChangedSignal("ViewportSize")`. The formula `math.min(1.0, (viewportW - 80) / designW, (viewportH - 80) / designH)` with a 0.5 floor is locked per user decisions.

The 4 small modals in scope -- SettingsUI (360x380), FeedbackUI (360x380), SpectatorUI (multi-panel), and LeaderboardUI (stub) -- are the cleanest integration targets. They have zero ScrollingFrame usage, zero AbsoluteSize/AbsoluteContentSize dependencies, and zero dynamically-created panels. This makes them ideal for validating the infrastructure before tackling complex modals in Phase 2.

The primary technical discretion areas are: (1) whether to use `Camera.ViewportSize` or `ScreenGui.AbsoluteSize` for viewport measurement (GuiInset affects the calculation since `IgnoreGuiInset = false`), (2) how to handle the ViewportSize one-frame timing quirk, and (3) internal data structure for tracking managed UIScale instances. Research findings support concrete recommendations for each.

**Primary recommendation:** Build ResponsiveScale.luau in src/shared/ with explicit `applyToFrame(frame, designW, designH)` API, initialize from MainUI.luau constructor, and apply to each small modal's root frame with a single line of code per modal.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** ResponsiveScale module lives in `src/shared/` -- follows existing pattern where ThemeConfig and Config are already in shared/
- **D-02:** MainUI.luau initializes ResponsiveScale once and passes it to modals -- single viewport listener, centralized control
- **D-03:** LeaderboardUI stays in scope (MODAL-13) even though it's currently a stub -- future-proofing
- **D-04:** 40px padding on each side of modals on mobile -- comfortable margin, modal doesn't feel edge-to-edge
- **D-05:** Minimum scale floor of 0.5x -- prevents modals from shrinking below usability threshold (780px modal becomes 390px at floor)
- **D-06:** Scale formula: `math.min(1.0, (viewportW - 80) / designW, (viewportH - 80) / designH)` -- 80 = 40px padding x 2 sides
- **D-07:** All SpectatorUI sub-panels scale uniformly (prompt 280x50, rankings 200x300, controls 400x44) -- consistency over selective scaling
- **D-08:** Explicit per-modal opt-in via `ResponsiveScale:applyToFrame(frame, designW, designH)` -- clear, no magic
- **D-09:** Also update the unused `UIFactory.createModal()` to include scaling -- so future modals auto-scale when using createModal
- **D-10:** Each modal stores its own design size (width, height) as constants at the top of the file (e.g., `local PANEL_W = 360`)

### Claude's Discretion
- How to handle the Camera.ViewportSize one-frame timing quirk (task.wait or alternative)
- Whether to use ScreenGui.AbsoluteSize or Camera.ViewportSize for the viewport measurement (research found GuiInset considerations)
- Internal data structure for tracking managed UIScale instances
- How to structure the signal/callback for notifying modals of scale changes

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SCALE-01 | Centralized ResponsiveScale module computes scale factor from viewport size and modal design size | ResponsiveScale.luau in src/shared/ with calculateScale() and applyToFrame() API. ThemeConfig.luau is the pattern model. |
| SCALE-02 | Scale formula: `math.min(1.0, (viewportW - padding) / designW, (viewportH - padding) / designH)` | Formula locked by D-06 with 80px total padding. Must account for GuiInset (see Discretion Recommendation 1). |
| SCALE-03 | Viewport change listener recalculates scale on Camera.ViewportSize change | Single listener in ResponsiveScale.init() batch-updates all tracked UIScale instances. task.wait() recommended for timing (see Discretion Recommendation 2). |
| SCALE-04 | Minimum scale floor (0.5) prevents modals from shrinking below usability threshold | math.max(scaleFactor, 0.5) applied after math.min. Locked by D-05. |
| SCALE-05 | Desktop screens show modals at full design size (scale clamped to 1.0) | The `1.0` in math.min ensures desktop never upscales. Verified: small modals (360px) already fit on mobile, so scaling infrastructure validates correctly when scale=1.0 on desktop. |
| MODAL-10 | SettingsUI scales properly on small screens | applyToFrame on self.container (360x380). No ScrollingFrame, no AbsoluteSize usage. Clean integration. |
| MODAL-11 | FeedbackUI scales properly on small screens | applyToFrame on self.container (360x380). Same pattern as SettingsUI. No complications. |
| MODAL-12 | SpectatorUI scales properly on small screens | Three separate panels: promptContainer (280x50), rankingsPanel (200x300), controlBar (400x44). D-07 says all scale uniformly -- each gets its own applyToFrame call with its own design dimensions. |
| MODAL-13 | LeaderboardUI scales properly on small screens | Currently a stub (empty constructor). Future-proof by adding a comment or placeholder for when UI is built. No UI to scale yet. |
</phase_requirements>

## Standard Stack

### Core
| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| UIScale | Engine built-in (stable) | Uniform scale multiplier on each modal frame | Scales parent AND all descendants -- sizes, text, UICorner, UIStroke, padding -- in one shot. Official Roblox-endorsed approach. |
| Camera.ViewportSize | Engine built-in (stable) | Read current screen dimensions (Vector2) | Returns device dimensions in UI offset units. Standard community pattern. |
| Camera:GetPropertyChangedSignal("ViewportSize") | Engine built-in (stable) | React to viewport size changes | Fires on window resize, device rotation. Confirmed working with deferred signal behavior. |

### Supporting
| Technology | Version | Purpose | When to Use |
|------------|---------|---------|-------------|
| GuiService:GetGuiInset() | Engine built-in | Get top bar inset height | Use to subtract from ViewportSize.Y when IgnoreGuiInset=false (which this codebase uses) |
| task.wait() | Engine built-in | One-frame yield after viewport change | Use inside ViewportSize change handler to let layout settle before reading new size |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Camera.ViewportSize | ScreenGui.AbsoluteSize | AbsoluteSize already accounts for GuiInset but requires ScreenGui reference. Camera is globally accessible. See Discretion Recommendation 1. |
| task.wait() for timing | task.defer() | task.defer runs at end of current resumption cycle, may not wait long enough. task.wait() yields one full frame. |

**Installation:** No packages needed. All APIs are Roblox engine built-ins.

## Architecture Patterns

### Recommended Project Structure
```
src/
  shared/
    ResponsiveScale.luau   # NEW: centralized scale computation + UIScale management
    ThemeConfig.luau        # existing: design tokens (pattern model)
    Config.luau             # existing: game configuration
  client/
    UI/
      MainUI.luau           # MODIFIED: initialize ResponsiveScale, apply to modals
      UIFactory.luau        # MODIFIED: add scaling to createModal()
      SettingsUI.luau       # MODIFIED: one-line applyToFrame call
      FeedbackUI.luau       # MODIFIED: one-line applyToFrame call
      SpectatorUI.luau      # MODIFIED: three applyToFrame calls (one per sub-panel)
      LeaderboardUI.luau    # MODIFIED: placeholder comment for future scaling
```

### Pattern 1: Centralized Scale Module with Per-Modal Opt-In
**What:** ResponsiveScale.luau exports `applyToFrame(frame, designW, designH)` which creates a UIScale child, computes the initial scale, and registers the frame for viewport-change updates.
**When to use:** Every modal that needs responsive scaling.
**Example:**
```luau
-- ResponsiveScale.luau (src/shared/)
local Camera = workspace.CurrentCamera
local GuiService = game:GetService("GuiService")

local ResponsiveScale = {}

local MIN_SCALE = 0.5
local PADDING = 80 -- 40px each side

local trackedScales: {{
    uiScale: UIScale,
    designWidth: number,
    designHeight: number,
}} = {}

function ResponsiveScale.calculateScale(designWidth: number, designHeight: number): number
    local viewport = Camera.ViewportSize
    local _, guiInsetTop = GuiService:GetGuiInset()
    -- Subtract GuiInset from height since ScreenGui has IgnoreGuiInset=false
    local availableW = viewport.X
    local availableH = viewport.Y - guiInsetTop.Y
    local scaleX = (availableW - PADDING) / designWidth
    local scaleY = (availableH - PADDING) / designHeight
    local scale = math.min(scaleX, scaleY, 1.0)
    return math.max(scale, MIN_SCALE)
end

function ResponsiveScale.applyToFrame(
    frame: GuiObject,
    designWidth: number,
    designHeight: number
): UIScale
    local uiScale = Instance.new("UIScale")
    uiScale.Scale = ResponsiveScale.calculateScale(designWidth, designHeight)
    uiScale.Parent = frame
    table.insert(trackedScales, {
        uiScale = uiScale,
        designWidth = designWidth,
        designHeight = designHeight,
    })
    return uiScale
end

function ResponsiveScale._updateAll()
    for i = #trackedScales, 1, -1 do
        local entry = trackedScales[i]
        if entry.uiScale.Parent then
            entry.uiScale.Scale = ResponsiveScale.calculateScale(
                entry.designWidth,
                entry.designHeight
            )
        else
            table.remove(trackedScales, i)
        end
    end
end

function ResponsiveScale.init()
    Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        task.wait() -- yield one frame for layout to settle
        ResponsiveScale._updateAll()
    end)
end

return ResponsiveScale
```
**Source:** Roblox UIScale API docs + project-level ARCHITECTURE.md research

### Pattern 2: Per-Modal Single-Line Integration
**What:** Each modal adds ONE line after its root frame is created.
**When to use:** Every modal's constructor or build function.
**Example:**
```luau
-- In SettingsUI:_build(), after self.container is created:
local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)
ResponsiveScale.applyToFrame(self.container, PANEL_W, PANEL_H)
```

### Pattern 3: UIFactory.createModal() Auto-Scaling
**What:** Update the unused UIFactory.createModal() to automatically apply ResponsiveScale to the panel it creates.
**When to use:** Future modals using UIFactory.createModal() get scaling for free.
**Example:**
```luau
-- In UIFactory.createModal, after creating panel:
local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)

function UIFactory.createModal(parent, options)
    -- ... existing overlay + panel creation ...

    -- NEW: Apply responsive scaling (opt-out via options.responsive == false)
    if options.responsive ~= false then
        ResponsiveScale.applyToFrame(
            panel,
            options.size.X.Offset,
            options.size.Y.Offset
        )
    end

    return overlay, panel
end
```

### Pattern 4: SpectatorUI Multi-Panel Scaling
**What:** SpectatorUI has 3 independent sub-panels (not one modal). Each gets its own applyToFrame call with its own design dimensions, per D-07.
**When to use:** SpectatorUI specifically.
**Example:**
```luau
-- In SpectatorUI:createUI(), after each sub-panel is created:
ResponsiveScale.applyToFrame(self.promptContainer, 280, 50)
ResponsiveScale.applyToFrame(self.rankingsPanel, 200, 300)
ResponsiveScale.applyToFrame(controlBar, 400, 44)
```
**Note:** The SpectatorUI HUD frame (full-screen transparent overlay) should NOT be scaled -- it's a layout container, not a modal.

### Anti-Patterns to Avoid
- **UIScale on ScreenGui:** Would scale HUD elements (out of scope per PROJECT.md). Always per-modal.
- **Scaling logic in every UI module:** Duplicated formula across files. Always centralized in ResponsiveScale.
- **Converting UDim2 offsets to scale values:** Massive rewrite. UIScale achieves same result with zero layout changes.
- **Using AbsoluteSize instead of Camera.ViewportSize:** ScreenGui.AbsoluteSize requires a ScreenGui reference; Camera is globally accessible.
- **Forgetting GuiInset:** Since IgnoreGuiInset=false, the usable height is ViewportSize.Y minus the top bar inset (~36-58px). Ignoring this makes modals slightly too large for the available space.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Modal scaling | Custom size calculation per modal | UIScale instance with ResponsiveScale module | UIScale handles all descendants automatically -- text, corners, strokes, padding. Zero changes to child elements. |
| Viewport detection | Per-modal viewport listeners | Single Camera.ViewportSize listener in ResponsiveScale.init() | One listener, one place to debug, consistent across all modals. |
| Scale computation | Inline math in each UI file | ResponsiveScale.calculateScale(designW, designH) | One formula, one place to tune padding/floor constants. |

**Key insight:** UIScale is a render-level transform that does not modify the logical coordinate space. All existing Size/Position values remain valid. This is what makes the approach low-risk for Phase 1.

## Claude's Discretion Recommendations

### Recommendation 1: Viewport Measurement -- Use Camera.ViewportSize with GuiInset Subtraction

**Decision:** Use `Camera.ViewportSize` and subtract the GuiInset top offset for the height calculation.

**Rationale:**
- The codebase ScreenGui has `IgnoreGuiInset = false` (MainUI.luau line 60), meaning the content area starts below the Roblox top bar
- `Camera.ViewportSize` returns full screen dimensions, but the usable area for UI is reduced by the top bar inset (~36-58px depending on client version)
- `GuiService:GetGuiInset()` returns the inset as a Vector2 pair: `(topLeftInset, bottomRightInset)`. The Y component of the first return value gives the top bar height.
- Alternatively, `ScreenGui.AbsoluteSize` already accounts for the inset, but requires passing the ScreenGui reference to ResponsiveScale

**Implementation:**
```luau
local GuiService = game:GetService("GuiService")
local guiInset = GuiService:GetGuiInset() -- returns (Vector2 topLeft, Vector2 bottomRight)
local availableH = Camera.ViewportSize.Y - guiInset.Y
```

**Confidence:** HIGH -- verified that IgnoreGuiInset=false in codebase, and GuiService:GetGuiInset() is a stable API.

### Recommendation 2: ViewportSize Timing -- Use task.wait() in Change Handler

**Decision:** Add `task.wait()` after the ViewportSize change signal fires, before reading the new value and recalculating.

**Rationale:**
- Known Roblox behavior: ViewportSize signal can fire before UI layout has fully recalculated
- `task.wait()` yields one full frame, ensuring layout is settled
- `task.defer()` runs at the end of the current resumption cycle -- may not wait long enough
- Performance impact is negligible (one frame delay on resize, not on every frame)
- This matches the community-verified pattern from DevForum

**Implementation:**
```luau
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    task.wait() -- one frame for layout to settle
    ResponsiveScale._updateAll()
end)
```

**Confidence:** HIGH -- documented pattern with community verification.

### Recommendation 3: Internal Data Structure -- Simple Array of Tracked Entries

**Decision:** Use a flat array of `{uiScale, designWidth, designHeight}` tuples.

**Rationale:**
- Phase 1 has at most 6 tracked entries (4 small modals, some with multiple panels). Phase 2/3 adds ~15 more. Total will never exceed ~25.
- Array iteration is O(n) but n is trivially small. No need for a hash map or linked list.
- Reverse iteration in _updateAll() allows safe removal of cleaned-up entries (when uiScale.Parent is nil).
- The entry stores the design dimensions alongside the UIScale reference so recalculation doesn't need to look them up elsewhere.

**Confidence:** HIGH -- straightforward data structure for the scale of this problem.

### Recommendation 4: No Callback/Signal System Needed

**Decision:** ResponsiveScale directly updates UIScale.Scale values. No external signal/callback to modals.

**Rationale:**
- UIScale is a Roblox Instance property. Changing `.Scale` immediately updates the visual rendering.
- No modal in Phase 1 needs to react to scale changes (no dynamic layout recalculation, no AbsoluteSize usage).
- If a future phase needs callbacks (e.g., Phase 2 ScrollingFrame CanvasSize recalculation), the module can be extended with an optional callback in the tracked entry.
- Keep it simple now; extend later if needed.

**Confidence:** HIGH -- verified that Phase 1 modals have zero AbsoluteSize/AbsoluteContentSize dependencies.

## Common Pitfalls

### Pitfall 1: GuiInset Not Accounted For
**What goes wrong:** Scale calculation uses full ViewportSize.Y but the ScreenGui only occupies ViewportSize.Y minus the top bar inset. Modals appear slightly too large for the actual available space.
**Why it happens:** `IgnoreGuiInset = false` in MainUI.luau (line 60) reduces the usable area, but Camera.ViewportSize reports the full screen.
**How to avoid:** Subtract `GuiService:GetGuiInset().Y` from ViewportSize.Y before computing scale.
**Warning signs:** On mobile, the top of a modal overlaps with or approaches the Roblox top bar.

### Pitfall 2: ViewportSize One-Frame Stale Read
**What goes wrong:** Scale recalculation uses stale viewport dimensions because the signal fires before layout fully updates.
**Why it happens:** Roblox deferred signal behavior -- ViewportSize changed signal fires immediately but UI layout may not have recomputed yet.
**How to avoid:** Add `task.wait()` after the signal fires, before reading ViewportSize.
**Warning signs:** On window resize, modals briefly appear at wrong scale then snap to correct size.

### Pitfall 3: Applying UIScale to Wrong Frame (SpectatorUI)
**What goes wrong:** SpectatorUI has a full-screen HUD frame (`self.hud`) that is a transparent layout container. Applying UIScale to it would scale the entire HUD including child positions.
**Why it happens:** SpectatorUI structure is different from other modals -- it has 3 separate positioned sub-panels inside a full-screen container, not a single centered modal.
**How to avoid:** Apply UIScale to each sub-panel individually (promptContainer, rankingsPanel, controlBar), not to `self.hud`.
**Warning signs:** Rankings panel positioned at top-left appears shifted toward center after scaling.

### Pitfall 4: LeaderboardUI Stub Confusion
**What goes wrong:** Developer tries to apply scaling to LeaderboardUI but there's no UI frame to scale.
**Why it happens:** LeaderboardUI.luau is an empty stub -- the leaderboard is server-side SurfaceGui on physical parts, not a client-side modal.
**How to avoid:** Add a comment in LeaderboardUI noting it's a stub and scaling will be applied when UI is built. Mark MODAL-13 as satisfied by future-proofing.
**Warning signs:** Attempting to call applyToFrame on nil.

### Pitfall 5: Module Require Path
**What goes wrong:** ResponsiveScale.luau in src/shared/ but require path is wrong.
**Why it happens:** The Rojo project maps src/shared/ to ReplicatedStorage.Shared. New files must follow the same convention.
**How to avoid:** Require via `require(ReplicatedStorage.Shared.ResponsiveScale)` -- same pattern as ThemeConfig and Config.
**Warning signs:** "Module not found" errors at runtime.

### Pitfall 6: SpectatorUI Sub-Panel Design Dimensions
**What goes wrong:** Using incorrect design dimensions for SpectatorUI sub-panels causes wrong scale calculations.
**Why it happens:** SpectatorUI sub-panel sizes are hardcoded in the createUI() function, not stored as constants at the top of the file.
**How to avoid:** Extract design dimensions as constants at the top of SpectatorUI.luau (per D-10) before applying scaling.
**Warning signs:** Panels appear too large or too small on mobile relative to expectations.

## Code Examples

### Example 1: ResponsiveScale Module Core
See Architecture Patterns > Pattern 1 above for the complete module implementation.

### Example 2: SettingsUI Integration (representative of all small modals)
```luau
-- At top of SettingsUI.luau, add require:
local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)

-- In SettingsUI:_build(), after self.container is created and configured:
-- (after line 45 in current code)
ResponsiveScale.applyToFrame(self.container, PANEL_W, PANEL_H)
```

### Example 3: SpectatorUI Multi-Panel Integration
```luau
-- At top of SpectatorUI.luau:
local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)

-- Design dimensions as constants (per D-10):
local PROMPT_W = 280
local PROMPT_H = 50
local RANKINGS_W = 200
local RANKINGS_H = 300
local CONTROL_W = 400
local CONTROL_H = 44

-- In SpectatorUI:createUI(), after each sub-panel is created:
ResponsiveScale.applyToFrame(self.promptContainer, PROMPT_W, PROMPT_H)
ResponsiveScale.applyToFrame(self.rankingsPanel, RANKINGS_W, RANKINGS_H)
ResponsiveScale.applyToFrame(controlBar, CONTROL_W, CONTROL_H)
```

### Example 4: MainUI.luau Initialization
```luau
-- At top of MainUI.luau, add require:
local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)

-- In MainUI.new(), early in the constructor (before creating UI components):
ResponsiveScale.init()
```

### Example 5: UIFactory.createModal Update
```luau
-- At top of UIFactory.luau:
local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)

-- In UIFactory.createModal, after panel creation (before return):
if options.responsive ~= false then
    ResponsiveScale.applyToFrame(
        panel,
        options.size.X.Offset,
        options.size.Y.Offset
    )
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Convert all UDim2 offsets to Scale | UIScale instance per modal | Standard since UIScale API stabilized | Zero changes to existing layout code |
| GuiService.ViewportDisplaySize buckets | Camera.ViewportSize continuous formula | ViewportDisplaySize released Oct 2025, but too coarse | Use continuous formula for precise scaling |
| UIStroke FixedSize mode | UIStroke ScaledSize mode available | Dec 2025 | NOT adopting -- ScaledSize has known UIScale interaction bug. Stick with FixedSize. Phase 2 concern anyway. |

**Deprecated/outdated:**
- UISizeConstraint + UIScale combination: Known engine bug where UIScale ignores UISizeConstraint. Do not combine them.

## Open Questions

1. **SpectatorUI prompt position offset after scaling**
   - What we know: promptContainer uses absolute position `UDim2.new(0.5, -140, 1, -70)`. UIScale will visually shrink the container but the position offset (-140, -70) is also affected by the UIScale.
   - What's unclear: Since UIScale scales the frame and its position offsets relative to the parent, the prompt may shift position visually. Need to verify during implementation.
   - Recommendation: Test on mobile emulator. If position is off, the prompt may need its AnchorPoint set to (0.5, 1) with Scale-based position instead of offset-based.

2. **SpectatorUI control bar width vs mobile viewport**
   - What we know: Control bar is 400x44px. On a 414px phone with 80px padding, available width is 334px. Scale = 334/400 = 0.835x. The bar becomes 334px wide -- fits but tight.
   - What's unclear: Whether the 4 control buttons inside remain readable/tappable at 0.835x scale (buttons are 85x32, become ~71x27).
   - Recommendation: Verify during implementation. At 0.835x, button hit areas should be acceptable (71px > 44px minimum).

3. **GuiInset exact value on modern Roblox clients**
   - What we know: Historically 36px, reports suggest 58px on newer clients. GetGuiInset() returns the actual runtime value.
   - What's unclear: Whether the value varies by platform (PC vs mobile vs console).
   - Recommendation: Use GetGuiInset() at runtime rather than hardcoding any offset. The API returns the correct value per platform.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Jest 3.10.0 (jsdotlua/jest) |
| Config file | test.project.json (Rojo test config) |
| Quick run command | `run-in-roblox --place test.project.json --script scripts/run-tests.server.luau` |
| Full suite command | Same (single test entry point) |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SCALE-01 | ResponsiveScale.calculateScale returns correct factor for given viewport and design size | unit | Jest test in shared/__tests__/ | Wave 0 |
| SCALE-02 | Formula produces correct values: math.min(1.0, (vW-80)/dW, (vH-80)/dH) | unit | Jest test in shared/__tests__/ | Wave 0 |
| SCALE-03 | ViewportSize listener calls _updateAll | manual-only | Requires Roblox runtime (Camera mock not practical) | N/A |
| SCALE-04 | Scale floor of 0.5 prevents going below threshold | unit | Jest test in shared/__tests__/ | Wave 0 |
| SCALE-05 | Desktop viewport returns scale=1.0 for small modals | unit | Jest test in shared/__tests__/ | Wave 0 |
| MODAL-10 | SettingsUI has applyToFrame call | manual-only | Visual verification in Studio device emulator | N/A |
| MODAL-11 | FeedbackUI has applyToFrame call | manual-only | Visual verification in Studio device emulator | N/A |
| MODAL-12 | SpectatorUI sub-panels have applyToFrame calls | manual-only | Visual verification in Studio device emulator | N/A |
| MODAL-13 | LeaderboardUI stub has scaling placeholder | manual-only | Code review (stub has no UI to test) | N/A |

**Note on testability:** ResponsiveScale.calculateScale() is a pure function that takes design dimensions and returns a number. It can be unit tested with mocked Camera.ViewportSize. The applyToFrame and viewport listener require Roblox runtime (Instance creation, property signals) and are not unit-testable in the Jest framework. They require manual verification in Studio's device emulator.

### Sampling Rate
- **Per task commit:** Unit tests for calculateScale function
- **Per wave merge:** Full Jest suite + visual verification in Studio device emulator at 414x736 (iPhone SE) and 1920x1080 (desktop)
- **Phase gate:** All unit tests green + visual confirmation at mobile resolution

### Wave 0 Gaps
- [ ] `src/shared/__tests__/ResponsiveScale.spec.luau` -- covers SCALE-01, SCALE-02, SCALE-04, SCALE-05
- [ ] Mock for Camera.ViewportSize in test environment (may require injecting viewport size as parameter to calculateScale for testability)

## Sources

### Primary (HIGH confidence)
- Project codebase analysis: SettingsUI.luau, FeedbackUI.luau, SpectatorUI.luau, LeaderboardUI.luau, MainUI.luau, UIFactory.luau, ThemeConfig.luau -- verified all frame types, sizes, patterns
- Project-level STACK.md research -- UIScale API, formula, viewport detection
- Project-level ARCHITECTURE.md research -- ResponsiveScale module design, integration points
- Project-level PITFALLS.md research -- GuiInset, timing, multi-panel structures

### Secondary (MEDIUM confidence)
- [Roblox UIScale API Reference](https://create.roblox.com/docs/reference/engine/classes/UIScale) -- Confirms scaling behavior
- [Camera.ViewportSize API Reference](https://create.roblox.com/docs/reference/engine/classes/Camera/ViewportSize) -- Viewport dimensions
- [GuiService:GetGuiInset()](https://create.roblox.com/docs/reference/engine/classes/GuiService#GetGuiInset) -- Top bar offset
- [ViewportSize GetPropertyChangedSignal behavior (DevForum)](https://devforum.roblox.com/t/getpropertychangedsignalviewportsize-behaviour/3987385) -- Timing quirk + task.wait() fix

### Tertiary (LOW confidence)
- SpectatorUI position offset behavior under UIScale -- needs runtime verification (Open Question 1)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- Roblox engine built-ins, well-documented APIs
- Architecture: HIGH -- follows existing codebase patterns (ThemeConfig in shared/, module pattern), verified integration points
- Pitfalls: HIGH -- Phase 1 modals are specifically chosen for low risk (no ScrollingFrame, no AbsoluteSize usage, no dynamic creation). Known issues (UIStroke, ScrollingFrame) are Phase 2 concerns.
- Discretion recommendations: HIGH -- each backed by codebase verification and official documentation

**Research date:** 2026-03-21
**Valid until:** 2026-04-21 (stable Roblox engine APIs, no expected breaking changes)
