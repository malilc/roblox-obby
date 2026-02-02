---
name: Mario Kart Obby Roadmap
overview: แผน Roadmap สำหรับพัฒนาเกม Roblox Obby ให้เป็นเกมแข่งแบบ multiplayer พร้อม Item system แบบ Mario Kart และ Character Class system
todos:
  - id: phase1-match-manager
    content: "Phase 1.1: สร้าง MatchManager.luau - ระบบสร้าง/เข้าร่วมห้องแข่ง รองรับ solo mode"
    status: completed
  - id: phase1-match-ui
    content: "Phase 1.2: สร้าง MatchLobbyUI.luau - UI แสดงห้องแข่ง, รายชื่อผู้เล่น, countdown"
    status: completed
  - id: phase1-time-limit
    content: "Phase 1.2: สร้างระบบ Time Limit 15 นาที + แจ้งเตือนใกล้หมดเวลา"
    status: completed
  - id: phase1-race-state
    content: "Phase 1.3: ปรับ GameManager ให้จัดการ race state, ranking, finish order"
    status: completed
  - id: phase2-item-types
    content: "Phase 2.1: สร้าง ItemTypes.luau - นิยาม items 6 ชนิด (Missile, Banana, Shield, Boost, Swap, Lightning)"
    status: completed
  - id: phase2-item-logic
    content: "Phase 2.2: แก้ไข ItemManager - ระบบ weighted random, item effects, cooldowns"
    status: completed
  - id: phase2-item-ui
    content: "Phase 2.3: ปรับ ItemUI + สร้าง ItemRouletteUI - แสดง item slot, roulette animation"
    status: completed
  - id: phase3-class-types
    content: "Phase 3.1: สร้าง ClassTypes.luau - นิยาม 3 classes (Runner, Jumper, Tank)"
    status: completed
  - id: phase3-class-manager
    content: "Phase 3.2: สร้าง ClassManager.luau - apply class stats, passive abilities"
    status: completed
  - id: phase3-class-ui
    content: "Phase 3.3: สร้าง ClassSelectionUI.luau - UI เลือก class ก่อนเข้าห้อง"
    status: completed
  - id: phase4-integration
    content: "Phase 4: Integration - เชื่อมทุกระบบเข้าด้วยกัน, Race results, Victory screen"
    status: completed
  - id: phase4-balance
    content: "Phase 4: Balance testing - ทดสอบและปรับค่า items/classes"
    status: completed
isProject: false
---

# Roadmap: Mario Kart Style Racing Obby

## สรุปภาพรวม

พัฒนาเกม Obby ปัจจุบันให้เป็นเกมแข่งขัน multiplayer พร้อมระบบ Item แบบ Mario Kart และ Character Classes ที่มีความสามารถต่างกัน

---

## Phase 1: Multiplayer Race System (ระบบแข่งขันหลายคน)

### 1.1 Matchmaking Lobby System

สร้างระบบ Matchmaking ให้ผู้เล่นสามารถเข้าร่วมห้องแข่งได้

**ไฟล์ที่ต้องสร้าง/แก้ไข:**

- `src/server/MatchManager.luau` - จัดการห้องแข่ง, รอผู้เล่น, เริ่มเกม
- `src/client/UI/MatchLobbyUI.luau` - UI แสดงรายชื่อผู้เล่นในห้อง
- แก้ไข `src/shared/Config.luau` - เพิ่ม Match settings

**ฟังก์ชันหลัก:**

- `MatchManager:createRoom(host, settings)` - สร้างห้องแข่ง
- `MatchManager:joinRoom(player, roomId)` - เข้าร่วมห้อง
- `MatchManager:startMatch(roomId)` - เริ่มการแข่ง
- รองรับเล่นคนเดียว (Solo mode) สำหรับ testing

**Match Settings:**

- จำนวนผู้เล่น: 1-16 คน
- รอเวลา: 3 วินาที (Testing mode) - ปรับเป็น 30-60 วินาทีใน Production
- สุ่ม/เลือกด่าน

**Config ที่ต้องเพิ่ม:**

```lua
Match = {
    MinPlayers = 1,        -- Solo testing
    MaxPlayers = 16,
    WaitTime = 3,          -- Testing: 3 วิ, Production: 30-60 วิ
    IsTestingMode = true,  -- Toggle สำหรับ testing
}
```

### 1.2 Race Time Limit System

**ระบบจำกัดเวลาต่อรอบ:**

- เวลาสูงสุด: 15 นาที (900 วินาที)
- แจ้งเตือนเมื่อเหลือ: 5 นาที, 1 นาที, 30 วินาที, 10 วินาที
- เมื่อหมดเวลา: จบการแข่งทันที คนที่ไปได้ไกลสุดชนะ

**UI Components:**

- Timer แสดงเวลาที่เหลือ (มุมบนจอ)
- แจ้งเตือนกลางจอเมื่อใกล้หมด (พร้อมเสียง)
- สีเปลี่ยนเมื่อเหลือน้อย (เขียว → เหลือง → แดง)

### 1.3 Race State Management

จัดการสถานะการแข่งขัน

**เพิ่มใน GameManager:**

- ติดตาม ranking แบบ real-time
- จัดการ finish order
- ระบบ spectate เมื่อจบก่อน

### 1.4 Leaderboard และ Race Results

แสดงผลการแข่งขัน

**UI Components:**

- Real-time position indicator (อันดับ 1, 2, 3...)
- Mini-map แสดงตำแหน่งผู้เล่น (optional)
- Race results screen เมื่อจบ

