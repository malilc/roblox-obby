# PC Responsive Fix — Design Spec

**Date:** 2026-03-24
**Status:** Approved
**Scope:** Fix 3 UI issues caused by AdaptiveLayout mobile migration affecting PC

## Problem

After migrating HUD elements to AdaptiveLayout zone system for mobile support, PC has three issues:
1. **HUD bottom-left overlapping** — zone stacking miscalculates when viewport is (1,1) during init
2. **Debug UI overlapping HUD** — FlyUI, TestingBtn, UpdateLogBtn have hardcoded positions that collide with zone-managed elements
3. **UpdateLog popup not responsive** — 460x480 panel has no adaptive scaling

## Fix 1: AdaptiveLayout Init Timing Bug

### Root Cause

`AdaptiveLayout.init()` calls `_recalculate()` when `Camera.ViewportSize` may still be `(1,1)` (Roblox startup race). This produces `scale = 0.4` (MIN_SCALE clamp), causing zone stacking to use wrong `scaledHeight` values.

Secondary bug: if `camera = nil` at init time, the `ViewportSize` change listener is never connected, so scale never updates.

### Changes in `src/shared/AdaptiveLayout.luau`

**New module-level state:**
- `viewportReady: boolean = false` — set to true when `_recalculate()` succeeds with valid viewport
- `viewportConnection: RBXScriptConnection? = nil` — stores current ViewportSize listener for cleanup on camera swap

**`_recalculate()`** — add viewport guard:
- If `vp.X <= 1` or `vp.Y <= 1`, return early (keep defaults: scale=1.0, Desktop)
- On success, set `viewportReady = true`
- Existing calculation logic unchanged otherwise

**`init()`** — restructure camera setup:

```
local function connectCamera(cam)
    camera = cam
    -- Disconnect old ViewportSize listener to avoid leaks on camera swap
    if viewportConnection then
        viewportConnection:Disconnect()
        viewportConnection = nil
    end
    -- Connect new listener
    viewportConnection = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        task.wait()
        _updateAll()
    end)
    -- Full update (not just _recalculate) so modals + HUD positions update too
    _updateAll()
end

-- Connect current camera if available
local cam = Workspace.CurrentCamera
if cam then
    connectCamera(cam)
end

-- ALWAYS connect CurrentCamera change (handles camera swap on respawn)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    local newCam = Workspace.CurrentCamera
    if newCam then
        connectCamera(newCam)
    end
end)

-- If viewport not ready yet, poll until it is
if not viewportReady then
    task.spawn(function()
        while not viewportReady do
            task.wait(0.1)
            _updateAll()
        end
    end)
end
```

Key changes vs original:
- `connectCamera()` disconnects old listener before connecting new one (no leak)
- `connectCamera()` calls `_updateAll()` (not just `_recalculate()`) so HUD + modals update
- `CurrentCamera` signal always connected (not only when camera is nil)
- Polling uses `viewportReady` flag (not `currentScale <= MIN_SCALE` which would be true=1.0 due to guard)
- Polling loop stops naturally once viewport becomes valid

### Behavior

| Scenario | Before | After |
|----------|--------|-------|
| Viewport (1,1) at init | scale=0.4, stuck | scale=1.0 (default), auto-corrects when viewport ready |
| Camera nil at init | ViewportSize listener never connected | Listener connected when camera appears via CurrentCamera signal |
| Camera replaced (respawn) | Old listener orphaned, new camera has none | Old listener disconnected, new camera gets fresh listener |
| Polling + listener fire simultaneously | N/A | Safe — `_updateAll()` is idempotent |

## Fix 2: UpdateLog Popup Responsive

### Changes in `src/client/init.client.luau`

- Add `require(AdaptiveLayout)` at top of file (alongside Theme require)
- Add `AdaptiveLayout.applyScale(panel, panelW, panelH)` inside `showUpdateLog()`, after all panel children are created but before the opening tween animation starts

Placement: between content construction (scroll frame, buttons, etc.) and the fade-in tween. This ensures the panel animates in at the correct scaled size from the start.

Uses existing modal scaling system (60px margin, clamp 0.4-1.0). Same pattern as ShopUI, ClassSelectionUI, etc.

Note: UpdateLog popup is destroyed on close (`updateGui:Destroy()`). The orphan cleaner in `_cleanOrphans()` automatically removes the tracked modal entry when `frame.Parent == nil`, so no manual cleanup needed.

## Fix 3: Debug UI Position Adjustments

### FlyUI — move to bottom-right (`src/client/FlyController.luau`)

| Element | Old Position | New Position |
|---------|-------------|-------------|
| FlyButton | `(0, 160, 1, -30)` | `(1, -180, 1, -30)` |
| SpeedLabel | `(0, 215, 1, -30)` | `(1, -125, 1, -30)` |
| SpeedUp | `(0, 255, 1, -30)` | `(1, -85, 1, -30)` |
| SpeedDown | `(0, 278, 1, -30)` | `(1, -62, 1, -30)` |

Rationale: BottomRight zone has no registered elements, so no collision.

### UpdateLogBtn — shift left (`src/client/init.client.luau`)

| Element | Old Position | New Position |
|---------|-------------|-------------|
| UpdateLogBtn | `(1, -180, 0, 10)` | `(1, -260, 0, 10)` |
| ItemTestingUI | `(1, -130, 0, 10)` | unchanged |

Gap between buttons: 90px (no overlap).

## Files Modified

1. `src/shared/AdaptiveLayout.luau` — init timing fix
2. `src/client/init.client.luau` — UpdateLog applyScale + UpdateLogBtn position
3. `src/client/FlyController.luau` — FlyUI button positions

## Testing

1. Start game in Studio — verify HUD elements don't overlap (BottomLeft zone stacks correctly)
2. Resize Studio viewport — verify elements reposition smoothly
3. Open UpdateLog popup — verify it scales on small viewport
4. Check FlyUI buttons at bottom-right — verify no overlap with HUD
5. Check TestingBtn + UpdateLogBtn at top-right — verify no overlap
