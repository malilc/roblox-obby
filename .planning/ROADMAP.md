# Roadmap: Responsive UI Overhaul

## Milestones

- **v1.0 Modal Scaling** - Phases 1-3 (shipped)
- **v1.1 Mobile HUD Fix** - Phases 4-5 (in progress)

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

<details>
<summary>v1.0 Modal Scaling (Phases 1-3) - SHIPPED</summary>

- [x] **Phase 1: Scaling Infrastructure + Small Modals** - Build ResponsiveScale module, add ThemeConfig constants, validate on 4 small modals
- [x] **Phase 2: Large Modal Scaling** - Apply scaling to the 5 large 780x580 modals, resolve UIStroke and ScrollingFrame pitfalls
- [x] **Phase 3: Medium Modals + Touch + Polish** - Scale 4 medium modals, validate touch targets, add scale animation and safe area checks

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
- [x] 01-01: Build ResponsiveScale module with TDD (calculateScale pure function + UIScale management)
- [x] 01-02: Integrate scaling into 4 small modals + UIFactory.createModal + visual verification

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
**Plans**: 2 plans

Plans:
- [x] 02-01: TBD
- [x] 02-02: TBD

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
**Plans**: 2 plans

Plans:
- [x] 03-01: TBD
- [x] 03-02: TBD

</details>

### v1.1 Mobile HUD Fix

**Milestone Goal:** Fix HUD element overlaps and sizing issues on mobile screens

- [ ] **Phase 4: HUD Element Fixes** - Fix menu grid sizing, item slot duplication, and item bar anchoring
- [ ] **Phase 5: HUD Overlap Resolution** - Resolve positional conflicts between HUD elements and touch controls

## Phase Details

### Phase 4: HUD Element Fixes
**Goal**: Individual HUD elements render correctly on mobile -- right size, no duplication, properly anchored
**Depends on**: Phase 3 (v1.0 complete)
**Requirements**: MENU-01, MENU-02, ITEM-01, ITEM-02
**Success Criteria** (what must be TRUE):
  1. Menu grid on mobile is visibly smaller than on desktop and does not dominate the left side of the screen
  2. Each menu grid button can be tapped on mobile without accidentally hitting adjacent buttons
  3. Item slots appear exactly once on mobile (no duplicate slots visible)
  4. Item bar sits flush against the bottom edge of the screen on both desktop and mobile
**Plans**: TBD

Plans:
- [ ] 04-01: TBD
- [ ] 04-02: TBD

### Phase 5: HUD Overlap Resolution
**Goal**: All HUD elements coexist without overlapping each other or Roblox touch controls on every screen size
**Depends on**: Phase 4
**Requirements**: HUD-01, HUD-02, HUD-03
**Success Criteria** (what must be TRUE):
  1. Rankings panel is fully visible on mobile without covering item slots or the jump button
  2. Coins/Gems bar is fully visible on mobile without covering the movement joystick
  3. All HUD elements on desktop remain in their original positions with no visual change from pre-v1.1
**Plans**: TBD

Plans:
- [ ] 05-01: TBD
- [ ] 05-02: TBD

## Progress

**Execution Order:**
Phases 1-3 shipped. Current: 4 -> 5

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Scaling Infrastructure | v1.0 | 2/2 | Complete | shipped |
| 2. Large Modal Scaling | v1.0 | 2/2 | Complete | shipped |
| 3. Medium Modals + Polish | v1.0 | 2/2 | Complete | shipped |
| 4. HUD Element Fixes | v1.1 | 0/? | Not started | - |
| 5. HUD Overlap Resolution | v1.1 | 0/? | Not started | - |
