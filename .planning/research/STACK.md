# Technology Stack: Responsive UI Scaling

**Project:** Roblox Obby -- Modal Responsiveness Fix
**Researched:** 2026-03-21
**Research mode:** Ecosystem (Roblox UI scaling APIs)

## Recommended Stack

### Core Mechanism: UIScale Instance

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| `UIScale` | Engine built-in (stable) | Uniform scale multiplier on each modal frame | Scales the parent AND all descendants -- sizes, text, UICorner, UIStroke, padding -- in one shot. No need to touch individual child elements. |
| `Camera.ViewportSize` | Engine built-in (stable) | Read current screen dimensions (Vector2) | Returns device safe-area size in UI offset units. The denominator in the scale formula. |

**Confidence: HIGH** -- Official Roblox documentation confirms UIScale "proportionally scales the object and all of its children, including any applied appearance modifiers." This is the standard approach endorsed by the Roblox developer community for scaling fixed-pixel UIs across devices.

### The Formula

For each modal, compute a scale factor that shrinks the modal when the viewport is smaller than the design size, and caps at 1.0 so desktop stays unchanged:

```lua
local camera = workspace.CurrentCamera
local viewportSize = camera.ViewportSize  -- Vector2

local DESIGN_WIDTH = 780   -- e.g., ShopUI mainFrame width
local DESIGN_HEIGHT = 580  -- e.g., ShopUI mainFrame height
local PADDING = 40         -- breathing room (20px each side)

local scaleX = (viewportSize.X - PADDING) / DESIGN_WIDTH
local scaleY = (viewportSize.Y - PADDING) / DESIGN_HEIGHT
local scaleFactor = math.min(scaleX, scaleY, 1.0)  -- never exceed 1.0

uiScale.Scale = scaleFactor
```

**Why `math.min(scaleX, scaleY, 1.0)`:**
- `math.min(scaleX, scaleY)` picks the tighter constraint (width or height), ensuring the modal fits entirely within the viewport regardless of aspect ratio.
- The `, 1.0` cap ensures desktop modals stay at their current designed pixel size -- the project requirement says "desktop experience unchanged."

**Why subtract PADDING:**
- Prevents the modal from touching screen edges. On a 414px-wide phone, a 780px modal without padding would scale to `414/780 = 0.53x`. With 40px padding: `374/780 = 0.48x`, leaving 20px margin on each side.

### Viewport Change Detection

| Technology | Purpose | Why |
|------------|---------|-----|
| `Camera:GetPropertyChangedSignal("ViewportSize")` | React to screen size changes | Fires when viewport dimensions change (window resize, device rotation). Standard pattern; confirmed working with deferred signal behavior. |

**Confidence: MEDIUM** -- The signal works but has a known timing quirk: it can fire before UI layout has fully recalculated. The fix is trivial: add `task.wait()` after the signal fires to yield one frame before reading ViewportSize.

```lua
camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    task.wait()  -- yield one frame for layout to settle
    updateScale()
end)
```

### Supporting Instances

| Instance | Purpose | When to Use | Confidence |
|----------|---------|-------------|------------|
| `UISizeConstraint` | Set min/max pixel bounds | Use on modals that should never shrink below a readable minimum (e.g., MinSize = Vector2.new(280, 200)) | HIGH -- stable, well-documented |
| `UIAspectRatioConstraint` | Lock width:height ratio | NOT needed here -- modals keep their pixel sizes and UIScale handles uniform scaling | N/A |

**UISizeConstraint rationale:** Even with UIScale, you may want a floor. On extremely small screens, a 780px modal at 0.3x scale (234px) might have unreadably small text. A UISizeConstraint with MinSize prevents scaling below a usable threshold. However, since Roblox mobile viewport widths are typically 400-450px (not 234px), this is a safety net rather than a primary need.

### NOT Needed: ViewportDisplaySize API

| Technology | Status | Why NOT to use |
|------------|--------|----------------|
| `GuiService.ViewportDisplaySize` | Stable (released Oct 2025) | Categorizes screens into `Small`/`Medium`/`Large` buckets based on physical screen size. Too coarse for this project -- we need a continuous scale factor, not 3 buckets. Useful for layout switching (e.g., show sidebar on Large), but we are explicitly NOT doing layout changes. |

