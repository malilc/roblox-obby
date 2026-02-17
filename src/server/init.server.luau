-- Roblox Obby Game - Server Entry Point
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(ReplicatedStorage.Shared.Logger)

Logger.info("Server", "Starting Obby Game...")

local GameManager = require(script.GameManager)

-- Setup workspace object names (ต้องเซ็ตหลัง Rojo sync เสร็จ)
local spawnLocation = workspace:FindFirstChild("SpawnLocation")
if spawnLocation then
	spawnLocation.Name = "LobbySpawn"
	Logger.info("Server", "SpawnLocation renamed to LobbySpawn")
end

local lobby = workspace:FindFirstChild("Lobby")
if lobby then
	local selectionZone = lobby:FindFirstChild("SelectionZone")
	if selectionZone then
		selectionZone.Name = "SelectionZone"
		Logger.info("Server", "Lobby SelectionZone named correctly")
	end
end

-- Initialize game
local game_manager = GameManager.new()

Logger.info("Server", "Obby Game initialized!")
Logger.info("Server", "Map generated with randomized stages")
Logger.info("Server", "Waiting for players...")
