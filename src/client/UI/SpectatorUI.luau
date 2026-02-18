-- SpectatorUI: HUD + Controls สำหรับ Spectator Mode

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SpectatorCamera = require(script.Parent.Parent.SpectatorCamera)
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)

local LocalPlayer = Players.LocalPlayer

local SpectatorUI = {}
SpectatorUI.__index = SpectatorUI

function SpectatorUI.new(parent: ScreenGui)
	local self = setmetatable({}, SpectatorUI)

	self.parent = parent
	self.isVisible = false
	self.isSpectating = false
	self.spectatorCamera = SpectatorCamera.new()
	self.currentMode = "Follow"
	self.latestRankings = {}
	self.latestTimeRemaining = 0
	self.activePlayers = {} :: {Player}
	self.selectedPlayerIndex = 1
	self.rankingEntries = {}

	self:createUI()
	self:setupRemotes()

	return self
end

function SpectatorUI:createUI()
	-- === Spectate Prompt (หลังจบ race) ===
	local promptContainer = Instance.new("Frame")
	promptContainer.Name = "SpectatePrompt"
	promptContainer.Size = UDim2.new(0, 280, 0, 50)
	promptContainer.Position = UDim2.new(0.5, -140, 1, -70)
	promptContainer.BackgroundTransparency = 1
	promptContainer.Visible = false
	promptContainer.ZIndex = 8
	promptContainer.Parent = self.parent
	self.promptContainer = promptContainer

	local spectateBtn = Instance.new("TextButton")
	spectateBtn.Name = "SpectateButton"
	spectateBtn.Size = UDim2.new(0, 130, 0, 42)
	spectateBtn.Position = UDim2.new(0, 0, 0, 0)
	spectateBtn.BackgroundColor3 = Theme.ACCENT_CYAN
	spectateBtn.Text = "SPECTATE"
	spectateBtn.TextColor3 = Theme.TEXT_DARK
	spectateBtn.TextSize = 16
	spectateBtn.Font = Enum.Font.GothamBold
	spectateBtn.AutoButtonColor = false
	spectateBtn.ZIndex = 9
	spectateBtn.Parent = promptContainer

	local specCorner = Instance.new("UICorner")
	specCorner.CornerRadius = Theme.CORNER_SM
	specCorner.Parent = spectateBtn

	local specStroke = Instance.new("UIStroke")
	specStroke.Color = Theme.ACCENT_CYAN
	specStroke.Thickness = Theme.STROKE_MED
	specStroke.Parent = spectateBtn

	spectateBtn.MouseButton1Click:Connect(function()
		self:startSpectating()
	end)

	local leavePromptBtn = Instance.new("TextButton")
	leavePromptBtn.Name = "LeavePromptButton"
	leavePromptBtn.Size = UDim2.new(0, 130, 0, 42)
	leavePromptBtn.Position = UDim2.new(0, 145, 0, 0)
	leavePromptBtn.BackgroundColor3 = Theme.BG_SURFACE
	leavePromptBtn.Text = "LEAVE"
	leavePromptBtn.TextColor3 = Theme.DANGER
	leavePromptBtn.TextSize = 16
	leavePromptBtn.Font = Enum.Font.GothamBold
	leavePromptBtn.AutoButtonColor = false
	leavePromptBtn.ZIndex = 9
	leavePromptBtn.Parent = promptContainer

	local leaveCorner = Instance.new("UICorner")
	leaveCorner.CornerRadius = Theme.CORNER_SM
	leaveCorner.Parent = leavePromptBtn

	local leaveStroke = Instance.new("UIStroke")
	leaveStroke.Color = Theme.DANGER
	leaveStroke.Thickness = Theme.STROKE_MED
	leaveStroke.Parent = leavePromptBtn

	leavePromptBtn.MouseButton1Click:Connect(function()
		self:hideSpectatePrompt()
		self:fireLeaveRemote()
	end)

	-- === Spectator HUD (ระหว่าง spectate) ===
	local hud = Instance.new("Frame")
	hud.Name = "SpectatorHUD"
	hud.Size = UDim2.new(1, 0, 1, 0)
	hud.BackgroundTransparency = 1
	hud.Visible = false
	hud.ZIndex = 8
	hud.Parent = self.parent
	self.hud = hud

	-- Top label: "SPECTATING: PlayerName"
	local topLabel = Instance.new("TextLabel")
	topLabel.Name = "SpectatingLabel"
	topLabel.Size = UDim2.new(0, 300, 0, 36)
	topLabel.Position = UDim2.new(0.5, -150, 0, 10)
	topLabel.BackgroundColor3 = Theme.BG_BASE
	topLabel.BackgroundTransparency = 0.3
	topLabel.Text = "SPECTATING"
	topLabel.TextColor3 = Theme.ACCENT_CYAN
	topLabel.TextSize = 16
	topLabel.Font = Enum.Font.GothamBold
	topLabel.ZIndex = 9
	topLabel.Parent = hud
	self.spectatingLabel = topLabel

	local topCorner = Instance.new("UICorner")
	topCorner.CornerRadius = Theme.CORNER_SM
	topCorner.Parent = topLabel

	-- Left: Rankings panel
	local rankingsPanel = Instance.new("Frame")
	rankingsPanel.Name = "RankingsPanel"
	rankingsPanel.Size = UDim2.new(0, 200, 0, 300)
	rankingsPanel.Position = UDim2.new(0, 10, 0, 60)
	rankingsPanel.BackgroundColor3 = Theme.BG_BASE
	rankingsPanel.BackgroundTransparency = 0.3
	rankingsPanel.BorderSizePixel = 0
	rankingsPanel.ZIndex = 9
	rankingsPanel.Parent = hud
	self.rankingsPanel = rankingsPanel

	local rankCorner = Instance.new("UICorner")
	rankCorner.CornerRadius = Theme.CORNER_SM
	rankCorner.Parent = rankingsPanel

	local rankStroke = Instance.new("UIStroke")
	rankStroke.Color = Theme.BG_ELEVATED
	rankStroke.Thickness = Theme.STROKE_THIN
	rankStroke.Parent = rankingsPanel

	-- Rankings header
	local rankHeader = Instance.new("TextLabel")
	rankHeader.Name = "RankHeader"
	rankHeader.Size = UDim2.new(1, 0, 0, 28)
	rankHeader.BackgroundTransparency = 1
	rankHeader.Text = "RANKINGS"
	rankHeader.TextColor3 = Theme.TEXT_MUTED
	rankHeader.TextSize = 13
	rankHeader.Font = Enum.Font.GothamBold
	rankHeader.ZIndex = 10
	rankHeader.Parent = rankingsPanel

	-- Time remaining
	local timeLabel = Instance.new("TextLabel")
	timeLabel.Name = "TimeLabel"
	timeLabel.Size = UDim2.new(1, 0, 0, 20)
	timeLabel.Position = UDim2.new(0, 0, 0, 26)
	timeLabel.BackgroundTransparency = 1
	timeLabel.Text = ""
	timeLabel.TextColor3 = Theme.TEXT_MUTED
	timeLabel.TextSize = 11
	timeLabel.Font = Enum.Font.Gotham
	timeLabel.ZIndex = 10
	timeLabel.Parent = rankingsPanel
	self.timeLabel = timeLabel

	-- Rankings list container
	local rankList = Instance.new("Frame")
	rankList.Name = "RankList"
	rankList.Size = UDim2.new(1, -12, 1, -56)
	rankList.Position = UDim2.new(0, 6, 0, 50)
	rankList.BackgroundTransparency = 1
	rankList.ZIndex = 10
	rankList.Parent = rankingsPanel

	local rankLayout = Instance.new("UIListLayout")
	rankLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rankLayout.Padding = UDim.new(0, 2)
	rankLayout.Parent = rankList
	self.rankList = rankList

	-- Bottom controls bar
	local controlBar = Instance.new("Frame")
	controlBar.Name = "ControlBar"
	controlBar.Size = UDim2.new(0, 400, 0, 44)
	controlBar.Position = UDim2.new(0.5, -200, 1, -60)
	controlBar.BackgroundColor3 = Theme.BG_BASE
	controlBar.BackgroundTransparency = 0.3
	controlBar.BorderSizePixel = 0
	controlBar.ZIndex = 9
	controlBar.Parent = hud

	local controlCorner = Instance.new("UICorner")
	controlCorner.CornerRadius = Theme.CORNER_SM
	controlCorner.Parent = controlBar

	local controlLayout = Instance.new("UIListLayout")
	controlLayout.FillDirection = Enum.FillDirection.Horizontal
	controlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	controlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	controlLayout.Padding = UDim.new(0, 8)
	controlLayout.Parent = controlBar

	-- Prev button
	local prevBtn = self:createControlButton(controlBar, "Prev", "< Prev", 1, function()
		self:cyclePlayer(-1)
	end)

	-- Mode toggle
	local modeBtn = self:createControlButton(controlBar, "ModeToggle", "Free Cam", 2, function()
		self:toggleMode()
	end)
	self.modeButton = modeBtn

	-- Next button
	local nextBtn = self:createControlButton(controlBar, "Next", "Next >", 3, function()
		self:cyclePlayer(1)
	end)

	-- Leave button
	local leaveBtn = self:createControlButton(controlBar, "Leave", "Leave", 4, function()
		self:stopSpectating()
	end)
	leaveBtn.BackgroundColor3 = Theme.BG_SURFACE
	leaveBtn.TextColor3 = Theme.DANGER
