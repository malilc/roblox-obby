-- MainUI: ควบคุม UI ทั้งหมดบน Client

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local RemoteRegistry = require(ReplicatedStorage.Shared.RemoteRegistry)
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)

local ScoreUI = require(script.Parent.ScoreUI)
local ItemUI = require(script.Parent.ItemUI)
local StageSelectionUI = require(script.Parent.StageSelectionUI)
local CurrencyUI = require(script.Parent.CurrencyUI)
local SummaryUI = require(script.Parent.SummaryUI)
local MatchLobbyUI = require(script.Parent.MatchLobbyUI)
local ClassSelectionUI = require(script.Parent.ClassSelectionUI)
local RaceResultsUI = require(script.Parent.RaceResultsUI)
local TitleHUDUI = require(script.Parent.TitleHUDUI)
local TitleCollectionUI = require(script.Parent.TitleCollectionUI)
local TutorialUI = require(script.Parent.TutorialUI)
local SpectatorUI = require(script.Parent.SpectatorUI)
local DailyBonusUI = require(script.Parent.DailyBonusUI)
local LeaderboardUI = require(script.Parent.LeaderboardUI)
local ShopUI = require(script.Parent.ShopUI)

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
	self.matchLobbyUI = MatchLobbyUI.new(screenGui)
	self.raceResultsUI = RaceResultsUI.new(screenGui)
	self.titleCollectionUI = TitleCollectionUI.new(screenGui)
	self.tutorialUI = TutorialUI.new(screenGui, {
		onShow = function()
			if self.classSelectionUI and self.classSelectionUI.isVisible then
				self.classSelectionUI:hide()
			end
			if self.titleCollectionUI and self.titleCollectionUI.isVisible then
				self.titleCollectionUI:hide()
			end
		end,
	})
	self.spectatorUI = SpectatorUI.new(screenGui)
	self.dailyBonusUI = DailyBonusUI.new(screenGui)
	self.leaderboardUI = LeaderboardUI.new(screenGui)

	-- ShopUI with mutual exclusion
	self.shopUI = ShopUI.new(screenGui, {
		onShow = function()
			if self.stageSelectionUI and self.stageSelectionUI.isVisible then
				self.stageSelectionUI:hide()
			end
			if self.classSelectionUI and self.classSelectionUI.isVisible then
				self.classSelectionUI:hide()
			end
			if self.titleCollectionUI and self.titleCollectionUI.isVisible then
				self.titleCollectionUI:hide()
			end
		end,
	})

	-- ClassSelectionUI with cross-navigation callback
	self.classSelectionUI = ClassSelectionUI.new(screenGui, {
		onOpenTitleCollection = function()
			self.classSelectionUI:hide()
			task.delay(0.15, function()
				self.titleCollectionUI:show()
			end)
		end,
		onShow = function()
			if self.titleCollectionUI and self.titleCollectionUI.isVisible then
				self.titleCollectionUI:hide()
			end
			if self.tutorialUI and self.tutorialUI.isVisible then
				self.tutorialUI:hide()
			end
		end,
	})

	-- TitleHUD with callback to open collection
	self.titleHUDUI = TitleHUDUI.new(screenGui, function()
		self:toggleTitleCollection()
	end)

	-- Setup remote listeners
	self:setupRemotes()

	return self
end

function MainUI:toggleTitleCollection()
	if self.titleCollectionUI then
		if self.titleCollectionUI.isVisible then
			self.titleCollectionUI:hide()
		else
			if self.classSelectionUI and self.classSelectionUI.isVisible then
				self.classSelectionUI:hide()
			end
			if self.tutorialUI and self.tutorialUI.isVisible then
				self.tutorialUI:hide()
			end
			self.titleCollectionUI:show()
		end
	end
end

