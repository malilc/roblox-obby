-- ScoreUI: แสดงคะแนนแบบ Modern Style (Enhanced Version)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local ScoreUI = {}
ScoreUI.__index = ScoreUI

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
	-- === SCORE FRAME (มุมบนซ้าย) - Modern Design ===
	local scoreFrame = Instance.new("Frame")
	scoreFrame.Name = "ScoreFrame"
	scoreFrame.Size = UDim2.new(0, 120, 0, 44)
	scoreFrame.Position = UDim2.new(0, 10, 0, 10)
	scoreFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
	scoreFrame.BackgroundTransparency = 0.3
	scoreFrame.BorderSizePixel = 0
	scoreFrame.Parent = self.parent
	self.scoreFrame = scoreFrame
	
	local scoreCorner = Instance.new("UICorner")
	scoreCorner.CornerRadius = UDim.new(0, 22)
	scoreCorner.Parent = scoreFrame
	
	-- Frame Stroke (glow effect)
	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Color3.fromRGB(100, 200, 255)
	frameStroke.Thickness = 1.5
	frameStroke.Transparency = 0.5
	frameStroke.Parent = scoreFrame
	self.frameStroke = frameStroke
	
	-- Gradient background
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 40, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 25, 40))
	})
	gradient.Rotation = 45
	gradient.Parent = scoreFrame
	
	-- Score Icon Container
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(0, 36, 0, 36)
	iconContainer.Position = UDim2.new(0, 4, 0.5, -18)
	iconContainer.BackgroundTransparency = 1
	iconContainer.Parent = scoreFrame
	self.iconContainer = iconContainer
	
	-- Score Icon Background (star)
	local scoreIcon = Instance.new("Frame")
	scoreIcon.Name = "ScoreIcon"
	scoreIcon.Size = UDim2.new(1, 0, 1, 0)
	scoreIcon.Position = UDim2.new(0, 0, 0, 0)
	scoreIcon.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
	scoreIcon.BorderSizePixel = 0
	scoreIcon.Parent = iconContainer
	self.scoreIcon = scoreIcon
	
	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(1, 0)
	iconCorner.Parent = scoreIcon
	
	-- Icon gradient (3D effect)
	local iconGradient = Instance.new("UIGradient")
	iconGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 220, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 180, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 120, 200))
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
	
	-- Icon stroke
	local iconStroke = Instance.new("UIStroke")
	iconStroke.Color = Color3.fromRGB(50, 100, 180)
	iconStroke.Thickness = 2
	iconStroke.Parent = scoreIcon
	
	-- Score Number
	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "ScoreLabel"
	scoreLabel.Size = UDim2.new(1, -50, 1, 0)
	scoreLabel.Position = UDim2.new(0, 44, 0, 0)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Text = "0"
	scoreLabel.TextColor3 = Color3.fromRGB(200, 230, 255)
	scoreLabel.TextSize = 22
	scoreLabel.Font = Enum.Font.GothamBlack
	scoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	scoreLabel.Parent = scoreFrame
	self.roundScoreLabel = scoreLabel
	
	-- Text stroke for better visibility
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(30, 60, 100)
	textStroke.Thickness = 1
	textStroke.Transparency = 0.5
	textStroke.Parent = scoreLabel
	
	-- === HIGH SCORE FRAME (ข้าง Score) ===
	local highScoreFrame = Instance.new("Frame")
	highScoreFrame.Name = "HighScoreFrame"
	highScoreFrame.Size = UDim2.new(0, 100, 0, 32)
	highScoreFrame.Position = UDim2.new(0, 135, 0, 16)
	highScoreFrame.BackgroundColor3 = Color3.fromRGB(30, 25, 20)
	highScoreFrame.BackgroundTransparency = 0.4
	highScoreFrame.BorderSizePixel = 0
	highScoreFrame.Parent = self.parent
	self.highScoreFrame = highScoreFrame
	
	local hsCorner = Instance.new("UICorner")
	hsCorner.CornerRadius = UDim.new(0, 16)
	hsCorner.Parent = highScoreFrame
	
	-- High Score Gradient
	local hsGradient = Instance.new("UIGradient")
	hsGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 40, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 25, 20))
	})
	hsGradient.Rotation = 45
	hsGradient.Parent = highScoreFrame
	
	-- High Score Stroke
	local hsStroke = Instance.new("UIStroke")
	hsStroke.Color = Color3.fromRGB(255, 200, 100)
	hsStroke.Thickness = 1
	hsStroke.Transparency = 0.6
	hsStroke.Parent = highScoreFrame
	
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
	highScoreLabel.TextColor3 = Color3.fromRGB(255, 215, 100)
	highScoreLabel.TextSize = 16
	highScoreLabel.Font = Enum.Font.GothamBold
	highScoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	highScoreLabel.Parent = highScoreFrame
	self.highScoreLabel = highScoreLabel
	
	-- === STAGE PROGRESS (ใต้ Score) ===
	local stageFrame = Instance.new("Frame")
	stageFrame.Name = "StageFrame"
	stageFrame.Size = UDim2.new(0, 160, 0, 28)
	stageFrame.Position = UDim2.new(0, 10, 0, 58)
	stageFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 25)
	stageFrame.BackgroundTransparency = 0.4
	stageFrame.BorderSizePixel = 0
	stageFrame.Parent = self.parent
	self.stageFrame = stageFrame
	
	local stageCorner = Instance.new("UICorner")
	stageCorner.CornerRadius = UDim.new(0, 14)
	stageCorner.Parent = stageFrame
	
	-- Stage Gradient
	local stageGradient = Instance.new("UIGradient")
	stageGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 50, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 30, 25))
	})
	stageGradient.Rotation = 45
	stageGradient.Parent = stageFrame
	
	-- Stage Stroke
	local stageStroke = Instance.new("UIStroke")
	stageStroke.Color = Color3.fromRGB(100, 255, 150)
	stageStroke.Thickness = 1
	stageStroke.Transparency = 0.6
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
	
	-- Stage Progress Bar Background
	local progressBg = Instance.new("Frame")
	progressBg.Name = "ProgressBg"
	progressBg.Size = UDim2.new(0, 85, 0, 12)
	progressBg.Position = UDim2.new(0, 30, 0.5, -6)
	progressBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	progressBg.BorderSizePixel = 0
	progressBg.Parent = stageFrame
	
	local progressBgCorner = Instance.new("UICorner")
	progressBgCorner.CornerRadius = UDim.new(0, 6)
	progressBgCorner.Parent = progressBg
	
	-- Stage Progress Bar Fill
	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.Position = UDim2.new(0, 0, 0, 0)
	progressFill.BackgroundColor3 = Color3.fromRGB(100, 255, 150)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBg
	self.progressFill = progressFill
	
	local progressFillCorner = Instance.new("UICorner")
	progressFillCorner.CornerRadius = UDim.new(0, 6)
	progressFillCorner.Parent = progressFill
	
	-- Progress Fill Gradient
	local progressGradient = Instance.new("UIGradient")
	progressGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 255, 180)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 200, 120))
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
	stageLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
	stageLabel.TextSize = 13
	stageLabel.Font = Enum.Font.GothamBold
	stageLabel.TextXAlignment = Enum.TextXAlignment.Center
	stageLabel.Parent = stageFrame
	self.stageLabel = stageLabel
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
	local originalSize = UDim2.new(0, 120, 0, 44)
	
	-- Frame scale animation
	local scaleUp = TweenService:Create(self.scoreFrame, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 135, 0, 50)
	})
	scaleUp:Play()
	
	-- Glow effect
	local glowUp = TweenService:Create(self.frameStroke, TweenInfo.new(0.1), {
		Transparency = 0,
		Thickness = 2.5
	})
	glowUp:Play()
	
	scaleUp.Completed:Connect(function()
		local scaleDown = TweenService:Create(self.scoreFrame, TweenInfo.new(0.15, Enum.EasingStyle.Bounce), {
			Size = originalSize
		})
		scaleDown:Play()
		
		local glowDown = TweenService:Create(self.frameStroke, TweenInfo.new(0.2), {
			Transparency = 0.5,
			Thickness = 1.5
		})
		glowDown:Play()
	end)
	
	-- Flash score color
	self.roundScoreLabel.TextColor3 = Color3.fromRGB(255, 255, 200)
	task.delay(0.15, function()
		local colorTween = TweenService:Create(self.roundScoreLabel, TweenInfo.new(0.25), {
			TextColor3 = Color3.fromRGB(200, 230, 255)
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
	notification.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	notification.BackgroundTransparency = 0.2
	notification.BorderSizePixel = 0
	notification.Parent = self.parent
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = notification
	
	-- Gradient
	local notifGradient = Instance.new("UIGradient")
	notifGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 35, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 30))
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
		text.TextColor3 = Color3.fromRGB(255, 215, 0)
		
		-- Gold stroke
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 215, 0)
		stroke.Thickness = 2
		stroke.Transparency = 0.3
		stroke.Parent = notification
	else
		icon.Text = "✅"
		text.Text = "STAGE " .. stageIndex .. " CLEAR!"
		text.TextColor3 = Color3.fromRGB(100, 255, 150)
		
		-- Green stroke
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(100, 255, 150)
		stroke.Thickness = 2
		stroke.Transparency = 0.4
		stroke.Parent = notification
	end
	
	-- Animate in
	notification.Position = UDim2.new(0.5, -140, 0.2, 0)
	notification.BackgroundTransparency = 1
	text.TextTransparency = 1
	icon.TextTransparency = 1
	
	local showTween = TweenService:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, -140, 0.25, 0),
		BackgroundTransparency = 0.2
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
		BackgroundTransparency = 0.4
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

return ScoreUI
