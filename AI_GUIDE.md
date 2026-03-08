# AI Development Guide - Roblox Obby Game

คู่มือสำหรับ AI ที่จะมาพัฒนาต่อ

## 📁 Project Structure

```
src/
├── server/                      # Server-side code
│   ├── init.server.luau         # Entry point - สร้าง GameManager
│   ├── GameManager.luau         # ควบคุมเกมทั้งหมด (orchestrator)
│   ├── MapManager.luau          # จัดการ map/stages + animations + per-match instancing
│   ├── StageTracker.luau         # ⭐ Lightweight stage tracking (per-round, no DataStore)
│   ├── CurrencyManager.luau     # 💰 ระบบเงิน + Class Unlock + Mastery + Daily Login + DataStore
│   ├── ItemManager.luau         # 🎯 ระบบ Items แบบ Mario Kart
│   ├── MatchManager.luau        # 🏁 ระบบ Matchmaking/Race + Stage Voting
│   ├── ClassManager.luau        # 🎭 ระบบ Character Classes
│   ├── LeaderboardManager.luau  # 🏆 Dual Leaderboards: Gems + Wins (2 OrderedDataStores + 2 Physical Boards)
│   ├── SpectatorManager.luau    # 👁️ ระบบ Spectator Mode (แยกจาก GameManager)
│   ├── SelectionZoneManager.luau # ⭐ ระบบ SelectionZone detection + stage confirm (แยกจาก GameManager)
│   ├── ShopManager.luau        # 🛒 ระบบ Shop purchases (item buy with coins + class gacha with gems) + rate limiting + state sync
│   ├── ShopZoneManager.luau    # 🛒 ระบบ ShopZone detection + model placement (InsertService)
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
│       ├── MainUI.luau          # Controller หลัก (panel mutual exclusion + MenuGridUI wiring)
│       ├── UIFactory.luau       # 🏗️ Reusable UI component factory (createPanel/Button/Label/Modal)
│       ├── MenuGridUI.luau      # 📱 2x3 menu button grid (Shop/Classes/Titles/Daily/Help/Settings) — left side, vertically centered
│       ├── ScoreUI.luau         # 💎 แสดง Gems + Stage Progress + Timer (bottom-left)
│       ├── CurrencyUI.luau      # 💰 แสดงเงิน (bottom-left)
│       ├── ItemUI.luau          # 🎯 แสดง Item (2 slots) + Tooltip
│       ├── ItemTestingUI.luau   # 🧪 Testing Menu (items, gems, mastery, solo start, solo wins) — toggle button มุมบนขวา
│       ├── StageSelectionUI.luau # ⭐ GUI เลือกลำดับด่าน
│       ├── SummaryUI.luau       # 🏆 แสดง Summary จบเกม
│       ├── MatchLobbyUI.luau    # 🏁 UI Matchmaking lobby
│       ├── ClassSelectionUI.luau # 🎭 UI เลือก Class (standardized panel layout)
│       ├── TitleHUDUI.luau      # 🏷️ HUD แสดง Active Title (hidden — replaced by MenuGridUI)
│       ├── TitleCollectionUI.luau # 🏷️ หน้ารายการ Title (standardized panel layout)
│       ├── RaceResultsUI.luau   # 🏁 UI ผลการแข่ง
│       ├── TutorialUI.luau      # ❓ Game Guide popup (standardized panel layout, 5 tabs RichText)
│       ├── SpectatorUI.luau     # 👁️ Spectator HUD + prompt + rankings
│       ├── DailyBonusUI.luau    # 🎁 Daily Login 7-day calendar popup (hideHudButton option)
│       ├── ShopUI.luau          # 🛒 Shop popup (standardized panel layout) — 2 tabs: Items + Classes gacha
│       ├── SettingsUI.luau      # ⚙️ Settings panel (Music/SFX toggles)
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
    ├── ClassTypes.luau          # 🎭 นิยาม Classes ทั้งหมด (+ ultimateSkill field)
    ├── ThemeConfig.luau         # 🎨 UI theme tokens + helpers
    └── __tests__/               # 🧪 Jest Lua unit tests
        ├── jest.config.luau     # Jest config
        ├── ClassTypes.spec.luau # Tests for ClassTypes
        ├── ItemTypes.spec.luau  # Tests for ItemTypes
        └── StageInfo.spec.luau  # Tests for StageInfo

scripts/
└── run-tests.server.luau        # 🧪 Jest test runner (run-in-roblox)
```

---

## 🏠 Workspace Structure

```
Workspace/
├── SpawnLocation          # จุดเกิดเริ่มต้น (Slate สีทราย)
├── Lobby/                 # Folder เก็บ Lobby ทั้งหมด (Outdoor Park Theme — เปิดโล่ง ไม่มีเพดาน/ผนัง)
│   ├── FallFloor          # พื้นหญ้าสีเขียว (Grass, 100x2x100, Y=99)
│   ├── SelectionZone      # ⭐ Zone เลือกด่าน (SmoothPlastic สีเหลืองอ่อน, center Z=30)
│   ├── ShopZone           # 🛒 Zone เปิด Shop (Cylinder SmoothPlastic สีส้ม, X=30, Z=5, radius 6)
│   ├── DirtPath_Main      # ทางเดินหลัก Slate สีน้ำตาล (spawn → SelectionZone)
│   ├── DirtPath_ShopBranch # ทางแยกไป Shop
│   ├── Stage_Platform     # แท่น Concrete ยกสูง (24x1.5x24, ใต้ SelectionZone)
│   ├── Stage_Pillar_NE/NW/SE/SW  # เสา Concrete 4 ต้น
│   ├── Stage_Roof         # หลังคาไม้ (Wood, 26x1x26)
│   ├── Stage_RailBack/Left/Right  # ราว Concrete 3 ด้าน (เปิดหน้า)
│   ├── Stage_StepFront    # ขั้นบันไดเข้า (Concrete)
│   ├── Hedge_N/S/E/W      # พุ่มไม้ขอบ Lobby (Grass, สูง 3 studs)
│   └── InvisWall_N/S/E/W  # กำแพงล่องหน (Transparency=1, สูง 20 studs, กันตก)
├── ShopModel              # 🛒 Loaded via InsertService (Asset 2310029676)
├── GemLeaderboard         # 💎 Physical gem leaderboard board (สร้างอัตโนมัติ, X=22)
├── WinLeaderboard         # 🏆 Physical win leaderboard board (สร้างอัตโนมัติ, X=-22)
├── Stages/                # Folder เก็บด่านที่ generate
└── KillBrick              # พื้นที่ตายเมื่อตก
```

