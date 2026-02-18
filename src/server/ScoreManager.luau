-- ScoreManager: จัดการคะแนนรอบและคะแนนถาวร

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Logger)

local ScoreManager = {}
ScoreManager.__index = ScoreManager

export type PlayerScoreData = {
	roundScore: number,
	currentStage: number,
	totalScore: number,
	highScore: number,
}

function ScoreManager.new(currencyManager: any?)
	local self = setmetatable({}, ScoreManager)
	
	self.playerData = {} :: {[Player]: PlayerScoreData}
	self.pendingSaves = {} :: {[Player]: boolean} -- Track players needing save
	self.currencyManager = currencyManager -- Reference to CurrencyManager
	
	-- DataStore
	pcall(function()
		self.dataStore = DataStoreService:GetDataStore(Config.DataStore.Name)
	end)
	
	-- Remotes
	self.updateScoreRemote = ReplicatedStorage.Remotes.UpdateScore
	
	-- Start auto-save loop
	self:startAutoSave()
	
	return self
end

-- Initialize player data
function ScoreManager:initPlayer(player: Player)
	self.playerData[player] = {
		roundScore = 0,
		currentStage = 0,
		totalScore = 0,
		highScore = 0,
	}
	
	-- Load from DataStore
	self:loadPlayerData(player)
end

-- Load player data from DataStore
function ScoreManager:loadPlayerData(player: Player)
	if not self.dataStore then return end
	
	local success, data = pcall(function()
		return self.dataStore:GetAsync("Player_" .. player.UserId)
	end)
	
	if success and data then
		local playerData = self.playerData[player]
		if playerData then
			playerData.totalScore = data.totalScore or 0
			playerData.highScore = data.highScore or 0
		end
		Logger.debug("ScoreManager", "Loaded data for", player.Name, "- HighScore:", data.highScore or 0)
	else
		Logger.debug("ScoreManager", "No saved data for", player.Name)
	end
	
	-- Update client
	self:sendScoreUpdate(player)
end

-- Save player data to DataStore
function ScoreManager:savePlayerData(player: Player)
	if not self.dataStore then return end
	
	local playerData = self.playerData[player]
	if not playerData then return end
	
	local success, err = pcall(function()
		self.dataStore:UpdateAsync("Player_" .. player.UserId, function(existingData)
			if type(existingData) ~= "table" then
				existingData = {}
			end
			existingData.totalScore = playerData.totalScore
			existingData.highScore = playerData.highScore
			return existingData
		end)
	end)
	
	if success then
		Logger.debug("ScoreManager", "Saved data for", player.Name)
	else
		Logger.warn("ScoreManager", "Failed to save data for", player.Name, ":", err)
	end
end

-- Add stage score
function ScoreManager:addStageScore(player: Player, stageIndex: number)
	local playerData = self.playerData[player]
	if not playerData then return end
	
	-- ตรวจสอบว่าผ่านด่านนี้แล้วหรือยัง
	if stageIndex <= playerData.currentStage then
		return -- ผ่านด่านนี้ไปแล้ว
	end
	
	playerData.currentStage = stageIndex
	
	-- Stage 1 is just starting, no score
	if stageIndex > 1 then
		playerData.roundScore = playerData.roundScore + Config.Score.PerStage
		Logger.debug("ScoreManager", player.Name, "passed stage", stageIndex - 1, "- Score:", playerData.roundScore)
	else
		Logger.debug("ScoreManager", player.Name, "started stage 1")
	end
	
	self:sendScoreUpdate(player)
end

-- Add finish bonus
function ScoreManager:addFinishBonus(player: Player)
	local playerData = self.playerData[player]
	if not playerData then return end
	
	playerData.roundScore = playerData.roundScore + Config.Score.FinishBonus
	
	-- Add to total score
	playerData.totalScore = playerData.totalScore + playerData.roundScore
	
	-- Check high score
	if playerData.roundScore > playerData.highScore then
		playerData.highScore = playerData.roundScore
		Logger.debug("ScoreManager", player.Name, "NEW HIGH SCORE:", playerData.highScore)
	end
	
	Logger.debug("ScoreManager", player.Name, "FINISHED! Round Score:", playerData.roundScore, "Total:", playerData.totalScore)
	
	-- Mark for pending save (will be saved in auto-save loop or when leaving)
	self.pendingSaves[player] = true
	
	self:sendScoreUpdate(player)
