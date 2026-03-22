-- SummaryUI: แสดง Summary เมื่อจบเกม

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local StageInfo = require(ReplicatedStorage.Shared.StageInfo)
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)
local AdaptiveLayout = require(ReplicatedStorage.Shared.AdaptiveLayout)

local PANEL_W = 400
local PANEL_H = 520

local SummaryUI = {}
SummaryUI.__index = SummaryUI

-- Stage data from StageInfo (single source of truth)

function SummaryUI.new(parent: ScreenGui)
	local self = setmetatable({}, SummaryUI)

	self.parent = parent
	self.isVisible = false

	self:createUI()

	return self
end

-- Format time as MM:SS
local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%d:%02d", mins, secs)
end

function SummaryUI:createUI()
	-- Background overlay (dark dim behind popup)
	local overlay = Instance.new("Frame")
	overlay.Name = "SummaryOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 49
	overlay.Visible = false
	overlay.Parent = self.parent
	self.overlay = overlay

	-- Main Frame (centered popup)
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "SummaryFrame"
	mainFrame.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = Theme.BG_BASE
	mainFrame.BackgroundTransparency = 0.05
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.ZIndex = 50
	mainFrame.Parent = self.parent
	self.mainFrame = mainFrame

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = Theme.CORNER_LG
	mainCorner.Parent = mainFrame

	-- Gradient background
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.PANEL_GRAD_TOP),
		ColorSequenceKeypoint.new(1, Theme.PANEL_GRAD_BTM)
	})
	gradient.Rotation = 180
	gradient.Parent = mainFrame

	-- Border glow (gold)
	local borderStroke = Instance.new("UIStroke")
	borderStroke.Color = Theme.PRIMARY
	borderStroke.Thickness = Theme.STROKE_BOLD
	borderStroke.Transparency = 0.2
	borderStroke.Parent = mainFrame
	self.borderStroke = borderStroke

	-- Drop shadow
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 8, 1, 8)
	shadow.Position = UDim2.new(0, -4, 0, 4)
	shadow.BackgroundColor3 = Theme.CARD_SHADOW
	shadow.BackgroundTransparency = 0.7
	shadow.BorderSizePixel = 0
	shadow.ZIndex = mainFrame.ZIndex - 1
	shadow.Parent = mainFrame
	Theme.applyCorner(shadow, "lg")

	-- ==================== HEADER SECTION ====================
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "HeaderFrame"
	headerFrame.Size = UDim2.new(1, 0, 0, 100)
	headerFrame.Position = UDim2.new(0, 0, 0, 0)
	headerFrame.BackgroundColor3 = Theme.BG_SURFACE
	headerFrame.BorderSizePixel = 0
	headerFrame.ZIndex = 51
	headerFrame.Parent = mainFrame
	Theme.applyCorner(headerFrame, "lg")

	-- Bottom fill (covers bottom corners to make top-only rounded)
	local headerFill = Instance.new("Frame")
	headerFill.Name = "HeaderFill"
	headerFill.Size = UDim2.new(1, 0, 0, 20)
	headerFill.Position = UDim2.new(0, 0, 1, -20)
	headerFill.BackgroundColor3 = Theme.BG_SURFACE
	headerFill.BorderSizePixel = 0
	headerFill.ZIndex = 51
	headerFill.Parent = headerFrame

	-- Header gradient (lighter purple at top)
	local headerGrad = Instance.new("UIGradient")
	headerGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.BG_ELEVATED),
		ColorSequenceKeypoint.new(1, Theme.BG_SURFACE),
	})
	headerGrad.Rotation = 90
	headerGrad.Parent = headerFrame

	-- Apply same gradient to fill rect
	local fillGrad = Instance.new("UIGradient")
	fillGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.BG_SURFACE),
		ColorSequenceKeypoint.new(1, Theme.BG_SURFACE),
	})
	fillGrad.Parent = headerFill

	-- Gem icon
	local gemLabel = Instance.new("TextLabel")
	gemLabel.Name = "GemIcon"
	gemLabel.Size = UDim2.new(1, 0, 0, 44)
	gemLabel.Position = UDim2.new(0, 0, 0, 6)
	gemLabel.BackgroundTransparency = 1
	gemLabel.Text = "\u{1F48E}"
	gemLabel.TextSize = 36
	gemLabel.Font = Enum.Font.GothamBold
	gemLabel.ZIndex = 52
	gemLabel.Parent = headerFrame

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 32)
	titleLabel.Position = UDim2.new(0, 0, 0, 48)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "GAME COMPLETE!"
	titleLabel.TextColor3 = Theme.MEDAL_GOLD
	titleLabel.TextSize = 24
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextStrokeColor3 = Color3.fromRGB(100, 70, 0)
	titleLabel.TextStrokeTransparency = 0.5
	titleLabel.ZIndex = 52
	titleLabel.Parent = headerFrame
	self.titleLabel = titleLabel

	-- Gold divider line at bottom of header
	local headerDivider = Instance.new("Frame")
	headerDivider.Name = "HeaderDivider"
	headerDivider.Size = UDim2.new(1, -30, 0, 2)
	headerDivider.Position = UDim2.new(0, 15, 0, 88)
	headerDivider.BackgroundColor3 = Theme.PRIMARY
	headerDivider.BackgroundTransparency = 0.3
	headerDivider.BorderSizePixel = 0
	headerDivider.ZIndex = 52
	headerDivider.Parent = headerFrame

	-- ==================== SCROLLABLE CONTENT AREA ====================
	local contentScroll = Instance.new("ScrollingFrame")
	contentScroll.Name = "ContentScroll"
	contentScroll.Size = UDim2.new(1, 0, 1, -185) -- header(100) + footer(85)
	contentScroll.Position = UDim2.new(0, 0, 0, 100)
	contentScroll.BackgroundTransparency = 1
	contentScroll.BorderSizePixel = 0
	contentScroll.ScrollBarThickness = 4
	contentScroll.ScrollBarImageColor3 = Theme.TEXT_MUTED
	contentScroll.ScrollBarImageTransparency = 0.5
	contentScroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	contentScroll.CanvasSize = UDim2.new(0, 0, 0, 415) -- stages(60)+gap(10)+stats(110)+gap(10)+currency(215)+pad(10)
	contentScroll.ZIndex = 51
	contentScroll.Parent = mainFrame
	self.contentScroll = contentScroll

	-- ==================== STAGES SECTION ====================
	local stagesContainer = Instance.new("Frame")
	stagesContainer.Name = "StagesContainer"
	stagesContainer.Size = UDim2.new(1, -40, 0, 60)
	stagesContainer.Position = UDim2.new(0, 20, 0, 8)
	stagesContainer.BackgroundColor3 = Theme.BG_SURFACE
	stagesContainer.BackgroundTransparency = 0.15
	stagesContainer.BorderSizePixel = 0
	stagesContainer.ZIndex = 51
	stagesContainer.Parent = contentScroll
	self.stagesContainer = stagesContainer

	local stagesCorner = Instance.new("UICorner")
	stagesCorner.CornerRadius = Theme.CORNER_SM
	stagesCorner.Parent = stagesContainer

	local stagesGradient = Instance.new("UIGradient")
	stagesGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.BG_SURFACE),
		ColorSequenceKeypoint.new(1, Theme.BG_ELEVATED)
	})
	stagesGradient.Rotation = 90
	stagesGradient.Parent = stagesContainer

	-- Stages header
	local stagesHeader = Instance.new("TextLabel")
	stagesHeader.Name = "Header"
	stagesHeader.Size = UDim2.new(1, 0, 0, 18)
	stagesHeader.Position = UDim2.new(0, 0, 0, 4)
	stagesHeader.BackgroundTransparency = 1
	stagesHeader.Text = "\u{1F4CB} STAGES PLAYED"
	stagesHeader.TextColor3 = Theme.TEXT_MUTED
	stagesHeader.TextSize = 12
	stagesHeader.Font = Enum.Font.GothamBold
	stagesHeader.ZIndex = 52
	stagesHeader.Parent = stagesContainer

	-- Stages list container
	local stagesList = Instance.new("Frame")
	stagesList.Name = "StagesList"
	stagesList.Size = UDim2.new(1, -16, 0, 34)
	stagesList.Position = UDim2.new(0, 8, 0, 22)
	stagesList.BackgroundTransparency = 1
	stagesList.ZIndex = 52
	stagesList.Parent = stagesContainer
	self.stagesList = stagesList

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = stagesList

	-- ==================== STATS SECTION ====================
	local statsContainer = Instance.new("Frame")
	statsContainer.Name = "StatsContainer"
	statsContainer.Size = UDim2.new(1, -40, 0, 110)
	statsContainer.Position = UDim2.new(0, 20, 0, 78)
	statsContainer.BackgroundColor3 = Theme.BG_SURFACE
	statsContainer.BackgroundTransparency = 0.15
	statsContainer.BorderSizePixel = 0
	statsContainer.ZIndex = 51
	statsContainer.Parent = contentScroll
	self.statsContainer = statsContainer

	local statsCorner = Instance.new("UICorner")
	statsCorner.CornerRadius = Theme.CORNER_SM
	statsCorner.Parent = statsContainer

	local statsGradient = Instance.new("UIGradient")
	statsGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.BG_SURFACE),
		ColorSequenceKeypoint.new(1, Theme.BG_ELEVATED)
	})
	statsGradient.Rotation = 90
	statsGradient.Parent = statsContainer

	-- Stats header
	local statsHeader = Instance.new("TextLabel")
	statsHeader.Size = UDim2.new(1, 0, 0, 20)
	statsHeader.Position = UDim2.new(0, 0, 0, 4)
	statsHeader.BackgroundTransparency = 1
	statsHeader.Text = "\u{1F4CA} STATS"
	statsHeader.TextColor3 = Theme.TEXT_PRIMARY
	statsHeader.TextSize = 12
	statsHeader.Font = Enum.Font.GothamBold
	statsHeader.ZIndex = 52
	statsHeader.Parent = statsContainer

	-- Stats rows
	self.statsRows = {}
	local statsConfig = {
		{name = "Gems", icon = "\u{1F48E}", key = "gemsEarned", color = Color3.fromRGB(200, 120, 255)},
		{name = "Time", icon = "\u{23F1}\u{FE0F}", key = "timeSpent", color = Theme.TEXT_MUTED, isTime = true},
	}

	for i, config in ipairs(statsConfig) do
		local row = self:createSmallRow(config, i, statsContainer, 24)
		self.statsRows[config.key] = row
	end

	-- Rank indicator (shows finish position)
	local rankLabel = Instance.new("TextLabel")
	rankLabel.Name = "RankLabel"
	rankLabel.Size = UDim2.new(1, -20, 0, 26)
	rankLabel.Position = UDim2.new(0, 10, 0, 70)
	rankLabel.BackgroundTransparency = 1
	rankLabel.Text = ""
	rankLabel.TextColor3 = Theme.MEDAL_GOLD
	rankLabel.TextSize = 18
	rankLabel.Font = Enum.Font.GothamBlack
	rankLabel.TextStrokeColor3 = Color3.fromRGB(100, 70, 0)
	rankLabel.TextStrokeTransparency = 0.4
	rankLabel.TextXAlignment = Enum.TextXAlignment.Center
	rankLabel.ZIndex = 52
	rankLabel.Visible = false
	rankLabel.Parent = statsContainer
	self.rankLabel = rankLabel

	-- "TOP 30%" indicator (hidden by default, shown when isTop30)
	local top30Label = Instance.new("TextLabel")
	top30Label.Name = "Top30Label"
	top30Label.Size = UDim2.new(1, -20, 0, 20)
	top30Label.Position = UDim2.new(0, 10, 0, 88)
	top30Label.BackgroundTransparency = 1
	top30Label.Text = "\u{1F48E} TOP 30%"
	top30Label.TextColor3 = Color3.fromRGB(200, 120, 255)
	top30Label.TextSize = 13
	top30Label.Font = Enum.Font.GothamBold
	top30Label.TextXAlignment = Enum.TextXAlignment.Center
	top30Label.ZIndex = 52
	top30Label.Visible = false
	top30Label.Parent = statsContainer
	self.top30Label = top30Label

	-- ==================== CURRENCY SECTION ====================
	local currencyContainer = Instance.new("Frame")
	currencyContainer.Name = "CurrencyContainer"
	currencyContainer.Size = UDim2.new(1, -40, 0, 215)
	currencyContainer.Position = UDim2.new(0, 20, 0, 198)
	currencyContainer.BackgroundColor3 = Theme.BG_SURFACE
	currencyContainer.BackgroundTransparency = 0.15
	currencyContainer.BorderSizePixel = 0
	currencyContainer.ZIndex = 51
	currencyContainer.Parent = contentScroll
	self.currencyContainer = currencyContainer

	local currencyCorner = Instance.new("UICorner")
	currencyCorner.CornerRadius = Theme.CORNER_SM
	currencyCorner.Parent = currencyContainer

	local currencyGradient = Instance.new("UIGradient")
	currencyGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.BG_SURFACE),
		ColorSequenceKeypoint.new(1, Theme.BG_ELEVATED)
	})
	currencyGradient.Rotation = 90
	currencyGradient.Parent = currencyContainer

	-- Currency header
	local currencyHeader = Instance.new("TextLabel")
	currencyHeader.Size = UDim2.new(1, 0, 0, 22)
	currencyHeader.Position = UDim2.new(0, 0, 0, 4)
	currencyHeader.BackgroundTransparency = 1
	currencyHeader.Text = "\u{1F4B0} CURRENCY EARNED"
	currencyHeader.TextColor3 = Theme.darkenForText(Theme.MEDAL_GOLD, 0.45)
	currencyHeader.TextSize = 13
	currencyHeader.Font = Enum.Font.GothamBold
	currencyHeader.ZIndex = 52
	currencyHeader.Parent = currencyContainer

	-- Currency rows
	self.currencyRows = {}

	-- Coins row
	local coinsRow = self:createCurrencyRow("coins", "\u{1F4B0} Coins", 1, currencyContainer, 28)
	self.currencyRows.coins = coinsRow

	-- Stage Clear row
	local stageRow = self:createCurrencyRow("stage", "\u{1F3C1} Stage Clear", 2, currencyContainer, 28)
	self.currencyRows.stage = stageRow

	-- Stage Rewards row
	local rewardsRow = self:createCurrencyRow("rewards", "\u{1F3AF} Stage Rewards", 3, currencyContainer, 28)
	self.currencyRows.rewards = rewardsRow

	-- Finish Bonus row
	local finishRow = self:createCurrencyRow("finish", "\u{1F381} Finish Bonus", 4, currencyContainer, 28)
	self.currencyRows.finish = finishRow

	-- Divider
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(1, -20, 0, 2)
	divider.Position = UDim2.new(0, 10, 0, 157)
	divider.BackgroundColor3 = Theme.PRIMARY
	divider.BackgroundTransparency = 0.5
	divider.BorderSizePixel = 0
	divider.ZIndex = 52
	divider.Parent = currencyContainer

	-- Total row with highlight frame
	local totalHighlight = Instance.new("Frame")
	totalHighlight.Name = "TotalHighlight"
	totalHighlight.Size = UDim2.new(1, -10, 0, 42)
	totalHighlight.Position = UDim2.new(0, 5, 0, 164)
	totalHighlight.BackgroundColor3 = Theme.BG_ELEVATED
	totalHighlight.BackgroundTransparency = 0.5
	totalHighlight.BorderSizePixel = 0
	totalHighlight.ZIndex = 52
	totalHighlight.Parent = currencyContainer
	Theme.applyCorner(totalHighlight, "sm")
	Theme.applyStroke(totalHighlight, Theme.MEDAL_GOLD, "thin", 0.3)

	local totalLabel = Instance.new("TextLabel")
	totalLabel.Size = UDim2.new(0.55, 0, 1, 0)
	totalLabel.Position = UDim2.new(0, 10, 0, 0)
	totalLabel.BackgroundTransparency = 1
	totalLabel.Text = "\u{2728} TOTAL EARNED"
	totalLabel.TextColor3 = Theme.darkenForText(Theme.MEDAL_GOLD, 0.40)
	totalLabel.TextSize = 15
	totalLabel.Font = Enum.Font.GothamBlack
	totalLabel.TextXAlignment = Enum.TextXAlignment.Left
	totalLabel.ZIndex = 53
	totalLabel.Parent = totalHighlight
	self.totalLabel = totalLabel
	self.totalHighlight = totalHighlight

	local totalValue = Instance.new("TextLabel")
	totalValue.Name = "Value"
	totalValue.Size = UDim2.new(0.4, 0, 1, 0)
	totalValue.Position = UDim2.new(0.55, 0, 0, 0)
	totalValue.BackgroundTransparency = 1
	totalValue.Text = "+0"
	totalValue.TextColor3 = Theme.darkenForText(Theme.MEDAL_GOLD, 0.40)
	totalValue.TextSize = 20
	totalValue.Font = Enum.Font.GothamBlack
	totalValue.TextXAlignment = Enum.TextXAlignment.Right
	totalValue.ZIndex = 53
	totalValue.Parent = totalHighlight
	self.totalValueLabel = totalValue

	-- ==================== FOOTER (OK + UPSELL) ====================
	local footerFrame = Instance.new("Frame")
	footerFrame.Name = "FooterFrame"
	footerFrame.Size = UDim2.new(1, -20, 0, 75)
	footerFrame.Position = UDim2.new(0, 10, 1, -80)
	footerFrame.BackgroundTransparency = 1
	footerFrame.BorderSizePixel = 0
	footerFrame.ZIndex = 51
	footerFrame.Parent = mainFrame
	self.footerFrame = footerFrame

	-- OK button (right side of footer)
	local okButton = Instance.new("TextButton")
	okButton.Name = "OKButton"
	okButton.Size = UDim2.new(0, 160, 0, 60)
	okButton.Position = UDim2.new(1, 0, 0, 0)
	okButton.AnchorPoint = Vector2.new(1, 0)
	okButton.BackgroundTransparency = 1
	okButton.BorderSizePixel = 0
	okButton.Text = ""
	okButton.ZIndex = 51
	okButton.Parent = footerFrame
	self.okButton = okButton

	local okBg = Instance.new("Frame")
	okBg.Name = "OKBg"
	okBg.Size = UDim2.new(1, 0, 1, 0)
	okBg.BackgroundColor3 = Color3.new(1, 1, 1)
	okBg.BorderSizePixel = 0
	okBg.ZIndex = 51
	okBg.Parent = okButton

	local okCorner = Instance.new("UICorner")
	okCorner.CornerRadius = Theme.CORNER_MD
	okCorner.Parent = okBg

	local okGradient = Instance.new("UIGradient")
	okGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.SUCCESS),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 150, 60))
	})
	okGradient.Rotation = 90
	okGradient.Parent = okBg

	local okStroke = Instance.new("UIStroke")
	okStroke.Color = Theme.SUCCESS
	okStroke.Thickness = Theme.STROKE_MED
	okStroke.Transparency = 0.3
	okStroke.Parent = okBg

	local okLabel = Instance.new("TextLabel")
	okLabel.Name = "OKLabel"
	okLabel.Size = UDim2.new(1, 0, 1, 0)
	okLabel.BackgroundTransparency = 1
	okLabel.Text = "\u{2705} OK"
	okLabel.TextColor3 = Theme.TEXT_ON_ACCENT
	okLabel.TextSize = 20
	okLabel.Font = Enum.Font.GothamBold
	okLabel.ZIndex = 52
	okLabel.Parent = okButton

	-- Button click
	okButton.MouseButton1Click:Connect(function()
		self:hide()
	end)

	-- Hover effects
	okButton.MouseEnter:Connect(function()
		TweenService:Create(okButton, TweenInfo.new(0.2), {
			Size = UDim2.new(0, 170, 0, 64)
		}):Play()
	end)

	okButton.MouseLeave:Connect(function()
		TweenService:Create(okButton, TweenInfo.new(0.2), {
			Size = UDim2.new(0, 160, 0, 60)
		}):Play()
	end)

	-- Responsive scaling (Phase 3)
	AdaptiveLayout.applyScale(mainFrame, PANEL_W, PANEL_H)
	self.uiScale = uiScale
