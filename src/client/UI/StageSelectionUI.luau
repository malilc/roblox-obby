-- StageSelectionUI: GUI สำหรับเลือกลำดับด่าน (Modern Design)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local StageInfo = require(ReplicatedStorage.Shared.StageInfo)
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)

local StageSelectionUI = {}
StageSelectionUI.__index = StageSelectionUI

function StageSelectionUI.new(parent: ScreenGui)
	local self = setmetatable({}, StageSelectionUI)
	self.parent = parent
	self.selectedStages = {} :: {number}
	self.isVisible = false
	self.hasVoted = false           -- Whether player has voted this session
	self.gameMode = "Race"          -- "Race" (PVP) or "TimeTrial" — set by server
	self.currentRoomId = nil :: string?
	self.currentPlayerCount = 1

	-- Remotes
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	self.showRemote = remotes:WaitForChild("ShowStageSelection")
	self.hideRemote = remotes:WaitForChild("HideStageSelection")
	self.countdownRemote = remotes:WaitForChild("CountdownUpdate")

	-- Stage voting remotes
	self.voteStagesRemote = remotes:WaitForChild("VoteStages")
	self.stageVoteUpdateRemote = remotes:WaitForChild("StageVoteUpdate")

	-- Match updates
	self.matchUpdateRemote = remotes:WaitForChild("MatchUpdate")

	-- Create UI
	self:createUI()

	-- Setup remote listeners
	self:setupRemotes()

	return self
end

-- Helper function to create gradient
local function createGradient(parent: GuiObject, color1: Color3, color2: Color3)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color1),
		ColorSequenceKeypoint.new(1, color2)
	})
	gradient.Rotation = 45
	gradient.Parent = parent
	return gradient
end

