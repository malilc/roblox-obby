-- MatchLobbyUI: UI สำหรับระบบ Matchmaking

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local MatchLobbyUI = {}
MatchLobbyUI.__index = MatchLobbyUI

function MatchLobbyUI.new(parent: ScreenGui)
	local self = setmetatable({}, MatchLobbyUI)
	
	self.parent = parent
	self.isVisible = false
	self.currentRoom = nil
	
	self:createUI()
	self:setupRemotes()
	
	return self
end

function MatchLobbyUI:createUI()
	-- Main container (initially hidden)
	local container = Instance.new("Frame")
	container.Name = "MatchLobbyContainer"
	container.Size = UDim2.new(0, 400, 0, 500)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	container.BackgroundTransparency = 0.1
	container.BorderSizePixel = 0
	container.Visible = false
	container.Parent = self.parent
	self.container = container
	
	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 16)
	containerCorner.Parent = container
	
	-- Stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 150, 255)
	stroke.Thickness = 2
	stroke.Parent = container
	
	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 60)
	header.BackgroundColor3 = Color3.fromRGB(40, 60, 100)
	header.BackgroundTransparency = 0.5
	header.BorderSizePixel = 0
	header.Parent = container
	
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 16)
	headerCorner.Parent = header
	
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -80, 1, 0)
	title.Position = UDim2.new(0, 20, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "MATCH LOBBY"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 24
	title.Font = Enum.Font.GothamBlack
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header
	self.titleLabel = title
	
	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 40, 0, 40)
	closeBtn.Position = UDim2.new(1, -50, 0.5, 0)
	closeBtn.AnchorPoint = Vector2.new(0, 0.5)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 20
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = header
	self.closeButton = closeBtn
	
	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 8)
	closeBtnCorner.Parent = closeBtn
	
	-- Player count
	local playerCount = Instance.new("TextLabel")
	playerCount.Name = "PlayerCount"
	playerCount.Size = UDim2.new(1, -40, 0, 30)
	playerCount.Position = UDim2.new(0, 20, 0, 70)
	playerCount.BackgroundTransparency = 1
	playerCount.Text = "Players: 0/16"
	playerCount.TextColor3 = Color3.fromRGB(200, 200, 200)
	playerCount.TextSize = 18
	playerCount.Font = Enum.Font.GothamMedium
	playerCount.TextXAlignment = Enum.TextXAlignment.Left
	playerCount.Parent = container
	self.playerCountLabel = playerCount
	
	-- Player list container
	local listContainer = Instance.new("ScrollingFrame")
	listContainer.Name = "PlayerList"
	listContainer.Size = UDim2.new(1, -40, 0, 250)
	listContainer.Position = UDim2.new(0, 20, 0, 110)
	listContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	listContainer.BackgroundTransparency = 0.5
	listContainer.BorderSizePixel = 0
	listContainer.ScrollBarThickness = 6
	listContainer.ScrollBarImageColor3 = Color3.fromRGB(100, 150, 255)
	listContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	listContainer.Parent = container
	self.playerList = listContainer
	
	local listCorner = Instance.new("UICorner")
	listCorner.CornerRadius = UDim.new(0, 8)
	listCorner.Parent = listContainer
	
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 5)
	listLayout.Parent = listContainer
	
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 8)
	listPadding.PaddingLeft = UDim.new(0, 8)
	listPadding.PaddingRight = UDim.new(0, 8)
	listPadding.Parent = listContainer
	
	-- Countdown/Status label
	local countdown = Instance.new("TextLabel")
	countdown.Name = "Countdown"
	countdown.Size = UDim2.new(1, -40, 0, 50)
	countdown.Position = UDim2.new(0, 20, 0, 370)
	countdown.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
	countdown.BackgroundTransparency = 0.5
	countdown.BorderSizePixel = 0
	countdown.Text = "Waiting for players..."
	countdown.TextColor3 = Color3.fromRGB(255, 255, 255)
	countdown.TextSize = 22
	countdown.Font = Enum.Font.GothamBold
	countdown.Parent = container
	self.countdownLabel = countdown
	
	local countdownCorner = Instance.new("UICorner")
	countdownCorner.CornerRadius = UDim.new(0, 8)
	countdownCorner.Parent = countdown
	
	-- Buttons container
	local buttonsFrame = Instance.new("Frame")
	buttonsFrame.Name = "Buttons"
	buttonsFrame.Size = UDim2.new(1, -40, 0, 50)
	buttonsFrame.Position = UDim2.new(0, 20, 0, 430)
	buttonsFrame.BackgroundTransparency = 1
	buttonsFrame.Parent = container
	
	-- Create Match button
	local createBtn = Instance.new("TextButton")
	createBtn.Name = "CreateMatch"
	createBtn.Size = UDim2.new(0.48, 0, 1, 0)
	createBtn.Position = UDim2.new(0, 0, 0, 0)
	createBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	createBtn.BorderSizePixel = 0
	createBtn.Text = "CREATE MATCH"
	createBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	createBtn.TextSize = 16
	createBtn.Font = Enum.Font.GothamBold
	createBtn.Parent = buttonsFrame
	self.createButton = createBtn
	
	local createBtnCorner = Instance.new("UICorner")
	createBtnCorner.CornerRadius = UDim.new(0, 8)
	createBtnCorner.Parent = createBtn
	
	-- Leave/Ready button
	local leaveBtn = Instance.new("TextButton")
	leaveBtn.Name = "LeaveMatch"
	leaveBtn.Size = UDim2.new(0.48, 0, 1, 0)
	leaveBtn.Position = UDim2.new(0.52, 0, 0, 0)
	leaveBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
	leaveBtn.BorderSizePixel = 0
	leaveBtn.Text = "LEAVE"
	leaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	leaveBtn.TextSize = 16
	leaveBtn.Font = Enum.Font.GothamBold
	leaveBtn.Visible = false
	leaveBtn.Parent = buttonsFrame
	self.leaveButton = leaveBtn
	
	local leaveBtnCorner = Instance.new("UICorner")
	leaveBtnCorner.CornerRadius = UDim.new(0, 8)
	leaveBtnCorner.Parent = leaveBtn
	
	-- Setup button events
	self:setupButtonEvents()
	
	-- Race Timer UI (separate from lobby)
	self:createRaceTimerUI()
	
	-- Time Warning UI
	self:createTimeWarningUI()
	
	-- Race Ranking UI
	self:createRaceRankingUI()
