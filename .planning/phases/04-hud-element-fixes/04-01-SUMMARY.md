---
phase: 04-hud-element-fixes
plan: 01
subsystem: ui
tags: [roblox, luau, hud, mobile, responsive, touch]

# Dependency graph
requires:
  - phase: none
    provides: none
provides:
  - Mobile-scaled menu grid with 48x44px buttons (65% of desktop)
  - Bottom-anchored item bar at Y=-50 on all platforms
  - Platform-conditional positioning for Gems/Stage/Currency bars
affects: [04-02, phase-05]

# Tech tracking
tech-stack:
  added: []
  patterns: [IS_MOBILE constant from UserInputService.TouchEnabled, M_ prefixed mobile-aware layout constants]

key-files:
  created: []
  modified:
    - src/client/UI/MenuGridUI.luau
    - src/client/UI/ItemUI.luau
    - src/client/UI/ScoreUI.luau
    - src/client/UI/CurrencyUI.luau

key-decisions:
  - "Used 0.65x scale factor for mobile menu grid keeping 48x44px buttons above 44px tap target minimum"
  - "Moved Gems/Stage/Currency to top-left on mobile (Y=10/60/94) to clear walk joystick area"
  - "Item bar position Y=-50 applied uniformly on both platforms per D-05"

patterns-established:
  - "IS_MOBILE constant: local IS_MOBILE = UserInputService.TouchEnabled for platform detection"
  - "M_ prefix: mobile-aware layout constants that resolve to desktop values when IS_MOBILE is false"
  - "Conditional UDim2: if IS_MOBILE then mobilePos else desktopPos for platform-specific positioning"

requirements-completed: [MENU-01, MENU-02, ITEM-02]

# Metrics
duration: 3min
completed: 2026-03-21
---

# Phase 4 Plan 1: HUD Element Fixes Summary

**Mobile-scaled menu grid (65% with 48x44px buttons), bottom-anchored item bar, and top-left Gems/Coins/Stage bars on mobile using UserInputService.TouchEnabled detection**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-21T13:33:53Z
- **Completed:** 2026-03-21T13:36:54Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Menu grid renders at 65% size on touch devices (114x200 panel with 48x44 buttons) while remaining full size on desktop
- Item bar repositioned from 105px to 50px above bottom edge on all platforms for flush bottom anchoring
- Gems/Stage/Currency bars moved to top-left corner on mobile (Y=10/60/94) to avoid walk joystick overlap
- Desktop positions for all HUD elements remain exactly as before (no visual regression)

## Task Commits

Each task was committed atomically:

1. **Task 1: Scale menu grid on mobile and reposition item bar** - `43a05f9` (feat)
2. **Task 2: Move Coins/Gems/Stage bars to top-left on mobile** - `6bfad74` (feat)

## Files Created/Modified
- `src/client/UI/MenuGridUI.luau` - Added UserInputService import, IS_MOBILE detection, MOBILE_SCALE=0.65, M_ prefixed mobile-aware layout constants, updated panel/button sizes and hide/show animation targets
- `src/client/UI/ItemUI.luau` - Changed container position Y offset from -105 to -50 in createUI and both updateItems branches
- `src/client/UI/ScoreUI.luau` - Added UserInputService import, IS_MOBILE detection, conditional positioning for GemFrame (top-left on mobile) and StageFrame (below GemFrame on mobile)
- `src/client/UI/CurrencyUI.luau` - Added UserInputService import, IS_MOBILE detection, conditional positioning for CurrencyFrame (below StageFrame on mobile)

## Decisions Made
- Used 0.65x scale factor for mobile menu grid: produces 48x44px buttons that satisfy the 44px minimum tap target requirement while being visibly smaller than desktop's 74x68px buttons
- Positioned mobile HUD bars vertically stacked at top-left: GemFrame at Y=10, StageFrame at Y=60 (10+44+6gap), CurrencyFrame at Y=94 (60+28+6gap)
- Applied item bar Y=-50 position to both platforms per D-05 decision (same anchored position desktop and mobile)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all functionality is fully wired.

## Next Phase Readiness
- HUD element positions and sizes are now mobile-aware
- Phase 04 Plan 02 can address remaining HUD fixes (item slot duplication, rankings panel overlap)
- Phase 05 can handle cross-element overlap resolution with these baseline positions established

---
*Phase: 04-hud-element-fixes*
*Completed: 2026-03-21*