function StageSelectionUI:createUI()
	-- Main Frame with modern design
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "StageSelectionFrame"
	mainFrame.Size = UDim2.new(0, 580, 0, 520)
	mainFrame.Position = UDim2.new(0.5, -290, 0.5, -260)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = Theme.BG_BASE
	mainFrame.BackgroundTransparency = 0.15
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = self.parent
	self.mainFrame = mainFrame

	-- Add gradient background
	createGradient(mainFrame, Theme.BG_BASE, Theme.BG_SURFACE)

	-- Glow stroke
	local borderStroke = Instance.new("UIStroke")
	borderStroke.Color = Theme.ACCENT_CYAN
	borderStroke.Thickness = Theme.STROKE_BOLD
	borderStroke.Transparency = 0.2
	borderStroke.Parent = mainFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CORNER_LG
	corner.Parent = mainFrame

	-- Drop shadow
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 6, 1, 6)
	shadow.Position = UDim2.new(0, -3, 0, 4)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.6
	shadow.BorderSizePixel = 0
	shadow.ZIndex = mainFrame.ZIndex - 1
	shadow.Parent = mainFrame
	Theme.applyCorner(shadow, "lg")

	-- Title with gradient text effect
	local titleContainer = Instance.new("Frame")
	titleContainer.Name = "TitleContainer"
	titleContainer.Size = UDim2.new(1, -40, 0, 50)
	titleContainer.Position = UDim2.new(0, 20, 0, 15)
	titleContainer.BackgroundTransparency = 1
	titleContainer.Parent = mainFrame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 30)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "\u{1F3AE} SELECT STAGE ORDER"
	title.TextColor3 = Theme.TEXT_PRIMARY
	title.TextSize = 28
	title.Font = Enum.Font.GothamBold
	title.TextStrokeTransparency = 0.8
	title.TextStrokeColor3 = Theme.ACCENT_CYAN
	title.Parent = titleContainer

	-- Subtitle
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, 0, 0, 20)
	subtitle.Position = UDim2.new(0, 0, 0, 32)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Pick up to " .. Config.Stages.SelectionCount .. " stages, or press RANDOM"
	subtitle.TextColor3 = Theme.TEXT_MUTED
	subtitle.TextSize = 14
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextTransparency = 0.3
	subtitle.Parent = titleContainer

	-- === Mode Badge (static, determined by zone) ===
	local modeBadge = Instance.new("Frame")
	modeBadge.Name = "ModeBadge"
	modeBadge.Size = UDim2.new(0, 160, 0, 28)
	modeBadge.Position = UDim2.new(0, 20, 0, 70)
	modeBadge.BackgroundColor3 = Color3.fromRGB(255, 95, 85)
	modeBadge.BackgroundTransparency = 0.1
	modeBadge.BorderSizePixel = 0
	modeBadge.Parent = mainFrame
	self.modeBadge = modeBadge

	local modeBadgeCorner = Instance.new("UICorner")
	modeBadgeCorner.CornerRadius = UDim.new(0, 8)
	modeBadgeCorner.Parent = modeBadge

	local modeBadgeStroke = Instance.new("UIStroke")
	modeBadgeStroke.Color = Color3.fromRGB(255, 95, 85)
	modeBadgeStroke.Thickness = 2
	modeBadgeStroke.Transparency = 0.2
	modeBadgeStroke.Parent = modeBadge
	self.modeBadgeStroke = modeBadgeStroke

	local modeBadgeLabel = Instance.new("TextLabel")
	modeBadgeLabel.Name = "Label"
	modeBadgeLabel.Size = UDim2.new(1, 0, 1, 0)
	modeBadgeLabel.BackgroundTransparency = 1
	modeBadgeLabel.Text = "\u{2694}\u{FE0F} PVP RACE"
	modeBadgeLabel.TextColor3 = Theme.TEXT_PRIMARY
	modeBadgeLabel.TextSize = 14
	modeBadgeLabel.Font = Enum.Font.GothamBold
	modeBadgeLabel.Parent = modeBadge
	self.modeBadgeLabel = modeBadgeLabel

	-- === Player Count ===
	local playerCountLabel = Instance.new("TextLabel")
	playerCountLabel.Name = "PlayerCount"
	playerCountLabel.Size = UDim2.new(0, 100, 0, 28)
	playerCountLabel.Position = UDim2.new(0, 190, 0, 70)
	playerCountLabel.BackgroundColor3 = Theme.BG_ELEVATED
	playerCountLabel.BackgroundTransparency = 0.5
	playerCountLabel.BorderSizePixel = 0
	playerCountLabel.Text = "\u{1F465} 1/16"
	playerCountLabel.TextColor3 = Theme.TEXT_PRIMARY
	playerCountLabel.TextSize = 13
	playerCountLabel.Font = Enum.Font.GothamBold
	playerCountLabel.Parent = mainFrame
	self.playerCountLabel = playerCountLabel

	local pcCorner = Instance.new("UICorner")
	pcCorner.CornerRadius = UDim.new(0, 8)
	pcCorner.Parent = playerCountLabel

	-- === Match Countdown Label (shows countdown from MatchManager) ===
	local matchCountdownLabel = Instance.new("TextLabel")
	matchCountdownLabel.Name = "MatchCountdown"
	matchCountdownLabel.Size = UDim2.new(0, 120, 0, 28)
	matchCountdownLabel.Position = UDim2.new(0, 300, 0, 70)
	matchCountdownLabel.BackgroundColor3 = Theme.BG_ELEVATED
	matchCountdownLabel.BackgroundTransparency = 0.5
	matchCountdownLabel.BorderSizePixel = 0
	matchCountdownLabel.Text = ""
	matchCountdownLabel.TextColor3 = Theme.WARNING
	matchCountdownLabel.TextSize = 13
	matchCountdownLabel.Font = Enum.Font.GothamBold
	matchCountdownLabel.Visible = false
	matchCountdownLabel.Parent = mainFrame
	self.matchCountdownLabel = matchCountdownLabel

	local mcCorner = Instance.new("UICorner")
	mcCorner.CornerRadius = UDim.new(0, 8)
	mcCorner.Parent = matchCountdownLabel

	-- === In Progress overlay ===
	local inProgressOverlay = Instance.new("Frame")
	inProgressOverlay.Name = "InProgressOverlay"
	inProgressOverlay.Size = UDim2.new(1, -40, 0, 340)
	inProgressOverlay.Position = UDim2.new(0, 20, 0, 105)
	inProgressOverlay.BackgroundColor3 = Theme.BG_SURFACE
	inProgressOverlay.BackgroundTransparency = 0.3
	inProgressOverlay.BorderSizePixel = 0
	inProgressOverlay.Visible = false
	inProgressOverlay.ZIndex = mainFrame.ZIndex + 10
	inProgressOverlay.Parent = mainFrame
	self.inProgressOverlay = inProgressOverlay

	local ipCorner = Instance.new("UICorner")
	ipCorner.CornerRadius = UDim.new(0, 12)
	ipCorner.Parent = inProgressOverlay

	local inProgressLabel = Instance.new("TextLabel")
	inProgressLabel.Size = UDim2.new(1, 0, 1, 0)
	inProgressLabel.BackgroundTransparency = 1
	inProgressLabel.Text = "\u{23F3} Match in progress...\nPlease wait for the current match to finish."
	inProgressLabel.TextColor3 = Theme.TEXT_MUTED
	inProgressLabel.TextSize = 18
	inProgressLabel.Font = Enum.Font.GothamBold
	inProgressLabel.TextWrapped = true
	inProgressLabel.ZIndex = mainFrame.ZIndex + 11
	inProgressLabel.Parent = inProgressOverlay

	-- Difficulty Tab Bar
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, -40, 0, 30)
	tabBar.Position = UDim2.new(0, 20, 0, 105)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = mainFrame

	self.activeTab = "Easy"
	self.tabButtons = {}
	self.tabStrokesMap = {}

	local difficulties = {"Easy", "Normal", "Hard"}
	for idx, diff in ipairs(difficulties) do
		local diffInfo = StageInfo.DifficultyInfo[diff]

		local tab = Instance.new("TextButton")
		tab.Name = "Tab_" .. diff
		tab.Size = UDim2.new(0, 160, 0, 28)
		tab.Position = UDim2.new(0, (idx - 1) * 180, 0, 0)
		tab.BackgroundColor3 = diffInfo.badgeColor
		tab.BackgroundTransparency = 0.7
		tab.BorderSizePixel = 0
		tab.Text = diffInfo.label
		tab.TextColor3 = Theme.TEXT_PRIMARY
		tab.TextSize = 13
		tab.Font = Enum.Font.GothamBold
		tab.Parent = tabBar

		local tabCorner = Instance.new("UICorner")
		tabCorner.CornerRadius = UDim.new(0, 6)
		tabCorner.Parent = tab

		local tabStroke = Instance.new("UIStroke")
		tabStroke.Color = diffInfo.color
		tabStroke.Thickness = 1.5
		tabStroke.Transparency = 0.7
		tabStroke.Parent = tab

		tab.MouseButton1Click:Connect(function()
			self:switchTab(diff)
		end)

		self.tabButtons[diff] = tab
		self.tabStrokesMap[diff] = tabStroke
	end

	-- Stage Buttons Container
	local buttonsContainer = Instance.new("Frame")
	buttonsContainer.Name = "ButtonsContainer"
	buttonsContainer.Size = UDim2.new(1, -40, 0, 200)
	buttonsContainer.Position = UDim2.new(0, 20, 0, 145)
	buttonsContainer.BackgroundTransparency = 1
	buttonsContainer.Parent = mainFrame
	self.buttonsContainer = buttonsContainer

	-- Stage buttons from StageInfo (single source of truth)
	local totalStages = StageInfo.getTotalStageCount()
	self.stageButtons = {}

	for i = 1, totalStages do
		local stageData = StageInfo.getStage(i)
		if not stageData then continue end

		local buttonContainer = Instance.new("Frame")
		buttonContainer.Name = "Stage" .. i .. "Container"
		buttonContainer.Size = UDim2.new(0, 100, 0, 105)
		buttonContainer.Position = UDim2.new(0, 0, 0, 0)
		buttonContainer.BackgroundTransparency = 1
		buttonContainer.Visible = false
		buttonContainer.Parent = buttonsContainer

		local button = Instance.new("TextButton")
		button.Name = "Stage" .. i .. "Button"
		button.Size = UDim2.new(1, 0, 1, 0)
		button.Position = UDim2.new(0, 0, 0, 0)
		button.BackgroundColor3 = stageData.color
		button.BackgroundTransparency = 0.2
		button.BorderSizePixel = 0
		button.Text = ""
		button.Parent = buttonContainer

		-- Add gradient
		createGradient(button, stageData.color, stageData.gradientEnd)

		-- Add border
		local buttonStroke = Instance.new("UIStroke")
		buttonStroke.Color = stageData.color
		buttonStroke.Thickness = 2
		buttonStroke.Transparency = 0.6
		buttonStroke.Parent = button

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 12)
		btnCorner.Parent = button

		-- Difficulty badge (top-right corner)
		local diffInfo = StageInfo.DifficultyInfo[stageData.difficulty]
		local badge = Instance.new("TextLabel")
		badge.Name = "DifficultyBadge"
		badge.Size = UDim2.new(0, 42, 0, 14)
		badge.Position = UDim2.new(1, -44, 0, 4)
		badge.BackgroundColor3 = diffInfo.badgeColor
		badge.BackgroundTransparency = 0.2
		badge.Text = diffInfo.label
		badge.TextColor3 = Theme.TEXT_PRIMARY
		badge.TextSize = 8
		badge.Font = Enum.Font.GothamBold
		badge.ZIndex = button.ZIndex + 1
		badge.Parent = button

		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0, 4)
		badgeCorner.Parent = badge

		-- Icon
		local icon = Instance.new("TextLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.new(1, 0, 0, 40)
		icon.Position = UDim2.new(0, 0, 0, 10)
		icon.BackgroundTransparency = 1
		icon.Text = stageData.icon
		icon.TextSize = 32
		icon.Font = Enum.Font.GothamBold
		icon.TextColor3 = Theme.TEXT_PRIMARY
		icon.Parent = button

		-- Stage number
		local numberLabel = Instance.new("TextLabel")
		numberLabel.Name = "Number"
		numberLabel.Size = UDim2.new(1, 0, 0, 20)
		numberLabel.Position = UDim2.new(0, 0, 0, 50)
		numberLabel.BackgroundTransparency = 1
		numberLabel.Text = "[" .. i .. "]"
		numberLabel.TextSize = 16
		numberLabel.Font = Enum.Font.GothamBold
		numberLabel.TextColor3 = Theme.TEXT_PRIMARY
		numberLabel.TextStrokeTransparency = 0.5
		numberLabel.Parent = button

		-- Stage name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.Size = UDim2.new(1, 0, 0, 16)
		nameLabel.Position = UDim2.new(0, 0, 0, 68)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = stageData.name
		nameLabel.TextSize = 11
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.TextColor3 = Theme.TEXT_PRIMARY
		nameLabel.TextStrokeTransparency = 0.7
		nameLabel.Parent = button

		-- Stage Reward indicator
		local coinLabel = Instance.new("TextLabel")
		coinLabel.Name = "CoinLabel"
		coinLabel.Size = UDim2.new(1, 0, 0, 14)
		coinLabel.Position = UDim2.new(0, 0, 0, 84)
		coinLabel.BackgroundTransparency = 1
		coinLabel.Text = "\u{1F4B0} +" .. stageData.reward
		coinLabel.TextSize = 10
		coinLabel.Font = Enum.Font.GothamBold
		coinLabel.TextColor3 = Theme.MEDAL_GOLD
		coinLabel.TextStrokeTransparency = 0.5
		coinLabel.TextStrokeColor3 = Color3.fromRGB(100, 70, 0)
		coinLabel.Parent = button

		-- Selected indicator
		local selectedIndicator = Instance.new("Frame")
		selectedIndicator.Name = "SelectedIndicator"
		selectedIndicator.Size = UDim2.new(1, -4, 1, -4)
		selectedIndicator.Position = UDim2.new(0, 2, 0, 2)
		selectedIndicator.BackgroundColor3 = Theme.TEXT_PRIMARY
		selectedIndicator.BackgroundTransparency = 0.8
		selectedIndicator.BorderSizePixel = 0
		selectedIndicator.Visible = false
		selectedIndicator.Parent = button

		local indicatorCorner = Instance.new("UICorner")
		indicatorCorner.CornerRadius = UDim.new(0, 10)
		indicatorCorner.Parent = selectedIndicator

		-- Hover effect
		button.MouseEnter:Connect(function()
			if not table.find(self.selectedStages, i) then
				local hoverTween = TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
					BackgroundTransparency = 0.1,
					Size = UDim2.new(1.1, 0, 1.1, 0),
					Position = UDim2.new(-0.05, 0, -0.05, 0)
				})
				hoverTween:Play()
			end
		end)

		button.MouseLeave:Connect(function()
			if not table.find(self.selectedStages, i) then
				local leaveTween = TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
					BackgroundTransparency = 0.2,
					Size = UDim2.new(1, 0, 1, 0),
					Position = UDim2.new(0, 0, 0, 0)
				})
				leaveTween:Play()
			end
		end)

		-- Click handler
		button.MouseButton1Click:Connect(function()
			self:toggleStage(i)
		end)

		-- Selection order badge (green circle with number, top-right)
		local orderBadge = Instance.new("TextLabel")
		orderBadge.Name = "OrderBadge"
		orderBadge.Size = UDim2.new(0, 24, 0, 24)
		orderBadge.Position = UDim2.new(1, -14, 0, -6)
		orderBadge.AnchorPoint = Vector2.new(0.5, 0.5)
		orderBadge.BackgroundColor3 = Theme.SUCCESS
		orderBadge.BackgroundTransparency = 0
		orderBadge.Text = ""
		orderBadge.TextColor3 = Theme.TEXT_PRIMARY
		orderBadge.TextSize = 13
		orderBadge.Font = Enum.Font.GothamBold
		orderBadge.ZIndex = button.ZIndex + 2
		orderBadge.Visible = false
		orderBadge.Parent = button
		Theme.applyCorner(orderBadge, "full")

		self.stageButtons[i] = {
			button = button,
			container = buttonContainer,
			indicator = selectedIndicator,
			stroke = buttonStroke,
			difficulty = stageData.difficulty,
			orderBadge = orderBadge,
		}
	end

	-- Selected Order Display with modern design
	local selectedContainer = Instance.new("Frame")
	selectedContainer.Name = "SelectedContainer"
	selectedContainer.Size = UDim2.new(1, -40, 0, 50)
	selectedContainer.Position = UDim2.new(0, 20, 0, 360)
	selectedContainer.BackgroundColor3 = Theme.BG_SURFACE
	selectedContainer.BackgroundTransparency = 0.5
	selectedContainer.BorderSizePixel = 0
	selectedContainer.Parent = mainFrame

	local selectedCorner = Instance.new("UICorner")
	selectedCorner.CornerRadius = Theme.CORNER_SM
	selectedCorner.Parent = selectedContainer

	local selectedLabel = Instance.new("TextLabel")
	selectedLabel.Name = "SelectedLabel"
	selectedLabel.Size = UDim2.new(1, -20, 1, 0)
	selectedLabel.Position = UDim2.new(0, 10, 0, 0)
	selectedLabel.BackgroundTransparency = 1
	selectedLabel.Text = "\u{2728} Selected: (none)"
	selectedLabel.TextColor3 = Theme.TEXT_MUTED
	selectedLabel.TextSize = 16
	selectedLabel.Font = Enum.Font.Gotham
	selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
	selectedLabel.Parent = selectedContainer
	self.selectedLabel = selectedLabel

	-- Clear Button (modern design)
	local clearButton = Instance.new("TextButton")
	clearButton.Name = "ClearButton"
	clearButton.Size = UDim2.new(0, 110, 0, 35)
	clearButton.Position = UDim2.new(1, -130, 0, 365)
	clearButton.BackgroundColor3 = Theme.BG_ELEVATED
	clearButton.BorderSizePixel = 0
	clearButton.Text = "\u{1F5D1}\u{FE0F} Clear"
	clearButton.TextColor3 = Theme.TEXT_PRIMARY
	clearButton.TextSize = 14
	clearButton.Font = Enum.Font.GothamBold
	clearButton.Parent = mainFrame

	local clearCorner = Instance.new("UICorner")
	clearCorner.CornerRadius = Theme.CORNER_SM
	clearCorner.Parent = clearButton

	local clearStroke = Instance.new("UIStroke")
	clearStroke.Color = Theme.TEXT_MUTED
	clearStroke.Thickness = Theme.STROKE_THIN
	clearStroke.Transparency = 0.5
	clearStroke.Parent = clearButton

	clearButton.MouseButton1Click:Connect(function()
		self:clearSelection()
	end)

	-- Random Vote Button (modern gradient design)
	local randomButton = Instance.new("TextButton")
	randomButton.Name = "RandomButton"
	randomButton.Size = UDim2.new(0, 170, 0, 50)
	randomButton.Position = UDim2.new(0, 20, 0, 450)
	randomButton.BackgroundColor3 = Color3.fromRGB(255, 95, 85)
	randomButton.BackgroundTransparency = 0
	randomButton.BorderSizePixel = 0
	randomButton.Text = "\u{1F3B2} RANDOM VOTE"
	randomButton.TextColor3 = Theme.TEXT_PRIMARY
	randomButton.TextSize = 18
	randomButton.Font = Enum.Font.GothamBold
	randomButton.TextStrokeTransparency = 0.3
	randomButton.TextStrokeColor3 = Color3.fromRGB(120, 30, 30)
	randomButton.ZIndex = 10
	randomButton.Parent = mainFrame
	self.randomButton = randomButton

	Theme.applyCorner(randomButton, "sm")

	local randomStroke = Instance.new("UIStroke")
	randomStroke.Color = Color3.fromRGB(255, 140, 130)
	randomStroke.Thickness = Theme.STROKE_MED
	randomStroke.Transparency = 0.1
	randomStroke.Parent = randomButton

	randomButton.MouseButton1Click:Connect(function()
		self:confirmSelection(true)
	end)

	-- Vote Button (replaces Start button)
	local startButton = Instance.new("TextButton")
	startButton.Name = "StartButton"
	startButton.Size = UDim2.new(0, 170, 0, 50)
	startButton.Position = UDim2.new(1, -190, 0, 450)
	startButton.BackgroundColor3 = Color3.fromRGB(55, 195, 95)
	startButton.BackgroundTransparency = 0
	startButton.BorderSizePixel = 0
	startButton.Text = "\u{1F680} VOTE"
	startButton.TextColor3 = Theme.TEXT_PRIMARY
	startButton.TextSize = 20
	startButton.Font = Enum.Font.GothamBold
	startButton.TextStrokeTransparency = 0.3
	startButton.TextStrokeColor3 = Color3.fromRGB(15, 80, 30)
	startButton.ZIndex = 10
	startButton.Parent = mainFrame
	self.startButton = startButton

	Theme.applyCorner(startButton, "sm")

	local startStroke = Instance.new("UIStroke")
	startStroke.Color = Theme.SUCCESS
	startStroke.Thickness = Theme.STROKE_MED
	startStroke.Transparency = 0.2
	startStroke.Parent = startButton
	self.startStroke = startStroke

	-- Start disabled
	startButton.Active = false
	startButton.BackgroundColor3 = Color3.fromRGB(40, 80, 50)
	startButton.TextTransparency = 0.4
	if startStroke then
		startStroke.Transparency = 0.8
	end

	startButton.MouseButton1Click:Connect(function()
		if startButton.Active then
			self:confirmSelection(false)
		end
	end)

	-- Countdown Frame (modern design) - center of screen
	local countdownFrame = Instance.new("Frame")
	countdownFrame.Name = "CountdownFrame"
	countdownFrame.Size = UDim2.new(0, 350, 0, 250)
	countdownFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	countdownFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	countdownFrame.BackgroundColor3 = Theme.BG_BASE
	countdownFrame.BackgroundTransparency = 0.4
	countdownFrame.BorderSizePixel = 0
	countdownFrame.Visible = false
	countdownFrame.ZIndex = 100
	countdownFrame.Parent = self.parent
	self.countdownFrame = countdownFrame

	createGradient(countdownFrame, Theme.BG_BASE, Theme.BG_OVERLAY)

	local countdownCorner = Instance.new("UICorner")
	countdownCorner.CornerRadius = Theme.CORNER_LG
	countdownCorner.Parent = countdownFrame

	local countdownStroke = Instance.new("UIStroke")
	countdownStroke.Color = Theme.ACCENT_CYAN
	countdownStroke.Thickness = Theme.STROKE_BOLD
	countdownStroke.Transparency = 0.3
	countdownStroke.Parent = countdownFrame

	local countdownNumber = Instance.new("TextLabel")
	countdownNumber.Name = "CountdownNumber"
	countdownNumber.Size = UDim2.new(1, 0, 0, 150)
	countdownNumber.AnchorPoint = Vector2.new(0.5, 0)
	countdownNumber.Position = UDim2.new(0.5, 0, 0, 20)
	countdownNumber.BackgroundTransparency = 1
	countdownNumber.Text = "3"
	countdownNumber.TextColor3 = Theme.TEXT_PRIMARY
	countdownNumber.TextSize = 120
	countdownNumber.Font = Enum.Font.GothamBold
	countdownNumber.TextStrokeTransparency = 0
	countdownNumber.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	countdownNumber.TextXAlignment = Enum.TextXAlignment.Center
	countdownNumber.ZIndex = 101
	countdownNumber.Parent = countdownFrame
	self.countdownNumber = countdownNumber

	local countdownMessage = Instance.new("TextLabel")
	countdownMessage.Name = "CountdownMessage"
	countdownMessage.Size = UDim2.new(1, 0, 0, 60)
	countdownMessage.AnchorPoint = Vector2.new(0.5, 0)
	countdownMessage.Position = UDim2.new(0.5, 0, 0, 170)
	countdownMessage.BackgroundTransparency = 1
	countdownMessage.Text = "Starting..."
	countdownMessage.TextColor3 = Theme.TEXT_PRIMARY
	countdownMessage.TextSize = 24
	countdownMessage.Font = Enum.Font.GothamBold
	countdownMessage.TextStrokeTransparency = 0
	countdownMessage.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	countdownMessage.TextXAlignment = Enum.TextXAlignment.Center
	countdownMessage.ZIndex = 101
	countdownMessage.Parent = countdownFrame
	self.countdownMessage = countdownMessage

	-- Initialize default tab
	self:switchTab("Easy")
