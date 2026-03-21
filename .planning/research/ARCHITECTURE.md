# Architecture Patterns

**Domain:** Responsive UI scaling for Roblox obby game
**Researched:** 2026-03-21

## Recommended Architecture

### Central ResponsiveScale Module + UIFactory Integration

The scaling logic should live in a **single dedicated module** (`ResponsiveScale.luau`) in `src/shared/`, with **UIFactory.luau** as the only integration point for automatically applying scaling to new modals. Individual UI modules should not contain any scaling logic.

**Why this placement:**
- `src/shared/` because the module needs access from any client code (including init.client.luau's UpdateLog popup which creates its own ScreenGui)
- Centralized because the scaling formula and viewport listener must be defined once, not scattered across 15+ UI files
- UIFactory integration because that is the natural point where panels/modals are created -- but most UIs do NOT use UIFactory.createModal today, so the module must also expose a standalone function

### Architecture Diagram

```
workspace.CurrentCamera.ViewportSize
            |
            v
  +--------------------+
  | ResponsiveScale    |  <-- src/shared/ResponsiveScale.luau
  | .getScale(w, h)    |      Pure function: returns scale factor
  | .applyToFrame(f)   |      Adds UIScale child + connects listener
  | .onViewportChanged |      Signal connection manager
  +--------------------+
       |           |
       v           v
  UIFactory    Direct calls from UI modules
  .createModal()   (for UIs that don't use UIFactory)
  .createPanel()
       |
       v
  UIScale instance parented to each modal frame
  (Scale property updated on viewport change)
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **ResponsiveScale** | Calculate scale factor from viewport vs design size; manage UIScale instances; listen to viewport changes | Camera (reads ViewportSize), UIScale instances (writes Scale property) |
| **UIFactory** | Create panels/modals with automatic responsive scaling applied | ResponsiveScale (calls applyToFrame), Theme (reads colors/sizes) |
| **ThemeConfig** | Store design-time size constants (MODAL_LARGE, MODAL_MEDIUM, etc.) | ResponsiveScale (provides design dimensions for scale calculation) |
| **Individual UIs** | Create their own content using fixed pixel sizes (unchanged) | UIFactory or ResponsiveScale.applyToFrame (one-time call on root frame) |
| **MainUI** | Orchestrate panel visibility; no scaling responsibility | Individual UIs (show/hide) |

### Data Flow: Viewport Change to Scale Update

```
1. Player rotates phone / resizes window
2. Camera.ViewportSize property changes
3. Camera:GetPropertyChangedSignal("ViewportSize") fires
4. ResponsiveScale handler reads new ViewportSize
5. For each tracked modal frame:
   a. Compute: scaleFactor = math.min(viewportW / designW, viewportH / designH, 1.0)
   b. Clamp: scaleFactor = math.max(scaleFactor, MIN_SCALE)
   c. Update: uiScaleInstance.Scale = scaleFactor
6. UIScale proportionally scales the frame AND all descendants
   (including UICorner, UIStroke -- confirmed by official docs)
7. Frame stays centered (AnchorPoint 0.5, 0.5 already set on all modals)
```

**Critical detail:** UIScale scales the parent GuiObject and ALL descendants proportionally, including appearance modifiers like UIStroke and UICorner. This means adding a single UIScale instance to each modal's root frame is sufficient -- no changes needed to any child elements.

## The ResponsiveScale Module

### Core Design

```luau
-- ResponsiveScale.luau
-- Central viewport-aware scaling for modal UI frames

local Camera = workspace.CurrentCamera

local ResponsiveScale = {}

-- Design resolution: the viewport size modals were designed for
-- Based on typical Roblox desktop viewport (~1920x1080 minus top bar)
local DESIGN_WIDTH = 1920
local DESIGN_HEIGHT = 1080

-- Minimum scale to prevent modals from becoming unusably small
local MIN_SCALE = 0.45

-- Maximum scale (1.0 = never upscale beyond design size)
local MAX_SCALE = 1.0

-- Padding factor: ensure modal doesn't touch screen edges
local PADDING = 0.92  -- 8% margin

-- Track all managed UIScale instances for batch updates
local trackedScales: {{
    uiScale: UIScale,
    designWidth: number,
    designHeight: number,
}} = {}

-- Calculate scale for a specific modal given current viewport
function ResponsiveScale.calculateScale(
    designWidth: number,
    designHeight: number
): number
    local viewport = Camera.ViewportSize
    local scaleX = (viewport.X * PADDING) / designWidth
    local scaleY = (viewport.Y * PADDING) / designHeight
    local scale = math.min(scaleX, scaleY, MAX_SCALE)
    return math.max(scale, MIN_SCALE)
end

-- Apply responsive scaling to a frame
-- Returns the UIScale instance for external control if needed
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

-- Update all tracked scales (called on viewport change)
function ResponsiveScale._updateAll()
    for i = #trackedScales, 1, -1 do
        local entry = trackedScales[i]
        if entry.uiScale.Parent then
            entry.uiScale.Scale = ResponsiveScale.calculateScale(
                entry.designWidth,
                entry.designHeight
            )
        else
            -- UIScale was destroyed (modal cleaned up), remove tracking
            table.remove(trackedScales, i)
        end
    end
end

-- Initialize viewport listener (call once from client entry point)
function ResponsiveScale.init()
    Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        ResponsiveScale._updateAll()
    end)
