# Domain Pitfalls: Roblox Responsive UI Scaling

**Domain:** UIScale-based responsive scaling for existing Roblox obby game
**Researched:** 2026-03-21
**Codebase:** 23 UI panels, all programmatic Luau, fixed pixel sizes (UDim2 offsets)

---

## Critical Pitfalls

Mistakes that cause visual breakage, broken interactions, or require significant rework.

### Pitfall 1: UIStroke Thickness Scales Disproportionately Under UIScale

**What goes wrong:** When a UIScale instance is applied to a parent frame, all UIStroke children have their Thickness visually multiplied by the scale factor -- but the rendering result is disproportionate. Strokes become visibly thicker or thinner than expected relative to the scaled content. At a UIScale of 0.6, a 2.5px stroke should render as 1.5px, but the actual rendered thickness can be inconsistent across devices.

**Why it happens:** UIScale was historically not designed to interact with UIStroke Thickness. Roblox released UIStroke improvements (December 2025) adding a ScaledSize mode, but the legacy Thickness behavior under UIScale remains buggy. The Roblox team acknowledged this in early 2026 as a known issue they are working on.

**Consequences:** On mobile (where UIScale < 1.0), strokes appear proportionally too thick relative to the scaled-down panel, making the UI look heavy and unpolished. This codebase has 88 UIStroke instances across 19 UI files -- every single panel is affected.

**This codebase specifically:** The ThemeConfig defines STROKE_THIN (1.5), STROKE_MED (2.5), and STROKE_BOLD (4). These absolute pixel values will not scale proportionally with UIScale. Panels like ShopUI (12 UIStrokes) and TitleCollectionUI (8 UIStrokes) are heavily affected.

**Prevention:**
- Do NOT rely on UIScale to automatically handle stroke thickness
- After applying UIScale, manually adjust UIStroke.Thickness values by dividing by the scale factor: `stroke.Thickness = originalThickness / uiScale.Scale` (or multiply, depending on the visual outcome -- test empirically)
- Alternatively, migrate UIStrokes to use the new `StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize` where Thickness acts as a percentage of the parent's shortest axis. This is a larger refactor but future-proof.
- Test strokes at both scale 1.0 (desktop) and scale ~0.55 (smallest mobile target) during implementation

**Detection:** Visually inspect modals in Roblox Studio using the device emulator at mobile resolutions. Strokes that look disproportionately thick compared to the content are the signal.

