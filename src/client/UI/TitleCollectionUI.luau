-- TitleCollectionUI: Collection UI with 2 tabs — Titles + Trails (manual equip)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ClassTypes = require(ReplicatedStorage.Shared.ClassTypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)
local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local TitleCollectionUI = {}
TitleCollectionUI.__index = TitleCollectionUI

local TAB_TITLES = "Titles"
local TAB_TRAILS = "Trails"

local FILTER_ALL = "All"
local FILTER_UNLOCKED = "Unlocked"
local FILTER_LOCKED = "Locked"
local SORT_CLASS = "Class"
local SORT_RARITY = "Rarity"
local SORT_LEVEL = "Level"

local SORT_ORDER = {SORT_CLASS, SORT_RARITY, SORT_LEVEL}
local RARITY_ORDER = {
	Common = 1,
	Rare = 2,
	Epic = 3,
	Legendary = 4,
}

-- Rarity accent colors for left border strips
local RARITY_COLORS = {
	Common = Theme.RARITY_COMMON,
	Rare = Theme.RARITY_RARE,
	Epic = Theme.RARITY_EPIC,
	Legendary = Theme.RARITY_LEGENDARY,
}

-- Light bright palette mapped from Theme tokens
local COLORS = {
	BG_PRIMARY = Theme.BG_BASE,
	BG_CARD = Theme.BG_SURFACE,
	BG_CARD_LOCKED = Theme.BG_ELEVATED,       -- light gray (NOT BG_OVERLAY which is black)
	BG_LIST = Theme.BG_BASE,
	BG_SEARCH = Theme.BG_SURFACE,
	BG_FILTER = Theme.BG_ELEVATED,
	BG_FILTER_ACTIVE = Theme.ACCENT_CYAN,
	BG_SORT = Theme.BG_ELEVATED,
	BG_CLOSE = Theme.DANGER,
	BG_BANNER = Theme.BG_SURFACE,
	BG_UNEQUIP = Theme.SECONDARY,
	BG_EQUIP = Theme.SUCCESS,
	BG_LOCKED_BTN = Theme.BG_ELEVATED,
	BG_TAB = Theme.BG_ELEVATED,
	BG_TAB_ACTIVE = Theme.BG_SURFACE,
	TEXT_PRIMARY = Theme.TEXT_PRIMARY,
	TEXT_SECONDARY = Theme.TEXT_MUTED,
	TEXT_MUTED = Theme.TEXT_MUTED,
	TEXT_WHITE = Theme.TEXT_PRIMARY,
	TEXT_LOCKED = Theme.CARD_SHADOW,            -- muted gray for locked text
	STROKE_DEFAULT = Theme.BG_ELEVATED,
	STROKE_BANNER = Theme.BG_ELEVATED,
	STROKE_CARD = Theme.BG_ELEVATED,
	STROKE_CARD_LOCKED = Theme.CARD_SHADOW,    -- soft gray (NOT BG_OVERLAY which is black)
	TAB_UNDERLINE = Theme.ACCENT_CYAN,
}

local PANEL_W = 780
local PANEL_H = 580

local RARITY_EMOJI = {Common = "\u{26AA}", Uncommon = "\u{1F7E2}", Rare = "\u{1F535}", Epic = "\u{1F7E3}", Legendary = "\u{2B50}"}

local function cloneEntry(source: any): {id: string, name: string, classId: string, level: number, rarity: string, description: string?, unlocked: boolean}?
	if type(source) ~= "table" then
		return nil
	end

	if type(source.id) ~= "string" or source.id == "" then
		return nil
	end

	if type(source.name) ~= "string" or source.name == "" then
		return nil
	end

	if type(source.classId) ~= "string" or source.classId == "" then
		return nil
	end

	return {
		id = source.id,
		name = source.name,
		classId = source.classId,
		level = math.max(1, math.floor(tonumber(source.level) or 1)),
		rarity = if type(source.rarity) == "string" and source.rarity ~= "" then source.rarity else "Common",
		description = if type(source.description) == "string" then source.description else nil,
		unlocked = source.unlocked == true,
	}
end

local function cloneEntryList(source: any): {{id: string, name: string, classId: string, level: number, rarity: string, description: string?, unlocked: boolean}}
	local list = {} :: {{id: string, name: string, classId: string, level: number, rarity: string, description: string?, unlocked: boolean}}
	if type(source) ~= "table" then
		return list
	end

	for _, entry in ipairs(source) do
		local cloned = cloneEntry(entry)
		if cloned then
			table.insert(list, cloned)
		end
	end

	local classOrderIndex = {} :: {[string]: number}
	for index, classId in ipairs(ClassTypes.getAllClassIds()) do
		classOrderIndex[classId] = index
	end

	table.sort(list, function(a, b)
		local aOrder = classOrderIndex[a.classId] or 999
		local bOrder = classOrderIndex[b.classId] or 999
		if aOrder == bOrder then
			if a.level == b.level then
				return a.id < b.id
			end
			return a.level < b.level
		end
		return aOrder < bOrder
	end)

	return list
end

local function getEntryTheme(rarity: string, classColor: Color3?): {textColor: Color3, frameColor: Color3}
	local configured = Config.Mastery and Config.Mastery.TitleThemes
	local theme = type(configured) == "table" and configured[rarity] or nil

	local result = {
		textColor = classColor or Theme.TEXT_MUTED,
		frameColor = classColor or COLORS.STROKE_DEFAULT,
	}

	if type(theme) == "table" then
		if typeof(theme.textColor) == "Color3" then
			result.textColor = theme.textColor
		end
		if typeof(theme.frameColor) == "Color3" then
			result.frameColor = theme.frameColor
		end
	end

	return result
end

