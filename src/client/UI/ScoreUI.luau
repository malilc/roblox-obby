-- ScoreUI: แสดงคะแนนแบบ Coin Style

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
	-- === COIN SCORE (มุมบนซ้าย) ===
	local coinFrame = Instance.new("Frame")
	coinFrame.Name = "CoinFrame"
	coinFrame.Size = UDim2.new(0, 100, 0, 36)
	coinFrame.Position = UDim2.new(0, 10, 0, 10)
	coinFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	coinFrame.BackgroundTransparency = 0.5
	coinFrame.BorderSizePixel = 0
	coinFrame.Parent = self.parent
	self.coinFrame = coinFrame
	
	local coinCorner = Instance.new("UICorner")
	coinCorner.CornerRadius = UDim.new(0, 18)
	coinCorner.Parent = coinFrame
	
	-- Coin Icon
	local coinIcon = Instance.new("TextLabel")
	coinIcon.Name = "CoinIcon"
	coinIcon.Size = UDim2.new(0, 30, 0, 30)
	coinIcon.Position = UDim2.new(0, 3, 0.5, -15)
	coinIcon.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	coinIcon.BackgroundTransparency = 0
	coinIcon.Text = "💰"
	coinIcon.TextSize = 18
	coinIcon.Parent = coinFrame
	
	local coinIconCorner = Instance.new("UICorner")
	coinIconCorner.CornerRadius = UDim.new(1, 0)
	coinIconCorner.Parent = coinIcon
	
	-- Coin stroke (เหรียญ)
	local coinStroke = Instance.new("UIStroke")
	coinStroke.Color = Color3.fromRGB(200, 150, 0)
	coinStroke.Thickness = 2
	coinStroke.Parent = coinIcon
	
	-- Score Number
	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "ScoreLabel"
	scoreLabel.Size = UDim2.new(1, -40, 1, 0)
	scoreLabel.Position = UDim2.new(0, 36, 0, 0)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Text = "0"
	scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	scoreLabel.TextSize = 18
	scoreLabel.Font = Enum.Font.GothamBold
	scoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	scoreLabel.Parent = coinFrame
	self.roundScoreLabel = scoreLabel
	
	-- === HIGH SCORE (ข้าง Coin) ===
	local highScoreFrame = Instance.new("Frame")
	highScoreFrame.Name = "HighScoreFrame"
	highScoreFrame.Size = UDim2.new(0, 90, 0, 28)
	highScoreFrame.Position = UDim2.new(0, 115, 0, 14)
	highScoreFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	highScoreFrame.BackgroundTransparency = 0.6
	highScoreFrame.BorderSizePixel = 0
	highScoreFrame.Parent = self.parent
	self.highScoreFrame = highScoreFrame
	
	local hsCorner = Instance.new("UICorner")
	hsCorner.CornerRadius = UDim.new(0, 14)
	hsCorner.Parent = highScoreFrame
	
	-- Trophy Icon
	local trophyIcon = Instance.new("TextLabel")
	trophyIcon.Name = "TrophyIcon"
	trophyIcon.Size = UDim2.new(0, 28, 1, 0)
	trophyIcon.Position = UDim2.new(0, 0, 0, 0)
	trophyIcon.BackgroundTransparency = 1
	trophyIcon.Text = "🏆"
	trophyIcon.TextSize = 14
	trophyIcon.Parent = highScoreFrame
	
	-- High Score Number
	local highScoreLabel = Instance.new("TextLabel")
	highScoreLabel.Name = "HighScoreLabel"
	highScoreLabel.Size = UDim2.new(1, -30, 1, 0)
	highScoreLabel.Position = UDim2.new(0, 28, 0, 0)
	highScoreLabel.BackgroundTransparency = 1
	highScoreLabel.Text = "0"
	highScoreLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	highScoreLabel.TextSize = 14
	highScoreLabel.Font = Enum.Font.GothamBold
	highScoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	highScoreLabel.Parent = highScoreFrame
	self.highScoreLabel = highScoreLabel
	
	-- === STAGE PROGRESS (ใต้ Coin) ===
	local stageFrame = Instance.new("Frame")
	stageFrame.Name = "StageFrame"
	stageFrame.Size = UDim2.new(0, 150, 0, 24)
	stageFrame.Position = UDim2.new(0, 10, 0, 50)
	stageFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	stageFrame.BackgroundTransparency = 0.6
	stageFrame.BorderSizePixel = 0
	stageFrame.Parent = self.parent
	self.stageFrame = stageFrame
	
	local stageCorner = Instance.new("UICorner")
	stageCorner.CornerRadius = UDim.new(0, 12)
	stageCorner.Parent = stageFrame
	
	-- Stage Icon
	local stageIcon = Instance.new("TextLabel")
	stageIcon.Name = "StageIcon"
	stageIcon.Size = UDim2.new(0, 24, 1, 0)
	stageIcon.Position = UDim2.new(0, 2, 0, 0)
	stageIcon.BackgroundTransparency = 1
	stageIcon.Text = "🚩"
	stageIcon.TextSize = 12
	stageIcon.Parent = stageFrame
	
	-- Stage Progress Bar Background
	local progressBg = Instance.new("Frame")
	progressBg.Name = "ProgressBg"
	progressBg.Size = UDim2.new(0, 80, 0, 10)
	progressBg.Position = UDim2.new(0, 28, 0.5, -5)
	progressBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	progressBg.BorderSizePixel = 0
	progressBg.Parent = stageFrame
	
	local progressBgCorner = Instance.new("UICorner")
	progressBgCorner.CornerRadius = UDim.new(0, 5)
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
	progressFillCorner.CornerRadius = UDim.new(0, 5)
	progressFillCorner.Parent = progressFill
	
	-- Stage Text
	local stageLabel = Instance.new("TextLabel")
	stageLabel.Name = "StageLabel"
	stageLabel.Size = UDim2.new(0, 35, 1, 0)
	stageLabel.Position = UDim2.new(0, 112, 0, 0)
	stageLabel.BackgroundTransparency = 1
	stageLabel.Text = "0/5"
	stageLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
	stageLabel.TextSize = 12
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
		
		-- Coin pop animation
		if data.roundScore > oldScore then
			self:playCoinAnimation()
		end
	end
	
	if data.currentStage then
		self.currentStage = data.currentStage
		self.stageLabel.Text = self.currentStage .. "/" .. self.totalStages
		
		-- Update progress bar
		local progress = self.currentStage / self.totalStages
		local targetWidth = 80 * progress
		
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

