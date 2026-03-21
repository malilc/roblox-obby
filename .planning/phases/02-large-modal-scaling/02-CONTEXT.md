# Phase 2: Large Modal Scaling - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Apply ResponsiveScale to the 5 large modals (780x580): ShopUI, ClassSelectionUI, TitleCollectionUI, TutorialUI, DailyBonusUI. These are the most broken on mobile and carry the highest technical risk due to UIStroke, ScrollingFrame, and dynamic creation patterns. Desktop experience must remain unchanged.

</domain>

<decisions>
## Implementation Decisions

### UIStroke Compensation
- **D-01:** Compensate UIStroke thickness proportionally with scale factor — stroke.Thickness * scale so borders stay visually correct at smaller sizes
- **D-02:** Add `compensateStrokes(frame, scale)` helper in ResponsiveScale module — traverses children, adjusts all UIStroke instances automatically
- **D-03:** Helper must store original thickness values and update on viewport change (same lifecycle as UIScale tracking)

### ScrollingFrame Strategy
- **D-04:** Manual CanvasSize calculation — do NOT rely on AutomaticCanvasSize under UIScale (known Roblox bug)
- **D-05:** Calculate canvas from content count × item size, set CanvasSize explicitly
- **D-06:** Affected modals: ShopUI (3 ScrollingFrames), ClassSelectionUI (2), TitleCollectionUI (1)

### DailyBonusUI Dynamic Pattern
- **D-07:** Call applyToFrame() inside showCalendar() after frame creation — each time the modal opens, it gets fresh scaling
- **D-08:** ResponsiveScale's existing orphan cleanup (reverse iteration in _updateAll) handles stale entries when DailyBonusUI destroys its frame

### Integration Pattern (inherited from Phase 1)
- **D-09:** Same opt-in pattern: `ResponsiveScale.applyToFrame(frame, 780, 580)` per modal
- **D-10:** Each modal stores design size as local constants at top of file
- **D-11:** No changes to ResponsiveScale.init() or MainUI.luau initialization — already running from Phase 1

### Claude's Discretion
- How to traverse frame children for UIStroke (recursive vs flat, performance considerations)
- Whether stroke compensation needs debouncing on viewport change
- Exact manual CanvasSize formulas per ScrollingFrame (depends on grid layout vs list layout)
- Execution order of the 5 modals (which to tackle first)
- TutorialUI is simplest (no scroll, no dynamic) — may be good first target for validation

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 1 Artifacts (foundation)
- `src/shared/ResponsiveScale.luau` — The module to extend with compensateStrokes helper
- `.planning/phases/01-scaling-infrastructure-small-modals/01-CONTEXT.md` — Phase 1 decisions (D-01 through D-10)
- `.planning/phases/01-scaling-infrastructure-small-modals/01-01-SUMMARY.md` — How ResponsiveScale was built
- `.planning/phases/01-scaling-infrastructure-small-modals/01-02-SUMMARY.md` — How modal integration was done

### Target Modal Files
- `src/client/UI/ShopUI.luau` (1901 lines) — 3 ScrollingFrames, heavy UIStroke, dynamic content from remotes
- `src/client/UI/ClassSelectionUI.luau` (1752 lines) — 2 ScrollingFrames, heavy UIStroke, refresh on show
- `src/client/UI/TitleCollectionUI.luau` (1251 lines) — 1 ScrollingFrame, heavy UIStroke, tabs/filter
- `src/client/UI/TutorialUI.luau` (336 lines) — No scroll, few UIStrokes, static content
- `src/client/UI/DailyBonusUI.luau` (650 lines) — No scroll, UIStrokes, recreates UI on each show

### Known Pitfalls
- `.planning/research/PITFALLS.md` — UIStroke thickness bug details, ScrollingFrame interaction, GuiInset considerations

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ResponsiveScale.applyToFrame()` — Already handles UIScale creation and tracking (Phase 1)
- `ResponsiveScale._updateAll()` — Viewport change handler with orphan cleanup (Phase 1)
- `ResponsiveScale.calculateScale()` — Pure scale computation (Phase 1)

### Established Patterns
- Phase 1 integration: `require` ResponsiveScale → call `applyToFrame(frame, designW, designH)` in constructor or show method
- Design size constants at top of file: `local PANEL_W = 780; local PANEL_H = 580`
- All 5 modals use AnchorPoint(0.5, 0.5) + centered Position — compatible with UIScale

### Integration Points
- `ResponsiveScale.luau` needs new `compensateStrokes()` function + stroke tracking in `_updateAll()`
- Each modal's main frame → `applyToFrame()` call
- ScrollingFrame instances → manual CanvasSize after content population
- DailyBonusUI.showCalendar() → applyToFrame() after frame creation

### Complexity Ranking
1. TutorialUI (336 lines) — simplest, no scroll, static content
2. DailyBonusUI (650 lines) — dynamic creation but no scroll
3. TitleCollectionUI (1251 lines) — 1 ScrollingFrame
4. ClassSelectionUI (1752 lines) — 2 ScrollingFrames, refresh on show
5. ShopUI (1901 lines) — most complex, 3 ScrollingFrames, heavy dynamic content

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches within the decisions captured above.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-large-modal-scaling*
*Context gathered: 2026-03-21*
