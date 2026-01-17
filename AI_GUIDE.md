# AI Development Guide - Roblox Obby Game

คู่มือสำหรับ AI ที่จะมาพัฒนาต่อ

## 📁 Project Structure

```
src/
├── server/                      # Server-side code
│   ├── init.server.luau         # Entry point - สร้าง GameManager
│   ├── GameManager.luau         # ควบคุมเกมทั้งหมด
│   ├── MapManager.luau          # จัดการ map/stages
│   ├── ScoreManager.luau        # ระบบคะแนน + DataStore
│   ├── ItemManager.luau         # ระบบ Push item
│   └── StageTemplates.luau      # ⭐ สร้างด่าน obby ที่นี่
│
├── client/                      # Client-side code
│   ├── init.client.luau         # Entry point
│   ├── FlyController.luau       # ระบบบินทดสอบ
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
    
    -- 2. Checkpoint (จุด respawn - ต้องมี)
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

### Attributes สำหรับ Obstacle พิเศษ:

| Attribute | Type | Description |
|-----------|------|-------------|
| `IsMoving` | boolean | Platform เคลื่อนที่ |
| `MoveAxis` | string | "X", "Y", หรือ "Z" |
| `MoveDistance` | number | ระยะเคลื่อนที่ (studs) |
| `MoveSpeed` | number | ความเร็ว |
| `IsSpinning` | boolean | หมุนรอบแกน Y |
| `SpinSpeed` | number | ความเร็วหมุน |
| `IsDisappearing` | boolean | หายไปเมื่อเหยียบ |
| `DisappearDelay` | number | วินาทีก่อนหาย |
| `ReappearDelay` | number | วินาทีก่อนกลับมา |
| `IsKillPart` | boolean | แตะแล้วตาย (respawn) |
| `IsFinishLine` | boolean | เส้นชัย (เฉพาะด่านสุดท้าย) |

### ตัวอย่าง: เพิ่ม Moving Platform

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

### ตัวอย่าง: เพิ่ม Spinning Kill Part

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
GameManager:onPlayerAdded()
    ↓
ScoreManager:initPlayer() + ItemManager:initPlayer()
    ↓
Player in Lobby
    ↓
Touch Portal / Press Start
    ↓
GameManager:startGameForPlayer()
    ↓
Teleport to Stage 1
    ↓
Playing (checkPlayerPosition loop)
    ↓
Pass Checkpoint → ScoreManager:addStageScore()
    ↓
Reach Finish → ScoreManager:addFinishBonus()
    ↓
Return to Lobby
```

---

## 🧪 Testing

### Fly Mode (ทดสอบ):
- กด **F** เพื่อบิน
- **W/A/S/D** เคลื่อนที่
- **Space** ขึ้น, **Shift** ลง
- ปุ่ม +/- ปรับความเร็ว

### Commands (เพิ่มเองได้):
สามารถเพิ่ม admin commands ใน `init.server.luau`:
```lua
Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
        if message == "/regen" then
            gameManager:regenerateMap()
        end
    end)
end)
```

---

## 📝 Quick Reference

### Helper Functions ใน StageTemplates.luau:

| Function | Description |
|----------|-------------|
| `createPart(props)` | สร้าง Part พร้อม properties |
| `createCheckpoint(pos)` | สร้าง SpawnLocation |
| `createItemPickup(pos)` | สร้าง Item pickup (ลูกบอลสีทอง) |

### Constants:

| Constant | Value | Location |
|----------|-------|----------|
| `STAGE_LENGTH` | 100 | StageTemplates.luau |
| `Config.Stages.Count` | 5 | Config.luau |
| `Config.KillZoneY` | -20 | Config.luau |

---

## ⚠️ Important Notes

1. **Stage ต้องมี**: StartPart, EndPart, Checkpoint, Obstacles folder, ItemPickups folder
2. **Position**: Stage วางต่อกันตามแกน Z (ไปข้างหน้า)
3. **Checkpoint**: ตำแหน่ง respawn เมื่อตาย
4. **DataStore**: ใช้ `ObbyGameData_v1` - เปลี่ยนชื่อถ้าต้องการ reset
5. **Rojo**: ใช้ `rojo serve` เพื่อ sync กับ Studio
