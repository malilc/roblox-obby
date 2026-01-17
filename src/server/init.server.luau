-- Roblox Obby Game - Server Entry Point
print("[Server] Starting Obby Game...")

local GameManager = require(script.GameManager)

-- Initialize game
local game_manager = GameManager.new()

print("[Server] Obby Game initialized!")
print("[Server] Map generated with randomized stages")
print("[Server] Waiting for players...")
