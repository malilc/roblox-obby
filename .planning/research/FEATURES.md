# Feature Research

**Domain:** Roblox responsive UI / mobile modal scaling for obby game
**Researched:** 2026-03-21
**Confidence:** HIGH (Roblox official docs + developer community + codebase analysis)

## Feature Landscape

### Table Stakes (Users Expect These)

Features mobile players assume work. Missing these = game is broken on phone.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Viewport-aware modal scaling** | 780px-wide modals overflow on ~414px phone screens. Content is literally cut off and unusable. | LOW | UIScale on each modal frame. Formula: `min(1, viewportWidth * margin / designWidth, viewportHeight * margin / designHeight)`. Apply to the top-level panel frame. All children scale proportionally for free. |
| **Maintain aspect ratio on scale** | Scaled modals must not stretch or distort -- they should shrink uniformly. | LOW | UIScale handles this inherently -- it applies a uniform multiplier. No UIAspectRatioConstraint needed since we keep offset-based sizing and just scale the container. |
| **Modals stay centered after scaling** | If a modal shrinks but drifts off-center, buttons become unreachable. | LOW | Already handled -- all modals use `AnchorPoint = (0.5, 0.5)` with `Position = UDim2.new(0.5, 0, 0.5, 0)`. UIScale shrinks around the anchor point, so centering is preserved. |
| **Desktop experience unchanged** | Desktop players should see zero difference. Scale factor = 1.0 on screens larger than design size. | LOW | Clamp UIScale to `min(1.0, computed)`. Never upscale. |
| **Touch targets remain usable at scaled size** | Buttons that shrink below ~44px become untappable. Industry standard: 44x44px minimum (Apple HIG), 48x48dp (Material Design). | MEDIUM | Close buttons are 40x40px at design size. At worst-case scale (~0.53 for 780px modal on 414px screen), they become ~21px -- too small. Must validate minimum scale factor and consider enlarging close button hit areas on mobile. |
| **Viewport change listener** | Device orientation changes or Roblox UI resizes mid-session must re-trigger scale calculation. | LOW | Connect to `Camera:GetPropertyChangedSignal("ViewportSize")`. Already a standard Roblox pattern. |
| **No overlap with Roblox system controls** | Mobile has virtual thumbstick (bottom-left) and jump button (bottom-right). Modals must not place critical buttons behind these. | LOW | Currently not an issue -- modals are centered with overlay blocking input to controls behind. UIScale shrinking makes overlap less likely, not more. |

### Differentiators (Competitive Advantage)

Features that elevate the mobile experience above "it works" to "it feels good."

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Smooth scale transition on show/hide** | Modal appears with a tween from 0.8 to target scale, feels polished. Many Roblox games just pop modals in. | LOW | TweenService on UIScale.Scale property. The codebase already uses tweens for overlay transparency -- add scale tween to match. |
| **ScreenInsets-aware safe area** | iPhones with notch/Dynamic Island clip UI when ScreenGui uses `None` or `DeviceSafeInsets`. Using `CoreUISafeInsets` keeps modals clear of device cutouts AND Roblox top bar. | LOW | Set `screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets` (already the default). Verify the existing ScreenGui in MainUI.luau hasn't overridden this. If `IgnoreGuiInset = false` (current setting), safe area is already respected. |
| **Enlarged close button hit area on mobile** | 40px close button scaled to 0.53x = 21px tap target. Wrapping in a transparent 60x60 hit area frame solves this. | LOW | Create invisible TextButton parent larger than the visual close button. Only needed on touch devices (detect via `UserInputService.TouchEnabled`, which MobileInputUI already uses). |
| **Per-modal scale awareness** | Different modals have different design sizes (780x580 vs 360x380). Each should compute its own scale factor rather than one global scale. | LOW | Store design size per modal. Compute scale individually. Smaller modals (360px Settings) may not need scaling at all on many phones. |
| **Minimum scale floor** | Prevent modals from shrinking below usability threshold (e.g., scale floor of 0.5). Below this, text becomes unreadable. | LOW | Clamp scale: `max(0.5, computed_scale)`. At 0.5x on a 780px modal, effective size = 390px which fits a 414px screen with 12px margin per side. |
| **Dynamic text size adjustment** | At extreme scale-down, some text labels (especially 14px and below) become hard to read. Could bump text sizes on mobile. | HIGH | Requires iterating all TextLabel descendants and adjusting TextSize. Fragile and hard to maintain. Recommend NOT doing this for v1 -- UIScale + minimum floor handles it adequately. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems for this specific project scope.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| **Content reflow / mobile-specific layouts** | "Make it look native on mobile" -- rearrange grid columns, stack elements vertically. | Requires redesigning every modal (23 UI files). Massive scope increase with high regression risk. Project explicitly scopes this out. The codebase builds all UI programmatically in Luau, so layout changes mean rewriting creation code per-modal. | Scale-down preserves existing layouts. Same code path for all devices. |
| **Global UIScale on ScreenGui** | "Just scale everything at once" -- apply one UIScale to the root ScreenGui. | HUD elements (currency, score, menu grid) don't need scaling and would shrink unnecessarily. The user confirmed HUD is fine at current sizes. Global scale also affects MobileInputUI touch buttons which are already sized for mobile. | Per-modal UIScale instances. Only scale what overflows. |
| **UISizeConstraint for clamping** | "Add MaxSize to prevent overflow." | Known Roblox engine bug: UIScale does NOT respect UISizeConstraint MinSize/MaxSize (confirmed unfixed as of Nov 2025). Cannot combine these approaches reliably. | Use code-side clamping of the UIScale.Scale value instead. |
| **Scale-based (UDim2 scale) sizing instead of offset** | "Convert all sizes from pixels to percentages." | Requires rewriting every UDim2 in all 23 UI files. Scale-based sizing makes elements relative to parent, which changes behavior of nested elements unpredictably. A 780px modal's internal layout (headers, grids, buttons) all use coordinated pixel offsets. | Keep offset sizing. Apply UIScale to the top-level container only. All pixel offsets scale proportionally under UIScale. |
| **Orientation handling (portrait support)** | "Support portrait mode on phones." | Roblox mobile defaults to landscape on phones for games. Portrait mode dramatically changes aspect ratio (from ~16:9 to ~9:16), requiring completely different layouts. Obby gameplay requires landscape for adequate field of view. | Lock to landscape (default Roblox behavior for games). Design scaling for landscape phone viewports only. |
| **Tablet-specific optimizations** | "Tablets need different scaling." | Tablets have larger screens (768px+ width in landscape). Most modals at 780px nearly fit without scaling. The margin between "desktop" and "tablet" is small. | Treat tablet same as desktop -- modals display at design size or near it. The viewport-based scaling formula handles this naturally. |
| **Animated modal resize on orientation change** | "Smoothly resize when screen dimensions change." | Orientation changes are rare mid-gameplay (landscape lock). Over-engineering for an edge case. | Instant recalculation on ViewportSize change. No animation needed for resize events. |

