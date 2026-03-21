# Requirements: Responsive UI Overhaul

**Defined:** 2026-03-21
**Core Value:** Every modal must be fully visible and usable on both desktop and mobile phone screens

## v1 Requirements

### Scaling Infrastructure

- [x] **SCALE-01**: Centralized ResponsiveScale module computes scale factor from viewport size and modal design size
- [x] **SCALE-02**: Scale formula: `math.min(1.0, (viewportW - padding) / designW, (viewportH - padding) / designH)`
- [x] **SCALE-03**: Viewport change listener recalculates scale on Camera.ViewportSize change
- [x] **SCALE-04**: Minimum scale floor (0.5) prevents modals from shrinking below usability threshold
- [x] **SCALE-05**: Desktop screens show modals at full design size (scale clamped to 1.0)

### Large Modal Scaling (780x580)

- [ ] **MODAL-01**: ShopUI scales down on mobile screens
- [ ] **MODAL-02**: ClassSelectionUI scales down on mobile screens
- [ ] **MODAL-03**: TitleCollectionUI scales down on mobile screens
- [ ] **MODAL-04**: TutorialUI scales down on mobile screens
- [ ] **MODAL-05**: DailyBonusUI scales down on mobile screens

### Medium Modal Scaling

- [ ] **MODAL-06**: StageSelectionUI (580x480) scales down on mobile screens
- [ ] **MODAL-07**: SummaryUI (400x600) scales down on mobile screens
- [ ] **MODAL-08**: MatchLobbyUI (400x500) scales down on mobile screens
- [ ] **MODAL-09**: RaceResultsUI (450x500) scales down on mobile screens

### Small Modal Scaling

- [x] **MODAL-10**: SettingsUI scales properly on small screens
- [x] **MODAL-11**: FeedbackUI scales properly on small screens
- [x] **MODAL-12**: SpectatorUI scales properly on small screens
- [x] **MODAL-13**: LeaderboardUI scales properly on small screens

### Touch & Usability

- [ ] **TOUCH-01**: Close buttons remain tappable (44px+ hit area) at scaled sizes on mobile
- [ ] **TOUCH-02**: Action buttons (buy, equip, confirm) remain tappable at scaled sizes
- [ ] **TOUCH-03**: ScreenInsets/CoreUISafeInsets verified — modals don't clip behind notch/Dynamic Island

### Polish

- [ ] **POLISH-01**: Modals animate scale on show (tween from 0.8 to target scale)
- [ ] **POLISH-02**: Modals remain centered after scaling on all screen sizes

## v2 Requirements

### Advanced Responsiveness

- **TEXT-01**: Dynamic text size adjustment for extreme scale-down scenarios
- **LAYOUT-01**: Per-breakpoint layout adjustments for specific modals (e.g., Shop grid)
- **ORIENT-01**: Landscape orientation lock enforcement if players report portrait issues

## Out of Scope

| Feature | Reason |
|---------|--------|
| Content reflow / mobile-specific layouts | Massive scope increase (23 UI files), user explicitly chose scale-down approach |
| Global UIScale on ScreenGui | Would shrink HUD elements too; user confirmed HUD is fine |
| HUD element scaling | User confirmed HUD (currency, gems, score, menu grid, items) is acceptable |
| Portrait mode support | Roblox games default to landscape; obby gameplay requires landscape FoV |
| Tablet-specific optimizations | Viewport-based formula handles tablets naturally (near 1.0 scale) |
| UISizeConstraint approach | Known Roblox engine bug — UIScale ignores UISizeConstraint |
| Converting offset to scale-based UDim2 | Would require rewriting all 23 UI files; UIScale achieves same result |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SCALE-01 | Phase 1 | Complete |
| SCALE-02 | Phase 1 | Complete |
| SCALE-03 | Phase 1 | Complete |
| SCALE-04 | Phase 1 | Complete |
| SCALE-05 | Phase 1 | Complete |
| MODAL-01 | Phase 2 | Pending |
| MODAL-02 | Phase 2 | Pending |
| MODAL-03 | Phase 2 | Pending |
| MODAL-04 | Phase 2 | Pending |
| MODAL-05 | Phase 2 | Pending |
| MODAL-06 | Phase 3 | Pending |
| MODAL-07 | Phase 3 | Pending |
| MODAL-08 | Phase 3 | Pending |
| MODAL-09 | Phase 3 | Pending |
| MODAL-10 | Phase 1 | Complete |
| MODAL-11 | Phase 1 | Complete |
| MODAL-12 | Phase 1 | Complete |
| MODAL-13 | Phase 1 | Complete |
| TOUCH-01 | Phase 3 | Pending |
| TOUCH-02 | Phase 3 | Pending |
| TOUCH-03 | Phase 3 | Pending |
| POLISH-01 | Phase 3 | Pending |
| POLISH-02 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 23 total
- Mapped to phases: 23
- Unmapped: 0

---
*Requirements defined: 2026-03-21*
*Last updated: 2026-03-21 after roadmap creation*