end

function StageSelectionUI:updateModeBadge(gameMode: string)
	self.gameMode = gameMode

	if gameMode == "TimeTrial" then
		self.modeBadgeLabel.Text = "\u{23F1}\u{FE0F} TIME TRIAL"
		self.modeBadge.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
		self.modeBadgeStroke.Color = Color3.fromRGB(0, 200, 255)
	else
		self.modeBadgeLabel.Text = "\u{2694}\u{FE0F} PVP RACE"
		self.modeBadge.BackgroundColor3 = Color3.fromRGB(255, 95, 85)
		self.modeBadgeStroke.Color = Color3.fromRGB(255, 95, 85)
	end

	-- Update subtitle
	local titleContainer = self.mainFrame:FindFirstChild("TitleContainer")
	if titleContainer then
		local sub = titleContainer:FindFirstChild("Subtitle")
		if sub then
			if gameMode == "TimeTrial" then
				sub.Text = "\u{23F1}\u{FE0F} No items \u{2014} Race against the clock!"
			else
				sub.Text = "Pick up to " .. Config.Stages.SelectionCount .. " stages, or press RANDOM"
			end
		end
	end
end

function StageSelectionUI:updatePlayerCount(count: number)
	self.currentPlayerCount = count
	local maxPlayers = (Config.Match and Config.Match.MaxPlayers) or 16
	self.playerCountLabel.Text = "\u{1F465} " .. count .. "/" .. maxPlayers
