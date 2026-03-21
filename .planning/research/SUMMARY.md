# Project Research Summary

**Project:** Roblox Obby -- Modal Responsiveness Fix
**Domain:** Roblox UI scaling retrofit (offset-based modals, mobile phone target)
**Researched:** 2026-03-21
**Confidence:** HIGH

## Executive Summary

This project is a mobile responsiveness retrofit: 23 programmatic Luau UI panels using fixed pixel-offset sizes (UDim2 offsets) need to scale down gracefully on phone-sized viewports (~414px wide) without changing desktop appearance. The established Roblox pattern for this exact scenario is a `UIScale` instance parented to each modal's root frame. UIScale propagates a uniform multiplier to every descendant element -- sizes, text, UICorner, UIStroke, padding -- so a single instance per modal is sufficient. The scale factor is computed as `math.min(viewportW * 0.92 / designW, viewportH * 0.92 / designH, 1.0)` where 0.92 provides an 8% edge margin and the 1.0 cap preserves the desktop experience unchanged. This is a low-complexity, low-risk approach that requires zero changes to any existing UDim2 values.

The recommended architecture centralizes all scaling logic in a single `ResponsiveScale.luau` module in `src/shared/`. This module owns the scale formula, manages a table of tracked UIScale instances, and listens to a single `Camera:GetPropertyChangedSignal("ViewportSize")` connection. Individual UI modules call `ResponsiveScale.applyToFrame(frame, designWidth, designHeight)` once after creating their root frame. This avoids duplicating logic across 15+ files and provides one place to tune constants (MIN_SCALE, PADDING factor) based on real device testing.

The primary risks are not architectural -- they are implementation-level gotchas specific to the Roblox engine. Three issues require active handling and cannot be deferred: (1) UIStroke thickness does not scale proportionally under UIScale (engine bug, confirmed Dec 2025), requiring manual thickness adjustment per modal; (2) ScrollingFrame CanvasSize calculations using AbsoluteContentSize break under UIScale because AbsoluteSize reflects the scaled value; and (3) small touch targets (close buttons at 32x32px) become untappable at ~0.55x scale. The 5 large 780x580 modals (Shop, ClassSelection, TitleCollection, Tutorial, DailyBonus) are the highest-impact targets and the most technically risky due to combining scrolling content, heavy UIStroke use, and dynamic canvas sizing.

## Key Findings

### Recommended Stack

The entire solution uses built-in Roblox engine APIs -- no external packages required. `UIScale` is the sole scaling mechanism: it is the only Roblox API that scales a parent frame and all descendants (including appearance modifiers) via a single numeric property. `Camera.ViewportSize` is the correct viewport source, as it returns the device safe area in UI offset units and is globally accessible. `Camera:GetPropertyChangedSignal("ViewportSize")` enables reactive recalculation on orientation change. A one-frame `task.wait()` after this signal fires is a known timing workaround to avoid reading stale values.

**Core technologies:**
- `UIScale` (engine built-in) -- uniform visual scale multiplier; applied once per modal root frame; scales all descendants automatically
- `Camera.ViewportSize` (engine built-in) -- authoritative viewport dimensions; use over `ScreenGui.AbsoluteSize` for consistency
- `Camera:GetPropertyChangedSignal("ViewportSize")` -- reactive resize handling; one global connection batches all updates
- `UISizeConstraint` -- safety net for minimum readable size; secondary to code-side clamping since UIScale does not respect UISizeConstraint (engine bug)

**Critical version note:** `UIStroke.StrokeSizingMode.ScaledSize` introduced Dec 2025 has a known interaction bug with UIScale. This codebase uses `FixedSize` mode exclusively, which is correct -- do not migrate to ScaledSize.

### Expected Features

**Must have (table stakes):**
- Viewport-aware modal scaling -- 780px modals currently overflow on 414px phones; content is cut off and unusable
- Viewport change listener -- recalculates scale on device rotation or window resize
- Desktop experience unchanged -- scale clamped to max 1.0; zero visual change on desktop
- Per-modal scale awareness -- each of 23 modals carries its own design dimensions; a single global scale would over-shrink small modals and under-shrink large ones
- Minimum scale floor (0.45-0.55) -- prevents modals from shrinking to unreadable sizes
- Touch target validation -- close buttons (32x32px) and tab buttons (160x28px height) become untappable at 0.55x scale

**Should have (v1.x, add after core works):**
- Smooth scale transition on show/hide -- tween UIScale.Scale from 0.8 to target; codebase already uses tweens for overlay transparency
- Enlarged close button hit area on mobile -- transparent 60x60 hit area around 32px visual close button; detect via `UserInputService.TouchEnabled`
- ScreenInsets verification -- confirm `CoreUISafeInsets` is active on the MainUI ScreenGui