end

function MatchLobbyUI:createRaceTimerUI()
	-- Timer display during race
	local timerFrame = Instance.new("Frame")
	timerFrame.Name = "RaceTimer"
	timerFrame.Size = UDim2.new(0, 150, 0, 50)
	timerFrame.Position = UDim2.new(0.5, 0, 0, 10)
	timerFrame.AnchorPoint = Vector2.new(0.5, 0)
	timerFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	timerFrame.BackgroundTransparency = 0.3
	timerFrame.BorderSizePixel = 0
	timerFrame.Visible = false
	timerFrame.Parent = self.parent
	self.timerFrame = timerFrame
	
	local timerCorner = Instance.new("UICorner")
	timerCorner.CornerRadius = UDim.new(0, 10)
	timerCorner.Parent = timerFrame
	
	local timerStroke = Instance.new("UIStroke")
	timerStroke.Color = Color3.fromRGB(100, 200, 100)
	timerStroke.Thickness = 2
	timerStroke.Parent = timerFrame
	self.timerStroke = timerStroke
	
	local timerIcon = Instance.new("TextLabel")
	timerIcon.Name = "Icon"
	timerIcon.Size = UDim2.new(0, 30, 1, 0)
	timerIcon.Position = UDim2.new(0, 10, 0, 0)
	timerIcon.BackgroundTransparency = 1
	timerIcon.Text = "⏱️"
	timerIcon.TextSize = 24
	timerIcon.Parent = timerFrame
	
	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "Time"
	timerLabel.Size = UDim2.new(1, -50, 1, 0)
	timerLabel.Position = UDim2.new(0, 45, 0, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = "15:00"
	timerLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	timerLabel.TextSize = 28
	timerLabel.Font = Enum.Font.GothamBold
	timerLabel.TextXAlignment = Enum.TextXAlignment.Left
	timerLabel.Parent = timerFrame
	self.timerLabel = timerLabel
end

function MatchLobbyUI:createTimeWarningUI()
	-- Time warning overlay
	local warningFrame = Instance.new("Frame")
	warningFrame.Name = "TimeWarning"
	warningFrame.Size = UDim2.new(0, 400, 0, 80)
	warningFrame.Position = UDim2.new(0.5, 0, 0.3, 0)
	warningFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	warningFrame.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	warningFrame.BackgroundTransparency = 0.2
	warningFrame.BorderSizePixel = 0
	warningFrame.Visible = false
	warningFrame.Parent = self.parent
	self.warningFrame = warningFrame
	
	local warningCorner = Instance.new("UICorner")
	warningCorner.CornerRadius = UDim.new(0, 12)
	warningCorner.Parent = warningFrame
	
	local warningLabel = Instance.new("TextLabel")
	warningLabel.Name = "Message"
	warningLabel.Size = UDim2.new(1, 0, 1, 0)
	warningLabel.BackgroundTransparency = 1
	warningLabel.Text = "5 minutes remaining!"
	warningLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	warningLabel.TextSize = 32
	warningLabel.Font = Enum.Font.GothamBlack
	warningLabel.Parent = warningFrame
	self.warningLabel = warningLabel
end

function MatchLobbyUI:createRaceRankingUI()
	-- Ranking display during race
	local rankFrame = Instance.new("Frame")
	rankFrame.Name = "RaceRanking"
	rankFrame.Size = UDim2.new(0, 180, 0, 200)
	rankFrame.Position = UDim2.new(1, -10, 0, 70)
	rankFrame.AnchorPoint = Vector2.new(1, 0)
	rankFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	rankFrame.BackgroundTransparency = 0.3
	rankFrame.BorderSizePixel = 0
	rankFrame.Visible = false
	rankFrame.Parent = self.parent
	self.rankFrame = rankFrame
	
	local rankCorner = Instance.new("UICorner")
	rankCorner.CornerRadius = UDim.new(0, 10)
	rankCorner.Parent = rankFrame
	
	-- Header
	local rankHeader = Instance.new("TextLabel")
	rankHeader.Name = "Header"
	rankHeader.Size = UDim2.new(1, 0, 0, 30)
	rankHeader.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	rankHeader.BackgroundTransparency = 0.5
	rankHeader.BorderSizePixel = 0
	rankHeader.Text = "RANKINGS"
	rankHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
	rankHeader.TextSize = 14
	rankHeader.Font = Enum.Font.GothamBold
	rankHeader.Parent = rankFrame
	
	local rankHeaderCorner = Instance.new("UICorner")
	rankHeaderCorner.CornerRadius = UDim.new(0, 10)
	rankHeaderCorner.Parent = rankHeader
	
	-- Rankings list
	local rankList = Instance.new("Frame")
	rankList.Name = "List"
	rankList.Size = UDim2.new(1, -16, 1, -40)
	rankList.Position = UDim2.new(0, 8, 0, 35)
	rankList.BackgroundTransparency = 1
	rankList.Parent = rankFrame
	self.rankList = rankList
	
	local rankLayout = Instance.new("UIListLayout")
	rankLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rankLayout.Padding = UDim.new(0, 4)
	rankLayout.Parent = rankList
	
	-- Your rank indicator
	local yourRank = Instance.new("TextLabel")
	yourRank.Name = "YourRank"
	yourRank.Size = UDim2.new(0, 60, 0, 30)
	yourRank.Position = UDim2.new(1, -10, 0, 10)
	yourRank.AnchorPoint = Vector2.new(1, 0)
	yourRank.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	yourRank.BackgroundTransparency = 0.2
	yourRank.BorderSizePixel = 0
	yourRank.Text = "#1"
	yourRank.TextColor3 = Color3.fromRGB(0, 0, 0)
	yourRank.TextSize = 20
	yourRank.Font = Enum.Font.GothamBlack
	yourRank.Visible = false
	yourRank.Parent = self.parent
	self.yourRankLabel = yourRank
	
	local yourRankCorner = Instance.new("UICorner")
	yourRankCorner.CornerRadius = UDim.new(0, 8)
	yourRankCorner.Parent = yourRank
end

function MatchLobbyUI:setupButtonEvents()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	
	-- Close button
	self.closeButton.MouseButton1Click:Connect(function()
		self:hide()
	end)
	
	-- Create match button
	self.createButton.MouseButton1Click:Connect(function()
		remotes.CreateMatch:FireServer({})
	end)
	
	-- Leave button
	self.leaveButton.MouseButton1Click:Connect(function()
		remotes.LeaveMatch:FireServer()
	end)
	
	-- Button hover effects
	self:addButtonHover(self.closeButton)
	self:addButtonHover(self.createButton)
	self:addButtonHover(self.leaveButton)
end

function MatchLobbyUI:addButtonHover(button: TextButton)
	local originalColor = button.BackgroundColor3
	
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.new(
				math.min(originalColor.R + 0.1, 1),
				math.min(originalColor.G + 0.1, 1),
				math.min(originalColor.B + 0.1, 1)
			)
		}):Play()
	end)
	
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15), {
			BackgroundColor3 = originalColor
		}):Play()
	end)
