-- RaceResultsUI: แสดงผลการแข่งขัน

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local RaceResultsUI = {}
RaceResultsUI.__index = RaceResultsUI

function RaceResultsUI.new(parent: ScreenGui)
	local self = setmetatable({}, RaceResultsUI)
	
	self.parent = parent
	self.isVisible = false
	
	self:createUI()
	self:setupRemotes()
	
	return self
end

function RaceResultsUI:createUI()
	-- Main container (initially hidden)
	local container = Instance.new("Frame")
	container.Name = "RaceResultsContainer"
	container.Size = UDim2.new(0, 450, 0, 500)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	container.BackgroundTransparency = 0.05
	container.BorderSizePixel = 0
	container.Visible = false
	container.Parent = self.parent
	self.container = container
	
	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 16)
	containerCorner.Parent = container
	
	-- Border/Glow
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 215, 0)
	stroke.Thickness = 3
	stroke.Parent = container
	
	-- Header background
	local headerBg = Instance.new("Frame")
	headerBg.Name = "HeaderBg"
	headerBg.Size = UDim2.new(1, 0, 0, 80)
	headerBg.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	headerBg.BackgroundTransparency = 0.3
	headerBg.BorderSizePixel = 0
	headerBg.Parent = container
	
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 16)
	headerCorner.Parent = headerBg
	
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "RACE FINISHED!"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 32
	title.Font = Enum.Font.GothamBlack
	title.Parent = container
	self.titleLabel = title
	
	-- Subtitle (reason)
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, 0, 0, 25)
	subtitle.Position = UDim2.new(0, 0, 0, 50)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "All players finished"
	subtitle.TextColor3 = Color3.fromRGB(200, 200, 200)
	subtitle.TextSize = 16
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.Parent = container
	self.subtitleLabel = subtitle
	
	-- Results list container
	local resultsFrame = Instance.new("ScrollingFrame")
	resultsFrame.Name = "ResultsFrame"
	resultsFrame.Size = UDim2.new(1, -40, 0, 320)
	resultsFrame.Position = UDim2.new(0, 20, 0, 100)
	resultsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	resultsFrame.BackgroundTransparency = 0.5
	resultsFrame.BorderSizePixel = 0
	resultsFrame.ScrollBarThickness = 6
	resultsFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 150, 255)
	resultsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	resultsFrame.Parent = container
	self.resultsFrame = resultsFrame
	
	local resultsCorner = Instance.new("UICorner")
	resultsCorner.CornerRadius = UDim.new(0, 10)
	resultsCorner.Parent = resultsFrame
	
	local resultsLayout = Instance.new("UIListLayout")
	resultsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	resultsLayout.Padding = UDim.new(0, 8)
	resultsLayout.Parent = resultsFrame
	
	local resultsPadding = Instance.new("UIPadding")
	resultsPadding.PaddingTop = UDim.new(0, 10)
	resultsPadding.PaddingLeft = UDim.new(0, 10)
	resultsPadding.PaddingRight = UDim.new(0, 10)
	resultsPadding.Parent = resultsFrame
	
	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 180, 0, 45)
	closeBtn.Position = UDim2.new(0.5, 0, 1, -55)
	closeBtn.AnchorPoint = Vector2.new(0.5, 0)
	closeBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "CONTINUE"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 18
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = container
	
	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 8)
	closeBtnCorner.Parent = closeBtn
	
	closeBtn.MouseButton1Click:Connect(function()
		self:hide()
	end)
end

function RaceResultsUI:setupRemotes()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	
	-- Match end
	remotes.MatchEnd.OnClientEvent:Connect(function(data)
		self:showResults(data)
	end)
end

