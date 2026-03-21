---
phase: 02
slug: large-modal-scaling
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-21
---

# Phase 02 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Jest (jsdotlua/jest@3.10.0) via run-in-roblox |
| **Config file** | test.project.json |
| **Quick run command** | `rojo build test.project.json -o test.rbxl && run-in-roblox --place test.rbxl --script test-runner.server.luau` |
| **Full suite command** | Same as quick run (single test suite) |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Visual inspection in Studio device emulator (414px viewport)
- **After every plan wave:** Full visual verification of all 5 modals on mobile + desktop
- **Before `/gsd:verify-work`:** All modals verified on both viewports
- **Max feedback latency:** 30 seconds (Studio load + modal open)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | SCALE-* | unit | ResponsiveScale.spec.luau (extend existing) | ✅ | ⬜ pending |
| 02-02-01 | 02 | 2 | MODAL-04 | visual | Studio device emulator | N/A | ⬜ pending |
| 02-02-02 | 02 | 2 | MODAL-05 | visual | Studio device emulator | N/A | ⬜ pending |
| 02-03-01 | 03 | 2 | MODAL-01 | visual | Studio device emulator | N/A | ⬜ pending |
| 02-03-02 | 03 | 2 | MODAL-02 | visual | Studio device emulator | N/A | ⬜ pending |
| 02-03-03 | 03 | 2 | MODAL-03 | visual | Studio device emulator | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements:
- ResponsiveScale.spec.luau already exists with 8 tests from Phase 1
- compensateStrokes tests can extend existing spec file
- Visual verification requires human inspection (no automated UI testing in Roblox)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Modal fits on 414px viewport | MODAL-01 to MODAL-05 | Roblox has no headless UI rendering | Open each modal in Studio device emulator with iPhone SE selected, verify no content cut off |
| UIStroke proportional at scale | Success Criteria #3 | Visual rendering quality | Compare stroke thickness visually at 1.0x vs scaled-down size |
| ScrollingFrame scrolls correctly | Success Criteria #2 | Scroll behavior requires interaction | Scroll through items in Shop/ClassSelection at scaled size |
| DailyBonusUI scales on each show | Success Criteria #4 | Requires triggering daily bonus remote | Open daily bonus, close, reopen — verify scaling applies each time |
| Desktop unchanged | Success Criteria #5 | Visual comparison | Open all 5 modals without device emulator, verify original sizes |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