end

return ResponsiveScale
```

### Key Formula Explanation

```
scaleFactor = math.min(
    (viewportWidth * 0.92) / modalDesignWidth,
    (viewportHeight * 0.92) / modalDesignHeight,
    1.0  -- never upscale
)
```

- Uses `math.min` of X-ratio and Y-ratio so the modal fits in BOTH dimensions
- The `0.92` padding factor keeps an 8% margin so modals do not touch screen edges
- Capped at `1.0` so desktop users see the original pixel-perfect sizes
- Floor of `0.45` prevents modals from becoming unreadable on tiny screens

**Example:** A 780x580 modal on a 414x736 phone (iPhone SE portrait):
- scaleX = (414 * 0.92) / 780 = 0.488
- scaleY = (736 * 0.92) / 580 = 1.167
- scale = math.min(0.488, 1.167, 1.0) = 0.488
- Modal renders at ~381x283 pixels -- fits with margin

## Integration Points with Existing Code

### Integration 1: UIFactory.createModal Enhancement

UIFactory.createModal is defined but **never used** in the current codebase. Every UI module creates its own frames manually. This is actually fine -- we do NOT need to force all UIs to use createModal. Instead:

**Option A (recommended):** Add `ResponsiveScale.applyToFrame()` call in UIFactory.createModal AND expose it for direct use by UIs that build frames manually.

```luau
-- In UIFactory.createModal, after creating the panel:
local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)

function UIFactory.createModal(parent, options)
    -- ... existing overlay + panel creation ...

    -- NEW: Apply responsive scaling to the panel
    if options.responsive ~= false then  -- opt-out, not opt-in
        ResponsiveScale.applyToFrame(
            panel,
            options.size.X.Offset,
            options.size.Y.Offset
        )
    end

    return overlay, panel
