# Phase 4: HUD Element Fixes - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix individual HUD elements on mobile: scale down menu grid, fix item slot duplication, anchor item bar to bottom, reposition coins/gems bar. Desktop experience must remain unchanged.

</domain>

<decisions>
## Implementation Decisions

### Coins/Gems Bar Position
- **D-01:** On mobile, move Coins/Gems/StageProgress to top-left (currently bottom-left where they overlap walk joystick)
- **D-02:** On desktop, keep Coins/Gems at current bottom-left position (no regression)
- **D-03:** Use platform detection (UserInputService.TouchEnabled) to switch position

### Item Bar Position
- **D-04:** Item bar anchored to bottom edge but above safe area (Y=1, -50 approx) — not floating at Y=1,-105
- **D-05:** Both desktop and mobile get the same anchored position

### Item Slot Duplication
- **D-06:** Root cause: ItemUI creates centered item bar + MobileInputUI creates separate touch buttons = 2 sets visible
- **D-07:** Fix by hiding ItemUI keybind labels on mobile (MobileInputUI touch buttons are the correct ones for touch), OR hide MobileInputUI item buttons and keep ItemUI

### Claude's Discretion
- Menu grid scaling approach — UIScale, reduce button sizes, or fewer columns on mobile
- Which item UI to hide on mobile (ItemUI keybind hints vs MobileInputUI buttons) — pick the cleaner approach
- Exact Y position for item bar above safe area
- Whether StageProgress frame moves with Coins/Gems or stays separate
- How to detect mobile vs desktop for position switching (TouchEnabled check pattern)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### HUD Element Files
- `src/client/UI/MenuGridUI.luau` (152 lines) — 172x306 grid, BUTTON_W=74, BUTTON_H=68, 2x4 layout, position (0,10,0.5,-153)
- `src/client/UI/ItemUI.luau` (667 lines) — 160x95 item bar, centered at (0.5,-80,1,-105), creates keybind labels [1][2]
- `src/client/UI/MobileInputUI.luau` (269 lines) — Touch-only: right buttons (1,-170,1,-210) + left buttons (0,10,1,-90), creates separate item buttons
- `src/client/UI/ScoreUI.luau` (350+ lines) — GemFrame (0,10,1,-100) 130x44, StageFrame (0,10,1,-132) 160x28
- `src/client/UI/CurrencyUI.luau` (344 lines) — CurrencyFrame (0,10,1,-52) 140x44

### Infrastructure
- `src/shared/ResponsiveScale.luau` — applyToFrame, compensateStrokes (may extend for HUD)
- `src/client/UI/MainUI.luau` — Orchestrator, ResponsiveScale.init() already called

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ResponsiveScale.applyToFrame()` — Can scale HUD elements same way as modals
- `UserInputService.TouchEnabled` — Already used in MobileInputUI for platform detection
- `MobileInputUI.isTouchDevice` — Boolean flag available for mobile checks

### Established Patterns
- Platform detection: `UserInputService.TouchEnabled` check in constructor
- HUD positioning: Fixed pixel UDim2 offsets from screen edges
- All HUD elements parent to MainUI's screenGui

### Integration Points
- ScoreUI.luau — GemFrame + StageFrame need position change on mobile
- CurrencyUI.luau — CurrencyFrame needs position change on mobile
- ItemUI.luau — Position change + possible visibility toggle for keybind labels
- MobileInputUI.luau — May need to hide item buttons if ItemUI is kept
- MenuGridUI.luau — Needs scaling or size reduction on mobile

</code_context>

<specifics>
## Specific Ideas

- Coins/Gems ย้ายไปซ้ายบนบนมือถือ (ปัจจุบันทับปุ่มเดิน)
- Item bar ติดขอบล่างแต่เหนือ safe area

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 04-hud-element-fixes*
*Context gathered: 2026-03-21*