function TitleCollectionUI.new(parent: ScreenGui, callbacks: {onHide: (() -> ())?}?)
	local self = setmetatable({}, TitleCollectionUI)

	self.parent = parent
	self.callbacks = callbacks
	self.remotes = Remotes
	self.isVisible = false

	-- Tab state
	self.activeTab = TAB_TITLES

	-- Title data
	self.titleCatalog = {}
	self.activeTitle = nil

	-- Trail data
	self.trailCatalog = {}
	self.activeTrail = nil

	-- Shared UI state
	self.activeFilter = FILTER_ALL
	self.activeSort = SORT_CLASS
	self.searchText = ""
	self.filterButtons = {}
	self.activeToast = nil
	self.lastRenderedCount = nil
	self.lastRenderedTotal = nil

	self:createUI()
	self:setupRemotes()
	self:updateActiveBanner()
	self:updateFilterButtons()
	self:updateSortButton()
	self:updateSearchClearButtonState()
	self:updateTabButtons()
	self:rebuildEntries()

	return self
end

function TitleCollectionUI:createUI()
	-- Main container - light modal
	local container = Instance.new("Frame")
	container.Name = "TitleCollectionContainer"
	container.Size = UDim2.new(0, 780, 0, 580)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundColor3 = COLORS.BG_PRIMARY
	container.BackgroundTransparency = 0.02
	container.BorderSizePixel = 0
	container.Visible = false
	container.Parent = self.parent
	self.container = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CORNER_LG
	corner.Parent = container

	-- Gradient background
	local containerGrad = Instance.new("UIGradient")
	containerGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.PANEL_GRAD_TOP),
		ColorSequenceKeypoint.new(1, Theme.PANEL_GRAD_BTM),
	})
	containerGrad.Rotation = 180
	containerGrad.Parent = container

	-- Glow stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.ACCENT_CYAN
	stroke.Thickness = Theme.STROKE_MED
	stroke.Transparency = 0.5
	stroke.Parent = container

	-- Drop shadow
	local containerShadow = Instance.new("Frame")
	containerShadow.Name = "Shadow"
	containerShadow.Size = UDim2.new(1, 6, 1, 6)
	containerShadow.Position = UDim2.new(0, -3, 0, 4)
	containerShadow.BackgroundColor3 = Theme.CARD_SHADOW
	containerShadow.BackgroundTransparency = 0.7
	containerShadow.BorderSizePixel = 0
	containerShadow.ZIndex = container.ZIndex - 1
	containerShadow.Parent = container
	Theme.applyCorner(containerShadow, "lg")

	-- ===== HEADER =====
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(0, 300, 0, 40)
	header.Position = UDim2.new(0, 22, 0, 10)
	header.BackgroundTransparency = 1
	header.RichText = true
	header.Text = '<font size="22">\u{2B50}</font>  <font face="GothamBold" size="28"><b>COLLECTION</b></font>'
	header.TextColor3 = Theme.TEXT_PRIMARY
	header.TextSize = 28
	header.Font = Enum.Font.GothamBold
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = container

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 40, 0, 40)
	closeButton.Position = UDim2.new(1, -54, 0, 12)
	closeButton.BackgroundColor3 = Theme.DANGER
	closeButton.BorderSizePixel = 0
	closeButton.Text = ""
	closeButton.Parent = container
	self.closeButton = closeButton
	Theme.applyCorner(closeButton, "sm")

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = Theme.DANGER
	closeStroke.Thickness = 1
	closeStroke.Transparency = 0.3
	closeStroke.Parent = closeButton

	local closeBtnLabel = Instance.new("TextLabel")
	closeBtnLabel.Size = UDim2.new(1, 0, 1, 0)
	closeBtnLabel.BackgroundTransparency = 1
	closeBtnLabel.Text = "X"
	closeBtnLabel.TextColor3 = Theme.TEXT_ON_ACCENT
	closeBtnLabel.TextSize = 20
	closeBtnLabel.Font = Enum.Font.GothamBold
	closeBtnLabel.ZIndex = closeButton.ZIndex + 1
	closeBtnLabel.Parent = closeButton

	-- ===== TAB BAR =====
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, -32, 0, 30)
	tabBar.Position = UDim2.new(0, 16, 0, 52)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = container

	self.tabButtons = {}

	local function createTabButton(label: string, icon: string, posX: number, width: number)
		local tabFrame = Instance.new("Frame")
		tabFrame.Name = "Tab_" .. label
		tabFrame.Size = UDim2.new(0, width, 1, 0)
		tabFrame.Position = UDim2.new(0, posX, 0, 0)
		tabFrame.BackgroundColor3 = COLORS.BG_TAB
		tabFrame.BorderSizePixel = 0
		tabFrame.Parent = tabBar
		Theme.applyCorner(tabFrame, "sm")

		local tabLabel = Instance.new("TextLabel")
		tabLabel.Name = "Label"
		tabLabel.Size = UDim2.new(1, 0, 1, -3)
		tabLabel.BackgroundTransparency = 1
		tabLabel.Text = icon .. " " .. label
		tabLabel.TextColor3 = COLORS.TEXT_SECONDARY
		tabLabel.TextSize = 15
		tabLabel.Font = Enum.Font.GothamBold
		tabLabel.Parent = tabFrame

		local underline = Instance.new("Frame")
		underline.Name = "Underline"
		underline.Size = UDim2.new(0.7, 0, 0, 3)
		underline.Position = UDim2.new(0.15, 0, 1, -3)
		underline.BackgroundColor3 = COLORS.TAB_UNDERLINE
		underline.BorderSizePixel = 0
		underline.Visible = false
		underline.Parent = tabFrame
		Theme.applyCorner(underline, "sm")

		local tabButton = Instance.new("TextButton")
		tabButton.Name = "TabButton"
		tabButton.Size = UDim2.new(1, 0, 1, 0)
		tabButton.BackgroundTransparency = 1
		tabButton.Text = ""
		tabButton.ZIndex = tabFrame.ZIndex + 1
		tabButton.Parent = tabFrame

		self.tabButtons[label] = {
			frame = tabFrame,
			label = tabLabel,
			underline = underline,
			button = tabButton,
		}

		tabButton.MouseButton1Click:Connect(function()
			self:setActiveTab(label)
		end)
	end

	createTabButton(TAB_TITLES, "\u{1F3F7}", 0, 170)
	createTabButton(TAB_TRAILS, "\u{2728}", 178, 170)

	-- ===== ACTIVE BANNER =====
	local bannerFrame = Instance.new("Frame")
	bannerFrame.Name = "ActiveBanner"
	bannerFrame.Size = UDim2.new(1, -32, 0, 40)
	bannerFrame.Position = UDim2.new(0, 16, 0, 86)
	bannerFrame.BackgroundColor3 = COLORS.BG_BANNER
	bannerFrame.BackgroundTransparency = 0
	bannerFrame.BorderSizePixel = 0
	bannerFrame.Parent = container
	self.bannerFrame = bannerFrame

	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = Theme.CORNER_SM
	bannerCorner.Parent = bannerFrame

	local bannerStroke = Instance.new("UIStroke")
	bannerStroke.Color = COLORS.STROKE_BANNER
	bannerStroke.Thickness = 1.5
	bannerStroke.Parent = bannerFrame
	self.bannerStroke = bannerStroke

	local bannerPrefix = Instance.new("TextLabel")
	bannerPrefix.Name = "BannerPrefix"
	bannerPrefix.Size = UDim2.new(0, 110, 1, 0)
	bannerPrefix.Position = UDim2.new(0, 12, 0, 0)
	bannerPrefix.BackgroundTransparency = 1
	bannerPrefix.Text = "ACTIVE TITLE"
	bannerPrefix.TextColor3 = COLORS.TEXT_SECONDARY
	bannerPrefix.TextSize = 11
	bannerPrefix.Font = Enum.Font.GothamBold
	bannerPrefix.TextXAlignment = Enum.TextXAlignment.Left
	bannerPrefix.Parent = bannerFrame
	self.bannerPrefix = bannerPrefix

	local bannerValueLabel = Instance.new("TextLabel")
	bannerValueLabel.Name = "BannerValueLabel"
	bannerValueLabel.Size = UDim2.new(1, -260, 1, 0)
	bannerValueLabel.Position = UDim2.new(0, 128, 0, 0)
	bannerValueLabel.BackgroundTransparency = 1
	bannerValueLabel.Text = "None"
	bannerValueLabel.TextColor3 = COLORS.TEXT_MUTED
	bannerValueLabel.TextSize = 14
	bannerValueLabel.Font = Enum.Font.GothamBold
	bannerValueLabel.TextXAlignment = Enum.TextXAlignment.Left
	bannerValueLabel.TextTruncate = Enum.TextTruncate.AtEnd
	bannerValueLabel.Parent = bannerFrame
	self.bannerValueLabel = bannerValueLabel

	local unequipButton = Instance.new("TextButton")
	unequipButton.Name = "UnequipButton"
	unequipButton.Size = UDim2.new(0, 100, 0, 30)
	unequipButton.Position = UDim2.new(1, -112, 0.5, -15)
	unequipButton.BackgroundColor3 = COLORS.BG_UNEQUIP
	unequipButton.BorderSizePixel = 0
	unequipButton.Text = "UNEQUIP"
	unequipButton.TextColor3 = Theme.TEXT_ON_ACCENT
	unequipButton.TextSize = 13
	unequipButton.Font = Enum.Font.GothamBold
	unequipButton.Parent = bannerFrame
	self.unequipButton = unequipButton

	Theme.applyCorner(unequipButton, "sm")

	local unequipStroke = Instance.new("UIStroke")
	unequipStroke.Color = COLORS.BG_UNEQUIP
	unequipStroke.Thickness = Theme.STROKE_THIN
	unequipStroke.Transparency = 0.3
	unequipStroke.Parent = unequipButton

	-- ===== SEARCH + FILTER BAR =====
	local searchBox = Instance.new("TextBox")
	searchBox.Name = "SearchBox"
	searchBox.Size = UDim2.new(1, -120, 0, 32)
	searchBox.Position = UDim2.new(0, 16, 0, 134)
	searchBox.BackgroundColor3 = COLORS.BG_SEARCH
	searchBox.BackgroundTransparency = 0
	searchBox.BorderSizePixel = 0
	searchBox.PlaceholderText = "Search name, class, rarity..."
	searchBox.Text = ""
	searchBox.TextColor3 = COLORS.TEXT_PRIMARY
	searchBox.PlaceholderColor3 = COLORS.TEXT_MUTED
	searchBox.TextSize = 14
	searchBox.Font = Enum.Font.Gotham
	searchBox.ClearTextOnFocus = false
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.Parent = container
	self.searchBox = searchBox

	local searchCorner = Instance.new("UICorner")
	searchCorner.CornerRadius = UDim.new(0, 8)
	searchCorner.Parent = searchBox

	local searchStroke = Instance.new("UIStroke")
	searchStroke.Color = COLORS.STROKE_DEFAULT
	searchStroke.Thickness = 1
	searchStroke.Parent = searchBox

	local searchPadding = Instance.new("UIPadding")
	searchPadding.PaddingLeft = UDim.new(0, 10)
	searchPadding.Parent = searchBox

	local clearSearchButton = Instance.new("TextButton")
	clearSearchButton.Name = "ClearSearchButton"
	clearSearchButton.Size = UDim2.new(0, 84, 0, 32)
	clearSearchButton.Position = UDim2.new(1, -100, 0, 134)
	clearSearchButton.BackgroundColor3 = COLORS.BG_FILTER
	clearSearchButton.BorderSizePixel = 0
	clearSearchButton.Text = "CLEAR"
	clearSearchButton.TextColor3 = COLORS.TEXT_SECONDARY
	clearSearchButton.TextSize = 12
	clearSearchButton.Font = Enum.Font.GothamBold
	clearSearchButton.Parent = container
	self.clearSearchButton = clearSearchButton

	local clearSearchCorner = Instance.new("UICorner")
	clearSearchCorner.CornerRadius = UDim.new(0, 8)
	clearSearchCorner.Parent = clearSearchButton

	-- ===== FILTER + SORT BAR =====
	local filterBar = Instance.new("Frame")
	filterBar.Name = "FilterBar"
	filterBar.Size = UDim2.new(1, -32, 0, 28)
	filterBar.Position = UDim2.new(0, 16, 0, 174)
	filterBar.BackgroundTransparency = 1
	filterBar.Parent = container

	local function createFilterButton(label: string, position: UDim2, size: UDim2)
		local button = Instance.new("TextButton")
		button.Name = "Filter" .. label
		button.Size = size
		button.Position = position
		button.BackgroundColor3 = COLORS.BG_FILTER
		button.BorderSizePixel = 0
		button.Text = label
		button.TextColor3 = COLORS.TEXT_SECONDARY
		button.TextSize = 13
		button.Font = Enum.Font.GothamBold
		button.Parent = filterBar

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 7)
		btnCorner.Parent = button

		return button
	end

	self.filterButtons[FILTER_ALL] = createFilterButton(FILTER_ALL, UDim2.new(0, 0, 0, 0), UDim2.new(0, 60, 1, 0))
	self.filterButtons[FILTER_UNLOCKED] = createFilterButton(FILTER_UNLOCKED, UDim2.new(0, 66, 0, 0), UDim2.new(0, 96, 1, 0))
	self.filterButtons[FILTER_LOCKED] = createFilterButton(FILTER_LOCKED, UDim2.new(0, 168, 0, 0), UDim2.new(0, 80, 1, 0))

	local sortButton = Instance.new("TextButton")
	sortButton.Name = "SortButton"
	sortButton.Size = UDim2.new(0, 130, 1, 0)
	sortButton.Position = UDim2.new(0, 260, 0, 0)
	sortButton.BackgroundColor3 = COLORS.BG_SORT
	sortButton.BorderSizePixel = 0
	sortButton.Text = "Sort: Class \u{25BC}"
	sortButton.TextColor3 = COLORS.TEXT_WHITE
	sortButton.TextSize = 13
	sortButton.Font = Enum.Font.GothamBold
	sortButton.Parent = filterBar
	self.sortButton = sortButton

	local sortCorner = Instance.new("UICorner")
	sortCorner.CornerRadius = UDim.new(0, 7)
	sortCorner.Parent = sortButton

	local resultLabel = Instance.new("TextLabel")
	resultLabel.Name = "ResultLabel"
	resultLabel.Size = UDim2.new(1, -400, 1, 0)
	resultLabel.Position = UDim2.new(0, 400, 0, 0)
	resultLabel.BackgroundTransparency = 1
	resultLabel.Text = "0 / 0"
	resultLabel.TextColor3 = COLORS.TEXT_SECONDARY
	resultLabel.TextSize = 13
	resultLabel.Font = Enum.Font.Gotham
	resultLabel.TextXAlignment = Enum.TextXAlignment.Right
	resultLabel.Parent = filterBar
	self.resultLabel = resultLabel

	-- ===== ITEM LIST =====
	local listFrame = Instance.new("ScrollingFrame")
	listFrame.Name = "ItemList"
	listFrame.Size = UDim2.new(1, -32, 1, -214)
	listFrame.Position = UDim2.new(0, 16, 0, 208)
	listFrame.BackgroundColor3 = COLORS.BG_LIST
	listFrame.BackgroundTransparency = 0.3
	listFrame.BorderSizePixel = 0
	listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	listFrame.ScrollBarThickness = 6
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
	listFrame.ScrollBarImageColor3 = Theme.TEXT_MUTED
	listFrame.Parent = container
	self.listFrame = listFrame

	local listCorner = Instance.new("UICorner")
	listCorner.CornerRadius = UDim.new(0, 10)
	listCorner.Parent = listFrame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = listFrame
	self.listLayout = layout

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 6)
	listPadding.PaddingBottom = UDim.new(0, 6)
	listPadding.PaddingLeft = UDim.new(0, 6)
	listPadding.PaddingRight = UDim.new(0, 6)
	listPadding.Parent = listFrame

	local emptyLabel = Instance.new("TextLabel")
	emptyLabel.Name = "EmptyLabel"
	emptyLabel.Size = UDim2.new(1, -18, 0, 0)
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.Text = "No items found! Keep playing to earn more."
	emptyLabel.TextColor3 = COLORS.TEXT_SECONDARY
	emptyLabel.TextSize = 15
	emptyLabel.Font = Enum.Font.Gotham
	emptyLabel.Visible = false
	emptyLabel.Parent = listFrame
	self.emptyLabel = emptyLabel

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		local uiScaleObj = self.container:FindFirstChildOfClass("UIScale")
		local scaleFactor = uiScaleObj and uiScaleObj.Scale or 1
		self.listFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y / scaleFactor + 12)
	end)

	-- ===== CONNECTIONS =====
	closeButton.MouseButton1Click:Connect(function()
		self:hide()
	end)

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local query = string.lower(searchBox.Text or "")
		query = string.gsub(query, "^%s+", "")
		query = string.gsub(query, "%s+$", "")
		self.searchText = query
		self:updateSearchClearButtonState()
		self:rebuildEntries(true, "search")
	end)

	for filterId, button in pairs(self.filterButtons) do
		button.MouseButton1Click:Connect(function()
			self:setFilter(filterId)
		end)
	end

	clearSearchButton.MouseButton1Click:Connect(function()
		if self.searchText ~= "" then
			searchBox.Text = ""
		end
	end)

	sortButton.MouseButton1Click:Connect(function()
		self:cycleSortMode()
	end)

	unequipButton.MouseButton1Click:Connect(function()
		if self.activeTab == TAB_TITLES then
			if self.activeTitle then
				self.remotes.SetActiveTitle:FireServer("")
			end
		else
			if self.activeTrail then
				self.remotes.SetActiveTrail:FireServer("")
			end
		end
	end)

	-- Responsive scaling (Phase 2)
	local uiScale = ResponsiveScale.applyToFrame(self.container, PANEL_W, PANEL_H)
	ResponsiveScale.compensateStrokes(self.container, uiScale.Scale)
