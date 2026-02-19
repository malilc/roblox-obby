-- LeaderboardManager: จัดการ Global Leaderboard ด้วย OrderedDataStore + Physical Board

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Logger)
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)

local LeaderboardManager = {}
LeaderboardManager.__index = LeaderboardManager

local LEADERBOARD_STORE = "ObbyLeaderboard_v1"
local TOP_COUNT = 10
local REFRESH_INTERVAL = 60 -- วินาที

-- Physical board config — วางข้างๆ stage select (ขวามือของผู้เล่นที่หันหน้าไป +Z)
local BOARD_POSITION  = Vector3.new(22, 109, 12)  -- lobby floor ~Y102, right side
local BOARD_SIZE      = Vector3.new(10, 14, 0.5)  -- width × height × thickness
local BOARD_COLOR     = Theme.BG_BASE
local PIXELS_PER_STUD = 80

local GOLD   = Theme.PRIMARY
local WHITE  = Theme.TEXT_PRIMARY
local SILVER = Color3.fromRGB(200, 200, 220)  -- medal standard
local BRONZE = Color3.fromRGB(210, 130, 60)   -- medal standard
local MUTED  = Theme.TEXT_MUTED
local GREEN  = Theme.SUCCESS
local DARK   = Theme.BG_OVERLAY

local RANK_MEDAL = { "🥇", "🥈", "🥉" }
local RANK_COLOR = { GOLD, SILVER, BRONZE }

function LeaderboardManager.new()
	local self = setmetatable({}, LeaderboardManager)

	self.orderedStore = nil
	self.cachedTop = {} :: {{rank: number, name: string, score: number}}
	self.boardPart  = nil
	self.boardRows  = {}

	pcall(function()
		self.orderedStore = DataStoreService:GetOrderedDataStore(LEADERBOARD_STORE)
	end)

	self.leaderboardUpdateRemote = ReplicatedStorage.Remotes:WaitForChild("LeaderboardUpdate")

	-- Create physical board, then start refresh loop
	self:_createPhysicalBoard()
	self:startRefreshLoop()

	return self
end

-- ──────────────────────────────────────────────
-- Physical Board
-- ──────────────────────────────────────────────