**Defer (v2+):**
- Dynamic text size adjustment -- fragile, high maintenance, only warranted if user feedback reports readability issues
- Per-breakpoint layout reflow -- massive scope increase (redesigning 23 panels); UIScale-only approach is the correct v1 answer
- Portrait mode support -- obby gameplay requires landscape; edge case not worth solving

### Architecture Approach

The architecture is a centralized hub-and-spoke model. A single `ResponsiveScale.luau` module in `src/shared/` owns all scale logic and is the only file that reads `Camera.ViewportSize` or touches UIScale instances. The 23 individual UI modules each call one function (`ResponsiveScale.applyToFrame`) after creating their root frame -- they have no other scaling responsibility. UIFactory is an integration point for new modals going forward, but since UIFactory.createModal is currently unused, the direct-call pattern is the practical approach. ThemeConfig receives a set of canonical design size constants (MODAL_LARGE, MODAL_MEDIUM, etc.) that serve as both documentation and scale formula inputs.

**Major components:**
1. `ResponsiveScale.luau` (new, `src/shared/`) -- calculates scale factors, manages UIScale instances, owns viewport listener, updates all tracked modals on resize
2. `UIFactory.luau` (existing, minor addition) -- gains a `ResponsiveScale.applyToFrame` call in `createModal` as an opt-out integration point for future panels
3. `ThemeConfig.luau` (existing, minor addition) -- gains `MODAL_LARGE`, `MODAL_MEDIUM_TALL`, `MODAL_MEDIUM`, `MODAL_RACE`, `MODAL_STAGE`, `MODAL_SMALL` size constants
4. Per-modal root frames (23 existing files, one-line addition each) -- call `ResponsiveScale.applyToFrame(self.rootFrame, designW, designH)` after frame creation
5. `init.client.luau` (existing, one-line addition) -- calls `ResponsiveScale.init()` once early in client startup

### Critical Pitfalls

1. **UIStroke thickness does not scale proportionally (confirmed engine bug)** -- UIScale visually multiplies UIStroke Thickness, but the rendering is disproportionate. This codebase has 88 UIStroke instances across 19 files. Fix: manually set `stroke.Thickness = originalThickness / uiScale.Scale` after applying UIScale, or test empirically. Must be addressed in the same phase as UIScale application.

2. **ScrollingFrame CanvasSize breaks under UIScale** -- AbsoluteContentSize is already scaled, but CanvasSize is interpreted in unscaled space. Setting `CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)` under UIScale produces incorrect scroll area. ClassSelectionUI's use of `AutomaticCanvasSize = Enum.AutomaticSize.Y` is a documented engine bug with UIScale. Fix: divide AbsoluteContentSize by UIScale.Scale before using; switch AutomaticCanvasSize panels to manual calculation.

3. **Touch targets become untappable at mobile scale** -- Close buttons (32x32px) at 0.55x become 18x18px, well below the 44px minimum. Tab height in StageSelectionUI (28px) becomes 15px. Fix: increase base close button size to at least 44x44 or add transparent hit-area overlay; on mobile only, via `UserInputService.TouchEnabled`.

4. **AbsoluteSize reads return scaled values** -- Code that reads `.AbsoluteSize` for layout calculations gets the UIScale-multiplied value. ShopUI lines 1460-1462 use `card.AbsoluteSize` for game pass card positioning. Fix: divide `.AbsoluteSize` results by `UIScale.Scale` before using for layout math.

5. **DailyBonusUI creates and destroys its panel dynamically** -- Unlike all other panels created once in constructors, DailyBonusUI.showCalendar() creates a fresh 780x580 panel each call. UIScale must be applied inside showCalendar() after panel creation, not in the module constructor.

## Implications for Roadmap

Based on research, a 5-phase structure is recommended, following the implementation order identified in ARCHITECTURE.md:

### Phase 1: Foundation Infrastructure
**Rationale:** Everything else depends on ResponsiveScale existing and being initialized. Build and validate the module on the simplest modals first to confirm the formula before applying to complex high-risk panels.
**Delivers:** `ResponsiveScale.luau` module, `init.client.luau` initialization, ThemeConfig size constants, and scaling validated on SettingsUI and FeedbackUI (the two smallest, simplest modals that use UIFactory.createPanel).
**Addresses:** Viewport-aware scaling, viewport change listener, desktop unchanged, per-modal scale awareness, minimum scale floor.
**Avoids:** Pitfall 5 (stale scale) by building the viewport listener into init; Pitfall 6 (GuiInset) by using the correct viewport formula from the start; Pitfall 9 (global scale) by establishing per-modal architecture.

