---
phase: 04
plan: 02
one_liner: "Item slot dedup (hide ItemUI on mobile), visual verification with iterative fixes for coins/gems overlap, menu sizing, and IS_MOBILE race condition"
---

# Plan 04-02 Summary

## What was done
- ItemUI container hidden on mobile (MobileInputUI [1][2] buttons as primary)
- SlotLabel numbers hidden on mobile
- Multiple rounds of visual fixes:
  - Coins/Gems: UIScale 0.5 on mobile, positioned bottom-left above joystick
  - Menu grid: UIScale 0.55, center-left position on mobile
  - Item bar [1][2]: moved to center-bottom, ZIndex=0 behind modals
- Root cause fix: IS_MOBILE (TouchEnabled) unreliable at module load — switched to viewport-based detection + UIScale approach

## Key decisions
- UIScale approach for mobile HUD sizing (Size property changes don't persist reliably)
- ViewportSize.Y < 500 for mobile detection (TouchEnabled false at load time in Studio)
- task.defer insufficient — ViewportSize > 1 check needed

## Deviations
- Original plan used TouchEnabled — switched to viewport-based after discovering race condition
- Multiple iteration rounds needed to find working approach