end

function MatchLobbyUI:setupRemotes()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	
	-- Match update
	remotes.MatchUpdate.OnClientEvent:Connect(function(data)
		self:onMatchUpdate(data)
	end)
	
	-- Match start
	remotes.MatchStart.OnClientEvent:Connect(function(data)
		self:onMatchStart(data)
	end)
	
	-- Match end
	remotes.MatchEnd.OnClientEvent:Connect(function(data)
		self:onMatchEnd(data)
	end)
	
	-- Race update (rankings, timer)
	remotes.RaceUpdate.OnClientEvent:Connect(function(data)
		self:onRaceUpdate(data)
	end)
	
	-- Time warning
	remotes.TimeWarning.OnClientEvent:Connect(function(data)
		self:onTimeWarning(data)
	end)
end

function MatchLobbyUI:onMatchUpdate(data)
	if data.type == "roomUpdate" then
		self.currentRoom = data
		self:updatePlayerList(data.players)
		self.playerCountLabel.Text = string.format("Players: %d/%d", data.playerCount, data.maxPlayers)
		
		-- Update buttons
		self.createButton.Visible = false
		self.leaveButton.Visible = true
		
		-- Show lobby if not visible
		if not self.isVisible then
			self:show()
		end
		
	elseif data.type == "countdown" then
		if data.countdown > 0 then
			self.countdownLabel.Text = string.format("Starting in %d...", data.countdown)
			self.countdownLabel.BackgroundColor3 = Color3.fromRGB(50, 100, 150)
		end
	end