end

function StageSelectionUI:setupRemotes()
	self.showRemote.OnClientEvent:Connect(function(data)
		self:show(data)
	end)

	self.hideRemote.OnClientEvent:Connect(function()
		self:hide()
	end)

	self.countdownRemote.OnClientEvent:Connect(function(data)
		self:updateCountdown(data)
	end)

	-- Stage voting update
	self.stageVoteUpdateRemote.OnClientEvent:Connect(function(data)
		self:onStageVoteUpdate(data)
	end)

	-- Match updates (player count, countdown from MatchManager)
	self.matchUpdateRemote.OnClientEvent:Connect(function(data)
		self:onMatchUpdate(data)
	end)
end

-- Handle match updates (countdown, room changes)
function StageSelectionUI:onMatchUpdate(data)
	if not self.isVisible then return end

	if data.type == "countdown" then
		self.matchCountdownLabel.Text = "\u{23F0} Start in " .. data.countdown .. "s"
		self.matchCountdownLabel.Visible = true
		self:updatePlayerCount(data.playerCount or self.currentPlayerCount)
	elseif data.type == "roomUpdate" then
		self:updatePlayerCount(data.playerCount or self.currentPlayerCount)
	end
end

-- Handle stage vote update from server
function StageSelectionUI:onStageVoteUpdate(data)
	if data.type == "voteUpdate" then
		-- Could enhance to show other players' votes
	end
