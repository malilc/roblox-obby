-- ShopUI: Shop popup with Items tab + Class Gacha tab

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemTypes = require(ReplicatedStorage.Shared.ItemTypes)
local ClassTypes = require(ReplicatedStorage.Shared.ClassTypes)
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)
local RemoteRegistry = require(ReplicatedStorage.Shared.RemoteRegistry)

local ShopUI = {}
ShopUI.__index = ShopUI

-- ========== CARD COLOR HELPERS ==========

local CARD_BG_COLORS = {
	Common   = Color3.fromRGB(50, 50, 70),
	Uncommon = Color3.fromRGB(25, 65, 45),
	Rare     = Color3.fromRGB(25, 45, 80),
	Epic     = Color3.fromRGB(60, 25, 80),
}

local BADGE_BG_COLORS = {
	Common   = Color3.fromRGB(80, 80, 100),
	Uncommon = Color3.fromRGB(40, 100, 60),
	Rare     = Color3.fromRGB(40, 65, 120),
	Epic     = Color3.fromRGB(90, 40, 120),
}

local PRICE_BTN_COLORS = {
	Common   = Color3.fromRGB(120, 120, 140),
	Uncommon = Color3.fromRGB(55, 175, 75),
	Rare     = Color3.fromRGB(60, 125, 215),
	Epic     = Color3.fromRGB(165, 65, 195),
}

function ShopUI.new(parent: ScreenGui, callbacks: {onShow: (() -> ())?}?)
	local self = setmetatable({}, ShopUI)
	self.parent = parent
	self.isVisible = false
	self.callbacks = callbacks or {}
	self.activeTab = "Items"
	self.itemButtons = {} :: {[string]: {btn: TextButton, label: TextLabel}}
	self.isGachaPending = false

	-- Player state (synced from server)
	self.playerCurrency = 0
	self.playerGems = 0
	self.unlockedClasses = {}
	self.itemSlots = {nil, nil}

	-- Remotes
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	self.showRemote = remotes:WaitForChild("ShowShop")
	self.hideRemote = remotes:WaitForChild("HideShop")
	self.buyShopItemRemote = remotes:WaitForChild("BuyShopItem")
	self.gachaClassPullRemote = remotes:WaitForChild("GachaClassPull")
	self.shopUpdateRemote = remotes:WaitForChild("ShopUpdate")

	self:createUI()
	self:setupRemotes()

	return self
end

-- ========== HELPERS ==========

local function createGradient(parent: GuiObject, color1: Color3, color2: Color3)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color1),
		ColorSequenceKeypoint.new(1, color2),
	})
	gradient.Rotation = 45
	gradient.Parent = parent
	return gradient
end

local function countItems(): number
	local count = 0
	for _ in pairs(ItemTypes.Items) do
		count += 1
	end
	return count
end

local function countClasses(): number
	return #ClassTypes.ClassOrder
end

-- ========== CREATE UI ==========

function ShopUI:createUI()
	-- Main frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "ShopFrame"
	mainFrame.Size = UDim2.new(0, 780, 0, 560)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainFrame.BackgroundColor3 = Color3.fromRGB(30, 22, 55)
	mainFrame.BackgroundTransparency = 0.02
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = self.parent
	self.mainFrame = mainFrame

	Theme.applyCorner(mainFrame, "lg")

	local borderStroke = Instance.new("UIStroke")
	borderStroke.Color = Theme.ACCENT_CYAN
	borderStroke.Thickness = Theme.STROKE_BOLD
	borderStroke.Transparency = 0.4
	borderStroke.Parent = mainFrame

	-- ===== HEADER ROW (Y: 0-55) =====
	self:createHeader(mainFrame)

	-- ===== TAB BAR (Y: 58-108) =====
	self:createTabBar(mainFrame)

	-- ===== RARITY LEGEND (Y: 115-135) =====
	self:createRarityLegend(mainFrame)

	-- ===== ITEMS CONTENT (Y: 140 to bottom-40) =====
	self:createItemsContent(mainFrame)

	-- ===== CLASSES CONTENT (gacha) =====
	self:createClassesContent(mainFrame)

	-- Status label (bottom)
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -40, 0, 24)
	statusLabel.Position = UDim2.new(0, 20, 1, -32)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.TextColor3 = Theme.TEXT_MUTED
	statusLabel.TextSize = 12
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextTransparency = 1
	statusLabel.Parent = mainFrame
	self.statusLabel = statusLabel

	-- Default tab
	self:switchTab("Items")
end

-- ========== HEADER ==========

function ShopUI:createHeader(parent: Frame)
	-- Cart icon + SHOP title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0, 200, 0, 40)
	title.Position = UDim2.new(0, 22, 0, 10)
	title.BackgroundTransparency = 1
	title.RichText = true
	title.Text = '<font size="20">\u{1F6D2}</font>  <font face="GothamBold" size="24"><b>SHOP</b></font>'
	title.TextColor3 = Theme.TEXT_PRIMARY
	title.TextSize = 24
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = parent

	-- Currency displays (top right)
	self:createCurrencyDisplays(parent)

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -50, 0, 12)
	closeBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 75)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = ""
	closeBtn.Parent = parent
	Theme.applyCorner(closeBtn, "sm")

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = Theme.TEXT_MUTED
	closeStroke.Thickness = 1
	closeStroke.Transparency = 0.5
	closeStroke.Parent = closeBtn

	local closeBtnLabel = Instance.new("TextLabel")
	closeBtnLabel.Size = UDim2.new(1, 0, 1, 0)
	closeBtnLabel.BackgroundTransparency = 1
	closeBtnLabel.Text = "X"
	closeBtnLabel.TextColor3 = Theme.TEXT_MUTED
	closeBtnLabel.TextSize = 18
	closeBtnLabel.Font = Enum.Font.GothamBold
	closeBtnLabel.ZIndex = closeBtn.ZIndex + 1
	closeBtnLabel.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		self:hide()
	end)
end

-- ========== CURRENCY DISPLAYS ==========

