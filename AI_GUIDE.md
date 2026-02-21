# AI Development Guide - Roblox Obby Game

คู่มือสำหรับ AI ที่จะมาพัฒนาต่อ

## 📁 Project Structure

```
src/
├── server/                      # Server-side code
│   ├── init.server.luau         # Entry point - สร้าง GameManager
│   ├── GameManager.luau         # ควบคุมเกมทั้งหมด (orchestrator)
│   ├── MapManager.luau          # จัดการ map/stages + animations + per-match instancing
│   ├── ScoreManager.luau        # ระบบคะแนน + DataStore (ผ่าน DataStoreHelper)
│   ├── CurrencyManager.luau     # 💰 ระบบเงิน + Class Unlock + Mastery + Daily Login + DataStore
│   ├── ItemManager.luau         # 🎯 ระบบ Items แบบ Mario Kart
│   ├── MatchManager.luau        # 🏁 ระบบ Matchmaking/Race + Stage Voting
│   ├── ClassManager.luau        # 🎭 ระบบ Character Classes
│   ├── LeaderboardManager.luau  # 🏆 Global Leaderboard (OrderedDataStore + Physical Board)
│   ├── SpectatorManager.luau    # 👁️ ระบบ Spectator Mode (แยกจาก GameManager)
│   ├── SelectionZoneManager.luau # ⭐ ระบบ SelectionZone detection + stage confirm (แยกจาก GameManager)
│   ├── DataStoreHelper.luau     # 💾 Centralized DataStore utilities + retry logic + schema versioning
│   └── StageTemplates.luau      # ⭐ สร้างด่าน obby ที่นี่
│
├── client/                      # Client-side code
│   ├── init.client.luau         # Entry point
│   ├── FlyController.luau       # ระบบบินทดสอบ (กด F)
│   ├── ItemEffects.luau         # 🎯 Screen effects (shake, flash, zoom)
│   ├── SoundManager.luau        # 🔊 BGM + SFX manager (ใส่ rbxassetid ใน SOUNDS table)
│   ├── TweenHelper.luau         # 🎨 Reusable tween/animation utilities (pop, fadeIn, slideIn, etc.)
│   ├── UltimateSkillController.luau # ⚡ Ultimate Skills (Sprint, Double Jump, Iron Will)
│   ├── SpectatorCamera.luau     # 👁️ กล้อง Follow + FreeCam สำหรับ Spectator Mode
│   └── UI/
│       ├── MainUI.luau          # Controller หลัก (popup mutual exclusion)
│       ├── UIFactory.luau       # 🏗️ Reusable UI component factory (createPanel/Button/Label/Modal)
│       ├── ScoreUI.luau         # แสดงคะแนน
│       ├── CurrencyUI.luau      # 💰 แสดงเงิน
│       ├── ItemUI.luau          # 🎯 แสดง Item (2 slots) + Tooltip
│       ├── ItemTestingUI.luau   # 🧪 UI ทดสอบ Item (กด T)
│       ├── MasteryTestingUI.luau # 🧪 UI ทดสอบ Mastery (กด M)
│       ├── StageSelectionUI.luau # ⭐ GUI เลือกลำดับด่าน
│       ├── SummaryUI.luau       # 🏆 แสดง Summary จบเกม
│       ├── MatchLobbyUI.luau    # 🏁 UI Matchmaking lobby
│       ├── ClassSelectionUI.luau # 🎭 UI เลือก Class
│       ├── TitleHUDUI.luau      # 🏷️ HUD แสดง Active Title
│       ├── TitleCollectionUI.luau # 🏷️ หน้ารายการ Title (ล็อก/ปลดล็อก + filter/search)
│       ├── RaceResultsUI.luau   # 🏁 UI ผลการแข่ง
│       ├── TutorialUI.luau      # ❓ Game Guide popup (ปุ่ม "?" + 5 tabs RichText)
│       ├── SpectatorUI.luau     # 👁️ Spectator HUD + prompt + rankings
│       ├── DailyBonusUI.luau    # 🎁 Daily Login 7-day calendar popup + HUD button
│       ├── LeaderboardUI.luau   # 🏆 Stub เท่านั้น (physical board สร้างโดย LeaderboardManager)
│       └── MobileInputUI.luau   # 📱 Touch buttons สำหรับมือถือ (Item/Sprint/Jump)
│
└── shared/                      # Shared code (server + client)
    ├── Config.luau              # ⭐ ค่า Config ทั้งหมด (+ Debug flags + Ultimate Skills + Timing + Map)
    ├── StageInfo.luau           # ⭐ Stage metadata (name, icon, difficulty, color, reward) — single source of truth
    ├── Types.luau               # Type definitions
    ├── Logger.luau              # 🔧 Centralized logging (configurable levels)
    ├── RemoteRegistry.luau      # 📡 Centralized RemoteEvent access with caching + WaitForChild fallback
    ├── ItemTypes.luau           # 🎯 นิยาม Items ทั้งหมด
    └── ClassTypes.luau          # 🎭 นิยาม Classes ทั้งหมด (+ ultimateSkill field)
```

---

## 🏠 Workspace Structure

```
Workspace/
├── SpawnLocation          # จุดเกิดเริ่มต้น (Neon Cyan)
├── Lobby/                 # Folder เก็บ Lobby ทั้งหมด (Synthwave Arcade Theme)
│   ├── ArcadeFloor        # พื้น SmoothPlastic สีดำเข้ม
│   ├── ArcadeCeiling      # เพดาน SmoothPlastic สีดำเข้ม
│   ├── GlassWall_N/S/E/W  # ผนัง Glass สีม่วงเข้ม (4 ด้าน)
│   ├── FrameCorner_NE/NW/SE/SW  # เสามุมห้อง Neon Cyan (4 ต้น)
│   ├── FloorNeon_N/S/E/W  # ขอบพื้น Neon Cyan (4 เส้น)
│   ├── CeilLight_1/2/3    # แถบไฟ Neon Magenta ใต้เพดาน (3 เส้น)
│   ├── GridH_1-4          # เส้น Grid แนวนอน บนพื้น (Neon น้ำเงินจาง)
│   ├── GridV_1-4          # เส้น Grid แนวตั้ง บนพื้น (Neon น้ำเงินจาง)
│   └── SelectionZone      # ⭐ Zone เลือกด่าน (Neon Magenta)
├── GlobalLeaderboard      # 🏆 Part สำหรับ physical leaderboard board (สร้างอัตโนมัติถ้าไม่มี)
├── Stages/                # Folder เก็บด่านที่ generate
└── KillBrick              # พื้นที่ตายเมื่อตก
```

**สำคัญ**: 
- `SpawnLocation` ต้องอยู่ใน Workspace โดยตรง ไม่ใช่ใน Folder
- `SelectionZone` ใช้ loop-based detection (เสถียรกว่า Touched events)
- `GlobalLeaderboard` ถ้าวาง Part ไว้ใน workspace ก่อน จะใช้ตำแหน่งนั้น (ไม่สร้างใหม่)

---

## 🎮 ระบบเลือกด่าน (Stage Selection)

### ไฟล์ที่เกี่ยวข้อง:
- `src/shared/StageInfo.luau` - Stage metadata (single source of truth)
- `src/server/SelectionZoneManager.luau` - Zone detection + confirm
- `src/server/MapManager.luau` - Map generation + balanced random
- `src/client/UI/StageSelectionUI.luau` - GUI ฝั่ง Client

### Stage Difficulty System:

| Stage | ชื่อ | Icon | ความยาก | Reward | กลไก |
|-------|------|------|---------|--------|------|
| 1 | Jump | 🦘 | Easy | 3 | แพลตฟอร์มนิ่ง |
| 2 | Moving | ↔️ | Normal | 4 | แพลตฟอร์มเคลื่อนที่ |
| 3 | Spin | 🌀 | Normal | 4 | แท่งหมุน kill part |
| 4 | Disappear | 💨 | Hard | 5 | แพลตฟอร์มหายไป |
| 5 | Combo | ⚡ | Hard | 6 | ผสมทุกกลไก |
| 6 | Lava Rise | 🌋 | Hard | 6 | พื้น kill part ยกตัว + แพลตฟอร์มลอย |
| 7 | Narrow | 🎯 | Hard | 7 | แพลตฟอร์มแคบ + spinner + moving narrow |

- Metadata ทั้งหมดอยู่ใน `StageInfo.luau` (name, icon, difficulty, color, gradientEnd, reward)
- UI ใช้ `StageInfo.getStage(id)` แทน hardcoded arrays
- Server ใช้ `StageInfo.getStage(id).reward` แทน `Config.Currency.StageRewards`

### Balanced Random Algorithm:
- `MapManager:balancedRandomStages()` เลือก `Config.Stages.SelectionCount` ด่านจาก pool ทั้งหมด
- การันตีอย่างน้อย `Config.Stages.BalancedRandom.MinPerDifficulty` (default 1) จากแต่ละระดับความยาก
- เติมที่เหลือจาก pool ที่ยังไม่ถูกเลือก แล้ว shuffle ลำดับสุดท้าย
- เช่น pool 7 ด่าน (1E+2N+4H) เลือก 5 → ได้ประมาณ 1E+2N+2H (เฉลี่ยดี)

### Config ที่เกี่ยวข้อง:
- `Config.Stages.TotalCount` = 7 (จำนวนด่านทั้งหมดใน pool)
- `Config.Stages.SelectionCount` = 5 (จำนวนด่านที่เลือกต่อรอบ, แก้ได้เพื่อ test)

### Difficulty Tabs (StageSelectionUI):

UI แบ่งเป็น 3 tabs ตามความยาก แต่ละ tab แสดงเฉพาะด่านของตัวเอง:

| Tab | สี | ด่านที่แสดง | Layout |
|-----|---|------------|--------|
| EASY | เขียว | Stage 1 (Jump) | 1 ปุ่ม อยู่กลาง |
| NORMAL | เหลือง | Stages 2-3 (Moving, Spin) | 2 ปุ่ม อยู่กลาง |
| HARD | แดง | Stages 4-7 (Disappear-Narrow) | 4 ปุ่ม เต็ม row |

- Selection ข้าม tab ได้ — `selectedStages` เป็น global ไม่ reset เมื่อเปลี่ยน tab
- Tab labels แสดง count ที่เลือก เช่น `HARD (2)`
- `switchTab(difficulty)` → `refreshStageButtons()` จัด visibility+position
- `show()` เรียก `switchTab(self.activeTab)` หลัง reset Visible เสมอ (เพราะ show loop ทำ Visible=true ทุกตัว)
- Default tab: Easy

### Flow:

```
ผู้เล่นเดินเข้า SelectionZone (เดินหาป้าย "SELECT STAGE")
    ↓
Server ส่ง ShowStageSelection → Client
    ↓
Client แสดง GUI: Tab Bar [EASY][NORMAL][HARD] + ปุ่มด่านของ tab ที่เลือก
    ↓
ผู้เล่นคลิก tab เพื่อดูด่านแต่ละระดับ + เลือกด่าน (สูงสุด SelectionCount รวมทุก tab)
    ↓
กด RANDOM หรือ START
    ↓
Client ส่ง ConfirmStageSelection → Server
    ↓
Server สร้าง Map ตามลำดับที่เลือก (RANDOM ใช้ balanced algorithm)
    ↓
Countdown 3, 2, 1 → Teleport ไปด่าน 1
```

