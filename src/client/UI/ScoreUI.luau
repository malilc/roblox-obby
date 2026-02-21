-- ScoreUI: แสดงคะแนนแบบ Colorful Youth Style (Vivid Gradient)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.ThemeConfig)
local UIFactory = require(script.Parent.UIFactory)

local LocalPlayer = Players.LocalPlayer

local ScoreUI = {}
ScoreUI.__index = ScoreUI

-- Helper: create drop shadow under a pill
local function createDropShadow(pill: Frame)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 4, 1, 4)
	shadow.Position = UDim2.new(0, -2, 0, 3)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.7
	shadow.BorderSizePixel = 0
	shadow.ZIndex = pill.ZIndex - 1
	shadow.Parent = pill

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = Theme.CORNER_LG
	shadowCorner.Parent = shadow
end

function ScoreUI.new(parent: ScreenGui)
	local self = setmetatable({}, ScoreUI)

	self.parent = parent
	self.roundScore = 0
	self.currentStage = 0
	self.totalStages = 5
	self.highScore = 0
	self.totalScore = 0

	self:createUI()

	return self
end

function ScoreUI:createUI()
	-- === SCORE FRAME (มุมบนซ้าย) - Vivid Cyan Gradient ===
	local scoreFrame = UIFactory.createPanel(self.parent, {
		name = "ScoreFrame",
		size = UDim2.new(0, 130, 0, 44),
		position = UDim2.new(0, 10, 0, 10),
		bgColor = Theme.HUD_SCORE_START,
		bgTransparency = 0.15,
		cornerSize = "lg",
		strokeColor = Theme.HUD_GLOW_CYAN,
		strokeWeight = "med",
		strokeTransparency = 0.2,
	})
	self.scoreFrame = scoreFrame
	self.frameStroke = scoreFrame:FindFirstChildOfClass("UIStroke")

	-- Vivid cyan→blue gradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.HUD_SCORE_START),
		ColorSequenceKeypoint.new(1, Theme.HUD_SCORE_END)
	})
	gradient.Rotation = 135
	gradient.Parent = scoreFrame

	-- Drop shadow
	createDropShadow(scoreFrame)

	-- Score Icon Container
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(0, 36, 0, 36)
	iconContainer.Position = UDim2.new(0, 4, 0.5, -18)
	iconContainer.BackgroundTransparency = 1
	iconContainer.Parent = scoreFrame
	self.iconContainer = iconContainer

	-- Score Icon Background (star circle)
	local scoreIcon = Instance.new("Frame")
	scoreIcon.Name = "ScoreIcon"
	scoreIcon.Size = UDim2.new(1, 0, 1, 0)
	scoreIcon.Position = UDim2.new(0, 0, 0, 0)
	scoreIcon.BackgroundColor3 = Theme.ACCENT_CYAN
	scoreIcon.BorderSizePixel = 0
	scoreIcon.Parent = iconContainer
	self.scoreIcon = scoreIcon

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = Theme.CORNER_FULL
	iconCorner.Parent = scoreIcon

	-- Icon gradient (vivid 3D)
	local iconGradient = Instance.new("UIGradient")
	iconGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 250, 255)),
		ColorSequenceKeypoint.new(0.5, Theme.ACCENT_CYAN),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 100, 220))
	})
	iconGradient.Rotation = 135
	iconGradient.Parent = scoreIcon

	-- Star symbol
	local starSymbol = Instance.new("TextLabel")
	starSymbol.Name = "StarSymbol"
	starSymbol.Size = UDim2.new(1, 0, 1, 0)
	starSymbol.Position = UDim2.new(0, 0, 0, 0)
	starSymbol.BackgroundTransparency = 1
	starSymbol.Text = "⭐"
	starSymbol.TextSize = 20
	starSymbol.Parent = scoreIcon

	-- Icon stroke (vivid glow)
	local iconStroke = Instance.new("UIStroke")
	iconStroke.Color = Color3.fromRGB(30, 80, 200)
	iconStroke.Thickness = Theme.STROKE_MED
	iconStroke.Parent = scoreIcon

	-- Score Number
	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "ScoreLabel"
	scoreLabel.Size = UDim2.new(1, -48, 1, 0)
	scoreLabel.Position = UDim2.new(0, 44, 0, 0)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Text = "0"
	scoreLabel.TextColor3 = Theme.TEXT_PRIMARY
	scoreLabel.TextSize = 22
	scoreLabel.Font = Enum.Font.GothamBlack
	scoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	scoreLabel.Parent = scoreFrame
	self.roundScoreLabel = scoreLabel

	-- Bold text stroke for visibility
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(15, 50, 150)
	textStroke.Thickness = 2
	textStroke.Transparency = 0.3
	textStroke.Parent = scoreLabel

	-- === HIGH SCORE FRAME (ข้าง Score) - Purple→Pink Gradient ===
	local highScoreFrame = Instance.new("Frame")
	highScoreFrame.Name = "HighScoreFrame"
	highScoreFrame.Size = UDim2.new(0, 100, 0, 32)
	highScoreFrame.Position = UDim2.new(0, 145, 0, 16)
	highScoreFrame.BackgroundColor3 = Theme.ACCENT_PINK
	highScoreFrame.BackgroundTransparency = 0.15
	highScoreFrame.BorderSizePixel = 0
	highScoreFrame.Parent = self.parent
	self.highScoreFrame = highScoreFrame

	local hsCorner = Instance.new("UICorner")
	hsCorner.CornerRadius = Theme.CORNER_LG
	hsCorner.Parent = highScoreFrame

	-- Purple→Pink Gradient
	local hsGradient = Instance.new("UIGradient")
	hsGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 80, 200)),
		ColorSequenceKeypoint.new(1, Theme.ACCENT_PINK)
	})
	hsGradient.Rotation = 135
	hsGradient.Parent = highScoreFrame

	-- High Score Glow Stroke
	local hsStroke = Instance.new("UIStroke")
	hsStroke.Color = Theme.ACCENT_PINK
	hsStroke.Thickness = Theme.STROKE_MED
	hsStroke.Transparency = 0.3
	hsStroke.Parent = highScoreFrame

	-- Drop shadow
	createDropShadow(highScoreFrame)

	-- Trophy Icon
	local trophyIcon = Instance.new("TextLabel")
	trophyIcon.Name = "TrophyIcon"
	trophyIcon.Size = UDim2.new(0, 28, 1, 0)
	trophyIcon.Position = UDim2.new(0, 4, 0, 0)
	trophyIcon.BackgroundTransparency = 1
	trophyIcon.Text = "🏆"
	trophyIcon.TextSize = 16
	trophyIcon.Parent = highScoreFrame

	-- High Score Number
	local highScoreLabel = Instance.new("TextLabel")
	highScoreLabel.Name = "HighScoreLabel"
	highScoreLabel.Size = UDim2.new(1, -36, 1, 0)
	highScoreLabel.Position = UDim2.new(0, 32, 0, 0)
	highScoreLabel.BackgroundTransparency = 1
	highScoreLabel.Text = "0"
	highScoreLabel.TextColor3 = Theme.TEXT_PRIMARY
	highScoreLabel.TextSize = 16
	highScoreLabel.Font = Enum.Font.GothamBold
	highScoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	highScoreLabel.Parent = highScoreFrame
	self.highScoreLabel = highScoreLabel

	-- HS text stroke
	local hsTextStroke = Instance.new("UIStroke")
	hsTextStroke.Color = Color3.fromRGB(80, 30, 120)
	hsTextStroke.Thickness = 1.5
	hsTextStroke.Transparency = 0.3
	hsTextStroke.Parent = highScoreLabel

	-- === STAGE PROGRESS (ใต้ Score) ===
	local stageFrame = Instance.new("Frame")
	stageFrame.Name = "StageFrame"
	stageFrame.Size = UDim2.new(0, 160, 0, 28)
	stageFrame.Position = UDim2.new(0, 10, 0, 58)
	stageFrame.BackgroundColor3 = Theme.BG_OVERLAY
	stageFrame.BackgroundTransparency = 0.3
	stageFrame.BorderSizePixel = 0
	stageFrame.Parent = self.parent
	self.stageFrame = stageFrame

	local stageCorner = Instance.new("UICorner")
	stageCorner.CornerRadius = Theme.CORNER_LG
	stageCorner.Parent = stageFrame

	-- Stage Gradient
	local stageGradient = Instance.new("UIGradient")
	stageGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.BG_SURFACE),
		ColorSequenceKeypoint.new(1, Theme.BG_OVERLAY)
	})
	stageGradient.Rotation = 45
	stageGradient.Parent = stageFrame

	-- Stage Glow Stroke
	local stageStroke = Instance.new("UIStroke")
	stageStroke.Color = Theme.SUCCESS
	stageStroke.Thickness = Theme.STROKE_MED
	stageStroke.Transparency = 0.4
	stageStroke.Parent = stageFrame

	-- Stage Icon
	local stageIcon = Instance.new("TextLabel")
	stageIcon.Name = "StageIcon"
	stageIcon.Size = UDim2.new(0, 24, 1, 0)
	stageIcon.Position = UDim2.new(0, 4, 0, 0)
	stageIcon.BackgroundTransparency = 1
	stageIcon.Text = "🚩"
	stageIcon.TextSize = 14
	stageIcon.Parent = stageFrame

	-- Hide by default
	stageFrame.Visible = false

	-- Drop shadow
	createDropShadow(stageFrame)

	-- Stage Progress Bar Background
	local progressBg = Instance.new("Frame")
	progressBg.Name = "ProgressBg"
	progressBg.Size = UDim2.new(0, 85, 0, 12)
	progressBg.Position = UDim2.new(0, 30, 0.5, -6)
	progressBg.BackgroundColor3 = Theme.BG_ELEVATED
	progressBg.BorderSizePixel = 0
	progressBg.Parent = stageFrame

	local progressBgCorner = Instance.new("UICorner")
	progressBgCorner.CornerRadius = Theme.CORNER_SM
	progressBgCorner.Parent = progressBg

	-- Stage Progress Bar Fill (vivid green→lime gradient)
	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.Position = UDim2.new(0, 0, 0, 0)
	progressFill.BackgroundColor3 = Theme.SUCCESS
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBg
	self.progressFill = progressFill

	local progressFillCorner = Instance.new("UICorner")
	progressFillCorner.CornerRadius = Theme.CORNER_SM
	progressFillCorner.Parent = progressFill

	-- Vivid green→lime gradient
	local progressGradient = Instance.new("UIGradient")
	progressGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 255, 150)),
		ColorSequenceKeypoint.new(1, Theme.SUCCESS)
	})
	progressGradient.Rotation = 0
	progressGradient.Parent = progressFill

	-- Stage Text
	local stageLabel = Instance.new("TextLabel")
	stageLabel.Name = "StageLabel"
	stageLabel.Size = UDim2.new(0, 40, 1, 0)
	stageLabel.Position = UDim2.new(0, 118, 0, 0)
	stageLabel.BackgroundTransparency = 1
	stageLabel.Text = "0/5"
	stageLabel.TextColor3 = Theme.SUCCESS
	stageLabel.TextSize = 13
	stageLabel.Font = Enum.Font.GothamBold
	stageLabel.TextXAlignment = Enum.TextXAlignment.Center
	stageLabel.Parent = stageFrame
	self.stageLabel = stageLabel

	-- === MATCH TIMER (บนกลางหน้าจอ) - Gradient ===
	local timerFrame = Instance.new("Frame")
	timerFrame.Name = "TimerFrame"
	timerFrame.Size = UDim2.new(0, 120, 0, 40)
	timerFrame.Position = UDim2.new(0.5, -60, 0, 10)
	timerFrame.BackgroundColor3 = Theme.BG_BASE
	timerFrame.BackgroundTransparency = 0.2
	timerFrame.BorderSizePixel = 0
	timerFrame.Visible = false
	timerFrame.Parent = self.parent
	self.timerFrame = timerFrame

	local timerCorner = Instance.new("UICorner")
	timerCorner.CornerRadius = Theme.CORNER_LG
	timerCorner.Parent = timerFrame

	-- Timer gradient
	local timerGradient = Instance.new("UIGradient")
	timerGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.BG_SURFACE),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 30, 100))
	})
	timerGradient.Rotation = 135
	timerGradient.Parent = timerFrame

	local timerStroke = Instance.new("UIStroke")
	timerStroke.Color = Theme.HUD_GLOW_CYAN
	timerStroke.Thickness = Theme.STROKE_MED
	timerStroke.Transparency = 0.3
	timerStroke.Parent = timerFrame
	self.timerStroke = timerStroke

	-- Drop shadow
	createDropShadow(timerFrame)

	local timerIcon = Instance.new("TextLabel")
	timerIcon.Name = "TimerIcon"
	timerIcon.Size = UDim2.new(0, 28, 1, 0)
	timerIcon.Position = UDim2.new(0, 4, 0, 0)
	timerIcon.BackgroundTransparency = 1
	timerIcon.Text = "⏱"
	timerIcon.TextSize = 20
	timerIcon.Parent = timerFrame

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerLabel"
	timerLabel.Size = UDim2.new(1, -36, 1, 0)
	timerLabel.Position = UDim2.new(0, 32, 0, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = "15:00"
	timerLabel.TextColor3 = Theme.TEXT_PRIMARY
	timerLabel.TextSize = 20
	timerLabel.Font = Enum.Font.GothamBold
	timerLabel.TextXAlignment = Enum.TextXAlignment.Center
	timerLabel.Parent = timerFrame
	self.timerLabel = timerLabel

	-- Timer text stroke
	local timerTextStroke = Instance.new("UIStroke")
	timerTextStroke.Color = Color3.fromRGB(20, 10, 60)
	timerTextStroke.Thickness = 1.5
	timerTextStroke.Transparency = 0.3
	timerTextStroke.Parent = timerLabel
end

function ScoreUI:updateScore(data: {[string]: any})
	if data.roundScore then
		local oldScore = self.roundScore
		self.roundScore = data.roundScore
		self.roundScoreLabel.Text = tostring(self.roundScore)

		-- Score pop animation
		if data.roundScore > oldScore then
			self:playScoreAnimation()
		end
	end

	if data.currentStage then
		self.currentStage = data.currentStage

		-- Update total stages if provided
		if data.totalStages then
			self.totalStages = data.totalStages
		end

		-- Use completed stages for display (Stage 1 Start -> 0 completed)
		local displayStage = math.max(0, self.currentStage - 1)

		if data.isFinished then
			displayStage = self.totalStages
		end

		self.stageLabel.Text = displayStage .. "/" .. self.totalStages

		-- Update progress bar
		local progress = math.clamp(displayStage / self.totalStages, 0, 1)
		local targetWidth = 85 * progress

		local tween = TweenService:Create(self.progressFill, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
			Size = UDim2.new(0, targetWidth, 1, 0)
		})
		tween:Play()
	end

	if data.highScore then
		self.highScore = data.highScore
		self.highScoreLabel.Text = tostring(self.highScore)
	end

	if data.totalScore then
		self.totalScore = data.totalScore
	end
