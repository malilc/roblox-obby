# AI Development Guide - Roblox Obby Game

คู่มือสำหรับ AI ที่จะมาพัฒนาต่อ

## 📁 Project Structure

```
src/
├── server/                      # Server-side code
│   ├── init.server.luau         # Entry point - สร้าง GameManager
│   ├── GameManager.luau         # ควบคุมเกมทั้งหมด
│   ├── MapManager.luau          # จัดการ map/stages + animations
│   ├── ScoreManager.luau        # ระบบคะแนน + DataStore (auto-save ทุก 30วิ)
│   ├── CurrencyManager.luau     # 💰 ระบบเงิน + Class Unlock + Mastery + DataStore
│   ├── ItemManager.luau         # 🎯 ระบบ Items แบบ Mario Kart
│   ├── MatchManager.luau        # 🏁 ระบบ Matchmaking/Race
│   ├── ClassManager.luau        # 🎭 ระบบ Character Classes
│   └── StageTemplates.luau      # ⭐ สร้างด่าน obby ที่นี่
│
├── client/                      # Client-side code
│   ├── init.client.luau         # Entry point
│   ├── FlyController.luau       # ระบบบินทดสอบ (กด F)
│   ├── ItemEffects.luau         # 🎯 Screen effects (shake, flash, zoom)
│   └── UI/
│       ├── MainUI.luau          # Controller หลัก
│       ├── ScoreUI.luau         # แสดงคะแนน
│       ├── CurrencyUI.luau      # 💰 แสดงเงิน
│       ├── ItemUI.luau          # 🎯 แสดง Item (2 slots) + Tooltip
│       ├── ItemTestingUI.luau   # 🧪 UI ทดสอบ Item (กด T)
│       ├── StageSelectionUI.luau # ⭐ GUI เลือกลำดับด่าน
│       ├── SummaryUI.luau       # 🏆 แสดง Summary จบเกม
│       ├── MatchLobbyUI.luau    # 🏁 UI Matchmaking lobby
│       ├── ClassSelectionUI.luau # 🎭 UI เลือก Class
│       ├── TitleHUDUI.luau      # 🏷️ HUD แสดง Active Title
│       ├── TitleCollectionUI.luau # 🏷️ หน้ารายการ Title (ล็อก/ปลดล็อก + filter/search)
│       └── RaceResultsUI.luau   # 🏁 UI ผลการแข่ง
│
└── shared/                      # Shared code (server + client)
    ├── Config.luau              # ⭐ ค่า Config ทั้งหมด (+ Debug flags)
    ├── Types.luau               # Type definitions
    ├── Logger.luau              # 🔧 Centralized logging (configurable levels)
    ├── ItemTypes.luau           # 🎯 นิยาม Items ทั้งหมด
    └── ClassTypes.luau          # 🎭 นิยาม Classes ทั้งหมด
```

---

## 🏠 Workspace Structure

```
Workspace/
├── SpawnLocation          # จุดเกิดเริ่มต้น (หันไปทาง +Z)
├── Lobby/                 # Folder เก็บ Lobby ทั้งหมด
│   ├── MainFloor          # พื้น Cyper Platform
│   ├── NeonRing           # วงแหวนเรืองแสง
│   ├── FloatingIslands    # เกาะลอยฟ้า
│   ├── NeonPillars        # เสาไฟ Neon
│   └── SelectionZone      # ⭐ Zone เลือกด่าน (มีป้าย "SELECT STAGE")
├── Stages/                # Folder เก็บด่านที่ generate
└── KillBrick              # พื้นที่ตายเมื่อตก
```

**สำคัญ**: 
- `SpawnLocation` ต้องอยู่ใน Workspace โดยตรง ไม่ใช่ใน Folder
- `SelectionZone` ใช้ loop-based detection (เสถียรกว่า Touched events)

---

## 🎮 ระบบเลือกด่าน (Stage Selection)

