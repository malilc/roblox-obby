---
phase: 01-scaling-infrastructure-small-modals
plan: 02
subsystem: ui
tags: [luau, uiscale, responsive, viewport, small-modals, settings, feedback, spectator, leaderboard, uifactory]

# Dependency graph
requires:
  - phase: 01-scaling-infrastructure-small-modals
    plan: 01
    provides: "ResponsiveScale shared module (calculateScale, applyToFrame, init)"
provides:
  - "ResponsiveScale initialization in MainUI client startup"
  - "Responsive scaling on SettingsUI (360x380)"
  - "Responsive scaling on FeedbackUI (360x380)"
  - "Responsive scaling on SpectatorUI 3 sub-panels (prompt 280x50, rankings 200x300, controlBar 400x44)"
  - "LeaderboardUI stub with scaling placeholder comment"
  - "UIFactory.createModal auto-scaling with opt-out support"
affects: [02-large-modals, 03-medium-touch-polish]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Single applyToFrame call per modal container for opt-in scaling", "Design dimension constants (PANEL_W/PANEL_H) at module top level", "UIFactory.createModal auto-scaling with options.responsive opt-out"]

key-files:
  created: []
  modified:
    - src/client/UI/MainUI.luau
    - src/client/UI/SettingsUI.luau
    - src/client/UI/FeedbackUI.luau
    - src/client/UI/SpectatorUI.luau
    - src/client/UI/LeaderboardUI.luau
    - src/client/UI/UIFactory.luau

key-decisions:
  - "SpectatorUI scales 3 sub-panels independently rather than scaling a single parent -- each panel has its own design dimensions"
  - "UIFactory.createModal defaults to auto-scaling (opt-out via options.responsive == false) for future-proofing"

patterns-established:
  - "Per-modal opt-in: require ResponsiveScale + single applyToFrame(container, PANEL_W, PANEL_H) call after container creation"
  - "UIFactory auto-scaling: new modals created via createModal get scaling by default"

requirements-completed: [MODAL-10, MODAL-11, MODAL-12, MODAL-13]

# Metrics
duration: 3min
completed: 2026-03-21
---

# Phase 01 Plan 02: Small Modal Scaling Integration Summary

**ResponsiveScale integrated into SettingsUI, FeedbackUI, SpectatorUI (3 sub-panels), LeaderboardUI stub, and UIFactory.createModal with auto-scaling opt-out -- visually verified on mobile and desktop viewports**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-21T17:55:00Z
- **Completed:** 2026-03-21T18:10:00Z
- **Tasks:** 2 (1 auto + 1 human-verify checkpoint)
- **Files modified:** 6

## Accomplishments
- Initialized ResponsiveScale.init() in MainUI.new() before any UI component creation, ensuring viewport listener is active for all modals
- Applied responsive scaling to SettingsUI (360x380) and FeedbackUI (360x380) with single applyToFrame calls on their container frames
- Applied responsive scaling to SpectatorUI's 3 independent sub-panels: promptContainer (280x50), rankingsPanel (200x300), controlBar (400x44)
- Added future-proofing comment to LeaderboardUI stub with example code for when client-side UI is built
- Added auto-scaling to UIFactory.createModal with opt-out via `options.responsive == false` for future modals
- User visually verified: SettingsUI and FeedbackUI shrink correctly on mobile (414px viewport), display at full size on desktop, and rescale on viewport change

## Task Commits

Each task was committed atomically:

1. **Task 1: Initialize ResponsiveScale in MainUI and integrate into all 4 small modals + UIFactory** - `5e8b938` (feat)
2. **Task 2: Visual verification of scaling on mobile and desktop viewports** - checkpoint:human-verify (approved, no commit needed)

## Files Created/Modified
- `src/client/UI/MainUI.luau` - Added ResponsiveScale require and init() call in MainUI.new()
- `src/client/UI/SettingsUI.luau` - Added ResponsiveScale require and applyToFrame on container (360x380)
- `src/client/UI/FeedbackUI.luau` - Added ResponsiveScale require and applyToFrame on container (360x380)
- `src/client/UI/SpectatorUI.luau` - Added ResponsiveScale require, design dimension constants, and 3 applyToFrame calls for prompt/rankings/controlBar
- `src/client/UI/LeaderboardUI.luau` - Replaced minimal stub with documented stub including scaling placeholder comment
- `src/client/UI/UIFactory.luau` - Added ResponsiveScale require and auto-scaling in createModal with opt-out support

## Decisions Made
- SpectatorUI scales 3 sub-panels independently rather than scaling a single parent container, because the 3 panels have different design dimensions and positions (prompt at top-center, rankings at right, controlBar at bottom)
- UIFactory.createModal defaults to auto-scaling (opt-out via `options.responsive == false`) so future modals get scaling without explicit opt-in

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all scaling integrations are fully wired with real ResponsiveScale calls.

## Next Phase Readiness
- Phase 01 complete: ResponsiveScale infrastructure built (Plan 01) and validated on 4 small modals (Plan 02)
- Phase 02 can apply the same applyToFrame pattern to the 5 large modals (780x580)
- Phase 02 must address UIStroke thickness bug and ScrollingFrame CanvasSize bug documented in STATE.md blockers
- Phase 02 must handle DailyBonusUI's dynamic panel creation pattern (UIScale applied inside showCalendar, not constructor)

## Self-Check: PASSED

All files exist, all commits verified:
- FOUND: src/client/UI/MainUI.luau
- FOUND: src/client/UI/SettingsUI.luau
- FOUND: src/client/UI/FeedbackUI.luau
- FOUND: src/client/UI/SpectatorUI.luau
- FOUND: src/client/UI/LeaderboardUI.luau
- FOUND: src/client/UI/UIFactory.luau
- FOUND: 5e8b938 (Task 1 feat commit)

---
*Phase: 01-scaling-infrastructure-small-modals*
*Completed: 2026-03-21*
