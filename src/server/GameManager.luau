-- GameManager: ควบคุมการทำงานของเกมทั้งหมด

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapManager = require(script.Parent.MapManager)
local ScoreManager = require(script.Parent.ScoreManager)
local ItemManager = require(script.Parent.ItemManager)
local CurrencyManager = require(script.Parent.CurrencyManager)
local MatchManager = require(script.Parent.MatchManager)
local ClassManager = require(script.Parent.ClassManager)
local Config = require(ReplicatedStorage.Shared.Config)

local GameManager = {}
GameManager.__index = GameManager

export type PlayerState = "Lobby" | "Playing" | "Finished"

function GameManager.new()
	local self = setmetatable({}, GameManager)
	
	-- Managers
	self.mapManager = MapManager.new()
	self.currencyManager = CurrencyManager.new()
	self.scoreManager = ScoreManager.new(self.currencyManager) -- Pass CurrencyManager to ScoreManager
	self.matchManager = MatchManager.new(self) -- Pass GameManager to MatchManager (create before ItemManager)
	self.classManager = ClassManager.new(self.currencyManager, function(player: Player)
		return self:canPlayerChangeClass(player)
	end) -- Character class system
	self.itemManager = ItemManager.new(self.currencyManager, self, self.matchManager) -- Pass CurrencyManager, GameManager, and MatchManager to ItemManager
	
	-- Player states
	self.playerStates = {} :: {[Player]: PlayerState}
	self.playerCheckpoints = {} :: {[Player]: Vector3}
	self.teleportingToLobby = {} :: {[Player]: boolean} -- Track teleporting players
	
	-- Per-player match tracking (for instanced maps)
	self.playerMatchIds = {} :: {[Player]: string} -- Player -> MatchId mapping
	
	-- Round statistics for summary
	self.playerRoundStats = {} :: {[Player]: {
		startTime: number,
		coinsCollected: number,
	}}
	
	-- Remotes
	self.startGameRemote = ReplicatedStorage.Remotes.StartGame
	self.stageCompleteRemote = ReplicatedStorage.Remotes.StageComplete
	self.playerDiedRemote = ReplicatedStorage.Remotes.PlayerDied
	self.showStageSelectionRemote = ReplicatedStorage.Remotes.ShowStageSelection
	self.hideStageSelectionRemote = ReplicatedStorage.Remotes.HideStageSelection
	self.confirmStageSelectionRemote = ReplicatedStorage.Remotes.ConfirmStageSelection
	self.countdownUpdateRemote = ReplicatedStorage.Remotes.CountdownUpdate
	
	-- Selection zone tracking
	self.playersInSelectionZone = {} :: {[Player]: boolean}

	-- Player event connections (for cleanup on leave)
	self.playerConnections = {} :: {[Player]: {RBXScriptConnection}}
	self.playerDiedConnections = {} :: {[Player]: RBXScriptConnection?}
	
	-- Setup
	self:setupRemotes()
	self:setupPlayerEvents()
	self:setupLobby()
	self:setupSelectionZone()
	
	-- ไม่สร้าง map ตอนเริ่ม - จะสร้างเมื่อผู้เล่นเลือกด่าน
	-- self:generateNewMap()
	
	return self
end

function GameManager:canPlayerChangeClass(player: Player): boolean
	return self.playerStates[player] == "Lobby"
end

-- Get match ID for a player (returns nil if not in a match / solo play)
function GameManager:getMatchIdForPlayer(player: Player): string?
	return self.playerMatchIds[player]
end

-- Check if player is in an active match with instanced map
function GameManager:isPlayerInInstancedMatch(player: Player): boolean
	local matchId = self.playerMatchIds[player]
	if not matchId then return false end
	return self.mapManager:getMatchMapData(matchId) ~= nil
end

