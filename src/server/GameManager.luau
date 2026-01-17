-- GameManager: ควบคุมการทำงานของเกมทั้งหมด

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapManager = require(script.Parent.MapManager)
local ScoreManager = require(script.Parent.ScoreManager)
local ItemManager = require(script.Parent.ItemManager)
local Config = require(ReplicatedStorage.Shared.Config)

local GameManager = {}
GameManager.__index = GameManager

export type PlayerState = "Lobby" | "Playing" | "Finished"

function GameManager.new()
	local self = setmetatable({}, GameManager)
	
	-- Managers
	self.mapManager = MapManager.new()
	self.scoreManager = ScoreManager.new()
	self.itemManager = ItemManager.new()
	
	-- Player states
	self.playerStates = {} :: {[Player]: PlayerState}
	self.playerCheckpoints = {} :: {[Player]: Vector3}
	
	-- Remotes
	self.startGameRemote = ReplicatedStorage.Remotes.StartGame
	self.stageCompleteRemote = ReplicatedStorage.Remotes.StageComplete
	self.playerDiedRemote = ReplicatedStorage.Remotes.PlayerDied
	
	-- Setup
	self:setupRemotes()
	self:setupPlayerEvents()
	self:setupLobby()
	
	-- Generate initial map
	self:generateNewMap()
	
	return self
end

-- Setup remote events
function GameManager:setupRemotes()
	-- Start game from lobby
	self.startGameRemote.OnServerEvent:Connect(function(player)
		self:startGameForPlayer(player)
	end)
end

-- Setup player events
function GameManager:setupPlayerEvents()
	Players.PlayerAdded:Connect(function(player)
		self:onPlayerAdded(player)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		self:onPlayerRemoving(player)
	end)
	
	-- Handle existing players
	for _, player in ipairs(Players:GetPlayers()) do
		self:onPlayerAdded(player)
	end
end

-- Player added
function GameManager:onPlayerAdded(player: Player)
	self.playerStates[player] = "Lobby"
	
	-- Initialize managers
	self.scoreManager:initPlayer(player)
	self.scoreManager:setupLeaderstats(player)
	self.itemManager:initPlayer(player)
	
	-- Wait for character
	player.CharacterAdded:Connect(function(character)
		self:onCharacterAdded(player, character)
	end)
	
	-- Handle existing character
	if player.Character then
		self:onCharacterAdded(player, player.Character)
	end
	
	print("[GameManager] Player joined:", player.Name)
end

-- Player removing
function GameManager:onPlayerRemoving(player: Player)
	self.playerStates[player] = nil
	self.playerCheckpoints[player] = nil
	
	self.scoreManager:removePlayer(player)
	self.itemManager:removePlayer(player)
	
	print("[GameManager] Player left:", player.Name)
end

-- Character added
function GameManager:onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid")
	
	-- Handle death
	humanoid.Died:Connect(function()
		self:onPlayerDied(player)
	end)
	
	-- Setup touch events for character
	task.wait(0.5) -- Wait for character to fully load
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		self:setupCharacterTouchEvents(player, humanoidRootPart)
	end
end

-- Setup touch events for character
function GameManager:setupCharacterTouchEvents(player: Player, rootPart: Part)
	-- Monitor position for stage completion
	task.spawn(function()
		while player.Character and player.Character:FindFirstChild("HumanoidRootPart") do
			self:checkPlayerPosition(player)
			task.wait(0.5)
		end
	end)
end

-- Check player position
function GameManager:checkPlayerPosition(player: Player)
	local state = self.playerStates[player]
	if state ~= "Playing" then return end
	
	local character = player.Character
	if not character then return end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	
	local position = humanoidRootPart.Position
	
	-- Check for stage completion
	local currentStageIndex = self.mapManager:getStageIndexFromPosition(position)
	if currentStageIndex then
		local playerCurrentStage = self.scoreManager:getCurrentStage(player)
		
		if currentStageIndex > playerCurrentStage then
			self:onStageComplete(player, currentStageIndex)
		end
	end
	
	-- Check for finish line
	if self.mapManager:isAtFinishLine(position) then
		self:onPlayerFinished(player)
	end
	
	-- Check for kill zone (fall off map)
	if position.Y < Config.KillZoneY then
		self:respawnPlayer(player)
	end