end

function SummaryUI:createSmallRow(config: {name: string, icon: string, key: string, color: Color3, isTime: boolean?}, index: number, parent: Frame, startY: number): Frame
	local row = Instance.new("Frame")
	row.Name = config.key .. "Row"
	row.Size = UDim2.new(1, -20, 0, 22)
	row.Position = UDim2.new(0, 10, 0, startY + (index - 1) * 22)
	row.BackgroundTransparency = 1
	row.ZIndex = 52
	row.Parent = parent

	-- Icon + Label
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(0.6, 0, 1, 0)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = config.icon .. " " .. config.name
	label.TextColor3 = Theme.TEXT_MUTED
	label.TextSize = 13
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 52
	label.Parent = row

	-- Value
	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.Size = UDim2.new(0.4, 0, 1, 0)
	value.Position = UDim2.new(0.6, 0, 0, 0)
	value.BackgroundTransparency = 1
	value.Text = "0"
	value.TextColor3 = config.color
	value.TextSize = 14
	value.Font = Enum.Font.GothamBold
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.ZIndex = 52
	value.Parent = row

	-- Store config
	row:SetAttribute("isTime", config.isTime or false)

	return row
end

function SummaryUI:createCurrencyRow(key: string, labelText: string, index: number, parent: Frame, startY: number): Frame
	local row = Instance.new("Frame")
	row.Name = key .. "Row"
	row.Size = UDim2.new(1, -20, 0, 30)
	row.Position = UDim2.new(0, 10, 0, startY + (index - 1) * 32)
	row.BackgroundTransparency = 1
	row.ZIndex = 52
	row.Parent = parent

	-- Label (e.g., "💰 Coins")
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(0.45, 0, 1, 0)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Theme.TEXT_MUTED
	label.TextSize = 13
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 52
	label.Parent = row

	-- Breakdown (e.g., "(3 x 1)")
	local breakdown = Instance.new("TextLabel")
	breakdown.Name = "Breakdown"
	breakdown.Size = UDim2.new(0.25, 0, 1, 0)
	breakdown.Position = UDim2.new(0.45, 0, 0, 0)
	breakdown.BackgroundTransparency = 1
	breakdown.Text = ""
	breakdown.TextColor3 = Theme.TEXT_MUTED
	breakdown.TextSize = 11
	breakdown.Font = Enum.Font.Gotham
	breakdown.TextXAlignment = Enum.TextXAlignment.Center
	breakdown.ZIndex = 52
	breakdown.Parent = row

	-- Value (e.g., "+3")
	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.Size = UDim2.new(0.3, 0, 1, 0)
	value.Position = UDim2.new(0.7, 0, 0, 0)
	value.BackgroundTransparency = 1
	value.Text = "+0"
	value.TextColor3 = Theme.darkenForText(Theme.MEDAL_GOLD, 0.40)
	value.TextSize = 15
	value.Font = Enum.Font.GothamBold
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.ZIndex = 52
	value.Parent = row

	return row