-- Setup remote events
function GameManager:setupRemotes()
	-- Start game from lobby
	self.startGameRemote.OnServerEvent:Connect(function(player)
		self:startGameForPlayer(player)
	end)
	
	-- Confirm stage selection
	self.confirmStageSelectionRemote.OnServerEvent:Connect(function(player, data)
		self:onStageSelectionConfirmed(player, data)
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
	self.playerConnections[player] = {}

	-- Initialize managers
	self.scoreManager:initPlayer(player)
	self.scoreManager:setupLeaderstats(player)
	self.currencyManager:initPlayer(player)
	self.itemManager:initPlayer(player)
	self.classManager:initPlayer(player)

	-- Wait for character (store connection for cleanup)
	local charConn = player.CharacterAdded:Connect(function(character)
		self:onCharacterAdded(player, character)
	end)
	table.insert(self.playerConnections[player], charConn)

	-- Handle existing character
	if player.Character then
		self:onCharacterAdded(player, player.Character)
	end

	print("[GameManager] Player joined:", player.Name)
end

-- Player removing
function GameManager:onPlayerRemoving(player: Player)
	-- Disconnect all event connections for this player
	for _, conn in ipairs(self.playerConnections[player] or {}) do
		conn:Disconnect()
	end
	self.playerConnections[player] = nil

	if self.playerDiedConnections[player] then
		self.playerDiedConnections[player]:Disconnect()
		self.playerDiedConnections[player] = nil
	end

	self.playerStates[player] = nil
	self.playerCheckpoints[player] = nil
	self.playersInSelectionZone[player] = nil
	self.teleportingToLobby[player] = nil
	self.playerRoundStats[player] = nil

	self.scoreManager:removePlayer(player)
	self.currencyManager:removePlayer(player)
	self.itemManager:removePlayer(player)
	self.matchManager:removePlayer(player)
	self.classManager:removePlayer(player)

	print("[GameManager] Player left:", player.Name)
end

-- Character added
function GameManager:onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid")

	-- Disconnect previous Died connection to prevent leak
	if self.playerDiedConnections[player] then
		self.playerDiedConnections[player]:Disconnect()
	end

	-- Handle death (store connection for cleanup)
	self.playerDiedConnections[player] = humanoid.Died:Connect(function()
		self:onPlayerDied(player)
	end)
	
	-- Setup touch events for character
	task.wait(0.5) -- Wait for character to fully load
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		self:setupCharacterTouchEvents(player, humanoidRootPart)
	end

	if self.currencyManager and self.currencyManager.applyActiveTitleToCharacter then
		self.currencyManager:applyActiveTitleToCharacter(player, character)
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

	-- Skip if teleporting to lobby
	if self.teleportingToLobby[player] then return end
	
	local character = player.Character
	if not character then return end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	
	local position = humanoidRootPart.Position
	
	-- Check if player is in an instanced match
	local matchId = self:getMatchIdForPlayer(player)
	if matchId then
		-- Use per-match map functions
		local currentStageIndex = self.mapManager:getStageIndexFromPositionForMatch(matchId, position)
		if currentStageIndex then
			local playerCurrentStage = self.scoreManager:getCurrentStage(player)
			
			if currentStageIndex > playerCurrentStage then
				self:onStageComplete(player, currentStageIndex)
			end
		end
		
		-- Check for finish line
		if self.mapManager:isAtFinishLineForMatch(matchId, position) then
			self:onPlayerFinished(player)
		end
	else
		-- Use global map (backwards compatibility)
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
	end
	
	-- Check for kill zone (fall off map)
	if position.Y < Config.KillZoneY then
		self:respawnPlayer(player)
	end
end

function GameManager:addMasteryXP(player: Player, amount: number, reason: string)
	if amount <= 0 then return end
	if not self.currencyManager or not self.classManager then return end

	local classId = self.classManager:getPlayerClass(player)
	if not classId then return end

	self.currencyManager:addMasteryXP(player, classId, amount, reason)
end

-- On stage complete
function GameManager:onStageComplete(player: Player, stageIndex: number)
	self.scoreManager:addStageScore(player, stageIndex)
	self.scoreManager:updateLeaderstats(player)
	
	-- Get stage order based on player's match
	local matchId = self:getMatchIdForPlayer(player)
	local stageOrder = if matchId 
		then self.mapManager:getStageOrderForMatch(matchId) 
		else self.mapManager.stageOrder
	
	-- Give currency for completing stage (except stage 1 start)
	if stageIndex > 1 then
		-- Stage Clear bonus (คงที่)
		self.currencyManager:addCurrency(player, Config.Currency.PerStage)

		local stageMasteryXP = (Config.Mastery and Config.Mastery.PerStageXP) or 0
		self:addMasteryXP(player, stageMasteryXP, "StageComplete")
		
		-- Stage Reward (ตามด่านที่ผ่าน)
		local completedStageNum = stageOrder[stageIndex - 1] -- ด่านที่เพิ่งผ่าน
		local stageReward = Config.Currency.StageRewards[completedStageNum] or 0
		if stageReward > 0 then
			self.currencyManager:addCurrency(player, stageReward)
			
			-- Track stage rewards total
			local roundStats = self.playerRoundStats[player]
			if roundStats then
				roundStats.stageRewardsTotal = (roundStats.stageRewardsTotal or 0) + stageReward
			end
		end
	end
	
	-- Save checkpoint
	local checkpointPos
	if matchId then
		checkpointPos = self.mapManager:getCheckpointPositionForMatch(matchId, stageIndex)
	else
		checkpointPos = self.mapManager:getCheckpointPosition(stageIndex)
	end
	if checkpointPos then
		self.playerCheckpoints[player] = checkpointPos
	end
	
	-- Get dynamic total stages
	local totalStages = #stageOrder
	if totalStages == 0 then totalStages = Config.Stages.Count end
	
	-- Update MatchManager with progress
	local character = player.Character
	local distance = 0
	if character and character:FindFirstChild("HumanoidRootPart") then
		distance = character.HumanoidRootPart.Position.X -- Track X position for distance
	end
	self.matchManager:updatePlayerProgress(player, stageIndex, distance)
	
	-- Notify client
	self.stageCompleteRemote:FireClient(player, {
		stageIndex = stageIndex,
		totalStages = totalStages,
		isStart = (stageIndex == 1),
	})
	
	print("[GameManager]", player.Name, if stageIndex == 1 then "started stage 1" else "completed stage " .. (stageIndex - 1))
end

-- On player finished
function GameManager:onPlayerFinished(player: Player)
	local state = self.playerStates[player]
	if state ~= "Playing" then return end

	-- Mark as teleporting to prevent multiple calls
	self.teleportingToLobby[player] = true
	
	self.playerStates[player] = "Finished"
	
	-- Notify MatchManager that player finished
	self.matchManager:playerFinished(player)
	
	self.scoreManager:addFinishBonus(player)
	self.scoreManager:updateLeaderstats(player)
	
	-- Get stage order based on player's match
	local matchId = self:getMatchIdForPlayer(player)
	local stageOrder = if matchId 
		then self.mapManager:getStageOrderForMatch(matchId) 
		else self.mapManager.stageOrder
	
	-- Get dynamic total stages
	local totalStages = #stageOrder
	if totalStages == 0 then totalStages = Config.Stages.Count end
	
	-- Give Stage Clear bonus and Stage Reward for the LAST stage (not given in onStageComplete)
	if totalStages > 0 then
		-- Stage Clear bonus for last stage
		self.currencyManager:addCurrency(player, Config.Currency.PerStage)
		
		-- Stage Reward for last stage
		local lastStageNum = stageOrder[totalStages]
		local lastStageReward = Config.Currency.StageRewards[lastStageNum] or 0
		if lastStageReward > 0 then
			self.currencyManager:addCurrency(player, lastStageReward)
			
			-- Track stage rewards total
			local roundStats = self.playerRoundStats[player]
			if roundStats then
				roundStats.stageRewardsTotal = (roundStats.stageRewardsTotal or 0) + lastStageReward
			end
		end
	end
	
	-- Give currency bonus for finishing
	self.currencyManager:addCurrency(player, Config.Currency.FinishBonus)

	local finishMasteryXP = (Config.Mastery and Config.Mastery.FinishBonusXP) or 0
	self:addMasteryXP(player, finishMasteryXP, "Finish")

	-- Calculate summary data
	local roundStats = self.playerRoundStats[player]
	local elapsedTime = os.clock() - (roundStats and roundStats.startTime or os.clock())
	local coinsCollected = roundStats and roundStats.coinsCollected or 0
	local stageRewardsTotal = roundStats and roundStats.stageRewardsTotal or 0

	-- Calculate stages cleared (all stages count now, including last one given in onPlayerFinished)
	local stagesCleared = totalStages

	-- Notify client with summary data
	self.stageCompleteRemote:FireClient(player, {
		finished = true,
		stageIndex = totalStages,
		totalStages = totalStages,
		summary = {
			-- Stats
			scoreEarned = self.scoreManager:getRoundScore(player),
			timeSpent = elapsedTime,
			-- Currency breakdown
			coinsCollected = coinsCollected, -- จำนวนเหรียญที่เก็บได้
			coinValue = Config.Currency.PerCoin, -- มูลค่าต่อเหรียญ
			stagesCleared = stagesCleared, -- จำนวนด่านที่ผ่าน
			stageValue = Config.Currency.PerStage, -- มูลค่าต่อด่าน (Stage Clear bonus)
			stageRewardsTotal = stageRewardsTotal, -- รางวัลตามด่านรวม
			finishBonus = Config.Currency.FinishBonus, -- โบนัสจบเกม
			totalCurrency = self.currencyManager:getCurrency(player),
			stageOrder = stageOrder, -- Stage ที่เลือกเล่น
		},
	})
	
	print("[GameManager]", player.Name, "FINISHED THE OBBY!")
	
	-- Teleport กลับ Lobby (หลังแสดง Summary 5 วินาที)
	task.delay(5, function()
		self:teleportToLobby(player)
		-- Clear teleporting flag after teleport
		task.delay(0.5, function()
			self.teleportingToLobby[player] = nil
		end)
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
	local startPos
	local matchId = self:getMatchIdForPlayer(player)
	if matchId then
		startPos = self.mapManager:getCheckpointPositionForMatch(matchId, 1)
	else
		startPos = self.mapManager:getCheckpointPosition(1)
	end
	
	if startPos then
		local character = player.Character
		if character then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart then
				humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
				humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
			-- Teleport และหันหน้าไปทาง +X (ไปทางซ้ายในด่าน)
			humanoidRootPart.CFrame = CFrame.lookAt(startPos, startPos + Vector3.new(1, 0, 0))
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
		local matchId = self:getMatchIdForPlayer(player)
		if matchId then
			checkpoint = self.mapManager:getCheckpointPositionForMatch(matchId, 1)
		else
			checkpoint = self.mapManager:getCheckpointPosition(1)
		end
	end
	
	if checkpoint then
		-- Reset velocity
		humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
		humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
		
		-- Teleport และหันหน้าไปทาง +Z (ไปข้างหน้าในด่าน)
		humanoidRootPart.CFrame = CFrame.lookAt(checkpoint, checkpoint + Vector3.new(0, 0, 1))
		
		print("[GameManager] Respawned", player.Name, "at checkpoint")
	end
	
	-- Notify client
	self.playerDiedRemote:FireClient(player)
end

-- Setup lobby
function GameManager:setupLobby()
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

-- Setup selection zone
function GameManager:setupSelectionZone()
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then return end
	
	local selectionZone = lobby:FindFirstChild("SelectionZone")
	if not selectionZone then return end
	
	-- ใช้ loop ตรวจสอบตำแหน่งผู้เล่นแทน Touched events (เสถียรกว่า)
	
	-- Add "Select Stage" Label
	if not selectionZone:FindFirstChild("StageLabelBillboard") then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "StageLabelBillboard"
		billboard.Size = UDim2.new(0, 200, 0, 50)
		billboard.StudsOffset = Vector3.new(0, 5, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = selectionZone
		
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = "SELECT STAGE"
		label.TextColor3 = Color3.fromRGB(100, 200, 255)
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
		label.TextSize = 24
		label.Font = Enum.Font.GothamBold
		label.Parent = billboard
	end
	
	task.spawn(function()
		while true do
			task.wait(0.2) -- ตรวจสอบทุก 0.2 วินาที
			
			for _, player in ipairs(Players:GetPlayers()) do
				local isInZone = self:isPlayerInSelectionZone(player, selectionZone)
				local wasInZone = self.playersInSelectionZone[player]
				
				if isInZone and not wasInZone then
					-- เพิ่งเข้า zone
					if self.playerStates[player] == "Lobby" then
						self.playersInSelectionZone[player] = true
						self:onPlayerEnterSelectionZone(player)
					end
				elseif not isInZone and wasInZone then
					-- เพิ่งออกจาก zone
					self.playersInSelectionZone[player] = nil
					self:onPlayerLeaveSelectionZone(player)
				end
			end
		end
	end)
end

-- ตรวจสอบว่าผู้เล่นอยู่ใน selection zone หรือไม่
function GameManager:isPlayerInSelectionZone(player: Player, zone: Part): boolean
	local character = player.Character
	if not character then return false end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return false end
	
	local playerPos = humanoidRootPart.Position
	local zonePos = zone.Position
	local zoneSize = zone.Size
	
	-- ตรวจสอบว่าอยู่ใน bounding box ของ zone
	local halfSize = zoneSize / 2
	local minBound = zonePos - halfSize
	local maxBound = zonePos + halfSize
	
	return playerPos.X >= minBound.X and playerPos.X <= maxBound.X
		and playerPos.Y >= minBound.Y - 5 and playerPos.Y <= maxBound.Y + 10 -- เผื่อความสูง
		and playerPos.Z >= minBound.Z and playerPos.Z <= maxBound.Z
end

-- Player entered selection zone
function GameManager:onPlayerEnterSelectionZone(player: Player)
	-- Show stage selection UI
	self.showStageSelectionRemote:FireClient(player)
	print("[GameManager]", player.Name, "entered selection zone")
end

-- Player left selection zone
function GameManager:onPlayerLeaveSelectionZone(player: Player)
	-- Hide stage selection UI
	self.hideStageSelectionRemote:FireClient(player)
	print("[GameManager]", player.Name, "left selection zone")
end

-- Validate stage order from client input
function GameManager:validateStageOrder(stageOrder: any): {number}?
	if type(stageOrder) ~= "table" then return nil end
	if #stageOrder == 0 or #stageOrder > Config.Stages.Count then return nil end

	local seen = {}
	for _, stageNum in ipairs(stageOrder) do
		if type(stageNum) ~= "number" then return nil end
		stageNum = math.floor(stageNum)
		if stageNum < 1 or stageNum > Config.Stages.Count then return nil end
		if seen[stageNum] then return nil end -- duplicate
		seen[stageNum] = true
	end

	return stageOrder
end

-- Stage selection confirmed
function GameManager:onStageSelectionConfirmed(player: Player, data: any)
	local state = self.playerStates[player]
	if state ~= "Lobby" then return end

	-- Validate client input
	if type(data) ~= "table" then
		warn("[GameManager] Invalid data from", player.Name)
		return
	end

	local stageOrder: {number}

	if data.isRandom == true then
		-- Random order
		stageOrder = self.mapManager:shuffleStages()
	elseif data.stageOrder then
		-- Custom order - validate
		local validated = self:validateStageOrder(data.stageOrder)
		if not validated then
			warn("[GameManager] Invalid stageOrder from", player.Name)
			return
		end
		stageOrder = validated
	else
		-- Default: use current map order
		stageOrder = self.mapManager.stageOrder
	end
	
	-- Hide UI
	self.hideStageSelectionRemote:FireClient(player)
	
	-- Start countdown and game
	self:startGameWithOrder(player, stageOrder)
end

-- Start game with specific stage order
-- Uses per-match instanced maps for multiplayer support
function GameManager:startGameWithOrder(player: Player, stageOrder: {number})
	-- Check if player is in a match room
	local matchRoom = self.matchManager:getPlayerRoom(player)
	local matchId: string?
	
	if matchRoom then
		-- Player is in a match - use per-match instanced map
		matchId = matchRoom.id
		self.playerMatchIds[player] = matchId
		
		-- Set the stage order in MatchManager
		self.matchManager:setStageOrderForMatch(matchId, stageOrder)
		
		-- Generate instanced map for this match
		self.mapManager:generateMapForMatch(matchId, stageOrder)
		
		-- Setup map elements for this match
		self:setupKillPartsForMatch(matchId)
		self:setupFinishLineForMatch(matchId)
		
		local pickups = self.mapManager:getAllItemPickupsForMatch(matchId)
		self.itemManager:setupItemPickups(pickups)
	else
		-- Solo play - use global map (backwards compatibility)
		self.playerMatchIds[player] = nil
		self.mapManager:generateMapWithOrder(stageOrder)
		
		-- Setup map elements
		self:setupKillParts()
		self:setupFinishLine()
		
		local pickups = self.mapManager:getAllItemPickups()
		self.itemManager:setupItemPickups(pickups)
	end
	
	-- Start countdown
	self:startCountdown(player, 3, stageOrder)
end

-- Start countdown (with stageOrder parameter for total stages)
function GameManager:startCountdown(player: Player, seconds: number, stageOrder: {number}?)
	-- Get dynamic total stages
	local totalStages = stageOrder and #stageOrder or #self.mapManager.stageOrder
	if totalStages == 0 then totalStages = Config.Stages.Count end
	
	for i = seconds, 1, -1 do
		self.countdownUpdateRemote:FireClient(player, {
			number = i,
			message = if i > 1 then "Starting..." else "GO!",
			totalStages = totalStages,
		})
		task.wait(1)
	end
	
	-- Teleport to first stage
	self:startGameForPlayer(player)
end

-- Start game for player
function GameManager:startGameForPlayer(player: Player)
	local state = self.playerStates[player]
	-- Only allow starting from Lobby (or if called from countdown, state might already be set)
	if state == "Finished" then return end
	
	-- Set to Playing if not already
	if state ~= "Playing" then
		self.playerStates[player] = "Playing"
	end
	
	-- Reset scores
	self.scoreManager:resetRoundScore(player)
	self.itemManager:resetPlayer(player)
	
	-- Initialize round stats for summary
	self.playerRoundStats[player] = {
		startTime = os.clock(),
		coinsCollected = 0,
		stageRewardsTotal = 0,
	}
	
	-- Clear checkpoint
	self.playerCheckpoints[player] = nil
	
	-- Teleport to first stage
	local startPos
	local matchId = self:getMatchIdForPlayer(player)
	if matchId then
		startPos = self.mapManager:getCheckpointPositionForMatch(matchId, 1)
	else
		startPos = self.mapManager:getCheckpointPosition(1)
	end
	
	if startPos then
		local character = player.Character
		if character then
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart then
				-- Reset velocity
				humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
				humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
			-- Teleport และหันหน้าไปทาง +X (ไปทางซ้ายในด่าน)
			humanoidRootPart.CFrame = CFrame.lookAt(startPos, startPos + Vector3.new(1, 0, 0))
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
	
	-- Clear match ID (player leaves match when returning to lobby)
	local matchId = self.playerMatchIds[player]
	self.playerMatchIds[player] = nil

	-- Use Config position directly for more reliable teleport
	local targetPosition = Config.Lobby.SpawnPosition
	print("[GameManager] Teleporting", player.Name, "to lobby at:", targetPosition)

	local character = player.Character
	if character then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			-- Reset velocity
			humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
			humanoidRootPart.AssemblyAngularVelocity = Vector3.zero

			-- Teleport to Config position
			humanoidRootPart.CFrame = CFrame.new(targetPosition + Vector3.new(0, 3, 0))
			print("[GameManager] Teleport successful for", player.Name)
		else
			warn("[GameManager] Could not find HumanoidRootPart for", player.Name)
		end
	else
		warn("[GameManager] Could not find character for", player.Name)
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

-- Add coin collected (called by ItemManager)
function GameManager:addCoinCollected(player: Player)
	local roundStats = self.playerRoundStats[player]
	if roundStats then
		roundStats.coinsCollected = roundStats.coinsCollected + 1
		print("[GameManager]", player.Name, "collected coin - Total:", roundStats.coinsCollected)
	end
end

-- ============================================
-- PER-MATCH MAP SETUP FUNCTIONS
-- ============================================

-- Setup finish line touch detection for a specific match
function GameManager:setupFinishLineForMatch(matchId: string)
	local matchData = self.mapManager:getMatchMapData(matchId)
	if not matchData then return end
	
	local lastStage = matchData.stages[#matchData.stages]
	if lastStage then
		local endPart = lastStage:FindFirstChild("EndPart")
		if endPart then
			-- เพิ่ม touch detection
			endPart.Touched:Connect(function(hit)
				local humanoid = hit.Parent:FindFirstChild("Humanoid")
				if humanoid then
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					-- Check if this player belongs to this match
					if player and self.playerStates[player] == "Playing" and self.playerMatchIds[player] == matchId then
						self:onPlayerFinished(player)
					end
				end
			end)
			
			-- เปลี่ยนสี EndPart ให้เด่นชัด (เส้นชัย)
			endPart.Color = Color3.fromRGB(0, 255, 100)
			endPart.Material = Enum.Material.Neon
			
			print("[GameManager] Finish line setup for match:", matchId, "at:", endPart.Position)
		end
	end
end

-- Setup kill parts for a specific match
function GameManager:setupKillPartsForMatch(matchId: string)
	local killParts = self.mapManager:getAllKillPartsForMatch(matchId)
	
	for _, part in ipairs(killParts) do
		part.Touched:Connect(function(hit)
			local humanoid = hit.Parent:FindFirstChild("Humanoid")
			if humanoid then
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				-- Check if this player belongs to this match
				if player and self.playerStates[player] == "Playing" and self.playerMatchIds[player] == matchId then
					self:respawnPlayer(player)
				end
			end
		end)
	end
end

-- Get match ID for player (public accessor)
function GameManager:getPlayerMatchId(player: Player): string?
	return self.playerMatchIds[player]
end

return GameManager