function ShopUI:createCurrencyDisplays(parent: Frame)
	-- Coin display pill
	local coinDisplay = Instance.new("Frame")
	coinDisplay.Name = "CoinDisplay"
	coinDisplay.Size = UDim2.new(0, 130, 0, 34)
	coinDisplay.Position = UDim2.new(1, -238, 0, 13)
	coinDisplay.BackgroundColor3 = Color3.fromRGB(40, 30, 65)
	coinDisplay.BorderSizePixel = 0
	coinDisplay.Parent = parent
	Theme.applyCorner(coinDisplay, "full")

	local coinStroke = Instance.new("UIStroke")
	coinStroke.Color = Theme.HUD_CURRENCY_START
	coinStroke.Thickness = 2
	coinStroke.Transparency = 0.1
	coinStroke.Parent = coinDisplay

	-- Coin icon circle
	local coinIconBg = Instance.new("Frame")
	coinIconBg.Size = UDim2.new(0, 26, 0, 26)
	coinIconBg.Position = UDim2.new(0, 4, 0.5, -13)
	coinIconBg.BackgroundColor3 = Theme.HUD_CURRENCY_START
	coinIconBg.BorderSizePixel = 0
	coinIconBg.Parent = coinDisplay
	Theme.applyCorner(coinIconBg, "full")

	local coinIcon = Instance.new("TextLabel")
	coinIcon.Size = UDim2.new(1, 0, 1, 0)
	coinIcon.BackgroundTransparency = 1
	coinIcon.Text = "$"
	coinIcon.TextColor3 = Color3.fromRGB(40, 30, 10)
	coinIcon.TextSize = 16
	coinIcon.Font = Enum.Font.GothamBold
	coinIcon.Parent = coinIconBg

	local coinLabel = Instance.new("TextLabel")
	coinLabel.Name = "CoinLabel"
	coinLabel.Size = UDim2.new(1, -38, 1, 0)
	coinLabel.Position = UDim2.new(0, 34, 0, 0)
	coinLabel.BackgroundTransparency = 1
	coinLabel.Text = "0"
	coinLabel.TextColor3 = Theme.TEXT_PRIMARY
	coinLabel.TextSize = 16
	coinLabel.Font = Enum.Font.GothamBold
	coinLabel.TextXAlignment = Enum.TextXAlignment.Left
	coinLabel.Parent = coinDisplay
	self.coinLabel = coinLabel

	-- Gem display pill
	local gemDisplay = Instance.new("Frame")
	gemDisplay.Name = "GemDisplay"
	gemDisplay.Size = UDim2.new(0, 90, 0, 34)
	gemDisplay.Position = UDim2.new(1, -100, 0, 13)
	gemDisplay.BackgroundColor3 = Color3.fromRGB(40, 30, 65)
	gemDisplay.BorderSizePixel = 0
	gemDisplay.Parent = parent
	Theme.applyCorner(gemDisplay, "full")

	local gemStroke = Instance.new("UIStroke")
	gemStroke.Color = Theme.ACCENT_CYAN
	gemStroke.Thickness = 2
	gemStroke.Transparency = 0.2
	gemStroke.Parent = gemDisplay

	local gemIcon = Instance.new("TextLabel")
	gemIcon.Size = UDim2.new(0, 28, 1, 0)
	gemIcon.Position = UDim2.new(0, 6, 0, 0)
	gemIcon.BackgroundTransparency = 1
	gemIcon.Text = "\u{1F48E}"
	gemIcon.TextSize = 16
	gemIcon.Parent = gemDisplay

	local gemLabel = Instance.new("TextLabel")
	gemLabel.Name = "GemLabel"
	gemLabel.Size = UDim2.new(1, -38, 1, 0)
	gemLabel.Position = UDim2.new(0, 34, 0, 0)
	gemLabel.BackgroundTransparency = 1
	gemLabel.Text = "0"
	gemLabel.TextColor3 = Theme.TEXT_PRIMARY
	gemLabel.TextSize = 16
	gemLabel.Font = Enum.Font.GothamBold
	gemLabel.TextXAlignment = Enum.TextXAlignment.Left
	gemLabel.Parent = gemDisplay
	self.gemLabel = gemLabel
end

-- ========== TAB BAR ==========

function ShopUI:createTabBar(parent: Frame)
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, -44, 0, 42)
	tabBar.Position = UDim2.new(0, 22, 0, 58)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = parent

	self.tabButtons = {}
	self.tabStrokes = {}
	self.tabBadges = {}

	local tabDefs = {
		{ name = "Items",   icon = "\u{1F3AF}", count = countItems(),   color = Theme.PRIMARY },
		{ name = "Classes", icon = "\u{2694}\u{FE0F}",  count = countClasses(), color = Theme.HUD_GEM_START },
	}

	local tabWidth = math.floor((780 - 44 - 12) / 2) -- half width minus gap

	for idx, tabDef in ipairs(tabDefs) do
		local tab = Instance.new("TextButton")
		tab.Name = "Tab_" .. tabDef.name
		tab.Size = UDim2.new(0, tabWidth, 0, 42)
		tab.Position = UDim2.new(0, (idx - 1) * (tabWidth + 12), 0, 0)
		tab.BackgroundColor3 = tabDef.color
		tab.BackgroundTransparency = 0.85
		tab.BorderSizePixel = 0
		tab.Text = ""
		tab.AutoButtonColor = false
		tab.Parent = tabBar
		Theme.applyCorner(tab, "sm")

		-- Tab content (icon + text + badge) via TextLabel
		local tabContent = Instance.new("TextLabel")
		tabContent.Name = "Content"
		tabContent.Size = UDim2.new(1, -60, 1, 0)
		tabContent.Position = UDim2.new(0, 10, 0, 0)
		tabContent.BackgroundTransparency = 1
		tabContent.Text = tabDef.icon .. "  " .. tabDef.name
		tabContent.TextColor3 = Theme.TEXT_PRIMARY
		tabContent.TextSize = 16
		tabContent.Font = Enum.Font.GothamBold
		tabContent.TextXAlignment = Enum.TextXAlignment.Center
		tabContent.Parent = tab

		-- Count badge
		local badge = Instance.new("Frame")
		badge.Name = "Badge"
		badge.Size = UDim2.new(0, 24, 0, 24)
		badge.Position = UDim2.new(1, -36, 0.5, -12)
		badge.BackgroundColor3 = Color3.fromRGB(60, 50, 90)
		badge.BorderSizePixel = 0
		badge.Parent = tab
		Theme.applyCorner(badge, "full")

		local badgeLabel = Instance.new("TextLabel")
		badgeLabel.Size = UDim2.new(1, 0, 1, 0)
		badgeLabel.BackgroundTransparency = 1
		badgeLabel.Text = tostring(tabDef.count)
		badgeLabel.TextColor3 = Theme.TEXT_MUTED
		badgeLabel.TextSize = 12
		badgeLabel.Font = Enum.Font.GothamBold
		badgeLabel.Parent = badge

		tab.MouseButton1Click:Connect(function()
			self:switchTab(tabDef.name)
		end)

		self.tabButtons[tabDef.name] = tab
		self.tabBadges[tabDef.name] = badge
	end
