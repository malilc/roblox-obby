# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — Responsive UI Overhaul

**Shipped:** 2026-03-21
**Phases:** 3 | **Plans:** 8 | **Tasks:** 15

### What Was Built
- Centralized ResponsiveScale module with TDD (8 unit tests)
- 13 modals scaled for mobile using UIScale approach
- UIStroke compensation helper (compensateStrokes)
- ScrollingFrame CanvasSize fixes for 7 scroll instances
- Touch target enforcement (44px+ effective hit area)
- Scale-in/out animations on all modals
- Safe area compliance (CoreUISafeInsets explicit)

### What Worked
- **Phased approach (small→large→medium)**: Validated infrastructure on simple modals first, caught UIStroke and ScrollingFrame bugs before tackling complex ones
- **Coarse granularity (3 phases)**: Right level for a focused fix project — no over-planning overhead
- **Parallel execution**: Wave 1 plans in Phase 3 ran simultaneously with no file conflicts
- **Pure function design**: calculateScale testable without Roblox runtime

### What Was Inefficient
- **SummaryUI design height**: Set to 660px to accommodate upsell variant, but this was too tall for landscape mobile — had to refactor to scrollable layout during verification
- **Touch target sizing**: Initial 54px OK button still too small at scale — needed checkpoint feedback to catch this

### Patterns Established
- `ResponsiveScale.applyToFrame(frame, designW, designH)` as standard opt-in pattern
- `compensateStrokes(frame, scale)` for UIStroke under UIScale
- Design size constants at top of every modal file (`local PANEL_W = 400`)
- Manual CanvasSize for ScrollingFrames under UIScale (AutomaticCanvasSize broken)
- Scale-in animation: `uiScale.Scale = target * 0.8` → tween to target with EasingStyle.Back

### Key Lessons
1. **Test on actual viewport dimensions early**: The 660px SummaryUI issue would have been caught earlier if design heights were validated against real phone landscape heights (~375px)
2. **UIScale-only approach works for 90% of cases**: SummaryUI was the only modal that needed a layout change (scroll) — the rest scaled cleanly
3. **Touch targets need calculation, not guessing**: Effective size = design size * scale factor. Must compute at worst-case scale to ensure 44px minimum

### Cost Observations
- Model mix: 100% inherit (opus)
- Sessions: ~3 (Phase 1+2 in session 1, Phase 3 in session 2-3)
- Notable: Parallel executor agents saved significant time in Wave 1 execution

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | ~3 | 3 | Initial project — established ResponsiveScale patterns |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v1.0 | 8 | ResponsiveScale core | ResponsiveScale.luau |
