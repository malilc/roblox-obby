-- MainUI: ควบคุม UI ทั้งหมดบน Client

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local ScoreUI = require(script.Parent.ScoreUI)
local ItemUI = require(script.Parent.ItemUI)
local LeaderboardUI = require(script.Parent.LeaderboardUI)

local LocalPlayer = Players.LocalPlayer

local MainUI = {}
MainUI.__index = MainUI

function MainUI.new()
	local self = setmetatable({}, MainUI)
	
	-- Wait for PlayerGui
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	
	-- Create main ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ObbyGameUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = false
	screenGui.Parent = playerGui
	self.screenGui = screenGui
	
	-- Create UI components
	self.scoreUI = ScoreUI.new(screenGui)
	self.itemUI = ItemUI.new(screenGui)
	self.leaderboardUI = LeaderboardUI.new(screenGui)
	
	-- Setup remote listeners
	self:setupRemotes()
	
	return self
end

function MainUI:setupRemotes()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	
	-- Update score
	local updateScore = remotes:WaitForChild("UpdateScore")
	updateScore.OnClientEvent:Connect(function(data)
		self:onScoreUpdate(data)
	end)
	
	-- Stage complete
	local stageComplete = remotes:WaitForChild("StageComplete")
	stageComplete.OnClientEvent:Connect(function(data)
		self:onStageComplete(data)
	end)
	
	-- Leaderboard update
	local updateLeaderboard = remotes:WaitForChild("UpdateLeaderboard")
	updateLeaderboard.OnClientEvent:Connect(function(entries)
		self:onLeaderboardUpdate(entries)
	end)
	
	-- Player died
	local playerDied = remotes:WaitForChild("PlayerDied")
	playerDied.OnClientEvent:Connect(function()
		self:onPlayerDied()
	end)
end

function MainUI:onScoreUpdate(data: {[string]: any})
	-- Update score UI
	self.scoreUI:updateScore(data)
	
	-- Update item UI
	self.itemUI:updateItems(data)
end

function MainUI:onStageComplete(data: {[string]: any})
	local stageIndex = data.stageIndex
	local isFinished = data.finished
	
	-- Show notification
	self.scoreUI:showStageComplete(stageIndex, isFinished)
	
	-- Update score UI
	self.scoreUI:updateScore({
		currentStage = stageIndex
	})
end

function MainUI:onLeaderboardUpdate(entries: {{userId: number, name: string, highScore: number}})
	self.leaderboardUI:updateLeaderboard(entries)
end

function MainUI:onPlayerDied()
	-- Could show death notification or effect
	self:showDeathNotification()
end

function MainUI:showDeathNotification()
	local notification = Instance.new("TextLabel")
	notification.Name = "DeathNotification"
	notification.Size = UDim2.new(0, 300, 0, 50)
	notification.Position = UDim2.new(0.5, -150, 0.4, 0)
	notification.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
	notification.BackgroundTransparency = 0.3
	notification.BorderSizePixel = 0
	notification.Text = "Respawning..."
	notification.TextColor3 = Color3.fromRGB(255, 255, 255)
	notification.TextSize = 20
	notification.Font = Enum.Font.GothamMedium
	notification.Parent = self.screenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = notification
	
	-- Fade out
	task.delay(1.5, function()
		if notification.Parent then
			notification:Destroy()
		end
	end)
end

return MainUI