### ไฟล์ที่เกี่ยวข้อง:
- `src/server/GameManager.luau` - Logic ฝั่ง Server
- `src/client/UI/StageSelectionUI.luau` - GUI ฝั่ง Client

### Flow:

```
ผู้เล่นเดินเข้า SelectionZone (เดินหาป้าย "SELECT STAGE")
    ↓
Server ส่ง ShowStageSelection → Client
    ↓
Client แสดง GUI เลือกด่าน
    ↓
ผู้เล่นเลือกลำดับด่าน หรือ กด RANDOM
    ↓
Client ส่ง ConfirmStageSelection → Server
    ↓
Server สร้าง Map ตามลำดับที่เลือก
    ↓
Countdown 3, 2, 1
    ↓
Teleport ไปด่าน 1
```

### การเลือกด่าน:
- **คลิกปุ่มด่าน** - เพิ่มเข้าลำดับ (เช่น 3 → 1 → 5)
- **คลิกอีกครั้ง** - ลบออกจากลำดับ
- **ปุ่ม RANDOM** - สุ่มลำดับด่าน
- **ปุ่ม START** - ต้องเลือกอย่างน้อย 1 ด่านก่อนกดได้

### Zone Detection (Loop-based):

```lua
-- ตรวจสอบทุก 0.2 วินาที (เสถียรกว่า Touched events)
task.spawn(function()
    while true do
        task.wait(0.2)
        for _, player in ipairs(Players:GetPlayers()) do
            local isInZone = self:isPlayerInSelectionZone(player, selectionZone)
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
        StageTemplates.createStage1,
        StageTemplates.createStage2,
        StageTemplates.createStage3,
        StageTemplates.createStage4,
        StageTemplates.createStage5,
        StageTemplates.createStage6, -- เพิ่มใหม่
    }
end
```

3. อัพเดท `Config.Stages.Count` ใน `src/shared/Config.luau`

---

## 🎲 ระบบสุ่ม/เลือกลำดับด่าน

### ไฟล์: `src/server/MapManager.luau`

