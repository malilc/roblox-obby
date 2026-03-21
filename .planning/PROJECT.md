# Responsive UI Overhaul

## What This Is

A viewport-aware UI system for the Roblox obby game. v1.0 scaled all 13 modals for mobile. v1.1 fixes HUD element overlaps and sizing issues on mobile screens — menu grid, item slots, rankings, and currency displays.

## Core Value

Every UI element must be fully visible, usable, and non-overlapping on both desktop and mobile phone screens.

## Current Milestone: v1.1 Mobile HUD Fix

**Goal:** Fix HUD element overlaps and sizing issues on mobile screens

**Target fixes:**
- Menu grid (left side) too large on mobile
- Item slots duplicated on mobile (not on desktop)
- Item bar not anchored to bottom edge
- Rankings panel overlapping item slots and jump button
- Coins/Gems bar overlapping walk/movement controls

## Requirements

### Validated

- [x] All 13 modals scale properly on mobile — v1.0
- [x] Scaling preserves existing layout — v1.0
- [x] Desktop experience unchanged — v1.0
- [x] Touch targets stay usable at scaled sizes — v1.0

### Active

- [ ] Menu grid scales down on mobile screens
- [ ] Item slots render only once on mobile (fix duplication)
- [ ] Item bar anchored to bottom edge of screen
- [ ] Rankings panel doesn't overlap other HUD elements
- [ ] Coins/Gems bar doesn't overlap movement controls

### Out of Scope

- Content reflow or mobile-specific layouts — scale down approach
- Tablet-specific tweaks — viewport formula handles naturally
- New UI features or visual redesign — purely fixing overlaps
- Leaderboard billboard sizing (3D world objects, not HUD)

## Context

- Roblox obby game with HUD elements managed by MainUI.luau and init.client.luau
- ResponsiveScale module available (from v1.0) for viewport-aware sizing
- HUD elements use fixed pixel positioning — works on desktop but overlaps on mobile
- Item slot duplication is mobile-only — likely a platform-specific rendering or creation issue
- Movement controls are Roblox default touch controls (joystick, jump button)

## Constraints

- **Tech stack**: Roblox Luau, all UI created via code
- **Approach**: Fix overlaps by repositioning/resizing — minimal layout changes
- **Compatibility**: Must work on both desktop and mobile without breaking existing HUD

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Scale down (not reflow) | Proven approach from v1.0 | ✓ Good |
| UIScale-based shrinking | Works for modals, may extend to HUD | ✓ Good |
| SummaryUI scrollable layout | Design too tall for mobile | ✓ Good |
| Tab indentation | Matches codebase practice | ✓ Good |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:**
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone:**
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-21 after v1.1 milestone started — Mobile HUD Fix*