### Phase 2: Large Modal Scaling (High Impact, High Risk)
**Rationale:** The 5 large 780x580 modals (Shop, ClassSelection, TitleCollection, Tutorial, DailyBonus) are the panels most broken on mobile and the most technically complex. They share the same design size so validating one validates the formula for all. They must be done as a group to catch UIStroke and ScrollingFrame issues before applying the same pattern to medium modals.
**Delivers:** All 5 large modals scaling correctly on phone; UIStroke thickness strategy confirmed and applied; ScrollingFrame CanvasSize fixes for Shop, ClassSelection, TitleCollection; DailyBonusUI dynamic creation pattern resolved.
**Avoids:** Pitfall 1 (UIStroke), Pitfall 2 (ScrollingFrame), Pitfall 8 (inconsistent panel structure), Pitfall 10 (DailyBonusUI dynamic creation).

### Phase 3: Medium Modal Scaling
**Rationale:** Medium modals (400-580px wide) are less critical on mobile since they partially fit on phone screens, but they still need scaling for optimal UX. Lower technical risk than large modals -- fewer ScrollingFrames, fewer UIStrokes.
**Delivers:** SummaryUI, MatchLobbyUI, RaceResultsUI, StageSelectionUI, and StageSelection countdown scaled correctly.
**Avoids:** Pitfall 4 (AbsoluteSize in SummaryUI dynamic height tween).

### Phase 4: External Popups and Edge Cases
**Rationale:** The UpdateLog popup in `init.client.luau` and any debug UI lives outside the MainUI system. These need individual handling and are lower priority since they are rarely visible.
**Delivers:** UpdateLog popup (460x480) scaled; MasteryTestingUI and ItemTestingUI noted as debug-only low priority.

### Phase 5: Touch Target and Polish Audit
**Rationale:** Touch target sizes can only be validated after scaling is active. This phase tests actual device usability and adds polish (close button hit areas, scale transition tweens, ScreenInsets verification).
**Delivers:** Close button hit areas enlarged on mobile; smooth scale-on-show tween added; real device testing sign-off; MIN_SCALE constant tuned based on empirical results.
**Addresses:** Touch target validation, smooth scale transition, enlarged close button hit area, ScreenInsets verification.
**Avoids:** Pitfall 3 (touch targets) and Pitfall 7 (text readability at min scale).

### Phase Ordering Rationale

- Phase 1 must precede everything -- the shared module and viewport listener are prerequisites for all subsequent phases.
- Phase 2 precedes Phase 3 because large modals carry the most risk (ScrollingFrames, UIStrokes, dynamic creation) and lessons learned there inform medium modal implementation.
- Phase 4 follows Phase 3 because external popups have no dependencies on the MainUI system and are lower priority.
- Phase 5 is last by design -- touch target sizes and text readability cannot be fully assessed until scale factors are known from real device testing. Polish tweens should only be added after confirming core scaling is correct.
- The 5 small modals (Settings 360x380, Feedback 360x380, MasteryTesting 350x300, StageCountdown 350x250) need minimal or no scaling on most phones, which is why they are used for Phase 1 validation rather than as their own phase.

### Research Flags

Phases with sufficient patterns (research-phase not needed):
- **Phase 1:** UIScale, Camera.ViewportSize, and GetPropertyChangedSignal are fully documented with official sources. Standard implementation.
- **Phase 3:** Medium modals follow identical patterns to large modals once established in Phase 2.
- **Phase 4:** Direct application of Phase 1 and 2 patterns to outlier files.

Phases that may benefit from targeted investigation:
- **Phase 2:** UIStroke thickness fix strategy needs empirical testing in Roblox Studio device emulator before committing to a formula. The `stroke.Thickness / uiScale.Scale` math is logical but the visual outcome should be confirmed before applying to all 88 UIStroke instances.
- **Phase 5:** MIN_SCALE floor value (currently proposed at 0.45) must be validated on a physical phone. The acceptable floor depends on actual rendered text size at that scale. This requires real device access, not emulator.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All APIs are official Roblox engine built-ins with documented behavior. UIScale scaling children including UIStroke/UICorner is explicitly stated in official docs. |
| Features | HIGH | Feature set derived from official cross-platform docs, verified codebase analysis, and real-world constraints. Prioritization is well-grounded. |
| Architecture | HIGH | Central module + per-modal UIScale is the standard community pattern for offset-based UI retrofits. Module design is straightforward and all integration points are verified in the codebase. |
| Pitfalls | HIGH | All 4 critical pitfalls are either confirmed engine bugs with DevForum documentation or directly verified in the codebase via code analysis (UIStroke count, ScrollingFrame usage, AbsoluteSize references, DailyBonus dynamic creation). |