end

function ScoreUI:playScoreAnimation()
	-- Scale up score frame
	local originalSize = UDim2.new(0, 130, 0, 44)

	-- Frame scale animation
	local scaleUp = TweenService:Create(self.scoreFrame, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 145, 0, 50)
	})
	scaleUp:Play()

	-- Glow effect (brighter)
	local glowUp = TweenService:Create(self.frameStroke, TweenInfo.new(0.1), {
		Transparency = 0,
		Thickness = Theme.STROKE_BOLD
	})
	glowUp:Play()

	scaleUp.Completed:Connect(function()
		local scaleDown = TweenService:Create(self.scoreFrame, TweenInfo.new(0.15, Enum.EasingStyle.Bounce), {
			Size = originalSize
		})
		scaleDown:Play()

		local glowDown = TweenService:Create(self.frameStroke, TweenInfo.new(0.2), {
			Transparency = 0.2,
			Thickness = Theme.STROKE_MED
		})
		glowDown:Play()
	end)

	-- Flash score color
	self.roundScoreLabel.TextColor3 = Color3.fromRGB(255, 255, 200)
	task.delay(0.15, function()
		local colorTween = TweenService:Create(self.roundScoreLabel, TweenInfo.new(0.25), {
			TextColor3 = Theme.TEXT_PRIMARY
		})
		colorTween:Play()
	end)

	-- Icon bounce animation
	local iconBounce = TweenService:Create(self.iconContainer, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 42, 0, 42),
		Position = UDim2.new(0, 1, 0.5, -21)
	})
	iconBounce:Play()

	iconBounce.Completed:Connect(function()
		local iconReturn = TweenService:Create(self.iconContainer, TweenInfo.new(0.15, Enum.EasingStyle.Bounce), {
			Size = UDim2.new(0, 36, 0, 36),
			Position = UDim2.new(0, 4, 0.5, -18)
		})
		iconReturn:Play()
	end)
