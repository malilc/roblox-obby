-- GameManager: ควบคุมการทำงานของเกมทั้งหมด

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapManager = require(script.Parent.MapManager)
local StageTracker = require(script.Parent.StageTracker)
local ItemManager = require(script.Parent.ItemManager)
local CurrencyManager = require(script.Parent.CurrencyManager)
local MatchManager = require(script.Parent.MatchManager)
local ClassManager = require(script.Parent.ClassManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local SpectatorManager = require(script.Parent.SpectatorManager)
local SelectionZoneManager = require(script.Parent.SelectionZoneManager)
local ShopZoneManager = require(script.Parent.ShopZoneManager)
local ShopManager = require(script.Parent.ShopManager)
local FeedbackManager = require(script.Parent.FeedbackManager)
local Config = require(ReplicatedStorage.Shared.Config)
local StageInfo = require(ReplicatedStorage.Shared.StageInfo)
local Logger = require(ReplicatedStorage.Shared.Logger)

local GameManager = {}
GameManager.__index = GameManager

export type PlayerState = "Lobby" | "Playing" | "Finished" | "Spectating"

function GameManager.new()
	local self = setmetatable({}, GameManager)
	
	-- Managers
	self.mapManager = MapManager.new()
	self.currencyManager = CurrencyManager.new()
	self.stageTracker = StageTracker.new()
	self.matchManager = MatchManager.new(self) -- Pass GameManager to MatchManager (create before ItemManager)
	self.leaderboardManager = LeaderboardManager.new()
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

	-- Debug: solo wins flag per player
	self.soloWinsEnabled = {} :: {[Player]: boolean}
	
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
	self.returnToLobbyRemote = ReplicatedStorage.Remotes.ReturnToLobby
	self.showShopRemote = ReplicatedStorage.Remotes.ShowShop
	self.hideShopRemote = ReplicatedStorage.Remotes.HideShop
	
	-- Spectator Manager
	self.spectatorManager = SpectatorManager.new({
		getPlayerState = function(player) return self.playerStates[player] end,
		setPlayerState = function(player, state) self.playerStates[player] = state end,
		teleportToLobby = function(player) self:teleportToLobby(player) end,
		setTeleportingFlag = function(player, value) self.teleportingToLobby[player] = value end,
		getTeleportFlagClearDelay = function() return Config.Timing.TeleportFlagClearDelay end,
	})

	-- Selection Zone Manager
	self.selectionZoneManager = SelectionZoneManager.new({
		getPlayerState = function(player) return self.playerStates[player] end,
		mapManager = self.mapManager,
		showStageSelectionRemote = self.showStageSelectionRemote,
		hideStageSelectionRemote = self.hideStageSelectionRemote,
		startGameWithOrder = function(player, stageOrder) self:startGameWithOrder(player, stageOrder) end,
		createMatchRoom = function(player, stageOrder) self:createMatchRoom(player, stageOrder) end,
		getAnyActiveRoom = function() return self.matchManager:getAnyActiveRoom() end,
		joinMatchRoom = function(player, roomId) self:joinMatchRoom(player, roomId) end,
		spectateMatchRoom = function(player) self:spectateMatchRoom(player) end,
	})

	-- Shop Zone Manager
	self.shopZoneManager = ShopZoneManager.new({
		getPlayerState = function(player) return self.playerStates[player] end,
		showShopRemote = self.showShopRemote,
		hideShopRemote = self.hideShopRemote,
	})

	-- Shop Manager (purchases + gacha)
	self.shopManager = ShopManager.new(self.currencyManager, self.itemManager, self.classManager, self)

	-- Feedback Manager (Discord webhook)
	self.feedbackManager = FeedbackManager.new()

	-- Player event connections (for cleanup on leave)
	self.playerConnections = {} :: {[Player]: {RBXScriptConnection}}
	self.playerDiedConnections = {} :: {[Player]: RBXScriptConnection?}

	-- Map touch connections (for cleanup on map regenerate)
	self.mapConnections = {} :: {RBXScriptConnection}
	self.matchConnections = {} :: {[string]: {RBXScriptConnection}}

	-- Setup
	self:setupRemotes()
	self:setupPlayerEvents()
	self:setupLobby()
	self.selectionZoneManager:setup()
	self.shopZoneManager:setup()

	-- ไม่สร้าง map ตอนเริ่ม - จะสร้างเมื่อผู้เล่นเลือกด่าน
	-- self:generateNewMap()
	
	return self
end

function GameManager:canPlayerChangeClass(player: Player): boolean
	return self.playerStates[player] == "Lobby"
end

-- Setup leaderstats (Gems, Wins, Currency)
function GameManager:setupLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local gems = Instance.new("IntValue")
	gems.Name = "Gems"
	gems.Value = 0
	gems.Parent = leaderstats

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = 0
	wins.Parent = leaderstats

	local currency = Instance.new("IntValue")
	currency.Name = "Currency"
	currency.Value = 0
	currency.Parent = leaderstats

	-- Update values after data loads
	task.spawn(function()
		task.wait(Config.Timing.LeaderstatsLoadDelay)
		if player.Parent then
			gems.Value = self.currencyManager:getGems(player)
			wins.Value = self.currencyManager:getWins(player)
			currency.Value = self.currencyManager:getCurrency(player)
		end
	end)
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
	
	-- Confirm stage selection (delegated to SelectionZoneManager)
	self.confirmStageSelectionRemote.OnServerEvent:Connect(function(player, data)
		self.selectionZoneManager:onStageSelectionConfirmed(player, data)
	end)

	-- Spectator system (delegated to SpectatorManager)
	local spectateRemote = ReplicatedStorage.Remotes:FindFirstChild("SpectateMatch")
	if spectateRemote then
		spectateRemote.OnServerEvent:Connect(function(player)
			self.spectatorManager:onPlayerSpectate(player)
		end)
	end

	local spectatorLeaveRemote = ReplicatedStorage.Remotes:FindFirstChild("SpectatorLeave")
	if spectatorLeaveRemote then
		spectatorLeaveRemote.OnServerEvent:Connect(function(player)
			self.spectatorManager:onSpectatorLeave(player)
		end)
	end

	-- Debug: toggle solo wins
	if Config.Debug and Config.Debug.Enabled then
		local toggleSoloWins = ReplicatedStorage.Remotes:FindFirstChild("ToggleSoloWins")
		if toggleSoloWins then
			toggleSoloWins.OnServerEvent:Connect(function(player, enabled)
				self.soloWinsEnabled[player] = enabled == true
				Logger.debug("GameManager", player.Name, "solo wins:", tostring(self.soloWinsEnabled[player]))
			end)
		end
	end
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
	self.stageTracker:initPlayer(player)
	self.currencyManager:initPlayer(player)
	self.itemManager:initPlayer(player)
	self.classManager:initPlayer(player)

	-- Setup leaderstats
	self:setupLeaderstats(player)

	-- Check game passes on join (so benefits work immediately)
	task.spawn(function()
		self.shopManager:checkAllGamePasses(player)
		self.shopManager:sendGamePassUpdate(player)
	end)

	-- Send cached leaderboard to new player
	task.delay(Config.Timing.LeaderboardSendDelay, function()
		if player.Parent then
			self.leaderboardManager:sendToPlayer(player)
		end
	end)

	-- Wait for character (store connection for cleanup)
	local charConn = player.CharacterAdded:Connect(function(character)
		self:onCharacterAdded(player, character)
	end)
	table.insert(self.playerConnections[player], charConn)

	-- Handle existing character
	if player.Character then
		self:onCharacterAdded(player, player.Character)
	end

	Logger.debug("GameManager", "Player joined:", player.Name)
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
	self.selectionZoneManager:removePlayer(player)
	self.shopZoneManager:removePlayer(player)
	self.shopManager:removePlayer(player)
	self.teleportingToLobby[player] = nil
	self.soloWinsEnabled[player] = nil
	self.playerRoundStats[player] = nil

	self.stageTracker:removePlayer(player)
	self.currencyManager:removePlayer(player)
	self.itemManager:removePlayer(player)
	self.matchManager:removePlayer(player)
	self.classManager:removePlayer(player)

	Logger.debug("GameManager", "Player left:", player.Name)
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
	task.wait(Config.Timing.CharacterSetupDelay) -- Wait for character to fully load
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart then
		self:setupCharacterTouchEvents(player, humanoidRootPart)
	end

	if self.currencyManager and self.currencyManager.applyActiveTitleToCharacter then
		self.currencyManager:applyActiveTitleToCharacter(player, character)
	end

	-- Apply VIP visual effects
	self:applyVIPEffects(player, character)
end

-- VIP visual effects: badge, golden glow, chat tag
function GameManager:applyVIPEffects(player: Player, character: Model)
	-- Clean up previous VIP effects
	self:removeVIPEffects(character)

	local isVIP = self.shopManager and self.shopManager:hasGamePass(player, "VIP")
	player:SetAttribute("IsVIP", isVIP == true)

	if not isVIP then return end

	local head = character:FindFirstChild("Head")

	-- 1. VIP Badge (BillboardGui above title)
	if head then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "VIPBadgeBillboard"
		billboard.Size = UDim2.new(0, 100, 0, 22)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.8, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 80
		billboard.Parent = head

		local container = Instance.new("Frame")
		container.Name = "Container"
		container.Size = UDim2.new(1, 0, 1, 0)
		container.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
		container.BackgroundTransparency = 0.15
		container.BorderSizePixel = 0
		container.Parent = billboard

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = container

		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 80)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 170, 40)),
		})
		gradient.Rotation = 90
		gradient.Parent = container

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(180, 140, 30)
		stroke.Thickness = 1.5
		stroke.Transparency = 0.1
		stroke.Parent = container

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = "\u{2B50} VIP"
		label.TextColor3 = Color3.fromRGB(60, 40, 0)
		label.TextStrokeTransparency = 0.6
		label.TextStrokeColor3 = Color3.fromRGB(255, 255, 200)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.Parent = container
	end

	Logger.debug("GameManager", "VIP effects applied to", player.Name)
