# Adaptive Layout — Unified Responsive UI System

**Date:** 2026-03-22
**Status:** Approved
**Replaces:** ResponsiveScale.luau + scattered viewport UIScale listeners

## Problem

ระบบ responsive ปัจจุบันมี 2 ระบบทำงานคู่ขนาน:
- **ResponsiveScale** สำหรับ 11 modal panels — คำนวณ scale จาก viewport
- **Viewport UIScale** สำหรับ 6 HUD elements — hardcoded scale (0.5, 0.7) + ViewportSize.Y < 500

ทำให้เกิดปัญหา:
1. Modal panels ยังล้นจอมือถือ
2. HUD elements ซ้อนทับกัน
3. Scale ไม่สม่ำเสมอ (บางอันเล็กเกิน บางอันใหญ่เกิน)
4. Device Emulator ใช้ได้ แต่มือถือจริงไม่ตรง
5. แก้ไข 18+ commits ยังไม่ลงตัว

## Solution

สร้างโมดูลใหม่ `AdaptiveLayout.luau` แทนที่ทั้ง 2 ระบบเดิม ด้วยระบบเดียวที่จัดการ:
- **Safe Area** calculation จาก Camera.ViewportSize + GuiInset
- **Continuous scale** ไม่ใช่ breakpoints — รองรับทุกขนาดจอ
- **Zone-based HUD layout** ป้องกัน overlap อัตโนมัติ
- **Viewport listener ตัวเดียว** สำหรับทุก element

---

## Part 1: Core Module — `AdaptiveLayout.luau`

**Location:** `src/shared/AdaptiveLayout.luau`

### Safe Area Calculation

```lua
ViewportSize = Camera.ViewportSize
GuiInset = GuiService:GetGuiInset()  -- Roblox top bar (health, backpack etc.)

SafeArea = {
    width  = ViewportSize.X,
    height = ViewportSize.Y - GuiInset.Y,
}
```

**หมายเหตุ CoreUISafeInsets:** MainUI ตั้ง `ScreenGui.ScreenInsets = CoreUISafeInsets` ซึ่ง Roblox จะ
ตัด notch/Dynamic Island/status bar ออกจาก coordinate space ให้แล้ว การลบ `GuiInset.Y` เพิ่มเติม
คือเพื่อเว้นพื้นที่ Roblox top bar (health, backpack) ที่อยู่ **ภายใน** safe area ไม่ใช่ double-count
ต้องทดสอบบน iPhone 14 Pro (Dynamic Island) เพื่อยืนยันว่า safe area ไม่เล็กเกินจริง

### Scale Formula

```lua
DESIGN_VIEWPORT = { width = 1920, height = 1080 }  -- desktop baseline
MIN_SCALE = 0.4
MAX_SCALE = 1.0

scale = math.clamp(
    math.min(SafeArea.width / DESIGN_VIEWPORT.width,
             SafeArea.height / DESIGN_VIEWPORT.height),
    MIN_SCALE, MAX_SCALE
)
```

- สูตรเดียวใช้ทั้ง modal + HUD
- Continuous — ไม่มี hardcoded breakpoint
- MIN_SCALE = 0.4 ป้องกันเล็กจนอ่านไม่ออก
- **หมายเหตุ:** บน phone ส่วนใหญ่ scale จะชน MIN_SCALE (0.4) เพราะ width ratio ต่ำมาก
  (เช่น iPhone SE: 375/1920 = 0.195 → clamp เป็น 0.4) — นี่คือ behavior ที่ตั้งใจ

### Client-Only Module

แม้ไฟล์อยู่ใน `src/shared/` (ตาม convention ของ ResponsiveScale เดิม) แต่ module นี้ใช้ client-only
APIs (`workspace.CurrentCamera`, `GuiService`) — **ต้อง require จาก client scripts เท่านั้น**
ใส่ comment ที่หัวไฟล์: `-- CLIENT ONLY: requires Camera and GuiService`

### Device Type (metadata hint, ไม่ใช่ breakpoint)

```lua
deviceType = "Phone" | "Tablet" | "Desktop"
-- Phone: SafeArea.height < 500
-- Tablet: SafeArea.height 500-900
-- Desktop: SafeArea.height > 900
```

ใช้เป็น hint สำหรับ zone layout (เช่น Rankings จำกัด top 3 บน Phone) — ไม่ใช้กำหนด scale

### Viewport Listener — ตัวเดียว

```lua
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    -- recalculate safe area + scale
    -- notify ทุก registered element
end)
```

- `init()` เรียกครั้งเดียวจาก `MainUI.luau`
- ทุก element register ผ่าน callback

### Public API & Types

