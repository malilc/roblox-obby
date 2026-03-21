# Responsive UI Overhaul

## What This Is

A viewport-aware scaling system for all modal/popup UI panels in the Roblox obby game. All 13 modals now scale properly on mobile phone screens using a centralized ResponsiveScale module with UIScale-based shrinking. Desktop experience remains unchanged.

## Core Value

Every modal must be fully visible and usable on both desktop and mobile phone screens — no content cut off, no overflow.

## Current State

**Shipped:** v1.0 (2026-03-21)
- 13 modals scaled across 3 phases (4 small, 5 large, 4 medium)
- ResponsiveScale shared module with calculateScale, applyToFrame, compensateStrokes
- UIStroke thickness compensation, ScrollingFrame CanvasSize fixes
- Touch target enforcement (44px+ at scaled sizes)
- Scale-in/out animation on show/hide
- Safe area compliance (CoreUISafeInsets explicit)
- SummaryUI refactored with scrollable content + footer layout

## Requirements

### Validated

- [x] Smaller modals (Settings, Feedback, Spectator, Leaderboard) scale properly — v1.0
- [x] Scaling preserves existing layout — no content reflow or rearrangement — v1.0
- [x] Desktop experience unchanged — modals stay at full design size — v1.0
- [x] All large modals (Shop, Class Selection, Title Collection, Tutorial, Daily Bonus) scale on mobile — v1.0
- [x] All medium modals (Stage Selection, Summary, Match Lobby, Race Results) scale on mobile — v1.0
- [x] Modals remain centered on screen after scaling — v1.0
- [x] Touch targets stay usable at scaled-down sizes — v1.0

### Active

None — all v1 requirements validated.

### Out of Scope

- HUD elements (currency, gems, score, menu grid, items) — user confirmed these are fine
- Content reflow or mobile-specific layouts — scale down approach chosen
- Tablet-specific tweaks — viewport formula handles tablets naturally
- Dynamic text size adjustment — v2 if needed (TEXT-01)
- Per-breakpoint layout adjustments — v2 if needed (LAYOUT-01)
- Landscape orientation enforcement — v2 if needed (ORIENT-01)

## Context

- Roblox obby game with 23 UI panels managed by MainUI.luau orchestrator
- All UI built programmatically in Luau (no Roblox Studio GUI editor)
- ResponsiveScale.luau in src/shared/ — centralized scale computation and UIScale management
- ThemeConfig.luau for styling, UIFactory.luau for panel creation (auto-scaling enabled)
- UIScale approach proven across all 13 modals with 8 unit tests

## Constraints

- **Tech stack**: Roblox Luau, all UI created via code (no .rbxm GUI files)
- **Approach**: UIScale-based shrinking — layout changes only where necessary (SummaryUI scroll)
- **Compatibility**: Works on both desktop and mobile (phone) Roblox clients

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Scale down (not reflow) | User wants same layout, just smaller on mobile | ✓ Good — worked for 12/13 modals |
| Fix all modals, not just large ones | Consistency across all popup panels | ✓ Good — 13 modals covered |
| Skip HUD fixes | User confirmed HUD elements are acceptable | ✓ Good — no complaints |
| UIStroke compensation | Strokes render disproportionately under UIScale | ✓ Good — compensateStrokes helper |
| Manual ScrollingFrame CanvasSize | AutomaticCanvasSize broken under UIScale | ✓ Good — static CanvasSize pattern |
| SummaryUI scrollable layout | 660px design too tall for landscape mobile | ✓ Good — scrollable content + footer |
| Tab indentation | Matches codebase practice over CLAUDE.md spec | ✓ Good — consistent with project |

---
*Last updated: 2026-03-21 after v1.0 milestone — all 13 modals responsive on mobile*