end

function SpectatorUI:createControlButton(parent: Frame, name: string, label: string, order: number, callback: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(0, 85, 0, 32)
	button.BackgroundColor3 = Theme.BG_ELEVATED
	button.Text = label
	button.TextColor3 = Theme.TEXT_MUTED
	button.TextSize = 13
	button.Font = Enum.Font.GothamBold
	button.AutoButtonColor = false
	button.LayoutOrder = order
	button.ZIndex = 10
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CORNER_SM
	corner.Parent = button

	button.MouseButton1Click:Connect(callback)
	return button
end

function SpectatorUI:showSpectatePrompt()
	self.promptContainer.Visible = true

	-- Animate in
	self.promptContainer.Position = UDim2.new(0.5, -140, 1, -50)
	TweenService:Create(self.promptContainer, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, -140, 1, -70),
	}):Play()
end

function SpectatorUI:hideSpectatePrompt()
	self.promptContainer.Visible = false
end

function SpectatorUI:startSpectating()
	self:hideSpectatePrompt()

	-- Fire SpectateMatch remote
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local spectateRemote = remotes and remotes:FindFirstChild("SpectateMatch")
	if spectateRemote then
		spectateRemote:FireServer()
	end

	-- Build active player list from latest rankings
	self:buildActivePlayerList()

	-- Start camera
	self.spectatorCamera:start()
	self.isSpectating = true

	-- Follow first active player
	if #self.activePlayers > 0 then
		self.selectedPlayerIndex = 1
		self:followCurrentTarget()
	else
		self.spectatorCamera:setFreeCamMode()
		self.currentMode = "FreeCam"
	end

	-- Show HUD
	self.hud.Visible = true
	self:updateModeDisplay()
