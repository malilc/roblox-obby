-- Roblox Obby Game - Server Entry Point
print("[Server] Starting Obby Game...")

local GameManager = require(script.GameManager)

-- Setup workspace object names (ต้องเซ็ตหลัง Rojo sync เสร็จ)
local spawnLocation = workspace:FindFirstChild("SpawnLocation")
if spawnLocation then
	spawnLocation.Name = "LobbySpawn"
	print("[Server] SpawnLocation renamed to LobbySpawn")
end

local lobby = workspace:FindFirstChild("Lobby")
if lobby then
	local selectionZone = lobby:FindFirstChild("SelectionZone")
	if selectionZone then
		selectionZone.Name = "SelectionZone"
		print("[Server] Lobby SelectionZone named correctly")
	end
end

-- Initialize game
local game_manager = GameManager.new()

print("[Server] Obby Game initialized!")
print("[Server] Map generated with randomized stages")
print("[Server] Waiting for players...")
