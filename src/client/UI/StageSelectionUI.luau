-- StageSelectionUI: GUI สำหรับเลือกลำดับด่าน (Modern Design)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local StageInfo = require(ReplicatedStorage.Shared.StageInfo)
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)
local AdaptiveLayout = require(ReplicatedStorage.Shared.AdaptiveLayout)

local PANEL_W = 580
local PANEL_H = 480

local StageSelectionUI = {}
StageSelectionUI.__index = StageSelectionUI

function StageSelectionUI.new(parent: ScreenGui)
	local self = setmetatable({}, StageSelectionUI)
	self.parent = parent
	self.selectedStages = {} :: {number}
	self.isVisible = false
	self.isVotingMode = false  -- Flag for multiplayer voting mode
	self.currentVotes = {}     -- Store votes from other players
	self.availableRooms = {}   -- Available rooms to join

	-- Remotes
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	self.showRemote = remotes:WaitForChild("ShowStageSelection")
	self.hideRemote = remotes:WaitForChild("HideStageSelection")
	self.confirmRemote = remotes:WaitForChild("ConfirmStageSelection")
	self.countdownRemote = remotes:WaitForChild("CountdownUpdate")

	-- Stage voting remotes
	self.voteStagesRemote = remotes:WaitForChild("VoteStages")
	self.stageVoteUpdateRemote = remotes:WaitForChild("StageVoteUpdate")

	-- Match remotes (for room list + joining)
	self.matchUpdateRemote = remotes:WaitForChild("MatchUpdate")
	self.joinMatchRemote = remotes:WaitForChild("JoinMatch")

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
	-- Background Blur (optional - can be added if needed)

	-- Main Frame with modern design
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "StageSelectionFrame"
	mainFrame.Size = UDim2.new(0, 580, 0, 480)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = Theme.BG_BASE
	mainFrame.BackgroundTransparency = 0.15
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = self.parent
	self.mainFrame = mainFrame

	-- Add gradient background (sky→green, top-to-bottom)
	local mainGrad = Instance.new("UIGradient")
	mainGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.PANEL_GRAD_TOP),
		ColorSequenceKeypoint.new(1, Theme.PANEL_GRAD_BTM),
	})
	mainGrad.Rotation = 180
	mainGrad.Parent = mainFrame

	-- Glow stroke
	local borderStroke = Instance.new("UIStroke")
	borderStroke.Color = Theme.ACCENT_CYAN
	borderStroke.Thickness = Theme.STROKE_MED
	borderStroke.Transparency = 0.5
	borderStroke.Parent = mainFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CORNER_LG
	corner.Parent = mainFrame

	-- Drop shadow
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 6, 1, 6)
	shadow.Position = UDim2.new(0, -3, 0, 4)
	shadow.BackgroundColor3 = Theme.CARD_SHADOW
	shadow.BackgroundTransparency = 0.7
	shadow.BorderSizePixel = 0
	shadow.ZIndex = mainFrame.ZIndex - 1
	shadow.Parent = mainFrame
	Theme.applyCorner(shadow, "lg")

	-- Title with gradient text effect
	local titleContainer = Instance.new("Frame")
	titleContainer.Name = "TitleContainer"
	titleContainer.Size = UDim2.new(1, -40, 0, 70)
	titleContainer.Position = UDim2.new(0, 20, 0, 20)
	titleContainer.BackgroundTransparency = 1
	titleContainer.Parent = mainFrame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 1, 0)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "🎮 SELECT STAGE ORDER"
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
	subtitle.Position = UDim2.new(0, 0, 0, 50)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Pick up to " .. Config.Stages.SelectionCount .. " stages, or press RANDOM"
	subtitle.TextColor3 = Theme.TEXT_MUTED
	subtitle.TextSize = 14
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextTransparency = 0.3
	subtitle.Parent = titleContainer

	-- Difficulty Tab Bar
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, -40, 0, 30)
	tabBar.Position = UDim2.new(0, 20, 0, 95)
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
	buttonsContainer.Position = UDim2.new(0, 20, 0, 135)
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
		badge.TextColor3 = Theme.TEXT_ON_ACCENT
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
		numberLabel.TextColor3 = Theme.TEXT_ON_ACCENT
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
		nameLabel.TextColor3 = Theme.TEXT_ON_ACCENT
		nameLabel.TextStrokeTransparency = 0.7
		nameLabel.Parent = button

		-- Stage Reward indicator
		local coinLabel = Instance.new("TextLabel")
		coinLabel.Name = "CoinLabel"
		coinLabel.Size = UDim2.new(1, 0, 0, 14)
		coinLabel.Position = UDim2.new(0, 0, 0, 84)
		coinLabel.BackgroundTransparency = 1
		coinLabel.Text = "💰 +" .. stageData.reward
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
		orderBadge.TextColor3 = Theme.TEXT_ON_ACCENT
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
	selectedContainer.Position = UDim2.new(0, 20, 0, 350)
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
	selectedLabel.Text = "✨ Selected: (none)"
	selectedLabel.TextColor3 = Theme.TEXT_MUTED
	selectedLabel.TextSize = 16
	selectedLabel.Font = Enum.Font.Gotham
	selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
	selectedLabel.Parent = selectedContainer
	self.selectedLabel = selectedLabel

	-- Clear Button (modern design)
	local clearButton = Instance.new("TextButton")
	clearButton.Name = "ClearButton"
	clearButton.Size = UDim2.new(0, 110, 0, 48)
	clearButton.Position = UDim2.new(1, -130, 0, 355)
	clearButton.BackgroundColor3 = Theme.BG_ELEVATED
	clearButton.BorderSizePixel = 0
	clearButton.Text = "🗑️ Clear"
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

	-- Random Button (modern gradient design)
	local randomButton = Instance.new("TextButton")
	randomButton.Name = "RandomButton"
	randomButton.Size = UDim2.new(0, 170, 0, 56)
	randomButton.Position = UDim2.new(0, 20, 0, 410)
	randomButton.BackgroundColor3 = Color3.fromRGB(255, 95, 85)
	randomButton.BackgroundTransparency = 0
	randomButton.BorderSizePixel = 0
	randomButton.Text = "\u{1F3B2} RANDOM"
	randomButton.TextColor3 = Theme.TEXT_ON_ACCENT
	randomButton.TextSize = 20
	randomButton.Font = Enum.Font.GothamBold
	randomButton.TextStrokeTransparency = 0.3
	randomButton.TextStrokeColor3 = Color3.fromRGB(120, 30, 30)
	randomButton.ZIndex = 10
	randomButton.Parent = mainFrame

	Theme.applyCorner(randomButton, "sm")

	local randomStroke = Instance.new("UIStroke")
	randomStroke.Color = Color3.fromRGB(255, 140, 130)
	randomStroke.Thickness = Theme.STROKE_MED
	randomStroke.Transparency = 0.1
	randomStroke.Parent = randomButton

	randomButton.MouseButton1Click:Connect(function()
		self:confirmSelection(true)
	end)

	-- Start Button (modern gradient design)
	local startButton = Instance.new("TextButton")
	startButton.Name = "StartButton"
	startButton.Size = UDim2.new(0, 170, 0, 56)
	startButton.Position = UDim2.new(1, -190, 0, 410)
	startButton.BackgroundColor3 = Color3.fromRGB(55, 195, 95)
	startButton.BackgroundTransparency = 0
	startButton.BorderSizePixel = 0
	startButton.Text = "\u{1F680} START"
	startButton.TextColor3 = Theme.TEXT_ON_ACCENT
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

	-- เริ่มต้น disable ปุ่ม Start — ใช้สีเข้มแทน transparency เพื่อไม่ให้พื้นหลังม่วงทะลุ
	startButton.Active = false
	startButton.BackgroundColor3 = Color3.fromRGB(200, 208, 218)
	startButton.TextTransparency = 0.4
	if startStroke then
		startStroke.Transparency = 0.8
	end

	startButton.MouseButton1Click:Connect(function()
		if startButton.Active then
			self:confirmSelection(false)
		end
	end)

	-- Countdown Frame (modern design) - อยู่ตรงกลางหน้าจอ
	local countdownFrame = Instance.new("Frame")
	countdownFrame.Name = "CountdownFrame"
	countdownFrame.Size = UDim2.new(0, 350, 0, 250)
	countdownFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	countdownFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	countdownFrame.BackgroundColor3 = Theme.BG_BASE
	countdownFrame.BackgroundTransparency = 0.4
	countdownFrame.BorderSizePixel = 0
	countdownFrame.Visible = false
	countdownFrame.ZIndex = 100 -- ให้อยู่ด้านบนสุด
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
	countdownNumber.TextColor3 = Theme.TEXT_ON_ACCENT
	countdownNumber.TextSize = 120
	countdownNumber.Font = Enum.Font.GothamBold
	countdownNumber.TextStrokeTransparency = 0 -- stroke ชัดเต็มที่
	countdownNumber.TextStrokeColor3 = Color3.fromRGB(0, 0, 0) -- สีดำให้ตัดกับตัวอักษร
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
	countdownMessage.TextColor3 = Theme.TEXT_ON_ACCENT
	countdownMessage.TextSize = 24
	countdownMessage.Font = Enum.Font.GothamBold
	countdownMessage.TextStrokeTransparency = 0
	countdownMessage.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	countdownMessage.TextXAlignment = Enum.TextXAlignment.Center
	countdownMessage.ZIndex = 101
	countdownMessage.Parent = countdownFrame
	self.countdownMessage = countdownMessage

	-- Available Rooms Banner (shows when rooms exist)
	local roomsBanner = Instance.new("Frame")
	roomsBanner.Name = "RoomsBanner"
	roomsBanner.Size = UDim2.new(1, 0, 0, 50)
	roomsBanner.Position = UDim2.new(0, 0, 0, -45)
	roomsBanner.BackgroundColor3 = Theme.ACCENT_CYAN
	roomsBanner.BackgroundTransparency = 0.15
	roomsBanner.BorderSizePixel = 0
	roomsBanner.Visible = false
	roomsBanner.Parent = mainFrame
	self.roomsBanner = roomsBanner

	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = Theme.CORNER_SM
	bannerCorner.Parent = roomsBanner

	local bannerStroke = Instance.new("UIStroke")
	bannerStroke.Color = Theme.ACCENT_CYAN
	bannerStroke.Thickness = Theme.STROKE_THIN
	bannerStroke.Transparency = 0.3
	bannerStroke.Parent = roomsBanner

	local bannerLabel = Instance.new("TextLabel")
	bannerLabel.Name = "BannerLabel"
	bannerLabel.Size = UDim2.new(1, -120, 1, 0)
	bannerLabel.Position = UDim2.new(0, 12, 0, 0)
	bannerLabel.BackgroundTransparency = 1
	bannerLabel.Text = "1 room waiting..."
	bannerLabel.TextColor3 = Theme.TEXT_ON_ACCENT
	bannerLabel.TextSize = 14
	bannerLabel.Font = Enum.Font.GothamBold
	bannerLabel.TextXAlignment = Enum.TextXAlignment.Left
	bannerLabel.Parent = roomsBanner
	self.roomsBannerLabel = bannerLabel

	local joinBtn = Instance.new("TextButton")
	joinBtn.Name = "JoinRoomBtn"
	joinBtn.Size = UDim2.new(0, 100, 0, 48)
	joinBtn.Position = UDim2.new(1, -100, 0.5, 0)
	joinBtn.AnchorPoint = Vector2.new(0, 0.5)
	joinBtn.BackgroundColor3 = Theme.SUCCESS
	joinBtn.BorderSizePixel = 0
	joinBtn.Text = "JOIN"
	joinBtn.TextColor3 = Theme.TEXT_ON_ACCENT
	joinBtn.TextSize = 14
	joinBtn.Font = Enum.Font.GothamBold
	joinBtn.Parent = roomsBanner
	self.joinRoomBtn = joinBtn

	local joinCorner = Instance.new("UICorner")
	joinCorner.CornerRadius = UDim.new(0, 6)
	joinCorner.Parent = joinBtn

	joinBtn.MouseButton1Click:Connect(function()
		if #self.availableRooms > 0 then
			local roomId = self.availableRooms[1].id
			self.joinMatchRemote:FireServer(roomId)
			self:hide()
		end
	end)

	-- Responsive scaling (Phase 3)
	AdaptiveLayout.applyScale(self.mainFrame, PANEL_W, PANEL_H)
	self.uiScale = self.mainFrame:FindFirstChild("AdaptiveScale")

	-- Initialize default tab
	self:switchTab("Easy")