end

function ShopUI:switchTab(tabName: string)
	self.activeTab = tabName

	local tabColors = {
		Items = Theme.PRIMARY,
		Classes = Theme.HUD_GEM_START,
	}

	for name, tab in pairs(self.tabButtons) do
		local badge = self.tabBadges[name]
		if name == tabName then
			TweenService:Create(tab, TweenInfo.new(0.15), { BackgroundTransparency = 0.05 }):Play()
			if badge then
				badge.BackgroundColor3 = Color3.fromRGB(90, 75, 30)
			end
		else
			TweenService:Create(tab, TweenInfo.new(0.15), { BackgroundTransparency = 0.85 }):Play()
			if badge then
				badge.BackgroundColor3 = Color3.fromRGB(60, 50, 90)
			end
		end
	end

	if self.itemsContent then
		self.itemsContent.Visible = (tabName == "Items")
	end
	if self.rarityLegend then
		self.rarityLegend.Visible = (tabName == "Items")
	end
	if self.classesContent then
		self.classesContent.Visible = (tabName == "Classes")
	end
end

-- ========== RARITY LEGEND ==========

function ShopUI:createRarityLegend(parent: Frame)
	local legend = Instance.new("Frame")
	legend.Name = "RarityLegend"
	legend.Size = UDim2.new(1, -44, 0, 20)
	legend.Position = UDim2.new(0, 22, 0, 108)
	legend.BackgroundTransparency = 1
	legend.Parent = parent
	self.rarityLegend = legend

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 16)
	layout.Parent = legend

	local rarities = {
		{ name = "Common",   color = Theme.RARITY_COMMON },
		{ name = "Uncommon", color = Theme.RARITY_UNCOMMON },
		{ name = "Rare",     color = Theme.RARITY_RARE },
		{ name = "Epic",     color = Theme.RARITY_EPIC },
	}

	for _, r in ipairs(rarities) do
		local entry = Instance.new("Frame")
		entry.Name = r.name
		entry.Size = UDim2.new(0, 90, 0, 18)
		entry.BackgroundTransparency = 1
		entry.Parent = legend

		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 10, 0, 10)
		dot.Position = UDim2.new(0, 0, 0.5, -5)
		dot.BackgroundColor3 = r.color
		dot.BorderSizePixel = 0
		dot.Parent = entry
		Theme.applyCorner(dot, "full")

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -16, 1, 0)
		label.Position = UDim2.new(0, 16, 0, 0)
		label.BackgroundTransparency = 1
		label.Text = r.name
		label.TextColor3 = Theme.TEXT_MUTED
		label.TextSize = 12
		label.Font = Enum.Font.Gotham
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = entry
	end
end

-- ========== ITEMS TAB ==========

function ShopUI:createItemsContent(parent: Frame)
	local content = Instance.new("ScrollingFrame")
	content.Name = "ItemsContent"
	content.Size = UDim2.new(1, -44, 1, -175)
	content.Position = UDim2.new(0, 22, 0, 135)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 4
	content.ScrollBarImageColor3 = Theme.ACCENT_CYAN
	content.Parent = parent
	self.itemsContent = content

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 225, 0, 270)
	grid.CellPadding = UDim2.new(0, 14, 0, 14)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = content

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 5)
	padding.Parent = content

	-- Sort items by rarity
	local rarityOrder = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4 }
	local allItems = {}
	for _, item in pairs(ItemTypes.Items) do
		table.insert(allItems, item)
	end
	table.sort(allItems, function(a, b)
		return (rarityOrder[a.rarity] or 99) < (rarityOrder[b.rarity] or 99)
	end)

	for layoutOrder, itemDef in ipairs(allItems) do
		self:createItemCard(content, itemDef, layoutOrder)
	end

	-- Update canvas size
	grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		content.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 15)
	end)
end