end

function MatchLobbyUI:onMatchStart(data)
	-- Hide lobby UI
	self:hide()
	
	-- Show race timer
	self.timerFrame.Visible = true
	self.rankFrame.Visible = true
	self.yourRankLabel.Visible = true
end

function MatchLobbyUI:onMatchEnd(data)
	-- Hide race UI
	self.timerFrame.Visible = false
	self.rankFrame.Visible = false
	self.yourRankLabel.Visible = false
	
	-- Reset buttons
	self.createButton.Visible = true
	self.leaveButton.Visible = false
	self.countdownLabel.Text = "Waiting for players..."
	self.countdownLabel.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
	self.currentRoom = nil
	
	-- Clear player list
	self:clearPlayerList()
end

function MatchLobbyUI:onRaceUpdate(data)
	-- Update timer
	local minutes = math.floor(data.timeRemaining / 60)
	local seconds = math.floor(data.timeRemaining % 60)
	self.timerLabel.Text = string.format("%02d:%02d", minutes, seconds)
	
	-- Change timer color based on time remaining
	if data.timeRemaining <= 30 then
		self.timerLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
		self.timerStroke.Color = Color3.fromRGB(255, 50, 50)
	elseif data.timeRemaining <= 60 then
		self.timerLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
		self.timerStroke.Color = Color3.fromRGB(255, 200, 50)
	elseif data.timeRemaining <= 300 then
		self.timerLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
		self.timerStroke.Color = Color3.fromRGB(100, 200, 100)
	else
		self.timerLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		self.timerStroke.Color = Color3.fromRGB(100, 200, 100)
	end
	
	-- Update your rank
	self.yourRankLabel.Text = "#" .. data.yourRank
	
	-- Update rankings list
	self:updateRankingsList(data.rankings, data.yourRank)
end

function MatchLobbyUI:onTimeWarning(data)
	-- Show warning
	self.warningLabel.Text = data.message
	self.warningFrame.Visible = true
	
	-- Critical warning styling
	if data.isCritical then
		self.warningFrame.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		-- Pulse animation
		task.spawn(function()
			for i = 1, 3 do
				TweenService:Create(self.warningFrame, TweenInfo.new(0.2), {
					BackgroundTransparency = 0
				}):Play()
				task.wait(0.2)
				TweenService:Create(self.warningFrame, TweenInfo.new(0.2), {
					BackgroundTransparency = 0.3
				}):Play()
				task.wait(0.2)
			end
		end)
	else
		self.warningFrame.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
	end
	
	-- Hide after delay
	task.delay(3, function()
		TweenService:Create(self.warningFrame, TweenInfo.new(0.5), {
			BackgroundTransparency = 1
		}):Play()
		task.delay(0.5, function()
			self.warningFrame.Visible = false
			self.warningFrame.BackgroundTransparency = 0.2
		end)
	end)
end