### การเลือกด่าน:
- **คลิก tab** - สลับดูด่านระดับนั้น (Easy/Normal/Hard)
- **คลิกปุ่มด่าน** - เพิ่มเข้าลำดับ (เช่น 3 → 1 → 5)
- **คลิกอีกครั้ง** - ลบออกจากลำดับ
- **เลือกครบ SelectionCount** - กดปุ่มด่านอื่นไม่ได้ (จนกว่าจะถอดออก)
- **ปุ่ม RANDOM** - สุ่มลำดับด่านแบบเฉลี่ยความยาก (balanced)
- **ปุ่ม START** - ต้องเลือกอย่างน้อย 1 ด่านก่อนกดได้
- **Difficulty badge** - แสดงบนปุ่มแต่ละด่าน (EASY/NORMAL/HARD)

### Zone Detection (Loop-based):

```lua
-- ตรวจสอบทุก Config.Timing.SelectionZoneInterval (0.2 วินาที) — เสถียรกว่า Touched events
-- จัดการโดย SelectionZoneManager.luau (แยกออกจาก GameManager)
task.spawn(function()
    while true do
        task.wait(Config.Timing.SelectionZoneInterval)
        for _, player in ipairs(Players:GetPlayers()) do
            local isInZone = self:isPlayerInZone(player)
            -- เปรียบเทียบกับสถานะก่อนหน้า แล้ว show/hide UI
        end
    end
end)
```

---

## 🗺️ การสร้าง/แก้ไข Stage (Map)

### ไฟล์ที่ต้องแก้: `src/server/StageTemplates.luau`

### โครงสร้าง Stage Function:

```lua
function StageTemplates.createStageX(startPosition: Vector3): Model
    local stage = Instance.new("Model")
    stage.Name = "StageX_Name"
    
    -- 1. StartPart (จุดเริ่มต้น - ต้องมี)
    local startPart = createPart({
        Name = "StartPart",
        Size = Vector3.new(10, 2, 10),
        Position = startPosition,
        Color = Color3.fromRGB(R, G, B),
    })
    startPart.Parent = stage
    
    -- 2. Checkpoint (จุด respawn - ต้องมี) ⚠️ เป็น Part ไม่ใช่ SpawnLocation
    local checkpoint = createCheckpoint(startPosition + Vector3.new(0, 1.5, 0))
    checkpoint.Parent = stage
    
    -- 3. Obstacles folder
    local obstacles = Instance.new("Folder")
    obstacles.Name = "Obstacles"
    obstacles.Parent = stage
    
    -- 4. ItemPickups folder
    local itemPickups = Instance.new("Folder")
    itemPickups.Name = "ItemPickups"
    itemPickups.Parent = stage
    
    -- 5. สร้าง obstacles ต่างๆ...
    
    -- 6. EndPart (จุดสิ้นสุด - ต้องมี)
    local endPart = createPart({
        Name = "EndPart",
        Size = Vector3.new(10, 2, 10),
        Position = startPosition + Vector3.new(0, 0, STAGE_LENGTH),
        Color = Color3.fromRGB(R, G, B),
    })
    endPart.Parent = stage
    
    return stage
end
```

### Helper Functions:

| Function | Return Type | Description |
|----------|-------------|-------------|
| `createPart(props)` | `Part` | สร้าง Part พร้อม Friction สูง |
| `createCheckpoint(pos)` | `Part` | สร้าง Checkpoint (Part สีเขียว Neon) |
| `createItemPickup(pos)` | `Part` | สร้าง Item pickup (Item Box Mesh ID: 6325349064) |

### ⚠️ สำคัญ: Checkpoint เป็น Part ไม่ใช่ SpawnLocation

```lua
-- ✅ ถูกต้อง - ใช้ Part
local function createCheckpoint(position: Vector3): Part
    local checkpoint = Instance.new("Part")
    checkpoint.Name = "Checkpoint"
    -- ...
end

-- ❌ ผิด - ถ้าใช้ SpawnLocation จะทำให้ผู้เล่นเกิดที่นี่แทน Lobby
local checkpoint = Instance.new("SpawnLocation")
```

### Attributes สำหรับ Obstacle พิเศษ:

| Attribute | Type | Description |
|-----------|------|-------------|
| `IsMoving` | boolean | Platform เคลื่อนที่ (ใช้ PrismaticConstraint) |
| `MoveAxis` | string | "X", "Y", หรือ "Z" |
| `MoveDistance` | number | ระยะเคลื่อนที่ (studs) |
| `MoveSpeed` | number | ความเร็ว |
| `IsSpinning` | boolean | หมุนรอบแกน Y (สำหรับ Spinner) |
| `SpinSpeed` | number | ความเร็วหมุน |
| `IsItemBox` | boolean | 🎯 Item Box - ให้ random item เมื่อเก็บ |
| `IsCoin` | boolean | ❌ ไม่ใช้แล้ว (เปลี่ยนเป็น Item Box) |
| `IsDisappearing` | boolean | หายไปเมื่อเหยียบ |
| `DisappearDelay` | number | วินาทีก่อนหาย |
| `ReappearDelay` | number | วินาทีก่อนกลับมา |
| `IsKillPart` | boolean | แตะแล้วตาย (respawn) |

### ตัวอย่าง: Moving Platform (Physics-based)

```lua
local platform = createPart({
    Name = "MovingPlatform",
    Size = Vector3.new(8, 1, 8),
    Position = startPosition + Vector3.new(0, 0, 50),
    Color = Color3.fromRGB(255, 165, 0),
})
platform:SetAttribute("IsMoving", true)
platform:SetAttribute("MoveAxis", "X")
platform:SetAttribute("MoveDistance", 10)
platform:SetAttribute("MoveSpeed", 3)
platform.Parent = obstacles
```

**หมายเหตุ**: Moving Platform จะใช้ `PrismaticConstraint` โดยอัตโนมัติ ทำให้ผู้เล่นเกาะไปด้วย (ไม่ลื่น)

### ตัวอย่าง: Spinning Kill Part

```lua
local spinner = createPart({
    Name = "Spinner",
    Size = Vector3.new(20, 2, 2),
    Position = startPosition + Vector3.new(0, 3, 30),
    Color = Color3.fromRGB(255, 50, 50),
})
spinner:SetAttribute("IsSpinning", true)
spinner:SetAttribute("SpinSpeed", 2)
spinner:SetAttribute("IsKillPart", true)
spinner.Parent = obstacles
```

### ตัวอย่าง: Item Box Pickup

```lua
-- สร้าง Item Box (ให้ random item)
local itemBox = createItemPickup(startPosition + Vector3.new(0, 5, 20))
-- IsItemBox = true, IsCoin = false (default จาก createItemPickup)
itemBox.Parent = itemPickups
```

**createItemPickup สร้าง:**
- รูปทรง: **Mesh (Item Box)** ID: 6325349064
- ขนาด: Scale `0.30, 0.30, 0.30`
- สี: **เหลืองสว่าง** (255, 200, 50) + Material Neon
- ยกขึ้น: **+3 studs** จากตำแหน่งที่ให้
- หมุน: อัตโนมัติรอบแกน Y
- เอฟเฟกต์: **Rainbow Sparkles** + PointLight เรืองแสง
- Attributes: `IsItemBox = true`, `IsCoin = false`

**🎯 Item Box:**
- เมื่อเก็บ: ได้ **random item** (Missile, Banana, Shield, etc.)
- Item ที่ได้ขึ้นอยู่กับ **อันดับในการแข่ง** (catch-up mechanic)
- คนท้ายมีโอกาสได้ item หายากมากกว่า
- Respawn หลัง 10 วินาที

### เพิ่ม Stage ใหม่:

1. สร้าง function `createStageX()` ใน `StageTemplates.luau`
2. เพิ่มเข้า `getStageCreators()`:

```lua
function StageTemplates.getStageCreators(): {(Vector3) -> Model}
    return {
        StageTemplates.createStage1,  -- Easy: Jump
        StageTemplates.createStage2,  -- Normal: Moving
        StageTemplates.createStage3,  -- Normal: Spin
        StageTemplates.createStage4,  -- Hard: Disappear
        StageTemplates.createStage5,  -- Hard: Combo
        StageTemplates.createStage6,  -- Hard: Lava Rise
        StageTemplates.createStage7,  -- Hard: Narrow
        StageTemplates.createStage8,  -- เพิ่มใหม่
    }
end
```

3. เพิ่ม metadata ใน `src/shared/StageInfo.luau` (id, name, icon, difficulty, color, gradientEnd, reward)
4. อัพเดท `Config.Stages.TotalCount` ใน `src/shared/Config.luau`

---

## 🎲 ระบบสุ่ม/เลือกลำดับด่าน

### ไฟล์: `src/server/MapManager.luau`

```lua
-- สุ่มลำดับแบบ shuffle ธรรมดา (Fisher-Yates, TotalCount ด่าน)
function MapManager:shuffleStages(): {number}

-- สุ่มแบบเฉลี่ยความยาก (balanced random, return SelectionCount ด่าน)
function MapManager:balancedRandomStages(selectionCount: number?): {number}
    -- การันตี MinPerDifficulty จากแต่ละระดับ (Easy/Normal/Hard)
    -- เติมที่เหลือจาก pool + shuffle ลำดับสุดท้าย

-- สร้าง Map ด้วยลำดับที่กำหนด (global map)
function MapManager:generateMapWithOrder(stageOrder: {number})
    -- ผลลัพธ์เก็บใน self.globalMap.stageOrder, self.globalMap.stages
end

-- สร้าง Map สำหรับ match เฉพาะ
function MapManager:generateMapForMatch(matchId: string, stageOrder: {number})
    -- ผลลัพธ์เก็บใน self.matchMaps[matchId]
end
```

**⚠️ ข้อสำคัญ (หลัง refactor):**
- Global map state: `self.globalMap.stageOrder`, `self.globalMap.stages` (ไม่ใช่ `self.stageOrder`, `self.currentStages` แล้ว)
- Internal helpers `_xxxInternal()` ถูก share ระหว่าง global และ per-match — ห้ามเรียกตรงๆ จากนอก MapManager

**Output ใน Console**: `[MapManager] Stage order: 3, 1, 5, 2, 4`

---

## 🏃 Moving Platform System (Physics-based)

### ไฟล์: `src/server/MapManager.luau`

Moving Platforms ใช้ `PrismaticConstraint` แทน CFrame animation เพื่อให้ผู้เล่นเกาะไปด้วย:

```lua
function MapManager:setupMovingPlatformConstraint(part: Part)
    -- Unanchor เพื่อให้ physics ทำงาน
    part.Anchored = false
    
    -- สร้าง Anchor Part (มองไม่เห็น)
    local anchorPart = Instance.new("Part")
    anchorPart.Anchored = true
    anchorPart.CanCollide = false
    anchorPart.Transparency = 1
    
    -- สร้าง PrismaticConstraint
    local prismatic = Instance.new("PrismaticConstraint")
    prismatic.ActuatorType = Enum.ActuatorType.Servo
    prismatic.ServoMaxForce = 1000000
    -- ...
end
```

---

## 🧱 Friction System (ไม่ลื่น)

### ไฟล์: `src/server/StageTemplates.luau`

ทุก Part ที่สร้างจะมี Friction สูงโดยอัตโนมัติ:

```lua
local function createPart(properties): Part
    local part = Instance.new("Part")
    part.Material = Enum.Material.Concrete
    
    -- Friction สูง = ไม่ลื่น
    part.CustomPhysicalProperties = PhysicalProperties.new(
        0.7,  -- Density
        2.0,  -- Friction (สูง!)
        0.1,  -- Elasticity
        1.0,  -- FrictionWeight
        0.5   -- ElasticityWeight
    )
    -- ...
end
```

---

## ⚙️ การแก้ไข Config

