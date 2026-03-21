# Phase 5: HUD Overlap Resolution - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Resolve remaining HUD overlaps on mobile: Rankings panel must not cover item buttons or jump button. Verify Coins/Gems positioning from Phase 4 still works. Desktop must remain unchanged.

</domain>

<decisions>
## Implementation Decisions

### Rankings Panel on Mobile
- **D-01:** Rankings panel on mobile shows only top 3 players (instead of full list) to reduce size
- **D-02:** Rankings panel scaled down (UIScale) on mobile — same approach as Coins/Gems from Phase 4
- **D-03:** Rankings must not overlap with MobileItemButtons (center-bottom) or Roblox jump button (right-bottom)

### Coins/Gems (inherited from Phase 4)
- **D-04:** Already fixed — UIScale 0.5 on mobile, positioned bottom-left above joystick
- **D-05:** Viewport-based detection (ViewportSize.Y < 500) proven reliable

### Desktop Regression
- **D-06:** All HUD elements on desktop remain at original positions — no changes

### Claude's Discretion
- Exact Rankings panel position on mobile (which corner/edge avoids all conflicts)
- Whether to use UIScale or resize the Rankings frame directly
- How to limit Rankings to top 3 on mobile (filter data or hide rows)
- Rankings panel styling at reduced size (font size, row height adjustments)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 4 Artifacts (foundation)
- `.planning/phases/04-hud-element-fixes/04-CONTEXT.md` — HUD mobile decisions, viewport detection
- `.planning/phases/04-hud-element-fixes/04-02-SUMMARY.md` — UIScale approach, IS_MOBILE race condition fix

### Target Files
- `src/client/UI/SpectatorUI.luau` — Rankings panel (already has ResponsiveScale from v1.0)
- `src/client/UI/MobileInputUI.luau` — Item buttons at center-bottom (0.5,-80,1,-80), ZIndex=0
- `src/client/UI/ScoreUI.luau` — Gems/Stage UIScale 0.5 on mobile
- `src/client/UI/CurrencyUI.luau` — Coins UIScale 0.5 on mobile

### Race Condition Note
- `UserInputService.TouchEnabled` is FALSE at module load time in Studio Device Emulator
- Use `camera.ViewportSize.Y < 500` with `> 1` guard for mobile detection
- Or use UIScale with viewport listener (proven pattern from Phase 4)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- UIScale approach from Phase 4 — proven for Gems/Coins/MenuGrid
- ViewportSize listener pattern — responsive to viewport changes
- SpectatorUI already has ResponsiveScale from v1.0 (for prompt/rankings/controls)

### Established Patterns
- ViewportSize.Y > 1 AND < 500 = mobile
- UIScale instance on frame for mobile shrinking
- camera:GetPropertyChangedSignal("ViewportSize") for responsive updates

### Integration Points
- SpectatorUI rankings panel — needs mobile-specific top-3 limit + scaling
- Rankings positioning must avoid MobileItemButtons at (0.5,-80,1,-80)
- Rankings positioning must avoid Roblox jump button at bottom-right

</code_context>

<specifics>
## Specific Ideas

- Rankings บนมือถือแสดงแค่ top 3 (ประหยัดพื้นที่)
- ย่อ + เล็กลง (UIScale) ไม่ย้ายตำแหน่ง

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 05-hud-overlap-resolution*
*Context gathered: 2026-03-21*