## Feature Dependencies

```
[Viewport-aware modal scaling] (P1 - core feature)
    |
    |--requires--> [Viewport change listener] (must detect screen size)
    |--requires--> [Per-modal scale awareness] (each modal knows its design size)
    |--enhances--> [Minimum scale floor] (prevents over-shrinking)
    |--enhances--> [Smooth scale transition] (polish on show)
    |
    +--enables--> [Touch targets remain usable] (validates post-scale sizes)
                      |
                      +--enhances--> [Enlarged close button hit area] (fix for smallest modals)

[ScreenInsets-aware safe area] (independent, verify early)

[Desktop experience unchanged] (constraint, not dependency -- enforced by clamping scale to max 1.0)
```

### Dependency Notes

- **Modal scaling requires viewport listener:** Without detecting viewport size, there is no input to the scale formula.
- **Per-modal scale awareness enhances scaling:** Without it, a single global scale would over-shrink small modals and under-shrink large ones. A 360px Settings panel on a 414px screen only needs ~0.87 scale, while a 780px Shop needs ~0.53.
- **Touch target validation depends on scaling being implemented:** Can only test and validate touch sizes after scaling is active.
- **Enlarged close button is a refinement:** Only matters after scaling reveals that 40px buttons become too small. Can be added in same phase or deferred.

## MVP Definition

### Launch With (v1)

Minimum viable responsive UI -- every modal visible and usable on mobile phones.

- [x] **Viewport-aware modal scaling** -- core feature, makes modals fit on phone screens
- [x] **Viewport change listener** -- recalculates on screen size change
- [x] **Desktop experience unchanged** -- clamp scale to max 1.0
- [x] **Per-modal scale awareness** -- each modal carries its own design size
- [x] **Minimum scale floor** -- prevent shrinking below 0.5x
- [x] **Touch target validation** -- verify close/action buttons remain tappable

### Add After Validation (v1.x)

Features to add once core scaling is working and tested on real devices.

- [ ] **Smooth scale transition on show** -- tween UIScale for polished feel; add after confirming base scaling works
- [ ] **Enlarged close button hit area on mobile** -- if device testing reveals tap issues on close buttons
- [ ] **ScreenInsets verification** -- confirm CoreUISafeInsets is active; fix if not

### Future Consideration (v2+)

Features to defer until responsive modals are battle-tested.

- [ ] **Dynamic text size adjustment** -- only if user feedback indicates text readability problems at scale
- [ ] **Per-breakpoint layout adjustments** -- if specific modals (e.g., Shop with grid of items) prove unusable when simply scaled down
- [ ] **Landscape orientation lock enforcement** -- if players report portrait mode issues

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Viewport-aware modal scaling | HIGH | LOW | P1 |
| Viewport change listener | HIGH | LOW | P1 |
| Desktop unchanged (scale clamp) | HIGH | LOW | P1 |
| Per-modal scale awareness | HIGH | LOW | P1 |
| Minimum scale floor | MEDIUM | LOW | P1 |
| Touch target validation | HIGH | LOW | P1 |
| Smooth scale transition | MEDIUM | LOW | P2 |
| Enlarged close button hit area | MEDIUM | LOW | P2 |
| ScreenInsets verification | LOW | LOW | P2 |
| Dynamic text size adjustment | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch -- modals must be visible and usable on phone
- P2: Should have, add when possible -- polish and edge case handling
- P3: Nice to have, future consideration -- only if user feedback warrants it