### ไฟล์: `src/shared/Config.luau`

```lua
local Config = {
    -- Lobby Settings
    Lobby = {
        SpawnPosition = Vector3.new(0, 100, 0),
    },

    -- Stage Settings
    Stages = {
        TotalCount = 7,         -- จำนวนด่านทั้งหมดใน pool
        SelectionCount = 5,     -- จำนวนด่านที่เลือกต่อรอบ (แก้ได้เพื่อ test)
        StageLength = 100,      -- ความยาวแต่ละด่าน
        StartOffset = Vector3.new(-150, 0, 250),
        BalancedRandom = {
            MinPerDifficulty = 1, -- การันตีอย่างน้อย 1 ด่านจากแต่ละระดับ
        },
    },

    -- Score Settings
    Score = {
        PerStage = 10,          -- คะแนนต่อด่าน
        FinishBonus = 50,       -- โบนัสจบเกม
    },

    -- Currency Settings
    Currency = {
        PerStage = 5,           -- 💰 Stage Clear bonus (คงที่ต่อด่าน)
        PerCoin = 1,            -- 💰 เงินที่ได้เมื่อเก็บเหรียญ
        FinishBonus = 25,       -- 💰 โบนัสเงินเมื่อเข้าเส้นชัย
        StartingAmount = 0,     -- 💰 เงินเริ่มต้นของผู้เล่นใหม่
        -- 🎯 Stage Rewards อยู่ใน StageInfo.luau (StageInfo.getStage(id).reward)
    },

    -- Push Item Settings
    PushItem = {
        StartingAmount = 1,     -- เริ่มต้นมีกี่ชิ้น
        MaxAmount = 5,          -- สูงสุด
        Range = 15,             -- ระยะโจมตี
        Force = 100,            -- แรงผลัก
        Cooldown = 10,          -- cooldown (วินาที)
    },

    -- DataStore
    DataStore = {
        Name = "ObbyGameData_v1",
        ScoreKey = "PlayerScore",
        HighScoreKey = "HighScore",
        CurrencyKey = "PlayerCurrency", -- 💰 Key สำหรับเก็บเงิน
    },

    KillZoneY = -120,            -- ความสูงที่ตาย

    -- Daily Login (7-day streak)
    DailyLogin = {
        CooldownHours = 20,  -- รับได้หลังจาก 20 ชั่วโมง
        ResetHours    = 48,  -- streak reset ถ้าไม่ได้ login 48 ชั่วโมง
        Rewards = {          -- coins ต่อวัน (วนซ้ำหลังครบ 7 วัน)
            [1] = 25, [2] = 50, [3] = 75, [4] = 100,
            [5] = 150, [6] = 200, [7] = 500,
        },
    },

    -- Timing Settings (previously hardcoded magic numbers)
    Timing = {
        LeaderboardSendDelay = 3,       -- delay ก่อนส่งผล leaderboard
        CharacterSetupDelay = 0.5,      -- รอ character โหลด
        PositionCheckInterval = 0.5,    -- loop ตรวจสอบตำแหน่ง
        SelectionZoneInterval = 0.2,    -- loop ตรวจสอบ selection zone
        AutoTeleportDelay = 5,          -- delay ก่อน auto-teleport หลังจบ
        TeleportFlagClearDelay = 0.5,   -- delay ล้าง teleport flag
        AutoSaveInterval = 30,          -- auto-save interval (วินาที)
        LeaderstatsLoadDelay = 1,       -- delay ก่อน update leaderstats หลัง load
    },

    -- Map Settings (previously hardcoded magic numbers)
    Map = {
        StageGapStuds = 10,             -- ระยะห่างระหว่าง stages (studs)
        FinishLineRadius = 20,          -- รัศมีตรวจจับ finish line
        PlatformServoForce = 1000000,   -- ServoMaxForce สำหรับ moving platform
        PlatformServoSpeed = 50,        -- ServoMaxVelocity สำหรับ moving platform
    },

    -- Debug / Development Settings
    Debug = {
        Enabled = true,          -- Master toggle: set false for production
        FlyMode = true,          -- Press F to fly (client)
        ItemTesting = true,      -- Press T for item test menu (client + server remotes)
        MasteryTesting = true,   -- Press M for mastery test menu
    },
}
```

---

## 🎯 Item System (Mario Kart Style)

### ไฟล์ที่เกี่ยวข้อง:
- `src/shared/ItemTypes.luau` - นิยาม Items ทั้งหมด
- `src/server/ItemManager.luau` - Logic ฝั่ง Server + VFX
- `src/client/UI/ItemUI.luau` - UI แสดง Item (2 slots) + Tooltip
- `src/client/UI/ItemTestingUI.luau` - UI ทดสอบ Item (กด T)
- `src/client/ItemEffects.luau` - Screen effects (shake, flash, zoom)

### Items ที่มี:

| Item | Rarity | Icon | Description |
|------|--------|------|-------------|
| Missile | Common | 🚀 | Fire a homing missile that tracks the nearest target ahead! Knocks down on hit (ล้ม). |
| Banana | Common | 🍌 | Drop a banana behind you. Makes players slip! |
| Shield | Uncommon | 🛡️ | Create a shield that blocks 1 attack. |
| Speed Boost | Uncommon | ⚡ | +50% speed for 3 seconds! |
| Swap | Rare | 🔄 | Swap positions with the nearest player ahead of you! |
| Lightning | Epic | ⚡🌩️ | Slows ALL other players for 3 sec! |

### Dual Item Slots:
- ผู้เล่นถือได้ **2 items** พร้อมกัน
- กด **1** = ใช้ item ช่องซ้าย
- กด **2** = ใช้ item ช่องขวา
- UI แสดงแบบ **horizontal** (ซ้าย-ขวา)
- กรอบ item มี **สี rarity** (Common=เทา, Uncommon=เขียว, Rare=น้ำเงิน, Epic=ม่วง)

### Item Box (Neon Cube Style):

```lua
-- สร้าง Item Box (Neon Cube - ให้ random item)
local itemBox = createItemPickup(position)
-- Style: Purple-blue neon cube (150, 100, 255)
-- มี bobbing animation + spinning + particles
itemBox.Parent = itemPickups
```

### Visual Effects (VFX):

| Item | Visual Effect |
|------|---------------|
| Missile | Rocket mesh + flame/smoke trails + explosion particles + HOMING (tracks target) + FALL EFFECT (ล้มเหมือนกล้วย) |
| Banana | Yellow mesh (ID: 6407990721) + sparkles + slip animation (ล้มไปข้างหลัง) + works on dummies too |
| Shield | Force field bubble + hex particles + aura (rising/swirling) + pulsing glow |
| Speed Boost | Speed lines + aura particles + trail |
| Swap | Portal ring + swirl particles + teleport flash |
| Lightning | Global screen flash + lightning strikes per player |

### Banana Slip Effect:
```lua
-- ผู้เล่นจะ:
-- 1. ลอยขึ้นเล็กน้อย (Y = 15) ← LinearVelocity
-- 2. ไถลไปข้างหน้า (velocity * 20) ← LinearVelocity
-- 3. หมุนล้มไปข้างหลัง ← AngularVelocity (constraint-based)
-- 4. เข้า FallingDown state
-- 5. กระโดดไม่ได้ระหว่างล้ม (loop บังคับ JumpPower = 0)
-- 6. ลุกขึ้นหลัง 0.5 วินาที (GettingUp state)
-- เจ้าของกล้วยก็ลื่นได้เหมือนกัน!
-- Test Dummies ก็ลื่นได้เหมือนกัน!
```

### Missile Homing System:
```lua
-- Homing Missile Parameters:
-- speed = 60          -- ช้ากว่าปกติเพื่อให้ track ได้
-- turnSpeed = 6       -- ความเร็วในการหัน (สูง = หันเร็ว)
-- viewConeAngle = 90  -- องศาจากกลาง (180° total cone)
-- trackingRange = 120 -- ระยะล็อคเป้าสูงสุด

-- การทำงาน:
-- 1. ตอนยิง: หาเป้าหมายที่ใกล้ที่สุดใน view cone
-- 2. isInViewCone() เช็คว่าเป้าอยู่ในมุมมองหรือไม่
-- 3. ทุก frame: ค่อยๆ หันไปหาเป้า (lerp direction)
-- 4. CFrame หันหน้าตามทิศที่บิน
-- 5. ถ้าไม่มีเป้า = ยิงตรงเหมือนเดิม

-- หันหลังก่อนยิง = ยิงคนข้างหลังได้!
-- เป้าเคลื่อนที่เร็ว = ยังหลบได้
```

### Missile Hit Effect (Fall):
```lua
-- เมื่อโดน Missile จะ:
-- 1. ลอยขึ้น (Y = 18) ← LinearVelocity
-- 2. กระเด็นไปข้างหลัง (velocity * -25) ← LinearVelocity
-- 3. หมุนล้มหงาย ← AngularVelocity (constraint-based, -10)
-- 4. เข้า FallingDown state
-- 5. Visual: 💥⭐💥 หมุนเหนือหัว + particles ควัน/ไฟ
-- 6. ลุกขึ้นหลัง 0.6 วินาที
-- ล้มเหมือนกล้วย แต่มี theme ระเบิด!
```

### Sound Effects:

| Item | Sound |
|------|-------|
| Banana Drop | rbxassetid://70557734865364 |
| Banana Slip | rbxassetid://129432532096499 |
| Shield Activate | rbxassetid://105300932320033 |
| Shield Break | rbxassetid://122218831341898 |
| Speed Boost | rbxassetid://105300932320033 |
| Missile Fire | rbxassetid://287390459 |
| Explosion | rbxassetid://287390954 |
| Swap Teleport | rbxassetid://93826112721753 |
| Lightning Zap | rbxassetid://8952019380 |

### Item Testing UI (Development):
- กด **T** เพื่อเปิด/ปิดเมนูทดสอบ
- เลือก item ที่ต้องการให้ตัวเอง
- กด **"Spawn Test Dummy"** เพื่อสร้าง Dummy สำหรับทดสอบ Missile/Swap/Lightning
- กด **"Remove All Dummies"** เพื่อลบ Dummies ทั้งหมด
- กด "Clear All Items" เพื่อล้าง
- แบ่งกลุ่มตาม rarity

### Weighted Random Item:
- คนอันดับท้ายมีโอกาสได้ item หายากมากกว่า (catch-up mechanic)
- ใช้ `catchUpBonus` ใน ItemTypes เพื่อปรับ weight

### ItemManager Key Functions:

| Function | Description |
|----------|-------------|
| `useMissile(player, rootPart, itemDef)` | ยิง homing missile |
| `useBanana(player, rootPart, itemDef)` | วางกล้วย |
| `useShield(player, itemDef)` | สร้างโล่ป้องกัน |
| `useSpeedBoost(player, itemDef)` | เพิ่มความเร็ว |
| `useSwap(player, itemDef)` | สลับตำแหน่งกับคนข้างหน้า |
| `useLightning(player, itemDef)` | ช็อตทุกคน |
| `isInViewCone(myPos, lookDir, targetPos, maxAngle)` | เช็คว่าเป้าอยู่ใน view cone |
| `findMissileTarget(player, myPos, lookDir, maxAngle, maxRange)` | หาเป้าหมายสำหรับ homing missile |
| `applySlip(player, itemDef)` | ทำให้ player ลื่น (กล้วย) |
| `applyDummySlip(dummy, itemDef)` | ทำให้ dummy ลื่น |
| `applyStun(target, duration)` | Stun ธรรมดา (ยืน) |
| `applyStunWithFall(target, duration)` | Stun + ล้ม (Missile) |
| `applyDummyStun(dummy, duration)` | Stun dummy (Lightning) |