end

function ScoreUI:showStageComplete(stageIndex: number, isFinished: boolean?)
	-- Stage complete notification (modern design)
	local notification = Instance.new("Frame")
	notification.Name = "StageNotification"
	notification.Size = UDim2.new(0, 280, 0, 60)
	notification.Position = UDim2.new(0.5, -140, 0.25, 0)
	notification.BackgroundColor3 = Theme.BG_BASE
	notification.BackgroundTransparency = 0.1
	notification.BorderSizePixel = 0
	notification.Parent = self.parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CORNER_LG
	corner.Parent = notification

	-- Gradient
	local notifGradient = Instance.new("UIGradient")
	notifGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.BG_SURFACE),
		ColorSequenceKeypoint.new(1, Theme.BG_BASE)
	})
	notifGradient.Rotation = 45
	notifGradient.Parent = notification

	-- Icon
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(0, 50, 1, 0)
	icon.Position = UDim2.new(0, 5, 0, 0)
	icon.BackgroundTransparency = 1
	icon.TextSize = 32
	icon.Parent = notification

	-- Text
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -60, 1, 0)
	text.Position = UDim2.new(0, 55, 0, 0)
	text.BackgroundTransparency = 1
	text.TextSize = 20
	text.Font = Enum.Font.GothamBold
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Parent = notification

	if isFinished then
		icon.Text = "🎉"
		text.Text = "FINISH!"
		text.TextColor3 = Theme.PRIMARY

		-- Gold stroke
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.PRIMARY
		stroke.Thickness = Theme.STROKE_BOLD
		stroke.Transparency = 0.2
		stroke.Parent = notification
	else
		icon.Text = "✅"
		text.Text = "STAGE " .. stageIndex .. " CLEAR!"
		text.TextColor3 = Theme.SUCCESS

		-- Green stroke
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.SUCCESS
		stroke.Thickness = Theme.STROKE_BOLD
		stroke.Transparency = 0.2
		stroke.Parent = notification
	end

	-- Animate in
	notification.Position = UDim2.new(0.5, -140, 0.2, 0)
	notification.BackgroundTransparency = 1
	text.TextTransparency = 1
	icon.TextTransparency = 1

	local showTween = TweenService:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, -140, 0.25, 0),
		BackgroundTransparency = 0.1
	})
	showTween:Play()

	TweenService:Create(text, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
	TweenService:Create(icon, TweenInfo.new(0.3), {TextTransparency = 0}):Play()

	-- Hide after delay
	task.delay(1.5, function()
		local hideTween = TweenService:Create(notification, TweenInfo.new(0.3), {
			Position = UDim2.new(0.5, -140, 0.2, 0),
			BackgroundTransparency = 1
		})
		hideTween:Play()
		TweenService:Create(text, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		TweenService:Create(icon, TweenInfo.new(0.3), {TextTransparency = 1}):Play()

		hideTween.Completed:Connect(function()
			notification:Destroy()
		end)
	end)
end

function ScoreUI:flashLabel(label: TextLabel, color: Color3)
	local originalColor = label.TextColor3
	label.TextColor3 = color

	task.delay(0.3, function()
		local tween = TweenService:Create(label, TweenInfo.new(0.2), {
			TextColor3 = originalColor
		})
		tween:Play()
	end)
end

function ScoreUI:showStageProgress(totalStages: number?)
	if totalStages then
		self.totalStages = totalStages
	end

	-- Reset display
	self.currentStage = 0
	self.stageLabel.Text = "0/" .. self.totalStages
	self.progressFill.Size = UDim2.new(0, 0, 1, 0)

	-- Show frame
	self.stageFrame.Visible = true

	-- Fade in
	self.stageFrame.BackgroundTransparency = 1
	for _, child in ipairs(self.stageFrame:GetChildren()) do
		if child:IsA("GuiObject") then
			child.Visible = true
		end
	end

	local fadeIn = TweenService:Create(self.stageFrame, TweenInfo.new(0.5), {
		BackgroundTransparency = 0.3
	})
	fadeIn:Play()
end

function ScoreUI:hideStageProgress()
	-- Fade out
	local fadeOut = TweenService:Create(self.stageFrame, TweenInfo.new(0.5), {
		BackgroundTransparency = 1
	})
	fadeOut:Play()

	fadeOut.Completed:Connect(function()
		self.stageFrame.Visible = false
	end)
end

function ScoreUI:showTimer()
	self.timerFrame.Visible = true
	self.timerFrame.BackgroundTransparency = 1
	self.timerLabel.TextTransparency = 1
	local fadeIn = TweenService:Create(self.timerFrame, TweenInfo.new(0.3), {
		BackgroundTransparency = 0.2
	})
	fadeIn:Play()
	TweenService:Create(self.timerLabel, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
end

function ScoreUI:hideTimer()
	local fadeOut = TweenService:Create(self.timerFrame, TweenInfo.new(0.4), {
		BackgroundTransparency = 1
	})
	fadeOut:Play()
	TweenService:Create(self.timerLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
	fadeOut.Completed:Connect(function()
		self.timerFrame.Visible = false
	end)
end

function ScoreUI:updateTimer(seconds: number)
	if not self.timerFrame.Visible then
		self:showTimer()
	end

	local totalSecs = math.max(0, math.floor(seconds))
	local mins = math.floor(totalSecs / 60)
	local secs = totalSecs % 60
	self.timerLabel.Text = string.format("%d:%02d", mins, secs)

	-- Pulse red when ≤ 30 seconds
	if totalSecs <= 30 then
		self.timerLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
		self.timerStroke.Color = Color3.fromRGB(255, 80, 80)
		if totalSecs <= 10 then
			-- Fast pulse
			local pulse = TweenService:Create(self.timerLabel, TweenInfo.new(0.2), {
				TextSize = 24
			})
			pulse:Play()
			pulse.Completed:Connect(function()
				TweenService:Create(self.timerLabel, TweenInfo.new(0.2), { TextSize = 20 }):Play()
			end)
		end
	else
		self.timerLabel.TextColor3 = Theme.TEXT_PRIMARY
		self.timerStroke.Color = Theme.HUD_GLOW_CYAN
	end
end

return ScoreUI