## Competitor Feature Analysis

| Feature | Tower of Hell | Adopt Me | Brookhaven | Our Approach |
|---------|---------------|----------|------------|--------------|
| Modal scaling | Minimal UI; avoids large modals entirely. HUD-only design with tiny popup confirmations. | Uses Scale-based UDim2 for most elements. Modals sized as percentage of screen. | Similar to Adopt Me -- Scale-based sizing with minimal pixel offsets. | UIScale on offset-based modals. Preserves existing layout code while achieving same visual result as Scale-based approaches. |
| Touch targets | Large, thumb-friendly buttons. Minimal interactive elements on screen at once. | Oversized buttons with generous padding. Everything tappable is 60px+. | Large icons, minimal text buttons. | Validate post-scale button sizes. Enlarge close button hit areas where needed. |
| Mobile-first design | Yes -- designed for mobile from start. | Yes -- primary audience is mobile. | Yes -- mobile-dominant. | Retrofit -- adding mobile support to desktop-first design. UIScale approach is specifically good for retrofits. |
| Screen insets | Handled by Roblox defaults. | Uses CoreUISafeInsets. | Standard safe area handling. | Verify CoreUISafeInsets is active (likely already is via defaults). |

## Key Technical Context for This Codebase

**Why UIScale is the right approach here:**
1. All 23 UI panels use pixel-offset sizing (`UDim2.new(0, px, 0, px)`)
2. Modals are already centered with AnchorPoint (0.5, 0.5)
3. UIScale on a parent frame scales all children proportionally
4. No code changes needed inside individual modal files for basic scaling
5. The UIFactory.createModal pattern provides a natural injection point
6. MobileInputUI already has platform detection (`UserInputService.TouchEnabled`)

**Critical modal sizes to scale:**
| Category | Modals | Design Size (WxH) | Scale at 414px viewport |
|----------|--------|--------------------|------------------------|
| Large | Shop, ClassSelection, TitleCollection, Tutorial, DailyBonus | 780x580 | ~0.50 |
| Medium-tall | SummaryUI | 400x600 | ~0.98 (width OK, height may clip) |
| Medium | StageSelection | 580x480 | ~0.68 |
| Medium | RaceResults | 450x500 | ~0.87 |
| Medium | MatchLobby | 400x500 | ~0.98 |
| Small | Settings, Feedback | 360x380 | 1.0 (fits without scaling) |
| Small | MasteryTesting | 350x300 | 1.0 (fits without scaling) |
| Countdown | StageSelection countdown | 350x250 | 1.0 (fits without scaling) |

**Viewport height matters too:** Mobile landscape is roughly 414x736 (iPhone) or similar. A 600px-tall SummaryUI at full width scale still fits in 736px height. But with Roblox top bar inset (~36px), effective height is ~700px. All modals fit vertically on standard phones.

## Sources

- [Roblox Cross-Platform Design (Official)](https://create.roblox.com/docs/ui/cross-platform-design) -- mobile thumb zones, reserved control areas, context-based UI
- [Roblox ScreenInsets Enum (Official)](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets) -- CoreUISafeInsets vs DeviceSafeInsets vs None
- [Roblox Camera.ViewportSize (Official)](https://create.roblox.com/docs/reference/engine/classes/Camera/ViewportSize) -- returns device safe area in Roblox UI offset units
- [Roblox UI/UX Design Guide (Official)](https://create.roblox.com/docs/production/game-design/ui-ux-design) -- mobile-first design, contextual UI
- [Designing UI Tips and Best Practices (Roblox Staff)](https://devforum.roblox.com/t/designing-ui-tips-and-best-practices/3074034) -- Scale over Offset, safe areas, anchor points
- [Scaler - UIScale Community Resource](https://devforum.roblox.com/t/scaler-using-uiscale-to-scale-your-ui/1105672) -- UIScale-based scaling with reference resolution
- [RobloxAutoUIScaler (GitHub)](https://github.com/enc0ded/RobloxAutoUIScaler) -- scale formula: ViewportWidth / ReferenceWidth
- [UIScale does not respect UISizeConstraint (Bug)](https://devforum.roblox.com/t/uiscale-does-not-respect-uisizeconstraint-properties/632943) -- confirmed unfixed Nov 2025; must clamp in code
- [WCAG 2.1 Touch Target Sizes](https://www.w3.org/WAI/WCAG21/Understanding/target-size.html) -- 44x44px minimum for touch targets

---
*Feature research for: Roblox responsive UI / mobile modal scaling*
*Researched: 2026-03-21*