### การเพิ่ม Item ใหม่:

1. เพิ่มใน `ItemTypes.luau`:
```lua
NewItem = {
    id = "NewItem",
    name = "New Item",
    description = "Item description here",
    icon = "🆕", -- ใช้ emoji หรือ rbxassetid://...
    rarity = "Uncommon", -- Common, Uncommon, Rare, Epic
    weight = 15,
    catchUpBonus = 2,
    duration = 5,
    cooldown = 1,
},
```

2. เพิ่ม Logic ใน `ItemManager:executeItemEffect()`:
```lua
elseif itemDef.id == "NewItem" then
    return self:useNewItem(player, itemDef)
```

3. สร้าง function `useNewItem()` พร้อม VFX และ Sound

---

## 🎭 Character Class System

### ไฟล์ที่เกี่ยวข้อง:
- `src/shared/ClassTypes.luau` - นิยาม Classes
- `src/server/ClassManager.luau` - Logic ฝั่ง Server
- `src/server/CurrencyManager.luau` - Mastery + Rewards + Title equip/persistence
- `src/client/UI/ClassSelectionUI.luau` - UI เลือก Class
- `src/client/UI/TitleHUDUI.luau` - HUD แสดง Active Title
- `src/client/UI/TitleCollectionUI.luau` - หน้า Collection ของ Title

### Classes ที่มี:

| Class | WalkSpeed | JumpPower | Passive |
|-------|-----------|-----------|---------|
| Normal | 16 (±0%) | 50 (±0%) | Balanced - ไม่มีข้อได้เปรียบ/เสียเปรียบ |
| Runner | 18.4 (+15%) | 45 (-10%) | Sprint Burst - เพิ่มความเร็วชั่วคราว |
| Jumper | 14.4 (-10%) | 60 (+20%) | Charged Jump - กระโดดสูงขึ้นเมื่อชาร์จ |
| Tank | 13.6 (-15%) | 50 (±0%) | Stun Immunity - ไม่โดน stun |

### Class Unlock Settings (Config.luau):

```lua
Classes = {
    DefaultClass = "Normal",
    FreeClasses = {
        Normal = true,
    },
    Costs = {
        Runner = 300,
        Jumper = 450,
        Tank = 600,
    },
    RequestCooldown = 0.25,
},
```

### Class Mastery Settings (Config.luau):

```lua
Mastery = {
    MaxLevel = 20,
    BaseXpPerLevel = 100,
    XpGrowthMultiplier = 1.25,
    PerStageXP = 20,
    FinishBonusXP = 60,
    TitleThemes = {
        Common = { textColor = Color3.fromRGB(210, 210, 210), strokeColor = Color3.fromRGB(40, 40, 50), frameColor = Color3.fromRGB(80, 80, 95) },
        Rare = { textColor = Color3.fromRGB(120, 205, 255), strokeColor = Color3.fromRGB(25, 55, 85), frameColor = Color3.fromRGB(75, 135, 190) },
        Epic = { textColor = Color3.fromRGB(220, 150, 255), strokeColor = Color3.fromRGB(70, 30, 95), frameColor = Color3.fromRGB(155, 90, 215) },
        Legendary = { textColor = Color3.fromRGB(255, 220, 120), strokeColor = Color3.fromRGB(95, 65, 25), frameColor = Color3.fromRGB(220, 170, 70) },
    },
    Rewards = {
        Normal = {
            {id = "normal_title_balanced_cadet", level = 5, rewardType = "Title", rarity = "Common", name = "Balanced Cadet"},
            {id = "normal_trail_calm_flow", level = 10, rewardType = "Trail", rarity = "Rare", name = "Calm Flow"},
            {id = "normal_badge_specialist", level = 15, rewardType = "Badge", rarity = "Epic", name = "Normal Specialist"},
            {id = "normal_frame_master", level = 20, rewardType = "CardFrame", rarity = "Legendary", name = "Normal Master Frame"},
        },
        -- Runner/Jumper/Tank ใช้รูปแบบเดียวกัน
    },
},
```

### Mastery v2 (ตอนนี้ทำแล้ว):
- เก็บ Mastery แยกตาม class ใน DataStore (`classMastery`)
- เก็บสถานะ reward ที่ปลดแล้วใน DataStore (`masteryRewards`)
- ผู้เล่นเก่าที่ไม่มีข้อมูล mastery จะถูก migrate เป็น Lv.1 ทุก class อัตโนมัติ
- ผู้เล่นเก่าที่เลเวลสูงอยู่แล้วจะได้รับ reward ตาม milestone ย้อนหลังอัตโนมัติ
- ได้ XP จาก:
  - ผ่านด่าน: `Config.Mastery.PerStageXP` (เฉพาะตอนผ่านด่านจริง)
  - เข้าเส้นชัย: `Config.Mastery.FinishBonusXP`
- ส่งข้อมูลผ่าน `MasteryUpdate` ไปที่ client
- UI หน้า Class Selection แสดง Mastery Lv, XP progress bar, stat bars (green=buff, red=nerf) ของแต่ละ class
- UI หน้า Class Selection มี panel preview milestone rewards + ปุ่ม "VIEW ALL" ไปหน้า Title Collection
- Title selector ถูกย้ายไปอยู่ใน `TitleCollectionUI` แยกหน้าต่างหาก (ไม่มีใน Class modal แล้ว)
- มี `TitleHUD` แสดง `Active Title` ที่มุมบนซ้าย (light bar + ปุ่ม 📋 เปิด Collection)
- ถ้ายังไม่มี title จะแสดง "Tap to set title ›" เป็น hint text (คลิกเปิด Collection ได้)
- มี `TitleCollection` แยกหน้า: ดู title ทั้งหมด (ล็อก/ปลดล็อก), Active Title Banner, กด equip/unequip ได้
- หน้า `TitleCollection` มี `All/Unlocked/Locked` filter + search ชื่อ title/class/rarity + Sort dropdown
- Title cards แบบ compact (62px) มี rarity-colored left border strip
- **Modal mutual exclusion**: Class modal และ Title Collection เปิดพร้อมกันไม่ได้ (เปิดอันหนึ่งจะปิดอีกอัน)
- Reward ยังเป็น cosmetic-only (Title/Trail/Badge/CardFrame) ไม่มีผลเพิ่มพลัง

### การเลือก Class:
- คลิกที่ Class indicator (มุมบนซ้าย) เพื่อเปิด UI
- ถ้า class ปลดล็อกแล้ว: กด `EQUIP` เพื่อสวมทันที
- ถ้า class ยังล็อกและเงินพอ: กด `BUY & EQUIP` เพื่อซื้อและสวมทันที
- ถ้าเงินไม่พอ: ปุ่มจะเป็น `NOT ENOUGH`
- เปลี่ยน class ได้เฉพาะตอนอยู่ Lobby (ระหว่างวิ่งด่านจะถูกปฏิเสธ)
- สถานะปลดล็อกและ class ที่ใส่ล่าสุดถูกบันทึกถาวรใน DataStore

### End-game Roadmap (Class):
1. **Class Mastery (Lv1-20)**: ได้ XP จากการเล่นด้วย class นั้น ปลดล็อก title/trail/frame
2. **Class Prestige**: ครบ mastery แล้วรีเซ็ต progression ของ class แลก `Class Token`
3. **Class Contracts**: ภารกิจรายวัน/รายสัปดาห์ที่บังคับใช้ class เฉพาะ เพื่อเพิ่ม retention

---

## ⚡ Ultimate Skills System

### ไฟล์ที่เกี่ยวข้อง:
- `src/shared/Config.luau` - `Mastery.UltimateUnlockLevel` + `Mastery.UltimateSkills` config
- `src/shared/ClassTypes.luau` - `ultimateSkill` field ใน ClassDefinition
- `src/server/CurrencyManager.luau` - `hasUltimateUnlocked()` function
- `src/client/UltimateSkillController.luau` - จัดการ Ultimate Skills (Sprint, Double Jump, Iron Will)
- `src/server/ItemManager.luau` - `checkIronWillImmunity()` for Tank stun immunity

### Ultimate Skills Config (Config.luau):

```lua
Mastery = {
    MaxLevel = 20,
    UltimateUnlockLevel = 20,  -- ⚡ Unlock at mastery level 20
    UltimateSkills = {
        Runner = {
            id = "Sprint",
            name = "Sprint",
            description = "Press Shift to run 50% faster for 3 seconds",
            cooldown = 15,
            duration = 3,
            speedMultiplier = 1.5,
        },
        Jumper = {
            id = "DoubleJump",
            name = "Double Jump",
            description = "Jump again in mid-air",
            maxAirJumps = 1,
        },
        Tank = {
            id = "IronWill",
            name = "Iron Will",
            description = "Immune to all item stuns",
            stunImmunity = true,
        },
    },
    -- ... other mastery config
},
```

### Ultimate Skills ที่มี:

| Class | Ultimate Skill | Input | Description |
|-------|---------------|-------|-------------|
| Runner | Sprint | Shift | วิ่งเร็วขึ้น 50% เป็นเวลา 3 วินาที, cooldown 15 วินาที |
| Jumper | Double Jump | Space (mid-air) | กระโดดได้ 2 ครั้งในอากาศ |
| Tank | Iron Will | Passive | ไม่โดน stun จาก items (Banana, Missile, Lightning) |

### Ultimate Skill Controller:

```lua
-- UltimateSkillController tracks:
-- - currentClass: string
-- - ultimateUnlocked: boolean
-- - isSprintActive: boolean
-- - sprintCooldown: number
-- - airJumpCount: number
-- - classMastery: table (from server)

-- Sprint (Runner):
-- - Press Shift to activate
-- - WalkSpeed *= speedMultiplier
-- - Visual: Blue trail effect
-- - Auto-end after duration

-- Double Jump (Jumper):
-- - Press Space while in air
-- - Reset airJumpCount when grounded
-- - Visual: Green burst effect

-- Iron Will (Tank):
-- - Passive - always active when LV 20+
-- - Server-side check in ItemManager:applySlip/applyStunWithFall
```

### Visual Effects:

| Skill | VFX |
|-------|-----|
| Sprint | Blue trail (Trail attachment) on HumanoidRootPart |
| Double Jump | Green burst (Part + ParticleEmitter) at jump position |

### Testing:

1. กด **M** เพื่อเปิด Mastery Testing UI
2. กด **MAX** หรือ **SET ALL LV 20** เพื่อปลดล็อก ultimate
3. เลือก class ที่มี LV 20 แล้ว
4. ทดสอบ ultimate skill:
   - **Runner**: กด Shift ขณะวิ่ง
   - **Jumper**: กระโดดแล้วกด Space ในอากาศ
   - **Tank**: โดน Banana/Missile → จะไม่ถูก stun

### Debug Config:

```lua
Debug = {
    Enabled = true,
    FlyMode = true,
    ItemTesting = true,
    MasteryTesting = true,  -- ⚡ Press M for mastery test menu
},
```

---

## 🗺️ Per-Match Map Instancing

### ไฟล์ที่เกี่ยวข้อง:
- `src/server/MapManager.luau` - `matchMaps` table, `generateMapForMatch()`, `clearMapForMatch()`
- `src/server/MatchManager.luau` - `stageVotes`, `selectedStageOrder`, `handleStageVote()`
- `src/server/GameManager.luau` - `playerMatchIds` tracking
- `src/client/UI/StageSelectionUI.luau` - `VoteStages` remote integration

### การทำงาน:

```lua
-- MapManager keeps track of maps per match:
self.matchMaps = {
    [matchId] = {
        map = Model,           -- The generated map
        stageOrder = {3, 1, 5, 2, 4},
        checkpoints = {...},
    }
}

-- Generate map for specific match:
function MapManager:generateMapForMatch(matchId: string, stageOrder: {number})
    self:clearMapForMatch(matchId)
    -- Generate map in separate folder...
end

-- Get checkpoint position for specific match:
function MapManager:getCheckpointPositionForMatch(matchId: string, stageIndex: number): Vector3?
```

### Stage Voting System:

```lua
-- MatchManager handles stage voting:
self.stageVotes = {
    [player] = {3, 1, 5},  -- Player's vote for stage order
}

-- When match starts:
-- 1. Collect all votes
-- 2. Calculate final order (majority/random)
-- 3. Generate map with selected order
-- 4. Bind players to match
```

### Client Integration:

```lua
-- StageSelectionUI sends vote:
self.voteStagesRemote:FireServer(selectedStages)

-- Server handles vote:
function MatchManager:handleStageVote(player: Player, stageOrder: {number})
    self.stageVotes[player] = stageOrder
    -- Broadcast update to all players in match...
end
```

### RemoteEvents for Match System:

| Event | Direction | Usage |
|-------|-----------|-------|
| `VoteStages` | Client → Server | ส่งคะแนนโหวต stage order |
| `StageVoteUpdate` | Server → Client | อัพเดทผลโหวตให้ผู้เล่นทุกคน |

---

## 🏁 Match/Race System

### ไฟล์ที่เกี่ยวข้อง:
- `src/server/MatchManager.luau` - Logic Matchmaking
- `src/client/UI/MatchLobbyUI.luau` - UI Lobby
- `src/client/UI/RaceResultsUI.luau` - UI ผลการแข่ง

### Match Settings (Config.luau):

```lua
Match = {
    MinPlayers = 1,        -- Solo testing enabled
    MaxPlayers = 16,       -- Maximum players per match
    WaitTime = 3,          -- Testing: 3 วิ, Production: 30-60 วิ
    IsTestingMode = true,  -- Toggle สำหรับ testing
    TimeLimit = 900,       -- 15 นาที per match
    TimeWarnings = {300, 60, 30, 10}, -- แจ้งเตือนเมื่อเหลือเวลา
},
```

### Match States:
- `Waiting` - รอผู้เล่น
- `Starting` - Countdown ก่อนเริ่ม
- `Racing` - กำลังแข่ง
- `Finished` - จบแล้ว

### Player States:
- `Lobby` - อยู่ใน lobby
- `Playing` - กำลังแข่ง
- `Finished` - จบแล้ว (รอเลือก spectate/leave)
- `Spectating` - ดูคนอื่นแข่ง (character ซ่อน)

---

## ⏱️ Match Timer UI

### ไฟล์ที่เกี่ยวข้อง:
- `src/client/UI/ScoreUI.luau` - timer frame (top-center, hidden by default)
- `src/client/UI/MainUI.luau` - wires `RaceUpdate` / `TimeWarning` / `ReturnToLobby`

### การทำงาน:
- Server ส่ง `RaceUpdate` พร้อม `{ timeRemaining, isRunning }` → ScoreUI:showTimer / updateTimer
- Server ส่ง `TimeWarning` พร้อม `{ timeLeft, isCritical }` → MainUI:showTimeWarning (popup + tween)
- เมื่อ `timeRemaining <= 30`: timer เปลี่ยนเป็นสีแดง + pulse
- `ReturnToLobby` → ScoreUI:hideTimer

---

## 🎁 Daily Login System

### ไฟล์ที่เกี่ยวข้อง:
- `src/shared/Config.luau` → `Config.DailyLogin`
- `src/server/CurrencyManager.luau` → `checkDailyLogin()`
- `src/client/UI/DailyBonusUI.luau` → HUD button + calendar popup

### การทำงาน:
```
Player joins → CurrencyManager:loadPlayerData()
    ↓
checkDailyLogin(player):
  - ถ้า elapsed < CooldownHours: ส่ง { claimed=false, day, rewards } (status only)
  - ถ้า elapsed >= CooldownHours:
      - ถ้า elapsed >= ResetHours: streak = 0
      - streak = (streak % 7) + 1
      - เพิ่ม currency ตาม rewards[streak]
      - ส่ง { claimed=true, day=streak, amount, rewards }
    ↓
Client รับ DailyBonusClaimed:
  - claimed=true  → เปิด calendar popup (claim mode)
  - claimed=false → อัพเดท HUD button badge เท่านั้น
```

### DataStore Fields (เพิ่มใหม่):
- `lastLoginTime` (number?) — os.time() ครั้งล่าสุดที่รับ
- `loginStreak` (number) — วันที่ปัจจุบัน 1–7

### DailyBonusUI:
- **HUD button** 🎁 มุมล่างซ้าย — แสดง "Day X", สีทอง=ยังไม่รับ, สีเขียว=รับแล้ว
- **Calendar popup** — 7 day cards แสดงสถานะ (past=✓, today=gold/green, future=dim)
- **isClaim mode**: ปุ่ม "✨ CLAIM!" → กด → green overlay ✓ ทับ card → ปิดใน 1.2 วิ
- **view mode**: ปุ่ม "OK", today card แสดง ✓ สีเขียว
- guard `_calendarOpen`: ป้องกันเปิด popup ซ้อนกัน

### Testing:
- กด **T** → Item Testing menu → "🎁 Reset Daily Login" → รีเซ็ต streak ทันที (debug only)

---

## 🏆 Global Leaderboard (Physical Board)

### ไฟล์ที่เกี่ยวข้อง:
- `src/server/LeaderboardManager.luau` — สร้าง board + OrderedDataStore
- `src/server/GameManager.luau` — เรียก `updateScore()` เมื่อผู้เล่นจบเกม + `sendToPlayer()` เมื่อ join
- `src/client/UI/LeaderboardUI.luau` — **stub เท่านั้น** (ลบ screen toggle แล้ว)

### Physical Board:
```lua
-- LeaderboardManager สร้าง Part ชื่อ "GlobalLeaderboard" ใน workspace
-- ถ้ามี Part อยู่แล้วจะใช้ตำแหน่งนั้น (ย้าย Part ใน Studio ได้)
BOARD_POSITION = Vector3.new(22, 109, 12)  -- ขวาของ stage select, lobby floor Y~102
BOARD_SIZE     = Vector3.new(10, 14, 0.5)  -- กว้าง × สูง × บาง
-- หันหน้า -X (มองเห็นจากกลาง lobby)
-- SurfaceGui: PixelsPerStud=80, Face=Front, Top 10 rows
```

### Key Functions:
| Function | Description |
|----------|-------------|
| `updateScore(player, score)` | บันทึก high score ลง OrderedDataStore |
| `fetchTopScores()` | ดึง Top 10 จาก OrderedDataStore |
| `broadcast()` | fetch → อัพเดท physical board UI + fire LeaderboardUpdate |
| `sendToPlayer(player)` | ส่ง cached top ให้ผู้เล่นที่เพิ่งเข้า |
| `startRefreshLoop()` | refresh ทุก 60 วินาที |

---

## 🔊 Sound Manager

### ไฟล์: `src/client/SoundManager.luau`

ต้องใส่ asset IDs ก่อนเกมจะมีเสียง:

```lua
-- src/client/SoundManager.luau (บรรทัดต้นไฟล์)
local SOUNDS = {
    BGM_Lobby         = "",  -- ใส่ rbxassetid://XXXXXXX เพลง lobby loop
    SFX_Countdown     = "",  -- เสียง countdown beep
    SFX_GameStart     = "",  -- เสียง GO!
    SFX_StageComplete = "",  -- เสียง stage clear
    SFX_ItemPickup    = "",  -- เสียง item pickup
}
```

### Key Methods:
| Method | Description |
|--------|-------------|
| `playBGM()` | เล่น BGM (loop) ถ้า SoundId ไม่ว่าง |
| `stopBGM()` | หยุด BGM |
| `playSFX(name)` | เล่น SFX ถ้า SoundId ไม่ว่าง |
| `_setupRemotes()` | ฟัง CountdownUpdate / StageComplete RemoteEvents |

> SoundManager init ใน `init.client.luau` ด้วย `task.spawn` ไม่ block main thread

---

## 📡 RemoteEvents

### ไฟล์: `default.project.json` → `ReplicatedStorage.Remotes`

| Event | Direction | Usage |
|-------|-----------|-------|
| `UseItem` | Client → Server | ใช้ Item |
| `UpdateScore` | Server → Client | อัพเดทคะแนน + Item |
| `UpdateCurrency` | Server → Client | 💰 อัพเดทเงิน |
| `StageComplete` | Server → Client | ผ่านด่าน |
| `StartGame` | Client → Server | เริ่มเกมจาก Lobby (legacy) |
| `PlayerDied` | Server → Client | แจ้งผู้เล่นตาย |
| `ShowStageSelection` | Server → Client | ⭐ แสดง GUI เลือกด่าน |
| `HideStageSelection` | Server → Client | ⭐ ซ่อน GUI เลือกด่าน |
| `ConfirmStageSelection` | Client → Server | ⭐ ยืนยันการเลือกด่าน |
| `CountdownUpdate` | Server → Client | ⭐ อัพเดท countdown 3, 2, 1 |
| `CreateMatch` | Client → Server | 🏁 สร้าง Match ใหม่ |
| `JoinMatch` | Client → Server | 🏁 เข้าร่วม Match |
| `LeaveMatch` | Client → Server | 🏁 ออกจาก Match |
| `MatchUpdate` | Server → Client | 🏁 อัพเดทสถานะ Match |
| `MatchStart` | Server → Client | 🏁 Match เริ่มแล้ว |
| `MatchEnd` | Server → Client | 🏁 Match จบแล้ว |
| `RaceUpdate` | Server → Client | 🏁 อัพเดทอันดับ |
| `TimeWarning` | Server → Client | 🏁 แจ้งเตือนเวลา |
| `SelectClass` | Client → Server | 🎭 เลือก Class |
| `ClassUpdate` | Server → Client | 🎭 อัพเดท Class + unlock state + action result |
| `MasteryUpdate` | Server → Client | 📈 อัพเดท Class Mastery (level/xp) |
| `SetActiveTitle` | Client → Server | 🏷️ เลือก/ถอด Title ที่ใช้งาน (จาก Class UI หรือ Title Collection) |
| `TitleUpdate` | Server → Client | 🏷️ อัพเดท `titleCatalog` (locked/unlocked) + `activeTitle` + action |
| `ItemEffectEvent` | Server → Client | 🎯 Client-side VFX (screen shake, flash) |
| `GiveTestItem` | Client → Server | 🧪 ให้ item สำหรับทดสอบ |
| `ClearTestItems` | Client → Server | 🧪 ล้าง items ทั้งหมด |
| `SpawnTestDummy` | Client → Server | 🤖 สร้าง Test Dummy |
| `RemoveTestDummies` | Client → Server | 🤖 ลบ Test Dummies ทั้งหมด |
| `TutorialSeen` | Client → Server | ❓ ผู้เล่นเปิด Tutorial ครั้งแรก (persist ใน DataStore) |
| `SpectateMatch` | Client → Server | 👁️ ผู้เล่นเลือก Spectate หลังจบ |
| `SpectatorLeave` | Client → Server | 👁️ ออกจาก Spectator mode |
| `DailyBonusClaimed` | Server → Client | 🎁 Daily Login status/claim `{ claimed, day, amount, rewards }` |
| `LeaderboardUpdate` | Server → Client | 🏆 Top 10 scores `{ top: [{rank,name,score}] }` |
| `ResetDailyLogin` | Client → Server | 🧪 รีเซ็ต daily login streak (debug mode เท่านั้น) |