end
```

**Option B (for UIs that build frames manually):** Each UI module adds ONE line after creating its root frame:

```luau
-- In ShopUI:createUI(), after creating mainFrame:
local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)
ResponsiveScale.applyToFrame(self.mainFrame, 780, 580)
```

### Integration 2: ThemeConfig Size Constants

Add standard modal size constants to ThemeConfig so design dimensions are centralized:

```luau
-- In ThemeConfig.luau, add to STRUCTURE TOKENS section:
Theme.MODAL_LARGE  = { width = 780, height = 580 }  -- Shop, Class, Title, Tutorial, Daily
Theme.MODAL_MEDIUM_TALL = { width = 400, height = 600 }  -- Summary
Theme.MODAL_MEDIUM = { width = 400, height = 500 }  -- Match Lobby
Theme.MODAL_RACE   = { width = 450, height = 500 }  -- Race Results
Theme.MODAL_STAGE  = { width = 580, height = 480 }  -- Stage Selection
Theme.MODAL_SMALL  = { width = 360, height = 380 }  -- Settings, Feedback
```

This gives ResponsiveScale accurate design dimensions to compute against. These constants also serve as documentation of intended sizes.

### Integration 3: Client Entry Point Initialization

In `src/client/init.client.luau`, add one line early in the file:

```luau
-- After requiring modules, before creating MainUI:
local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)
ResponsiveScale.init()
```

This sets up the viewport change listener once. All subsequent `applyToFrame` calls will automatically participate in viewport-driven updates.

### Integration 4: UpdateLog Popup (init.client.luau)

The UpdateLog popup in init.client.luau creates a 460x480 panel outside the MainUI system. It needs a direct `ResponsiveScale.applyToFrame(panel, 460, 480)` call.

### Integration 5: DailyBonusUI Calendar Popup

DailyBonusUI creates its own ScreenGui with DisplayOrder 100 for the calendar popup. The scaling should be applied to the panel frame inside this ScreenGui, not the ScreenGui itself. `ResponsiveScale.applyToFrame(panel, 780, 580)` after the panel is created.

## Patterns to Follow

### Pattern 1: One UIScale Per Modal Root Frame

**What:** Add exactly one UIScale instance as a child of each modal's root frame (the fixed-pixel-size frame, not the overlay).

**When:** Every modal or popup that uses fixed pixel dimensions.

**Why:** UIScale propagates to ALL descendants. Adding it at the root means every label, button, scroll frame, and stroke inside the modal scales uniformly. No changes to child elements.

**Example:**
```luau
-- ShopUI.luau, inside createUI()
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 780, 0, 580)  -- UNCHANGED
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)  -- UNCHANGED
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)  -- UNCHANGED
-- ... all other setup ...
mainFrame.Parent = self.parent