function RaceResultsUI:showResults(data: {
	reason: string,
	results: {{
		playerName: string,
		position: number,
		finished: boolean,
		finishTime: number?,
		stage: number,
	}},
	winner: string?,
})
	-- Set title based on reason
	if data.reason == "timeout" then
		self.titleLabel.Text = "TIME'S UP!"
		self.subtitleLabel.Text = "The race has ended"
	elseif data.reason == "allFinished" then
		self.titleLabel.Text = "RACE FINISHED!"
		self.subtitleLabel.Text = "All players completed the race"
	else
		self.titleLabel.Text = "RACE OVER"
		self.subtitleLabel.Text = ""
	end
	
	-- Clear existing results
	for _, child in ipairs(self.resultsFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	-- Add result entries
	for i, result in ipairs(data.results) do
		self:createResultEntry(i, result)
	end
	
	-- Update canvas size
	self.resultsFrame.CanvasSize = UDim2.new(0, 0, 0, #data.results * 58)
	
	-- Show UI
	self:show()
	
	-- Highlight winner
	if data.winner then
		-- Play celebration for winner
		if LocalPlayer.Name == data.winner then
			self:playWinnerCelebration()
		end
	end
end

function RaceResultsUI:createResultEntry(index: number, result: {
	playerName: string,
	position: number,
	finished: boolean,
	finishTime: number?,
	stage: number,
})
	local isLocalPlayer = result.playerName == LocalPlayer.Name
	
	-- Entry frame
	local entry = Instance.new("Frame")
	entry.Name = "Result_" .. index
	entry.Size = UDim2.new(1, -20, 0, 50)
	entry.BackgroundColor3 = isLocalPlayer and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(40, 40, 60)
	entry.BackgroundTransparency = isLocalPlayer and 0.3 or 0.5
	entry.BorderSizePixel = 0
	entry.LayoutOrder = index
	entry.Parent = self.resultsFrame
	
	local entryCorner = Instance.new("UICorner")
	entryCorner.CornerRadius = UDim.new(0, 8)
	entryCorner.Parent = entry
	
	-- Position medal/number
	local position = Instance.new("TextLabel")
	position.Size = UDim2.new(0, 50, 1, 0)
	position.BackgroundTransparency = 1
	
	local medal = ""
	local medalColor = Color3.fromRGB(255, 255, 255)
	if result.position == 1 then
		medal = "🥇"
		medalColor = Color3.fromRGB(255, 215, 0)
	elseif result.position == 2 then
		medal = "🥈"
		medalColor = Color3.fromRGB(192, 192, 192)
	elseif result.position == 3 then
		medal = "🥉"
		medalColor = Color3.fromRGB(205, 127, 50)
	else
		medal = "#" .. result.position
	end
	
	position.Text = medal
	position.TextSize = result.position <= 3 and 28 or 20
	position.TextColor3 = medalColor
	position.Font = Enum.Font.GothamBold
	position.Parent = entry
	
	-- Player name
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(0, 150, 1, 0)
	name.Position = UDim2.new(0, 55, 0, 0)
	name.BackgroundTransparency = 1
	name.Text = result.playerName
	name.TextColor3 = isLocalPlayer and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
	name.TextSize = 16
	name.Font = Enum.Font.GothamBold
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Parent = entry
	
	-- Status (Finished / Stage X)
	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(0, 100, 1, 0)
	status.Position = UDim2.new(1, -180, 0, 0)
	status.BackgroundTransparency = 1
	
	if result.finished then
		status.Text = "FINISHED"
		status.TextColor3 = Color3.fromRGB(100, 255, 100)
	else
		status.Text = "Stage " .. result.stage
		status.TextColor3 = Color3.fromRGB(255, 200, 100)
	end
	
	status.TextSize = 14
	status.Font = Enum.Font.GothamMedium
	status.TextXAlignment = Enum.TextXAlignment.Right
	status.Parent = entry
	
	-- Time (if finished)
	local timeLabel = Instance.new("TextLabel")
	timeLabel.Size = UDim2.new(0, 70, 1, 0)
	timeLabel.Position = UDim2.new(1, -75, 0, 0)
	timeLabel.BackgroundTransparency = 1
	
	if result.finishTime then
		local minutes = math.floor(result.finishTime / 60)
		local seconds = math.floor(result.finishTime % 60)
		local ms = math.floor((result.finishTime % 1) * 100)
		timeLabel.Text = string.format("%d:%02d.%02d", minutes, seconds, ms)
	else
		timeLabel.Text = "--:--.--"
	end
	
	timeLabel.TextColor3 = isLocalPlayer and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(150, 150, 150)
	timeLabel.TextSize = 14
	timeLabel.Font = Enum.Font.GothamMedium
	timeLabel.TextXAlignment = Enum.TextXAlignment.Right
	timeLabel.Parent = entry
end

function RaceResultsUI:playWinnerCelebration()
	-- Flash golden border
	task.spawn(function()
		local stroke = self.container:FindFirstChildOfClass("UIStroke")
		if stroke then
			for i = 1, 5 do
				TweenService:Create(stroke, TweenInfo.new(0.2), {
					Thickness = 6
				}):Play()
				task.wait(0.2)
				TweenService:Create(stroke, TweenInfo.new(0.2), {
					Thickness = 3
				}):Play()
				task.wait(0.2)
			end
		end
	end)
	
	-- TODO: Add confetti particles or other celebration effects
end

function RaceResultsUI:show()
	self.isVisible = true
	self.container.Visible = true
	
	-- Animate in
	self.container.Position = UDim2.new(0.5, 0, 0.5, 50)
	self.container.BackgroundTransparency = 1
	
	TweenService:Create(self.container, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 0.05
	}):Play()
end

function RaceResultsUI:hide()
	self.isVisible = false
	
	-- Animate out
	TweenService:Create(self.container, TweenInfo.new(0.2), {
		Position = UDim2.new(0.5, 0, 0.5, 50),
		BackgroundTransparency = 1
	}):Play()
	
	task.delay(0.2, function()
		self.container.Visible = false
	end)
end

return RaceResultsUI
