# Roadmap: Responsive UI Overhaul

## Overview

This project retrofits viewport-aware scaling onto 23 fixed-size modal panels in a Roblox obby game. The approach is UIScale-based: a centralized ResponsiveScale module computes a per-modal scale factor from viewport size vs design size, and individual modals opt in with a single function call. Phase 1 builds the infrastructure and validates on the simplest modals. Phase 2 tackles the 5 large (780x580) modals that are most broken on mobile and carry the highest technical risk (UIStroke, ScrollingFrame, dynamic creation). Phase 3 applies scaling to the 4 medium modals and adds touch target and polish work that can only be validated once scaling is active.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Scaling Infrastructure + Small Modals** - Build ResponsiveScale module, add ThemeConfig constants, validate on 4 small modals
- [ ] **Phase 2: Large Modal Scaling** - Apply scaling to the 5 large 780x580 modals, resolve UIStroke and ScrollingFrame pitfalls
- [ ] **Phase 3: Medium Modals + Touch + Polish** - Scale 4 medium modals, validate touch targets, add scale animation and safe area checks

## Phase Details

### Phase 1: Scaling Infrastructure + Small Modals
**Goal**: A working, tested scaling system exists and is proven on the simplest modals
**Depends on**: Nothing (first phase)
**Requirements**: SCALE-01, SCALE-02, SCALE-03, SCALE-04, SCALE-05, MODAL-10, MODAL-11, MODAL-12, MODAL-13
**Success Criteria** (what must be TRUE):
  1. ResponsiveScale module exists in src/shared/ and is initialized on client startup
  2. SettingsUI, FeedbackUI, SpectatorUI, and LeaderboardUI shrink to fit on a 414px-wide phone viewport in Studio device emulator
  3. The same 4 modals display at their original fixed size on a desktop-sized viewport (no visual change)
  4. Resizing the viewport (e.g., toggling device emulator) causes modals to recalculate and rescale without a reload
**Plans**: 2 plans

Plans:
- [ ] 01-01-PLAN.md -- Build ResponsiveScale module with TDD (calculateScale pure function + UIScale management)
- [ ] 01-02-PLAN.md -- Integrate scaling into 4 small modals + UIFactory.createModal + visual verification

### Phase 2: Large Modal Scaling
**Goal**: The 5 most broken modals (Shop, ClassSelection, TitleCollection, Tutorial, DailyBonus) are fully visible and usable on mobile
**Depends on**: Phase 1
**Requirements**: MODAL-01, MODAL-02, MODAL-03, MODAL-04, MODAL-05
**Success Criteria** (what must be TRUE):
  1. All 5 large modals (780x580) fit entirely within a 414px-wide phone viewport with no content cut off
  2. ScrollingFrames inside Shop and ClassSelection scroll correctly at scaled sizes (no broken canvas, no content clipping)
  3. UIStroke borders render at visually correct thickness at scaled sizes (no disproportionate thickening)
  4. DailyBonusUI scales correctly despite its dynamic panel creation pattern (panel created on each show, not once in constructor)
  5. All 5 modals remain at original fixed size on desktop viewport
**Plans**: TBD

Plans:
- [ ] 02-01: TBD
- [ ] 02-02: TBD

### Phase 3: Medium Modals + Touch + Polish
**Goal**: All remaining modals scale correctly, touch targets are usable at scaled sizes, and modals animate smoothly on show
**Depends on**: Phase 2
**Requirements**: MODAL-06, MODAL-07, MODAL-08, MODAL-09, TOUCH-01, TOUCH-02, TOUCH-03, POLISH-01, POLISH-02
**Success Criteria** (what must be TRUE):
  1. StageSelectionUI, SummaryUI, MatchLobbyUI, and RaceResultsUI fit within a 414px-wide phone viewport with no content cut off
  2. Close buttons and action buttons (buy, equip, confirm) are tappable on mobile at scaled sizes (44px+ effective hit area)
  3. Modals do not clip behind notch or Dynamic Island (ScreenInsets/CoreUISafeInsets verified)
  4. Modals animate from 0.8 to target scale on show (smooth tween, not instant pop-in)
  5. All modals remain centered on screen after scaling on all screen sizes
**Plans**: TBD

Plans:
- [ ] 03-01: TBD
- [ ] 03-02: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Scaling Infrastructure + Small Modals | 0/2 | Not started | - |
| 2. Large Modal Scaling | 0/TBD | Not started | - |
| 3. Medium Modals + Touch + Polish | 0/TBD | Not started | - |