end

function StageSelectionUI:setupRemotes()
	self.showRemote.OnClientEvent:Connect(function()
		self:show()
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

	-- Room list updates (available rooms to join)
	self.matchUpdateRemote.OnClientEvent:Connect(function(data)
		if data.type == "roomList" then
			self:updateAvailableRooms(data.rooms)
		end
	end)
end

-- Handle stage vote update from server
function StageSelectionUI:onStageVoteUpdate(data)
	if data.type == "voteUpdate" then
		self.currentVotes = data.votes
		self:updateVotesDisplay()
	end
end

-- Update votes display (show other players' votes)
function StageSelectionUI:updateVotesDisplay()
	-- For now, just update the subtitle to show vote count
	-- In a full implementation, you'd show each player's vote
	local subtitle = self.mainFrame:FindFirstChild("TitleContainer")
	if subtitle then
		local subtitleLabel = subtitle:FindFirstChild("Subtitle")
		if subtitleLabel then
			-- This would be enhanced to show actual votes
			-- For now, just indicate voting is happening
		end
	end
end

function StageSelectionUI:show()
	if self.isVisible then return end
	self.isVisible = true

	-- Reset state
	self.mainFrame.Size = UDim2.new(0, 580, 0, 480)
	self.mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	self.mainFrame.Visible = true

	-- Fade in จากโปร่งใส
	for _, child in ipairs(self.mainFrame:GetDescendants()) do
		if child:IsA("GuiObject") then
			child.Visible = true
		end
	end

	-- Re-apply tab filter (show() sets all Visible=true above)
	self:switchTab(self.activeTab)
	self:updateOrderBadges()

	-- Show/hide rooms banner based on actual room data
	if self.roomsBanner then
		self.roomsBanner.Visible = #self.availableRooms > 0
	end

	-- Simple fade in
	self.mainFrame.BackgroundTransparency = 1
	local fadeIn = TweenService:Create(self.mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.15
	})
	fadeIn:Play()

	-- Scale-in animation (POLISH-01)
	if self.uiScale then
		local targetScale = self.uiScale.Scale
		self.uiScale.Scale = targetScale * 0.8
		TweenService:Create(self.uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = targetScale
		}):Play()
	end