function ShopUI:createItemCard(parent: ScrollingFrame, itemDef: any, layoutOrder: number)
	local rarityColor = Theme.rarityColor(itemDef.rarity)
	local price = Config.Shop.ItemPrices[itemDef.rarity] or 999
	local cardBg = CARD_BG_COLORS[itemDef.rarity] or Color3.fromRGB(50, 50, 70)
	local badgeBg = BADGE_BG_COLORS[itemDef.rarity] or Color3.fromRGB(80, 80, 100)
	local priceBtnColor = PRICE_BTN_COLORS[itemDef.rarity] or Color3.fromRGB(120, 120, 140)

	-- Card frame
	local card = Instance.new("Frame")
	card.Name = "ItemCard_" .. itemDef.id
	card.BackgroundColor3 = cardBg
	card.BorderSizePixel = 0
	card.LayoutOrder = layoutOrder
	card.Parent = parent
	Theme.applyCorner(card, "md")

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = rarityColor
	cardStroke.Thickness = 1.5
	cardStroke.Transparency = 0.6
	cardStroke.Parent = card

	-- Rarity badge (top right)
	local badgeFrame = Instance.new("Frame")
	badgeFrame.Name = "RarityBadge"
	badgeFrame.Size = UDim2.new(0, 90, 0, 22)
	badgeFrame.Position = UDim2.new(1, -98, 0, 8)
	badgeFrame.BackgroundColor3 = badgeBg
	badgeFrame.BorderSizePixel = 0
	badgeFrame.Parent = card
	Theme.applyCorner(badgeFrame, "full")

	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = rarityColor
	badgeStroke.Thickness = 1
	badgeStroke.Transparency = 0.4
	badgeStroke.Parent = badgeFrame

	local badgeLabel = Instance.new("TextLabel")
	badgeLabel.Size = UDim2.new(1, 0, 1, 0)
	badgeLabel.BackgroundTransparency = 1
	badgeLabel.Text = string.upper(itemDef.rarity)
	badgeLabel.TextColor3 = rarityColor
	badgeLabel.TextSize = 10
	badgeLabel.Font = Enum.Font.GothamBold
	badgeLabel.Parent = badgeFrame

	-- Large icon (centered)
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(1, 0, 0, 70)
	icon.Position = UDim2.new(0, 0, 0, 35)
	icon.BackgroundTransparency = 1
	icon.Text = itemDef.icon
	icon.TextSize = 50
	icon.Parent = card

	-- Item name (centered, bold)
	local name = Instance.new("TextLabel")
	name.Name = "ItemName"
	name.Size = UDim2.new(1, -16, 0, 24)
	name.Position = UDim2.new(0, 8, 0, 110)
	name.BackgroundTransparency = 1
	name.Text = itemDef.name
	name.TextColor3 = Theme.TEXT_PRIMARY
	name.TextSize = 18
	name.Font = Enum.Font.GothamBold
	name.Parent = card

	-- Description (centered, muted)
	local desc = Instance.new("TextLabel")
	desc.Name = "Description"
	desc.Size = UDim2.new(1, -24, 0, 52)
	desc.Position = UDim2.new(0, 12, 0, 138)
	desc.BackgroundTransparency = 1
	desc.Text = itemDef.description
	desc.TextColor3 = Theme.TEXT_MUTED
	desc.TextSize = 12
	desc.Font = Enum.Font.Gotham
	desc.TextWrapped = true
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.Parent = card

	-- Price button (bottom)
	local buyBtn = Instance.new("TextButton")
	buyBtn.Name = "BuyBtn"
	buyBtn.Size = UDim2.new(1, -24, 0, 36)
	buyBtn.Position = UDim2.new(0, 12, 1, -48)
	buyBtn.BackgroundTransparency = 1
	buyBtn.Text = ""
	buyBtn.Parent = card

	local buyBg = Instance.new("Frame")
	buyBg.Name = "BuyBg"
	buyBg.Size = UDim2.new(1, 0, 1, 0)
	buyBg.BackgroundColor3 = priceBtnColor
	buyBg.BorderSizePixel = 0
	buyBg.Parent = buyBtn
	Theme.applyCorner(buyBg, "full")

	-- Coin icon in price button
	local priceIconBg = Instance.new("Frame")
	priceIconBg.Size = UDim2.new(0, 24, 0, 24)
	priceIconBg.Position = UDim2.new(0.5, -38, 0.5, -12)
	priceIconBg.BackgroundColor3 = Theme.HUD_CURRENCY_START
	priceIconBg.BorderSizePixel = 0
	priceIconBg.ZIndex = buyBg.ZIndex + 1
	priceIconBg.Parent = buyBtn
	Theme.applyCorner(priceIconBg, "full")

	local priceIcon = Instance.new("TextLabel")
	priceIcon.Size = UDim2.new(1, 0, 1, 0)
	priceIcon.BackgroundTransparency = 1
	priceIcon.Text = "$"
	priceIcon.TextColor3 = Color3.fromRGB(40, 30, 10)
	priceIcon.TextSize = 14
	priceIcon.Font = Enum.Font.GothamBold
	priceIcon.ZIndex = buyBg.ZIndex + 2
	priceIcon.Parent = priceIconBg

	local buyLabel = Instance.new("TextLabel")
	buyLabel.Name = "BuyLabel"
	buyLabel.Size = UDim2.new(0.5, 0, 1, 0)
	buyLabel.Position = UDim2.new(0.5, -10, 0, 0)
	buyLabel.BackgroundTransparency = 1
	buyLabel.Text = tostring(price)
	buyLabel.TextColor3 = Theme.TEXT_PRIMARY
	buyLabel.TextSize = 18
	buyLabel.Font = Enum.Font.GothamBold
	buyLabel.TextXAlignment = Enum.TextXAlignment.Left
	buyLabel.ZIndex = buyBg.ZIndex + 1
	buyLabel.Parent = buyBtn

	buyBtn.MouseButton1Click:Connect(function()
		self:onBuyItem(itemDef.id)
	end)

	-- Hover effect
	buyBtn.MouseEnter:Connect(function()
		TweenService:Create(cardStroke, TweenInfo.new(0.1), { Transparency = 0.1, Thickness = 2.5 }):Play()
	end)

	buyBtn.MouseLeave:Connect(function()
		TweenService:Create(cardStroke, TweenInfo.new(0.1), { Transparency = 0.6, Thickness = 1.5 }):Play()
	end)

	-- Card hover effect
	card.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			TweenService:Create(cardStroke, TweenInfo.new(0.1), { Transparency = 0.1, Thickness = 2.5 }):Play()
		end
	end)

	card.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			TweenService:Create(cardStroke, TweenInfo.new(0.1), { Transparency = 0.6, Thickness = 1.5 }):Play()
		end
	end)

	self.itemButtons[itemDef.id] = {
		btn = buyBtn,
		bg = buyBg,
		label = buyLabel,
		priceIconBg = priceIconBg,
		price = price,
		priceBtnColor = priceBtnColor,
		cardStroke = cardStroke,
	}
end

function ShopUI:onBuyItem(itemId: string)
	self.buyShopItemRemote:FireServer({ itemId = itemId })

	-- Disable button briefly
	local data = self.itemButtons[itemId]
	if data then
		data.btn.Active = false
		task.delay(0.6, function()
			if data.btn then
				data.btn.Active = true
			end
		end)
	end