end

function SummaryUI:createStageTag(stageNum: number, index: number, _coinMultiplier: number?): Frame
	local stageData = StageInfo.getStage(stageNum)
	local stageReward = stageData and stageData.reward or 0
	local diffInfo = stageData and StageInfo.DifficultyInfo[stageData.difficulty]

	local tag = Instance.new("Frame")
	tag.Name = "Stage" .. stageNum
	tag.Size = UDim2.new(0, 52, 0, 32)
	tag.BackgroundColor3 = Theme.BG_ELEVATED
	tag.BorderSizePixel = 0
	tag.ZIndex = 53

	local tagCorner = Instance.new("UICorner")
	tagCorner.CornerRadius = Theme.CORNER_SM
	tagCorner.Parent = tag

	-- Difficulty color stripe (top border)
	if diffInfo then
		local stripe = Instance.new("Frame")
		stripe.Name = "DiffStripe"
		stripe.Size = UDim2.new(1, 0, 0, 3)
		stripe.Position = UDim2.new(0, 0, 0, 0)
		stripe.BackgroundColor3 = diffInfo.color
		stripe.BorderSizePixel = 0
		stripe.ZIndex = 54
		stripe.Parent = tag

		local stripeCorner = Instance.new("UICorner")
		stripeCorner.CornerRadius = UDim.new(0, 2)
		stripeCorner.Parent = stripe
	end

	-- Stage number
	local stageLabel = Instance.new("TextLabel")
	stageLabel.Size = UDim2.new(1, 0, 0, 16)
	stageLabel.Position = UDim2.new(0, 0, 0, 3)
	stageLabel.BackgroundTransparency = 1
	stageLabel.Text = "S" .. stageNum
	stageLabel.TextColor3 = diffInfo and diffInfo.color or Theme.ACCENT_CYAN
	stageLabel.TextSize = 11
	stageLabel.Font = Enum.Font.GothamBold
	stageLabel.ZIndex = 54
	stageLabel.Parent = tag

	-- Stage reward
	local coinLabel = Instance.new("TextLabel")
	coinLabel.Size = UDim2.new(1, 0, 0, 14)
	coinLabel.Position = UDim2.new(0, 0, 0, 17)
	coinLabel.BackgroundTransparency = 1
	coinLabel.Text = "\u{1F4B0}+" .. stageReward
	coinLabel.TextColor3 = Theme.MEDAL_GOLD
	coinLabel.TextSize = 10
	coinLabel.Font = Enum.Font.GothamBold
	coinLabel.ZIndex = 54
	coinLabel.Parent = tag

	-- Start hidden for animation
	tag.BackgroundTransparency = 1
	stageLabel.TextTransparency = 1
	coinLabel.TextTransparency = 1

	return tag
