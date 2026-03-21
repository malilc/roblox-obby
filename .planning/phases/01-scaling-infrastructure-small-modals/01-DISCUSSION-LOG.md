# Phase 1: Scaling Infrastructure + Small Modals - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-21
**Phase:** 01-scaling-infrastructure-small-modals
**Areas discussed:** Module location, Scale behavior, Integration pattern

---

## Module Location

| Option | Description | Selected |
|--------|-------------|----------|
| src/shared/ (Recommended) | Accessible from any client script. Follows existing pattern. | ✓ |
| src/client/UI/ | Co-located with UI code. But other client scripts can't access it easily. | |
| You decide | Claude picks based on what works best | |

**User's choice:** src/shared/ (Recommended)
**Notes:** Follows existing pattern where ThemeConfig and Config are already in shared/

---

| Option | Description | Selected |
|--------|-------------|----------|
| MainUI initializes | MainUI creates ResponsiveScale once, passes it to modals. | ✓ |
| Self-managing | Each modal calls ResponsiveScale.applyToFrame() itself. | |
| You decide | Claude picks the cleanest architecture | |

**User's choice:** MainUI initializes
**Notes:** Single viewport listener, centralized control

---

| Option | Description | Selected |
|--------|-------------|----------|
| Skip LeaderboardUI | It's a stub with no UI to scale. | |
| Keep in scope | Keep the requirement in case it gets a real UI later | ✓ |

**User's choice:** Keep in scope

---

## Scale Behavior

| Option | Description | Selected |
|--------|-------------|----------|
| 20px each side | Tight fit — maximizes modal size on small screens | |
| 40px each side (Recommended) | Comfortable margin — modal doesn't feel edge-to-edge | ✓ |
| You decide | Claude picks based on what looks good | |

**User's choice:** 40px each side (Recommended)

---

| Option | Description | Selected |
|--------|-------------|----------|
| 0.5x (Recommended) | Half size — still readable, 780px modal becomes 390px | ✓ |
| 0.4x | Smaller — fits tighter screens but text gets tiny | |
| No floor | Shrink as much as needed to fit | |

**User's choice:** 0.5x (Recommended)

---

| Option | Description | Selected |
|--------|-------------|----------|
| Scale all panels | Consistent — everything scales uniformly | ✓ |
| Only rankings panel | Only the 200x300 panel needs scaling | |
| You decide | Claude determines which sub-panels need scaling | |

**User's choice:** Scale all panels

---

## Integration Pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit per-modal | Each modal calls ResponsiveScale:applyToFrame(frame, designW, designH) | ✓ |
| Via UIFactory | Add scaling to UIFactory.createPanel/createModal | |
| You decide | Claude picks the cleanest approach | |

**User's choice:** Explicit per-modal

---

| Option | Description | Selected |
|--------|-------------|----------|
| Update it (Recommended) | Add scaling so future modals auto-scale when using createModal | ✓ |
| Leave it alone | Focus only on what's needed now | |
| You decide | Claude decides based on effort | |

**User's choice:** Update it (Recommended)

---

## Claude's Discretion

- Camera.ViewportSize timing quirk handling
- ScreenGui.AbsoluteSize vs Camera.ViewportSize choice
- Internal data structure for managed UIScale instances
- Signal/callback structure for scale change notifications

## Deferred Ideas

None — discussion stayed within phase scope.