end

function ShopUI:refreshItemAffordability()
	local hasSlot = (self.itemSlots[1] == nil or self.itemSlots[2] == nil)

	for _, data in pairs(self.itemButtons) do
		local canAfford = self.playerCurrency >= data.price
		local canBuy = canAfford and hasSlot

		if not hasSlot then
			data.bg.BackgroundColor3 = Theme.BG_OVERLAY
			data.label.Text = "NO SLOT"
			data.label.TextColor3 = Theme.DANGER
			data.priceIconBg.Visible = false
		elseif not canAfford then
			data.bg.BackgroundColor3 = Theme.BG_OVERLAY
			data.label.Text = tostring(data.price)
			data.label.TextColor3 = Theme.TEXT_MUTED
			data.priceIconBg.Visible = true
		else
			data.bg.BackgroundColor3 = data.priceBtnColor
			data.label.Text = tostring(data.price)
			data.label.TextColor3 = Theme.TEXT_PRIMARY
			data.priceIconBg.Visible = true
		end

		data.btn.Active = canBuy
	end
end

-- ========== CLASSES TAB (GACHA) ==========

function ShopUI:createClassesContent(parent: Frame)
	local content = Instance.new("ScrollingFrame")
	content.Name = "ClassesContent"
	content.Size = UDim2.new(1, -44, 1, -115)
	content.Position = UDim2.new(0, 22, 0, 108)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 4
	content.ScrollBarImageColor3 = Theme.HUD_GEM_START
	content.CanvasSize = UDim2.new(0, 0, 0, 520)
	content.Visible = false
	content.Parent = parent
	self.classesContent = content

	-- Title
	local gachaTitle = Instance.new("TextLabel")
	gachaTitle.Size = UDim2.new(1, 0, 0, 30)
	gachaTitle.Position = UDim2.new(0, 0, 0, 5)
	gachaTitle.BackgroundTransparency = 1
	gachaTitle.Text = "\u{1F3B0}  CLASS GACHA"
	gachaTitle.TextColor3 = Theme.TEXT_PRIMARY
	gachaTitle.TextSize = 22
	gachaTitle.Font = Enum.Font.GothamBold
	gachaTitle.Parent = content

	-- Cost label
	local costLabel = Instance.new("TextLabel")
	costLabel.Size = UDim2.new(1, 0, 0, 18)
	costLabel.Position = UDim2.new(0, 0, 0, 38)
	costLabel.BackgroundTransparency = 1
	costLabel.Text = "\u{1F48E}  " .. Config.Shop.Gacha.CostGems .. " gems per pull"
	costLabel.TextColor3 = Theme.HUD_GEM_START
	costLabel.TextSize = 14
	costLabel.Font = Enum.Font.Gotham
	costLabel.Parent = content

	-- Result card area (large mystery card)
	self:createGachaResultCard(content)

	-- PULL button (wide)
	local pullBtn = Instance.new("TextButton")
	pullBtn.Name = "PullButton"
	pullBtn.Size = UDim2.new(0.85, 0, 0, 52)
	pullBtn.Position = UDim2.new(0.075, 0, 0, 310)
	pullBtn.BackgroundTransparency = 1
	pullBtn.Text = ""
	pullBtn.Parent = content

	local pullBg = Instance.new("Frame")
	pullBg.Name = "PullBg"
	pullBg.Size = UDim2.new(1, 0, 1, 0)
	pullBg.BackgroundColor3 = Theme.HUD_GEM_START
	pullBg.BorderSizePixel = 0
	pullBg.Parent = pullBtn
	Theme.applyCorner(pullBg, "md")
	createGradient(pullBg, Theme.HUD_GEM_START, Theme.HUD_GEM_END)

	local pullStroke = Instance.new("UIStroke")
	pullStroke.Color = Theme.HUD_GLOW_GEM
	pullStroke.Thickness = 2.5
	pullStroke.Transparency = 0.2
	pullStroke.Parent = pullBg

	local pullLabel = Instance.new("TextLabel")
	pullLabel.Name = "PullLabel"
	pullLabel.Size = UDim2.new(1, 0, 1, 0)
	pullLabel.BackgroundTransparency = 1
	pullLabel.Text = "\u{1F3B2}  PULL (" .. Config.Shop.Gacha.CostGems .. " \u{1F48E})"
	pullLabel.TextColor3 = Theme.TEXT_PRIMARY
	pullLabel.TextSize = 22
	pullLabel.Font = Enum.Font.GothamBold
	pullLabel.ZIndex = pullBg.ZIndex + 1
	pullLabel.Parent = pullBtn
	self.pullLabel = pullLabel
	self.pullBg = pullBg

	pullBtn.MouseButton1Click:Connect(function()
		self:onGachaPull()
	end)
	self.pullBtn = pullBtn

	-- Gacha banner (shown after result)
	local banner = Instance.new("TextLabel")
	banner.Name = "GachaBanner"
	banner.Size = UDim2.new(0.7, 0, 0, 28)
	banner.Position = UDim2.new(0.15, 0, 0, 278)
	banner.BackgroundColor3 = Theme.SUCCESS
	banner.BackgroundTransparency = 1
	banner.BorderSizePixel = 0
	banner.Text = ""
	banner.TextColor3 = Theme.TEXT_PRIMARY
	banner.TextSize = 14
	banner.Font = Enum.Font.GothamBold
	banner.TextTransparency = 1
	banner.Parent = content
	Theme.applyCorner(banner, "sm")
	self.gachaBanner = banner

	-- Owned classes section
	self:createOwnedClassesSection(content)
end