end

function SpectatorUI:stopSpectating()
	self.isSpectating = false
	self.hud.Visible = false

	-- Stop camera
	self.spectatorCamera:stop()

	-- Fire SpectatorLeave remote
	self:fireLeaveRemote()
end

function SpectatorUI:fireLeaveRemote()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local leaveRemote = remotes and remotes:FindFirstChild("SpectatorLeave")
	if leaveRemote then
		leaveRemote:FireServer()
	end
end

function SpectatorUI:toggleMode()
	if self.currentMode == "Follow" then
		self.currentMode = "FreeCam"
		self.spectatorCamera:setFreeCamMode()
	else
		self.currentMode = "Follow"
		self:followCurrentTarget()
	end
	self:updateModeDisplay()
end

function SpectatorUI:updateModeDisplay()
	if self.modeButton then
		if self.currentMode == "Follow" then
			self.modeButton.Text = "Free Cam"
		else
			self.modeButton.Text = "Follow"
		end
	end
end

function SpectatorUI:followCurrentTarget()
	if #self.activePlayers == 0 then return end

	self.selectedPlayerIndex = math.clamp(self.selectedPlayerIndex, 1, #self.activePlayers)
	local target = self.activePlayers[self.selectedPlayerIndex]

	if target then
		self.spectatorCamera:setFollowMode(target)
		self.spectatingLabel.Text = "SPECTATING: " .. target.Name
	end
end

function SpectatorUI:cyclePlayer(direction: number)
	if #self.activePlayers == 0 then return end

	self.selectedPlayerIndex = self.selectedPlayerIndex + direction
	if self.selectedPlayerIndex > #self.activePlayers then
		self.selectedPlayerIndex = 1
	elseif self.selectedPlayerIndex < 1 then
		self.selectedPlayerIndex = #self.activePlayers
	end

	if self.currentMode ~= "Follow" then
		self.currentMode = "Follow"
		self:updateModeDisplay()
	end

	self:followCurrentTarget()
end

function SpectatorUI:buildActivePlayerList()
	self.activePlayers = {}

	for _, ranking in ipairs(self.latestRankings) do
		if not ranking.finished then
			local player = Players:FindFirstChild(ranking.playerName)
			if player and player ~= LocalPlayer then
				table.insert(self.activePlayers, player)
			end
		end
	end

	-- If no active players, include finished ones (excluding self)
	if #self.activePlayers == 0 then
		for _, ranking in ipairs(self.latestRankings) do
			local player = Players:FindFirstChild(ranking.playerName)
			if player and player ~= LocalPlayer then
				table.insert(self.activePlayers, player)
			end
		end
	end
end

function SpectatorUI:updateRankings(data: {[string]: any})
	self.latestRankings = data.rankings or {}
	self.latestTimeRemaining = data.timeRemaining or 0

	-- Update time
	local minutes = math.floor(self.latestTimeRemaining / 60)
	local seconds = math.floor(self.latestTimeRemaining % 60)
	self.timeLabel.Text = string.format("Time: %d:%02d", minutes, seconds)

	-- Clear old entries
	for _, entry in ipairs(self.rankingEntries) do
		entry:Destroy()
	end
	self.rankingEntries = {}

	-- Create ranking entries
	for i, ranking in ipairs(self.latestRankings) do
		local entry = Instance.new("TextLabel")
		entry.Name = "Rank_" .. i
		entry.Size = UDim2.new(1, 0, 0, 22)
		entry.BackgroundTransparency = 1
		entry.LayoutOrder = i
		entry.ZIndex = 11

		local medal = if i == 1 then "#1 " elseif i == 2 then "#2 " elseif i == 3 then "#3 " else "#" .. i .. " "
		local status = if ranking.finished then " [DONE]" else " Stage " .. (ranking.stage or 0)
		entry.Text = medal .. ranking.playerName .. status

		-- Highlight followed player
		local isFollowed = self.currentMode == "Follow"
			and self.activePlayers[self.selectedPlayerIndex]
			and self.activePlayers[self.selectedPlayerIndex].Name == ranking.playerName

		if ranking.playerName == LocalPlayer.Name then
			entry.TextColor3 = Theme.PRIMARY
		elseif isFollowed then
			entry.TextColor3 = Theme.ACCENT_CYAN
		elseif ranking.finished then
			entry.TextColor3 = Theme.SUCCESS
		else
			entry.TextColor3 = Theme.TEXT_MUTED
		end

		entry.TextSize = 12
		entry.Font = Enum.Font.GothamMedium
		entry.TextXAlignment = Enum.TextXAlignment.Left
		entry.Parent = self.rankList

		table.insert(self.rankingEntries, entry)
	end

	-- Update active player list
	self:buildActivePlayerList()

	-- Check if follow target is still valid
	if self.isSpectating and self.currentMode == "Follow" then
		if not self.spectatorCamera:isFollowTargetValid() then
			-- Target disconnected or invalid, cycle to next
			if #self.activePlayers > 0 then
				self.selectedPlayerIndex = math.clamp(self.selectedPlayerIndex, 1, #self.activePlayers)
				self:followCurrentTarget()
			else
				-- No one left, switch to free cam
				self.currentMode = "FreeCam"
				self.spectatorCamera:setFreeCamMode()
				self:updateModeDisplay()
				self.spectatingLabel.Text = "FREE CAM"
			end
		end
	end
end

function SpectatorUI:setupRemotes()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	-- RaceUpdate: live rankings
	remotes.RaceUpdate.OnClientEvent:Connect(function(data)
		if self.isSpectating then
			self:updateRankings(data)
		elseif self.promptContainer.Visible then
			-- Store rankings even before spectating (for buildActivePlayerList)
			self.latestRankings = data.rankings or {}
		end
	end)

	-- MatchEnd: exit spectator
	remotes.MatchEnd.OnClientEvent:Connect(function()
		if self.isSpectating then
			self:stopSpectating()
		end
		self:hideSpectatePrompt()
	end)
end

function SpectatorUI:show()
	self.isVisible = true
end

function SpectatorUI:hide()
	self.isVisible = false
	if self.isSpectating then
		self:stopSpectating()
	end
	self:hideSpectatePrompt()
end

return SpectatorUI