end

function SummaryUI:show(data: {gemsEarned: number, timeSpent: number, coinsCollected: number, coinValue: number, stagesCleared: number, stageValue: number, finishBonus: number, totalCurrency: number, stageOrder: {number}?, isWin: boolean?, isTop30: boolean?, isDoubleCoin: boolean?})
	if self.isVisible then return end
	self.isVisible = true

	-- Update total row for DoubleCoin
	self.totalLabel.Text = "\u{2728} TOTAL EARNED"
	self.totalHighlight.BackgroundColor3 = Theme.BG_ELEVATED

	-- Clear previous stage tags
	for _, child in ipairs(self.stagesList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Create stage tags (with multiplied reward display)
	local stageOrder = data.stageOrder or {}
	local multiplier = data.coinMultiplier or 1
	for i, stageNum in ipairs(stageOrder) do
		local tag = self:createStageTag(stageNum, i, multiplier)
		tag.Parent = self.stagesList
	end

	-- Setup gamepass upsell buttons
	self:setupGamePassUpsell(data.gamePassUpsell)

	-- Show rank indicator
	local pos = data.finishPosition or 0
	local total = data.totalRacers or 1
	if pos > 0 then
		local suffix = "TH"
		if pos == 1 then suffix = "ST"
		elseif pos == 2 then suffix = "ND"
		elseif pos == 3 then suffix = "RD"
		end

		local medal = ""
		local rankColor = Theme.TEXT_PRIMARY
		if pos == 1 then
			medal = "\u{1F947} "
			rankColor = Theme.MEDAL_GOLD
			self.rankLabel.TextStrokeColor3 = Color3.fromRGB(100, 70, 0)
		elseif pos == 2 then
			medal = "\u{1F948} "
			rankColor = Theme.MEDAL_SILVER
			self.rankLabel.TextStrokeColor3 = Color3.fromRGB(60, 60, 70)
		elseif pos == 3 then
			medal = "\u{1F949} "
			rankColor = Theme.MEDAL_BRONZE
			self.rankLabel.TextStrokeColor3 = Color3.fromRGB(80, 50, 20)
		else
			medal = "#"
			rankColor = Theme.TEXT_PRIMARY
			self.rankLabel.TextStrokeColor3 = Color3.fromRGB(30, 30, 40)
		end

		if pos <= 3 then
			self.rankLabel.Text = medal .. pos .. suffix .. " PLACE!"
		else
			self.rankLabel.Text = medal .. pos .. suffix .. " / " .. total .. " players"
		end
		self.rankLabel.TextColor3 = rankColor
		self.rankLabel.Visible = true
	else
		self.rankLabel.Visible = false
	end

	-- Show top30 indicator
	self.top30Label.Visible = data.isTop30 == true

	-- Fixed panel size — content scrolls if needed
	self.mainFrame.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
	self.mainFrame.Visible = true

	-- Scale-in animation via UIScale (POLISH-01)
	local targetScale = self.uiScale.Scale
	self.uiScale.Scale = targetScale * 0.8
	TweenService:Create(self.uiScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = targetScale
	}):Play()

	-- Animate border glow
	task.spawn(function()
		while self.isVisible do
			local glowUp = TweenService:Create(self.borderStroke, TweenInfo.new(0.5), {
				Transparency = 0.1
			})
			glowUp:Play()
			glowUp.Completed:Wait()

			local glowDown = TweenService:Create(self.borderStroke, TweenInfo.new(0.5), {
				Transparency = 0.4
			})
			glowDown:Play()
			glowDown.Completed:Wait()
		end
	end)

	-- Animate stage tags
	task.delay(0.3, function()
		self:animateStageTags()
	end)

	-- Animate stats section
	task.delay(0.5, function()
		self:animateStats(data)
	end)

	-- Animate currency section
	task.delay(0.8, function()
		self:animateCurrency(data)
	end)