end

-- ===== TAB MANAGEMENT =====

function TitleCollectionUI:setActiveTab(tabId: string)
	if tabId ~= TAB_TITLES and tabId ~= TAB_TRAILS then
		return
	end
	if self.activeTab == tabId then
		return
	end

	self.activeTab = tabId
	self.lastRenderedCount = nil
	self.lastRenderedTotal = nil
	self:updateTabButtons()
	self:updateActiveBanner()
	self:rebuildEntries()
end

function TitleCollectionUI:updateTabButtons()
	for tabId, tabUI in pairs(self.tabButtons) do
		local isActive = tabId == self.activeTab
		tabUI.frame.BackgroundColor3 = if isActive then COLORS.BG_TAB_ACTIVE else COLORS.BG_TAB
		tabUI.label.TextColor3 = if isActive then COLORS.TEXT_PRIMARY else COLORS.TEXT_SECONDARY
		tabUI.label.Font = if isActive then Enum.Font.GothamBold else Enum.Font.GothamMedium
		tabUI.underline.Visible = isActive
	end
end

-- ===== BANNER =====

function TitleCollectionUI:updateActiveBanner()
	if not self.bannerValueLabel then
		return
	end

	-- Stop existing pulse
	if self._bannerPulseTween then
		self._bannerPulseTween:Cancel()
		self._bannerPulseTween = nil
	end

	local isTitle = self.activeTab == TAB_TITLES
	local activeItem = if isTitle then self.activeTitle else self.activeTrail
	local emptyText = if isTitle then "No Title" else "No Trail"

	if self.bannerPrefix then
		self.bannerPrefix.Text = if isTitle then "ACTIVE TITLE" else "ACTIVE TRAIL"
	end

	if not activeItem then
		self.bannerValueLabel.Text = emptyText
		self.bannerValueLabel.TextColor3 = COLORS.TEXT_MUTED
		if self.unequipButton then
			self.unequipButton.Active = false
			self.unequipButton.AutoButtonColor = false
			self.unequipButton.BackgroundColor3 = COLORS.BG_LOCKED_BTN
			self.unequipButton.TextColor3 = COLORS.TEXT_MUTED
			self.unequipButton.TextTransparency = 0.4
		end
		if self.bannerStroke then
			self.bannerStroke.Color = COLORS.STROKE_BANNER
			self.bannerStroke.Transparency = 0
		end
		return
	end

	local classDef = ClassTypes.getClass(activeItem.classId)
	local theme = getEntryTheme(activeItem.rarity, classDef and classDef.color or nil)

	self.bannerValueLabel.Text = string.format("[%s] %s", activeItem.rarity, activeItem.name)
	self.bannerValueLabel.TextColor3 = theme.textColor

	if self.unequipButton then
		self.unequipButton.Active = true
		self.unequipButton.AutoButtonColor = true
		self.unequipButton.BackgroundColor3 = COLORS.BG_UNEQUIP
		self.unequipButton.TextColor3 = Theme.TEXT_ON_ACCENT
		self.unequipButton.TextTransparency = 0
	end

	-- Banner stroke glow pulse with rarity color
	if self.bannerStroke then
		self.bannerStroke.Color = theme.frameColor
		self.bannerStroke.Transparency = 0.2
		self._bannerPulseTween = TweenService:Create(self.bannerStroke,
			TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.6 }
		)
		self._bannerPulseTween:Play()
	end