function MainUI:setupRemotes()
	-- Update score
	RemoteRegistry.get("UpdateScore").OnClientEvent:Connect(function(data)
		self:onScoreUpdate(data)
	end)

	-- Stage complete
	RemoteRegistry.get("StageComplete").OnClientEvent:Connect(function(data)
		self:onStageComplete(data)
	end)

	-- Player died
	RemoteRegistry.get("PlayerDied").OnClientEvent:Connect(function()
		self:onPlayerDied()
	end)

	-- Countdown update (Game Start)
	RemoteRegistry.get("CountdownUpdate").OnClientEvent:Connect(function(data)
		if data.totalStages then
			self.scoreUI:showStageProgress(data.totalStages)
		end
		if data.gameMode then
			self.scoreUI:showModeBadge(data.gameMode)
		end
	end)

	-- Update currency
	RemoteRegistry.get("UpdateCurrency").OnClientEvent:Connect(function(data)
		self:onCurrencyUpdate(data)
	end)

	-- Match timer (RaceUpdate fires every second during a race)
	RemoteRegistry.get("RaceUpdate").OnClientEvent:Connect(function(data)
		if data.timeRemaining then
			self.scoreUI:updateTimer(data.timeRemaining)
		end
	end)

	-- Time warning notification
	RemoteRegistry.get("TimeWarning").OnClientEvent:Connect(function(data)
		self:showTimeWarning(data.message, data.isCritical)
	end)

	-- Update gems + wins
	RemoteRegistry.get("UpdateGems").OnClientEvent:Connect(function(data)
		self.scoreUI:updateGems(data)
	end)

	-- Hide timer + mode badge when returning to lobby
	RemoteRegistry.get("ReturnToLobby").OnClientEvent:Connect(function()
		self.scoreUI:hideTimer()
		self.scoreUI:hideModeBadge()
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

		-- Show spectate prompt if in a match that's still racing
		if data.summary and data.summary.canSpectate then
			task.delay(2, function()
				self.spectatorUI:showSpectatePrompt()
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

function MainUI:showTimeWarning(message: string, isCritical: boolean?)
	local TweenService = game:GetService("TweenService")
	local notification = Instance.new("TextLabel")
	notification.Name = "TimeWarning"
	notification.Size = UDim2.new(0, 260, 0, 36)
	notification.Position = UDim2.new(0.5, -130, 0, 60)
	notification.BackgroundColor3 = if isCritical then Theme.DANGER else Theme.WARNING
	notification.BackgroundTransparency = 0.2
	notification.BorderSizePixel = 0
	notification.Text = "\u{23F0}  " .. message
	notification.TextColor3 = Theme.TEXT_PRIMARY
	notification.TextSize = 16
	notification.Font = Enum.Font.GothamBold
	notification.TextTransparency = 1
	notification.Parent = self.screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CORNER_SM
	corner.Parent = notification

	TweenService:Create(notification, TweenInfo.new(0.25), { TextTransparency = 0, BackgroundTransparency = 0.2 }):Play()
	task.delay(2.5, function()
		if notification.Parent then
			local fade = TweenService:Create(notification, TweenInfo.new(0.3), { TextTransparency = 1, BackgroundTransparency = 1 })
			fade:Play()
			fade.Completed:Connect(function() notification:Destroy() end)
		end
	end)
end

function MainUI:showDeathNotification()
	local TweenService = game:GetService("TweenService")

	-- เล็กลง + อยู่ด้านบน + โปร่งใส
	local notification = Instance.new("TextLabel")
	notification.Name = "DeathNotification"
	notification.Size = UDim2.new(0, 120, 0, 30)
	notification.Position = UDim2.new(0.5, -60, 0, 90)
	notification.AnchorPoint = Vector2.new(0, 0)
	notification.BackgroundColor3 = Theme.BG_OVERLAY
	notification.BackgroundTransparency = 0.5
	notification.BorderSizePixel = 0
	notification.Text = "Respawn"
	notification.TextColor3 = Theme.DANGER
	notification.TextSize = 14
	notification.Font = Enum.Font.GothamBold
	notification.TextTransparency = 0
	notification.Parent = self.screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CORNER_SM
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