end

function SummaryUI:animateStageTags()
	local tags = {}
	for _, child in ipairs(self.stagesList:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(tags, child)
		end
	end

	for i, tag in ipairs(tags) do
		task.delay((i - 1) * 0.08, function()
			-- Fade in
			TweenService:Create(tag, TweenInfo.new(0.2), {
				BackgroundTransparency = 0
			}):Play()

			for _, label in ipairs(tag:GetChildren()) do
				if label:IsA("TextLabel") then
					TweenService:Create(label, TweenInfo.new(0.2), {
						TextTransparency = 0
					}):Play()
				end
			end

			-- Pop animation
			tag.Size = UDim2.new(0, 44, 0, 28)
			TweenService:Create(tag, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
				Size = UDim2.new(0, 52, 0, 32)
			}):Play()
		end)
	end
end

function SummaryUI:animateStats(data: {gemsEarned: number, timeSpent: number, isWin: boolean?, isTop30: boolean?})
	-- Gems
	task.delay(0, function()
		local row = self.statsRows.gemsEarned
		if row then
			local valueLabel = row:FindFirstChild("Value")
			if valueLabel then
				valueLabel.Text = tostring(data.gemsEarned or 0)
				valueLabel.TextSize = 10
				TweenService:Create(valueLabel, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
					TextSize = 14
				}):Play()
			end
		end
	end)

	-- Time
	task.delay(0.1, function()
		local row = self.statsRows.timeSpent
		if row then
			local valueLabel = row:FindFirstChild("Value")
			if valueLabel then
				valueLabel.Text = formatTime(data.timeSpent or 0)
				valueLabel.TextSize = 10
				TweenService:Create(valueLabel, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
					TextSize = 14
				}):Play()
			end
		end
	end)

	-- Animate rank label with glow pulse
	if (data.finishPosition or 0) > 0 then
		task.delay(0.2, function()
			if self.rankLabel.Visible then
				self.rankLabel.TextSize = 12
				TweenService:Create(self.rankLabel, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
					TextSize = 18
				}):Play()

				-- Glow pulse loop
				task.spawn(function()
					while self.isVisible and self.rankLabel.Visible do
						TweenService:Create(self.rankLabel, TweenInfo.new(0.6), {
							TextStrokeTransparency = 0.2
						}):Play()
						task.wait(0.6)
						TweenService:Create(self.rankLabel, TweenInfo.new(0.6), {
							TextStrokeTransparency = 0.6
						}):Play()
						task.wait(0.6)
					end
				end)
			end
		end)
	end

	-- Animate "TOP 30%" label
	if data.isTop30 then
		task.delay(0.3, function()
			if self.top30Label.Visible then
				self.top30Label.TextSize = 9
				TweenService:Create(self.top30Label, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
					TextSize = 13
				}):Play()
			end
		end)
	end