end

function StageSelectionUI:show(data: any?)
	if self.isVisible then return end
	self.isVisible = true
	self.hasVoted = false

	-- Parse data from server
	local gameMode = "Race"
	local playerCount = 1
	local roomState = nil

	if type(data) == "table" then
		gameMode = data.gameMode or "Race"
		playerCount = data.playerCount or 1
		roomState = data.roomState
		self.currentRoomId = data.roomId
	end

	-- Reset vote UI state
	self:resetVoteUI()

	-- Update mode badge and player count
	self:updateModeBadge(gameMode)
	self:updatePlayerCount(playerCount)

	-- Hide match countdown initially
	self.matchCountdownLabel.Visible = false

	-- Handle InProgress state
	if roomState == "InProgress" then
		self.inProgressOverlay.Visible = true
	else
		self.inProgressOverlay.Visible = false
	end

	self.mainFrame.Size = UDim2.new(0, 580, 0, 520)
	self.mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	self.mainFrame.Visible = true

	-- Show all children
	for _, child in ipairs(self.mainFrame:GetDescendants()) do
		if child:IsA("GuiObject") then
			child.Visible = true
		end
	end

	-- Re-hide InProgress overlay if not needed
	if roomState ~= "InProgress" then
		self.inProgressOverlay.Visible = false
	end

	-- Re-apply tab filter
	self:switchTab(self.activeTab)
	self:updateOrderBadges()

	-- Fade in
	self.mainFrame.BackgroundTransparency = 1
	local fadeIn = TweenService:Create(self.mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.15
	})
	fadeIn:Play()