**Overall confidence:** HIGH

### Gaps to Address

- **UIStroke thickness correction formula:** The exact formula to apply (`originalThickness / uiScale.Scale` or an empirically tuned value) needs in-Studio testing. The approach is clear; the exact coefficient may need adjustment per stroke category (STROKE_THIN vs STROKE_MED vs STROKE_BOLD). Address in Phase 2 before batch-applying.

- **MIN_SCALE floor value:** The proposed 0.45 floor is a starting estimate. The correct value depends on whether smallest text (8-11px base size) is readable at that scale on a physical phone. Address in Phase 5 with real device testing. May require bumping several small TextSize values from 8-10px to 12-14px baseline.

- **ScrollingFrame behavior with AutomaticCanvasSize:** ClassSelectionUI uses `AutomaticCanvasSize = Enum.AutomaticSize.Y`, which has a documented bug with UIScale. The exact fix (switch to manual CanvasSize calculation) is clear, but the implementation detail depends on how ClassSelectionUI populates its scroll content. Verify during Phase 2 implementation.

- **GuiInset exact value:** The Roblox top bar inset is documented as "historically 36px, now 58px on newer clients." The actual value affects the height dimension of the scale formula. Use `GuiService:GetGuiInset()` at runtime rather than hardcoding.

## Sources

### Primary (HIGH confidence)
- [Roblox UIScale API Reference](https://create.roblox.com/docs/reference/engine/classes/UIScale) -- UIScale behavior, children scaling
- [Roblox Creator Docs: Size Modifiers](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/size-modifiers.md) -- UIScale scales all descendants including UIStroke/UICorner
- [Camera.ViewportSize API Reference](https://create.roblox.com/docs/reference/engine/classes/Camera/ViewportSize) -- viewport dimensions in UI offset units
- [ScreenGui.ScreenInsets documentation](https://create.roblox.com/docs/reference/engine/classes/ScreenGui#ScreenInsets) -- GuiInset behavior with IgnoreGuiInset=false
- [Roblox Cross-Platform Design Guide](https://create.roblox.com/docs/ui/cross-platform-design) -- mobile thumb zones, touch target guidance
- [UIStroke Improvements Full Release (Dec 2025)](https://devforum.roblox.com/t/full-release-uistroke-improvements-scaling-offsets-and-more/3958036) -- StrokeSizingMode details, ScaledSize bug

### Secondary (MEDIUM confidence)
- [UIStroke incorrectly scaling under UIScale (DevForum, Dec 2025)](https://devforum.roblox.com/t/uiscale-incorrectly-scaling-uistroke-thickness/4157250) -- confirmed engine bug
- [AutomaticCanvasSize + UIScale bug (DevForum)](https://devforum.roblox.com/t/automaticcanvassize-working-with-uilistlayout-and-uiscale-causes-wrong-automatic-size/1334861) -- ScrollingFrame bug
- [UIScale does not change CanvasSize (DevForum)](https://devforum.roblox.com/t/uiscale-does-not-change-canvassize-of-scrollingframe/1644271) -- ScrollingFrame behavior
- [UIScale affects AbsoluteSize/Position (DevForum)](https://devforum.roblox.com/t/why-does-uiscale-affect-absolutesizeposition-like-this/2149310) -- AbsoluteSize returns scaled values
- [ViewportSize GetPropertyChangedSignal timing (DevForum)](https://devforum.roblox.com/t/getpropertychangedsignalviewportsize-behaviour/3987385) -- task.wait() fix
- [UIScale does not respect UISizeConstraint (DevForum, unfixed Nov 2025)](https://devforum.roblox.com/t/uiscale-does-not-respect-uisizeconstraint-properties/632943) -- must clamp in code
- [Scaler: UIScale community resource](https://devforum.roblox.com/t/scaler-using-uiscale-to-scale-your-ui/1105672) -- reference implementation pattern
- [RobloxAutoUIScaler (GitHub)](https://github.com/enc0ded/RobloxAutoUIScaler) -- ViewportWidth/ReferenceWidth formula confirmation

### Tertiary (LOW confidence)
- [WCAG 2.1 Touch Target Sizes](https://www.w3.org/WAI/WCAG21/Understanding/target-size.html) -- 44px minimum; applies directionally but Roblox mobile is not a web context

---
*Research completed: 2026-03-21*
*Ready for roadmap: yes*