function LeaderboardManager:_createPhysicalBoard()
	-- Reuse an existing Part named "GlobalLeaderboard" if placed manually
	local part = workspace:FindFirstChild("GlobalLeaderboard")
	if not (part and part:IsA("BasePart")) then
		part = Instance.new("Part")
		part.Name        = "GlobalLeaderboard"
		part.Size        = BOARD_SIZE
		-- หันเฉียงไปทาง SpawnLocation (0, y, -8) ~42° จาก west → southwest
		part.CFrame      = CFrame.new(BOARD_POSITION, Vector3.new(0, BOARD_POSITION.Y, -8))
		part.Anchored    = true
		part.CanCollide  = false
		part.CastShadow  = false
		part.Material    = Enum.Material.SmoothPlastic
		part.Color       = BOARD_COLOR
		part.Parent      = workspace
	end
	self.boardPart = part

	-- Remove old SurfaceGui
	local old = part:FindFirstChild("LeaderboardSurface")
	if old then old:Destroy() end

	-- Canvas dimensions (pixels): width = studs * pps, height = studs * pps
	local canvasW = BOARD_SIZE.X * PIXELS_PER_STUD  -- 10 * 80 = 800
	local canvasH = BOARD_SIZE.Y * PIXELS_PER_STUD  -- 14 * 80 = 1120

	local sg = Instance.new("SurfaceGui")
	sg.Name            = "LeaderboardSurface"
	sg.Face            = Enum.NormalId.Front
	sg.SizingMode      = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud   = PIXELS_PER_STUD
	sg.CanvasSize      = Vector2.new(canvasW, canvasH)
	sg.ClipsDescendants = true
	sg.AlwaysOnTop     = false
	sg.Parent          = part

	-- Background
	local bg = Instance.new("Frame")
	bg.Size            = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = DARK
	bg.BorderSizePixel = 0
	bg.Parent          = sg

	local bgGrad = Instance.new("UIGradient")
	bgGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.BG_SURFACE),
		ColorSequenceKeypoint.new(1, Theme.BG_OVERLAY),
	})
	bgGrad.Rotation = 135
	bgGrad.Parent   = bg

	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color             = Theme.PRIMARY
	bgStroke.Thickness         = 4
	bgStroke.ApplyStrokeMode   = Enum.ApplyStrokeMode.Border
	bgStroke.Parent            = bg

	-- Title bar
	local TITLE_H = 130
	local titleBar = Instance.new("Frame")
	titleBar.Size            = UDim2.new(1, 0, 0, TITLE_H)
	titleBar.BackgroundColor3 = GOLD
	titleBar.BorderSizePixel = 0
	titleBar.ZIndex          = 2
	titleBar.Parent          = sg

	local titleGrad = Instance.new("UIGradient")
	titleGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.PRIMARY),
		ColorSequenceKeypoint.new(1, Theme.PRIMARY_DARK),
	})
	titleGrad.Rotation = 90
	titleGrad.Parent   = titleBar

	local trophy = Instance.new("TextLabel")
	trophy.Size               = UDim2.new(0, 100, 1, 0)
	trophy.Position           = UDim2.new(0, 10, 0, 0)
	trophy.BackgroundTransparency = 1
	trophy.Text               = "🏆"
	trophy.TextSize           = 70
	trophy.Font               = Enum.Font.GothamBold
	trophy.ZIndex             = 3
	trophy.Parent             = titleBar

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size               = UDim2.new(1, -120, 0.55, 0)
	titleLabel.Position           = UDim2.new(0, 110, 0, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text               = "GLOBAL LEADERBOARD"
	titleLabel.TextColor3         = DARK
	titleLabel.TextSize           = 46
	titleLabel.Font               = Enum.Font.GothamBlack
	titleLabel.TextXAlignment     = Enum.TextXAlignment.Left
	titleLabel.ZIndex             = 3
	titleLabel.Parent             = titleBar

	local subLabel = Instance.new("TextLabel")
	subLabel.Size               = UDim2.new(1, -120, 0.45, 0)
	subLabel.Position           = UDim2.new(0, 110, 0.55, 0)
	subLabel.BackgroundTransparency = 1
	subLabel.Text               = "TOP 10 PLAYERS"
	subLabel.TextColor3         = Theme.BG_OVERLAY
	subLabel.TextSize           = 30
	subLabel.Font               = Enum.Font.GothamBold
	subLabel.TextXAlignment     = Enum.TextXAlignment.Left
	subLabel.ZIndex             = 3
	subLabel.Parent             = titleBar

	-- Row list
	local ROW_H     = (canvasH - TITLE_H) / TOP_COUNT
	local PAD       = 8
	self.boardRows  = {}

	for i = 1, TOP_COUNT do
		local rowY  = TITLE_H + (i - 1) * ROW_H
		local isEven = (i % 2 == 0)

		local row = Instance.new("Frame")
		row.Size              = UDim2.new(1, -PAD * 2, 0, ROW_H - 4)
		row.Position          = UDim2.new(0, PAD, 0, rowY + 2)
		row.BackgroundColor3  = isEven and Theme.BG_OVERLAY or Theme.BG_BASE
		row.BackgroundTransparency = 0.1
		row.BorderSizePixel   = 0
		row.ZIndex            = 2
		row.Parent            = sg

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 8)
		rowCorner.Parent       = row

		-- Rank
		local rankLbl = Instance.new("TextLabel")
		rankLbl.Size               = UDim2.new(0, 90, 1, 0)
		rankLbl.Position           = UDim2.new(0, 0, 0, 0)
		rankLbl.BackgroundTransparency = 1
		rankLbl.Text               = if i <= 3 then RANK_MEDAL[i] else "#" .. i
		rankLbl.TextColor3         = if i <= 3 then RANK_COLOR[i] else MUTED
		rankLbl.TextSize           = if i <= 3 then 40 else 30
		rankLbl.Font               = Enum.Font.GothamBlack
		rankLbl.ZIndex             = 3
		rankLbl.Parent             = row

		-- Name
		local nameLbl = Instance.new("TextLabel")
		nameLbl.Name               = "PlayerName"
		nameLbl.Size               = UDim2.new(1, -230, 1, 0)
		nameLbl.Position           = UDim2.new(0, 96, 0, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text               = "---"
		nameLbl.TextColor3         = WHITE
		nameLbl.TextSize           = 28
		nameLbl.Font               = Enum.Font.Gotham
		nameLbl.TextXAlignment     = Enum.TextXAlignment.Left
		nameLbl.ZIndex             = 3
		nameLbl.Parent             = row

		-- Score
		local scoreLbl = Instance.new("TextLabel")
		scoreLbl.Name               = "Score"
		scoreLbl.Size               = UDim2.new(0, 200, 1, 0)
		scoreLbl.Position           = UDim2.new(1, -210, 0, 0)
		scoreLbl.BackgroundTransparency = 1
		scoreLbl.Text               = "---"
		scoreLbl.TextColor3         = GREEN
		scoreLbl.TextSize           = 28
		scoreLbl.Font               = Enum.Font.GothamBold
		scoreLbl.TextXAlignment     = Enum.TextXAlignment.Right
		scoreLbl.ZIndex             = 3
		scoreLbl.Parent             = row

		self.boardRows[i] = { nameLbl = nameLbl, scoreLbl = scoreLbl }
	end

	Logger.info("LeaderboardManager", "Physical board created at", tostring(BOARD_POSITION))
end

function LeaderboardManager:_updateBoardUI(top: {{rank: number, name: string, score: number}})
	if #self.boardRows == 0 then return end
	for i = 1, TOP_COUNT do
		local row   = self.boardRows[i]
		local entry = top[i]
		if row then
			if entry then
				row.nameLbl.Text  = entry.name
				row.scoreLbl.Text = tostring(entry.score) .. " pts"
			else
				row.nameLbl.Text  = "---"
				row.scoreLbl.Text = "---"
			end
		end
	end
end

-- บันทึก score เมื่อ player จบเกม
function LeaderboardManager:updateScore(player: Player, score: number)
	if not self.orderedStore then return end
	if score <= 0 then return end

	local userId = player.UserId
	pcall(function()
		-- ใช้ UpdateAsync เพื่อเก็บ high score เท่านั้น
		self.orderedStore:UpdateAsync(tostring(userId), function(existing)
			local current = tonumber(existing) or 0
			if score > current then
				return score
			end
			return existing
		end)
	end)

	Logger.debug("LeaderboardManager", "Updated score for", player.Name, ":", score)
end

-- ดึง Top N scores
function LeaderboardManager:fetchTopScores(): {{rank: number, name: string, score: number}}
	if not self.orderedStore then return {} end

	local result = {}
	local success, pages = pcall(function()
		return self.orderedStore:GetSortedAsync(false, TOP_COUNT)
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

		-- ลอง resolve ชื่อจาก UserId
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

-- Broadcast leaderboard: update physical board + notify clients
function LeaderboardManager:broadcast()
	local top = self:fetchTopScores()
	self.cachedTop = top

	-- Update physical board in lobby
	self:_updateBoardUI(top)

	-- Still fire remote for any client listeners
	for _, player in ipairs(Players:GetPlayers()) do
		self.leaderboardUpdateRemote:FireClient(player, { top = top })
	end

	Logger.debug("LeaderboardManager", "Broadcasted leaderboard with", #top, "entries")
end

-- ส่ง leaderboard ให้ player คนเดียว (เมื่อเพิ่งเข้าเกม)
function LeaderboardManager:sendToPlayer(player: Player)
	if #self.cachedTop > 0 then
		self.leaderboardUpdateRemote:FireClient(player, { top = self.cachedTop })
	end
end

-- Auto-refresh loop
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