end

function StageSelectionUI:hide()
	if not self.isVisible then return end
	self.isVisible = false
	self.currentRoomId = nil

	-- Fade out
	local fadeOut = TweenService:Create(self.mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1
	})
	fadeOut:Play()
	fadeOut.Completed:Connect(function()
		self.mainFrame.Visible = false
	end)
end

-- Reset vote buttons to default state
function StageSelectionUI:resetVoteUI()
	self.hasVoted = false
	self.selectedStages = {}

	-- Reset all stage buttons
	for i = 1, StageInfo.getTotalStageCount() do
		self:updateButtonState(i, false)
	end
	self:updateSelectedLabel()
	self:updateTabCounts()
	self:updateOrderBadges()

	-- Reset buttons to votable state
	if self.startButton then
		self.startButton.Text = "\u{1F680} VOTE"
		self.startButton.Active = false
		self.startButton.BackgroundColor3 = Color3.fromRGB(40, 80, 50)
		self.startButton.TextTransparency = 0.4
	end
	if self.randomButton then
		self.randomButton.Text = "\u{1F3B2} RANDOM VOTE"
		self.randomButton.Active = true
		self.randomButton.TextTransparency = 0
	end
end

function StageSelectionUI:toggleStage(stageNum: number)
	if self.hasVoted then return end -- Can't change after voting

	local index = table.find(self.selectedStages, stageNum)
	local buttonData = self.stageButtons[stageNum]
	if not buttonData then return end

	if index then
		-- Remove from selection
		table.remove(self.selectedStages, index)
		self:updateButtonState(stageNum, false)
	elseif #self.selectedStages >= Config.Stages.SelectionCount then
		-- Max selection reached
		return
	else
		-- Add to selection
		table.insert(self.selectedStages, stageNum)
		self:updateButtonState(stageNum, true)

		-- Pulse animation
		local pulse = TweenService:Create(buttonData.button, TweenInfo.new(0.2, Enum.EasingStyle.Elastic), {
			Size = UDim2.new(1.15, 0, 1.15, 0),
			Position = UDim2.new(-0.075, 0, -0.075, 0)
		})
		pulse:Play()
		pulse.Completed:Connect(function()
			local returnTween = TweenService:Create(buttonData.button, TweenInfo.new(0.2), {
				Size = UDim2.new(1, 0, 1, 0),
				Position = UDim2.new(0, 0, 0, 0)
			})
			returnTween:Play()
		end)
	end

	self:updateSelectedLabel()
	self:updateTabCounts()
	self:updateOrderBadges()
