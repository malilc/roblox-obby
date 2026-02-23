-- LeaderboardManager: จัดการ Global Leaderboard ด้วย OrderedDataStore + Physical Board
-- 2 boards: Gems (💎) and Wins (🏆)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Logger)
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)

local LeaderboardManager = {}
LeaderboardManager.__index = LeaderboardManager

local GEM_STORE = "ObbyLeaderboard_Gems_v1"
local WIN_STORE = "ObbyLeaderboard_Wins_v1"
local TOP_COUNT = 10
local REFRESH_INTERVAL = 60 -- วินาที

-- Physical board config
local PIXELS_PER_STUD = 80
local BOARD_SIZE = Vector3.new(10, 14, 0.5)

-- Board positions — flanking SelectionZone (X=0, Z=30)
local WIN_BOARD_POS = Vector3.new(-22, 109, 30)
local GEM_BOARD_POS = Vector3.new(22, 109, 30)

local WHITE = Theme.TEXT_PRIMARY
local SILVER = Color3.fromRGB(200, 200, 220)
local BRONZE = Color3.fromRGB(210, 130, 60)
local MUTED = Theme.TEXT_MUTED
local DARK = Theme.BG_OVERLAY

local RANK_MEDAL = { "🥇", "🥈", "🥉" }

function LeaderboardManager.new()
	local self = setmetatable({}, LeaderboardManager)

	self.gemStore = nil
	self.winStore = nil
	self.cachedGemTop = {} :: {{rank: number, name: string, score: number}}
	self.cachedWinTop = {} :: {{rank: number, name: string, score: number}}

	pcall(function()
		self.gemStore = DataStoreService:GetOrderedDataStore(GEM_STORE)
	end)
	pcall(function()
		self.winStore = DataStoreService:GetOrderedDataStore(WIN_STORE)
	end)

	self.leaderboardUpdateRemote = ReplicatedStorage.Remotes:WaitForChild("LeaderboardUpdate")

	-- Create both physical boards
	self.gemBoard = self:_createBoard("GemLeaderboard", GEM_BOARD_POS, "💎", "GEM LEADERS", "TOP 10 COLLECTORS", {
		titleGradStart = Color3.fromRGB(180, 80, 255),
		titleGradEnd = Color3.fromRGB(120, 40, 200),
		strokeColor = Color3.fromRGB(200, 120, 255),
		rankColors = { Color3.fromRGB(200, 120, 255), SILVER, BRONZE },
		scoreColor = Color3.fromRGB(200, 120, 255),
		suffix = " 💎",
	})

	self.winBoard = self:_createBoard("WinLeaderboard", WIN_BOARD_POS, "🏆", "WIN LEADERS", "TOP 10 WINNERS", {
		titleGradStart = Theme.PRIMARY,
		titleGradEnd = Theme.PRIMARY_DARK,
		strokeColor = Theme.PRIMARY,
		rankColors = { Theme.MEDAL_GOLD, SILVER, BRONZE },
		scoreColor = Theme.MEDAL_GOLD,
		suffix = " 🏆",
	})

	self:startRefreshLoop()

	return self
end

-- ──────────────────────────────────────────────
-- Physical Board Creation (reusable helper)
-- ──────────────────────────────────────────────