end

-- ===== FILTER / SORT / SEARCH =====

function TitleCollectionUI:updateFilterButtons()
	for filterId, button in pairs(self.filterButtons) do
		local isSelected = filterId == self.activeFilter
		button.BackgroundColor3 = if isSelected then COLORS.BG_FILTER_ACTIVE else COLORS.BG_FILTER
		button.TextColor3 = if isSelected then Theme.TEXT_ON_ACCENT else COLORS.TEXT_SECONDARY
	end
end

function TitleCollectionUI:updateSortButton()
	if not self.sortButton then
		return
	end

	self.sortButton.Text = "Sort: " .. self.activeSort .. " \u{25BC}"
end

function TitleCollectionUI:updateSearchClearButtonState()
	if not self.clearSearchButton then
		return
	end

	local hasSearchText = self.searchText ~= ""
	self.clearSearchButton.Active = hasSearchText
	self.clearSearchButton.AutoButtonColor = hasSearchText
	self.clearSearchButton.BackgroundColor3 = if hasSearchText then COLORS.BG_FILTER_ACTIVE else COLORS.BG_FILTER
	self.clearSearchButton.TextColor3 = if hasSearchText then Theme.TEXT_ON_ACCENT else COLORS.TEXT_MUTED
end

function TitleCollectionUI:setFilter(filterId: string)
	if filterId ~= FILTER_ALL and filterId ~= FILTER_UNLOCKED and filterId ~= FILTER_LOCKED then
		return
	end

	if self.activeFilter == filterId then
		return
	end

	self.activeFilter = filterId
	self:updateFilterButtons()
	self:rebuildEntries(true, "filter")
