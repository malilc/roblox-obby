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
GuiInset = GuiService:GetGuiInset()  -- top bar (48px on mobile)

SafeArea = {
    width  = ViewportSize.X,
    height = ViewportSize.Y - GuiInset.Y,
}
```

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

### Public API

```lua
AdaptiveLayout.init()                                  -- เรียกครั้งเดียว
AdaptiveLayout.getScale() -> number                    -- scale ปัจจุบัน
AdaptiveLayout.getSafeArea() -> {width: number, height: number}
AdaptiveLayout.getDeviceType() -> "Phone" | "Tablet" | "Desktop"
AdaptiveLayout.onChanged(callback: () -> ())           -- register listener
AdaptiveLayout.applyScale(frame, designW, designH)     -- สำหรับ modals
AdaptiveLayout.registerHUD(frame, zone, config)        -- สำหรับ HUD
AdaptiveLayout.compensateStrokes(frame)                -- UIStroke fix
```

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

### Zone Registration

```lua
AdaptiveLayout.registerHUD(gemsFrame, "TopLeft", {
    order = 1,           -- ลำดับใน zone (1 = ชิดขอบสุด)
    padding = 8,         -- ระยะห่างระหว่าง elements
    direction = "Down",  -- stack direction
})
```

### Auto-Stacking

Elements ใน zone เดียวกัน stack อัตโนมัติตาม order:

```
TopLeft (direction = Down):
  ┌─ Gems (order=1)    Y = padding
  ├─ Coins (order=2)   Y = gems.bottom + padding
  └─ Stage (order=3)   Y = coins.bottom + padding

BottomCenter (direction = Up):
  └─ ItemBar (order=1)  Y = bottom - padding
```

ระบบคำนวณ position จาก actual size ของ element ก่อนหน้า × scale

### Zone Assignments

| Element | Zone | Order | Direction |
|---------|------|-------|-----------|
| Gems (ScoreUI) | TopLeft | 1 | Down |
| Coins (CurrencyUI) | TopLeft | 2 | Down |
| Stage Counter | TopLeft | 3 | Down |
| Menu Grid | BottomLeft | 1 | Up |
| Item Bar | BottomCenter | 1 | Up |
| Rankings | TopRight | 1 | Down |
| Spectate Prompt | BottomCenter | 2 | Up |

### Phone-Specific Adjustments

เมื่อ `deviceType == "Phone"`:
- Rankings จำกัด top 3 entries (ลดความสูง)
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

| ไฟล์ | เปลี่ยนอะไร |
|------|------------|
| `MainUI.luau` | `ResponsiveScale.init()` → `AdaptiveLayout.init()` |
| `UIFactory.luau` | เปลี่ยนเป็น `AdaptiveLayout.applyScale()` |
| 9 Modal panels | เปลี่ยน require + เรียก `applyScale` แทน |
| `ScoreUI.luau` | ลบ viewport listener → `registerHUD("TopLeft", order=1)` |
| `CurrencyUI.luau` | ลบ viewport listener → `registerHUD("TopLeft", order=2)` |
| `SpectatorUI.luau` | ลบ 3 UIScale instances → `registerHUD` per element |
| `MatchLobbyUI.luau` | ลบ custom UIScale → `registerHUD("TopRight")` |
| `MenuGridUI.luau` | ลบ viewport listener → `registerHUD("BottomLeft")` |
| `ItemBarUI.luau` | `registerHUD("BottomCenter")` |

### ไฟล์ที่ลบ

- `src/shared/ResponsiveScale.luau`
- `src/shared/__tests__/ResponsiveScale.spec.luau`

### Migration Order

1. สร้าง `AdaptiveLayout.luau` + unit tests
2. Modals — เปลี่ยน UIFactory + 9 panels
3. HUD ทีละตัว — ScoreUI → CurrencyUI → MenuGrid → ItemBar → SpectatorUI → MatchLobbyUI
4. ลบ ResponsiveScale หลังทุก reference หายหมด
5. ทดสอบบน Device Emulator + Roblox Studio MCP

### Testing Plan (Roblox Studio MCP)

**ระหว่าง Development:**
- `screen_capture` — ถ่าย screenshot ดู UI ผลลัพธ์
- `execute_luau` — ทดสอบ scale calculation, ตรวจ UIScale values
- `inspect_instance` — ตรวจ properties (Size, Position, UIScale)
- `start_stop_play` — Play test บน Device Emulator

**Device Emulator ขนาดทดสอบ:**
- iPhone SE (375×667) — จอเล็กสุด
- iPhone 14 (390×844) — phone ยอดนิยม
- iPad (810×1080) — tablet
- Desktop 1920×1080 — baseline

**เกณฑ์ผ่าน:**
- Modal ไม่ล้นจอทุกขนาด
- HUD ไม่ซ้อนทับกัน
- Scale สม่ำเสมอ ดูเป็นธรรมชาติ
- Device Emulator ≈ มือถือจริง