end

function StageSelectionUI:updateOrderBadges()
	-- Clear all badges
	for _, btnData in pairs(self.stageButtons) do
		if btnData.orderBadge then
			btnData.orderBadge.Visible = false
			btnData.orderBadge.Text = ""
		end
	end

	-- Show badges for selected stages with position number
	for order, stageNum in ipairs(self.selectedStages) do
		local btnData = self.stageButtons[stageNum]
		if btnData and btnData.orderBadge then
			btnData.orderBadge.Text = tostring(order)
			btnData.orderBadge.Visible = true
		end
	end
end

function StageSelectionUI:updateButtonState(stageNum: number, isSelected: boolean)
	local buttonData = self.stageButtons[stageNum]
	if not buttonData then return end

	if isSelected then
		buttonData.button.BackgroundTransparency = 0
		buttonData.indicator.Visible = true
		buttonData.stroke.Thickness = 3
		buttonData.stroke.Transparency = 0.2

		-- Glow effect
		local glowTween = TweenService:Create(buttonData.stroke, TweenInfo.new(0.3), {
			Thickness = 4,
			Transparency = 0
		})
		glowTween:Play()
	else
		buttonData.button.BackgroundTransparency = 0.2
		buttonData.indicator.Visible = false
		buttonData.stroke.Thickness = 2
		buttonData.stroke.Transparency = 0.6
		if buttonData.orderBadge then
			buttonData.orderBadge.Visible = false
		end
	end

	self:updateStartButtonState()
end

function StageSelectionUI:updateSelectedLabel()
	if #self.selectedStages == 0 then
		self.selectedLabel.Text = "\u{2728} Selected: (none)"
	else
		local orderText = table.concat(self.selectedStages, " \u{2192} ")

		-- Calculate total rewards
		local totalRewards = 0
		for _, sNum in ipairs(self.selectedStages) do
			local sData = StageInfo.getStage(sNum)
			totalRewards = totalRewards + (sData and sData.reward or 0)
		end

		self.selectedLabel.Text = "\u{2728} " .. orderText .. "  |  \u{1F4B0} +" .. totalRewards .. " rewards"
	end

	self:updateStartButtonState()
end

function StageSelectionUI:updateStartButtonState()
	if not self.startButton then return end
	if self.hasVoted then return end -- Don't change if already voted

	local hasSelection = #self.selectedStages > 0

	if hasSelection then
		self.startButton.Active = true

		local enableTween = TweenService:Create(self.startButton, TweenInfo.new(0.2), {
			BackgroundColor3 = Color3.fromRGB(55, 195, 95),
			BackgroundTransparency = 0,
			TextTransparency = 0
		})
		enableTween:Play()

		if self.startStroke then
			TweenService:Create(self.startStroke, TweenInfo.new(0.2), {
				Transparency = 0.2
			}):Play()
		end
	else
		self.startButton.Active = false

		local disableTween = TweenService:Create(self.startButton, TweenInfo.new(0.2), {
			BackgroundColor3 = Color3.fromRGB(40, 80, 50),
			TextTransparency = 0.4
		})
		disableTween:Play()

		if self.startStroke then
			TweenService:Create(self.startStroke, TweenInfo.new(0.2), {
				Transparency = 0.8
			}):Play()
		end
	end
end

