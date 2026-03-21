---
phase: 3
slug: medium-modals-touch-polish
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-21
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | jest 3.10.0 (jsdotlua/jest) via run-in-roblox |
| **Config file** | test.project.json |
| **Quick run command** | `aftman run rojo build test.project.json -o test.rbxl && aftman run run-in-roblox --place test.rbxl --script src/shared/__tests__/run-tests.server.luau` |
| **Full suite command** | same as quick run |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick test command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | MODAL-09 | unit | `grep "applyToFrame" src/client/UI/RaceResultsUI.luau` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | MODAL-07 | unit | `grep "applyToFrame" src/client/UI/SummaryUI.luau` | ❌ W0 | ⬜ pending |
| 03-02-01 | 02 | 2 | MODAL-08 | unit | `grep "applyToFrame" src/client/UI/MatchLobbyUI.luau` | ❌ W0 | ⬜ pending |
| 03-02-02 | 02 | 2 | MODAL-06 | unit | `grep "applyToFrame" src/client/UI/StageSelectionUI.luau` | ❌ W0 | ⬜ pending |
| 03-03-01 | 03 | 3 | TOUCH-01, TOUCH-02 | manual | visual inspection at 414px viewport | N/A | ⬜ pending |
| 03-03-02 | 03 | 3 | TOUCH-03 | manual | verify ScreenGui.ScreenInsets = CoreUISafeInsets | N/A | ⬜ pending |
| 03-03-03 | 03 | 3 | POLISH-01 | unit | `grep "TweenService" src/shared/ResponsiveScale.luau` | ❌ W0 | ⬜ pending |
| 03-03-04 | 03 | 3 | POLISH-02 | manual | verify AnchorPoint(0.5,0.5) + Position(0.5,0,0.5,0) | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- Existing test infrastructure covers ResponsiveScale unit tests (Phase 1)
- Phase 3 modals are primarily visual — integration verified by grep + manual inspection
- No new test framework setup needed

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Touch targets 44px+ at scaled size | TOUCH-01, TOUCH-02 | Requires runtime viewport simulation | Scale to 0.58x (414px viewport), measure effective button sizes |
| No notch/Dynamic Island clipping | TOUCH-03 | Device-specific rendering | Verify ScreenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets on all ScreenGuis |
| Scale-in animation smoothness | POLISH-01 | Visual quality assessment | Open modal, observe tween from 0.8→target, no pop-in |
| Centering after scaling | POLISH-02 | Multi-viewport verification | Test at 414px, 768px, 1920px viewports — modal always centered |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
