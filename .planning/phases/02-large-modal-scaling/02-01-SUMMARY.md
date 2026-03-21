---
phase: 02-large-modal-scaling
plan: 01
subsystem: ui
tags: [luau, roblox, uiscale, uistroke, responsive, modal]

# Dependency graph
requires:
  - phase: 01-scaling-infrastructure-small-modals
    provides: "ResponsiveScale module with calculateScale, applyToFrame, _updateAll, init"
provides:
  - "ResponsiveScale.compensateStrokes helper for UIStroke thickness scaling"
  - "trackedStrokes storage and _updateAll integration for viewport change recalculation"
  - "TutorialUI responsive scaling at 780x580"
  - "DailyBonusUI responsive scaling at 780x580 with per-show application"
affects: [02-02-PLAN, 02-03-PLAN]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "compensateStrokes(frame, scale) for UIStroke thickness compensation under UIScale"
    - "Per-show scaling in dynamic modals (DailyBonusUI showCalendar pattern)"
    - "Idempotent stroke tracking — second call recalculates from stored originals"

key-files:
  created: []
  modified:
    - "src/shared/ResponsiveScale.luau"
    - "src/shared/__tests__/ResponsiveScale.spec.luau"
    - "src/client/UI/TutorialUI.luau"
    - "src/client/UI/DailyBonusUI.luau"

key-decisions:
  - "GetDescendants for recursive UIStroke discovery -- flat array, performant for 50-200 element UI hierarchies"
  - "Idempotent compensateStrokes -- second call on same frame recalculates from stored originals, prevents drift"
  - "DailyBonusUI scaling inside showCalendar after all children added, before animate-in tween"

patterns-established:
  - "compensateStrokes called after applyToFrame with uiScale.Scale parameter"
  - "Dynamic modals apply scaling per-show, orphan cleanup via _updateAll handles Destroy()"
  - "Design size constants (PANEL_W, PANEL_H) at top of each modal file"

requirements-completed: [MODAL-04, MODAL-05]

# Metrics
duration: 3min
completed: 2026-03-21
---

# Phase 2 Plan 1: Stroke Compensation + TutorialUI/DailyBonusUI Scaling Summary

**UIStroke thickness compensation helper with idempotent tracking, integrated into TutorialUI (static) and DailyBonusUI (per-show dynamic) at 780x580 design size**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-21T11:38:47Z
- **Completed:** 2026-03-21T11:41:28Z
- **Tasks:** 2 (Task 1 TDD with RED+GREEN commits)
- **Files modified:** 4

## Accomplishments
- Built compensateStrokes helper that recursively discovers UIStrokes via GetDescendants, stores original thicknesses, and adjusts proportionally with scale
- Idempotent design prevents drift on repeated calls -- second call recalculates from stored originals
- Updated _updateAll with stroke recalculation loop using UIScale.Scale from the frame, with orphan cleanup for destroyed frames
- TutorialUI scales in createUI constructor (static panel)
- DailyBonusUI scales inside showCalendar per-show (dynamic panel per D-07), with orphan cleanup on modalGui:Destroy()
- 4 unit tests written for compensateStrokes behavior (proportional reduction, identity at 1.0, floor at 0.5, idempotency)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add compensateStrokes to ResponsiveScale + unit tests** (TDD)
   - `9dfff42` (test: failing tests for compensateStrokes)
   - `d599202` (feat: compensateStrokes implementation + _updateAll integration)
2. **Task 2: Integrate scaling into TutorialUI and DailyBonusUI** - `e13fc9d` (feat)

## Files Created/Modified
- `src/shared/ResponsiveScale.luau` - Added trackedStrokes storage, compensateStrokes function, _updateAll stroke recalculation loop
- `src/shared/__tests__/ResponsiveScale.spec.luau` - Added 4 tests in describe("compensateStrokes") block
- `src/client/UI/TutorialUI.luau` - Added ResponsiveScale require, PANEL_W/H constants, applyToFrame + compensateStrokes in createUI
- `src/client/UI/DailyBonusUI.luau` - Added ResponsiveScale require, PANEL_W/H constants, applyToFrame + compensateStrokes in showCalendar

## Decisions Made
- Used GetDescendants for recursive UIStroke discovery (flat array, performant for UI hierarchies of 50-200 elements)
- Implemented idempotent tracking: second call to compensateStrokes on the same frame recalculates from stored originals instead of re-reading modified Thickness values
- DailyBonusUI scaling placed after all panel children are created (including action button) and before the animate-in tween, per D-07

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- compensateStrokes helper is ready for use by Plan 02-02 (TitleCollectionUI with ScrollingFrame) and Plan 02-03 (ShopUI + ClassSelectionUI)
- The established pattern (applyToFrame + compensateStrokes) is validated on both static (TutorialUI) and dynamic (DailyBonusUI) modal creation patterns
- ScrollingFrame CanvasSize fixes needed for remaining 3 modals are independent of this plan's work

## Self-Check: PASSED

All 5 files verified present. All 3 commits verified in git log.

---
*Phase: 02-large-modal-scaling*
*Completed: 2026-03-21*