end

function TitleCollectionUI:cycleSortMode()
	local currentIndex = 1
	for index, value in ipairs(SORT_ORDER) do
		if value == self.activeSort then
			currentIndex = index
			break
		end
	end

	local nextIndex = currentIndex + 1
	if nextIndex > #SORT_ORDER then
		nextIndex = 1
	end

	self.activeSort = SORT_ORDER[nextIndex]
	self:updateSortButton()
	self:rebuildEntries(true, "sort")
end

function TitleCollectionUI:matchesFilter(entry: {id: string, name: string, classId: string, level: number, rarity: string, description: string?, unlocked: boolean}): boolean
	if self.activeFilter == FILTER_UNLOCKED and not entry.unlocked then
		return false
	end
	if self.activeFilter == FILTER_LOCKED and entry.unlocked then
		return false
	end

	local query = self.searchText
	if query == "" then
		return true
	end

	local classDef = ClassTypes.getClass(entry.classId)
	local className = string.lower(classDef and classDef.name or entry.classId)
	local itemName = string.lower(entry.name)
	local rarity = string.lower(entry.rarity)
	local description = string.lower(entry.description or "")

	return string.find(itemName, query, 1, true) ~= nil
		or string.find(className, query, 1, true) ~= nil
		or string.find(rarity, query, 1, true) ~= nil
		or string.find(description, query, 1, true) ~= nil