function StageSelectionUI:clearSelection()
	if self.hasVoted then return end

	self.selectedStages = {}

	for i = 1, StageInfo.getTotalStageCount() do
		self:updateButtonState(i, false)
	end

	self:updateSelectedLabel()
	self:updateTabCounts()
	self:updateOrderBadges()
end

-- Switch active difficulty tab
function StageSelectionUI:switchTab(difficulty: string)
	self.activeTab = difficulty

	-- Update tab visuals
	for diff, tab in pairs(self.tabButtons) do
		local stroke = self.tabStrokesMap[diff]
		if diff == difficulty then
			TweenService:Create(tab, TweenInfo.new(0.15), {
				BackgroundTransparency = 0.1,
			}):Play()
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.15), {
					Transparency = 0,
					Thickness = 2.5,
				}):Play()
			end
		else
			TweenService:Create(tab, TweenInfo.new(0.15), {
				BackgroundTransparency = 0.7,
			}):Play()
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.15), {
					Transparency = 0.7,
					Thickness = 1.5,
				}):Play()
			end
		end
	end

	self:refreshStageButtons()
end

-- Show/hide and reposition buttons for active tab
function StageSelectionUI:refreshStageButtons()
	local visibleStages = {}
	for i = 1, StageInfo.getTotalStageCount() do
		local btnData = self.stageButtons[i]
		if btnData and btnData.difficulty == self.activeTab then
			table.insert(visibleStages, i)
		end
	end

	-- Hide all buttons first
	for _, btnData in pairs(self.stageButtons) do
		btnData.container.Visible = false
	end

	-- Show and position visible buttons (centered)
	local columns = 4
	local count = #visibleStages
	local rowOffset = math.max(0, (columns - count) * 120 / 2)

	for idx, stageId in ipairs(visibleStages) do
		local btnData = self.stageButtons[stageId]
		btnData.container.Position = UDim2.new(0, rowOffset + (idx - 1) * 120, 0, 0)
		btnData.container.Visible = true
	end
end

-- Update tab labels with selection counts
function StageSelectionUI:updateTabCounts()
	for _, diff in ipairs({"Easy", "Normal", "Hard"}) do
		local count = 0
		for _, stageNum in ipairs(self.selectedStages) do
			local sd = StageInfo.getStage(stageNum)
			if sd and sd.difficulty == diff then
				count = count + 1
			end
		end
		local diffInfo = StageInfo.DifficultyInfo[diff]
		local label = diffInfo.label
		if count > 0 then
			label = label .. " (" .. count .. ")"
		end
		self.tabButtons[diff].Text = label
	end
end

function StageSelectionUI:confirmSelection(isRandom: boolean)
	if self.hasVoted then return end
	self.hasVoted = true

	-- Fire vote to server
	if isRandom then
		-- Random vote — let server pick random stages
		self.voteStagesRemote:FireServer({})
	else
		if #self.selectedStages == 0 then
			self.hasVoted = false
			return
		end
		self.voteStagesRemote:FireServer(self.selectedStages)
	end

	-- Update UI to show voted state
	if self.startButton then
		self.startButton.Text = "\u{2705} VOTED"
		self.startButton.Active = false
		TweenService:Create(self.startButton, TweenInfo.new(0.2), {
			BackgroundColor3 = Color3.fromRGB(60, 120, 70),
			TextTransparency = 0.2,
		}):Play()
	end
	if self.randomButton then
		self.randomButton.Text = "\u{2705} VOTED"
		self.randomButton.Active = false
		TweenService:Create(self.randomButton, TweenInfo.new(0.2), {
			BackgroundColor3 = Color3.fromRGB(100, 60, 60),
			TextTransparency = 0.2,
		}):Play()
	end
end

function StageSelectionUI:updateCountdown(data: {number: number, message: string})
	-- Reset state before showing
	self.countdownFrame.BackgroundTransparency = 0.4
	self.countdownFrame.Size = UDim2.new(0, 350, 0, 250)
	self.countdownFrame.Visible = true
	self.countdownNumber.Text = tostring(data.number)
	self.countdownMessage.Text = data.message

	-- Enhanced scale animation with rotation
	self.countdownNumber.TextSize = 80
	self.countdownNumber.Rotation = 0

	local scaleUp = TweenService:Create(self.countdownNumber, TweenInfo.new(0.15, Enum.EasingStyle.Elastic), {
		TextSize = 120,
		Rotation = 5
	})
	scaleUp:Play()

	scaleUp.Completed:Connect(function()
		local scaleDown = TweenService:Create(self.countdownNumber, TweenInfo.new(0.15, Enum.EasingStyle.Elastic), {
			TextSize = 100,
			Rotation = 0
		})
		scaleDown:Play()
	end)

	-- Color change based on number
	if data.number == 3 then
		self.countdownNumber.TextColor3 = Theme.ACCENT_CYAN
	elseif data.number == 2 then
		self.countdownNumber.TextColor3 = Theme.WARNING
	elseif data.number == 1 then
		self.countdownNumber.TextColor3 = Theme.SUCCESS
	end

	-- Hide after last countdown
	if data.number == 1 then
		task.delay(1, function()
			local fadeOut = TweenService:Create(self.countdownFrame, TweenInfo.new(0.3), {
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 300, 0, 200)
			})
			fadeOut:Play()
			fadeOut.Completed:Connect(function()
				self.countdownFrame.Visible = false
			end)
		end)
	end
end

return StageSelectionUI
