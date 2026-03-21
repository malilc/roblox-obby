# Milestones

## v1.0 Responsive UI Overhaul (Shipped: 2026-03-21)

**Phases completed:** 3 phases, 8 plans, 15 tasks

**Key accomplishments:**

- TDD-built ResponsiveScale shared module with pure calculateScale function, UIScale management, and 8-test coverage for viewport-aware modal scaling
- ResponsiveScale integrated into SettingsUI, FeedbackUI, SpectatorUI (3 sub-panels), LeaderboardUI stub, and UIFactory.createModal with auto-scaling opt-out -- visually verified on mobile and desktop viewports
- UIStroke thickness compensation helper with idempotent tracking, integrated into TutorialUI (static) and DailyBonusUI (per-show dynamic) at 780x580 design size
- Responsive scaling for TitleCollectionUI and ClassSelectionUI with ScrollingFrame CanvasSize fixes -- AbsoluteContentSize division and AutomaticCanvasSize replacement patterns validated
- ShopUI responsive scaling with 3 ScrollingFrame static CanvasSize fixes, AbsoluteSize gacha animation compensation, and visual verification of all 5 large modals on mobile and desktop
- RaceResultsUI and SummaryUI scaled for mobile with UIScale-based show/hide animation, stroke compensation, and 44px+ touch targets
- Responsive scaling for MatchLobbyUI (400x500) and StageSelectionUI (580x480) with touch target expansion, Position bug fix, and UIScale-based show/hide animations
- Explicit ScreenInsets for safe area compliance, plus SummaryUI button enlargement fixing mobile tappability issue reported during verification

---