**ClassUpdate Payload (สำคัญ):**
```lua
{
    classId = "Runner", -- currently equipped class
    classInfo = {...},  -- display info from ClassTypes
    unlockedClasses = { Normal = true, Runner = true },
    classCosts = { Runner = 300, Jumper = 450, Tank = 600 },
    currency = 512,
    classMastery = { -- optional fallback snapshot
        Normal = { level = 3, xp = 40, xpToNext = 156, isMax = false },
    },
    masteryRewards = { -- optional fallback snapshot
        Normal = {
            { id = "normal_title_balanced_cadet", level = 5, rewardType = "Title", rarity = "Common", name = "Balanced Cadet", unlocked = false },
        },
    },
    action = { -- optional
        type = "equip" | "purchase" | "error",
        classId = "Runner",
        cost = 300?, -- only purchase/error where relevant
        reason = "INSUFFICIENT_FUNDS" | "INVALID_CLASS" | "RATE_LIMIT" | "ALREADY_UNLOCKED" | "NOT_IN_LOBBY"?,
    }
}
```

**MasteryUpdate Payload (สำคัญ):**
```lua
{
    classMastery = {
        Normal = { level = 3, xp = 40, xpToNext = 156, isMax = false },
        Runner = { level = 1, xp = 0, xpToNext = 100, isMax = false },
    },
    masteryRewards = {
        Normal = {
            { id = "normal_title_balanced_cadet", level = 5, rewardType = "Title", rarity = "Common", name = "Balanced Cadet", unlocked = false },
        },
    },
    classId = "Normal", -- currently equipped class
    action = { -- optional
        type = "xp",
        classId = "Normal",
        xpGained = 20,
        leveledUp = true,
        newLevel = 3,
        reason = "StageComplete" | "Finish",
        unlockedRewards = { -- optional (when level-up crosses reward milestone)
            { id = "normal_title_balanced_cadet", level = 5, rewardType = "Title", rarity = "Common", name = "Balanced Cadet", unlocked = true },
        },
    }
}
```

**TitleUpdate Payload (สำคัญ):**
```lua
{
    titleCatalog = {
        { id = "normal_title_balanced_cadet", name = "Balanced Cadet", classId = "Normal", level = 5, rarity = "Common", unlocked = true },
        { id = "runner_title_quickstep", name = "Quickstep", classId = "Runner", level = 5, rarity = "Common", unlocked = false },
    },
    unlockedTitles = {
        { id = "normal_title_balanced_cadet", name = "Balanced Cadet", classId = "Normal", level = 5, rarity = "Common" },
    },
    activeTitle = { -- หรือ nil ถ้ายังไม่ใส่
        id = "normal_title_balanced_cadet",
        name = "Balanced Cadet",
        classId = "Normal",
        level = 5,
        rarity = "Common",
    },
    action = { -- optional
        type = "equip" | "clear" | "unlock" | "error",
        titleId = "normal_title_balanced_cadet"?,
        reason = "TITLE_LOCKED" | "INVALID_TITLE"?,
    }
}
```

### เพิ่ม RemoteEvent ใหม่:

1. เพิ่มใน `default.project.json`:
```json
"NewEvent": {
    "$className": "RemoteEvent"
}
```

2. ใช้งานใน Server:
```lua
local remote = ReplicatedStorage.Remotes.NewEvent
remote.OnServerEvent:Connect(function(player, data)
    -- handle
end)
remote:FireClient(player, data)
```

3. ใช้งานใน Client:
```lua
local remote = ReplicatedStorage.Remotes.NewEvent
remote:FireServer(data)
remote.OnClientEvent:Connect(function(data)
    -- handle
end)
```

---

## 📊 Roblox Leaderstats

### ไฟล์: `src/server/ScoreManager.luau`

Leaderstats เป็น built-in UI ของ Roblox ที่แสดงสถิติผู้เล่นอัตโนมัติ (แสดงใน PlayerList ด้านขวาของหน้าจอ)

### การทำงาน:

1. **สร้าง leaderstats folder** ใน Player object (ฝั่ง Server)
2. **เพิ่ม IntValue** ลงใน folder (ชื่อจะเป็นชื่อคอลัมน์ใน UI)
3. **Roblox แสดง UI อัตโนมัติ** เมื่อมี leaderstats folder

### ฟังก์ชันที่เกี่ยวข้อง:

**`setupLeaderstats(player)`** - สร้าง leaderstats folder และ IntValues:
- `HighScore`: คะแนนสูงสุด
- `RoundScore`: คะแนนรอบปัจจุบัน
- `Currency`: เงิน (💰)

**`updateLeaderstats(player)`** - อัพเดทค่าใน leaderstats:
- อัพเดท HighScore จาก playerData
- อัพเดท RoundScore จาก playerData
- อัพเดท Currency จาก CurrencyManager

### ตัวอย่างการใช้งาน:

```lua
-- ใน ScoreManager.luau
function ScoreManager:setupLeaderstats(player: Player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player
    
    -- HighScore
    local highScore = Instance.new("IntValue")
    highScore.Name = "HighScore"
    highScore.Value = 0
    highScore.Parent = leaderstats
    
    -- RoundScore
    local roundScore = Instance.new("IntValue")
    roundScore.Name = "RoundScore"
    roundScore.Value = 0
    roundScore.Parent = leaderstats
    
    -- Currency
    local currency = Instance.new("IntValue")
    currency.Name = "Currency"
    currency.Value = 0
    currency.Parent = leaderstats
end
```

### ข้อควรระวัง:

- **ชื่อ IntValue** จะเป็นชื่อคอลัมน์ใน UI (เช่น "HighScore", "RoundScore", "Currency")
- **ต้องเป็น IntValue หรือ NumberValue** เท่านั้น (StringValue จะไม่แสดง)
- **ต้องอยู่ใน folder ชื่อ "leaderstats"** เท่านั้น (case-sensitive)
- **ต้องอยู่ใน Player object** (ไม่ใช่ Character)
- **อัพเดทค่า**: เรียก `updateLeaderstats()` เมื่อต้องการอัพเดทค่า (เช่น เมื่อ HighScore เปลี่ยน)

### การอัพเดท Currency:

Currency จะอัพเดทอัตโนมัติเมื่อ:
- เรียก `updateLeaderstats()` (เช่น เมื่ออัพเดท HighScore)
- CurrencyManager จะดึงค่า currency ปัจจุบันมาแสดง

---

## 🎨 การแก้ไข UI

### ไฟล์หลัก: `src/client/UI/`

### UI ที่มีอยู่:

| Module | ตำแหน่ง | Description |
|--------|---------|-------------|
| `ScoreUI` | มุมบนซ้าย | ⭐ คะแนน + 🏆 High Score + 🚩 Progress Bar |
| `CurrencyUI` | มุมบนซ้าย (ใต้ StageFrame) | 💰 แสดงเงิน |
| `ClassSelectionUI` | มุมบนซ้าย (ใต้ Currency) | 🎭 แสดง Class indicator + คลิกเปิด modal เลือก Class (light theme) |
| `TitleHUDUI` | มุมบนซ้าย (ใต้ Class) | 🏷️ แสดง Active Title + ปุ่ม 📋 เปิด Collection |
| `TitleCollectionUI` | กลางจอ (modal) | 🏷️ หน้ารวม Title ทั้งหมด + filter/search/equip |
| `TutorialUI` | มุมบนซ้าย (Y=240) + กลางจอ (popup) | ❓ ปุ่ม "?" + Game Guide 5 tabs (RichText) |
| `ItemUI` | มุมล่างขวา | 🎯 2 Item slots (horizontal) + Tooltip |
| `ItemTestingUI` | มุมบนขวา (toggle) | 🧪 เมนูทดสอบ Item (กด T) |
| `FlyController` | ล่างซ้าย | FLY [F] ปุ่ม + Speed controls |
| `StageSelectionUI` | กลางจอ | ⭐ เลือกลำดับด่าน + Countdown |
| `SummaryUI` | กลางจอ (popup) | 🏆 Summary เมื่อจบเกม |
| `MatchLobbyUI` | กลางจอ | 🏁 Matchmaking lobby + Rankings |
| `RaceResultsUI` | กลางจอ (popup) | 🏁 ผลการแข่งขัน |
| `SpectatorUI` | กลางจอ (popup + HUD) | 👁️ Spectate prompt + rankings + camera controls |
| `DailyBonusUI` | มุมล่างซ้าย (HUD btn) + กลางจอ (popup) | 🎁 Daily Login 7-day calendar + claim/view mode |
| `LeaderboardUI` | — (stub) | 🏆 ไม่มี UI จริง — ดู Global Leaderboard ที่ป้ายกายภาพใน lobby |
| `MobileInputUI` | มุมล่าง (มือถือเท่านั้น) | 📱 Touch buttons: Item1/2, Sprint, Jump |

### StageSelectionUI:
- **ปุ่มด่าน 1-5**: คลิกเพื่อเพิ่ม/ลบจากลำดับ
- **Selected display**: แสดงลำดับที่เลือก (เช่น "3 → 1 → 5") + รางวัลรวม
- **ปุ่ม RANDOM**: สุ่มลำดับด่าน
- **ปุ่ม START**: กดได้เมื่อเลือกอย่างน้อย 1 ด่าน
- **Countdown**: แสดง 3, 2, 1 ก่อน teleport
- **Stage Reward**: แสดง `💰 +X` บนแต่ละปุ่มด่าน (รางวัลเมื่อผ่าน)

### SummaryUI (Game Complete):
- **แสดงเมื่อ**: จบเกม (finish)
- **Stages Played**: แสดงด่านที่เล่น + รางวัลแต่ละด่าน
- **STATS**: Score + Time
- **CURRENCY EARNED** (breakdown):
  - Coins (X x 1) = +X
  - Stage Clear (X x 5) = +X
  - Stage Rewards = +X
  - Finish Bonus = +25
  - **TOTAL EARNED** = รวมทั้งหมด
- **OK Button**: ปิด popup
- **Auto teleport**: กลับ Lobby หลัง 5 วินาที

---

## 🎨 UI Design System (Fall Guys Style)

### ThemeConfig: `src/shared/ThemeConfig.luau`

**ต้อง require ก่อนสร้าง UI ทุกครั้ง — ห้ามใช้ inline Color3:**

```lua
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)
```

### Palette Tokens

| Token | RGB | ใช้สำหรับ |
|-------|-----|----------|
| `Theme.BG_BASE` | (45, 30, 75) | พื้นหลัง panel หลัก |
| `Theme.BG_SURFACE` | (65, 50, 105) | card / section |
| `Theme.BG_ELEVATED` | (85, 68, 135) | hover / selected |
| `Theme.BG_OVERLAY` | (25, 15, 50) | modal dim / darkest |
| `Theme.PRIMARY` | (255, 220, 0) | ปุ่มหลัก (เหลือง) |
| `Theme.PRIMARY_DARK` | (200, 165, 0) | hover/pressed |
| `Theme.SECONDARY` | (255, 85, 50) | destructive / energy |
| `Theme.ACCENT_CYAN` | (80, 220, 255) | info / highlight |
| `Theme.ACCENT_PINK` | (255, 100, 180) | fun / special |
| `Theme.TEXT_PRIMARY` | (255, 255, 255) | text บน dark bg |
| `Theme.TEXT_MUTED` | (195, 178, 230) | secondary text |
| `Theme.SUCCESS` | (80, 230, 120) | equip / success |
| `Theme.DANGER` | (255, 70, 70) | leave / locked / danger |
| `Theme.WARNING` | (255, 200, 0) | time warning / can-buy |
| `Theme.INFO` | (80, 200, 255) | cyan info |

