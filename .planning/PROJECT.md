# Responsive UI Overhaul

## What This Is

A viewport-aware UI system for the Roblox obby game. All 13 modals and all HUD elements scale properly on mobile phone screens. Modals use UIScale-based shrinking, HUD elements use viewport-based UIScale with responsive positioning.

## Core Value

Every UI element must be fully visible, usable, and non-overlapping on both desktop and mobile phone screens.

## Current State

**Shipped:** v1.1 Mobile HUD Fix (2026-03-21)
- v1.0: 13 modals scaled for mobile (ResponsiveScale module)
- v1.1: HUD elements fixed for mobile (menu grid, item slots, rankings, coins/gems)

## Requirements

### Validated

- [x] All 13 modals scale properly on mobile — v1.0
- [x] Desktop experience unchanged — v1.0
- [x] Touch targets usable at scaled sizes — v1.0
- [x] Menu grid scales down on mobile — v1.1
- [x] Item slots no duplication on mobile — v1.1
- [x] Rankings panel no overlap — v1.1
- [x] Coins/Gems no overlap with joystick — v1.1
- [x] Desktop HUD unchanged — v1.1

### Active

None — all requirements validated.

### Out of Scope

- Content reflow or mobile-specific layouts
- Tablet-specific tweaks
- New UI features or visual redesign
- Leaderboard billboard sizing (3D world objects)
- Touch control customization (Roblox default)

## Context

- ResponsiveScale.luau for modals (UIScale + viewport listener)
- HUD elements use direct UIScale with ViewportSize.Y < 500 mobile detection
- TouchEnabled unreliable at module load time — use viewport-based detection
- UIScale approach proven across all UI elements

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| UIScale-based shrinking | Proven on modals, extended to HUD | ✓ Good |
| ViewportSize for mobile detection | TouchEnabled false at load time | ✓ Good |
| Rankings top-3 on mobile | Saves space, reduces overlap | ✓ Good |
| Hide ItemUI on mobile | MobileInputUI provides touch buttons | ✓ Good |
| UIScale instances (not Size changes) | Size property changes unreliable | ✓ Good |

---
*Last updated: 2026-03-21 after v1.1 milestone — Mobile HUD Fix shipped*