**Confidence: HIGH** -- Official release announcement confirms the 3-bucket design. Wrong tool for continuous scaling.

## How UIScale Interacts with Existing Code

### What UIScale Scales Automatically (No Code Changes Needed)

| Element | Behavior Under UIScale | Impact on This Codebase |
|---------|------------------------|------------------------|
| Frame sizes (`UDim2` offset) | Pixel values multiplied by Scale | All child frames shrink proportionally |
| TextLabel/TextButton text | Visually scaled (render-level) | Text stays proportional to its container -- no need to adjust TextSize values |
| `UICorner` radius | Scaled with parent | Rounded corners stay proportional |
| `UIStroke` thickness (FixedSize mode) | Scaled with parent | Existing strokes via `Theme.applyStroke()` scale correctly |
| `UIPadding` | Scaled with parent | Layout spacing stays proportional |
| `UIListLayout`/`UIGridLayout` | Cell sizes and padding scale | ScrollingFrame grids (ShopUI, TitleCollectionUI) scale correctly |
| Position (offset-based) | Scaled relative to parent | Child element positions stay correct within the modal |

**Confidence: HIGH** -- Official docs state UIScale scales "the object and all of its children, including any applied appearance modifiers." A 2020 regression where text stopped scaling was fixed within hours. No outstanding bugs for the FixedSize stroke mode.

### What Needs Manual Attention

| Element | Issue | Fix |
|---------|-------|-----|
| `ScrollingFrame.CanvasSize` | If set via AbsoluteContentSize listeners, may need re-evaluation after scale changes | Existing `GetPropertyChangedSignal("AbsoluteContentSize")` handlers in ShopUI/TitleCollectionUI should self-correct since AbsoluteContentSize updates with scale changes. Monitor during testing. |
| `UIStroke` with `StrokeSizingMode.ScaledSize` | Known bug (Dec 2025) where UIScale + ScaledSize interact incorrectly | NOT a concern -- this codebase uses pixel-based thickness (FixedSize mode) exclusively via `Theme.applyStroke()`. |
| Touch target sizes | Buttons may become too small to tap at low scale factors | Test on actual mobile device. Roblox minimum recommended touch target is ~44px. A 60px button at 0.5x = 30px, which is tight. PADDING in the formula helps, and UISizeConstraint is the backup. |

## Architecture: Where UIScale Lives

### Recommended: One UIScale Per Modal Frame

```
ScreenGui (ObbyGameUI)
  |-- ShopUI mainFrame (780x580, AnchorPoint 0.5,0.5, Position 0.5,0,0.5,0)
  |     |-- UIScale  <-- scale factor computed from viewport vs 780x580
  |     |-- ...all child content (tabs, cards, buttons)
  |
  |-- ClassSelectionUI mainFrame (780x580)
  |     |-- UIScale  <-- same computation
  |     |-- ...
  |
  |-- StageSelectionUI mainFrame (580x480)
  |     |-- UIScale  <-- different design size, same formula
  |     |-- ...
```

**Why per-modal, not per-ScreenGui:** Each modal has a different design size (780x580, 580x480, 400x600, etc.). A single UIScale on the ScreenGui would scale everything uniformly, but HUD elements are explicitly out of scope and should NOT be scaled. Per-modal UIScale gives precise control.

### Centralized Scale Computation Module

Create a shared `ResponsiveScale.luau` module (or add to ThemeConfig) that:
1. Reads `Camera.ViewportSize` once
2. Exports a function: `getScaleFactor(designWidth, designHeight, padding?) -> number`
3. Listens for ViewportSize changes and fires a signal so each UI can update its UIScale

This avoids 23 copies of the scale formula scattered across UI files.

## Installation

No packages to install. All APIs are built into the Roblox engine:

```lua
-- All you need:
local uiScale = Instance.new("UIScale")
uiScale.Scale = 1  -- default, overridden by responsive logic
uiScale.Parent = modalFrame

local camera = workspace.CurrentCamera
local viewportSize = camera.ViewportSize  -- Vector2
```

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| Scaling mechanism | `UIScale` on each modal | Convert all UDim2 offsets to Scale values | Massive rewrite of 23 UI files. UIScale achieves the same result with one Instance per modal and zero changes to existing layout code. |
| Scaling mechanism | `UIScale` on each modal | `UIAspectRatioConstraint` | Locks aspect ratio but does NOT scale content down. Would need to combine with Scale-based sizing, which again means rewriting all UDim2 values. |
| Viewport detection | `Camera.ViewportSize` | `GuiService.ViewportDisplaySize` | Only 3 buckets (Small/Medium/Large). Too coarse for continuous scaling. |
| Viewport detection | `Camera.ViewportSize` | `ScreenGui.AbsoluteSize` | Equivalent information but requires a reference to the ScreenGui. Camera is globally accessible via `workspace.CurrentCamera`. Both work; Camera.ViewportSize is the more common community pattern. |
| Scale application | Per-modal UIScale | Single UIScale on ScreenGui | Would scale HUD elements too (out of scope). No way to exempt specific children from UIScale. |
| Stroke scaling | Keep existing FixedSize mode | Switch to new ScaledSize mode | ScaledSize has a known UIScale interaction bug (Dec 2025). FixedSize mode scales correctly under UIScale. Don't fix what isn't broken. |

## Key Numbers for This Project

| Modal Category | Design Size | Example Modals | Scale at 414px wide phone (374px usable) |
|----------------|-------------|----------------|-------------------------------------------|
| Large | 780 x 580 | Shop, Class Selection, Title Collection, Tutorial, Daily Bonus | `min(374/780, 374/580, 1) = 0.48x` |
| Medium-tall | 400 x 600 | Summary | `min(374/400, 374/600, 1) = 0.62x` (height-constrained on landscape) |
| Medium-wide | 580 x 480 | Stage Selection | `min(374/580, 374/480, 1) = 0.64x` |
| Medium-square | ~400-450 x 500 | Match Lobby, Race Results | `min(374/450, 374/500, 1) = 0.75x` |
| Small | < 400 x 400 | Settings, Feedback, Spectator | Likely scale = 1.0 (already fits) |

The large 780x580 modals are the primary problem. At 0.48x, a 780px modal becomes ~374px wide -- exactly fitting the phone screen. Text at 18px becomes ~9px visually, which is small but readable for short labels. This validates the approach while flagging touch-target testing as important.

## Sources

- [Roblox UIScale API Reference](https://create.roblox.com/docs/reference/engine/classes/UIScale) -- Official documentation
- [Roblox Creator Docs: Size Modifiers](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/size-modifiers.md) -- Confirms UIScale scales children + appearance modifiers
- [Camera.ViewportSize API Reference](https://create.roblox.com/docs/reference/engine/classes/Camera/ViewportSize) -- Official documentation
- [UISizeConstraint API Reference](https://create.roblox.com/docs/reference/engine/classes/UISizeConstraint) -- Official documentation
- [ViewportDisplaySize Full Release](https://devforum.roblox.com/t/full-release-build-cross-platform-ui-with-the-viewportdisplaysize-api/3880384) -- Why 3-bucket API is wrong for this use case
- [UIStroke Improvements Full Release](https://devforum.roblox.com/t/full-release-uistroke-improvements-scaling-offsets-and-more/3958036) -- StrokeSizingMode details, ScaledSize bug
- [Fixed-size GUI scaling with UIScale](https://devforum.roblox.com/t/how-do-i-scale-a-fixed-size-gui-to-fit-within-screenresolution/2521210) -- Community pattern for viewport / design-size formula
- [Scaler: UIScale resource](https://devforum.roblox.com/t/scaler-using-uiscale-to-scale-your-ui/1105672) -- CollectionService + UIScale pattern
- [RobloxAutoUIScaler](https://github.com/enc0ded/RobloxAutoUIScaler) -- Reference implementation (ViewportWidth / ReferenceWidth formula)
- [ViewportSize GetPropertyChangedSignal behavior](https://devforum.roblox.com/t/getpropertychangedsignalviewportsize-behaviour/3987385) -- Timing quirk + task.wait() fix
- [UIScale text scaling bug (2020, fixed)](https://devforum.roblox.com/t/uiscale-no-longer-scales-text/644518) -- Confirms text scaling is intended behavior
