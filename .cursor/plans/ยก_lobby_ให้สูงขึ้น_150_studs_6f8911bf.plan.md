---
name: ยก Lobby ให้สูงขึ้น 150 studs
overview: ""
todos:
  - id: config-update
    content: อัปเดต Config.luau เพิ่ม LobbyHeight และแก้ SpawnPosition
    status: completed
  - id: gammgr-update
    content: แก้ GameManager.teleportToLobby() ให้ใช้ความสูงใหม่และหันหน้าไปด่าน
    status: completed
---

# ยก Lobby ให้สูงขึ้น 150 studs เพื่อมองเห็นด่านทั้งหมด

## ภาพรวม

ยก Lobby ขึ้นไปที่ 150 studs เพื่อให้ผู้เล่นมองเห็นด่านทั้งหมดจากด้านบน การควบคุมกล้องยังคงแบบ manual เหมือนเดิม

## ไฟล์ที่จะแก้ไข

### 1. [src/shared/Config.luau](src/shared/Config.luau)

- เพิ่ม `LobbyHeight = 150` ใน `Lobby` section
- เปลี่ยน `SpawnPosition` จาก `Vector3.new(0, 5, 0)` เป็น `Vector3.new(0, Config.Lobby.LobbyHeight, 0)`
- เก็บ `StartOffset` ที่ `Vector3.new(0, 0, 150)` เดิม (Stage จะอยู่ที่ Y = 0)

### 2. [src/server/GameManager.luau](src/server/GameManager.luau)

- อัปเดต `teleportToLobby()` บรรทัด 484-495 ให้ใช้ความสูงจาก `Config.Lobby.LobbyHeight` แทนค่าคงที่
- เพิ่ม logic หันหน้าไปทางด่านด้วย `CFrame.lookAt` เมื่อ teleport กลับ Lobby

### 3. [src/server/MapManager.luau](src/server/MapManager.luau)

- ไม่ต้องแก้ (logic การสร้าง Stage ยังเข้ากันได้ เพราะ StartOffset เป็นเดิม)

## ผลลัพธ์

- Lobby อยู่ที่ `Y = 150`
- Stage เริ่มที่ `Y = 0` (ห่างจาก Lobby 150 studs ในแนวแกน Y)
- ผู้เล่นอยู่ใน Lobby สามารถมองลงไปเห็นด่านทั้งหมด
- การควบคุมกล้อง: manual (เหมือนเดิม)