**สำคัญ**: 
- `SpawnLocation` ต้องอยู่ใน Workspace โดยตรง ไม่ใช่ใน Folder
- `SelectionZone` ใช้ loop-based detection (เสถียรกว่า Touched events)
- `ShopZone` ใช้ circular radius-based detection (ShopZoneManager), Cylinder shape แบนราบ
- `GemLeaderboard` + `WinLeaderboard` สร้างอัตโนมัติโดย LeaderboardManager (X=±22, Y=106, Z=30)

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
| `createItemPickup(pos)` | `Part` | สร้าง Item pickup (Lucky Block model, asset 129696127925672) |

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
- รูปทรง: **Lucky Block model** (asset ID: 129696127925672) — voxel-style golden "?" block
- โครงสร้าง: invisible hitbox Part (Transparency=1) + cloned Lucky Block model welded via WeldConstraint
- สี: **สีเดิมของ model** (golden) — ไม่มี Neon
- ยกขึ้น: **+3 studs** จากตำแหน่งที่ให้
- หมุน: อัตโนมัติรอบแกน Y (CFrame rotation บน hitbox Part)
- เอฟเฟกต์: **Gold Sparkles** (subtle) + warm PointLight
- Attributes: `IsItemBox = true`, `IsCoin = false`
- Fallback: ถ้า model load ไม่ได้ จะสร้าง yellow SmoothPlastic box แทน
- Strip: ProximityPrompt, ClickDetector, BaseScript ถูกลบออกจาก model อัตโนมัติ

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

    -- Currency Settings
    Currency = {
        PerStage = 5,           -- 💰 Stage Clear bonus (คงที่ต่อด่าน)
        PerCoin = 1,            -- 💰 เงินที่ได้เมื่อเก็บเหรียญ
        FinishBonus = 25,       -- 💰 โบนัสเงินเมื่อเข้าเส้นชัย
        StartingAmount = 0,     -- 💰 เงินเริ่มต้นของผู้เล่นใหม่
        -- 🎯 Stage Rewards อยู่ใน StageInfo.luau (StageInfo.getStage(id).reward)
    },

    -- 💎 Gems (rare premium currency) + 🏆 Wins
    Gems = {
        FinishRace = 1,         -- +1 gem เมื่อเข้าเส้นชัย
        Top30Bonus = 5,         -- +5 gems ถ้าจบ top 30% (multiplayer)
        DailyLoginGems = { [1]=1, [2]=1, [3]=2, [4]=2, [5]=3, [6]=3, [7]=5 },
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
        CurrencyKey = "PlayerCurrency", -- 💰 Key สำหรับเก็บเงิน (gems/wins ก็อยู่ใน profile เดียวกัน)
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
        ItemTesting = true,      -- Toggle button for testing menu (items, mastery, solo start)
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

### Item Box (Lucky Block Style):

```lua
-- สร้าง Item Box (Lucky Block model - ให้ random item)
local itemBox = createItemPickup(position)
-- Style: Golden voxel "?" block (asset 129696127925672)
-- Invisible hitbox + welded model + bobbing/spinning + gold sparkles
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

### Testing Menu (Development):
- กด **toggle button** มุมบนขวา (ไม่มี keyboard shortcut) เพื่อเปิด/ปิด
- **Items**: เลือก item ที่ต้องการให้ตัวเอง (แบ่งกลุ่มตาม rarity)
- **Tools**: Spawn Test Dummy, Remove All Dummies, Clear All Items
- **Daily Login**: Reset Daily Login streak
- **Game Testing**: Solo Wins toggle (ON/OFF), Solo Start (Random)
- **Gems**: แสดงจำนวน gems ปัจจุบัน + ปุ่ม +10/+100/+1000 + Reset (0) — sync ผ่าน UpdateGems remote
- **Mastery**: Per-class level controls (+/-/MAX), Set All Lv 20, Reset All Lv 1

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

1. เปิด **Testing Menu** (toggle button มุมบนขวา)
2. เลื่อนลงไปที่ section **Mastery**
3. กด **Set All Lv 20** เพื่อปลดล็อก ultimate ทุก class
4. เลือก class ที่ต้องการทดสอบ
5. ทดสอบ ultimate skill:
   - **Runner**: กด Shift ขณะวิ่ง
   - **Jumper**: กระโดดแล้วกด Space ในอากาศ
   - **Tank**: โดน Banana/Missile → จะไม่ถูก stun

### Debug Config:

```lua
Debug = {
    Enabled = true,
    FlyMode = true,
    ItemTesting = true,      -- Toggle button for testing menu (items, mastery, solo start)
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
- **Calendar popup** — 7 day cards แสดงสถานะพร้อม icons ตามสถานะ:
  - Past/Claimed → ✅ `\u{2705}`
  - Today (claim available) → 🪙 (coin)
  - Future days 1-6 → 🎁 `\u{1F381}`
  - Future day 7 → 👑 `\u{1F451}` (purple bg `RGB(120,80,180)`)
- **Panel size**: 500×360px (เพิ่มจาก 290px เพื่อรองรับ progress bar + timer)
- **Progress bar**: track + fill (SUCCESS green) + 7 dots — แสดงหลัง card grid, fill fraction = `claimedDay/7`
- **Countdown timer**: `task.spawn` loop อัพเดทตัวนับถอยหลัง — auto-cleans เมื่อ `modalGui:Destroy()` (ตรวจสอบ `not label.Parent`)
- **isClaim mode**: ปุ่ม "✨ CLAIM!" → กด → green overlay ✓ ทับ card → ปิดใน 1.2 วิ
- **view mode**: ปุ่ม "OK", today card แสดง ✓ สีเขียว, countdown แสดงเวลาถึงรางวัลถัดไป
- guard `_calendarOpen`: ป้องกันเปิด popup ซ้อนกัน
- **Modal ScreenGui**: popup เปิดใน ScreenGui แยก (`DailyLoginModalGui`, `DisplayOrder=100`, `IgnoreGuiInset=true`) — overlay ครอบคลุมเหนือ HUD elements ทุกตัว — ปิดแล้ว `modalGui:Destroy()` ล้างทุกอย่างพร้อมกัน
- **Server payload** (CurrencyManager): `FireClient` ส่ง `lastLoginTime` + `cooldownHours` เพื่อให้ client คำนวณ countdown

### Testing:
- เปิด Testing Menu (toggle button มุมบนขวา) → "🎁 Reset Daily Login" → รีเซ็ต streak ทันที (debug only)

### OBBY CHALLENGE Welcome Popup (`init.client.luau`):
- **ตำแหน่ง**: `showWelcomeMessage()` ใน `src/client/init.client.luau` — แสดงครั้งแรกเมื่อ character spawn
- **Panel size**: 480×240px, `AnchorPoint=(0.5,0.5)`, Position `(0.5,0,0.4,0)` (centered ด้านบน)
- **Background**: `Theme.BG_SURFACE`, UIGradient `BG_SURFACE→BG_BASE` (135°), `BackgroundTransparency=0`
- **Stroke**: `Theme.ACCENT_CYAN`, `STROKE_MED`, transparency=0.2
- **Corner**: `Theme.CORNER_LG`
- **Title**: "🏃 OBBY CHALLENGE 🏃", GothamBlack 36px, `Theme.ACCENT_CYAN`; UIStroke `HUD_SCORE_END` 1.5px (0.4 transparency)
- **Info text** (RichText=true): colored keywords
  - `BLUE ZONE` → `<font color="#50DCFF"><b>...</b></font>` (hardcoded cyan — blue zone is blue)
  - `[1]` `[2]` → `<font color="#FFC800"><b>...</b></font>` (PRIMARY yellow)
  - `win!` → `<font color="#50E678"><b>...</b></font>` (SUCCESS green)
  - Body color: `Theme.TEXT_MUTED`
- **GOT IT! button**: 300×45, 3-layer gradient pattern
  - TextButton (transparent, Text="") + Frame (green gradient `RGB(60,200,100)→RGB(40,170,70)`) + TextLabel (white, ZIndex+1)
  - UIStroke `Theme.SUCCESS`, `STROKE_THIN`, transparency=0.3; Corner `Theme.CORNER_MD`
- **Auto close**: `task.delay(10)` ถ้าไม่กดปุ่ม

---

## 🏆 Dual Leaderboards (Gems + Wins)

### ไฟล์ที่เกี่ยวข้อง:
- `src/server/LeaderboardManager.luau` — สร้าง 2 boards + 2 OrderedDataStores
- `src/server/GameManager.luau` — เรียก `updateGems()`/`updateWins()` เมื่อผู้เล่นจบเกม + `sendToPlayer()` เมื่อ join
- `src/client/UI/LeaderboardUI.luau` — **stub เท่านั้น** (physical boards สร้างโดย LeaderboardManager)

### Physical Boards:
```lua
-- LeaderboardManager สร้าง 2 boards อัตโนมัติใน workspace
-- 💎 GemLeaderboard: X=22, Z=30 (ขวาของ SelectionZone, purple theme)
-- 🏆 WinLeaderboard: X=-22, Z=30 (ซ้ายของ SelectionZone, gold theme)
GEM_BOARD_POS = Vector3.new(22, 106, 30)   -- ขวาของ SelectionZone
WIN_BOARD_POS = Vector3.new(-22, 106, 30)  -- ซ้ายของ SelectionZone
BOARD_SIZE    = Vector3.new(10, 14, 0.5)   -- กว้าง × สูง × บาง
-- SurfaceGui: PixelsPerStud=80, Face=Front, Top 10 rows
-- Colors: ใช้ ThemeConfig tokens
-- Gem board: purple theme, Win board: gold theme
```

### OrderedDataStores:
- `"ObbyLeaderboard_Gems_v1"` — ranks by total gems
- `"ObbyLeaderboard_Wins_v1"` — ranks by total wins

### Key Functions:
| Function | Description |
|----------|-------------|
| `updateGems(player, gems)` | บันทึก gems ลง OrderedDataStore |
| `updateWins(player, wins)` | บันทึก wins ลง OrderedDataStore |
| `broadcast()` | fetch → อัพเดท 2 physical boards + fire LeaderboardUpdate |
| `sendToPlayer(player)` | ส่ง cached top ให้ผู้เล่นที่เพิ่งเข้า |
| `startRefreshLoop()` | refresh ทุก 60 วินาที |

---

## 🛒 Shop System (Items + Class Gacha)

### ไฟล์ที่เกี่ยวข้อง:
- `src/server/ShopManager.luau` — Server purchase validation + class gacha logic
- `src/server/ShopZoneManager.luau` — Zone detection + model placement (InsertService)
- `src/server/ItemManager.luau` — `setItemInSlot()` + `getPlayerSlots()` (used by ShopManager)
- `src/server/GameManager.luau` — Wire ShopManager + ShopZoneManager + remotes + cleanup
- `src/client/UI/ShopUI.luau` — Full 2-tab shop UI (Items + Classes gacha)
- `src/client/UI/MainUI.luau` — Require ShopUI + mutual exclusion
- `src/shared/Config.luau` — `Config.Shop` section (prices, gacha cost/weights)

### Lobby Position:
```
ShopZone: (30, 100.1, 5) — Cylinder วงกลม SmoothPlastic หน้าร้าน
Size: 0.5×12×12 (diameter 12), CFrame rotated flat, CanCollide=false
ShopModel: วางที่ Z+10 จาก zone (ร้านอยู่หลัง zone) via InsertService
```

### Config.Shop:
```lua
Shop = {
    ItemPrices = { Common = 15, Uncommon = 35, Rare = 75, Epic = 150 },
    Gacha = { CostGems = 10, DuplicateGemsBack = 3 },
    GachaWeights = { Runner = 35, Jumper = 35, Tank = 30 },
    RequestCooldown = 0.5,
},
```

### ShopZoneManager (Server):
- ใช้ circular radius-based detection (loop, reuse `Config.Timing.SelectionZoneInterval`)
- `InsertService:LoadAsset(2310029676)` โหลด shop model → วางที่ Z+10 จาก ShopZone
- Model position: ใช้ `GetBoundingBox()` คำนวณ Y ให้ฐานอยู่บนพื้น
- Zone shape: Cylinder แบนราบ (CFrame rotated), detection ใช้ XZ distance <= radius
- Billboard label "SHOP" ลอยเหนือ zone
- Enter zone (state == "Lobby") → fire `ShowShop`
- Leave zone → fire `HideShop`

### ShopManager (Server):
- `ShopManager.new(currencyManager, itemManager, classManager, gameManager)`
- **Item Purchase** (`handleBuyItem`): rate limit → validate item → check lobby state → check price by rarity → check currency → check empty slot → spendCurrency → setItemInSlot → fire ShopUpdate
- **Class Gacha** (`handleGachaPull`): rate limit → check lobby → check gems (10) → spendGems → rollGachaClass (weighted random) → if new: unlockClass + fire ClassUpdate; if duplicate: refund 3 gems
- **Weighted Random** (`rollGachaClass`): cumulative weight selection from `Config.Shop.GachaWeights`
- **State Sync** (`sendStateSync`): fires on shop open, sends currency/gems/unlockedClasses/itemSlots
- Cleanup: `removePlayer(player)` clears rate limit state

### ShopUI (Client) — 780×560px:
- **Header**: "🛒 SHOP" RichText + close (X) button 36x36 (coin/gem pills hidden)
- **Tab Bar**: 2 tabs with count badges — `🎯 Items (6)` / `⚔️ Classes (4)`
  - Active: BackgroundTransparency=0.05; Inactive: 0.85
- **Rarity Legend**: color dots + labels (Common/Uncommon/Rare/Epic) — visible only on Items tab

#### Items Tab:
- UIGridLayout 3 columns, 225×270 cards, centered, sorted by rarity
- Per-rarity card backgrounds: `CARD_BG_COLORS` (dark tinted), `BADGE_BG_COLORS` (mid), `PRICE_BTN_COLORS` (button)
- Each card: rarity badge (top-right pill), large icon (50px emoji), name (18px), description (12px wrapped), price button (pill with $ icon)
- Hover effect: card stroke brightens (Transparency 0.6→0.1, Thickness 1.5→2.5)
- `refreshItemAffordability()`: affordable=rarity color, not enough=gray+muted, no slot="NO SLOT" red
- Buy → fire `BuyShopItem { itemId }`, disable button 0.6s

#### Classes Tab (Gacha):
- ScrollingFrame (CanvasSize 520px) with:
  - "🎰 CLASS GACHA" title + "💎 10 gems per pull" subtitle
  - Large mystery card (85% width, 230px tall) — starts with "?" icon
  - PULL button (85% wide, 52px, purple gradient HUD_GEM_START→END)
  - Banner (result text: "NEW CLASS UNLOCKED!" green / "DUPLICATE +3 gems" yellow)
  - Owned Classes section: dark bg panel, header "🔓 คลาสที่ปลดล็อค" + "X/4" count, class icons (58×58) with lock/emoji/checkmark states

#### Gacha Card Flip Animation:
1. Show mystery card ("?") — 0.5s hold
2. Flip out: width shrinks to 0 (0.3s, Quad In)
3. At midpoint: swap to class icon/name/color/description
4. Flip in: width expands back (0.3s, Back Out)
5. Glow stroke: class color pulse (thickness 2→4→2)
6. Banner fade in → fade out after 2.5s
7. Re-enable PULL after 2s

### RemoteEvents:
| Event | Direction | Usage |
|-------|-----------|-------|
| `ShowShop` | Server → Client | เปิด ShopUI (เดินเข้า ShopZone) |
| `HideShop` | Server → Client | ปิด ShopUI (ออกจาก ShopZone) |
| `BuyShopItem` | Client → Server | ซื้อ item `{ itemId }` |
| `GachaClassPull` | Client → Server | สุ่มคลาส (ใช้ gems) |
| `ShopUpdate` | Server → Client | State sync / purchase result / gacha result / error |

### ShopUpdate Payload Types:
```lua
-- State sync (on shop open)
{ type = "stateSync", currency = 100, gems = 15, unlockedClasses = {...}, itemSlots = {...} }

-- Item purchase success
{ type = "itemPurchase", success = true, itemId = "SpeedBoost", slot = 1, currency = 85 }

-- Gacha result (new class)
{ type = "gachaResult", isNew = true, classId = "Runner", gems = 5 }

-- Gacha result (duplicate + partial refund)
{ type = "gachaResult", isNew = false, classId = "Runner", gemsRefunded = 3, gems = 8 }

-- Error
{ type = "error", reason = "INSUFFICIENT_FUNDS" | "INSUFFICIENT_GEMS" | "NO_EMPTY_SLOT" | "NOT_IN_LOBBY" | "RATE_LIMIT" | "INVALID_ITEM" }
```

### Class Purchase Flow Change:
- **ก่อน**: ClassSelectionUI ซื้อคลาสด้วย coins (BUY & EQUIP button)
- **หลัง**: Gacha ใน ShopUI แทนที่การซื้อตรง — ClassSelectionUI แสดง "Get from Shop" สำหรับคลาสที่ล็อค, ปุ่ม confirm เป็น "GACHA IN SHOP" (disabled)
- `ClassUpdate.classCosts` ยังส่งอยู่แต่ไม่ใช้ใน UI แล้ว

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
| `UpdateGems` | Server → Client | 💎 อัพเดท gems + wins `{ gems, wins }` |
| `ToggleSoloWins` | Client → Server | 🧪 เปิด/ปิด solo wins (debug mode, payload: boolean) |
| `SetMasteryLevel` | Client → Server | 🧪 ตั้ง mastery level `{ classId, level }` or `{ setAll, level }` |
| `ResetDailyLogin` | Client → Server | 🧪 รีเซ็ต daily login streak (debug mode เท่านั้น) |
| `SetTestGems` | Client → Server | 🧪 ตั้ง/เพิ่ม gems `{ action = "add"|"set", amount }` (debug mode เท่านั้น) |
| `ShowShop` | Server → Client | 🛒 แสดง Shop popup (เดินเข้า ShopZone) |
| `HideShop` | Server → Client | 🛒 ซ่อน Shop popup (ออกจาก ShopZone) |
| `BuyShopItem` | Client → Server | 🛒 ซื้อ item ด้วย coins `{ itemId }` |
| `GachaClassPull` | Client → Server | 🛒 สุ่มคลาสด้วย gems (10 gems per pull) |
| `ShopUpdate` | Server → Client | 🛒 Shop state sync / purchase result / gacha result / error |

**ClassUpdate Payload (สำคัญ):**
```lua
{
    classId = "Runner", -- currently equipped class
    classInfo = {...},  -- display info from ClassTypes
    unlockedClasses = { Normal = true, Runner = true },
    classCosts = { Runner = 300, Jumper = 450, Tank = 600 }, -- ยังส่งอยู่แต่ไม่ใช้ใน UI (gacha แทน)
    currency = 512,
    classMastery = { -- optional fallback snapshot
        Normal = { level = 3, xp = 40, xpToNext = 156, isMax = false },
    },
    masteryRewards = { -- optional fallback snapshot
        Normal = {
            { id = "normal_title_balanced_cadet", level = 5, rewardType = "Title", rarity = "Common", name = "Balanced Cadet", unlocked = false },
        },
    },
    action = { -- optional (equip only — purchase ถูกแทนที่โดย gacha ใน ShopManager)
        type = "equip" | "error",
        classId = "Runner",
        reason = "INVALID_CLASS" | "RATE_LIMIT" | "NOT_IN_LOBBY"?,
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

### ไฟล์: `src/server/GameManager.luau` (setupLeaderstats inline)

Leaderstats เป็น built-in UI ของ Roblox ที่แสดงสถิติผู้เล่นอัตโนมัติ (แสดงใน PlayerList ด้านขวาของหน้าจอ)

### การทำงาน:

1. **สร้าง leaderstats folder** ใน Player object (ฝั่ง Server, ใน GameManager:onPlayerAdded)
2. **เพิ่ม IntValue** ลงใน folder: `Gems`, `Wins`, `Currency`
3. **Roblox แสดง UI อัตโนมัติ** เมื่อมี leaderstats folder
4. **Sync อัตโนมัติ**: CurrencyManager:sendGemUpdate() และ sendCurrencyUpdate() อัพเดท leaderstats ทุกครั้งที่ค่าเปลี่ยน

### ข้อควรระวัง:
- Leaderstats IntValues ต้อง sync ทุกครั้งที่ gems/wins/currency เปลี่ยน (อยู่ใน sendGemUpdate/sendCurrencyUpdate)
- **ต้องเป็น IntValue** และอยู่ใน folder ชื่อ `"leaderstats"` (case-sensitive)

---

## 🎨 การแก้ไข UI

### ไฟล์หลัก: `src/client/UI/`

### UI ที่มีอยู่:

| Module | ตำแหน่ง | Description |
|--------|---------|-------------|
| `MenuGridUI` | ซ้ายกลาง (X=10, Y=50%) | 📱 2x3 menu grid: Shop/Classes/Titles/Daily/Help/Settings (172×228) |
| `ScoreUI` | ล่างซ้าย | 💎 Gems (Y=1,-100) + 🚩 Stage (Y=1,-132, race only) + ⏱ Timer |
| `CurrencyUI` | ล่างซ้าย (Y=1,-52) | 💰 แสดงเงิน (gold HUD) |
| `ClassSelectionUI` | กลางจอ (popup, 720×480) | 🎭 เลือก Class (standardized layout, no indicator) |
| `TitleHUDUI` | hidden | 🏷️ replaced by MenuGridUI Titles button |
| `TitleCollectionUI` | กลางจอ (popup) | 🏷️ หน้ารวม Title (standardized layout) |
| `TutorialUI` | กลางจอ (popup, 680×500) | ❓ Game Guide 5 tabs (standardized layout, no standalone button) |
| `ItemUI` | มุมล่างขวา | 🎯 2 Item slots (horizontal) + Tooltip |
| `ItemTestingUI` | มุมบนขวา (toggle button) | 🧪 Testing Menu (items, gems, mastery, solo start, solo wins) |
| `FlyController` | ล่างซ้าย (X=160, Y=1,-30) | FLY [F] ปุ่ม + Speed controls (next to currency) |
| `StageSelectionUI` | กลางจอ | ⭐ เลือกลำดับด่าน + Countdown |
| `SummaryUI` | กลางจอ (popup) | 🏆 Summary เมื่อจบเกม |
| `MatchLobbyUI` | กลางจอ | 🏁 Matchmaking lobby + Rankings |
| `RaceResultsUI` | กลางจอ (popup) | 🏁 ผลการแข่งขัน |
| `SpectatorUI` | กลางจอ (popup + HUD) | 👁️ Spectate prompt + rankings + camera controls |
| `DailyBonusUI` | กลางจอ (popup only) | 🎁 Daily Login 7-day calendar (HUD button hidden, toggle via MenuGridUI) |
| `LeaderboardUI` | — (stub) | 🏆 ไม่มี UI จริง — ดู Global Leaderboard ที่ป้ายกายภาพใน lobby |
| `ShopUI` | กลางจอ (popup, 780×560) | 🛒 Shop 2-tab (standardized layout) — triggered by ShopZone or MenuGridUI |
| `SettingsUI` | กลางจอ (popup, 260×200) | ⚙️ Settings — Music/SFX toggle switches |
| `MobileInputUI` | มุมล่าง (มือถือเท่านั้น) | 📱 Touch buttons: Item1/2, Sprint, Jump |

### StageSelectionUI:
- **ปุ่มด่าน 1-5**: คลิกเพื่อเพิ่ม/ลบจากลำดับ
- **Selected display**: แสดงลำดับที่เลือก (เช่น "3 → 1 → 5") + รางวัลรวม
- **Order badge**: วงกลมเขียว (24×24, CORNER_FULL, SUCCESS) มุมบนขวาของการ์ดด่าน แสดงลำดับที่เลือก — เริ่มต้น Visible=false, update ผ่าน `updateOrderBadges()` ที่เรียกจาก `toggleStage()`, `clearSelection()`, และ `show()`
- **ปุ่ม RANDOM**: solid coral `RGB(255,95,85)` — **ห้ามใช้ UIGradient** (UIGradient คูณกับ BackgroundColor3 ทำให้สีหมอง ต้องใช้ solid color เท่านั้น)
- **ปุ่ม START**: solid green `RGB(55,195,95)` — **ห้ามใช้ UIGradient**
- **START disabled state**: ใช้ `BackgroundColor3 = RGB(40,80,50)` + `BackgroundTransparency=0` แทน transparency — ป้องกันพื้นหลัง (BG_BASE) ทะลุผ่านปุ่ม; enable tween คืนสีเขียวสด `RGB(55,195,95)`
- **Countdown**: แสดง 3, 2, 1 ก่อน teleport
- **Stage Reward**: แสดง `💰 +X` บนแต่ละปุ่มด่าน (รางวัลเมื่อผ่าน)

> ⚠️ **UIGradient gotcha (2 กรณี)**:
> 1. `UIGradient.Color` **คูณกับ `BackgroundColor3`** — ใส่ gradient บน TextButton ที่มี `BackgroundColor3` ไม่ใช่ขาว จะได้สีมืดกว่าที่ตั้ง → ใช้ solid color แทน หรือตั้ง `BackgroundColor3 = Color3.new(1,1,1)` แล้วให้ gradient เป็นสีจริง
> 2. `UIGradient` บน **TextButton ทำให้ตัวหนังสือหาย** AND **child Frame render ทับ text** → pattern ที่ถูกต้องสำหรับ gradient button: `TextButton (transparent, Text="")` → `Frame (gradient bg)` → `TextLabel (text, ZIndex สูงกว่า Frame)`

### ClassSelectionUI:
- **Modal size**: 720×480px, forest green theme (BG_SURFACE→BG_BASE gradient, 135°), leaf green glow stroke
- **Confirm/Equipped buttons**: green gradient (60,160,90)→(35,110,60), green stroke (80,190,110)
- **Class cards** (4 cards, 160×270px, `UIListLayout` horizontal, 12px gap):
  - Icon emoji (36px), class name (17px, class color)
  - Stat bars: 78px wide, 10px height; label 46px left; percentage 12px right of bar
    - Green = buff (+), Red = nerf (−), Light purple = neutral (0%)
    - KB Resist bar (Tank only): yellow `MASTERY_MAX` color
  - Passive ability name (11px, PRIMARY_DARK)
  - Mastery label (11px): `"Lv.20 ⚡ Double Jump"` หรือ `"Mastery Lv.5  124/244"`
  - XP bar (5px thin, ACCENT_CYAN leaf green)
  - Reward icons: 🏷️✨🏅🖼️ (dim=locked, vivid=unlocked)
  - CardFrame Mastery stroke: แสดงเมื่อ CardFrame reward unlocked
- **Hover animation**: card scale `160×270 → 168×278` (0.15s Quad), stroke เปลี่ยนเป็น class color
- **Selection**: card selected → ขนาดใหญ่ถาวร (168×278), stroke = class color 3px
- **Inner glow**: bottom shadow vignette (Frame transparent gradient 0→0.3) + top 3px class-color edge accent
- **Confirm button** (full-width, `1,-48 × 50`): TextButton(transparent) + Frame(gradient bg) + TextLabel(text)
  - EQUIPPED → purple `RGB(140,80,220)→RGB(90,50,170)` (styled disabled)
  - EQUIP → green `RGB(60,200,100)→RGB(40,170,70)`
  - GACHA IN SHOP → dark gray disabled (locked classes — gacha ใน ShopUI แทนการซื้อตรง)
- **Locked class cost label**: แสดง "Get from Shop" (HUD_GEM_START color) แทนราคา coins
- **Mastery Rewards bar**: `"🏆 MASTERY REWARDS (X/4)"` + next reward หรือ "All mastery rewards unlocked!"
- **Class indicator HUD** (175×42px, bottom-left): icon + name + mini XP bar + Lv badge + chevron, คลิก toggle modal
- **Mastery unlock levels**: 5=Title, 10=Trail, 15=Badge, 20=CardFrame + Ultimate skill

### TitleCollectionUI:
- **Modal size**: ~960×580px, forest green gradient (BG_SURFACE→BG_BASE, 135°), ACCENT_CYAN glow stroke
- **Active Title Banner** (top): shows equipped title name + rarity badge, UNEQUIP button
  - Banner stroke color = rarity `frameColor` (ไม่ใช่ gray default)
  - **Glow pulse animation**: TweenService Sine InOut, period 1.5s, repeat -1, reversing → stroke Transparency ไปมาระหว่าง 0.2–0.5
  - หยุด pulse เมื่อ unequip (`:Cancel()` tween เก่า ก่อนสร้างใหม่)
- **Title rows** (card per title, compact 62px height):
  - **Rarity left border strip**: 6px wide (ขึ้นจาก 4px), UICorner(0,3) มน, สี = rarity `frameColor`
  - **Rarity tag format**: `"⚪ [Common]"` / `"🔵 [Rare]"` / `"🟣 [Epic]"` / `"⭐ [Legendary]"` (emoji ก่อน bracket)
  - **Button sizing** (ในแต่ละ row): 100×32 (ขึ้นจาก 90×30), font 13px GothamBold
    - EQUIP (unlocked): SUCCESS bg + UIStroke SUCCESS 0.3 transparency
    - EQUIPPED (active): SECONDARY (orange-red) + UIStroke SECONDARY 0.3 transparency
    - LOCKED: BG_ELEVATED bg, TextTransparency=0.3 (dimmed look), no click
  - **UNEQUIP button** (banner): 100×30, Theme.applyCorner("sm"), UIStroke
  - **Row hover**: `InputBegan` (MouseMovement) → tween `BG_ELEVATED`; `InputEnded` → tween กลับ base color
- **Filters**: All / Unlocked / Locked tab + search TextBox (ชื่อ/class/rarity) + Sort dropdown

### SummaryUI (Game Complete):
- **แสดงเมื่อ**: จบเกม (finish)
- **Overlay**: dark semi-transparent overlay ด้านหลัง popup (ZIndex 49, ทำตาม DailyBonusUI pattern)
- **Header Section** (100px, แยกออกมาชัดเจน):
  - Gem emoji 💎 (TextSize 36) + "GAME COMPLETE!" (GothamBlack, MEDAL_GOLD)
  - Gold divider line ใต้ header
  - Top-rounded corners เท่านั้น (fill-rect trick)
- **STAGES PLAYED**: badge แต่ละด่านที่เล่น + รางวัล
- **STATS**: Gems Earned + Time + "1ST PLACE!" indicator (isWin) + "TOP 30%" indicator (isTop30)
- **CURRENCY EARNED** (breakdown):
  - Coins (X × 1) = +X
  - Stage Clear (X × 5) = +X
  - Stage Rewards = +X
  - Finish Bonus = +25
  - **TOTAL EARNED** = รวมทั้งหมด (highlight frame + gold border stroke)
- **OK Button**: ✅ OK — ใช้ Frame+TextLabel pattern (แยก UIGradient ออกจาก text)
- **Auto teleport**: กลับ Lobby หลัง 5 วินาที
- **Popup size**: 400 × 560

---

## 🎨 UI Design System (Colorful Youth Theme)

> **Theme**: Vivid gradient backgrounds, glow strokes (transparency 0.2), drop shadows, CORNER_LG pills, bold text with UIStroke, playful animations — เป้าหมาย: เด็ก 10-20 ปี

### ThemeConfig: `src/shared/ThemeConfig.luau`

**ต้อง require ก่อนสร้าง UI ทุกครั้ง — ห้ามใช้ inline Color3:**

```lua
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)
```

### Palette Tokens

| Token | RGB | ใช้สำหรับ |
|-------|-----|----------|
| `Theme.BG_BASE` | (35, 62, 48) | พื้นหลัง panel หลัก (forest green) |
| `Theme.BG_SURFACE` | (48, 80, 62) | card / section |
| `Theme.BG_ELEVATED` | (62, 100, 75) | hover / selected |
| `Theme.BG_OVERLAY` | (22, 42, 32) | modal dim / darkest |
| `Theme.PRIMARY` | (255, 220, 0) | ปุ่มหลัก (เหลือง) |
| `Theme.PRIMARY_DARK` | (200, 165, 0) | hover/pressed |
| `Theme.SECONDARY` | (255, 85, 50) | destructive / energy |
| `Theme.ACCENT_CYAN` | (85, 195, 130) | leaf green — info / highlight / glow border |
| `Theme.ACCENT_PINK` | (255, 100, 180) | fun / special |
| `Theme.TEXT_PRIMARY` | (245, 245, 240) | warm white — text บน dark bg |
| `Theme.TEXT_DARK` | (35, 62, 48) | dark green — text บน light bg |
| `Theme.TEXT_MUTED` | (170, 195, 175) | sage green-white — secondary text |
| `Theme.SUCCESS` | (80, 230, 120) | equip / success |
| `Theme.DANGER` | (255, 70, 70) | leave / locked / danger |
| `Theme.WARNING` | (255, 200, 0) | time warning / can-buy |
| `Theme.MEDAL_GOLD` | (255, 215, 0) | 1st place / gold |
| `Theme.MEDAL_SILVER` | (192, 192, 192) | 2nd place |
| `Theme.MEDAL_BRONZE` | (205, 127, 50) | 3rd place |
| `Theme.HUD_SCORE_START` | (60, 180, 100) | HUD score gradient (fresh green) |
| `Theme.HUD_SCORE_END` | (30, 110, 55) | HUD score gradient (deep green) |
| `Theme.HUD_GLOW_CYAN` | (100, 220, 140) | timer glow (green) |
| `Theme.HUD_GLOW_GOLD` | (255, 230, 100) | currency glow |

### Structure Tokens

| Token | Value | ใช้สำหรับ |
|-------|-------|----------|
| `Theme.CORNER_SM` | 8px | buttons, small badges |
| `Theme.CORNER_MD` | 14px | HUD panels, cards |
| `Theme.CORNER_LG` | 20px | modal containers (preferred) |
| `Theme.CORNER_FULL` | UDim(1,0) | circles / pills |
| `Theme.STROKE_THIN` | 1.5 | subtle border |
| `Theme.STROKE_MED` | 2.5 | glow border (default) |
| `Theme.STROKE_BOLD` | 4 | main modal glow |

### Helper Functions

```lua
Theme.rarityColor(rarity)   -- "Common"|"Rare"|"Epic"|"Legendary" → Color3
Theme.classColor(classId)   -- "Runner"|"Jumper"|"Tank" → Color3
Theme.applyCorner(obj, size) -- "sm"|"md"|"lg"|"full" → UICorner
Theme.applyStroke(obj, color, weight, transparency) -- "thin"|"med"|"bold" → UIStroke
```

### Vivid Gradient Pattern (ใช้กับทุก modal/panel ใหม่)

```lua
-- 1. Gradient background (BG_SURFACE → BG_BASE, 135°)
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.BG_SURFACE),
    ColorSequenceKeypoint.new(1, Theme.BG_BASE)
})
gradient.Rotation = 135
gradient.Parent = mainFrame