end

function TitleCollectionUI:compareBySort(
	a: {id: string, name: string, classId: string, level: number, rarity: string, description: string?, unlocked: boolean},
	b: {id: string, name: string, classId: string, level: number, rarity: string, description: string?, unlocked: boolean},
	classOrderIndex: {[string]: number}
): boolean
	local aClassOrder = classOrderIndex[a.classId] or 999
	local bClassOrder = classOrderIndex[b.classId] or 999
	local aRarityOrder = RARITY_ORDER[a.rarity] or 999
	local bRarityOrder = RARITY_ORDER[b.rarity] or 999

	if self.activeSort == SORT_RARITY then
		if aRarityOrder ~= bRarityOrder then
			return aRarityOrder < bRarityOrder
		end
		if aClassOrder ~= bClassOrder then
			return aClassOrder < bClassOrder
		end
		if a.level ~= b.level then
			return a.level < b.level
		end
	elseif self.activeSort == SORT_LEVEL then
		if a.level ~= b.level then
			return a.level > b.level
		end
		if aClassOrder ~= bClassOrder then
			return aClassOrder < bClassOrder
		end
		if aRarityOrder ~= bRarityOrder then
			return aRarityOrder < bRarityOrder
		end
	else
		if aClassOrder ~= bClassOrder then
			return aClassOrder < bClassOrder
		end
		if a.level ~= b.level then
			return a.level < b.level
		end
		if aRarityOrder ~= bRarityOrder then
			return aRarityOrder < bRarityOrder
		end
	end

	return a.id < b.id
end

function TitleCollectionUI:getActiveCatalog(): {{id: string, name: string, classId: string, level: number, rarity: string, description: string?, unlocked: boolean}}
	return if self.activeTab == TAB_TITLES then self.titleCatalog else self.trailCatalog
end

function TitleCollectionUI:getActiveEquipped(): {id: string, name: string, classId: string, level: number, rarity: string, description: string?, unlocked: boolean}?
	return if self.activeTab == TAB_TITLES then self.activeTitle else self.activeTrail
end

function TitleCollectionUI:getFilteredCatalog(): {{id: string, name: string, classId: string, level: number, rarity: string, description: string?, unlocked: boolean}}
	local filtered = {}
	local classOrderIndex = {} :: {[string]: number}
	for index, classId in ipairs(ClassTypes.getAllClassIds()) do
		classOrderIndex[classId] = index
	end

	local catalog = self:getActiveCatalog()
	for _, entry in ipairs(catalog) do
		if self:matchesFilter(entry) then
			table.insert(filtered, entry)
		end
	end

	table.sort(filtered, function(a, b)
		return self:compareBySort(a, b, classOrderIndex)
	end)

	return filtered
end

-- ===== ENTRY RENDERING =====

function TitleCollectionUI:clearEntryFrames()
	for _, child in ipairs(self.listFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name == "ItemEntry" then
			child:Destroy()
		end
	end
end

function TitleCollectionUI:showToast(text: string, color: Color3?)
	if not self.container then
		return
	end

	if self.activeToast and self.activeToast.Parent then
		self.activeToast:Destroy()
	end

	local toast = Instance.new("TextLabel")
	toast.Name = "CollectionToast"
	toast.Size = UDim2.new(0, 250, 0, 30)
	toast.Position = UDim2.new(1, -266, 0, 210)
	toast.BackgroundColor3 = COLORS.BG_CARD
	toast.BackgroundTransparency = 0
	toast.BorderSizePixel = 0
	toast.Text = text
	toast.TextColor3 = color or COLORS.TEXT_PRIMARY
	toast.TextSize = 12
	toast.Font = Enum.Font.GothamBold
	toast.TextTransparency = 1
	toast.Parent = self.container
	self.activeToast = toast

	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 8)
	toastCorner.Parent = toast

	local toastStroke = Instance.new("UIStroke")
	toastStroke.Color = COLORS.STROKE_DEFAULT
	toastStroke.Thickness = 1
	toastStroke.Parent = toast

	TweenService:Create(toast, TweenInfo.new(0.12), {
		TextTransparency = 0,
	}):Play()

	task.delay(1.5, function()
		if toast.Parent then
			local fade = TweenService:Create(toast, TweenInfo.new(0.2), {
				TextTransparency = 1,
				BackgroundTransparency = 1,
			})
			fade:Play()
			fade.Completed:Connect(function()
				if toast.Parent then
					toast:Destroy()
				end
			end)
		end
	end)