function ScoreUI:playCoinAnimation()
	-- Scale up coin frame
	local originalSize = self.coinFrame.Size
	
	local scaleUp = TweenService:Create(self.coinFrame, TweenInfo.new(0.1), {
		Size = UDim2.new(0, 110, 0, 40)
	})
	scaleUp:Play()
	
	scaleUp.Completed:Connect(function()
		local scaleDown = TweenService:Create(self.coinFrame, TweenInfo.new(0.1), {
			Size = originalSize
		})
		scaleDown:Play()
	end)
	
	-- Flash score color
	self.roundScoreLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
	task.delay(0.2, function()
		local colorTween = TweenService:Create(self.roundScoreLabel, TweenInfo.new(0.2), {
			TextColor3 = Color3.fromRGB(255, 255, 255)
		})
		colorTween:Play()
	end)
end

function ScoreUI:showStageComplete(stageIndex: number, isFinished: boolean?)
	-- Stage complete notification (เล็กลง + สวยงาม)
	local notification = Instance.new("Frame")
	notification.Name = "StageNotification"
	notification.Size = UDim2.new(0, 250, 0, 50)
	notification.Position = UDim2.new(0.5, -125, 0.25, 0)
	notification.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	notification.BackgroundTransparency = 0.4
	notification.BorderSizePixel = 0
	notification.Parent = self.parent
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = notification
	
	-- Icon
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(0, 50, 1, 0)
	icon.Position = UDim2.new(0, 0, 0, 0)
	icon.BackgroundTransparency = 1
	icon.TextSize = 28
	icon.Parent = notification
	
	-- Text
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -55, 1, 0)
	text.Position = UDim2.new(0, 50, 0, 0)
	text.BackgroundTransparency = 1
	text.TextSize = 18
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
		stroke.Transparency = 0.5
		stroke.Parent = notification
	else
		icon.Text = "✅"
		text.Text = "STAGE " .. stageIndex .. " CLEAR!"
		text.TextColor3 = Color3.fromRGB(100, 255, 150)
	end
	
	-- Animate in
	notification.Position = UDim2.new(0.5, -125, 0.2, 0)
	notification.BackgroundTransparency = 1
	text.TextTransparency = 1
	icon.TextTransparency = 1
	
	local showTween = TweenService:Create(notification, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, -125, 0.25, 0),
		BackgroundTransparency = 0.4
	})
	showTween:Play()
	
	TweenService:Create(text, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
	TweenService:Create(icon, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
	
	-- Hide after delay
	task.delay(1.5, function()
		local hideTween = TweenService:Create(notification, TweenInfo.new(0.3), {
			Position = UDim2.new(0.5, -125, 0.2, 0),
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

return ScoreUI