end

function StageSelectionUI:hide()
	if not self.isVisible then return end
	self.isVisible = false

	-- Hide rooms banner
	if self.roomsBanner then
		self.roomsBanner.Visible = false
	end

	-- Simple fade out
	local fadeOut = TweenService:Create(self.mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1
	})
	fadeOut:Play()
	fadeOut.Completed:Connect(function()
		self.mainFrame.Visible = false
	end)
end

function StageSelectionUI:toggleStage(stageNum: number)
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

	-- อัพเดทสถานะปุ่ม Start
	self:updateStartButtonState()
end

function StageSelectionUI:updateSelectedLabel()
	if #self.selectedStages == 0 then
		self.selectedLabel.Text = "✨ Selected: (none)"
	else
		local orderText = table.concat(self.selectedStages, " → ")

		-- คำนวณ total rewards
		local totalRewards = 0
		for _, sNum in ipairs(self.selectedStages) do
			local sData = StageInfo.getStage(sNum)
			totalRewards = totalRewards + (sData and sData.reward or 0)
		end

		self.selectedLabel.Text = "✨ " .. orderText .. "  |  💰 +" .. totalRewards .. " rewards"
	end

	-- อัพเดทสถานะปุ่ม Start
	self:updateStartButtonState()
end

function StageSelectionUI:updateStartButtonState()
	if not self.startButton then return end

	local hasSelection = #self.selectedStages > 0

	if hasSelection then
		-- Enable ปุ่ม Start
		self.startButton.Active = true

		-- Animation - enable button
		local enableTween = TweenService:Create(self.startButton, TweenInfo.new(0.2), {
			BackgroundColor3 = Color3.fromRGB(55, 195, 95),
			BackgroundTransparency = 0,
			TextTransparency = 0
		})
		enableTween:Play()

		-- Enable stroke
		if self.startStroke then
			local strokeTween = TweenService:Create(self.startStroke, TweenInfo.new(0.2), {
				Transparency = 0.2
			})
			strokeTween:Play()
		end
	else
		-- Disable ปุ่ม Start — ใช้สีเข้มแทน transparency
		self.startButton.Active = false

		-- Animation - disable button (เปลี่ยนสีเป็นเขียวเข้ม)
		local disableTween = TweenService:Create(self.startButton, TweenInfo.new(0.2), {
			BackgroundColor3 = Color3.fromRGB(200, 208, 218),
			TextTransparency = 0.4
		})
		disableTween:Play()

		-- Disable stroke
		if self.startStroke then
			local strokeTween = TweenService:Create(self.startStroke, TweenInfo.new(0.2), {
				Transparency = 0.8
			})
			strokeTween:Play()
		end
	end