end

function TitleCollectionUI:rebuildEntries(showFeedback: boolean?, feedbackSource: string?)
	if not self.listFrame then
		return
	end

	self:clearEntryFrames()

	local catalog = self:getActiveCatalog()
	local filteredCatalog = self:getFilteredCatalog()
	local itemLabel = if self.activeTab == TAB_TITLES then "titles" else "trails"

	if self.resultLabel then
		self.resultLabel.Text = string.format("%d / %d %s", #filteredCatalog, #catalog, itemLabel)
	end

	local filteredCount = #filteredCatalog
	local totalCount = #catalog
	if showFeedback and self.isVisible then
		local resultChanged = self.lastRenderedCount ~= filteredCount or self.lastRenderedTotal ~= totalCount
		if resultChanged then
			if filteredCount == 0 then
				local sourceLabel = if feedbackSource == "search" then "search"
					elseif feedbackSource == "filter" then "filter"
					elseif feedbackSource == "sort" then "sort"
					else "selection"
				self:showToast("No " .. itemLabel .. " found for current " .. sourceLabel, Theme.SECONDARY)
			end
		end
	end

	self.lastRenderedCount = filteredCount
	self.lastRenderedTotal = totalCount

	if #catalog == 0 then
		self.emptyLabel.Visible = true
		self.emptyLabel.LayoutOrder = 1
		self.emptyLabel.Size = UDim2.new(1, -18, 0, 30)
		self.emptyLabel.Text = "No " .. itemLabel .. " found! Keep playing to earn more."
		return
	end

	if #filteredCatalog == 0 then
		self.emptyLabel.Visible = true
		self.emptyLabel.LayoutOrder = 1
		self.emptyLabel.Size = UDim2.new(1, -18, 0, 30)
		self.emptyLabel.Text = "No " .. itemLabel .. " match your filter. Try 'All'"
		return
	end

	self.emptyLabel.Visible = false
	self.emptyLabel.Size = UDim2.new(1, -18, 0, 0)

	local activeEquipped = self:getActiveEquipped()
	local activeId = activeEquipped and activeEquipped.id or nil
	local isTitle = self.activeTab == TAB_TITLES
	local equipRemoteName = if isTitle then "SetActiveTitle" else "SetActiveTrail"

	for index, entry in ipairs(filteredCatalog) do
		local classDef = ClassTypes.getClass(entry.classId)
		local className = classDef and classDef.name or entry.classId
		local classIcon = classDef and classDef.icon or ""
		local theme = getEntryTheme(entry.rarity, classDef and classDef.color or nil)
		local rarityColor = RARITY_COLORS[entry.rarity] or RARITY_COLORS.Common
		local isActive = activeId == entry.id

		-- Compact card (62px height)
		local card = Instance.new("Frame")
		card.Name = "ItemEntry"
		card.Size = UDim2.new(1, -4, 0, 72)
		card.BackgroundColor3 = if entry.unlocked then COLORS.BG_CARD else COLORS.BG_CARD_LOCKED
		card.BackgroundTransparency = 0
		card.BorderSizePixel = 0
		card.LayoutOrder = index
		card.ClipsDescendants = true
		card.Parent = self.listFrame

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 8)
		cardCorner.Parent = card

		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = if isActive then theme.frameColor
			elseif entry.unlocked then COLORS.STROKE_CARD
			else COLORS.STROKE_CARD_LOCKED
		cardStroke.Thickness = if isActive then 2 else 1
		cardStroke.Parent = card

		-- Rarity color strip (left border, 6px + rounded)
		local rarityStrip = Instance.new("Frame")
		rarityStrip.Name = "RarityStrip"
		rarityStrip.Size = UDim2.new(0, 6, 1, 0)
		rarityStrip.Position = UDim2.new(0, 0, 0, 0)
		rarityStrip.BackgroundColor3 = if entry.unlocked then rarityColor else Theme.CARD_SHADOW
		rarityStrip.BackgroundTransparency = if entry.unlocked then 0 else 0.3
		rarityStrip.BorderSizePixel = 0
		rarityStrip.Parent = card

		local stripCorner = Instance.new("UICorner")
		stripCorner.CornerRadius = UDim.new(0, 3)
		stripCorner.Parent = rarityStrip

		-- Name (row 1) — with rarity emoji
		local rarityEmoji = RARITY_EMOJI[entry.rarity] or ""

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -160, 0, 24)
		nameLabel.Position = UDim2.new(0, 16, 0, 8)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = string.format("%s [%s] %s", rarityEmoji, entry.rarity, entry.name)
		nameLabel.TextColor3 = if entry.unlocked then theme.textColor else COLORS.TEXT_LOCKED
		nameLabel.TextSize = 17
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = card

		-- Detail line (row 2): "Runner • Lv.10"
		local detailText = if entry.unlocked
			then string.format("%s %s \u{2022} Lv.%d", classIcon, className, entry.level)
			else string.format("%s %s \u{2022} Reach Lv.%d to unlock", classIcon, className, entry.level)

		local detailLabel = Instance.new("TextLabel")
		detailLabel.Size = UDim2.new(1, -150, 0, 20)
		detailLabel.Position = UDim2.new(0, 14, 0, 32)
		detailLabel.BackgroundTransparency = 1
		detailLabel.Text = detailText
		detailLabel.TextColor3 = if entry.unlocked then COLORS.TEXT_SECONDARY else COLORS.TEXT_LOCKED
		detailLabel.TextSize = 14
		detailLabel.Font = Enum.Font.Gotham
		detailLabel.TextXAlignment = Enum.TextXAlignment.Left
		detailLabel.Parent = card

		-- Action button (right side)
		local actionButton = Instance.new("TextButton")
		actionButton.Size = UDim2.new(0, 100, 0, 32)
		actionButton.Position = UDim2.new(1, -112, 0.5, -16)
		actionButton.BorderSizePixel = 0
		actionButton.TextColor3 = Theme.TEXT_ON_ACCENT
		actionButton.TextSize = 13
		actionButton.Font = Enum.Font.GothamBold
		actionButton.Parent = card

		Theme.applyCorner(actionButton, "sm")

		local actionStroke = Instance.new("UIStroke")
		actionStroke.Thickness = Theme.STROKE_THIN
		actionStroke.Parent = actionButton

		if not entry.unlocked then
			actionButton.Text = "LOCKED"
			actionButton.Active = false
			actionButton.AutoButtonColor = false
			actionButton.BackgroundColor3 = Theme.BG_SURFACE
			actionButton.TextColor3 = COLORS.TEXT_LOCKED
			actionButton.TextTransparency = 0.2
			actionStroke.Color = Theme.BG_ELEVATED
			actionStroke.Transparency = 0.5
		else
			if isActive then
				actionButton.Text = "EQUIPPED"
				actionButton.Active = true
				actionButton.AutoButtonColor = true
				actionButton.BackgroundColor3 = COLORS.BG_UNEQUIP
				actionStroke.Color = COLORS.BG_UNEQUIP
				actionStroke.Transparency = 0.3
			else
				actionButton.Text = "EQUIP"
				actionButton.Active = true
				actionButton.AutoButtonColor = true
				actionButton.BackgroundColor3 = COLORS.BG_EQUIP
				actionStroke.Color = COLORS.BG_EQUIP
				actionStroke.Transparency = 0.3
			end

			local capturedEntryId = entry.id
			actionButton.MouseButton1Click:Connect(function()
				local currentEquipped = self:getActiveEquipped()
				if currentEquipped and currentEquipped.id == capturedEntryId then
					self.remotes[equipRemoteName]:FireServer("")
				else
					self.remotes[equipRemoteName]:FireServer(capturedEntryId)
				end
			end)
		end

		-- Row hover effect
		local baseBg = card.BackgroundColor3
		local hoverBg = if entry.unlocked then Theme.BG_ELEVATED else Theme.BG_SURFACE
		card.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				TweenService:Create(card, TweenInfo.new(0.12), {
					BackgroundColor3 = hoverBg,
				}):Play()
			end
		end)
		card.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				TweenService:Create(card, TweenInfo.new(0.12), {
					BackgroundColor3 = baseBg,
				}):Play()
			end
		end)
	end