---

## Phase 2: Item System (ระบบไอเทมแบบ Mario Kart)

### 2.1 Item Framework

ปรับปรุงระบบ Item ให้รองรับหลายชนิด

**ไฟล์ที่ต้องสร้าง/แก้ไข:**

- `src/shared/ItemTypes.luau` - นิยาม item ทั้งหมด
- แก้ไข `src/server/ItemManager.luau` - ปรับให้รองรับหลาย item
- แก้ไข `src/client/UI/ItemUI.luau` - แสดง item ที่ถืออยู่

**Item Pickup System:**

- Item Box (เหมือนที่มีอยู่) - สุ่มได้ item ต่างๆ
- ระบบ weighted random ตามอันดับ (คนท้าย = item ดีกว่า)

### 2.2 รายการ Items (5-6 ชนิด)


| Item                           | ผลลัพธ์                             | Rarity    |
| ------------------------------ | ----------------------------------- | --------- |
| **Missile (ขีปนาวุธ)**         | ยิงตรงไปข้างหน้า ชนแล้ว stun 2 วิ   | Common    |
| **Banana (กล้วย)**             | วางไว้บนพื้น ใครเหยียบลื่นล้ม       | Common    |
| **Shield (โล่)**               | ป้องกัน item 1 ครั้ง                | Uncommon  |
| **Speed Boost (เร่งความเร็ว)** | เพิ่มความเร็ว 50% เป็นเวลา 3 วิ     | Uncommon  |
| **Swap (สลับตำแหน่ง)**         | สลับที่กับคนอันดับ 1                | Rare      |
| **Lightning (ฟ้าผ่า)**         | ทำให้ทุกคนช้าลง 3 วิ (ยกเว้นตัวเอง) | Very Rare |


### 2.3 Item Effects Implementation

```lua
-- ตัวอย่างโครงสร้าง ItemTypes.luau
local ItemTypes = {
    Missile = {
        name = "Missile",
        icon = "rbxassetid://XXX",
        rarity = 0.25, -- 25% chance
        onUse = function(player) ... end,
    },
    Banana = { ... },
    -- etc.
}
```

**Visual Effects ที่ต้องสร้าง:**

- Missile trail effect
- Banana slip animation
- Shield bubble
- Speed boost particles
- Swap teleport effect
- Lightning strike

---

## Phase 3: Character Class System (ระบบคลาสตัวละคร)

### 3.1 Class Framework

สร้างระบบ class ให้ผู้เล่นเลือก

**ไฟล์ที่ต้องสร้าง/แก้ไข:**

- `src/shared/ClassTypes.luau` - นิยาม class ทั้งหมด
- `src/server/ClassManager.luau` - จัดการ class ของผู้เล่น
- `src/client/UI/ClassSelectionUI.luau` - UI เลือก class

### 3.2 รายการ Classes (3 ชนิด)


| Class      | ความสามารถพิเศษ          | จุดเด่น   | จุดด้อย        |
| ---------- | ------------------------ | --------- | -------------- |
| **Runner** | +15% WalkSpeed           | เร็ว      | JumpPower -10% |
| **Jumper** | +20% JumpPower           | กระโดดสูง | WalkSpeed -10% |
| **Tank**   | Knockback resistance 50% | อึด       | WalkSpeed -15% |


### 3.3 Class Abilities (Passive)

แต่ละ class มี passive ability:

- **Runner**: Double tap W = mini boost (cooldown 15 วิ)
- **Jumper**: กดค้าง Space = charged jump (กระโดดสูงขึ้น)
- **Tank**: ไม่โดน stun จาก item ระดับ Common

---

## Phase 4: Integration และ Polish

### 4.1 UI/UX Improvements

- Class selection ก่อนเข้าห้อง
- Item roulette animation เมื่อเก็บ Item Box
- Race countdown (3, 2, 1, GO!)
- Victory/Podium screen

### 4.2 Balance และ Testing

- ทดสอบ item balance
- ปรับค่า class stats
- Bug fixes

### 4.3 Progression System (Optional)

- Unlock classes ด้วย Currency
- Class levels และ upgrades
- Achievement badges

---

## สรุป Dependencies

```
Phase 1 (Race) ─────────────┐
                            ├──► Phase 4 (Integration)
Phase 2 (Items) ────────────┤
                            │
Phase 3 (Classes) ──────────┘
```

**หมายเหตุ:** Phase 1, 2, 3 สามารถทำแบบ parallel ได้บางส่วน แต่ควรทำ Phase 1 (Race system) ก่อนเพื่อให้มี multiplayer foundation

---

## ไฟล์ที่ต้องสร้างใหม่

- `src/server/MatchManager.luau`
- `src/server/ClassManager.luau`
- `src/shared/ItemTypes.luau`
- `src/shared/ClassTypes.luau`
- `src/client/UI/MatchLobbyUI.luau`
- `src/client/UI/ClassSelectionUI.luau`
- `src/client/UI/RaceResultsUI.luau`
- `src/client/UI/ItemRouletteUI.luau`

## ไฟล์ที่ต้องแก้ไข

- `src/server/GameManager.luau` - เพิ่ม race logic
- `src/server/ItemManager.luau` - รองรับ multi-item
- `src/shared/Config.luau` - เพิ่ม settings ใหม่
- `src/client/UI/ItemUI.luau` - แสดง item หลายชนิด
- `default.project.json` - เพิ่ม RemoteEvents ใหม่

