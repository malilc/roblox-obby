# Phase 3: Medium Modals + Touch + Polish - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Apply ResponsiveScale to the 4 medium modals (StageSelectionUI 580x480, SummaryUI 400x600, MatchLobbyUI 400x500, RaceResultsUI 450x500), ensure touch targets remain usable at scaled sizes, verify safe area compliance, and add scale-in animation polish. Desktop experience must remain unchanged.

</domain>

<decisions>
## Implementation Decisions

### Modal Scaling (inherited from Phase 1-2)
- **D-01:** Same opt-in pattern: `ResponsiveScale.applyToFrame(frame, designW, designH)` per modal
- **D-02:** Each modal stores design size as local constants at top of file
- **D-03:** `compensateStrokes()` already available in ResponsiveScale — call after applyToFrame
- **D-04:** ScrollingFrames (MatchLobbyUI playerList, RaceResultsUI resultsFrame) use manual CanvasSize — no AutomaticCanvasSize under UIScale

### Claude's Discretion
- Touch target enforcement strategy (TOUCH-01, TOUCH-02): how to ensure 44px+ effective hit area on Close/Buy/Equip/Confirm buttons at scaled sizes — invisible hit area frames, minimum size overrides, or padding approach
- Safe area / notch handling (TOUCH-03): whether to use CoreUISafeInsets API, ScreenInsets, or hardcoded safe margins to prevent modal clipping behind notch/Dynamic Island
- Scale-in animation (POLISH-01): TweenService approach for 0.8→target scale on show — duration, easing style, whether to apply to all modals globally or Phase 3 modals only
- Centering verification (POLISH-02): how to confirm modals stay centered after scaling on all screen sizes
- Execution order of the 4 modals — which to tackle first based on complexity
- ScrollingFrame CanvasSize formulas for MatchLobbyUI and RaceResultsUI

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 1-2 Artifacts (foundation)
- `src/shared/ResponsiveScale.luau` — Module with applyToFrame, compensateStrokes, calculateScale helpers
- `.planning/phases/01-scaling-infrastructure-small-modals/01-CONTEXT.md` — Phase 1 decisions (scale formula, padding, integration pattern)
- `.planning/phases/02-large-modal-scaling/02-CONTEXT.md` — Phase 2 decisions (UIStroke compensation, ScrollingFrame strategy, dynamic creation)

### Target Modal Files
- `src/client/UI/StageSelectionUI.luau` (1083 lines) — 580x480, 1 UIStroke, no scroll, tab-based layout with stage selection/voting
- `src/client/UI/SummaryUI.luau` (1122 lines) — 400x600, 1 UIStroke, no scroll, end-game summary with medals/achievements
- `src/client/UI/MatchLobbyUI.luau` (973 lines) — 400x500, 1 UIStroke, 1 ScrollingFrame (playerList), matchmaking lobby with room list
- `src/client/UI/RaceResultsUI.luau` (450 lines) — 450x500, 2 UIStrokes, 1 ScrollingFrame (resultsFrame), race rankings with Continue button

### Existing Infrastructure
- `src/client/UI/MainUI.luau` — Orchestrator that creates all modal instances, ResponsiveScale.init() already called
- `src/shared/ThemeConfig.luau` — STROKE_MED, STROKE_BOLD constants used by target modals

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ResponsiveScale.applyToFrame()` — UIScale creation and tracking, proven on 9 modals (Phase 1-2)
- `ResponsiveScale.compensateStrokes()` — UIStroke thickness adjustment, proven on large modals (Phase 2)
- `ResponsiveScale._updateAll()` — Viewport change handler with orphan cleanup
- All 4 modals have show()/hide() methods — natural integration points

### Established Patterns
- Phase 1-2 integration: `require` ResponsiveScale, call `applyToFrame(frame, designW, designH)` in constructor
- Design size constants at top of file: `local PANEL_W = 580; local PANEL_H = 480`
- AnchorPoint(0.5, 0.5) + centered Position on all 4 modals — compatible with UIScale
- Close button pattern: 40x40 red X button in top-right (MatchLobbyUI)
- Action button pattern: 170x50 (StageSelectionUI), 180x44 (SummaryUI), 180x45 (RaceResultsUI)

### Integration Points
- Each modal's main frame → `applyToFrame()` call
- UIStroke instances → `compensateStrokes()` call
- ScrollingFrames in MatchLobbyUI/RaceResultsUI → manual CanvasSize after content population
- show() methods → scale-in animation hook point

### Complexity Ranking
1. RaceResultsUI (450 lines) — simplest, 1 scroll + Continue button
2. SummaryUI (1122 lines) — medium, no scroll but complex medal/achievement display
3. MatchLobbyUI (973 lines) — medium, 1 scroll + close button + room list
4. StageSelectionUI (1083 lines) — most complex, tabs + voting + countdown + multiple action buttons

</code_context>

<specifics>
## Specific Ideas

No specific requirements — user chose to let Claude decide all implementation approaches for touch targets, safe area handling, and animation polish.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 03-medium-modals-touch-polish*
*Context gathered: 2026-03-21*