end

function StageSelectionUI:clearSelection()
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
			-- Active tab
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
			-- Inactive tab
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

	-- Refresh button visibility
	self:refreshStageButtons()
end

-- Show/hide and reposition buttons for active tab
function StageSelectionUI:refreshStageButtons()
	-- Collect visible stages for active tab
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

	-- Show and position visible buttons (centered, multi-row support)
	local columns = 4
	local cardSpacing = 120
	local rowHeight = 115
	local count = #visibleStages

	for idx, stageId in ipairs(visibleStages) do
		local btnData = self.stageButtons[stageId]
		local row = math.floor((idx - 1) / columns)
		local col = (idx - 1) % columns
		local rowCount = math.min(columns, count - row * columns)
		local rowOffset = math.max(0, (columns - rowCount) * cardSpacing / 2)
		btnData.container.Position = UDim2.new(0, rowOffset + col * cardSpacing, 0, row * rowHeight)
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
	if isRandom then
		-- Send random request
		self.confirmRemote:FireServer({
			isRandom = true
		})
	else
		-- ตรวจสอบว่าต้องเลือก stage ก่อน
		if #self.selectedStages == 0 then
			-- ไม่ส่งอะไร ถ้ายังไม่เลือก (ปุ่ม Start จะ disable อยู่แล้ว)
			return
		else
			-- Send custom order
			self.confirmRemote:FireServer({
				isRandom = false,
				stageOrder = self.selectedStages
			})

			-- Also send vote for multiplayer matches (server will ignore if not in a match)
			self.voteStagesRemote:FireServer(self.selectedStages)
		end
	end

	-- Hide selection UI
	self:hide()
end

function StageSelectionUI:updateCountdown(data: {number: number, message: string})
	-- Reset state ก่อนแสดง ป้องกัน stale state จาก round ก่อน
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

	-- Color change based on number (gameplay indicator - blue/yellow/green)
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

-- Update available rooms display
function StageSelectionUI:updateAvailableRooms(rooms)
	self.availableRooms = rooms or {}

	if #self.availableRooms > 0 then
		local room = self.availableRooms[1]
		local isRacing = (room.state == "Racing" or room.state == "Starting")

		if isRacing then
			self.roomsBannerLabel.Text = string.format(
				"Match in progress (%d players)",
				room.playerCount
			)
			self.joinRoomBtn.Text = "SPECTATE"
			self.roomsBanner.BackgroundColor3 = Theme.WARNING
		else
			self.roomsBannerLabel.Text = string.format(
				"%s's room (%d/%d)",
				room.hostName, room.playerCount, room.maxPlayers
			)
			self.joinRoomBtn.Text = "JOIN"
			self.roomsBanner.BackgroundColor3 = Theme.ACCENT_CYAN
		end
		self.roomsBanner.Visible = self.isVisible
	else
		self.roomsBanner.Visible = false
	end
end

return StageSelectionUI