end

function GameManager:removeVIPEffects(character: Model)
	if not character then return end

	-- Remove badge
	local head = character:FindFirstChild("Head")
	if head then
		local badge = head:FindFirstChild("VIPBadgeBillboard")
		if badge then badge:Destroy() end
	end

end

-- Setup touch events for character
function GameManager:setupCharacterTouchEvents(player: Player, rootPart: Part)
	-- Monitor position for stage completion
	task.spawn(function()
		while player.Character and player.Character:FindFirstChild("HumanoidRootPart") do
			self:checkPlayerPosition(player)
			task.wait(Config.Timing.PositionCheckInterval)
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
			local playerCurrentStage = self.stageTracker:getCurrentStage(player)
			
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
			local playerCurrentStage = self.stageTracker:getCurrentStage(player)
			
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

function GameManager:getCoinMultiplier(player: Player): number
	local multiplier = 1
	if self.shopManager then
		if self.shopManager:hasGamePass(player, "DoubleCoin") then
			multiplier = multiplier + 1 -- +1.0 = ×2
		end
		if self.shopManager:hasGamePass(player, "VIP") then
			multiplier = multiplier + 0.5 -- +0.5 = ×1.5
		end
	end
	return multiplier
end

function GameManager:getXPMultiplier(player: Player): number
	local multiplier = 1
	if self.shopManager then
		if self.shopManager:hasGamePass(player, "DoubleXP") then
			multiplier = multiplier + 1 -- +1.0 = ×2
		end
		if self.shopManager:hasGamePass(player, "VIP") then
			multiplier = multiplier + 0.5 -- +0.5 = ×1.5
		end
	end
	return multiplier
end

function GameManager:addMasteryXP(player: Player, amount: number, reason: string)
	if amount <= 0 then return end
	if not self.currencyManager or not self.classManager then return end

	local classId = self.classManager:getPlayerClass(player)
	if not classId then return end

	local xpMultiplier = self:getXPMultiplier(player)
	local finalAmount = math.floor(amount * xpMultiplier)
	self.currencyManager:addMasteryXP(player, classId, finalAmount, reason)
end

-- On stage complete
function GameManager:onStageComplete(player: Player, stageIndex: number)
	local advanced = self.stageTracker:advanceStage(player, stageIndex)
	if not advanced then return end

	-- Get stage order based on player's match
	local matchId = self:getMatchIdForPlayer(player)
	local stageOrder = if matchId 
		then self.mapManager:getStageOrderForMatch(matchId) 
		else self.mapManager.globalMap.stageOrder

	-- Give currency for completing stage (except stage 1 start)
	if stageIndex > 1 then
		local coinMultiplier = self:getCoinMultiplier(player)

		-- Stage Clear bonus (คงที่)
		self.currencyManager:addCurrency(player, Config.Currency.PerStage * coinMultiplier)

		local stageMasteryXP = (Config.Mastery and Config.Mastery.PerStageXP) or 0
		self:addMasteryXP(player, stageMasteryXP, "StageComplete")

		-- Stage Reward (ตามด่านที่ผ่าน)
		local completedStageNum = stageOrder[stageIndex - 1] -- ด่านที่เพิ่งผ่าน
		local stageData = StageInfo.getStage(completedStageNum)
		local stageReward = if stageData then stageData.reward else 0
		if stageReward > 0 then
			self.currencyManager:addCurrency(player, stageReward * coinMultiplier)
			
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
	if totalStages == 0 then totalStages = Config.Stages.SelectionCount end

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
	
	Logger.debug("GameManager", player.Name, if stageIndex == 1 then "started stage 1" else "completed stage " .. (stageIndex - 1))
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

	-- Get stage order based on player's match
	local matchId = self:getMatchIdForPlayer(player)
	local stageOrder = if matchId
		then self.mapManager:getStageOrderForMatch(matchId)
		else self.mapManager.globalMap.stageOrder

	-- Get dynamic total stages
	local totalStages = #stageOrder
	if totalStages == 0 then totalStages = Config.Stages.SelectionCount end

	-- Coin multiplier for DoubleCoin gamepass
	local coinMultiplier = self:getCoinMultiplier(player)

	-- Give Stage Clear bonus and Stage Reward for the LAST stage (not given in onStageComplete)
	if totalStages > 0 then
		-- Stage Clear bonus for last stage
		self.currencyManager:addCurrency(player, Config.Currency.PerStage * coinMultiplier)

		-- Stage Reward for last stage
		local lastStageNum = stageOrder[totalStages]
		local lastStageData = StageInfo.getStage(lastStageNum)
		local lastStageReward = if lastStageData then lastStageData.reward else 0
		if lastStageReward > 0 then
			self.currencyManager:addCurrency(player, lastStageReward * coinMultiplier)

			-- Track stage rewards total
			local roundStats = self.playerRoundStats[player]
			if roundStats then
				roundStats.stageRewardsTotal = (roundStats.stageRewardsTotal or 0) + lastStageReward
			end
		end
	end

	-- Give currency bonus for finishing
	self.currencyManager:addCurrency(player, Config.Currency.FinishBonus * coinMultiplier)

	local finishMasteryXP = (Config.Mastery and Config.Mastery.FinishBonusXP) or 0
	self:addMasteryXP(player, finishMasteryXP, "Finish")

	-- Award gems for finishing race
	local gemsConfig = Config.Gems or {}
	self.currencyManager:addGems(player, gemsConfig.FinishRace or 1, "FinishRace")

	-- Check finish position for top 30% bonus and win
	local matchRoom = self.matchManager:getPlayerRoom(player)
	local isTop30 = false
	local isWin = false
	local finishPosition = 0
	local totalPlayers = 1

	if matchRoom and #matchRoom.players > 1 then
		for i, p in ipairs(matchRoom.finishOrder) do
			if p == player then
				finishPosition = i
				break
			end
		end
		totalPlayers = #matchRoom.players

		-- Win = 1st place
		if finishPosition == 1 then
			isWin = true
			self.currencyManager:addWin(player)
		end
	else
		-- Solo play: always 1st of 1
		finishPosition = 1
		totalPlayers = 1

		if self.soloWinsEnabled[player] then
			-- Debug: solo wins mode — treat finish as a win
			isWin = true
			self.currencyManager:addWin(player)

			-- Top 30% bonus (denominator = all players in match)
			local cutoff = math.max(1, math.ceil(totalPlayers * 0.30))
			isTop30 = finishPosition <= cutoff
			if isTop30 then
				self.currencyManager:addGems(player, gemsConfig.Top30Bonus or 5, "Top30Bonus")
			end
		end
	end

	-- Calculate summary data
	local roundStats = self.playerRoundStats[player]
	local elapsedTime = os.clock() - (roundStats and roundStats.startTime or os.clock())
	local coinsCollected = roundStats and roundStats.coinsCollected or 0
	local stageRewardsTotal = roundStats and roundStats.stageRewardsTotal or 0

	-- Calculate stages cleared (all stages count now, including last one given in onPlayerFinished)
	local stagesCleared = totalStages

	-- Check if player is in an active match (for spectator support)
	local canSpectate = matchRoom ~= nil and matchRoom.state == "Racing"

	-- Calculate gems earned this round
	local gemsEarned = (gemsConfig.FinishRace or 1) + (if isTop30 then (gemsConfig.Top30Bonus or 5) else 0)

	-- Calculate actual earned (server-authoritative delta)
	local currentCurrency = self.currencyManager:getCurrency(player)
	local startCurrency = roundStats and roundStats.startCurrency or currentCurrency
	local totalEarned = currentCurrency - startCurrency

	-- XP multiplier info
	local xpMultiplier = self:getXPMultiplier(player)

	-- Gamepass upsell (show purchase buttons for passes the player doesn't own)
	local gamePassUpsell = {}
	if not self.shopManager:hasGamePass(player, "DoubleCoin") and Config.GamePasses.DoubleCoin then
		gamePassUpsell.doubleCoin = Config.GamePasses.DoubleCoin.gamePassId
	end
	if not self.shopManager:hasGamePass(player, "ExtraSlot") and Config.GamePasses.ExtraSlot then
		gamePassUpsell.extraSlot = Config.GamePasses.ExtraSlot.gamePassId
	end
	if not self.shopManager:hasGamePass(player, "VIP") and Config.GamePasses.VIP then
		gamePassUpsell.vip = Config.GamePasses.VIP.gamePassId
	end
	if not self.shopManager:hasGamePass(player, "DoubleXP") and Config.GamePasses.DoubleXP then
		local passId = Config.GamePasses.DoubleXP.gamePassId
		if passId and passId ~= 0 then
			gamePassUpsell.doubleXP = passId
		end
	end

	-- Notify client with summary data
	self.stageCompleteRemote:FireClient(player, {
		finished = true,
		stageIndex = totalStages,
		totalStages = totalStages,
		summary = {
			-- Gems & Wins
			gemsEarned = gemsEarned,
			gemsTotal = self.currencyManager:getGems(player),
			isTop30 = isTop30,
			isWin = isWin,
			finishPosition = finishPosition,
			totalRacers = totalPlayers,
			winsTotal = self.currencyManager:getWins(player),
			timeSpent = elapsedTime,
			-- Currency breakdown
			coinsCollected = coinsCollected,
			coinValue = Config.Currency.PerCoin * coinMultiplier,
			stagesCleared = stagesCleared,
			stageValue = Config.Currency.PerStage * coinMultiplier,
			stageRewardsTotal = stageRewardsTotal * coinMultiplier,
			finishBonus = Config.Currency.FinishBonus * coinMultiplier,
			isDoubleCoin = coinMultiplier > 1,
			coinMultiplier = coinMultiplier,
			xpMultiplier = xpMultiplier,
			totalEarned = totalEarned,
			totalCurrency = currentCurrency,
			stageOrder = stageOrder,
			canSpectate = canSpectate,
			gamePassUpsell = gamePassUpsell,
		},
	})

	-- Update global leaderboards (gems + wins)
	local totalGems = self.currencyManager:getGems(player)
	if totalGems and totalGems > 0 then
		self.leaderboardManager:updateGems(player, totalGems)
	end
	local totalWins = self.currencyManager:getWins(player)
	if totalWins and totalWins > 0 then
		self.leaderboardManager:updateWins(player, totalWins)
	end

	Logger.debug("GameManager", player.Name, "FINISHED THE OBBY!")

	if canSpectate then
		-- Match still racing: don't auto-teleport, let client choose spectate or leave
		Logger.debug("GameManager", player.Name, "can spectate - waiting for client decision")
	else
		-- Solo or match already finished: auto-teleport after 5 seconds
		task.delay(Config.Timing.AutoTeleportDelay, function()
			if not player.Parent then return end -- Player left the game
			if self.playerStates[player] == "Finished" then
				self:teleportToLobby(player)
				task.delay(Config.Timing.TeleportFlagClearDelay, function()
					self.teleportingToLobby[player] = nil
				end)
			end
		end)
	end
end

-- Teleport กลับจุดเริ่มต้น (Stage 1)
function GameManager:teleportToStart(player: Player)
	self.playerStates[player] = "Playing"
	
	-- Reset scores for new round
	self.stageTracker:resetRound(player)
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
	
	Logger.debug("GameManager", player.Name, "teleported back to start!")
end

-- On player died
function GameManager:onPlayerDied(player: Player)
	local state = self.playerStates[player]
	if state ~= "Playing" then return end
	
	Logger.debug("GameManager", player.Name, "died")
	
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

		-- Clear stun state ป้องกัน WalkSpeed=0 ค้าง
		if character:GetAttribute("IsPunchStunned") then
			character:SetAttribute("IsPunchStunned", false)
			local baseWalk = character:GetAttribute("PreStunWalkSpeed") or character:GetAttribute("BaseWalkSpeed") or 16
			local baseJump = character:GetAttribute("PreStunJumpPower") or character:GetAttribute("BaseJumpPower") or 50
			humanoid.WalkSpeed = baseWalk
			humanoid.JumpPower = baseJump
			character:SetAttribute("PreStunWalkSpeed", nil)
			character:SetAttribute("PreStunJumpPower", nil)
			-- ลบ stun visual ถ้ามี
			local stunVisual = humanoidRootPart:FindFirstChild("PunchStunVisual")
			if stunVisual then stunVisual:Destroy() end
		end

		-- Teleport และหันหน้าไปทาง +X (ไปข้างหน้าในด่าน)
		humanoidRootPart.CFrame = CFrame.lookAt(checkpoint, checkpoint + Vector3.new(1, 0, 0))

		Logger.debug("GameManager", "Respawned", player.Name, "at checkpoint")
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
	local totalStages = stageOrder and #stageOrder or #self.mapManager.globalMap.stageOrder
	if totalStages == 0 then totalStages = Config.Stages.SelectionCount end

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
	self.stageTracker:resetRound(player)
	self.itemManager:resetPlayer(player)
	
	-- Initialize round stats for summary
	self.playerRoundStats[player] = {
		startTime = os.clock(),
		coinsCollected = 0,
		stageRewardsTotal = 0,
		startCurrency = self.currencyManager:getCurrency(player),
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
	
	Logger.debug("GameManager", player.Name, "started the obby!")
end

-- Teleport to lobby
function GameManager:teleportToLobby(player: Player)
	self.playerStates[player] = "Lobby"

	-- Reset scores for next round
	self.stageTracker:resetRound(player)
	self.itemManager:resetPlayer(player)

	-- Clear checkpoint
	self.playerCheckpoints[player] = nil
	
	-- Clear match ID and room mapping (player leaves match when returning to lobby)
	local matchId = self.playerMatchIds[player]
	self.playerMatchIds[player] = nil
	self.matchManager.playerRooms[player] = nil

	-- Use Config position directly for more reliable teleport
	local targetPosition = Config.Lobby.SpawnPosition
	Logger.debug("GameManager", "Teleporting", player.Name, "to lobby at:", targetPosition)

	local character = player.Character
	if character then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			-- Reset velocity
			humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
			humanoidRootPart.AssemblyAngularVelocity = Vector3.zero

			-- Teleport to Config position หันหน้าไปทาง SelectionZone (+Z)
			local spawnPos = targetPosition + Vector3.new(0, 3, 0)
			humanoidRootPart.CFrame = CFrame.lookAt(spawnPos, spawnPos + Vector3.new(0, 0, 1))
			Logger.debug("GameManager", "Teleport successful for", player.Name)
		else
			Logger.warn("GameManager", "Could not find HumanoidRootPart for", player.Name)
		end
	else
		Logger.warn("GameManager", "Could not find character for", player.Name)
	end

	-- Notify client to snap camera toward SelectionZone
	self.returnToLobbyRemote:FireClient(player)

	Logger.debug("GameManager", player.Name, "returned to lobby")
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
	
	Logger.info("GameManager", "New map generated!")
	Logger.info("GameManager", "Stage order:", table.concat(self.mapManager.globalMap.stageOrder, ", "))
end

-- Disconnect all map touch connections (called before map regenerate)
function GameManager:disconnectMapConnections()
	for _, conn in ipairs(self.mapConnections) do
		conn:Disconnect()
	end
	self.mapConnections = {}
end

-- Disconnect match-specific touch connections
function GameManager:disconnectMatchConnections(matchId: string)
	local conns = self.matchConnections[matchId]
	if conns then
		for _, conn in ipairs(conns) do
			conn:Disconnect()
		end
		self.matchConnections[matchId] = nil
	end
end

-- Setup finish line touch detection
function GameManager:setupFinishLine()
	local finishPos = self.mapManager:getFinishLinePosition()
	if not finishPos then return end
	
	-- หา EndPart ของ stage สุดท้าย
	local lastStage = self.mapManager.globalMap.stages[#self.mapManager.globalMap.stages]
	if lastStage then
		local endPart = lastStage:FindFirstChild("EndPart")
		if endPart then
			-- เพิ่ม touch detection
			local conn = endPart.Touched:Connect(function(hit)
				local humanoid = hit.Parent:FindFirstChild("Humanoid")
				if humanoid then
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if player and self.playerStates[player] == "Playing" then
						self:onPlayerFinished(player)
					end
				end
			end)
			table.insert(self.mapConnections, conn)

			-- เปลี่ยนสี EndPart ให้เด่นชัด (เส้นชัย)
			endPart.Color = Color3.fromRGB(0, 255, 100)
			endPart.Material = Enum.Material.SmoothPlastic

			Logger.info("GameManager", "Finish line setup at:", endPart.Position)
		end
	end
end

-- Setup kill parts
function GameManager:setupKillParts()
	local killParts = self.mapManager:getAllKillParts()
	
	for _, part in ipairs(killParts) do
		local conn = part.Touched:Connect(function(hit)
			local humanoid = hit.Parent:FindFirstChild("Humanoid")
			if humanoid then
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player and self.playerStates[player] == "Playing" then
					self:respawnPlayer(player)
				end
			end
		end)
		table.insert(self.mapConnections, conn)
	end
end

-- Regenerate map (for admin or periodic reset)
function GameManager:regenerateMap()
	-- Disconnect old map connections before regenerating
	self:disconnectMapConnections()

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
		Logger.debug("GameManager", player.Name, "collected coin - Total:", roundStats.coinsCollected)
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
			if not self.matchConnections[matchId] then
				self.matchConnections[matchId] = {}
			end
			local conn = endPart.Touched:Connect(function(hit)
				local humanoid = hit.Parent:FindFirstChild("Humanoid")
				if humanoid then
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					-- Check if this player belongs to this match
					if player and self.playerStates[player] == "Playing" and self.playerMatchIds[player] == matchId then
						self:onPlayerFinished(player)
					end
				end
			end)
			table.insert(self.matchConnections[matchId], conn)

			-- เปลี่ยนสี EndPart ให้เด่นชัด (เส้นชัย)
			endPart.Color = Color3.fromRGB(0, 255, 100)
			endPart.Material = Enum.Material.SmoothPlastic

			Logger.info("GameManager", "Finish line setup for match:", matchId, "at:", endPart.Position)
		end
	end
end

-- Setup kill parts for a specific match
function GameManager:setupKillPartsForMatch(matchId: string)
	local killParts = self.mapManager:getAllKillPartsForMatch(matchId)
	if not self.matchConnections[matchId] then
		self.matchConnections[matchId] = {}
	end

	for _, part in ipairs(killParts) do
		local conn = part.Touched:Connect(function(hit)
			local humanoid = hit.Parent:FindFirstChild("Humanoid")
			if humanoid then
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				-- Check if this player belongs to this match
				if player and self.playerStates[player] == "Playing" and self.playerMatchIds[player] == matchId then
					self:respawnPlayer(player)
				end
			end
		end)
		table.insert(self.matchConnections[matchId], conn)
	end
end

-- Get match ID for player (public accessor)
function GameManager:getPlayerMatchId(player: Player): string?
	return self.playerMatchIds[player]
end

-- ============================================
-- WAITING ROOM / MATCH GAME START
-- ============================================

-- Join an existing waiting room (auto-join when room exists)
function GameManager:joinMatchRoom(player: Player, roomId: string)
	if self.matchManager:isPlayerInMatch(player) then
		Logger.warn("GameManager", player.Name, "already in a room")
		return
	end

	local joined = self.matchManager:joinRoom(player, roomId)
	if joined then
		Logger.info("GameManager", player.Name, "auto-joined room", roomId)
	end
end

-- Enter spectator mode for a match in progress
function GameManager:spectateMatchRoom(player: Player)
	if self.playerStates[player] ~= "Lobby" then return end

	self.spectatorManager:onPlayerSpectate(player)
	Logger.info("GameManager", player.Name, "entered spectator mode from lobby")
end

-- Create a match room (waiting room) after stage selection
-- If a waiting room already exists, auto-join instead of creating
function GameManager:createMatchRoom(player: Player, stageOrder: {number})
	-- Check if player is already in a room
	if self.matchManager:isPlayerInMatch(player) then
		Logger.warn("GameManager", player.Name, "already in a room")
		return
	end

	-- Check if there's already a waiting room → join it instead
	local existingRoom = self.matchManager:getAnyActiveRoom()
	if existingRoom and existingRoom.state == "Waiting" then
		local joined = self.matchManager:joinRoom(player, existingRoom.id)
		if joined then
			-- Submit stage vote for the existing room
			self.matchManager:handleStageVote(player, stageOrder)
			Logger.info("GameManager", player.Name, "joined existing room", existingRoom.id)
		end
		return
	elseif existingRoom and (existingRoom.state == "Starting" or existingRoom.state == "Racing") then
		-- Match in progress, enter spectator mode
		self:spectateMatchRoom(player)
		return
	end

	-- No room exists, create a new one
	local roomId = self.matchManager:createRoom(player, {stageOrder = stageOrder})
	if roomId then
		-- Store the stage vote
		self.matchManager:handleStageVote(player, stageOrder)
		Logger.info("GameManager", player.Name, "created waiting room", roomId)
	end
end

-- Start the match for ALL players in a room (called by MatchManager when host starts)
function GameManager:startMatchGame(roomId: string, stageOrder: {number})
	local room = self.matchManager:getRoom(roomId)
	if not room or room.state ~= "Waiting" then return end

	local players = {}
	for _, p in ipairs(room.players) do
		table.insert(players, p)
	end

	-- Set match IDs for all players
	for _, player in ipairs(players) do
		self.playerMatchIds[player] = roomId
	end

	-- Set stage order and generate instanced map
	self.matchManager:setStageOrderForMatch(roomId, stageOrder)
	self.mapManager:generateMapForMatch(roomId, stageOrder)
	self:setupKillPartsForMatch(roomId)
	self:setupFinishLineForMatch(roomId)

	local pickups = self.mapManager:getAllItemPickupsForMatch(roomId)
	self.itemManager:setupItemPickups(pickups)

	-- Transition to Starting (fires MatchStart to clients = hides lobby UI)
	self.matchManager:startMatch(roomId)

	-- Countdown + start game for all players
	task.spawn(function()
		local totalStages = #stageOrder
		if totalStages == 0 then totalStages = Config.Stages.SelectionCount end

		-- 3-2-1 countdown
		for i = 3, 1, -1 do
			for _, player in ipairs(players) do
				if player.Parent then
					self.countdownUpdateRemote:FireClient(player, {
						number = i,
						message = if i > 1 then "Starting..." else "GO!",
						totalStages = totalStages,
					})
				end
			end
			task.wait(1)
		end

		-- Transition to Racing
		self.matchManager:beginRacing(roomId)

		-- Start game for all players
		for _, player in ipairs(players) do
			if player.Parent then
				self:startGameForPlayer(player)
			end
		end
	end)
end

return GameManager