end

function SummaryUI:animateCurrency(data: {coinsCollected: number, coinValue: number, stagesCleared: number, stageValue: number, stageRewardsTotal: number, finishBonus: number, isDoubleCoin: boolean?, coinMultiplier: number?, totalEarned: number?})
	local coinMultiplier = data.coinMultiplier or 1
	local coinsCollected = data.coinsCollected or 0
	-- Show BASE values in breakdown (before multiplier)
	local baseCoinValue = (data.coinValue or 1) / coinMultiplier
	local baseStageValue = (data.stageValue or 5) / coinMultiplier
	local baseStageRewardsTotal = (data.stageRewardsTotal or 0) / coinMultiplier
	local baseFinishBonus = (data.finishBonus or 25) / coinMultiplier

	-- Base totals (before multiplier)
	local baseCoinsTotal = coinsCollected * baseCoinValue
	local stagesCleared = data.stagesCleared or 0
	local baseStageTotal = stagesCleared * baseStageValue
	local baseSubtotal = baseCoinsTotal + baseStageTotal + baseStageRewardsTotal + baseFinishBonus

	-- Grand total = server delta (already includes multiplier)
	local grandTotal = data.totalEarned or (baseSubtotal * coinMultiplier)

	-- Animate Coins row (show base values)
	task.delay(0, function()
		local row = self.currencyRows.coins
		local breakdown = row:FindFirstChild("Breakdown")
		local value = row:FindFirstChild("Value")

		if breakdown and value then
			breakdown.Text = "(" .. coinsCollected .. " \u{00D7} " .. baseCoinValue .. ")"
			value.Text = "+" .. baseCoinsTotal

			value.TextSize = 11
			TweenService:Create(value, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
				TextSize = 15
			}):Play()
		end
	end)

	-- Animate Stage Clear row (show base values)
	task.delay(0.1, function()
		local row = self.currencyRows.stage
		local breakdown = row:FindFirstChild("Breakdown")
		local value = row:FindFirstChild("Value")

		if breakdown and value then
			breakdown.Text = "(" .. stagesCleared .. " \u{00D7} " .. baseStageValue .. ")"
			value.Text = "+" .. baseStageTotal

			value.TextSize = 11
			TweenService:Create(value, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
				TextSize = 15
			}):Play()
		end
	end)

	-- Animate Stage Rewards row (show base values)
	task.delay(0.2, function()
		local row = self.currencyRows.rewards
		local breakdown = row:FindFirstChild("Breakdown")
		local value = row:FindFirstChild("Value")

		if breakdown and value then
			breakdown.Text = ""
			value.Text = "+" .. baseStageRewardsTotal
			value.TextColor3 = Theme.TEXT_PRIMARY

			value.TextSize = 11
			TweenService:Create(value, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
				TextSize = 15
			}):Play()
		end
	end)

	-- Animate Finish Bonus row (show base values)
	task.delay(0.3, function()
		local row = self.currencyRows.finish
		local breakdown = row:FindFirstChild("Breakdown")
		local value = row:FindFirstChild("Value")

		if breakdown and value then
			breakdown.Text = ""
			value.Text = "+" .. baseFinishBonus

			value.TextSize = 11
			TweenService:Create(value, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
				TextSize = 15
			}):Play()
		end
	end)

	-- Animate Total
	task.delay(0.45, function()
		if coinMultiplier > 1 then
			-- Show: actual base → ×multiplier → final total
			local actualBase = math.floor(grandTotal / coinMultiplier)
			local mulText = (coinMultiplier == math.floor(coinMultiplier))
				and tostring(math.floor(coinMultiplier))
				or string.format("%.1f", coinMultiplier)
			self.totalLabel.Text = "\u{2728} TOTAL +" .. actualBase .. " \u{00D7}" .. mulText
			self.totalValueLabel.Text = "+" .. grandTotal
			self.totalHighlight.BackgroundColor3 = Theme.PRIMARY:Lerp(Theme.BG_ELEVATED, 0.55)
		else
			self.totalLabel.Text = "\u{2728} TOTAL EARNED"
			self.totalValueLabel.Text = "+" .. grandTotal
		end

		-- Flash animation
		self.totalValueLabel.TextColor3 = Color3.fromRGB(255, 255, 150)
		self.totalValueLabel.TextSize = 16

		TweenService:Create(self.totalValueLabel, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
			TextSize = 20,
			TextColor3 = Theme.darkenForText(Theme.MEDAL_GOLD, 0.40)
		}):Play()

		-- Pulse the total highlight when coin multiplier active
		if coinMultiplier > 1 then
			task.spawn(function()
				while self.isVisible do
					TweenService:Create(self.totalHighlight, TweenInfo.new(0.6), {
						BackgroundTransparency = 0.3
					}):Play()
					task.wait(0.6)
					TweenService:Create(self.totalHighlight, TweenInfo.new(0.6), {
						BackgroundTransparency = 0.6
					}):Play()
					task.wait(0.6)
				end
			end)
		end
	end)