**Confidence:** HIGH -- documented Roblox engine bug with multiple DevForum reports ([UIScale incorrectly scaling UIStroke thickness](https://devforum.roblox.com/t/uiscale-incorrectly-scaling-uistroke-thickness/4157250), [UIStroke improvements release](https://devforum.roblox.com/t/full-release-uistroke-improvements-scaling-offsets-and-more/3958036))

**Phase impact:** Must be addressed in the same phase as UIScale application. Cannot be deferred.

---

### Pitfall 2: ScrollingFrame CanvasSize Breaks Under UIScale

**What goes wrong:** ScrollingFrame elements inside a UIScale-affected parent produce incorrect scrollable areas. When UIScale is applied, the CanvasSize (especially when calculated from UIListLayout.AbsoluteContentSize) gets naively multiplied by the scale factor, resulting in either too much or too little scrollable content. Users cannot scroll to the bottom of lists, or large empty space appears at the bottom.

**Why it happens:** AbsoluteContentSize reports values already affected by UIScale, but CanvasSize is interpreted in the unscaled coordinate space. Setting `CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)` after UIScale results in a canvas that is scale-factor-times too tall or too short.

**This codebase specifically:** 6 files use ScrollingFrame:
- ShopUI: 3 ScrollingFrames (items grid, classes content, game pass content) -- one uses AbsoluteContentSize for dynamic canvas sizing
- ClassSelectionUI: 2 ScrollingFrames -- one uses AutomaticCanvasSize = Enum.AutomaticSize.Y
- TitleCollectionUI: 1 ScrollingFrame with manual AbsoluteContentSize-based CanvasSize
- RaceResultsUI, MatchLobbyUI, ItemTestingUI: additional ScrollingFrames

The ClassSelectionUI use of `AutomaticCanvasSize = Enum.AutomaticSize.Y` is particularly risky -- this is a documented engine bug where AutomaticCanvasSize + UIScale produces wrong sizes.

**Prevention:**
- Place UIScale on the modal frame ABOVE the ScrollingFrame, not on or inside the ScrollingFrame itself
- For manually-set CanvasSize based on AbsoluteContentSize: divide AbsoluteContentSize.Y by UIScale.Scale before using it
- For AutomaticCanvasSize: test thoroughly -- if broken, switch to manual CanvasSize calculation
- Re-run any CanvasSize calculation after the UIScale value changes (e.g., on viewport resize)

**Detection:** Open each scrollable panel on mobile emulator. Scroll to the bottom. If content is cut off or there is excess empty space, the CanvasSize is wrong.

**Confidence:** HIGH -- multiple documented engine bugs ([AutomaticCanvasSize + UIScale bug](https://devforum.roblox.com/t/automaticcanvassize-working-with-uilistlayout-and-uiscale-causes-wrong-automatic-size/1334861), [UIScale does not change CanvasSize](https://devforum.roblox.com/t/uiscale-does-not-change-canvassize-of-scrollingframe/1644271))

**Phase impact:** Must be verified for every scrollable panel immediately after UIScale integration.

---

### Pitfall 3: Touch Targets Become Too Small on Mobile After Scaling

**What goes wrong:** Buttons that are comfortably tappable at their design size (e.g., 32x32 close buttons, 35px-tall action buttons) become physically too small to tap reliably on a phone after UIScale shrinks the modal to ~55-60% of its original size. A 32x32 close button becomes 18x18 physical pixels -- well below the ~44px minimum recommended touch target.

**Why it happens:** UIScale uniformly shrinks everything including interactive elements. The original UI was designed for desktop mouse cursors (pixel-precise), not for mobile finger taps (~44px minimum comfortable target). At 0.55x scale, any element originally smaller than 80px will fall below the 44px threshold.

**This codebase specifically:**
- Close buttons across all modals: 32x32px (scales to ~18x18 -- unusable)
- Tab buttons in StageSelectionUI: 160x28 (height scales to ~15px -- nearly impossible to tap)
- Toggle buttons in SettingsUI: 56x30 (scales to ~31x16 -- borderline)
- Category buttons in FeedbackUI: calculated at roughly 100x35 each
- Stage selection card buttons: 100x105 (these are fine)
- Daily bonus day cards: small cards with precision targets

**Prevention:**
- Audit all interactive elements at the minimum scale factor (use the smallest target mobile viewport)
- For elements that fall below ~44px effective size: increase their base size (in the original fixed layout) or add transparent hit-area padding via an invisible TextButton overlay that extends beyond the visual element
- Close buttons specifically: increase from 32x32 to at least 44x44 in the base design, or overlay a 44x44 invisible hit area
- Consider setting a minimum UIScale floor (e.g., 0.55) below which the UI simply does not shrink further -- it is better to have slight overflow than completely unusable buttons

**Detection:** Before shipping, tap every interactive element on an actual phone (not just emulator). The emulator does not reveal finger-size issues.

**Confidence:** HIGH -- this is a fundamental UX principle, not Roblox-specific. Apple HIG recommends 44pt minimum, Android recommends 48dp.

**Phase impact:** Address during implementation phase. Requires auditing all 23 panels for interactive element sizes.

---

### Pitfall 4: TweenHelper.pop() Breaks When UIScale Is Active

**What goes wrong:** The TweenHelper.pop() function captures `object.Size` as originalSize, scales it by a multiplier to create a tween target, then tweens back. Under UIScale, the visual size is already scaled, but the Size property is still in unscaled coordinates. The pop animation works correctly in unscaled space. HOWEVER, any code that dynamically reads or sets Size at runtime while UIScale is active risks confusion between "logical size" and "visual size."

**Why it happens:** UIScale does not modify the actual Size property -- it applies a visual transform. Code that reads `.Size` gets the unscaled value, but code that reads `.AbsoluteSize` gets the scaled value. If any animation or layout code mixes these two, positioning goes wrong.

**This codebase specifically:**
- TweenHelper.pop() reads `object.Size` and tweens Size -- this is safe because it operates in the same coordinate space
- MobileInputUI.luau tweens button Size on press (lines 143-154): `UDim2.new(0, 62, 0, 62)` to `UDim2.new(0, 70, 0, 70)` -- safe if MobileInputUI is NOT under UIScale (it should not be, as it is a HUD element)
- ShopUI.luau reads `card.AbsoluteSize.Y` and `card.AbsoluteSize.X` (line 1460-1462) for positioning -- this WILL break if a UIScale is on the ShopUI parent because AbsoluteSize reflects the scaled value
- SummaryUI dynamically tweens mainFrame Size when there is an upsell (line 717-726): `UDim2.new(0, 400, 0, panelHeight)` -- safe in Size space, but the visual result might look odd at different scales if the tween is not smooth

**Prevention:**
- Search for ALL uses of `.AbsoluteSize` and `.AbsolutePosition` in UI code and verify whether they need to be divided by the UIScale factor
- Do not place UIScale on HUD elements (MobileInputUI, ScoreUI, CurrencyUI, ItemUI) -- these are out of scope per PROJECT.md anyway
- For ShopUI's AbsoluteSize usage (game pass card positioning): divide by UIScale.Scale before using the value for calculations
- If any code dynamically sets `.Size` in pixel offsets, ensure it uses the unscaled coordinate space

**Detection:** Search codebase for `.AbsoluteSize` and `.AbsolutePosition` references. Each one is a potential breakage point under UIScale.

**Confidence:** HIGH -- verified in codebase grep. AbsoluteSize is used in ShopUI lines 1460-1462.

**Phase impact:** Must audit during implementation. The ShopUI.AbsoluteSize usage is a specific code fix needed.

---

## Moderate Pitfalls

### Pitfall 5: Viewport Resize Not Handled -- Scale Becomes Stale

**What goes wrong:** UIScale is calculated once at modal creation time based on the current viewport size, but the viewport can change (device rotation, Roblox window resize on desktop, split-screen on iPad). The modal remains at the stale scale factor, either too large or too small for the new viewport.

**Why it happens:** Developers calculate scale once and forget that `workspace.CurrentCamera.ViewportSize` can change at runtime. Roblox does not automatically re-trigger UIScale recalculation.

**Prevention:**
- Connect to `workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize")` to recalculate UIScale whenever the viewport changes
- Centralize the scale calculation in one place (e.g., a shared module or a function in UIFactory) so all panels update from the same signal
- Debounce the recalculation (viewport resize events can fire rapidly during window dragging)

**Detection:** Rotate a phone while a modal is open. If the modal does not resize to fit the new orientation, this pitfall is present.

**Confidence:** MEDIUM -- standard responsive design concern. Not Roblox-specific but easy to overlook.

**Phase impact:** Must be part of the core scaling infrastructure, not an afterthought.

---

### Pitfall 6: GuiInset Offset Not Accounted for in Viewport Calculation

**What goes wrong:** The viewport size from `workspace.CurrentCamera.ViewportSize` includes the full screen, but the ScreenGui's usable area is reduced by the Roblox top bar inset (historically 36px, now 58px on newer clients) and potentially device safe area insets (iPhone notch, Dynamic Island). The scaling calculation uses the full viewport height but the UI only has access to a smaller area, resulting in modals that are slightly too large for the actual available space.

**Why it happens:** The ScreenGui in this codebase has `IgnoreGuiInset = false` (line 60 of MainUI.luau), which means the content area starts below the top bar. But `ViewportSize` reports the full screen dimensions. The mismatch is ~36-58px in height.

**This codebase specifically:** With `IgnoreGuiInset = false`, the actual available height is `ViewportSize.Y - GuiInsetTop`. For a phone with viewport 375x667, the available height is roughly 667-58 = 609. A 580px-tall modal at scale 1.0 fits on desktop but needs the calculation to account for the reduced available height on mobile.

**Prevention:**
- Use `GuiService:GetGuiInset()` to get the actual top inset and subtract it from the available height before calculating scale
- Alternatively, use `screenGui.AbsoluteSize` instead of `ViewportSize` -- the ScreenGui's AbsoluteSize already accounts for GuiInset when IgnoreGuiInset is false
- Add a small margin (10-20px) beyond the inset calculation to prevent the modal from touching the screen edges

**Detection:** Test on iPhone with Dynamic Island or notch. If the top of the modal overlaps with or is obscured by the Roblox top bar, the inset was not accounted for.

**Confidence:** HIGH -- verified from codebase (IgnoreGuiInset = false) and Roblox documentation on [ScreenGui.ScreenInsets](https://create.roblox.com/docs/reference/engine/classes/ScreenGui#ScreenInsets).

**Phase impact:** Must be correct in the initial scale calculation formula.

---

### Pitfall 7: TextSize Does Not Scale with UIScale -- Text Overflows or Becomes Unreadable

**What goes wrong:** UIScale DOES visually scale text size along with everything else. However, hardcoded TextSize values interact with the visual scaling to produce text that may be too small to read on a physically small phone screen. A TextSize of 11 (used in StageSelectionUI for stage names) at UIScale 0.55 becomes effectively 6px -- completely unreadable.

**Why it happens:** The base design uses TextSize values ranging from 8 to 28 across the UI. While UIScale correctly shrinks the visual rendering, the resulting physical pixel size on a mobile screen can fall below legibility thresholds (~10-11px minimum for readability on mobile).

**This codebase specifically:** Found TextSize values as low as:
- 8px (StageSelectionUI badge) -> 4.4px at 0.55 scale
- 10px (StageSelectionUI coin label, ItemUI keybind hint) -> 5.5px at 0.55 scale
- 11px (StageSelectionUI name label, ItemUI slot label, icon text) -> 6px at 0.55 scale
- 12px (ItemUI tooltip rarity) -> 6.6px at 0.55 scale

**Prevention:**
- Set a minimum UIScale floor. Calculate the floor as: `minimumReadableSize / smallestTextSizeInUse`. If smallest text is 10px and minimum readable is 8px, floor is 0.8. If smallest text is 8px and minimum readable is 8px, floor is 1.0 (no scaling allowed).
- Practically: use a floor of ~0.55-0.6 and accept that the smallest text sizes (8-10px) need to be increased in the base design to at least 12-14px
- Alternatively, increase the small text sizes before applying UIScale so that at minimum scale they remain above 8px
- TextScaled is NOT a solution here -- it causes different problems (text filling containers, inconsistent sizes)

**Detection:** Check readability at minimum scale on a physical phone. If you cannot read stage names, coin labels, or badge text, the text is too small.

**Confidence:** HIGH -- arithmetic fact from codebase analysis.

**Phase impact:** Should be addressed before or alongside UIScale implementation. May require base text size increases.

---

### Pitfall 8: Panels Not Using UIFactory.createModal() Have Inconsistent Structure

**What goes wrong:** Not all panels use the UIFactory.createModal() pattern. Some create their own container directly (ShopUI, TutorialUI, DailyBonusUI, SummaryUI, StageSelectionUI, ClassSelectionUI all create raw Frames). This means the UIScale injection point differs per panel. If the scaling code assumes a uniform structure (e.g., "add UIScale to the panel child of the overlay"), it will miss panels that have their own structure.

**Why it happens:** The codebase evolved organically. UIFactory.createModal() was added as a helper, but the larger/complex panels predated it or needed custom structure.

**This codebase specifically:**
- UIFactory.createModal() returns (overlay, panel) -- UIScale would go on `panel`
- ShopUI creates `mainFrame` directly on screenGui
- TutorialUI creates `panel` directly on screenGui (no overlay)
- SummaryUI creates both `overlay` and `mainFrame` separately on screenGui
- ClassSelectionUI creates `container` directly
- DailyBonusUI creates `panel` directly during showCalendar (dynamic creation)
- SettingsUI and FeedbackUI use UIFactory.createPanel() (not createModal)

**Prevention:**
- Do NOT try to force a single injection pattern. Instead, identify the "root frame" for each modal individually
- Create a mapping of panel -> root frame to apply UIScale to
- Or, better: modify UIFactory to have a `createScaledModal()` / add a `UIFactory.applyScale(frame, designWidth, designHeight)` helper that any panel can call on its root frame
- The DailyBonusUI is special -- it creates and destroys its calendar panel dynamically. UIScale must be applied each time the panel is created.

**Detection:** If after implementation some panels scale and others do not, this inconsistency is the cause.

**Confidence:** HIGH -- verified from codebase analysis of all 23 UI files.

**Phase impact:** Must be mapped during planning. Each of the 23 panels needs its injection point documented.

---

## Minor Pitfalls

### Pitfall 9: Drop Shadows and Decorative Elements Scale Incorrectly

**What goes wrong:** ShopUI has a drop shadow frame (lines 137-145) with `Size = UDim2.new(1, 6, 1, 6)` and `Position = UDim2.new(0, -3, 0, 4)`. The pixel offsets (+6, -3, +4) will be scaled along with everything else under UIScale, making the shadow proportionally correct at any scale. This is actually fine. HOWEVER, if any decorative elements use absolute positioning relative to the ScreenGui (not relative to the modal), they will not scale and will appear misaligned.

**This codebase specifically:** The MainUI notification elements (TimeWarning, DeathNotification, InviteNotification) are created directly on screenGui with fixed pixel positions and are NOT modals. These should NOT be under UIScale -- but if someone accidentally adds UIScale at the ScreenGui level instead of per-modal, they break.

**Prevention:**
- Apply UIScale ONLY to individual modal root frames, never to the ScreenGui itself
- Verify that HUD elements (ScoreUI, CurrencyUI, ItemUI, MenuGridUI, MobileInputUI, TitleHUDUI) are not affected by UIScale
- Notification elements created by MainUI (TimeWarning, DeathNotification) must remain unscaled

**Detection:** Check that HUD elements and notifications appear at their original size after scaling changes.

**Confidence:** HIGH -- verified from codebase structure.

**Phase impact:** Architecture decision -- apply UIScale per-modal, not globally.

---

### Pitfall 10: DailyBonusUI Calendar Is Dynamically Created and Destroyed

**What goes wrong:** Unlike other panels that are created once in their constructor, DailyBonusUI:showCalendar() creates the calendar panel fresh each time and destroys it on hide. If UIScale logic runs only at panel construction time (e.g., in the module's .new() function), the daily bonus calendar will never receive scaling.

**This codebase specifically:** DailyBonusUI.luau line 165: `panel.Size = UDim2.new(0, 780, 0, 580)` is set inside showCalendar(), not in the constructor. The panel is parented to `self.parent` (the screenGui) each time.

**Prevention:**
- The UIScale application must happen inside `showCalendar()` after the panel is created, not in `DailyBonusUI.new()`
- Either: pass the current scale factor to showCalendar and apply it there
- Or: make the scale helper observable -- it reads the current viewport and applies scale at the time of frame creation

**Detection:** Open the daily bonus calendar on mobile. If it appears at full size (780x580) while other modals are scaled, this pitfall was hit.

**Confidence:** HIGH -- verified from codebase (DailyBonusUI creates/destroys panel dynamically).

**Phase impact:** Must handle during implementation. Easy to miss if treating all panels as "created once."

---

### Pitfall 11: Hardcoded Layout Math in ShopUI and DailyBonusUI

**What goes wrong:** Some panels compute layout positions based on hardcoded panel width. DailyBonusUI line 263: `local cardsStartX = (780 - (7 * cardW + 6 * cardSpacing)) / 2` and ShopUI line 345: `local tabWidth = math.floor((780 - 44 - 24) / 3)`. These calculations produce correct values at the original size and UIScale correctly shrinks the visual result. However, if anyone later tries to change the approach to "use smaller base sizes on mobile instead of UIScale," these hardcoded values become the problem.

**This is NOT a problem for the UIScale approach** because UIScale operates as a visual transform and does not change the logical coordinate space. The math remains valid.

**Prevention:**
- Stick with the UIScale approach (visual transform). Do not mix approaches (e.g., do not also change the base Size to smaller values on mobile)
- If these constants are ever refactored, extract them to the top of each file (some already are -- PANEL_W, PANEL_H in SettingsUI and FeedbackUI)

**Detection:** If the approach changes from UIScale to "rebuild with smaller sizes," these hardcoded values will need to be parameterized.

**Confidence:** HIGH -- verified from codebase, but risk is LOW with the UIScale-only approach.

**Phase impact:** No action needed unless approach changes.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Core scaling infrastructure | Pitfall 6 (GuiInset not accounted for) | Use screenGui.AbsoluteSize or subtract GuiInset from ViewportSize |
| Core scaling infrastructure | Pitfall 5 (Stale scale on resize) | Connect to ViewportSize changed signal from the start |
| Core scaling infrastructure | Pitfall 9 (Global vs per-modal scale) | Apply UIScale per-modal root frame, never on ScreenGui |
| Large modal scaling (780x580) | Pitfall 1 (UIStroke thickness) | Manually adjust stroke thickness or migrate to ScaledSize mode |
| Large modal scaling (780x580) | Pitfall 2 (ScrollingFrame CanvasSize) | Test every scrollable panel; fix AbsoluteContentSize-based calculations |
| Large modal scaling (780x580) | Pitfall 8 (Inconsistent panel structure) | Map each panel's root frame before batch-applying |
| Touch target audit | Pitfall 3 (Buttons too small) | Increase base sizes of close buttons and small interactive elements |
| Text readability audit | Pitfall 7 (Text too small) | Set minimum scale floor; increase base TextSize for smallest text |
| Dynamic panels | Pitfall 10 (DailyBonusUI calendar) | Apply UIScale inside showCalendar(), not in constructor |
| Position/size calculations | Pitfall 4 (AbsoluteSize under UIScale) | Audit and fix ShopUI's AbsoluteSize usage |

---

## Summary of Codebase-Specific Risk Areas

| UI File | Panel Size | ScrollingFrame? | UIStroke Count | Risk Level |
|---------|-----------|-----------------|----------------|------------|
| ShopUI | 780x580 | 3 (one dynamic canvas) | 12 | HIGH |
| ClassSelectionUI | 780x580 | 2 (one AutomaticCanvas) | 7 | HIGH |
| TitleCollectionUI | 780x580 | 1 (dynamic canvas) | 8 | HIGH |
| DailyBonusUI | 780x580 | 0 | 5 | MEDIUM (dynamic creation) |
| TutorialUI | 780x580 | 0 | 4 | LOW |
| SummaryUI | 400x600 | 0 | 3 | LOW (dynamic size change) |
| StageSelectionUI | 580x480 | 0 | 8 | MEDIUM |
| MatchLobbyUI | 400x500 | 0 | 8 | LOW |
| RaceResultsUI | 450x500 | 1 | 4 | MEDIUM |
| SettingsUI | 360x380 | 0 | 0 (via UIFactory) | LOW |
| FeedbackUI | 360x380 | 0 | 0 (via UIFactory) | LOW |
| SpectatorUI | various | 0 | 4 | LOW |
| LeaderboardUI | unknown | 0 | unknown | LOW |

## Sources

- [UIScale incorrectly scaling UIStroke thickness (DevForum, Dec 2025)](https://devforum.roblox.com/t/uiscale-incorrectly-scaling-uistroke-thickness/4157250)
- [UIStroke Improvements: Full Release (DevForum, Dec 2025)](https://devforum.roblox.com/t/full-release-uistroke-improvements-scaling-offsets-and-more/3958036)
- [AutomaticCanvasSize + UIListLayout + UIScale bug (DevForum)](https://devforum.roblox.com/t/automaticcanvassize-working-with-uilistlayout-and-uiscale-causes-wrong-automatic-size/1334861)
- [UIScale does not change CanvasSize of ScrollingFrame (DevForum)](https://devforum.roblox.com/t/uiscale-does-not-change-canvassize-of-scrollingframe/1644271)
- [UIScale affects AbsoluteSize/Position (DevForum)](https://devforum.roblox.com/t/why-does-uiscale-affect-absolutesizeposition-like-this/2149310)
- [Offset-Based GUI Positioning Bug with UIScale (DevForum, Apr 2025)](https://devforum.roblox.com/t/offset-based-gui-positioning-bug-with-uiscale-in-roblox-studio/3624878)
- [UIScale official documentation (Roblox)](https://create.roblox.com/docs/reference/engine/classes/UIScale)
- [ScreenGui.ScreenInsets documentation (Roblox)](https://create.roblox.com/docs/reference/engine/classes/ScreenGui#ScreenInsets)
- [Complete Roblox UI Scaling Guide (DevForum)](https://devforum.roblox.com/t/complete-comprehensive-roblox-ui-scaling-guide/2232510)
- [How to scale and position UI the correct way (DevForum)](https://devforum.roblox.com/t/how-to-scale-and-position-ui-the-correct-way/2020120)
