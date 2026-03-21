# Phase 1: Scaling Infrastructure + Small Modals - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Build a centralized ResponsiveScale module that computes viewport-aware scale factors for modal frames, and apply it to the 4 small modals (SettingsUI, FeedbackUI, SpectatorUI, LeaderboardUI) as validation. Desktop experience must remain unchanged.

</domain>

<decisions>
## Implementation Decisions

### Module Location
- **D-01:** ResponsiveScale module lives in `src/shared/` — follows existing pattern where ThemeConfig and Config are already in shared/
- **D-02:** MainUI.luau initializes ResponsiveScale once and passes it to modals — single viewport listener, centralized control
- **D-03:** LeaderboardUI stays in scope (MODAL-13) even though it's currently a stub — future-proofing

### Scale Behavior
- **D-04:** 40px padding on each side of modals on mobile — comfortable margin, modal doesn't feel edge-to-edge
- **D-05:** Minimum scale floor of 0.5x — prevents modals from shrinking below usability threshold (780px modal becomes 390px at floor)
- **D-06:** Scale formula: `math.min(1.0, (viewportW - 80) / designW, (viewportH - 80) / designH)` — 80 = 40px padding × 2 sides
- **D-07:** All SpectatorUI sub-panels scale uniformly (prompt 280x50, rankings 200x300, controls 400x44) — consistency over selective scaling

### Integration Pattern
- **D-08:** Explicit per-modal opt-in via `ResponsiveScale:applyToFrame(frame, designW, designH)` — clear, no magic
- **D-09:** Also update the unused `UIFactory.createModal()` to include scaling — so future modals auto-scale when using createModal
- **D-10:** Each modal stores its own design size (width, height) as constants at the top of the file (e.g., `local PANEL_W = 360`)

### Claude's Discretion
- How to handle the Camera.ViewportSize one-frame timing quirk (task.wait or alternative)
- Whether to use ScreenGui.AbsoluteSize or Camera.ViewportSize for the viewport measurement (research found GuiInset considerations)
- Internal data structure for tracking managed UIScale instances
- How to structure the signal/callback for notifying modals of scale changes

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scaling Infrastructure
- `.planning/research/STACK.md` — UIScale API details, scale formula, viewport detection approach, timing quirks
- `.planning/research/ARCHITECTURE.md` — Where ResponsiveScale fits in existing architecture, integration points, implementation order
- `.planning/research/PITFALLS.md` — UIStroke bug, ScrollingFrame interaction, touch target risks, GuiInset considerations

### Existing Code
- `src/shared/ThemeConfig.luau` — Centralized theme constants pattern (model for ResponsiveScale location)
- `src/client/UI/UIFactory.luau` — createPanel and createModal functions to update
- `src/client/UI/MainUI.luau` — Orchestrator that initializes all UI modules (integration point)
- `src/client/UI/SettingsUI.luau` — Small modal example (360x380, uses UIFactory.createPanel)
- `src/client/UI/FeedbackUI.luau` — Small modal example (similar pattern to SettingsUI)
- `src/client/UI/SpectatorUI.luau` — Multi-panel modal (prompt + rankings + controls, different pattern)
- `src/client/UI/LeaderboardUI.luau` — Stub module (no UI currently, keep in scope for future)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `UIFactory.createPanel()` — All small modals use this for frame creation with centered positioning
- `UIFactory.createModal()` — Exists but unused — natural hook for auto-scaling future modals
- `ThemeConfig.luau` — Pattern for shared constants/helpers in `src/shared/`
- `MobileInputUI.luau` — Has `UserInputService.TouchEnabled` platform detection

### Established Patterns
- Modals use `AnchorPoint = Vector2.new(0.5, 0.5)` + `Position = UDim2.new(0.5, 0, 0.5, 0)` for centering
- Design sizes stored as local constants: `local PANEL_W = 360; local PANEL_H = 380`
- `:show()` / `:hide()` pattern on all modal modules
- TweenService used for UI animations (overlay fade, etc.)

### Integration Points
- `MainUI.luau` creates all UI module instances — place to initialize ResponsiveScale and pass to modals
- `Camera:GetPropertyChangedSignal("ViewportSize")` — standard viewport change detection
- ScreenGui `IgnoreGuiInset = false` — means GuiInset is respected, affects viewport height calculation

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches within the decisions captured above.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-scaling-infrastructure-small-modals*
*Context gathered: 2026-03-21*