end

function SummaryUI:setupGamePassUpsell(upsellData: {doubleCoin: number?, extraSlot: number?, vip: number?, doubleXP: number?}?)
	-- Clear previous upsell buttons
	if self.upsellContainer then
		self.upsellContainer:Destroy()
		self.upsellContainer = nil
	end

	if not upsellData then return end

	-- Collect upsell entries
	local entries = {}
	if upsellData.doubleCoin then
		table.insert(entries, {text = "\u{1F4B0} 2\u{00D7} Coins!", id = upsellData.doubleCoin, color = Theme.PRIMARY})
	end
	if upsellData.vip then
		table.insert(entries, {text = "\u{2B50} VIP Pass!", id = upsellData.vip, color = Theme.MEDAL_GOLD})
	end
	if upsellData.doubleXP then
		table.insert(entries, {text = "\u{1F4AB} 2\u{00D7} XP!", id = upsellData.doubleXP, color = Color3.fromRGB(120, 80, 220)})
	end

	if #entries == 0 then return end

	-- Show max 2 buttons (most relevant)
	local showEntries = {}
	for i = 1, math.min(2, #entries) do
		table.insert(showEntries, entries[i])
	end

	-- Container for upsell buttons (left side of footer)
	local container = Instance.new("Frame")
	container.Name = "GamePassUpsell"
	container.Size = UDim2.new(0.55, -10, 0, 60)
	container.Position = UDim2.new(0, 0, 0, 0)
	container.BackgroundTransparency = 1
	container.ZIndex = 51
	container.Parent = self.footerFrame
	self.upsellContainer = container

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Padding = UDim.new(0, 6)
	layout.Parent = container

	local buttonWidth = if #showEntries >= 2 then 95 else 160

	for _, entry in ipairs(showEntries) do
		self:createUpsellButton(container, entry.text, entry.id, buttonWidth, entry.color)
	end
end

function SummaryUI:createUpsellButton(parent: Frame, text: string, gamePassId: number, width: number, color: Color3)
	local btn = Instance.new("TextButton")
	btn.Name = "UpsellBtn"
	btn.Size = UDim2.new(0, width, 0, 60)
	btn.BackgroundColor3 = color
	btn.BackgroundTransparency = 0.1
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.ZIndex = 52
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CORNER_SM
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = Theme.STROKE_MED
	stroke.Transparency = 0.3
	stroke.Parent = btn

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(1, color:Lerp(Theme.BG_ELEVATED, 0.3))
	})
	gradient.Rotation = 90
	gradient.Parent = btn

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Theme.TEXT_ON_ACCENT
	label.TextSize = 15
	label.Font = Enum.Font.GothamBold
	label.ZIndex = 53
	label.Parent = btn

	btn.MouseButton1Click:Connect(function()
		local player = Players.LocalPlayer
		if player and gamePassId then
			MarketplaceService:PromptGamePassPurchase(player, gamePassId)
		end
	end)

	-- Hover
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), {
			BackgroundTransparency = 0.0,
		}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), {
			BackgroundTransparency = 0.1,
		}):Play()
	end)
end

function SummaryUI:hide()
	if not self.isVisible then return end
	self.isVisible = false

	-- Scale-out animation via UIScale
	local currentScale = self.uiScale.Scale
	local hideScale = currentScale * 0.8
	local hideTween = TweenService:Create(self.uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Scale = hideScale
	})
	hideTween:Play()

	hideTween.Completed:Connect(function()
		self.mainFrame.Visible = false
		-- Restore scale for next show
		self.uiScale.Scale = currentScale
	end)
end

return SummaryUI
