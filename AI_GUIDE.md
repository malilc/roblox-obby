# AI Development Guide - Roblox Obby Game

คู่มือสำหรับ AI ที่จะมาพัฒนาต่อ

## 📁 Project Structure

```
src/
├── server/                      # Server-side code
│   ├── init.server.luau         # Entry point - สร้าง GameManager
│   ├── GameManager.luau         # ควบคุมเกมทั้งหมด
│   ├── MapManager.luau          # จัดการ map/stages + animations
│   ├── ScoreManager.luau        # ระบบคะแนน + DataStore
│   ├── ItemManager.luau         # ระบบ Push item
│   └── StageTemplates.luau      # ⭐ สร้างด่าน obby ที่นี่
│
├── client/                      # Client-side code
│   ├── init.client.luau         # Entry point
│   ├── FlyController.luau       # ระบบบินทดสอบ (กด F)
│   └── UI/
│       ├── MainUI.luau          # Controller หลัก
│       ├── ScoreUI.luau         # แสดงคะแนน
│       ├── ItemUI.luau          # แสดง Push item
│       └── LeaderboardUI.luau   # Leaderboard
│
└── shared/                      # Shared code (server + client)
    ├── Config.luau              # ⭐ ค่า Config ทั้งหมด
    └── Types.luau               # Type definitions
```

---

## 🏠 Workspace Structure

```
Workspace/
├── SpawnLocation          # จุดเกิดเริ่มต้น (ต้องอยู่ใน Workspace โดยตรง!)
├── Lobby/
│   ├── Floor              # พื้น Lobby
│   └── StartPortal        # Portal เข้าเกม
├── Stages/                # Folder เก็บด่านที่ generate
└── KillBrick              # พื้นที่ตายเมื่อตก
```

**สำคัญ**: `SpawnLocation` ต้องอยู่ใน Workspace โดยตรง ไม่ใช่ใน Folder ไม่งั้น Roblox จะไม่รู้จักเป็นจุดเกิด

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
| `createItemPickup(pos)` | `Part` | สร้าง Item pickup (ลูกบอลสีทอง) |

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
| `IsSpinning` | boolean | หมุนรอบแกน Y |
| `SpinSpeed` | number | ความเร็วหมุน |
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

## 🎲 ระบบสุ่มด่าน

### ไฟล์: `src/server/MapManager.luau`

```lua
-- Seed random เพื่อให้สุ่มได้จริง (ทำอัตโนมัติแล้ว)
math.randomseed(os.time() + os.clock() * 1000)

-- Fisher-Yates shuffle
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
```

**Output ใน Console**: `[GameManager] Stage order: 3, 1, 5, 2, 4`

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
        SpawnPosition = Vector3.new(0, 5, 0),
    },

    -- Stage Settings
    Stages = {
        Count = 5,              -- จำนวนด่าน
        StageLength = 100,      -- ความยาวแต่ละด่าน
        StartOffset = Vector3.new(0, 0, 50),
    },

    -- Score Settings
    Score = {
        PerStage = 10,          -- คะแนนต่อด่าน
        FinishBonus = 50,       -- โบนัสจบเกม
    },

    -- Push Item Settings
    PushItem = {
        StartingAmount = 1,     -- เริ่มต้นมีกี่ชิ้น
        MaxAmount = 5,          -- สูงสุด
        Range = 15,             -- ระยะโจมตี
        Force = 100,            -- แรงผลัก
        Cooldown = 10,          -- cooldown (วินาที)
    },

    KillZoneY = -20,            -- ความสูงที่ตาย
}
```

---

## 🎮 การเพิ่ม Item ใหม่

### ไฟล์ที่ต้องแก้:
1. `src/server/ItemManager.luau` - Logic
2. `src/client/UI/ItemUI.luau` - UI
3. `src/shared/Config.luau` - Config

### ขั้นตอน:

1. เพิ่ม Config ใน `Config.luau`:
```lua
NewItem = {
    StartingAmount = 0,
    MaxAmount = 3,
    Duration = 5,
    Cooldown = 15,
},
```

2. เพิ่ม Logic ใน `ItemManager.luau`:
```lua
function ItemManager:useNewItem(player: Player)
    -- implement logic
end
```

3. เพิ่ม RemoteEvent ใน `default.project.json`:
```json
"UseNewItem": {
    "$className": "RemoteEvent"
}
```

---

## 📡 RemoteEvents

### ไฟล์: `default.project.json` → `ReplicatedStorage.Remotes`

| Event | Direction | Usage |
|-------|-----------|-------|
| `UseItem` | Client → Server | ใช้ Push item |
| `UpdateScore` | Server → Client | อัพเดทคะแนน |
| `StageComplete` | Server → Client | ผ่านด่าน |
| `StartGame` | Client → Server | เริ่มเกมจาก Lobby |
| `UpdateLeaderboard` | Server → Client | อัพเดท Leaderboard |
| `PlayerDied` | Server → Client | แจ้งผู้เล่นตาย |

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

## 🎨 การแก้ไข UI

### ไฟล์หลัก: `src/client/UI/`

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
Spawn at Lobby (SpawnLocation in Workspace)
    ↓
GameManager:onPlayerAdded()
    ↓
ScoreManager:initPlayer() + ItemManager:initPlayer()
    ↓
Touch StartPortal
    ↓
GameManager:startGameForPlayer()
    ↓
Teleport to Stage 1 Checkpoint
    ↓
Playing (checkPlayerPosition loop)
    ↓
Pass Checkpoint → ScoreManager:addStageScore()
    ↓
Touch EndPart of last stage (Finish Line)
    ↓
GameManager:onPlayerFinished()
    ↓
Wait 2 seconds → Teleport back to Stage 1
```

---

## 🧪 Testing

### Fly Mode (ทดสอบ):
- กด **F** เพื่อบิน
- **W/A/S/D** เคลื่อนที่
- **Space** ขึ้น, **Shift/Ctrl** ลง
- ปุ่ม **+/-** ปรับความเร็ว (25-200)

### Debug Output:
```
[Server] Starting Obby Game...
[MapManager] Stage order: 3, 1, 5, 2, 4
[GameManager] Finish line setup at: 0, 0, 550
[GameManager] PlayerName started the obby!
[GameManager] PlayerName completed stage 1
[GameManager] PlayerName FINISHED THE OBBY!
```

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
| `STAGE_LENGTH` | 100 | StageTemplates.luau |
| `Config.Stages.Count` | 5 | Config.luau |
| `Config.KillZoneY` | -20 | Config.luau |
| `Friction` | 2.0 | StageTemplates.luau |

---

## ⚠️ Important Notes

1. **SpawnLocation**: ต้องอยู่ใน Workspace โดยตรง ไม่ใช่ใน Folder
2. **Checkpoint**: ใช้ `Part` ไม่ใช่ `SpawnLocation` (ไม่งั้นผู้เล่นจะเกิดที่นี่)
3. **Moving Platform**: ใช้ `PrismaticConstraint` (physics-based) ไม่ใช่ CFrame animation
4. **Friction**: ทุก Part มี `CustomPhysicalProperties` กับ Friction = 2.0
5. **Random Seed**: `math.randomseed()` ถูกเรียกใน MapManager แล้ว
6. **Stage ต้องมี**: StartPart, EndPart, Checkpoint, Obstacles folder, ItemPickups folder
7. **Position**: Stage วางต่อกันตามแกน Z (ไปข้างหน้า)
8. **DataStore**: ใช้ `ObbyGameData_v1` - เปลี่ยนชื่อถ้าต้องการ reset
9. **Rojo**: ใช้ `rojo serve` เพื่อ sync กับ Studio
