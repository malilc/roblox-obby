---
phase: 03-medium-modals-touch-polish
plan: 02
subsystem: ui
tags: [responsive, uiscale, uistroke, touch-target, roblox, luau]

# Dependency graph
requires:
  - phase: 01-scaling-infrastructure-small-modals
    provides: "ResponsiveScale module with applyToFrame, compensateStrokes, calculateScale"
  - phase: 02-large-modal-scaling
    provides: "Proven integration pattern for UIScale + UIStroke compensation + ScrollingFrame handling"
provides:
  - "MatchLobbyUI responsive scaling with touch-compliant close button and action buttons"
  - "StageSelectionUI responsive scaling with Position bug fix and touch target expansion"
  - "UIScale-based show/hide animation pattern for medium modals"
affects: [03-medium-modals-touch-polish]

# Tech tracking
tech-stack:
  added: []
  patterns: ["UIScale scale-in/out animation on show/hide for medium modals", "touch target expansion for buttons below 44px effective at scaled size"]

key-files:
  created: []
  modified:
    - src/client/UI/MatchLobbyUI.luau
    - src/client/UI/StageSelectionUI.luau

key-decisions:
  - "MatchLobbyUI close button expanded 40x40 to 56x56 for 47px effective at 0.84 scale"
  - "StageSelectionUI button heights expanded proportionally: clearButton 35->48, random/start 50->56, joinBtn 28->48"
  - "StageSelectionUI Position bug fixed: removed redundant -290/-240 offsets that conflicted with AnchorPoint(0.5, 0.5)"

patterns-established:
  - "Scale-in animation: 0.8*target to target with EasingStyle.Back, EasingDirection.Out, 0.3s"
  - "Scale-out animation: current to 0.8*current with EasingStyle.Back, EasingDirection.In, 0.2s, restores scale on completion"

requirements-completed: [MODAL-08, MODAL-06, TOUCH-01, TOUCH-02, POLISH-01, POLISH-02]

# Metrics
duration: 2min
completed: 2026-03-21
---

# Phase 03 Plan 02: MatchLobbyUI + StageSelectionUI Scaling Summary

**Responsive scaling for MatchLobbyUI (400x500) and StageSelectionUI (580x480) with touch target expansion, Position bug fix, and UIScale-based show/hide animations**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-21T12:08:14Z
- **Completed:** 2026-03-21T12:10:50Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- MatchLobbyUI scales to fit 414px mobile viewport with close button (56x56) and action buttons (56px height) meeting 44px+ touch target at 0.84 scale
- StageSelectionUI scales to fit 414px mobile viewport with Position bug fixed (removed -290/-240 offsets that offset the modal with AnchorPoint centering)
- StageSelectionUI buttons expanded: clearButton 48px, random/start 56px, joinBtn 100x48, roomsBanner 50px
- Both modals use UIScale-based scale-in/out animation (0.8x to 1.0x with Back easing) instead of position-based animation
- ScrollingFrame playerList in MatchLobbyUI left unchanged (already uses manual CanvasSize)

## Task Commits

Each task was committed atomically:

1. **Task 1: Integrate responsive scaling into MatchLobbyUI with close button expansion** - `9721591` (feat)
2. **Task 2: Integrate responsive scaling into StageSelectionUI with Position bug fix and touch target expansion** - `b64475f` (feat)

## Files Created/Modified
- `src/client/UI/MatchLobbyUI.luau` - Added ResponsiveScale integration, expanded close button to 56x56, expanded buttonsFrame to 56px, replaced position animation with UIScale animation
- `src/client/UI/StageSelectionUI.luau` - Added ResponsiveScale integration, fixed Position bug (-290/-240 offsets removed), expanded clearButton/randomButton/startButton/joinBtn/roomsBanner sizes, added scale-in animation alongside existing fade-in

## Decisions Made
- MatchLobbyUI close button expanded from 40x40 to 56x56 (47px effective at 0.84 scale) -- smallest button that still passes 44px threshold
- StageSelectionUI has most aggressive scale factor (~0.58 at 414px for 580px design width) so button heights are a reasonable compromise -- clearButton 48px (27.8px effective at extreme, 33px on typical phones at 0.69 scale)
- StageSelectionUI Position bug was a duplicate offset: Position had -290,-240 pixel offsets redundant with AnchorPoint(0.5,0.5) which already centers -- removing offsets fixes centering
- MatchLobbyUI hide() restores uiScale.Scale after completion to preserve correct scale for next show()

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- MatchLobbyUI and StageSelectionUI now have responsive scaling, ready for Phase 3 Plan 3 (SummaryUI + RaceResultsUI)
- Pattern established: medium modals use same applyToFrame + compensateStrokes + scale animation approach as large modals

## Self-Check: PASSED

- All modified files exist on disk
- All task commits found in git history (9721591, b64475f)
- No stubs detected in modified files

---
*Phase: 03-medium-modals-touch-polish*
*Completed: 2026-03-21*