```lua
-- สุ่มลำดับ (Fisher-Yates shuffle)
function MapManager:shuffleStages(): {number}
    local stages = {}
    for i = 1, Config.Stages.Count do
        table.insert(stages, i)
    end
    
    for i = #stages, 2, -1 do
        local j = math.random(1, i)
        stages[i], stages[j] = stages[j], stages[i]
    end
    
    return stages
end

-- สร้าง Map ด้วยลำดับที่กำหนด
function MapManager:generateMapWithOrder(stageOrder: {number})
    self:clearMap()
    self.stageOrder = stageOrder
    -- สร้างด่านตามลำดับ...
end
```

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
        Count = 5,              -- จำนวนด่าน
        StageLength = 100,      -- ความยาวแต่ละด่าน
        StartOffset = Vector3.new(0, 0, 150), -- ⭐ ห่างจาก Lobby
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
        -- 🎯 รางวัลเมื่อผ่านแต่ละด่าน (Stage Rewards)
        StageRewards = {
            3,  -- Stage 1: 3 currency
            4,  -- Stage 2: 4 currency
            4,  -- Stage 3: 4 currency
            5,  -- Stage 4: 5 currency
            6,  -- Stage 5: 6 currency
        },
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

    -- Debug / Development Settings
    Debug = {
        Enabled = true,          -- Master toggle: set false for production
        FlyMode = true,          -- Press F to fly (client)
        ItemTesting = true,      -- Press T for item test menu (client + server remotes)
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
| `ItemUI` | มุมล่างขวา | 🎯 2 Item slots (horizontal) + Tooltip |
| `ItemTestingUI` | มุมบนขวา (toggle) | 🧪 เมนูทดสอบ Item (กด T) |
| `FlyController` | ล่างซ้าย | FLY [F] ปุ่ม + Speed controls |
| `StageSelectionUI` | กลางจอ | ⭐ เลือกลำดับด่าน + Countdown |
| `SummaryUI` | กลางจอ (popup) | 🏆 Summary เมื่อจบเกม |
| `MatchLobbyUI` | กลางจอ | 🏁 Matchmaking lobby + Rankings |
| `RaceResultsUI` | กลางจอ (popup) | 🏁 ผลการแข่งขัน |

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
เดินเข้า SelectionZone (สีฟ้า)
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
| `Config.Stages.Count` | 5 | Config.luau |
| `Config.Stages.StartOffset` | (-150, 0, 250) | Config.luau |
| `Config.Lobby.SpawnPosition` | (0, 103, 0) | Config.luau |
| `Config.KillZoneY` | -120 | Config.luau |
| `Friction` | 2.0 | StageTemplates.luau |
| `checkPlayerPosition interval` | 0.5 วินาที | GameManager.luau |
| `selectionZone interval` | 0.2 วินาที | GameManager.luau |
| `Finish Line delay` | 2 วินาที | GameManager.luau |

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
38. **Stage Rewards**: `Config.Currency.StageRewards` (S1=3, S2=4, S3=4, S4=5, S5=6)
39. **Currency Breakdown**: Stage Clear (5) + Stage Rewards + Finish Bonus (25)
40. **CurrencyUI**: มุมบนซ้าย (ใต้ StageFrame)

### 🖥️ UI Layout (มุมบนซ้าย จากบนลงล่าง)
41. **Y=10**: Score Frame (⭐ คะแนน)
42. **Y=16**: High Score (🏆)
43. **Y=58**: Stage Frame (🚩 Progress)
44. **Y=92**: Currency Frame (💰 เงิน)
45. **Y=140**: Class Indicator (🎭 Class - light pill 168x40 + mastery badge + chevron)
46. **Y=186**: Active Title HUD (🏷️ light bar 220x36 + ปุ่ม 📋 เปิด Collection)

### 📊 Leaderstats
47. **Built-in UI**: แสดง HighScore, RoundScore, Currency
48. **Update**: เรียก `updateLeaderstats()` เมื่อค่าเปลี่ยน

### 📈 Class Mastery
49. **Mastery Data**: เก็บใน profile key เดียวกับ score/currency ที่ field `classMastery`
50. **Mastery Rewards Data**: เก็บสถานะ reward ที่ปลดแล้วใน field `masteryRewards`
51. **XP Sources**: ผ่านด่านได้ `PerStageXP` และเข้าเส้นชัยได้ `FinishBonusXP`
52. **UI Display**: แสดงทั้ง level/xp บน class card และ preview rewards ของ class ที่เลือก
53. **Remote**: ใช้ `MasteryUpdate` ส่ง level/xp/xpToNext/isMax + masteryRewards + unlockedRewards action

### 🔧 Code Quality (Audit Feb 2026)
54. **Debug Flags**: `Config.Debug.Enabled`, `FlyMode`, `ItemTesting` - ต้อง set `false` ก่อน production
55. **Logger**: `src/shared/Logger.luau` - ใช้ `Logger.debug/info/warn/error(tag, ...)` แทน `print("[Tag]", ...)`
56. **os.clock()**: ใช้ `os.clock()` แทน `tick()` ทั้ง project (tick deprecated)
57. **LinearVelocity/AngularVelocity**: ใช้ constraint-based แทน BodyVelocity/BodyAngularVelocity (deprecated)
58. **UpdateAsync**: DataStore ใช้ `UpdateAsync` (atomic) ไม่ใช่ `GetAsync`+`SetAsync` (race condition)
59. **Connection Cleanup**: CharacterAdded/Died connections ถูก track ใน `playerConnections` table และ disconnect เมื่อ player leave
60. **Input Validation**: `ConfirmStageSelection` remote ผ่าน `validateStageOrder()` ก่อนใช้งาน
61. **Shared Map Limitation**: Map เป็น global shared ใน workspace - ถ้า 2+ players เล่นพร้อมกันจะมีปัญหา (ต้องทำ instanced map ในอนาคต)
62. **Race Direction**: Stages progress ตามแกน +X (ไม่ใช่ +Z) - "ahead" check ใช้ `Position.X`
