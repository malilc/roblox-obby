---
status: testing
phase: 04-hud-element-fixes
source: [04-01-SUMMARY.md, 04-02-PLAN.md, hotfixes]
started: 2026-03-21T15:00:00.000Z
updated: 2026-03-21T15:00:00.000Z
---

## Current Test

number: 1
name: Menu grid size on mobile
expected: |
  Menu grid (left side) is visibly smaller than desktop. Buttons are compact but each one is tappable without hitting adjacent buttons. Icon is above text in each button, text doesn't overflow.
awaiting: user response

## Tests

### 1. Menu grid size on mobile
expected: Menu grid is visibly smaller on mobile, buttons tappable, icon above text, text doesn't overflow button
result: [pending]

### 2. Menu grid position
expected: Menu grid is positioned higher on mobile (not centered, slightly above center) and doesn't overlap with coins/gems at bottom-left
result: [pending]

### 3. Item slots — no duplication
expected: On mobile, only ONE set of item controls is visible (center-bottom [1][2] buttons). No duplicate slots on the right side. No keybind number labels on the slots.
result: [pending]

### 4. Item bar position
expected: Item buttons [1][2] are at center-bottom of screen, fully visible, not cut off
result: [pending]

### 5. Item bar behind popups
expected: When opening StageSelection or any modal, the item [1][2] buttons are BEHIND the popup (not visible on top of the modal)
result: [pending]

### 6. Coins/Gems position on mobile
expected: Coins and Gems bars are at bottom-left corner of screen, small size, flush to left edge, not overlapping with walk joystick or menu grid
result: [pending]

### 7. Desktop regression — no changes
expected: On desktop viewport, menu grid is full size, coins/gems at bottom-left (original position), item bar at bottom-center with [1][2][3] keybind hints visible
result: [pending]

## Summary

total: 7
passed: 0
issues: 0
pending: 7
skipped: 0
blocked: 0

## Gaps