end

-- Start auto-save loop
function ScoreManager:startAutoSave()
	task.spawn(function()
		while true do
			task.wait(30) -- Save every 30 seconds
			self:saveAllPending()
		end
	end)
end

-- Save all pending player data
function ScoreManager:saveAllPending()
	for player, isPending in pairs(self.pendingSaves) do
		if isPending and player.Parent then -- Player still in game
			self:savePlayerData(player)
			self.pendingSaves[player] = false
		end
	end
end

-- Reset round score
function ScoreManager:resetRoundScore(player: Player)
	local playerData = self.playerData[player]
	if not playerData then return end
	
	playerData.roundScore = 0
	playerData.currentStage = 0
	
	self:sendScoreUpdate(player)
end

-- Send score update to client
function ScoreManager:sendScoreUpdate(player: Player)
	local playerData = self.playerData[player]
	if not playerData then return end
	
	self.updateScoreRemote:FireClient(player, {
		roundScore = playerData.roundScore,
		currentStage = playerData.currentStage,
		totalScore = playerData.totalScore,
		highScore = playerData.highScore,
	})
end

-- Get player score data
function ScoreManager:getPlayerData(player: Player): PlayerScoreData?
	return self.playerData[player]
end

-- Get current stage
function ScoreManager:getCurrentStage(player: Player): number
	local playerData = self.playerData[player]
	return playerData and playerData.currentStage or 0
end

-- Get round score
function ScoreManager:getRoundScore(player: Player): number
	local playerData = self.playerData[player]
	return playerData and playerData.roundScore or 0
end

-- Get total score (used for leaderboard)
function ScoreManager:getTotalScore(player: Player): number
	local playerData = self.playerData[player]
	return playerData and playerData.totalScore or 0
end

-- Remove player data
function ScoreManager:removePlayer(player: Player)
	-- Save before removing (if pending)
	if self.pendingSaves[player] then
		self:savePlayerData(player)
	end
	
	-- Clear data
	self.playerData[player] = nil
	self.pendingSaves[player] = nil
end

-- Setup leaderstats
function ScoreManager:setupLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	
	local highScore = Instance.new("IntValue")
	highScore.Name = "HighScore"
	highScore.Value = 0
	highScore.Parent = leaderstats
	
	local roundScore = Instance.new("IntValue")
	roundScore.Name = "RoundScore"
	roundScore.Value = 0
	roundScore.Parent = leaderstats
	
	local currency = Instance.new("IntValue")
	currency.Name = "Currency"
	currency.Value = 0
	currency.Parent = leaderstats
	
	-- Update when player data loads
	task.spawn(function()
		task.wait(1)
		local playerData = self.playerData[player]
		if playerData then
			highScore.Value = playerData.highScore
		end
		
		-- Update currency if CurrencyManager is available
		if self.currencyManager then
			currency.Value = self.currencyManager:getCurrency(player)
		end
	end)
end

-- Update leaderstats
function ScoreManager:updateLeaderstats(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end
	
	local playerData = self.playerData[player]
	if not playerData then return end
	
	local highScoreStat = leaderstats:FindFirstChild("HighScore")
	if highScoreStat then
		highScoreStat.Value = playerData.highScore
	end
	
	local roundScoreStat = leaderstats:FindFirstChild("RoundScore")
	if roundScoreStat then
		roundScoreStat.Value = playerData.roundScore
	end
	
	-- Update currency if CurrencyManager is available
	if self.currencyManager then
		local currencyStat = leaderstats:FindFirstChild("Currency")
		if currencyStat then
			currencyStat.Value = self.currencyManager:getCurrency(player)
		end
	end
end

return ScoreManager
