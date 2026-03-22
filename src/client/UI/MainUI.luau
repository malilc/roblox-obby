-- MainUI: ควบคุม UI ทั้งหมดบน Client

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local RemoteRegistry = require(ReplicatedStorage.Shared.RemoteRegistry)
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)
local AdaptiveLayout = require(ReplicatedStorage.Shared.AdaptiveLayout)

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
local SettingsUI = require(script.Parent.SettingsUI)
local FeedbackUI = require(script.Parent.FeedbackUI)
local MenuGridUI = require(script.Parent.MenuGridUI)

local SocialService = game:GetService("SocialService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Map panel keys to MenuGridUI button IDs
local PANEL_TO_BUTTON = {
	shopUI            = "Shop",
	classSelectionUI  = "Classes",
	titleCollectionUI = "Titles",
	tutorialUI        = "Help",
	settingsUI        = "Settings",
	feedbackUI        = "Feedback",
}

local MANAGED_PANELS = {"shopUI", "classSelectionUI", "titleCollectionUI", "tutorialUI", "settingsUI", "feedbackUI"}

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
	-- Safe area: CoreUISafeInsets prevents modal clipping behind notch/Dynamic Island (TOUCH-03)
	screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screenGui.Parent = playerGui
	self.screenGui = screenGui

	-- Initialize responsive scaling system (per D-02: single viewport listener)
	AdaptiveLayout.init()

	-- Create UI components
	self.scoreUI = ScoreUI.new(screenGui)
	self.itemUI = ItemUI.new(screenGui)
	self.stageSelectionUI = StageSelectionUI.new(screenGui)
	self.currencyUI = CurrencyUI.new(screenGui)
	self.summaryUI = SummaryUI.new(screenGui)
	self.matchLobbyUI = MatchLobbyUI.new(screenGui)
	self.raceResultsUI = RaceResultsUI.new(screenGui)
	self.titleCollectionUI = TitleCollectionUI.new(screenGui, {
		onHide = function()
			self:_syncGridButton("titleCollectionUI", false)
		end,
	})
	self.tutorialUI = TutorialUI.new(screenGui, {
		hideHelpButton = true,
		onShow = function()
			self:_hideAllExcept("tutorialUI")
			self:_syncGridButton("tutorialUI", true)
		end,
		onHide = function()
			self:_syncGridButton("tutorialUI", false)
		end,
	})
	self.spectatorUI = SpectatorUI.new(screenGui)
	self.dailyBonusUI = DailyBonusUI.new(screenGui, { hideHudButton = true })
	self.leaderboardUI = LeaderboardUI.new(screenGui)

	-- ShopUI with mutual exclusion
	self.shopUI = ShopUI.new(screenGui, {
		onShow = function()
			self:_hideAllExcept("shopUI")
			self:_syncGridButton("shopUI", true)
		end,
		onHide = function()
			self:_syncGridButton("shopUI", false)
		end,
	})

	-- ClassSelectionUI with cross-navigation callback
	self.classSelectionUI = ClassSelectionUI.new(screenGui, {
		hideIndicator = true,
		onOpenTitleCollection = function()
			self.classSelectionUI:hide()
			task.delay(0.15, function()
				self:openMenuPanel("titleCollectionUI")
			end)
		end,
		onShow = function()
			self:_hideAllExcept("classSelectionUI")
			self:_syncGridButton("classSelectionUI", true)
		end,
		onHide = function()
			self:_syncGridButton("classSelectionUI", false)
		end,
	})

	-- SettingsUI
	self.settingsUI = SettingsUI.new(screenGui, {
		onHide = function()
			self:_syncGridButton("settingsUI", false)
		end,
	})

	-- FeedbackUI
	self.feedbackUI = FeedbackUI.new(screenGui, {
		onHide = function()
			self:_syncGridButton("feedbackUI", false)
		end,
	})

	-- TitleHUD with callback to open collection (hidden — replaced by menu grid)
	self.titleHUDUI = TitleHUDUI.new(screenGui, function()
		self:toggleMenuPanel("titleCollectionUI")
	end, { hidden = true })

	-- Menu Grid (top-left button grid)
	self.menuGridUI = MenuGridUI.new(screenGui, {
		onShop = function()
			self:toggleMenuPanel("shopUI")
		end,
		onClasses = function()
			self:toggleMenuPanel("classSelectionUI")
		end,
		onTitles = function()
			self:toggleMenuPanel("titleCollectionUI")
		end,
		onDaily = function()
			-- Toggle: if calendar is open, close it; otherwise close other panels and open it
			if self.dailyBonusUI._calendarOpen then
				self.dailyBonusUI:hideCalendar()
			else
				self:closeAllMenuPanels()
				local data = self.dailyBonusUI.lastData
					or { claimed = false, day = 1, rewards = {25, 50, 75, 100, 150, 200, 500}, gemRewards = {1, 1, 2, 2, 3, 3, 5} }
				self.dailyBonusUI:showCalendar(data)
			end
		end,
		onFeedback = function()
			self:toggleMenuPanel("feedbackUI")
		end,
		onInvite = function()
			if RunService:IsStudio() then
				self:showInviteNotification("Invite only works in published games")
				return
			end
			task.spawn(function()
				pcall(function()
					SocialService:PromptGameInvite(LocalPlayer)
				end)
			end)
		end,
		onHelp = function()
			self:toggleMenuPanel("tutorialUI")
		end,
		onSettings = function()
			self:toggleMenuPanel("settingsUI")
		end,
	})

	-- Setup remote listeners
	self:setupRemotes()

	return self
end

-- Sync grid button active state
function MainUI:_syncGridButton(panelKey: string, active: boolean)
	if self.menuGridUI then
		local btnId = PANEL_TO_BUTTON[panelKey]
		if btnId then
			self.menuGridUI:setActive(btnId, active)
		end
	end
end

-- Hide/show overlay ScreenGuis (Testing, UpdateLog) to prevent them from covering modals
function MainUI:_setOverlayButtonsVisible(visible: boolean)
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return end
	local testingGui = playerGui:FindFirstChild("ItemTestingUI")
	if testingGui then testingGui.Enabled = visible end
	local updateLogGui = playerGui:FindFirstChild("UpdateLogBtnGui")
	if updateLogGui then updateLogGui.Enabled = visible end
end

-- Hide all managed panels except the one specified
function MainUI:_hideAllExcept(exceptKey: string)
	for _, key in ipairs(MANAGED_PANELS) do
		if key ~= exceptKey then
			local panel = self[key]
			if panel and panel.isVisible then
				panel:hide()
			end
		end
	end
	-- Also close daily calendar if it's open
	if self.dailyBonusUI then
		self.dailyBonusUI:hideCalendar()
	end
	-- Also hide stage selection if shop is opening
	if exceptKey == "shopUI" and self.stageSelectionUI and self.stageSelectionUI.isVisible then
		self.stageSelectionUI:hide()
	end
end

-- Toggle a managed panel: close if open, open if closed (closing others first)
function MainUI:toggleMenuPanel(panelKey: string)
	local panel = self[panelKey]
	if not panel then return end

	if panel.isVisible then
		panel:hide()
		self:_setOverlayButtonsVisible(true)
	else
		self:openMenuPanel(panelKey)
	end
end

-- Always open a panel (used by zone triggers and cross-navigation)
function MainUI:openMenuPanel(panelKey: string)
	local panel = self[panelKey]
	if not panel then return end

	-- Hide all other managed panels
	self:_hideAllExcept(panelKey)

	-- Clear all grid active states, then set the target active
	if self.menuGridUI then
		self.menuGridUI:clearAllActive()
		local btnId = PANEL_TO_BUTTON[panelKey]
		if btnId then
			self.menuGridUI:setActive(btnId, true)
		end
	end

	if not panel.isVisible then
		panel:show()
	end

	-- Hide Testing/UpdateLog buttons so they don't cover the modal
	self:_setOverlayButtonsVisible(false)
end

-- Close all managed panels (e.g. when race starts)
function MainUI:closeAllMenuPanels()
	for _, key in ipairs(MANAGED_PANELS) do
		local panel = self[key]
		if panel and panel.isVisible then
			panel:hide()
		end
	end
	-- Also close daily calendar
	if self.dailyBonusUI then
		self.dailyBonusUI:hideCalendar()
	end
	if self.menuGridUI then
		self.menuGridUI:clearAllActive()
	end
	-- Restore Testing/UpdateLog buttons
	self:_setOverlayButtonsVisible(true)
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
			-- Close all menu panels and hide menu grid when race starts
			self:closeAllMenuPanels()
			self.menuGridUI:hide()
		end
	end)

	-- Update currency
	RemoteRegistry.get("UpdateCurrency").OnClientEvent:Connect(function(data)
		self:onCurrencyUpdate(data)
	end)

	-- Match timer is handled by MatchLobbyUI (RaceUpdate listener)

	-- Time warning notification
	RemoteRegistry.get("TimeWarning").OnClientEvent:Connect(function(data)
		self:showTimeWarning(data.message, data.isCritical)
	end)

	-- Update gems + wins
	RemoteRegistry.get("UpdateGems").OnClientEvent:Connect(function(data)
		self.scoreUI:updateGems(data)
	end)

	-- Hide timer when returning to lobby
	RemoteRegistry.get("ReturnToLobby").OnClientEvent:Connect(function()
		self.scoreUI:hideTimer()
		self.menuGridUI:show()
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

function MainUI:showInviteNotification(message: string)
	local notification = Instance.new("TextLabel")
	notification.Name = "InviteNotification"
	notification.Size = UDim2.new(0, 220, 0, 30)
	notification.Position = UDim2.new(0.5, -110, 0, 60)
	notification.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	notification.BackgroundTransparency = 0.15
	notification.BorderSizePixel = 0
	notification.Text = message
	notification.TextColor3 = Color3.fromRGB(255, 255, 255)
	notification.TextSize = 13
	notification.Font = Enum.Font.GothamBold
	notification.TextTransparency = 1
	notification.Parent = self.screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CORNER_SM
	corner.Parent = notification

	TweenService:Create(notification, TweenInfo.new(0.2), {
		TextTransparency = 0,
		BackgroundTransparency = 0.3,
	}):Play()

	task.delay(2, function()
		if notification.Parent then
			local fade = TweenService:Create(notification, TweenInfo.new(0.3), {
				TextTransparency = 1,
				BackgroundTransparency = 1,
			})
			fade:Play()
			fade.Completed:Connect(function()
				if notification.Parent then notification:Destroy() end
			end)
		end
	end)
end

return MainUI