```lua
export type DeviceType = "Phone" | "Tablet" | "Desktop"

export type ZoneName = "TopLeft" | "TopCenter" | "TopRight"
    | "BottomLeft" | "BottomCenter" | "BottomRight"

export type ZoneConfig = {
    order: number,              -- ลำดับใน zone (1 = ชิดขอบสุด)
    padding: number?,           -- ระยะห่าง (default 8)
    direction: ("Up" | "Down")?, -- stack direction (default จาก zone)
    designWidth: number?,       -- ขนาด design สำหรับคำนวณ stacking
    designHeight: number?,      -- (ถ้าไม่ใส่ ใช้ frame.AbsoluteSize)
}

AdaptiveLayout.init()                                       -- เรียกครั้งเดียว
AdaptiveLayout.getScale() -> number                         -- scale ปัจจุบัน
AdaptiveLayout.getSafeArea() -> {width: number, height: number}
AdaptiveLayout.getDeviceType() -> DeviceType
AdaptiveLayout.onChanged(callback: () -> ()) -> () -> ()    -- returns unsubscribe fn
AdaptiveLayout.applyScale(frame, designW, designH)          -- สำหรับ modals
AdaptiveLayout.registerHUD(frame, zone, config) -> () -> () -- returns unregister fn
AdaptiveLayout.unregisterHUD(frame)                         -- explicit cleanup
AdaptiveLayout.compensateStrokes(frame)                     -- UIStroke fix
```

### Cleanup / Unregister

- `registerHUD()` return ฟังก์ชัน unregister — เรียกเมื่อ element ถูก destroy
- `unregisterHUD(frame)` สำหรับ explicit cleanup
- ระบบตรวจ orphaned entries (frame.Parent == nil) อัตโนมัติทุกรอบ viewport change
  และลบออกจาก zone — ป้องกัน stale references

---

## Part 2: Zone System — HUD Layout

### Zone Map

```
┌──────────────────────────────────┐
│ TopLeft      TopCenter  TopRight │
│                                  │
│              Center              │
│           (modals only)          │
│                                  │
│ BottomLeft BottomCenter BottomRight│
└──────────────────────────────────┘
```

### Zone Anchoring & Position

แต่ละ zone มี anchor point และ starting position ที่ชัดเจน:

| Zone | AnchorPoint | Starting Position | Default Direction |
|------|-------------|-------------------|-------------------|
| TopLeft | (0, 0) | (0, padding, 0, padding) | Down |
| TopCenter | (0.5, 0) | (0.5, 0, 0, padding) | Down |
| TopRight | (1, 0) | (1, -padding, 0, padding) | Down |
| BottomLeft | (0, 1) | (0, padding, 1, -padding) | Up |
| BottomCenter | (0.5, 1) | (0.5, 0, 1, -padding) | Up |
| BottomRight | (1, 1) | (1, -padding, 1, -padding) | Up |

### Zone Registration

```lua
AdaptiveLayout.registerHUD(gemsFrame, "BottomLeft", {
    order = 1,              -- ลำดับใน zone (1 = ชิดขอบสุด)
    padding = 8,            -- ระยะห่างระหว่าง elements
    designWidth = 130,      -- ใช้คำนวณ stacking (ไม่พึ่ง AbsoluteSize)
    designHeight = 44,
})
```

### Auto-Stacking

Elements ใน zone เดียวกัน stack อัตโนมัติตาม order:

```
BottomLeft (direction = Up):
  ┌─ Stage (order=3)   Y = gems.top - padding
  ├─ Coins (order=2)   Y = stage.top - padding
  └─ Gems (order=1)    Y = bottom - padding  (ชิดล่างสุด)

BottomCenter (direction = Up):
  └─ ItemBar (order=1)  Y = bottom - padding
```

**สำคัญ:** ระบบคำนวณ position จาก `designSize * scale` (**ไม่ใช่** `AbsoluteSize`)
เพราะ `AbsoluteSize` อาจ stale 1 frame หลัง UIScale เปลี่ยน — ใช้ค่าที่คำนวณได้ทันทีเพื่อความแม่นยำ

### Zone Recalculation Triggers

Zone positions ถูกคำนวณใหม่เมื่อ:
1. **Viewport เปลี่ยน** — ผ่าน Camera listener
2. **Element visibility เปลี่ยน** — `Visible = false` จะถูก skip ในการ stack
3. **Element ถูก register/unregister** — เพิ่ม/ลบ element จาก zone

Elements ที่ `Visible = false` จะไม่ถูกนับใน stacking — elements ถัดไปจะขยับเข้ามาแทนที่

### Zone Assignments

