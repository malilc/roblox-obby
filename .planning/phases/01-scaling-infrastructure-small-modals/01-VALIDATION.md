---
phase: 1
slug: scaling-infrastructure-small-modals
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-21
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Luau spec files (.spec.luau) with custom test runner |
| **Config file** | run-tests.server.luau |
| **Quick run command** | `run-tests` (in Roblox Studio) |
| **Full suite command** | `run-tests` (all .spec.luau files) |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Verify ResponsiveScale.calculateScale() pure function tests pass
- **After every plan wave:** Run full test suite
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| TBD | 01 | 1 | SCALE-01 | unit | ResponsiveScale module exists | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | SCALE-02 | unit | calculateScale returns correct values | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | SCALE-04 | unit | scale floor enforced at 0.5 | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | SCALE-05 | unit | desktop returns scale 1.0 | ❌ W0 | ⬜ pending |
| TBD | 01 | 1 | SCALE-03 | manual | viewport resize triggers recalc | N/A | ⬜ pending |
| TBD | 02 | 2 | MODAL-10 | manual | SettingsUI scales on mobile viewport | N/A | ⬜ pending |
| TBD | 02 | 2 | MODAL-11 | manual | FeedbackUI scales on mobile viewport | N/A | ⬜ pending |
| TBD | 02 | 2 | MODAL-12 | manual | SpectatorUI panels scale on mobile | N/A | ⬜ pending |
| TBD | 02 | 2 | MODAL-13 | manual | LeaderboardUI stub is future-proofed | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `src/shared/ResponsiveScale.spec.luau` — unit tests for calculateScale pure function
- [ ] Test cases: desktop viewport (1920x1080 → 1.0), mobile viewport (414x736 → correct scale), minimum floor (tiny viewport → 0.5), various modal design sizes

*Existing test infrastructure (run-tests.server.luau + .spec.luau pattern) covers framework needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Viewport resize triggers recalc | SCALE-03 | Requires Roblox Studio device emulator | Toggle device emulator size, observe modal rescale |
| SettingsUI scales on mobile | MODAL-10 | Visual verification in Studio | Open Settings on 414px emulated viewport, verify fits |
| FeedbackUI scales on mobile | MODAL-11 | Visual verification in Studio | Open Feedback on 414px emulated viewport, verify fits |
| SpectatorUI panels scale | MODAL-12 | Visual verification in Studio | Enter spectator mode on 414px viewport, verify all 3 panels fit |
| LeaderboardUI future-proofed | MODAL-13 | Stub module — no visual to verify | Confirm module has scaling hook for when UI is added |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
