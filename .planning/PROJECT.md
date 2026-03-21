# Responsive UI Overhaul

## What This Is

A focused fix to make all modal/popup UI panels in the Roblox obby game scale properly on mobile phone screens. The game has 23 UI panels with fixed pixel sizes (e.g., 780x580) that overflow and get cut off on small screens. This project adds viewport-aware scaling so modals shrink to fit any screen while keeping their existing layout intact.

## Core Value

Every modal must be fully visible and usable on both desktop and mobile phone screens — no content cut off, no overflow.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] All large modals (Shop, Class Selection, Title Collection, Tutorial, Daily Bonus — 780x580) scale down on mobile
- [ ] All medium modals (Stage Selection 580x480, Summary 400x600, Match Lobby 400x500, Race Results 450x500) scale down on mobile
- [ ] Smaller modals (Settings, Feedback, Spectator, Leaderboard) also scale properly
- [ ] Scaling preserves existing layout — no content reflow or rearrangement
- [ ] Modals remain centered on screen after scaling
- [ ] Touch targets stay usable at scaled-down sizes
- [ ] Desktop experience unchanged — modals stay at their current fixed sizes on large screens

### Out of Scope

- HUD elements (currency, gems, score, menu grid, items) — user confirmed these are fine
- Content reflow or mobile-specific layouts — just scale down, same layout
- Tablet-specific tweaks — desktop and mobile only
- New UI features or visual redesign — purely a responsiveness fix

## Context

- Roblox obby game with 23 UI panels managed by MainUI.luau orchestrator
- All UI built programmatically in Luau (no Roblox Studio GUI editor)
- Centralized theme system (ThemeConfig.luau) and factory pattern (UIFactory.luau)
- Modals use fixed pixel sizes via UDim2.new(0, px, 0, px) with AnchorPoint centering
- Best approach: UIScale instance on modal frames, calculated from viewport size vs design size
- MobileInputUI already detects mobile devices — platform detection exists

## Constraints

- **Tech stack**: Roblox Luau, all UI created via code (no .rbxm GUI files)
- **Approach**: UIScale-based shrinking only — no layout changes, no content reflow
- **Compatibility**: Must work on both desktop and mobile (phone) Roblox clients

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Scale down (not reflow) | User wants same layout, just smaller on mobile | — Pending |
| Fix all modals, not just large ones | Consistency across all popup panels | — Pending |
| Skip HUD fixes | User confirmed HUD elements are acceptable | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-21 after initialization*
