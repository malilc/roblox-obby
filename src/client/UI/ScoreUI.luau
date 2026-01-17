-- ScoreUI: แสดงคะแนนและข้อมูลเกม

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
	-- Main frame
	local frame = Instance.new("Frame")
	frame.Name = "ScoreFrame"
	frame.Size = UDim2.new(0, 250, 0, 120)
	frame.Position = UDim2.new(0, 20, 0, 20)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Parent = self.parent
	self.frame = frame
	
	-- Corner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	
	-- Stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 200, 150)
	stroke.Thickness = 2
	stroke.Transparency = 0.5
	stroke.Parent = frame
	
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 30)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "OBBY SCORE"
	title.TextColor3 = Color3.fromRGB(100, 255, 150)
	title.TextSize = 18
	title.Font = Enum.Font.GothamBold
	title.Parent = frame
	
	-- Round Score
	local roundScoreLabel = Instance.new("TextLabel")
	roundScoreLabel.Name = "RoundScore"
	roundScoreLabel.Size = UDim2.new(1, -20, 0, 25)
	roundScoreLabel.Position = UDim2.new(0, 10, 0, 35)
	roundScoreLabel.BackgroundTransparency = 1
	roundScoreLabel.Text = "Round: 0"
	roundScoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	roundScoreLabel.TextSize = 16
	roundScoreLabel.Font = Enum.Font.GothamMedium
	roundScoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	roundScoreLabel.Parent = frame
	self.roundScoreLabel = roundScoreLabel
	
	-- Stage Progress
	local stageLabel = Instance.new("TextLabel")
	stageLabel.Name = "Stage"
	stageLabel.Size = UDim2.new(1, -20, 0, 25)
	stageLabel.Position = UDim2.new(0, 10, 0, 60)
	stageLabel.BackgroundTransparency = 1
	stageLabel.Text = "Stage: 0/5"
	stageLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	stageLabel.TextSize = 16
	stageLabel.Font = Enum.Font.GothamMedium
	stageLabel.TextXAlignment = Enum.TextXAlignment.Left
	stageLabel.Parent = frame
	self.stageLabel = stageLabel
	
	-- High Score
	local highScoreLabel = Instance.new("TextLabel")
	highScoreLabel.Name = "HighScore"
	highScoreLabel.Size = UDim2.new(1, -20, 0, 25)
	highScoreLabel.Position = UDim2.new(0, 10, 0, 85)
	highScoreLabel.BackgroundTransparency = 1
	highScoreLabel.Text = "High Score: 0"
	highScoreLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	highScoreLabel.TextSize = 14
	highScoreLabel.Font = Enum.Font.Gotham
	highScoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	highScoreLabel.Parent = frame
	self.highScoreLabel = highScoreLabel
end

function ScoreUI:updateScore(data: {[string]: any})
	if data.roundScore then
		self.roundScore = data.roundScore
		self.roundScoreLabel.Text = "Round: " .. tostring(self.roundScore)
		
		-- Flash effect
		self:flashLabel(self.roundScoreLabel, Color3.fromRGB(100, 255, 150))
	end
	
	if data.currentStage then
		self.currentStage = data.currentStage
		self.stageLabel.Text = "Stage: " .. self.currentStage .. "/" .. self.totalStages
	end
	
	if data.highScore then
		self.highScore = data.highScore
		self.highScoreLabel.Text = "High Score: " .. tostring(self.highScore)
	end
	
	if data.totalScore then
		self.totalScore = data.totalScore
	end
end

function ScoreUI:showStageComplete(stageIndex: number, isFinished: boolean?)
	-- Stage complete notification
	local notification = Instance.new("TextLabel")
	notification.Name = "StageNotification"
	notification.Size = UDim2.new(0, 400, 0, 60)
	notification.Position = UDim2.new(0.5, -200, 0.3, 0)
	notification.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	notification.BackgroundTransparency = 0.2
	notification.BorderSizePixel = 0
	notification.Parent = self.parent
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = notification
	
	if isFinished then
		notification.Text = "FINISH! CONGRATULATIONS!"
		notification.TextColor3 = Color3.fromRGB(255, 215, 0)
	else
		notification.Text = "STAGE " .. stageIndex .. " COMPLETE!"
		notification.TextColor3 = Color3.fromRGB(100, 255, 150)
	end
	
	notification.TextSize = 28
	notification.Font = Enum.Font.GothamBold
	
	-- Animate
	notification.TextTransparency = 1
	notification.BackgroundTransparency = 1
	
	local showTween = TweenService:Create(notification, TweenInfo.new(0.3), {
		TextTransparency = 0,
		BackgroundTransparency = 0.2
	})
	showTween:Play()
	
	-- Hide after delay
	task.delay(2, function()
		local hideTween = TweenService:Create(notification, TweenInfo.new(0.5), {
			TextTransparency = 1,
			BackgroundTransparency = 1
		})
		hideTween:Play()
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