function ShopUI:createGachaResultCard(parent: Frame)
	-- Large mystery card
	local card = Instance.new("Frame")
	card.Name = "GachaCard"
	card.Size = UDim2.new(0.85, 0, 0, 230)
	card.Position = UDim2.new(0.075, 0, 0, 65)
	card.BackgroundColor3 = Theme.BG_SURFACE
	card.BackgroundTransparency = 0.05
	card.BorderSizePixel = 0
	card.Parent = parent
	Theme.applyCorner(card, "lg")

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = Theme.BG_ELEVATED
	cardStroke.Thickness = 2
	cardStroke.Transparency = 0.3
	cardStroke.Parent = card
	self.gachaCardStroke = cardStroke

	-- Mystery "?" icon
	local cardIcon = Instance.new("TextLabel")
	cardIcon.Name = "Icon"
	cardIcon.Size = UDim2.new(1, 0, 0, 100)
	cardIcon.Position = UDim2.new(0, 0, 0, 35)
	cardIcon.BackgroundTransparency = 1
	cardIcon.Text = "?"
	cardIcon.TextSize = 72
	cardIcon.Font = Enum.Font.GothamBold
	cardIcon.TextColor3 = Theme.HUD_GEM_START
	cardIcon.Parent = card
	self.gachaCardIcon = cardIcon

	-- Placeholder text
	local cardName = Instance.new("TextLabel")
	cardName.Name = "ClassName"
	cardName.Size = UDim2.new(1, -20, 0, 24)
	cardName.Position = UDim2.new(0, 10, 0, 145)
	cardName.BackgroundTransparency = 1
	cardName.Text = "\u{0E01}\u{0E14}\u{0E2A}\u{0E38}\u{0E48}\u{0E21}\u{0E40}\u{0E1E}\u{0E37}\u{0E48}\u{0E2D}\u{0E25}\u{0E38}\u{0E49}\u{0E19}\u{0E04}\u{0E25}\u{0E32}\u{0E2A}!"
	cardName.TextColor3 = Theme.TEXT_MUTED
	cardName.TextSize = 16
	cardName.Font = Enum.Font.Gotham
	cardName.Parent = card
	self.gachaCardName = cardName

	-- Description (hidden initially, shown on reveal)
	local cardDesc = Instance.new("TextLabel")
	cardDesc.Name = "ClassDesc"
	cardDesc.Size = UDim2.new(1, -24, 0, 50)
	cardDesc.Position = UDim2.new(0, 12, 0, 170)
	cardDesc.BackgroundTransparency = 1
	cardDesc.Text = ""
	cardDesc.TextColor3 = Theme.TEXT_MUTED
	cardDesc.TextSize = 12
	cardDesc.Font = Enum.Font.Gotham
	cardDesc.TextWrapped = true
	cardDesc.TextYAlignment = Enum.TextYAlignment.Top
	cardDesc.Parent = card
	self.gachaCardDesc = cardDesc

	self.gachaCard = card
end

function ShopUI:createOwnedClassesSection(parent: Frame)
	-- Container with separator line
	local section = Instance.new("Frame")
	section.Name = "OwnedClassesSection"
	section.Size = UDim2.new(1, 0, 0, 140)
	section.Position = UDim2.new(0, 0, 0, 375)
	section.BackgroundColor3 = Color3.fromRGB(22, 16, 42)
	section.BackgroundTransparency = 0.3
	section.BorderSizePixel = 0
	section.Parent = parent
	Theme.applyCorner(section, "md")

	-- Top separator line
	local separator = Instance.new("Frame")
	separator.Size = UDim2.new(1, 0, 0, 1)
	separator.BackgroundColor3 = Theme.BG_ELEVATED
	separator.BackgroundTransparency = 0.5
	separator.BorderSizePixel = 0
	separator.Parent = section

	-- Header: lock icon + title + count
	local headerIcon = Instance.new("TextLabel")
	headerIcon.Size = UDim2.new(0, 24, 0, 24)
	headerIcon.Position = UDim2.new(0, 12, 0, 10)
	headerIcon.BackgroundTransparency = 1
	headerIcon.Text = "\u{1F513}"
	headerIcon.TextSize = 16
	headerIcon.Parent = section

	local headerTitle = Instance.new("TextLabel")
	headerTitle.Name = "HeaderTitle"
	headerTitle.Size = UDim2.new(0.6, 0, 0, 24)
	headerTitle.Position = UDim2.new(0, 36, 0, 10)
	headerTitle.BackgroundTransparency = 1
	headerTitle.Text = "\u{0E04}\u{0E25}\u{0E32}\u{0E2A}\u{0E17}\u{0E35}\u{0E48}\u{0E1B}\u{0E25}\u{0E14}\u{0E25}\u{0E47}\u{0E2D}\u{0E04}"
	headerTitle.TextColor3 = Theme.TEXT_MUTED
	headerTitle.TextSize = 14
	headerTitle.Font = Enum.Font.GothamBold
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.Parent = section

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.new(0, 60, 0, 24)
	countLabel.Position = UDim2.new(1, -72, 0, 10)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = "0 / " .. #ClassTypes.ClassOrder
	countLabel.TextColor3 = Theme.TEXT_MUTED
	countLabel.TextSize = 14
	countLabel.Font = Enum.Font.GothamBold
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.Parent = section
	self.ownedCountLabel = countLabel

	-- Class icons row
	local row = Instance.new("Frame")
	row.Name = "ClassRow"
	row.Size = UDim2.new(1, -20, 0, 90)
	row.Position = UDim2.new(0, 10, 0, 40)
	row.BackgroundTransparency = 1
	row.Parent = section

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	rowLayout.Padding = UDim.new(0, 12)
	rowLayout.Parent = row

	self.classIcons = {}

	for _, classId in ipairs(ClassTypes.ClassOrder) do
		local classDef = ClassTypes.getClass(classId)
		if not classDef then continue end

		local entry = Instance.new("Frame")
		entry.Name = "ClassEntry_" .. classId
		entry.Size = UDim2.new(0, 70, 0, 88)
		entry.BackgroundTransparency = 1
		entry.Parent = row

		-- Icon circle
		local iconFrame = Instance.new("Frame")
		iconFrame.Name = "IconFrame"
		iconFrame.Size = UDim2.new(0, 58, 0, 58)
		iconFrame.Position = UDim2.new(0.5, -29, 0, 0)
		iconFrame.BackgroundColor3 = Theme.BG_ELEVATED
		iconFrame.BackgroundTransparency = 0.2
		iconFrame.BorderSizePixel = 0
		iconFrame.Parent = entry
		Theme.applyCorner(iconFrame, "md")

		local iconStroke = Instance.new("UIStroke")
		iconStroke.Color = classDef.color
		iconStroke.Thickness = 2
		iconStroke.Transparency = 0.4
		iconStroke.Parent = iconFrame

		-- Class emoji (visible when unlocked)
		local emoji = Instance.new("TextLabel")
		emoji.Name = "Emoji"
		emoji.Size = UDim2.new(1, 0, 1, 0)
		emoji.BackgroundTransparency = 1
		emoji.Text = classDef.icon
		emoji.TextSize = 30
		emoji.Parent = iconFrame

		-- Lock overlay (visible when locked)
		local lockOverlay = Instance.new("TextLabel")
		lockOverlay.Name = "LockOverlay"
		lockOverlay.Size = UDim2.new(1, 0, 1, 0)
		lockOverlay.BackgroundTransparency = 1
		lockOverlay.Text = "\u{1F512}"
		lockOverlay.TextSize = 24
		lockOverlay.Visible = false
		lockOverlay.Parent = iconFrame

		-- Class name below
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "ClassName"
		nameLabel.Size = UDim2.new(1, 0, 0, 16)
		nameLabel.Position = UDim2.new(0, 0, 0, 62)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = classDef.name
		nameLabel.TextColor3 = Theme.TEXT_MUTED
		nameLabel.TextSize = 11
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.Parent = entry

		-- Checkmark badge (visible when unlocked)
		local checkBadge = Instance.new("Frame")
		checkBadge.Name = "CheckBadge"
		checkBadge.Size = UDim2.new(0, 18, 0, 18)
		checkBadge.Position = UDim2.new(1, -14, 0, -4)
		checkBadge.BackgroundColor3 = Theme.SUCCESS
		checkBadge.BackgroundTransparency = 0.1
		checkBadge.BorderSizePixel = 0
		checkBadge.Visible = false
		checkBadge.Parent = iconFrame
		Theme.applyCorner(checkBadge, "full")

		local checkLabel = Instance.new("TextLabel")
		checkLabel.Size = UDim2.new(1, 0, 1, 0)
		checkLabel.BackgroundTransparency = 1
		checkLabel.Text = "\u{2713}"
		checkLabel.TextColor3 = Theme.TEXT_PRIMARY
		checkLabel.TextSize = 11
		checkLabel.Font = Enum.Font.GothamBold
		checkLabel.Parent = checkBadge

		self.classIcons[classId] = {
			frame = iconFrame,
			entry = entry,
			emoji = emoji,
			lockOverlay = lockOverlay,
			nameLabel = nameLabel,
			iconStroke = iconStroke,
			checkBadge = checkBadge,
		}
	end

	self.ownedClassesSection = section
