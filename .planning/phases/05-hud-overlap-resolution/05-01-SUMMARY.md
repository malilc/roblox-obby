---
phase: 05
plan: 01
one_liner: "RaceRanking UIScale 0.5 + top-3 limit on mobile, SpectatorUI Rankings UIScale 0.55 + top-3, dynamic panel resize, no HUD overlaps"
---

# Plan 05-01 Summary

## What was done
- SpectatorUI RankingsPanel: UIScale 0.55 on mobile, top-3 limit, repositioned top-left
- RaceRanking (MatchLobbyUI): UIScale 0.5 on mobile, top-3 limit, dynamic panel height
- SpectatePrompt/ControlBar: UIScale 0.7 on mobile
- Viewport-based mobile detection (ViewportSize.Y > 1 AND < 500)
- Desktop: all elements unchanged (UIScale 1.0)

## Key decisions
- RaceRanking was the REAL rankings panel overlapping (not SpectatorUI RankingsPanel)
- Dynamic panel height: 35 + entries * 36 + 10 (shrinks to fit content)
- UIScale 0.5 matches Phase 4 pattern for consistency

## Deviations
- Original plan only addressed SpectatorUI — RaceRanking in MatchLobbyUI discovered during visual checkpoint
- Added dynamic panel resize to eliminate empty space