end

-- ===== DATA UPDATES =====

function TitleCollectionUI:applyTitleUpdatePayload(data: {[string]: any})
	if type(data.titleCatalog) == "table" then
		self.titleCatalog = cloneEntryList(data.titleCatalog)
	elseif type(data.unlockedTitles) == "table" then
		local fallbackCatalog = cloneEntryList(data.unlockedTitles)
		for _, entry in ipairs(fallbackCatalog) do
			entry.unlocked = true
		end
		self.titleCatalog = fallbackCatalog
	end

	if data.activeTitle == nil then
		self.activeTitle = nil
	else
		self.activeTitle = cloneEntry(data.activeTitle)
	end

	if self.activeTab == TAB_TITLES then
		self:updateActiveBanner()
		self:rebuildEntries()
	end
end

function TitleCollectionUI:applyTrailUpdatePayload(data: {[string]: any})
	if type(data.trailCatalog) == "table" then
		self.trailCatalog = cloneEntryList(data.trailCatalog)
	elseif type(data.unlockedTrails) == "table" then
		local fallbackCatalog = cloneEntryList(data.unlockedTrails)
		for _, entry in ipairs(fallbackCatalog) do
			entry.unlocked = true
		end
		self.trailCatalog = fallbackCatalog
	end

	if data.activeTrail == nil then
		self.activeTrail = nil
	else
		self.activeTrail = cloneEntry(data.activeTrail)
	end

	if self.activeTab == TAB_TRAILS then
		self:updateActiveBanner()
		self:rebuildEntries()
	end
end

function TitleCollectionUI:setupRemotes()
	self.remotes.TitleUpdate.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end

		self:applyTitleUpdatePayload(data)
	end)

	self.remotes.TrailUpdate.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end

		self:applyTrailUpdatePayload(data)
	end)
end

-- ===== SHOW / HIDE =====

function TitleCollectionUI:show()
	if self.isVisible then
		return
	end

	self.isVisible = true
	self.container.Visible = true
	self.container.BackgroundTransparency = 1

	TweenService:Create(self.container, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.02,
	}):Play()
end

function TitleCollectionUI:hide()
	if not self.isVisible then
		return
	end

	self.isVisible = false

	if self.callbacks and self.callbacks.onHide then
		self.callbacks.onHide()
	end

	local tween = TweenService:Create(self.container, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	})
	tween:Play()

	tween.Completed:Connect(function()
		if not self.isVisible then
			self.container.Visible = false
		end
	end)
end

function TitleCollectionUI:toggle()
	if self.isVisible then
		self:hide()
	else
		self:show()
	end
end

return TitleCollectionUI