end

function ShopUI:onGachaPull()
	if self.isGachaPending then return end
	self.isGachaPending = true

	self.gachaClassPullRemote:FireServer()

	self.pullBtn.Active = false
	self.pullLabel.Text = "Pulling..."
end

function ShopUI:playGachaReveal(classId: string, isNew: boolean, gemsRefunded: number?)
	local classDef = ClassTypes.getClass(classId)
	if not classDef then
		self.isGachaPending = false
		self.pullBtn.Active = true
		self.pullLabel.Text = "\u{1F3B2}  PULL (" .. Config.Shop.Gacha.CostGems .. " \u{1F48E})"
		return
	end

	local card = self.gachaCard

	card.Visible = true
	card.Size = UDim2.new(0.85, 0, 0, 230)
	card.Position = UDim2.new(0.075, 0, 0, 65)
	card.BackgroundColor3 = Theme.BG_OVERLAY
	self.gachaCardIcon.Text = "?"
	self.gachaCardIcon.TextColor3 = Theme.HUD_GEM_START
	self.gachaCardName.Text = "..."
	self.gachaCardName.TextColor3 = Theme.TEXT_MUTED
	self.gachaCardDesc.Text = ""
	self.gachaCardStroke.Color = Theme.BG_ELEVATED

	task.delay(0.5, function()
		local flipOut = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, 230),
			Position = UDim2.new(0.5, 0, 0, 65),
		})
		flipOut:Play()

		flipOut.Completed:Connect(function()
			card.BackgroundColor3 = Theme.BG_SURFACE
			self.gachaCardIcon.Text = classDef.icon
			self.gachaCardIcon.TextColor3 = classDef.color
			self.gachaCardName.Text = classDef.name
			self.gachaCardName.TextColor3 = classDef.color
			self.gachaCardDesc.Text = classDef.description
			self.gachaCardStroke.Color = classDef.color

			local flipIn = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.new(0.85, 0, 0, 230),
				Position = UDim2.new(0.075, 0, 0, 65),
			})
			flipIn:Play()

			flipIn.Completed:Connect(function()
				TweenService:Create(self.gachaCardStroke, TweenInfo.new(0.25), { Thickness = 4, Transparency = 0 }):Play()
				task.delay(0.25, function()
					TweenService:Create(self.gachaCardStroke, TweenInfo.new(0.25), { Thickness = 2, Transparency = 0.3 }):Play()
				end)

				if isNew then
					self:showGachaBanner("NEW CLASS UNLOCKED!", Theme.SUCCESS)
				else
					local refundText = gemsRefunded and ("+" .. gemsRefunded .. " gems") or ""
					self:showGachaBanner("DUPLICATE " .. refundText, Theme.WARNING)
				end

				task.delay(2, function()
					self.isGachaPending = false
					self:refreshGachaAffordability()
					self:refreshOwnedClassDisplay()
				end)
			end)
		end)
	end)
end

function ShopUI:showGachaBanner(text: string, color: Color3)
	self.gachaBanner.Text = text
	self.gachaBanner.BackgroundColor3 = color

	TweenService:Create(self.gachaBanner, TweenInfo.new(0.2), {
		TextTransparency = 0,
		BackgroundTransparency = 0.2,
	}):Play()

	task.delay(2.5, function()
		TweenService:Create(self.gachaBanner, TweenInfo.new(0.3), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		}):Play()
	end)