end

-- On stage complete
function GameManager:onStageComplete(player: Player, stageIndex: number)
	self.scoreManager:addStageScore(player, stageIndex)
	self.scoreManager:updateLeaderstats(player)
	
	-- Save checkpoint
	local checkpointPos = self.mapManager:getCheckpointPosition(stageIndex)
	if checkpointPos then
		self.playerCheckpoints[player] = checkpointPos
	end
	
	-- Notify client
	self.stageCompleteRemote:FireClient(player, {
		stageIndex = stageIndex,
		totalStages = Config.Stages.Count,
	})
	
	print("[GameManager]", player.Name, "completed stage", stageIndex)
end

-- On player finished
function GameManager:onPlayerFinished(player: Player)
	local state = self.playerStates[player]
	if state ~= "Playing" then return end
	
	self.playerStates[player] = "Finished"
	
	self.scoreManager:addFinishBonus(player)
	self.scoreManager:updateLeaderstats(player)
	
	-- Notify client
	self.stageCompleteRemote:FireClient(player, {
		finished = true,
		stageIndex = Config.Stages.Count,
		totalStages = Config.Stages.Count,
	})
	
	print("[GameManager]", player.Name, "FINISHED THE OBBY!")
	
	-- Teleport กลับจุดเริ่มต้นทันที (หลังแสดง message 2 วินาที)
	task.delay(2, function()
		self:teleportToStart(player)
	end)
end

-- Teleport กลับจุดเริ่มต้น (Stage 1)
function GameManager:teleportToStart(player: Player)
	self.playerStates[player] = "Playing"
	
	-- Reset scores for new round
	self.scoreManager:resetRoundScore(player)
	self.itemManager:resetPlayer(player)
	
	-- Clear checkpoint
	self.playerCheckpoints[player] = nil
	
	-- Teleport to first stage
	local startPos = self.mapManager:getCheckpointPosition(1)
	if startPos then
		local character = player.Character
		if character then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart then
				humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
				humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
				humanoidRootPart.CFrame = CFrame.new(startPos)
			end
		end
	end
	
	print("[GameManager]", player.Name, "teleported back to start!")
end

-- On player died
function GameManager:onPlayerDied(player: Player)
	local state = self.playerStates[player]
	if state ~= "Playing" then return end
	
	print("[GameManager]", player.Name, "died")
	
	-- Will respawn at checkpoint via respawnPlayer when character is added again
end

-- Respawn player at checkpoint
function GameManager:respawnPlayer(player: Player)
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	
	if not humanoid or not humanoidRootPart then return end
	
	-- Get checkpoint
	local checkpoint = self.playerCheckpoints[player]
	if not checkpoint then
		-- Use first stage checkpoint
		checkpoint = self.mapManager:getCheckpointPosition(1)
	end
	
	if checkpoint then
		-- Reset velocity
		humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
		humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
		
		-- Teleport
		humanoidRootPart.CFrame = CFrame.new(checkpoint)
		
		print("[GameManager] Respawned", player.Name, "at checkpoint")
	end
	
	-- Notify client
	self.playerDiedRemote:FireClient(player)
end

-- Setup lobby
function GameManager:setupLobby()
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then return end
	
	-- Setup portal touch
	local portal = lobby:FindFirstChild("StartPortal")
	if portal then
		portal.Touched:Connect(function(hit)
			local humanoid = hit.Parent:FindFirstChild("Humanoid")
			if humanoid then
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player then
					self:startGameForPlayer(player)
				end
			end
		end)
	end
	
	-- Setup kill brick
	local killBrick = workspace:FindFirstChild("KillBrick")
	if killBrick then
		killBrick.Touched:Connect(function(hit)
			local humanoid = hit.Parent:FindFirstChild("Humanoid")
			if humanoid then
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player and self.playerStates[player] == "Playing" then
					self:respawnPlayer(player)
				end
			end
		end)
	end