-- 2. Glow stroke (ACCENT_CYAN หรือ contextual color)
local stroke = Instance.new("UIStroke")
stroke.Color = Theme.ACCENT_CYAN  -- หรือ MEDAL_GOLD, SUCCESS, DANGER
stroke.Thickness = Theme.STROKE_BOLD  -- หรือ STROKE_MED
stroke.Transparency = 0.2
stroke.Parent = mainFrame

-- 3. Drop shadow
local shadow = Instance.new("Frame")
shadow.Size = UDim2.new(1, 6, 1, 6)
shadow.Position = UDim2.new(0, -3, 0, 4)
shadow.BackgroundColor3 = Color3.new(0, 0, 0)
shadow.BackgroundTransparency = 0.6
shadow.BorderSizePixel = 0
shadow.ZIndex = mainFrame.ZIndex - 1
shadow.Parent = mainFrame
Theme.applyCorner(shadow, "lg")

-- 4. Header text stroke (UIStroke ไม่ใช่ TextStroke)
local titleStroke = Instance.new("UIStroke")
titleStroke.Color = Theme.HUD_SCORE_END
titleStroke.Thickness = 1.5
titleStroke.Transparency = 0.4
titleStroke.Parent = titleLabel

-- 5. Button gradient (contextual color → BG_ELEVATED, 90°)
local btnGradient = Instance.new("UIGradient")
btnGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.SUCCESS),  -- หรือ DANGER, PRIMARY
    ColorSequenceKeypoint.new(1, Theme.BG_ELEVATED)
})
btnGradient.Rotation = 90
btnGradient.Parent = button
```

### UI Rules
1. **ห้าม** ใช้ inline `Color3.fromRGB(...)` สำหรับสีพื้นหลัง/ข้อความ (ยกเว้น drop shadow = `Color3.new(0,0,0)`)
2. **ต้อง** require ThemeConfig ทุกไฟล์ UI
3. Background: `BG_BASE` → `BG_SURFACE` → `BG_ELEVATED` (dark → light)
4. Font: Gotham family เท่านั้น (Gotham, GothamBold, GothamBlack)
5. Text บน dark bg = `TEXT_PRIMARY` (white); Text บน light bg = `TEXT_DARK`
6. ทุก modal ใหม่ต้องมี: UIGradient + glow UIStroke (transparency 0.2) + drop shadow
7. Corner: modal = `CORNER_LG`, panel/card = `CORNER_MD`, button = `CORNER_SM`
8. Stroke glow: `STROKE_BOLD` (thickness 4) สำหรับ modal หลัก, `STROKE_MED` (2.5) สำหรับ panel ย่อย
9. **Emoji ใน Luau**: ใช้ unicode escape `\u{1F381}` แทน emoji ตรงๆ ใน string literals เพื่อหลีกเลี่ยง encoding issues

### Checklist สำหรับ UI ใหม่

- [ ] `local Theme = require(ReplicatedStorage.Shared.ThemeConfig)`
- [ ] background ใช้ `BG_BASE` / `BG_SURFACE` / `BG_ELEVATED`
- [ ] UIGradient (BG_SURFACE → BG_BASE, 135°) บน main container
- [ ] Glow UIStroke (ACCENT_CYAN, STROKE_BOLD, transparency 0.2) บน main container
- [ ] Drop shadow Frame (Size +6px, Position -3/+4, transparency 0.6) บน main container
- [ ] Title UIStroke (HUD_SCORE_END, 1.5, 0.4) บน header label
- [ ] ปุ่มหลัก = gradient (contextual → BG_ELEVATED, 90°) + glow stroke
- [ ] text = `TEXT_PRIMARY` หรือ `TEXT_MUTED`
- [ ] UICorner: modal = `CORNER_LG`, panel = `CORNER_MD`, button = `CORNER_SM`
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
StageTracker:initPlayer() + CurrencyManager:initPlayer() + ItemManager:initPlayer()
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
  - StageTracker:advanceStage()
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
  - +1 gem (FinishRace)
  - +5 gems if top 30% (multiplayer)
  - +1 win if 1st place (multiplayer)
    ↓
Show SummaryUI popup (Currency breakdown + gems earned)
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

### Testing Menu - ต้อง `Config.Debug.ItemTesting = true`:
- กด **toggle button** มุมบนขวา เพื่อเปิด/ปิด Testing Menu
- เลือก item ที่ต้องการ (แบ่งกลุ่มตาม rarity)
- กด "Clear All Items" เพื่อล้าง items ทั้งหมด
- กด **"🎁 Reset Daily Login"** เพื่อรีเซ็ต streak + รับรางวัลวันที่ 1 ทันที (debug only)
- **Solo Wins** toggle: เปิด/ปิด solo wins สำหรับทดสอบ
- **Solo Start (Random)**: เริ่มเกมทันทีด้วย stages สุ่ม
- **Gems**: แสดง gems ปัจจุบัน + ปุ่ม +10/+100/+1000 + Reset (0) — ใช้ `SetTestGems` remote, sync ผ่าน `UpdateGems`
- **Mastery**: ตั้ง level per-class (+/-/MAX), Set All Lv 20, Reset All Lv 1

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

### Unit Testing (Jest Lua):

**Framework**: [Jest Lua](https://github.com/jsdotlua/jest-lua) v3.10.0 (ติดตั้งผ่าน Wally)

**ไฟล์สำคัญ**:
- `wally.toml` — dev-dependencies: Jest + JestGlobals
- `test.project.json` — Rojo project แยกสำหรับ tests (ไม่แตะ `default.project.json`)
- `scripts/run-tests.server.luau` — test runner entry point
- `src/shared/__tests__/*.spec.luau` — test files

**Run tests จาก command line**:
```bash
rojo build test.project.json --output test-place.rbxl
run-in-roblox --place test-place.rbxl --script scripts/run-tests.server.luau
```

**Tests ที่มี (45 tests, 3 suites)**:
- `ClassTypes.spec.luau` — getClass, getAllClassIds, calculateStats, getClassDisplayInfo
- `ItemTypes.spec.luau` — getItem, getItemsByRarity, getRarityColor, getRarityName, getWeightedRandomItem
- `StageInfo.spec.luau` — getStage, getStagesByDifficulty, getTotalStageCount

**เพิ่ม test ใหม่**:
1. สร้างไฟล์ `src/shared/__tests__/YourModule.spec.luau`
2. Require modules ผ่าน `ReplicatedStorage.Shared.YourModule`
3. Require JestGlobals ผ่าน `ReplicatedStorage.DevPackages.JestGlobals`
4. ใช้ syntax: `describe()`, `it()`, `expect()` (เหมือน Jest JS)

**ติดตั้ง dependencies** (ครั้งแรก):
```bash
aftman install   # ติดตั้ง rojo, wally, run-in-roblox
wally install    # ติดตั้ง Jest Lua → DevPackages/
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
9. **Auto-save**: CurrencyManager saves ทุก 30 วินาที (ลด request)
10. **Pending Saves**: ใช้ `pendingSaves` flag เพื่อ track ว่าต้อง save หรือไม่
11. **On Leave**: Save ทันทีเมื่อผู้เล่นออก (ถ้ามี pending)
12. **Shared Player Key**: ใช้ key เดียว `Player_<UserId>` และ save ด้วย `UpdateAsync` (atomic, ป้องกัน race condition)
13. **Class Fields**: ใน profile มี `unlockedClasses` + `equippedClass` ถาวรต่อบัญชี
14. **Title Field**: ใน profile มี `activeTitle` (string? หรือ nil) สำหรับ title ที่ใส่อยู่
15. **Daily Login Fields**: ใน profile มี `lastLoginTime` (number?) + `loginStreak` (number 1–7)

### 🎯 Item System (Mario Kart Style)
14. **Dual Slots**: ผู้เล่นถือได้ 2 items, กด 1/2 เพื่อใช้
15. **Item Box**: Lucky Block model (asset 129696127925672) — golden voxel "?" block + bobbing animation
16. **Weighted Random**: คนอันดับท้ายได้ item หายากมากกว่า (catch-up)
17. **Item Tooltip**: คลิกที่ item เพื่อดู description (auto-hide 6 วินาที)
18. **Rarity Colors**: Common=เทา, Uncommon=เขียว, Rare=น้ำเงิน, Epic=ม่วง
19. **Item Icons**: ใช้ emoji (🚀🍌🛡️⚡🔄⚡🌩️)
20. **Testing Menu**: toggle button มุมบนขวา เปิดเมนูทดสอบ (items, gems, mastery, solo start, solo wins)
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
35. **Nature Park Theme**: UI ใช้ forest green palette แทน purple neon — เข้ากับ outdoor park lobby

### 🏁 Match/Race System
34. **Match Config**: `Config.Match` - MinPlayers, MaxPlayers, WaitTime, TimeLimit
35. **Testing Mode**: `IsTestingMode = true` → WaitTime = 3 วินาที
36. **Time Limit**: 15 นาทีต่อ match พร้อมแจ้งเตือน
37. **Rankings**: คำนวณจาก stage + distance ใน stage

### 💰 Currency + 💎 Gems + 🏆 Wins
38. **Stage Rewards**: อยู่ใน `StageInfo.luau` → `StageInfo.getStage(id).reward` (S1=3, S2=4, S3=4, S4=5, S5=6, S6=6, S7=7)
39. **Currency Breakdown**: Stage Clear (5) + Stage Rewards + Finish Bonus (25)
40. **Gems**: +1 finish race, +5 top 30% (multiplayer), daily login gems
41. **Wins**: +1 when finishing 1st (multiplayer only, or with Solo Wins debug toggle)
42. **CurrencyUI**: มุมบนซ้าย Y=58 (ใต้ GemFrame), coin shine sweep ต่อเนื่อง (1.2s Quad InOut, no gap)

### 🖥️ UI Layout
**Left side — MenuGridUI** (vertically centered, X=10):
41. **MenuGridUI**: 2x3 button grid (172×228px) — Shop, Classes, Titles, Daily, Help, Settings
    - Each button: 74×68, UIFactory.createButton, colored stroke per type, emoji icon + label
    - `setActive(id)` tweens bg + stroke to show active panel
    - Toggle behavior: clicking opens/closes panels with mutual exclusion
    - `hide()`: slides panel off-screen left (during gameplay/race)
    - `show()`: slides panel back in (on ReturnToLobby)
    - Hidden on CountdownUpdate (race start), shown on ReturnToLobby

**Bottom-left — HUD pills**:
42. **Y=1,-132**: Stage Frame (🚩 Progress, only during race)
43. **Y=1,-100**: Gem Frame (💎 gems, purple gradient)
44. **Y=1,-52**: Currency Frame (💰 coins, gold gradient)
45. **FLY controls**: X=160, Y=1,-30 (debug only, next to currency)

**Hidden/Removed elements**:
46. ClassIndicator → `hideIndicator: true` in ClassSelectionUI
47. TitleHUD → `hidden: true` in TitleHUDUI
48. DailyBonus HUD button → `hideHudButton: true`
49. Tutorial "?" button → `hideHelpButton: true`

**Panel mutual exclusion** (managed by MainUI):
- Managed panels: shopUI, classSelectionUI, titleCollectionUI, tutorialUI
- Opening any panel auto-closes others + DailyBonus calendar
- Daily button toggles calendar (not managed panel, uses hideCalendar())
- Race start (`CountdownUpdate`) closes all panels

### 📊 Leaderstats
47. **Built-in UI**: แสดง Gems, Wins, Currency
48. **Update**: CurrencyManager sync leaderstats อัตโนมัติใน sendGemUpdate/sendCurrencyUpdate

### 📈 Class Mastery
49. **Mastery Data**: เก็บใน profile key เดียวกับ score/currency ที่ field `classMastery`
50. **Mastery Rewards Data**: เก็บสถานะ reward ที่ปลดแล้วใน field `masteryRewards`
51. **XP Sources**: ผ่านด่านได้ `PerStageXP` และเข้าเส้นชัยได้ `FinishBonusXP`
52. **UI Display**: แสดงทั้ง level/xp บน class card และ preview rewards ของ class ที่เลือก
53. **Remote**: ใช้ `MasteryUpdate` ส่ง level/xp/xpToNext/isMax + masteryRewards + unlockedRewards action

### ❓ Tutorial System
54. **เปิดจาก MenuGridUI**: ปุ่ม Help ใน menu grid (standalone "?" button hidden)
55. **Panel**: 680x500 กลางจอ, standardized layout (fade-only animation, 0.2s Quad)
56. **Tabs**: 5 tabs (Movement/Items/Classes/Mastery/Ultimates) อ่านจาก `Config.Tutorial.Sections`
57. **RichText**: content ใช้ `<font color="">` + `<b>` สำหรับ headers/keys/class names สีต่างๆ
58. **Popup Exclusion**: managed by MainUI — opening closes other panels + daily calendar
59. **Remote**: `TutorialSeen` fire ครั้งแรกที่เปิด → server save `hasSeenTutorial = true`

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
75. **Modal ScreenGui**: popup สร้างใน ScreenGui แยก `DisplayOrder=100` เพื่อ overlay ครอบเหนือ HUD ทั้งหมด — `IgnoreGuiInset=true` ครอบทั้งหน้าจอ
77. **lastData.claimed**: หลังปิด claim popup จะเซ็ตเป็น `false` เสมอ (ป้องกัน re-claim บน HUD)
78. **Testing**: ใช้ "🎁 Reset Daily Login" ใน Testing Menu (toggle button มุมบนขวา) — ต้อง `Config.Debug.ItemTesting = true`

### 🏆 Dual Leaderboards (Gems + Wins)
77. **DataStore**: ใช้ `OrderedDataStore` แยก 2 ตัว (`ObbyLeaderboard_Gems_v1`, `ObbyLeaderboard_Wins_v1`)
78. **Physical Boards**: 2 boards สร้างอัตโนมัติ — 💎 GemLeaderboard (X=22) + 🏆 WinLeaderboard (X=-22)
79. **Positions**: Flanking SelectionZone at Z=30, Y=106
80. **Refresh**: broadcast ทุก 60 วินาที + เมื่อผู้เล่นจบเกม

### 🔊 Sound Manager
81. **Asset IDs ว่าง**: SoundManager มีโครงสร้างแต่ทุก ID เป็น `""` — ต้องใส่ rbxassetid ก่อนเกมมีเสียง
82. **Safe**: ตรวจสอบ SoundId ก่อนเล่น ไม่ error ถ้า ID ว่าง

### 🔧 Code Quality (Audit Feb 2026)
83. **Debug Flags**: `Config.Debug.Enabled`, `FlyMode`, `ItemTesting` - ต้อง set `false` ก่อน production
84. **Logger**: `src/shared/Logger.luau` - ใช้ `Logger.debug/info/warn/error(tag, ...)` แทน `print("[Tag]", ...)`
85. **os.clock()**: ใช้ `os.clock()` แทน `tick()` ทั้ง project (tick deprecated)
86. **LinearVelocity/AngularVelocity**: ใช้ constraint-based แทน BodyVelocity/BodyAngularVelocity (deprecated)
87. **UpdateAsync**: DataStore ใช้ `UpdateAsync` (atomic) ไม่ใช่ `GetAsync`+`SetAsync` (race condition)
88. **Connection Cleanup**: CharacterAdded/Died connections ถูก track ใน `playerConnections` table และ disconnect เมื่อ player leave
89. **Input Validation**: `ConfirmStageSelection` remote ผ่าน `validateStageOrder()` ก่อนใช้งาน
90. **Shared Map Limitation**: Map เป็น global shared ใน workspace - ถ้า 2+ players เล่นพร้อมกันจะมีปัญหา (ต้องทำ instanced map ในอนาคต)
91. **Race Direction**: Stages progress ตามแกน +X (ไม่ใช่ +Z) - "ahead" check ใช้ `Position.X`

### 🏗️ Architecture (Refactored Feb 2026)
92. **GameManager split**: SpectatorManager + SelectionZoneManager + ShopZoneManager แยกออกจาก GameManager ใช้ dependency injection pattern
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
103. **MapManager internal**: ฟังก์ชัน `_xxxInternal()` เป็น internal helpers สำหรับ global/per-match deduplication — ห้ามเรียกจากนอก MapManager
104. **Config.Timing / Config.Map**: Magic numbers เวลาและ map ทั้งหมดอยู่ใน Config แล้ว — ไม่ hardcode ค่าใหม่
105. **Nature Park Theme (Mar 2026)**: UI ทั้งหมดใช้ forest green palette (BG_BASE 35,62,48) + leaf green glow (ACCENT_CYAN 85,195,130) + gradient + drop shadow — เปลี่ยนจาก purple neon เป็น green nature เพื่อเข้ากับ outdoor park lobby
106. **Emoji Unicode Escapes**: ใน Luau string literals ให้ใช้ `\u{1F381}` แทน emoji ตรงๆ (เช่น 🎁) เพื่อหลีกเลี่ยง encoding issues บาง environment
107. **All UIs use dark-green theme**: ClassSelectionUI, TitleCollectionUI, TitleHUDUI, ShopUI, DailyBonusUI ทั้งหมดใช้ forest green palette — hardcoded purple colors ถูก replace ด้วย Theme tokens แล้ว
108. **TitleCollectionUI rarity border**: strip width = 6px (ไม่ใช่ 4px), มี UICorner(0,3) มน; rarity tag ใช้ emoji prefix `"⚪ [Common]"` / `"🔵 [Rare]"` / `"🟣 [Epic]"` / `"⭐ [Legendary]"`
109. **TitleCollectionUI banner pulse**: stroke color = rarity frameColor, TweenInfo Sine InOut, repeatCount=-1, reverses=true — `:Cancel()` เมื่อ unequip เพื่อไม่ให้ leak connection
110. **Row hover บน Frame**: ใช้ `InputBegan`/`InputEnded` + check `UserInputType.MouseMovement` — MouseEnter/Leave ทำงานได้กับ Frame แต่ `InputBegan` สม่ำเสมอกว่าเมื่อมี child elements ทับ
111. **OBBY CHALLENGE popup**: อยู่ใน `init.client.luau` ไม่ใช่ `TutorialUI` — migrate ให้ใช้ ThemeConfig + RichText keywords + 3-layer gradient GOT IT button (300×45)

### 🛒 Shop System
112. **ShopManager**: server-side purchase validation + class gacha — dependency injection pattern (currencyManager, itemManager, classManager, gameManager)
113. **Item Purchase**: coins → validate item/lobby/price/slot → spendCurrency → setItemInSlot → ShopUpdate result
114. **Class Gacha**: 10 gems per pull → weighted random (Runner=35, Jumper=35, Tank=30) → new unlock OR duplicate refund (3 gems)
115. **Class Unlock Change**: ClassSelectionUI ไม่มีปุ่ม BUY แล้ว — ใช้ gacha ใน ShopUI แทน; ClassSelectionUI แสดง "Get from Shop" สำหรับคลาสล็อค
116. **ShopUI Card Grid**: 3-col UIGridLayout (225×270), per-rarity tinted backgrounds (CARD_BG_COLORS), rarity badge pills, price buttons with coin icons
117. **ShopUI Gacha Tab**: mystery card → PULL button → flip reveal animation → banner → owned classes section (lock/emoji/checkmark toggle)
118. **SetTestGems Remote**: Testing Menu gem editor — add/set gems via `SetTestGems { action, amount }`, synced through `UpdateGems`

### 🧪 Unit Testing (Jest Lua)
119. **Jest Lua v3.10.0** via Wally dev-dependencies — tests อยู่ใน `src/shared/__tests__/*.spec.luau`
120. **test.project.json** = Rojo project แยก — map `DevPackages/` + `src/shared/` + runner script; ไม่แตะ `default.project.json`
121. **Run**: `rojo build test.project.json --output test-place.rbxl && run-in-roblox --place test-place.rbxl --script scripts/run-tests.server.luau`
122. **45 tests / 3 suites**: ClassTypes (16), ItemTypes (18), StageInfo (11) — pure logic, no mocking needed
123. **เพิ่ม test**: สร้าง `.spec.luau` ใน `__tests__/`, require ผ่าน `ReplicatedStorage.Shared.*` + `ReplicatedStorage.DevPackages.JestGlobals`