### Structure Tokens

| Token | Value | ใช้สำหรับ |
|-------|-------|----------|
| `Theme.CORNER_SM` | 8px | buttons, small badges |
| `Theme.CORNER_MD` | 14px | HUD panels, cards |
| `Theme.CORNER_LG` | 20px | modal containers |
| `Theme.CORNER_FULL` | UDim(1,0) | circles / pills |
| `Theme.STROKE_THIN` | 1.5 | default border |
| `Theme.STROKE_MED` | 2.5 | selected / focused |
| `Theme.STROKE_BOLD` | 4 | emphasis / glow |

### Helper Functions

```lua
Theme.rarityColor(rarity)   -- "Common"|"Rare"|"Epic"|"Legendary" → Color3
Theme.classColor(classId)   -- "Runner"|"Jumper"|"Tank" → Color3
Theme.applyCorner(obj, size) -- "sm"|"md"|"lg"|"full" → UICorner
Theme.applyStroke(obj, color, weight, transparency) -- "thin"|"med"|"bold" → UIStroke
```

### UI Rules
1. **ห้าม** ใช้ inline `Color3.fromRGB(...)` สำหรับสีพื้นหลัง/ข้อความ
2. **ต้อง** require ThemeConfig ทุกไฟล์ UI
3. Background: `BG_BASE` → `BG_SURFACE` → `BG_ELEVATED` (dark → light)
4. Font: Gotham family เท่านั้น (Gotham, GothamBold, GothamBlack)
5. Text บน dark bg = `TEXT_PRIMARY` (white)

### Checklist สำหรับ UI ใหม่

- [ ] `local Theme = require(ReplicatedStorage.Shared.ThemeConfig)`
- [ ] background ใช้ `BG_BASE` / `BG_SURFACE` / `BG_ELEVATED`
- [ ] ปุ่มหลัก = `PRIMARY` (yellow), success = `SUCCESS`, danger = `DANGER`
- [ ] text = `TEXT_PRIMARY` หรือ `TEXT_MUTED`
- [ ] UICorner: panel = `CORNER_MD`, button = `CORNER_SM`, modal = `CORNER_LG`
- [ ] ลงทะเบียนใน `MainUI.luau` ถ้าเป็น popup

---

### โครงสร้าง UI Module:

```lua
local MyUI = {}
MyUI.__index = MyUI

function MyUI.new(parent: ScreenGui)
    local self = setmetatable({}, MyUI)
    self.parent = parent
    self:createUI()
    return self
end

function MyUI:createUI()
    -- สร้าง UI elements
end

function MyUI:update(data)
    -- อัพเดท UI
end

return MyUI
```

### เพิ่ม UI ใหม่:

1. สร้างไฟล์ใน `src/client/UI/NewUI.luau`
2. Require ใน `MainUI.luau`:
```lua
local NewUI = require(script.Parent.NewUI)
self.newUI = NewUI.new(screenGui)
```

---

## 🔧 Game Flow

```
Player Joins
    ↓
Spawn at Lobby (Config.Lobby.SpawnPosition = 0, 103, 0)
    ↓
GameManager:onPlayerAdded()
    ↓
ScoreManager:initPlayer() + CurrencyManager:initPlayer() + ItemManager:initPlayer()
    ↓
เดินเข้า SelectionZone (สี Magenta)
    ↓
แสดง GUI เลือกด่าน
    ↓
เลือกลำดับด่าน หรือ กด RANDOM
    ↓
กด START → Server สร้าง Map
    ↓
Countdown 3, 2, 1
    ↓
Teleport to Stage 1 (หันไปทาง +X)
    ↓
Playing (checkPlayerPosition loop ทุก 0.5 วินาที)
    ↓
Pass Checkpoint → onStageComplete():
  - ScoreManager:addStageScore()
  - CurrencyManager:addCurrency(PerStage) ← Stage Clear bonus
  - CurrencyManager:addCurrency(StageReward) ← Stage Reward ตามด่าน
    ↓
Touch EndPart of last stage (Finish Line)
    ↓
GameManager:onPlayerFinished() → Set teleportingToLobby flag
    ↓
Give bonuses for LAST stage:
  - Stage Clear bonus (PerStage)
  - Stage Reward (ตามด่านสุดท้าย)
  - Finish Bonus
    ↓
Show SummaryUI popup (Currency breakdown)
    ↓
Wait 5 seconds
    ↓
GameManager:teleportToLobby() → Use Config.Lobby.SpawnPosition
    ↓
Clear teleportingToLobby flag after 0.5 วินาที
    ↓
Back to Lobby (State = "Lobby")
```

---

## 🧪 Testing

**หมายเหตุ**: Fly Mode และ Item Testing อยู่หลัง `Config.Debug` flags - ต้องเปิดก่อนใช้งาน

### Fly Mode (ทดสอบ) - ต้อง `Config.Debug.FlyMode = true`:
- กด **F** เพื่อบิน
- **W/A/S/D** เคลื่อนที่
- **Space** ขึ้น, **Shift/Ctrl** ลง
- ปุ่ม **+/-** ปรับความเร็ว (25-200)

### Item Testing - ต้อง `Config.Debug.ItemTesting = true`:
- กด **T** เพื่อเปิด/ปิดเมนูทดสอบ Item
- เลือก item ที่ต้องการ (แบ่งกลุ่มตาม rarity)
- กด "Clear All Items" เพื่อล้าง items ทั้งหมด
- กด **"🎁 Reset Daily Login"** เพื่อรีเซ็ต streak + รับรางวัลวันที่ 1 ทันที (debug only)

### Item Controls:
- กด **1** = ใช้ item ช่องซ้าย
- กด **2** = ใช้ item ช่องขวา
- คลิกที่ item = ดู description

### Debug Output:
```
[Server] Starting Obby Game...
[GameManager] PlayerName entered selection zone
[MapManager] Stage order: 3, 1, 5, 2, 4
[GameManager] PlayerName started the obby!
[GameManager] PlayerName completed stage 1
[GameManager] PlayerName FINISHED THE OBBY!
[GameManager] Teleporting PlayerName to lobby at: 0, 103, 0
[GameManager] Teleport successful for PlayerName
[GameManager] PlayerName returned to lobby
```

### สิ่งที่ต้องทราบเกี่ยวกับ Finish Line:
- **Touch Detection**: EndPart ของ stage สุดท้ายมี `Touched` event ตรวจจับ
- **Position Check**: ระบบยังเช็คตำแหน่งด้วย `isAtFinishLine()` (loop-based)
- **Flag Protection**: ใช้ `teleportingToLobby` flag ป้องกันการเรียกซ้ำ
- **Teleport**: ใช้ `Config.Lobby.SpawnPosition` แทนการหา SpawnLocation (เสถียรกว่า)
- **Delay**: รอ 2 วินาทีก่อน teleport
- **DataStore**: จะ fail ใน Studio ถ้าไม่เปิด API access (ปกติใช้ได้จริง)

### Commands (เพิ่มเองได้):
สามารถเพิ่ม admin commands ใน `init.server.luau`:
```lua
Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
        if message == "/regen" then
            game_manager:regenerateMap()
        end
    end)
end)
```

---

## 📝 Quick Reference

### Constants:

| Constant | Value | Location |
|----------|-------|----------|
| `STAGE_LENGTH` | `Config.Stages.StageLength` (100) | StageTemplates.luau |
| `Config.Stages.TotalCount` | 7 | Config.luau |
| `Config.Stages.SelectionCount` | 5 | Config.luau |
| `Config.Stages.StartOffset` | (-150, 0, 250) | Config.luau |
| `Config.Lobby.SpawnPosition` | (0, 103, 0) | Config.luau |
| `Config.KillZoneY` | -120 | Config.luau |
| `Friction` | 2.0 | StageTemplates.luau |
| `Config.Timing.PositionCheckInterval` | 0.5 วินาที | Config.luau |
| `Config.Timing.SelectionZoneInterval` | 0.2 วินาที | Config.luau |
| `Config.Timing.AutoTeleportDelay` | 5 วินาที | Config.luau |
| `Config.Timing.AutoSaveInterval` | 30 วินาที | Config.luau |
| `Config.Map.StageGapStuds` | 10 studs | Config.luau |
| `Config.Map.FinishLineRadius` | 20 studs | Config.luau |
| `Config.Map.PlatformServoForce` | 1000000 | Config.luau |

---

## ⚠️ Important Notes

### 🏗️ Core System
1. **SpawnLocation**: ต้องอยู่ใน Workspace โดยตรง ไม่ใช่ใน Folder
2. **SelectionZone**: ใช้ loop-based detection ทุก 0.2 วินาที
3. **Checkpoint**: ใช้ `Part` ไม่ใช่ `SpawnLocation`
4. **Moving Platform**: ใช้ `PrismaticConstraint` (physics-based)
5. **Friction**: ทุก Part มี Friction = 2.0
6. **Stage ต้องมี**: StartPart, EndPart, Checkpoint, Obstacles folder, ItemPickups folder
7. **Rojo**: ใช้ `rojo serve` เพื่อ sync กับ Studio

### 💾 DataStore (Auto-save)
8. **DataStore Name**: `ObbyGameData_v1` - เปลี่ยนชื่อถ้าต้องการ reset
9. **Auto-save**: ทั้ง ScoreManager และ CurrencyManager save ทุก 30 วินาที (ลด request)
10. **Pending Saves**: ใช้ `pendingSaves` flag เพื่อ track ว่าต้อง save หรือไม่
11. **On Leave**: Save ทันทีเมื่อผู้เล่นออก (ถ้ามี pending)
12. **Shared Player Key**: ใช้ key เดียว `Player_<UserId>` และ save ด้วย `UpdateAsync` (atomic, ป้องกัน race condition)
13. **Class Fields**: ใน profile มี `unlockedClasses` + `equippedClass` ถาวรต่อบัญชี
14. **Title Field**: ใน profile มี `activeTitle` (string? หรือ nil) สำหรับ title ที่ใส่อยู่
15. **Daily Login Fields**: ใน profile มี `lastLoginTime` (number?) + `loginStreak` (number 1–7)

### 🎯 Item System (Mario Kart Style)
14. **Dual Slots**: ผู้เล่นถือได้ 2 items, กด 1/2 เพื่อใช้
15. **Item Box**: "Neon Cube" style (สีม่วง-น้ำเงิน) + bobbing animation
16. **Weighted Random**: คนอันดับท้ายได้ item หายากมากกว่า (catch-up)
17. **Item Tooltip**: คลิกที่ item เพื่อดู description (auto-hide 6 วินาที)
18. **Rarity Colors**: Common=เทา, Uncommon=เขียว, Rare=น้ำเงิน, Epic=ม่วง
19. **Item Icons**: ใช้ emoji (🚀🍌🛡️⚡🔄⚡🌩️)
20. **Item Testing**: กด T เปิดเมนูทดสอบ + Spawn Dummy สำหรับทดสอบ
21. **Banana Slip**: ล้มไปข้างหลัง + กระโดดไม่ได้ + เจ้าของก็ลื่นได้
22. **Swap**: สลับกับคนที่อยู่ **ข้างหน้า** เท่านั้น (ไม่ใช่ข้างหลัง)
23. **Shield Aura**: มี particles ลอยขึ้น + หมุนรอบตัว + กระพริบเรืองแสง
24. **Test Dummies**: สร้าง Dummy สำหรับทดสอบ Missile/Swap/Lightning