| Element | Zone | Order | Direction |
|---------|------|-------|-----------|
| Gems (ScoreUI) | BottomLeft | 1 | Up |
| Coins (CurrencyUI) | BottomLeft | 2 | Up |
| Stage Counter | BottomLeft | 3 | Up |
| Menu Grid | BottomLeft | 4 | Up |
| Item Bar (ItemUI) | BottomCenter | 1 | Up |
| Rankings (Spectator) | TopRight | 1 | Down |
| Rankings (MatchLobby) | TopRight | 1 | Down |
| Spectate Prompt | BottomCenter | 2 | Up |
| Spectator Controls | BottomCenter | 3 | Up |

**หมายเหตุ:** Gems/Coins/Stage อยู่ **BottomLeft** (ตรงกับตำแหน่งปัจจุบัน) ไม่ใช่ TopLeft

### Elements ที่ไม่อยู่ใน Zone System

| Element | เหตุผล |
|---------|--------|
| TimerFrame (ScoreUI) | อยู่ TopCenter ตายตัว, ไม่ต้อง stack กับอะไร — ใช้ HUD scale ตรงๆ |
| RaceTimer (MatchLobbyUI) | TopCenter fixed position, same pattern as TimerFrame — ใช้ HUD scale ตรงๆ |
| Notifications (TimeWarning, Death, Invite) | Transient labels ขนาดเล็ก, ใช้ relative position (0.5, X) อยู่แล้ว |
| ItemUI on mobile | ซ่อนถาวร (`Visible = false`) — MobileInputUI ทำหน้าที่แทน |
| LeaderboardUI | Server-side SurfaceGui, ไม่ใช่ ScreenGui |

### Phone-Specific Adjustments

เมื่อ `deviceType == "Phone"`:
- Rankings จำกัด top 3 entries — ทั้ง SpectatorUI rankings **และ** MatchLobbyUI race rankings
- Menu Grid ใช้ compact layout
- ไม่เปลี่ยน zone — แค่ลด content ภายใน element

---

## Part 3: Modal Scaling

### Scale Calculation

```lua
MODAL_MARGIN = 60  -- 30px รอบด้าน

modalScale = math.clamp(
    math.min(
        (SafeArea.width - MODAL_MARGIN) / designWidth,
        (SafeArea.height - MODAL_MARGIN) / designHeight
    ),
    0.4, 1.0
)
```

- ใช้ design dimensions ของ modal นั้นๆ (ไม่ใช่ DESIGN_VIEWPORT)
- Modal 780x580 บนจอเล็กจะ scale ต่างจาก Modal 360x380
- ทุก modal center กลางจอ (`AnchorPoint = 0.5, 0.5`)

### UIStroke Compensation

```lua
AdaptiveLayout.compensateStrokes(frame)
```

- ค้นหา UIStroke ทุกตัวใน frame tree
- เก็บ original thickness ใน attribute `_originalThickness`
- คูณด้วย scale: `stroke.Thickness = original * modalScale`
- เรียกอัตโนมัติเมื่อ viewport เปลี่ยน
- **API change:** signature เปลี่ยนจาก `(frame, scale)` → `(frame)` — scale อ่านจาก module ภายใน
  call sites เดิมที่ส่ง scale เป็น parameter ต้องลบ argument ที่ 2 ออก

### Modal vs HUD Scale

| | Modal Scale | HUD Scale |
|--|------------|-----------|
| คำนวณจาก | SafeArea vs modal design size | SafeArea vs DESIGN_VIEWPORT |
| Margin | 60px (เว้นขอบ) | Zone padding 8px |
| Range | 0.4 — 1.0 | 0.4 — 1.0 |
| ใช้กับ | Popup panels ตรงกลาง | Edge-anchored HUD |

---

## Part 4: Integration & Migration

### ไฟล์ใหม่

| ไฟล์ | หน้าที่ |
|------|--------|
| `src/shared/AdaptiveLayout.luau` | Core module แทนที่ ResponsiveScale |
| `src/shared/__tests__/AdaptiveLayout.spec.luau` | Unit tests |

### ไฟล์ที่แก้ไข

**Modal panels (เปลี่ยน ResponsiveScale → AdaptiveLayout.applyScale):**

| ไฟล์ | เปลี่ยนอะไร |
|------|------------|
| `MainUI.luau` | `ResponsiveScale.init()` → `AdaptiveLayout.init()` |
| `UIFactory.luau` | `ResponsiveScale.applyToFrame()` → `AdaptiveLayout.applyScale()` |
| `ClassSelectionUI.luau` | เปลี่ยน require + applyScale |
| `DailyBonusUI.luau` | เปลี่ยน require + applyScale |
| `FeedbackUI.luau` | เปลี่ยน require + applyScale |
| `MatchLobbyUI.luau` | เปลี่ยน require + applyScale (modal container) |
| `RaceResultsUI.luau` | เปลี่ยน require + applyScale |
| `SettingsUI.luau` | เปลี่ยน require + applyScale |
| `ShopUI.luau` | เปลี่ยน require + applyScale |
| `StageSelectionUI.luau` | เปลี่ยน require + applyScale |
| `SummaryUI.luau` | เปลี่ยน require + applyScale |
| `TitleCollectionUI.luau` | เปลี่ยน require + applyScale |
| `TutorialUI.luau` | เปลี่ยน require + applyScale |