function LeaderboardManager:_createBoard(
	name: string,
	position: Vector3,
	icon: string,
	title: string,
	subtitle: string,
	style: {[string]: any}
): {part: BasePart, rows: {{nameLbl: TextLabel, scoreLbl: TextLabel}}, suffix: string}
	-- Reuse an existing Part if placed manually
	local part = workspace:FindFirstChild(name)
	if not (part and part:IsA("BasePart")) then
		part = Instance.new("Part")
		part.Name = name
		part.Size = BOARD_SIZE
		part.CFrame = CFrame.new(position, Vector3.new(0, position.Y, -8))
		part.Anchored = true
		part.CanCollide = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Theme.BG_BASE
		part.Parent = workspace
	end

	-- Remove old SurfaceGui
	local old = part:FindFirstChild("LeaderboardSurface")
	if old then old:Destroy() end

	local canvasW = BOARD_SIZE.X * PIXELS_PER_STUD
	local canvasH = BOARD_SIZE.Y * PIXELS_PER_STUD

	local sg = Instance.new("SurfaceGui")
	sg.Name = "LeaderboardSurface"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = PIXELS_PER_STUD
	sg.CanvasSize = Vector2.new(canvasW, canvasH)
	sg.ClipsDescendants = true
	sg.AlwaysOnTop = false
	sg.Parent = part

	-- Background
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = DARK
	bg.BorderSizePixel = 0
	bg.Parent = sg

	local bgGrad = Instance.new("UIGradient")
	bgGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.BG_SURFACE),
		ColorSequenceKeypoint.new(1, Theme.BG_OVERLAY),
	})
	bgGrad.Rotation = 135
	bgGrad.Parent = bg

	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color = style.strokeColor
	bgStroke.Thickness = 4
	bgStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bgStroke.Parent = bg

	-- Title bar
	local TITLE_H = 130
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
	titleBar.BackgroundColor3 = style.titleGradStart
	titleBar.BorderSizePixel = 0
	titleBar.ZIndex = 2
	titleBar.Parent = sg

	local titleGrad = Instance.new("UIGradient")
	titleGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, style.titleGradStart),
		ColorSequenceKeypoint.new(1, style.titleGradEnd),
	})
	titleGrad.Rotation = 90
	titleGrad.Parent = titleBar

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(0, 100, 1, 0)
	iconLabel.Position = UDim2.new(0, 10, 0, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = icon
	iconLabel.TextSize = 70
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.ZIndex = 3
	iconLabel.Parent = titleBar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -120, 0.55, 0)
	titleLabel.Position = UDim2.new(0, 110, 0, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = DARK
	titleLabel.TextSize = 46
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 3
	titleLabel.Parent = titleBar

	local subLabel = Instance.new("TextLabel")
	subLabel.Size = UDim2.new(1, -120, 0.45, 0)
	subLabel.Position = UDim2.new(0, 110, 0.55, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Text = subtitle
	subLabel.TextColor3 = Theme.BG_OVERLAY
	subLabel.TextSize = 30
	subLabel.Font = Enum.Font.GothamBold
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	subLabel.ZIndex = 3
	subLabel.Parent = titleBar

	-- Row list
	local ROW_H = (canvasH - TITLE_H) / TOP_COUNT
	local PAD = 8
	local rows = {}

	for i = 1, TOP_COUNT do
		local rowY = TITLE_H + (i - 1) * ROW_H
		local isEven = (i % 2 == 0)

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -PAD * 2, 0, ROW_H - 4)
		row.Position = UDim2.new(0, PAD, 0, rowY + 2)
		row.BackgroundColor3 = isEven and Theme.BG_OVERLAY or Theme.BG_BASE
		row.BackgroundTransparency = 0.1
		row.BorderSizePixel = 0
		row.ZIndex = 2
		row.Parent = sg

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 8)
		rowCorner.Parent = row

		-- Rank
		local rankColor = if i <= 3 then style.rankColors[i] else MUTED
		local rankLbl = Instance.new("TextLabel")
		rankLbl.Size = UDim2.new(0, 90, 1, 0)
		rankLbl.Position = UDim2.new(0, 0, 0, 0)
		rankLbl.BackgroundTransparency = 1
		rankLbl.Text = if i <= 3 then RANK_MEDAL[i] else "#" .. i
		rankLbl.TextColor3 = rankColor
		rankLbl.TextSize = if i <= 3 then 40 else 30
		rankLbl.Font = Enum.Font.GothamBlack
		rankLbl.ZIndex = 3
		rankLbl.Parent = row

		-- Name
		local nameLbl = Instance.new("TextLabel")
		nameLbl.Name = "PlayerName"
		nameLbl.Size = UDim2.new(1, -230, 1, 0)
		nameLbl.Position = UDim2.new(0, 96, 0, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = "---"
		nameLbl.TextColor3 = WHITE
		nameLbl.TextSize = 28
		nameLbl.Font = Enum.Font.Gotham
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.ZIndex = 3
		nameLbl.Parent = row

		-- Score
		local scoreLbl = Instance.new("TextLabel")
		scoreLbl.Name = "Score"
		scoreLbl.Size = UDim2.new(0, 200, 1, 0)
		scoreLbl.Position = UDim2.new(1, -210, 0, 0)
		scoreLbl.BackgroundTransparency = 1
		scoreLbl.Text = "---"
		scoreLbl.TextColor3 = style.scoreColor
		scoreLbl.TextSize = 28
		scoreLbl.Font = Enum.Font.GothamBold
		scoreLbl.TextXAlignment = Enum.TextXAlignment.Right
		scoreLbl.ZIndex = 3
		scoreLbl.Parent = row

		rows[i] = { nameLbl = nameLbl, scoreLbl = scoreLbl }
	end

	Logger.info("LeaderboardManager", name, "board created at", tostring(position))

	return { part = part, rows = rows, suffix = style.suffix }
end

-- ──────────────────────────────────────────────
-- Update board UI
-- ──────────────────────────────────────────────

function LeaderboardManager:_updateBoardUI(
	board: {rows: {{nameLbl: TextLabel, scoreLbl: TextLabel}}, suffix: string},
	top: {{rank: number, name: string, score: number}}
)
	if not board or #board.rows == 0 then return end
	for i = 1, TOP_COUNT do
		local row = board.rows[i]
		local entry = top[i]
		if row then
			if entry then
				row.nameLbl.Text = entry.name
				row.scoreLbl.Text = tostring(entry.score) .. board.suffix
			else
				row.nameLbl.Text = "---"
				row.scoreLbl.Text = "---"
			end
		end
	end
end

-- ──────────────────────────────────────────────
-- Update scores
-- ──────────────────────────────────────────────

function LeaderboardManager:updateGems(player: Player, gems: number)
	if not self.gemStore then return end
	if gems <= 0 then return end

	local userId = player.UserId
	pcall(function()
		self.gemStore:UpdateAsync(tostring(userId), function(existing)
			local current = tonumber(existing) or 0
			if gems > current then
				return gems
			end
			return existing
		end)
	end)

	Logger.debug("LeaderboardManager", "Updated gems for", player.Name, ":", gems)
end

function LeaderboardManager:updateWins(player: Player, wins: number)
	if not self.winStore then return end
	if wins <= 0 then return end

	local userId = player.UserId
	pcall(function()
		self.winStore:UpdateAsync(tostring(userId), function(existing)
			local current = tonumber(existing) or 0
			if wins > current then
				return wins
			end
			return existing
		end)
	end)

	Logger.debug("LeaderboardManager", "Updated wins for", player.Name, ":", wins)
end

-- ──────────────────────────────────────────────
-- Fetch top scores
-- ──────────────────────────────────────────────

function LeaderboardManager:_fetchTop(store: any): {{rank: number, name: string, score: number}}
	if not store then return {} end

	local result = {}
	local success, pages = pcall(function()
		return store:GetSortedAsync(false, TOP_COUNT)
	end)

	if not success or not pages then return {} end

	local ok, data = pcall(function()
		return pages:GetCurrentPage()
	end)

	if not ok or not data then return {} end

	for rank, entry in ipairs(data) do
		local userId = tonumber(entry.key)
		local score = entry.value
		local name = "Player"

		pcall(function()
			name = Players:GetNameFromUserIdAsync(userId)
		end)

		table.insert(result, {
			rank = rank,
			name = name,
			score = score,
		})
	end

	return result
end

-- ──────────────────────────────────────────────
-- Broadcast
-- ──────────────────────────────────────────────

function LeaderboardManager:broadcast()
	local gemTop = self:_fetchTop(self.gemStore)
	local winTop = self:_fetchTop(self.winStore)
	self.cachedGemTop = gemTop
	self.cachedWinTop = winTop

	-- Update physical boards
	self:_updateBoardUI(self.gemBoard, gemTop)
	self:_updateBoardUI(self.winBoard, winTop)

	-- Notify clients
	for _, player in ipairs(Players:GetPlayers()) do
		self.leaderboardUpdateRemote:FireClient(player, {
			gemTop = gemTop,
			winTop = winTop,
		})
	end

	Logger.debug("LeaderboardManager", "Broadcasted leaderboards - Gems:", #gemTop, "Wins:", #winTop)
end

function LeaderboardManager:sendToPlayer(player: Player)
	if #self.cachedGemTop > 0 or #self.cachedWinTop > 0 then
		self.leaderboardUpdateRemote:FireClient(player, {
			gemTop = self.cachedGemTop,
			winTop = self.cachedWinTop,
		})
	end
end

function LeaderboardManager:startRefreshLoop()
	task.spawn(function()
		while true do
			task.wait(REFRESH_INTERVAL)
			self:broadcast()
		end
	end)

	-- Initial fetch after short delay (รอ DataStore ready)
	task.delay(5, function()
		self:broadcast()
	end)
end

return LeaderboardManager