### 🎭 Character Class System
25. **Default Class**: ผู้เล่นใหม่เริ่มที่ `Normal` เสมอ
26. **Unlock Model**: `Normal` ฟรี, `Runner/Jumper/Tank` ต้องซื้อด้วย currency
27. **Auto Equip**: ซื้อสำเร็จจะสวม class นั้นทันที
28. **Remember Last Class**: เข้าเกมใหม่จะ equip class ล่าสุดอัตโนมัติ
29. **Rate Limit**: `SelectClass` มี cooldown 0.25 วิ กัน spam
30. **Stats Apply**: เมื่อเลือก Class หรือ respawn จะ apply stats ใหม่
31. **Active Title HUD**: มุมบนซ้าย light bar แสดง title + ปุ่ม 📋 เปิด Collection (hint text เมื่อไม่มี title)
32. **Title Collection UI**: หน้า title list แยก (light theme, compact 62px cards, Active Title Banner, rarity border strips)
33. **Title Filter/Search**: รองรับ `All/Unlocked/Locked` + search + Sort dropdown (Class/Rarity/Level)
34. **Modal Exclusion**: Class modal กับ Title Collection เปิดพร้อมกันไม่ได้
35. **Light Theme**: Class modal, Title HUD, Title Collection ใช้ light palette (white/near-white backgrounds)

### 🏁 Match/Race System
34. **Match Config**: `Config.Match` - MinPlayers, MaxPlayers, WaitTime, TimeLimit
35. **Testing Mode**: `IsTestingMode = true` → WaitTime = 3 วินาที
36. **Time Limit**: 15 นาทีต่อ match พร้อมแจ้งเตือน
37. **Rankings**: คำนวณจาก stage + distance ใน stage

### 💰 Currency System
38. **Stage Rewards**: อยู่ใน `StageInfo.luau` → `StageInfo.getStage(id).reward` (S1=3, S2=4, S3=4, S4=5, S5=6, S6=6, S7=7)
39. **Currency Breakdown**: Stage Clear (5) + Stage Rewards + Finish Bonus (25)
40. **CurrencyUI**: มุมบนซ้าย (ใต้ StageFrame)

### 🖥️ UI Layout (มุมบนซ้าย จากบนลงล่าง)
41. **Y=10**: Score Frame (⭐ คะแนน)
42. **Y=16**: High Score (🏆)
43. **Y=58**: Stage Frame (🚩 Progress)
44. **Y=92**: Currency Frame (💰 เงิน)
45. **Y=140**: Class Indicator (🎭 Class - light pill 168x40 + mastery badge + chevron)
46. **Y=186**: Active Title HUD (🏷️ light bar 220x36 + ปุ่ม 📋 เปิด Collection)
47. **Y=240**: Tutorial "?" Button (❓ วงกลม 40x40 + hint label ข้างๆ)

### 📊 Leaderstats
47. **Built-in UI**: แสดง HighScore, RoundScore, Currency
48. **Update**: เรียก `updateLeaderstats()` เมื่อค่าเปลี่ยน

### 📈 Class Mastery
49. **Mastery Data**: เก็บใน profile key เดียวกับ score/currency ที่ field `classMastery`
50. **Mastery Rewards Data**: เก็บสถานะ reward ที่ปลดแล้วใน field `masteryRewards`
51. **XP Sources**: ผ่านด่านได้ `PerStageXP` และเข้าเส้นชัยได้ `FinishBonusXP`
52. **UI Display**: แสดงทั้ง level/xp บน class card และ preview rewards ของ class ที่เลือก
53. **Remote**: ใช้ `MasteryUpdate` ส่ง level/xp/xpToNext/isMax + masteryRewards + unlockedRewards action

### ❓ Tutorial System
54. **ปุ่ม "?"**: Y=240 มุมบนซ้าย (ใต้ TitleHUD), วงกลม 40x40
55. **Hint**: ผู้เล่นใหม่เห็น "Tap ? for help!" (fade out หลัง 8 วิ), persist ใน DataStore (`hasSeenTutorial`)
56. **Panel**: 680x500 กลางจอ, dark theme, overlay 2x จอ (มืด 70%)
57. **Tabs**: 5 tabs (Movement/Items/Classes/Mastery/Ultimates) อ่านจาก `Config.Tutorial.Sections`
58. **RichText**: content ใช้ `<font color="">` + `<b>` สำหรับ headers/keys/class names สีต่างๆ
59. **Popup Exclusion**: Tutorial, ClassSelection, TitleCollection เปิดพร้อมกันไม่ได้ (MainUI จัดการ callbacks)
60. **Remote**: `TutorialSeen` fire ครั้งแรกที่เปิด → server save `hasSeenTutorial = true`

### 👁️ Spectator Mode
61. **Spectate Prompt**: แสดง "SPECTATE" + "LEAVE" หลังจบ race ใน match ที่ยังแข่ง (`canSpectate` flag)
62. **SpectatorCamera**: Follow mode (lerp behind target) + FreeCam mode (WASD + mouse look)
63. **SpectatorUI**: HUD top label, left rankings panel, bottom controls (Prev/ModeToggle/Next/Leave)
64. **Rankings**: จาก `RaceUpdate` data (table objects: `{playerName, position, finished, finishTime, stage}`)
65. **Auto-exit**: Match end → auto-exit spectator, teleport lobby
66. **Character hide**: Spectating → Transparency=1, Anchored=true; Leave → restore + teleport lobby
67. **Config**: `Config.Spectator` (FreeCamSpeed=50, FollowDistance=15, FollowHeight=8, CameraSmoothness=0.1)

### 📱 Mobile Touch Buttons
68. **Detection**: `UserInputService.TouchEnabled` — ไม่สร้าง UI ถ้าไม่ใช่มือถือ
69. **Buttons**: Item 1/2 (ขวาล่าง 70x70), Sprint/Jump (ซ้ายล่าง 70x70)
70. **Integration**: เรียก `itemUI:useItemFromSlot(1/2)` และ `ultimateSkillController:tryActivateSprint()/tryDoubleJump()`
71. **Heartbeat**: loop อัพเดทสถานะปุ่ม (item icon, cooldown, ultimate visibility)
72. **Sprint/Jump**: ซ่อนเมื่อไม่มี ultimate ที่ปลดล็อค

### 🎁 Daily Login
73. **7-Day Streak**: streak reset เมื่อไม่ได้ login 48 ชั่วโมง, วนซ้ำหลัง Day 7
74. **Popup Guard**: `_calendarOpen` flag ป้องกัน calendar popup ซ้อน
75. **lastData.claimed**: หลังปิด claim popup จะเซ็ตเป็น `false` เสมอ (ป้องกัน re-claim บน HUD)
76. **Testing**: ใช้ "🎁 Reset Daily Login" ใน Item Testing menu (T) — ต้อง `Config.Debug.Enabled = true`

### 🏆 Global Leaderboard
77. **DataStore**: ใช้ `OrderedDataStore` แยกต่างหาก (`ObbyLeaderboard_v1`)
78. **Physical Board**: Part ชื่อ `GlobalLeaderboard` ใน workspace — วางเองใน Studio ได้ (จะใช้ตำแหน่งนั้น)
79. **Default Position**: `(22, 109, 12)` หันหน้า -X ขวาของ stage select area
80. **Refresh**: broadcast ทุก 60 วินาที + เมื่อผู้เล่นจบเกม

### 🔊 Sound Manager
81. **Asset IDs ว่าง**: SoundManager มีโครงสร้างแต่ทุก ID เป็น `""` — ต้องใส่ rbxassetid ก่อนเกมมีเสียง
82. **Safe**: ตรวจสอบ SoundId ก่อนเล่น ไม่ error ถ้า ID ว่าง

### 🔧 Code Quality (Audit Feb 2026)
83. **Debug Flags**: `Config.Debug.Enabled`, `FlyMode`, `ItemTesting`, `MasteryTesting` - ต้อง set `false` ก่อน production
84. **Logger**: `src/shared/Logger.luau` - ใช้ `Logger.debug/info/warn/error(tag, ...)` แทน `print("[Tag]", ...)`
85. **os.clock()**: ใช้ `os.clock()` แทน `tick()` ทั้ง project (tick deprecated)
86. **LinearVelocity/AngularVelocity**: ใช้ constraint-based แทน BodyVelocity/BodyAngularVelocity (deprecated)
87. **UpdateAsync**: DataStore ใช้ `UpdateAsync` (atomic) ไม่ใช่ `GetAsync`+`SetAsync` (race condition)
88. **Connection Cleanup**: CharacterAdded/Died connections ถูก track ใน `playerConnections` table และ disconnect เมื่อ player leave
89. **Input Validation**: `ConfirmStageSelection` remote ผ่าน `validateStageOrder()` ก่อนใช้งาน
90. **Shared Map Limitation**: Map เป็น global shared ใน workspace - ถ้า 2+ players เล่นพร้อมกันจะมีปัญหา (ต้องทำ instanced map ในอนาคต)
91. **Race Direction**: Stages progress ตามแกน +X (ไม่ใช่ +Z) - "ahead" check ใช้ `Position.X`

### 🏗️ Architecture (Refactored Feb 2026)
92. **GameManager split**: SpectatorManager + SelectionZoneManager แยกออกจาก GameManager ใช้ dependency injection pattern
93. **DataStoreHelper**: DataStore ทุก module ควรใช้ `DataStoreHelper.loadAsync()` + `DataStoreHelper.saveAsync()` (retry 3 ครั้ง, exponential backoff, schema versioning)
94. **RemoteRegistry**: ใช้ `RemoteRegistry.get("EventName")` แทนการ WaitForChild ตรงๆ (cached, safe fallback)
95. **TweenHelper**: Animation ซ้ำๆ ให้ใช้ `src/client/TweenHelper.luau` (pop, fadeIn, fadeOut, slideIn, glowStroke, colorFlash)
96. **UIFactory**: UI ใหม่ให้ใช้ `src/client/UI/UIFactory.luau` สำหรับ createPanel/createButton/createLabel แทนการสร้าง Instance ตรงๆ
97. **humanoidRootPart**: ใช้ชื่อเต็มเสมอ (ไม่ใช่ `hrp`) ทั้ง project
98. **StageInfo (single source of truth)**: Stage metadata ทั้งหมด (name, icon, difficulty, color, reward) อยู่ใน `StageInfo.luau` — ห้าม hardcode ใน UI
99. **Balanced Random**: `MapManager:balancedRandomStages()` ใช้แทน `shuffleStages()` เมื่อเลือก RANDOM (การันตีทุกระดับความยาก)
100. **TotalCount vs SelectionCount**: `Config.Stages.TotalCount` = pool size (7), `Config.Stages.SelectionCount` = per-run size (5)
101. **Stage Tab Filter**: `switchTab(diff)` → `refreshStageButtons()` จัด `Visible`+`Position` บน buttonContainer; `show()` ต้องเรียก switchTab หลัง loop ที่ set Visible=true
102. **Tab Selection Global**: selectedStages ไม่ reset เมื่อเปลี่ยน tab — selection ข้าม tab ได้, max = SelectionCount รวม
98. **MapManager internal**: ฟังก์ชัน `_xxxInternal()` เป็น internal helpers สำหรับ global/per-match deduplication — ห้ามเรียกจากนอก MapManager
99. **Config.Timing / Config.Map**: Magic numbers เวลาและ map ทั้งหมดอยู่ใน Config แล้ว — ไม่ hardcode ค่าใหม่