**HUD elements (ลบ viewport listeners → registerHUD):**

| ไฟล์ | เปลี่ยนอะไร |
|------|------------|
| `ScoreUI.luau` | ลบ viewport listener → `registerHUD` x2: gemFrame(BottomLeft, order=1), stageFrame(BottomLeft, order=3) |
| `CurrencyUI.luau` | ลบ viewport listener → `registerHUD("BottomLeft", order=2)` |
| `SpectatorUI.luau` | ลบ 3 UIScale instances → `registerHUD` x3: rankings(TopRight,1), prompt(BottomCenter,2), controlBar(BottomCenter,3) |
| `MatchLobbyUI.luau` | ลบ custom UIScale rankings → `registerHUD("TopRight")` |
| `MenuGridUI.luau` | ลบ viewport listener → `registerHUD("BottomLeft", order=4)` |
| `ItemUI.luau` | `registerHUD("BottomCenter", order=1)` — desktop only, ซ่อนบน mobile (Visible=false → zone skips) |

**Cleanup:**

| ไฟล์ | เปลี่ยนอะไร |
|------|------------|
| `LeaderboardUI.luau` | ลบ commented-out ResponsiveScale imports |

**หมายเหตุ:** MatchLobbyUI อยู่ **ทั้ง 2 กลุ่ม** — modal container ใช้ applyScale, rankings panel ใช้ registerHUD

### ไฟล์ที่ลบ

- `src/shared/ResponsiveScale.luau`
- `src/shared/__tests__/ResponsiveScale.spec.luau`

### Migration Order

1. สร้าง `AdaptiveLayout.luau` + unit tests
2. Modals — เปลี่ยน UIFactory + 12 panels (ทีละไฟล์ ทดสอบผ่าน MCP)
3. HUD ทีละตัว — ScoreUI → CurrencyUI → MenuGrid → ItemBar → SpectatorUI → MatchLobbyUI
4. ลบ ResponsiveScale — **ก่อนลบ ต้อง grep `ResponsiveScale` ใน src/ ยืนยัน 0 references**
5. ทดสอบบน Device Emulator + Roblox Studio MCP

### Testing Plan

#### Unit Tests (`AdaptiveLayout.spec.luau`)

1. **Scale calculation** — phone (375×667), tablet (810×1080), desktop (1920×1080)
2. **Modal scale with margin** — 780×580 modal on phone, tablet, desktop
3. **MIN_SCALE floor** — verify scale never goes below 0.4
4. **MAX_SCALE cap** — verify scale never exceeds 1.0
5. **Device type classification** — thresholds 500/900
6. **Zone stacking positions** — 3 elements in BottomLeft, verify Y offsets
7. **Zone skip invisible** — element with Visible=false, verify stacking skips it
8. **Stroke compensation** — idempotent, correct thickness at various scales
9. **Orphan cleanup** — unparented frame removed from tracking
10. **Unregister** — removed element recalculates zone positions

#### Roblox Studio MCP (ระหว่าง Development)

- `screen_capture` — ถ่าย screenshot ดู UI ผลลัพธ์
- `execute_luau` — ทดสอบ scale calculation, ตรวจ UIScale values
- `inspect_instance` — ตรวจ properties (Size, Position, UIScale)
- `start_stop_play` — Play test บน Device Emulator

#### Device Emulator ขนาดทดสอบ

- iPhone SE (375×667) — จอเล็กสุด
- iPhone 14 (390×844) — phone ยอดนิยม
- iPhone 14 Pro Max (430×932) — phone จอยาว + Dynamic Island (ทดสอบ CoreUISafeInsets)
- iPad (810×1080) — tablet
- iPad landscape (1080×810) — width > height, ทดสอบ constraint axis ต่าง
- Desktop 1920×1080 — baseline

#### เกณฑ์ผ่าน

- Modal ไม่ล้นจอทุกขนาด
- HUD ไม่ซ้อนทับกัน
- Scale สม่ำเสมอ ดูเป็นธรรมชาติ
- Device Emulator ≈ มือถือจริง
- UIStroke ไม่หนาเกินสัดส่วนบนจอเล็ก