-- ONE new line:
ResponsiveScale.applyToFrame(mainFrame, 780, 580)
```

### Pattern 2: Frame Stays Fixed Pixels, UIScale Does the Work

**What:** Do NOT change any existing UDim2 sizes from offset to scale. Keep all the `UDim2.new(0, px, 0, px)` values exactly as they are.

**When:** Always. This is the core principle.

**Why:** Converting to scale-based sizing would require touching hundreds of lines across 15+ files and would change the layout engine behavior. UIScale achieves the same visual result with zero changes to existing size/position values.

### Pattern 3: Centralized Viewport Listener

**What:** A single `Camera:GetPropertyChangedSignal("ViewportSize")` connection in ResponsiveScale.init() that batch-updates all tracked UIScale instances.

**When:** Set up once during client initialization.

**Why:** Avoids N separate viewport listeners (one per modal). More efficient and easier to debug. One place to add throttling or frame-delay workarounds if needed.

### Pattern 4: Scale-Down Only (Never Upscale)

**What:** Cap UIScale.Scale at 1.0. Modals are designed at their fixed pixel sizes and should never appear larger than designed.

**When:** Always. The MAX_SCALE constant enforces this.

**Why:** Upscaling would make text and UI elements appear blurry/pixelated. The fixed pixel sizes are the "ideal" appearance.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Scaling Logic in Every UI Module

**What:** Each UI module independently reading ViewportSize and computing its own scale.

**Why bad:** Duplicated logic across 15+ files. Inconsistent formulas. Difficult to tune globally. Impossible to add features like scale animation or debug overlay.

**Instead:** All scaling flows through ResponsiveScale module. UI modules call one function.

### Anti-Pattern 2: Replacing Offset Sizes with Scale Sizes

**What:** Converting `UDim2.new(0, 780, 0, 580)` to `UDim2.new(0.4, 0, 0.5, 0)` throughout the codebase.

**Why bad:** Massive change surface (hundreds of lines). Children sized with Scale relative to parent would need recalculation. Layout proportions would shift. Elements using absolute pixel positioning would break.

**Instead:** Keep all existing pixel sizes. UIScale handles the viewport adaptation.

### Anti-Pattern 3: UIScale on the ScreenGui

**What:** Placing one UIScale on the top-level ScreenGui to scale everything at once.

**Why bad:** HUD elements (currency, score, gems, menu grid) should NOT be scaled -- the user confirmed these are fine. Scaling the ScreenGui would shrink HUD elements too, requiring them to be un-scaled or moved to a separate ScreenGui.

**Instead:** UIScale on each individual modal frame. This preserves HUD sizing while only scaling popups.

### Anti-Pattern 4: Using AbsoluteSize Instead of Camera.ViewportSize

**What:** Reading `screenGui.AbsoluteSize` to determine viewport dimensions.

**Why bad:** AbsoluteSize is affected by IgnoreGuiInset setting and may not match the actual safe area. Camera.ViewportSize is the canonical source that represents the device safe area in Roblox UI offset units.

**Instead:** Always use `workspace.CurrentCamera.ViewportSize` for viewport dimensions.

## Complete Modal Inventory

Modals that need ResponsiveScale applied, grouped by design size:

### Group 1: Large Modals (780 x 580)

| Modal | File | Root Frame Variable | Notes |
|-------|------|---------------------|-------|
| Shop | ShopUI.luau | `self.mainFrame` | Manual frame creation |
| Class Selection | ClassSelectionUI.luau | `self.container` (line 296) | Manual frame creation |
| Title Collection | TitleCollectionUI.luau | `self.container` (line 198) | Manual frame creation |
| Tutorial | TutorialUI.luau | `self.panel` (line 78) | Manual frame creation |
| Daily Bonus Calendar | DailyBonusUI.luau | `panel` local (line 165) | Own ScreenGui, created in showCalendar() |

### Group 2: Medium-Tall Modals

| Modal | Size | File | Root Frame Variable |
|-------|------|------|---------------------|
| Summary | 400x600 | SummaryUI.luau | `self.mainFrame` |
| Match Lobby | 400x500 | MatchLobbyUI.luau | `self.container` |
| Race Results | 450x500 | RaceResultsUI.luau | `self.container` |

### Group 3: Medium Modals

| Modal | Size | File | Root Frame Variable |
|-------|------|------|---------------------|
| Stage Selection | 580x480 | StageSelectionUI.luau | `self.mainFrame` |
| Stage Countdown | 350x250 | StageSelectionUI.luau | `self.countdownFrame` |

### Group 4: Small Modals

| Modal | Size | File | Root Frame Variable |
|-------|------|------|---------------------|
| Settings | 360x380 | SettingsUI.luau | `self.container` |
| Feedback | 360x380 | FeedbackUI.luau | `self.container` |

### Group 5: External Popups (outside MainUI)

| Modal | Size | File | Notes |
|-------|------|------|-------|
| Update Log | 460x480 | init.client.luau | Created in `showUpdateLog()` function |
| Mastery Testing | 350x300 | MasteryTestingUI.luau | Debug only, low priority |
| Item Testing | 300x400 | ItemTestingUI.luau | Debug only, low priority |

### NOT Scaled (HUD elements, confirmed out of scope)

| Element | File | Why Skip |
|---------|------|----------|
| Score HUD | ScoreUI.luau | User confirmed fine |
| Currency HUD | CurrencyUI.luau | User confirmed fine |
| Item slots | ItemUI.luau | User confirmed fine |
| Menu grid | MenuGridUI.luau | User confirmed fine |
| Title HUD | TitleHUDUI.luau | Hidden, replaced by menu grid |
| Mobile buttons | MobileInputUI.luau | Touch-specific, not a modal |
| Spectate prompt | SpectatorUI.luau | Small bar, not a modal |

## Suggested Implementation Order

### Phase 1: Foundation (do first)

1. **Create ResponsiveScale.luau** in `src/shared/`
2. **Add `ResponsiveScale.init()` call** in `src/client/init.client.luau`
3. **Add size constants** to ThemeConfig.luau
4. **Test with ONE modal** (Settings or Feedback -- smallest, simplest)

**Rationale:** Settings/Feedback use UIFactory.createPanel already, making them the cleanest integration test. They are also the smallest modals so any scaling issues are easiest to debug.

### Phase 2: Large Modals (highest impact)

5. Apply to ShopUI (780x580) -- most-used panel, highest visibility
6. Apply to ClassSelectionUI (780x580)
7. Apply to TitleCollectionUI (780x580)
8. Apply to TutorialUI (780x580)
9. Apply to DailyBonusUI calendar (780x580) -- special case: own ScreenGui

**Rationale:** These five panels share the same 780x580 size, so verifying one verifies the formula for all. They are the panels most likely to overflow on mobile.

### Phase 3: Medium Modals

10. Apply to SummaryUI (400x600)
11. Apply to MatchLobbyUI (400x500)
12. Apply to RaceResultsUI (450x500)
13. Apply to StageSelectionUI (580x480)
14. Apply to StageSelectionUI countdown (350x250)

### Phase 4: External Popups

15. Apply to UpdateLog popup in init.client.luau (460x480)

### Phase 5: Polish and Edge Cases

16. Verify touch targets are still usable at minimum scale
17. Test DailyBonusUI calendar (separate ScreenGui path)
18. Test ScrollingFrame behavior inside scaled modals
19. Tune PADDING and MIN_SCALE constants based on real device testing

## Edge Cases and Special Considerations

### ScrollingFrame Inside Scaled Modals

ShopUI, ClassSelectionUI, and TutorialUI contain ScrollingFrame instances. UIScale should scale the ScrollingFrame's visible area proportionally. The `CanvasSize` and `AutomaticCanvasSize` properties should continue to work correctly because UIScale operates at the render level, not the layout level. **Verify this during implementation.**

### DailyBonusUI Own ScreenGui

DailyBonusUI creates its own ScreenGui with `DisplayOrder = 100`. The UIScale should be applied to the `panel` Frame inside this ScreenGui, not the ScreenGui itself. The scaling will work identically because UIScale operates on GuiObjects regardless of ScreenGui hierarchy.

### Tween Animations on Frame Size

StageSelectionUI line 679 sets `self.mainFrame.Size = UDim2.new(0, 580, 0, 480)` during show animations. UIScale is independent of the Size property -- it multiplies the rendered size. So tween animations on Size will work correctly; the tween target is the "design size" and UIScale multiplies the result.

### Deferred Signal Timing

With Roblox's deferred signal behavior (default), `GetPropertyChangedSignal("ViewportSize")` fires after the new ViewportSize is set. The new value should be available immediately in the handler. If timing issues occur on phone rotation, a one-frame delay (`task.defer` or `RunService.Heartbeat:Wait()`) can be added as a safety measure.

## Confidence Assessment

| Aspect | Confidence | Basis |
|--------|------------|-------|
| UIScale scales parent + all descendants | HIGH | Official Roblox creator docs (size-modifiers.md), multiple DevForum confirmations |
| UIScale works with UIStroke and UICorner | HIGH | Explicitly stated in official docs: "proportionally scales the object and all of its children, including any applied appearance modifiers like UIStroke or UICorner" |
| Camera.ViewportSize as viewport source | HIGH | Official API docs confirm it returns device safe area in UI offset units |
| GetPropertyChangedSignal for resize events | HIGH | Standard Roblox API, confirmed working in DevForum discussions |
| math.min(scaleX, scaleY) formula | HIGH | Standard responsive scaling approach, multiple community implementations confirm |
| ScrollingFrame behavior under UIScale | MEDIUM | Logical that it should work (UIScale is render-level), but not explicitly confirmed in docs. Verify during implementation. |
| MIN_SCALE of 0.45 being usable | LOW | Needs real device testing. Touch targets at 0.45x may be too small for buttons. May need per-modal minimum or minimum touch target enforcement. |

## Sources

- [Roblox Creator Docs: UIScale / Size Modifiers](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/size-modifiers.md) -- Confirms UIScale scales parent and all descendants including UIStroke/UICorner
- [Roblox API: Camera.ViewportSize](https://create.roblox.com/docs/reference/engine/classes/Camera/ViewportSize) -- ViewportSize returns device safe area in UI offset units
- [DevForum: Fixed Size GUI Scaling](https://devforum.roblox.com/t/how-do-i-scale-a-fixed-size-gui-to-fit-within-screenresolution/2521210) -- Community formula: smallest dimension / design dimension
- [DevForum: Scaler Module](https://devforum.roblox.com/t/scaler-using-uiscale-to-scale-your-ui/1105672) -- Community module using UIScale with Resolution attribute
- [DevForum: ViewportSize Signal Behavior](https://devforum.roblox.com/t/getpropertychangedsignalviewportsize-behaviour/3987385) -- Deferred signals fire after new value is set
- [DevForum: Comprehensive Scaling Guide](https://devforum.roblox.com/t/complete-comprehensive-roblox-ui-scaling-guide/2232510) -- General UI scaling best practices
- [DevForum: UIStroke Improvements](https://devforum.roblox.com/t/full-release-uistroke-improvements-scaling-offsets-and-more/3958036) -- Recent UIStroke updates (Sept-Dec 2025)

---

*Architecture analysis: 2026-03-21*