end

-- Start game for player
function GameManager:startGameForPlayer(player: Player)
	local state = self.playerStates[player]
	if state ~= "Lobby" then return end
	
	self.playerStates[player] = "Playing"
	
	-- Reset scores
	self.scoreManager:resetRoundScore(player)
	self.itemManager:resetPlayer(player)
	
	-- Clear checkpoint
	self.playerCheckpoints[player] = nil
	
	-- Teleport to first stage
	local startPos = self.mapManager:getCheckpointPosition(1)
	if startPos then
		local character = player.Character
		if character then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart then
				humanoidRootPart.CFrame = CFrame.new(startPos)
			end
		end
	end
	
	print("[GameManager]", player.Name, "started the obby!")
end

-- Teleport to lobby
function GameManager:teleportToLobby(player: Player)
	self.playerStates[player] = "Lobby"
	
	-- Reset scores for next round
	self.scoreManager:resetRoundScore(player)
	self.itemManager:resetPlayer(player)
	
	-- Clear checkpoint
	self.playerCheckpoints[player] = nil
	
	-- Teleport to SpawnLocation
	local spawn = workspace:FindFirstChild("SpawnLocation")
	if spawn then
		local character = player.Character
		if character then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart then
				humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
				humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
				humanoidRootPart.CFrame = CFrame.new(spawn.Position + Vector3.new(0, 3, 0))
			end
		end
	end
	
	print("[GameManager]", player.Name, "returned to lobby")
end

-- Generate new map
function GameManager:generateNewMap()
	self.mapManager:generateMap()
	
	-- Setup kill parts
	self:setupKillParts()
	
	-- Setup finish line touch detection
	self:setupFinishLine()
	
	-- Setup item pickups
	local pickups = self.mapManager:getAllItemPickups()
	self.itemManager:setupItemPickups(pickups)
	
	print("[GameManager] New map generated!")
	print("[GameManager] Stage order:", table.concat(self.mapManager.stageOrder, ", "))
end

-- Setup finish line touch detection
function GameManager:setupFinishLine()
	local finishPos = self.mapManager:getFinishLinePosition()
	if not finishPos then return end
	
	-- หา EndPart ของ stage สุดท้าย
	local lastStage = self.mapManager.currentStages[#self.mapManager.currentStages]
	if lastStage then
		local endPart = lastStage:FindFirstChild("EndPart")
		if endPart then
			-- เพิ่ม touch detection
			endPart.Touched:Connect(function(hit)
				local humanoid = hit.Parent:FindFirstChild("Humanoid")
				if humanoid then
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if player and self.playerStates[player] == "Playing" then
						self:onPlayerFinished(player)
					end
				end
			end)
			
			-- เปลี่ยนสี EndPart ให้เด่นชัด (เส้นชัย)
			endPart.Color = Color3.fromRGB(0, 255, 100)
			endPart.Material = Enum.Material.Neon
			
			print("[GameManager] Finish line setup at:", endPart.Position)
		end
	end
end

-- Setup kill parts
function GameManager:setupKillParts()
	local killParts = self.mapManager:getAllKillParts()
	
	for _, part in ipairs(killParts) do
		part.Touched:Connect(function(hit)
			local humanoid = hit.Parent:FindFirstChild("Humanoid")
			if humanoid then
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player and self.playerStates[player] == "Playing" then
					self:respawnPlayer(player)
				end
			end
		end)
	end
end

-- Regenerate map (for admin or periodic reset)
function GameManager:regenerateMap()
	-- Reset all playing players to lobby
	for player, state in pairs(self.playerStates) do
		if state == "Playing" then
			self:teleportToLobby(player)
		end
	end
	
	-- Generate new map
	self:generateNewMap()
end

return GameManager
