-- RaceResultsUI: แสดงผลการแข่งขัน

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.ThemeConfig)

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
	container.BackgroundColor3 = Theme.BG_BASE
	container.BackgroundTransparency = 0.05
	container.BorderSizePixel = 0
	container.Visible = false
	container.Parent = self.parent
	self.container = container

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = Theme.CORNER_MD
	containerCorner.Parent = container

	-- Border/Glow
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.MEDAL_GOLD
	stroke.Thickness = Theme.STROKE_BOLD
	stroke.Parent = container

	-- Header background
	local headerBg = Instance.new("Frame")
	headerBg.Name = "HeaderBg"
	headerBg.Size = UDim2.new(1, 0, 0, 80)
	headerBg.BackgroundColor3 = Theme.MEDAL_GOLD
	headerBg.BackgroundTransparency = 0.3
	headerBg.BorderSizePixel = 0
	headerBg.Parent = container

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = Theme.CORNER_MD
	headerCorner.Parent = headerBg

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "RACE FINISHED!"
	title.TextColor3 = Theme.TEXT_PRIMARY
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
	subtitle.TextColor3 = Theme.TEXT_MUTED
	subtitle.TextSize = 16
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.Parent = container
	self.subtitleLabel = subtitle

	-- Results list container
	local resultsFrame = Instance.new("ScrollingFrame")
	resultsFrame.Name = "ResultsFrame"
	resultsFrame.Size = UDim2.new(1, -40, 0, 320)
	resultsFrame.Position = UDim2.new(0, 20, 0, 100)
	resultsFrame.BackgroundColor3 = Theme.BG_OVERLAY
	resultsFrame.BackgroundTransparency = 0.5
	resultsFrame.BorderSizePixel = 0
	resultsFrame.ScrollBarThickness = 6
	resultsFrame.ScrollBarImageColor3 = Theme.ACCENT_CYAN
	resultsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	resultsFrame.Parent = container
	self.resultsFrame = resultsFrame

	local resultsCorner = Instance.new("UICorner")
	resultsCorner.CornerRadius = Theme.CORNER_SM
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
	closeBtn.BackgroundColor3 = Theme.SUCCESS
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "CONTINUE"
	closeBtn.TextColor3 = Theme.TEXT_PRIMARY
	closeBtn.TextSize = 18
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = container

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = Theme.CORNER_SM
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
	entry.BackgroundColor3 = isLocalPlayer and Theme.MEDAL_GOLD or Theme.BG_ELEVATED
	entry.BackgroundTransparency = isLocalPlayer and 0.3 or 0.5
	entry.BorderSizePixel = 0
	entry.LayoutOrder = index
	entry.Parent = self.resultsFrame

	local entryCorner = Instance.new("UICorner")
	entryCorner.CornerRadius = Theme.CORNER_SM
	entryCorner.Parent = entry

	-- Position medal/number
	local position = Instance.new("TextLabel")
	position.Size = UDim2.new(0, 50, 1, 0)
	position.BackgroundTransparency = 1

	local medal = ""
	local medalColor = Theme.TEXT_PRIMARY
	if result.position == 1 then
		medal = "🥇"
		medalColor = Theme.MEDAL_GOLD
	elseif result.position == 2 then
		medal = "🥈"
		medalColor = Theme.MEDAL_SILVER
	elseif result.position == 3 then
		medal = "🥉"
		medalColor = Theme.MEDAL_BRONZE
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
	name.TextColor3 = isLocalPlayer and Theme.TEXT_DARK or Theme.TEXT_PRIMARY
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
		status.TextColor3 = Theme.SUCCESS
	else
		status.Text = "Stage " .. result.stage
		status.TextColor3 = Theme.WARNING
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

	timeLabel.TextColor3 = isLocalPlayer and Theme.TEXT_DARK or Theme.TEXT_MUTED
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
					Thickness = Theme.STROKE_BOLD * 1.5
				}):Play()
				task.wait(0.2)
				TweenService:Create(stroke, TweenInfo.new(0.2), {
					Thickness = Theme.STROKE_BOLD
				}):Play()
				task.wait(0.2)
			end
		end
	end)
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