function MatchLobbyUI:updatePlayerList(playerNames: {string})
	-- Clear existing
	self:clearPlayerList()
	
	-- Add players
	for i, name in ipairs(playerNames) do
		local playerEntry = Instance.new("Frame")
		playerEntry.Name = "Player_" .. i
		playerEntry.Size = UDim2.new(1, -16, 0, 35)
		playerEntry.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
		playerEntry.BackgroundTransparency = 0.5
		playerEntry.BorderSizePixel = 0
		playerEntry.LayoutOrder = i
		playerEntry.Parent = self.playerList
		
		local entryCorner = Instance.new("UICorner")
		entryCorner.CornerRadius = UDim.new(0, 6)
		entryCorner.Parent = playerEntry
		
		-- Player number
		local numLabel = Instance.new("TextLabel")
		numLabel.Size = UDim2.new(0, 30, 1, 0)
		numLabel.BackgroundTransparency = 1
		numLabel.Text = i .. "."
		numLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		numLabel.TextSize = 14
		numLabel.Font = Enum.Font.GothamMedium
		numLabel.Parent = playerEntry
		
		-- Player name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -40, 1, 0)
		nameLabel.Position = UDim2.new(0, 35, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = name
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 16
		nameLabel.Font = Enum.Font.GothamMedium
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = playerEntry
		
		-- Host indicator
		if i == 1 then
			local hostIcon = Instance.new("TextLabel")
			hostIcon.Size = UDim2.new(0, 50, 0, 20)
			hostIcon.Position = UDim2.new(1, -55, 0.5, 0)
			hostIcon.AnchorPoint = Vector2.new(0, 0.5)
			hostIcon.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
			hostIcon.BackgroundTransparency = 0.3
			hostIcon.BorderSizePixel = 0
			hostIcon.Text = "HOST"
			hostIcon.TextColor3 = Color3.fromRGB(0, 0, 0)
			hostIcon.TextSize = 10
			hostIcon.Font = Enum.Font.GothamBold
			hostIcon.Parent = playerEntry
			
			local hostCorner = Instance.new("UICorner")
			hostCorner.CornerRadius = UDim.new(0, 4)
			hostCorner.Parent = hostIcon
		end
	end
	
	-- Update canvas size
	self.playerList.CanvasSize = UDim2.new(0, 0, 0, #playerNames * 40)
end

function MatchLobbyUI:updateRankingsList(rankings: {string}, yourRank: number)
	-- Clear existing
	for _, child in ipairs(self.rankList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	-- Show top 5 rankings
	local showCount = math.min(#rankings, 5)
	
	for i = 1, showCount do
		local rankEntry = Instance.new("Frame")
		rankEntry.Name = "Rank_" .. i
		rankEntry.Size = UDim2.new(1, 0, 0, 28)
		rankEntry.BackgroundColor3 = i == yourRank and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(40, 40, 60)
		rankEntry.BackgroundTransparency = i == yourRank and 0.3 or 0.7
		rankEntry.BorderSizePixel = 0
		rankEntry.LayoutOrder = i
		rankEntry.Parent = self.rankList
		
		local entryCorner = Instance.new("UICorner")
		entryCorner.CornerRadius = UDim.new(0, 4)
		entryCorner.Parent = rankEntry
		
		-- Position medal
		local medal = ""
		if i == 1 then medal = "🥇"
		elseif i == 2 then medal = "🥈"
		elseif i == 3 then medal = "🥉"
		else medal = i .. "."
		end
		
		local posLabel = Instance.new("TextLabel")
		posLabel.Size = UDim2.new(0, 30, 1, 0)
		posLabel.BackgroundTransparency = 1
		posLabel.Text = medal
		posLabel.TextSize = i <= 3 and 16 or 12
		posLabel.Font = Enum.Font.GothamMedium
		posLabel.Parent = rankEntry
		
		-- Name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -35, 1, 0)
		nameLabel.Position = UDim2.new(0, 30, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = rankings[i] or ""
		nameLabel.TextColor3 = i == yourRank and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
		nameLabel.TextSize = 12
		nameLabel.Font = Enum.Font.GothamMedium
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = rankEntry
	end
end

function MatchLobbyUI:clearPlayerList()
	for _, child in ipairs(self.playerList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

function MatchLobbyUI:show()
	self.isVisible = true
	self.container.Visible = true
	
	-- Animate in
	self.container.Position = UDim2.new(0.5, 0, 0.5, 50)
	self.container.BackgroundTransparency = 1
	
	TweenService:Create(self.container, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 0.1
	}):Play()
end

function MatchLobbyUI:hide()
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

function MatchLobbyUI:toggle()
	if self.isVisible then
		self:hide()
	else
		self:show()
	end
end

return MatchLobbyUI
