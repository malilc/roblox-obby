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
│       ├── LeaderboardUI.luau   # Leaderboard
│       └── StageSelectionUI.luau # ⭐ GUI เลือกลำดับด่าน
│
└── shared/                      # Shared code (server + client)
    ├── Config.luau              # ⭐ ค่า Config ทั้งหมด
    └── Types.luau               # Type definitions
```

---

## 🏠 Workspace Structure

```
Workspace/
├── SpawnLocation          # จุดเกิดเริ่มต้น (หันไปทาง +Z)
├── Lobby/
│   ├── Floor              # พื้น Lobby
│   └── SelectionZone      # ⭐ Zone เลือกด่าน (สีฟ้า, เดินเข้าไปเพื่อเปิด GUI)
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
ผู้เล่นเดินเข้า SelectionZone (สีฟ้า)
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
| `IsCoin` | boolean | เหรียญ Item Pickup (หมุนรอบแกน Y แนวตั้ง) |
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

### ตัวอย่าง: Item Coin Pickup

```lua
local coin = createItemPickup(startPosition + Vector3.new(0, 5, 20))
coin.Parent = itemPickups
```

**createItemPickup สร้าง:**
- รูปทรง: **Mesh (Item Box)** ID: 6325349064
- ขนาด: Scale `0.30, 0.30, 0.30`
- สี: **ทอง** (255, 215, 0)
- ยกขึ้น: **+3 studs** จากตำแหน่งที่ให้
- หมุน: อัตโนมัติรอบแกน Y (ตั้งค่า `IsCoin` attribute)
- เอฟเฟกต์: Sparkles + PointLight เรืองแสง

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

    -- Push Item Settings
    PushItem = {
        StartingAmount = 1,     -- เริ่มต้นมีกี่ชิ้น
        MaxAmount = 5,          -- สูงสุด
        Range = 15,             -- ระยะโจมตี
        Force = 100,            -- แรงผลัก
        Cooldown = 10,          -- cooldown (วินาที)
    },

    KillZoneY = -120,            -- ความสูงที่ตาย
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
| `StartGame` | Client → Server | เริ่มเกมจาก Lobby (legacy) |
| `UpdateLeaderboard` | Server → Client | อัพเดท Leaderboard |
| `PlayerDied` | Server → Client | แจ้งผู้เล่นตาย |
| `ShowStageSelection` | Server → Client | ⭐ แสดง GUI เลือกด่าน |
| `HideStageSelection` | Server → Client | ⭐ ซ่อน GUI เลือกด่าน |
| `ConfirmStageSelection` | Client → Server | ⭐ ยืนยันการเลือกด่าน |
| `CountdownUpdate` | Server → Client | ⭐ อัพเดท countdown 3, 2, 1 |

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

### UI ที่มีอยู่:

| Module | ตำแหน่ง | Description |
|--------|---------|-------------|
| `ScoreUI` | มุมบนซ้าย | 💰 คะแนน + 🏆 High Score + 🚩 Progress Bar |
| `ItemUI` | มุมล่างขวา | 👊 Push item (วงกลม 60x60) |
| `LeaderboardUI` | ขวาบน | 🏆 Toggle button + Leaderboard Panel |
| `FlyController` | ล่างซ้าย | FLY [F] ปุ่ม + Speed controls |
| `StageSelectionUI` | กลางจอ | ⭐ เลือกลำดับด่าน + Countdown |

### StageSelectionUI:
- **ปุ่มด่าน 1-5**: คลิกเพื่อเพิ่ม/ลบจากลำดับ
- **Selected display**: แสดงลำดับที่เลือก (เช่น "3 → 1 → 5")
- **ปุ่ม RANDOM**: สุ่มลำดับด่าน
- **ปุ่ม START**: กดได้เมื่อเลือกอย่างน้อย 1 ด่าน
- **Countdown**: แสดง 3, 2, 1 ก่อน teleport

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
ScoreManager:initPlayer() + ItemManager:initPlayer()
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
Pass Checkpoint → ScoreManager:addStageScore()
    ↓
Touch EndPart of last stage (Finish Line)
    ↓
GameManager:onPlayerFinished() → Set teleportingToLobby flag
    ↓
ScoreManager:addFinishBonus() + Save to DataStore
    ↓
Wait 2 seconds
    ↓
GameManager:teleportToLobby() → Use Config.Lobby.SpawnPosition
    ↓
Clear teleportingToLobby flag after 0.5 วินาที
    ↓
Back to Lobby (State = "Lobby")
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
| `STAGE_LENGTH` | 100 | StageTemplates.luau |
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

1. **SpawnLocation**: ต้องอยู่ใน Workspace โดยตรง ไม่ใช่ใน Folder (หันไปทาง SelectionZone)
2. **SelectionZone**: ใช้ loop-based detection ทุก 0.2 วินาที (เสถียรกว่า Touched)
3. **Checkpoint**: ใช้ `Part` ไม่ใช่ `SpawnLocation` (ไม่งั้นผู้เล่นจะเกิดที่นี่)
4. **Moving Platform**: ใช้ `PrismaticConstraint` (physics-based) ไม่ใช่ CFrame animation
5. **Friction**: ทุก Part มี `CustomPhysicalProperties` กับ Friction = 2.0
6. **Random Seed**: `math.randomseed()` ถูกเรียกใน MapManager แล้ว
7. **Stage ต้องมี**: StartPart, EndPart, Checkpoint, Obstacles folder, ItemPickups folder
8. **Position**: Stage วางต่อกันตามแกน X (ไปทางซ้าย)
9. **DataStore**: ใช้ `ObbyGameData_v1` - เปลี่ยนชื่อถ้าต้องการ reset
10. **Rojo**: ใช้ `rojo serve` เพื่อ sync กับ Studio
11. **Item Box**: ใช้ `createItemPickup()` → Mesh ID: 6325349064, Scale 0.30, หมุนรอบ Y, มีแสง
12. **UI Design**: ใช้ขนาดเล็ก + โปร่งใส เพื่อไม่ให้บังจอ
13. **Map Generation**: ไม่สร้างตอนเริ่มเกม จะสร้างเมื่อผู้เล่นเลือกด่านแล้ว
14. **Teleport Direction**: ใช้ `CFrame.lookAt()` เพื่อหันหน้าไปทาง +X (ไปทางซ้าย)
15. **จบเกม**: กลับไป Lobby โดยใช้ `Config.Lobby.SpawnPosition` (ไม่ใช่ Stage 1)
16. **Finish Line Detection**: ใช้ทั้ง `Touched` event และ position-based check (double check)
17. **Teleport Protection**: ใช้ `teleportingToLobby` flag ป้องกันการเรียกซ้ำ
18. **Lobby Position**: ต้องตรงกับ `Config.Lobby.SpawnPosition = (0, 103, 0)`
19. **DataStore Error**: ใน Studio จะแจ้ง error ถ้าไม่เปิด API access (ปกติใช้ได้จริง)
21. **Stage Counting**: เริ่มต้นที่ **0/N** (เข้า Stage 1), เข้า Stage 2 เป็น **1/N**, จบเกมเป็น **N/N**
22. **Stage Visibility**: ซ่อนใน Lobby, แสดงตอน Countdown, ซ่อนเมื่อจบเกม
23. **Scoring**: เริ่ม Stage 1 ไม่ได้คะแนน, เข้า Stage 2 ได้คะแนน (ถือว่าผ่านด่าน 1)