end

function ShopUI:refreshGachaAffordability()
	local cost = Config.Shop.Gacha.CostGems
	local canPull = self.playerGems >= cost and not self.isGachaPending

	self.pullBtn.Active = canPull

	if self.isGachaPending then
		self.pullLabel.Text = "Pulling..."
	elseif canPull then
		self.pullLabel.Text = "\u{1F3B2}  PULL (" .. cost .. " \u{1F48E})"
	else
		self.pullLabel.Text = "Need " .. cost .. " \u{1F48E}"
	end

	if canPull then
		self.pullBg.BackgroundColor3 = Theme.HUD_GEM_START
	else
		self.pullBg.BackgroundColor3 = Theme.BG_OVERLAY
	end
end

function ShopUI:refreshOwnedClassDisplay()
	local ownedCount = 0
	local totalCount = #ClassTypes.ClassOrder

	for classId, icons in pairs(self.classIcons) do
		local isOwned = self.unlockedClasses[classId] == true

		if isOwned then
			ownedCount += 1
			-- Show emoji, hide lock
			icons.emoji.Visible = true
			icons.lockOverlay.Visible = false
			icons.checkBadge.Visible = true
			icons.frame.BackgroundTransparency = 0.1
			icons.iconStroke.Transparency = 0.2
			icons.nameLabel.TextColor3 = Theme.TEXT_PRIMARY
		else
			-- Show lock, hide emoji
			icons.emoji.Visible = false
			icons.lockOverlay.Visible = true
			icons.checkBadge.Visible = false
			icons.frame.BackgroundTransparency = 0.5
			icons.iconStroke.Color = Theme.BG_ELEVATED
			icons.iconStroke.Transparency = 0.5
			icons.nameLabel.TextColor3 = Color3.fromRGB(100, 85, 130)
		end
	end

	-- Update count label
	if self.ownedCountLabel then
		self.ownedCountLabel.Text = ownedCount .. " / " .. totalCount
	end
end

-- ========== REMOTES ==========

function ShopUI:setupRemotes()
	self.showRemote.OnClientEvent:Connect(function()
		self:show()
	end)

	self.hideRemote.OnClientEvent:Connect(function()
		self:hide()
	end)

	self.shopUpdateRemote.OnClientEvent:Connect(function(data)
		self:onShopUpdate(data)
	end)

	-- Listen for currency updates
	RemoteRegistry.get("UpdateCurrency").OnClientEvent:Connect(function(data)
		if data.currency then
			self.playerCurrency = data.currency
			self:refreshCoinDisplay()
			self:refreshItemAffordability()
		end
	end)

	RemoteRegistry.get("UpdateGems").OnClientEvent:Connect(function(data)
		if data.gems then
			self.playerGems = data.gems
			self:refreshGemDisplay()
			self:refreshGachaAffordability()
		end
	end)
end

function ShopUI:onShopUpdate(data: {[string]: any})
	if data.type == "stateSync" then
		self.playerCurrency = data.currency or 0
		self.playerGems = data.gems or 0
		self.unlockedClasses = data.unlockedClasses or {}
		self.itemSlots = data.itemSlots or {nil, nil}
		self:refreshAllDisplays()

	elseif data.type == "itemPurchase" then
		if data.success then
			self.playerCurrency = data.currency or self.playerCurrency
			if data.slot then
				self.itemSlots[data.slot] = data.itemId
			end
			self:showStatusMessage("Purchased " .. (data.itemId or "item") .. "!", Theme.SUCCESS)
			self:refreshCoinDisplay()
			self:refreshItemAffordability()
		end

	elseif data.type == "gachaResult" then
		self.playerGems = data.gems or self.playerGems
		if data.isNew and data.classId then
			self.unlockedClasses[data.classId] = true
		end
		self:refreshGemDisplay()
		self:playGachaReveal(data.classId, data.isNew, data.gemsRefunded)

	elseif data.type == "error" then
		local errorMessages = {
			INSUFFICIENT_FUNDS = "Not enough coins!",
			INSUFFICIENT_GEMS = "Not enough gems!",
			NO_EMPTY_SLOT = "Item slots full!",
			NOT_IN_LOBBY = "Only in lobby!",
			RATE_LIMIT = "Please wait...",
			INVALID_ITEM = "Invalid item.",
		}
		self:showStatusMessage(errorMessages[data.reason] or "Failed", Theme.DANGER)

		if self.isGachaPending then
			self.isGachaPending = false
			self:refreshGachaAffordability()
		end
	end
end

-- ========== DISPLAY REFRESH ==========

function ShopUI:refreshAllDisplays()
	self:refreshCoinDisplay()
	self:refreshGemDisplay()
	self:refreshItemAffordability()
	self:refreshGachaAffordability()
	self:refreshOwnedClassDisplay()
end

function ShopUI:refreshCoinDisplay()
	if self.coinLabel then
		self.coinLabel.Text = tostring(self.playerCurrency)
	end
end

function ShopUI:refreshGemDisplay()
	if self.gemLabel then
		self.gemLabel.Text = tostring(self.playerGems)
	end
end

function ShopUI:showStatusMessage(text: string, color: Color3)
	self.statusLabel.Text = text
	self.statusLabel.TextColor3 = color

	TweenService:Create(self.statusLabel, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()

	task.delay(2, function()
		TweenService:Create(self.statusLabel, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
	end)
end

-- ========== SHOW / HIDE ==========

function ShopUI:show()
	if self.isVisible then return end
	self.isVisible = true

	if self.callbacks.onShow then
		self.callbacks.onShow()
	end

	self.mainFrame.Visible = true
	self.mainFrame.BackgroundTransparency = 1

	TweenService:Create(self.mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.02,
	}):Play()
end

function ShopUI:hide()
	if not self.isVisible then return end
	self.isVisible = false

	self.isGachaPending = false

	local fadeOut = TweenService:Create(self.mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	})
	fadeOut:Play()
	fadeOut.Completed:Connect(function()
		self.mainFrame.Visible = false
	end)
end

return ShopUI
