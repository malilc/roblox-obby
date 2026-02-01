-- MainUI: ควบคุม UI ทั้งหมดบน Client

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local ScoreUI = require(script.Parent.ScoreUI)
local ItemUI = require(script.Parent.ItemUI)
local StageSelectionUI = require(script.Parent.StageSelectionUI)
local CurrencyUI = require(script.Parent.CurrencyUI)
local SummaryUI = require(script.Parent.SummaryUI)

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
	self.stageSelectionUI = StageSelectionUI.new(screenGui)
	self.currencyUI = CurrencyUI.new(screenGui)
	self.summaryUI = SummaryUI.new(screenGui)
	
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
	
	-- Player died
	local playerDied = remotes:WaitForChild("PlayerDied")
	playerDied.OnClientEvent:Connect(function()
		self:onPlayerDied()
	end)
	
	-- Countdown update (Game Start)
	local countdownUpdate = remotes:WaitForChild("CountdownUpdate")
	countdownUpdate.OnClientEvent:Connect(function(data)
		if data.totalStages then
			-- Show stage UI when game starts
			self.scoreUI:showStageProgress(data.totalStages)
		end
	end)
	
	-- Update currency
	local updateCurrency = remotes:WaitForChild("UpdateCurrency")
	updateCurrency.OnClientEvent:Connect(function(data)
		self:onCurrencyUpdate(data)
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
	
	local isStart = data.isStart
	
	-- Show notification only if not just starting
	if not isStart then
		-- Show completion of previous stage
		self.scoreUI:showStageComplete(stageIndex - 1, isFinished)
	end
	
	-- Update score UI
	self.scoreUI:updateScore({
		currentStage = stageIndex,
		totalStages = data.totalStages,
		isFinished = isFinished -- Pass finish status
	})
	
	-- If finished, show summary and hide stage UI after delay
	if isFinished then
		-- Show summary UI if summary data is provided
		if data.summary then
			-- Small delay to let stage complete notification show first
			task.delay(0.5, function()
				self.summaryUI:show(data.summary)
			end)
		end
		
		task.delay(4, function()
			self.scoreUI:hideStageProgress()
		end)
	end
end

function MainUI:onPlayerDied()
	-- Could show death notification or effect
	self:showDeathNotification()
end

function MainUI:onCurrencyUpdate(data: {[string]: any})
	-- Update currency UI
	self.currencyUI:updateCurrency(data)
end

function MainUI:showDeathNotification()
	local TweenService = game:GetService("TweenService")
	
	-- เล็กลง + อยู่ด้านบน + โปร่งใส
	local notification = Instance.new("TextLabel")
	notification.Name = "DeathNotification"
	notification.Size = UDim2.new(0, 120, 0, 30)
	notification.Position = UDim2.new(0.5, -60, 0, 90)
	notification.AnchorPoint = Vector2.new(0, 0)
	notification.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	notification.BackgroundTransparency = 0.5
	notification.BorderSizePixel = 0
	notification.Text = "💀 Respawn"
	notification.TextColor3 = Color3.fromRGB(255, 100, 100)
	notification.TextSize = 14
	notification.Font = Enum.Font.GothamBold
	notification.TextTransparency = 0
	notification.Parent = self.screenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = notification
	
	-- Fade in
	notification.BackgroundTransparency = 1
	notification.TextTransparency = 1
	
	local fadeIn = TweenService:Create(notification, TweenInfo.new(0.2), {
		BackgroundTransparency = 0.5,
		TextTransparency = 0
	})
	fadeIn:Play()
	
	-- Fade out after delay
	task.delay(1, function()
		if notification.Parent then
			local fadeOut = TweenService:Create(notification, TweenInfo.new(0.3), {
				BackgroundTransparency = 1,
				TextTransparency = 1
			})
			fadeOut:Play()
			fadeOut.Completed:Connect(function()
				if notification.Parent then
					notification:Destroy()
				end
			end)
		end
	end)
end

return MainUI
