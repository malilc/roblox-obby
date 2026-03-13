-- ClassSelectionUI: UI สำหรับเลือก/ซื้อ Character Class (List + Detail Panel)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ClassTypes = require(ReplicatedStorage.Shared.ClassTypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ClassSelectionUI = {}
ClassSelectionUI.__index = ClassSelectionUI

-- Color palette (light bright theme via ThemeConfig)
local COLORS = {
	BG_PRIMARY = Theme.BG_BASE,
	BG_CARD = Theme.BG_SURFACE,
	BG_CARD_LOCKED = Theme.BG_BASE,
	TEXT_PRIMARY = Theme.TEXT_PRIMARY,
	TEXT_SECONDARY = Theme.TEXT_MUTED,
	TEXT_ACCENT = Theme.darkenForText(Theme.ACCENT_CYAN, 0.32),
	STROKE_DEFAULT = Theme.BG_ELEVATED,
	BTN_EQUIP = Theme.SUCCESS,
	BTN_PURCHASE = Theme.PRIMARY,
	BTN_DISABLED = Theme.BG_ELEVATED,
	STATUS_EQUIPPED = Theme.SUCCESS,
	STATUS_UNLOCKED = Theme.ACCENT_CYAN,
	STATUS_CAN_BUY = Theme.WARNING,
	STATUS_LOCKED = Theme.DANGER,
	BAR_BUFF = Theme.SUCCESS,
	BAR_NERF = Theme.DANGER,
	BAR_NEUTRAL = Theme.TEXT_MUTED,
	BAR_BG = Theme.BG_ELEVATED,
	MASTERY_BAR = Theme.INFO,
	MASTERY_MAX = Theme.darkenForText(Theme.PRIMARY, 0.50),
	INDICATOR_BG = Theme.BG_SURFACE,
	INDICATOR_HOVER = Theme.BG_ELEVATED,
	TOAST_BG = Theme.BG_SURFACE,
}

-- ── Utility functions (unchanged) ──

local function cloneBooleanMap(source: {[string]: boolean}?): {[string]: boolean}
	local result = {} :: {[string]: boolean}
	if not source then
		return result
	end

	for key, value in pairs(source) do
		if value == true then
			result[key] = true
		end
	end

	return result
end

local function cloneNumberMap(source: {[string]: number}?): {[string]: number}
	local result = {} :: {[string]: number}
	if not source then
		return result
	end

	for key, value in pairs(source) do
		if type(value) == "number" then
			result[key] = value
		end
	end

	return result
end

local function cloneMasteryMap(source: {[string]: any}?): {[string]: {level: number, xp: number, xpToNext: number, isMax: boolean}}
	local result = {} :: {[string]: {level: number, xp: number, xpToNext: number, isMax: boolean}}

	for _, classId in ipairs(ClassTypes.getAllClassIds()) do
		local incoming = type(source) == "table" and source[classId] or nil

		local level = 1
		local xp = 0
		local xpToNext = 0
		local isMax = false

		if type(incoming) == "table" then
			level = math.max(1, math.floor(tonumber(incoming.level) or 1))
			xp = math.max(0, math.floor(tonumber(incoming.xp) or 0))
			xpToNext = math.max(0, math.floor(tonumber(incoming.xpToNext) or 0))
			isMax = incoming.isMax == true
		end

		result[classId] = {
			level = level,
			xp = xp,
			xpToNext = xpToNext,
			isMax = isMax,
		}
	end

	return result
end

local function buildConfiguredMasteryRewards(): {[string]: {{id: string, level: number, rewardType: string, name: string, description: string?, unlocked: boolean}}}
	local result = {} :: {[string]: {{id: string, level: number, rewardType: string, name: string, description: string?, unlocked: boolean}}}
	local configuredRewards = Config.Mastery and Config.Mastery.Rewards
	local maxLevel = math.max(1, math.floor(tonumber(Config.Mastery and Config.Mastery.MaxLevel) or 20))

	for _, classId in ipairs(ClassTypes.getAllClassIds()) do
		result[classId] = {}

		local sourceRewards = type(configuredRewards) == "table" and configuredRewards[classId] or nil
		if type(sourceRewards) == "table" then
			for index, reward in ipairs(sourceRewards) do
				if type(reward) == "table" then
					local rewardId = type(reward.id) == "string" and reward.id or string.lower(classId) .. "_reward_" .. tostring(index)
					local rewardLevel = math.clamp(math.floor(tonumber(reward.level) or 1), 1, maxLevel)
					local rewardType = type(reward.rewardType) == "string" and reward.rewardType or "Cosmetic"
					local rewardName = type(reward.name) == "string" and reward.name or (rewardType .. " Reward")
					local rewardDescription = if type(reward.description) == "string" then reward.description else nil

					table.insert(result[classId], {
						id = rewardId,
						level = rewardLevel,
						rewardType = rewardType,
						name = rewardName,
						description = rewardDescription,
						unlocked = false,
					})
				end
			end
		end

		table.sort(result[classId], function(a, b)
			if a.level == b.level then
				return a.id < b.id
			end
			return a.level < b.level
		end)
	end

	return result
end

local function cloneMasteryRewardsMap(source: {[string]: any}?): {[string]: {{id: string, level: number, rewardType: string, name: string, description: string?, unlocked: boolean}}}
	local result = buildConfiguredMasteryRewards()

	for classId, rewards in pairs(result) do
		local sourceRewards = type(source) == "table" and source[classId] or nil
		if type(sourceRewards) == "table" then
			for _, sourceReward in ipairs(sourceRewards) do
				if type(sourceReward) == "table" then
					local sourceRewardId = type(sourceReward.id) == "string" and sourceReward.id or nil
					for _, currentReward in ipairs(rewards) do
						if sourceRewardId and currentReward.id == sourceRewardId then
							currentReward.unlocked = sourceReward.unlocked == true
							break
						end
					end
				end
			end
		end
	end

	return result
end

local function cloneTitleEntry(source: any): {id: string, name: string, classId: string, level: number, rarity: string, description: string?, unlocked: boolean}?
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
		unlocked = source.unlocked ~= false,
	}
end

local function cloneTitleList(source: any): {{id: string, name: string, classId: string, level: number, rarity: string, description: string?, unlocked: boolean}}
	local list = {} :: {{id: string, name: string, classId: string, level: number, rarity: string, description: string?, unlocked: boolean}}
	if type(source) ~= "table" then
		return list
	end

	for _, entry in ipairs(source) do
		local cloned = cloneTitleEntry(entry)
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

-- ── Constructor ──

function ClassSelectionUI.new(parent: ScreenGui, callbacks: {onOpenTitleCollection: (() -> ())?, onShow: (() -> ())?}?)
	local self = setmetatable({}, ClassSelectionUI)

	self.parent = parent
	self.isVisible = false
	self.callbacks = callbacks or {}

	self.currentClass = ClassTypes.DefaultClass
	self.selectedClass = ClassTypes.DefaultClass

	self.unlockedClasses = {[ClassTypes.DefaultClass] = true}
	if Config.Classes and type(Config.Classes.FreeClasses) == "table" then
		for classId, isFree in pairs(Config.Classes.FreeClasses) do
			if isFree == true then
				self.unlockedClasses[classId] = true
			end
		end
	end

	self.classCosts = {}
	if Config.Classes and type(Config.Classes.Costs) == "table" then
		self.classCosts = cloneNumberMap(Config.Classes.Costs)
	end

	self.currency = 0
	self.classMastery = cloneMasteryMap(nil)
	self.classMasteryRewards = cloneMasteryRewardsMap(nil)
	self.titleCatalog = {}
	self.unlockedTitles = {}
	self.activeTitle = nil
	self.classButtons = {}
	self.remotes = Remotes

	self:createUI()
	self:setupRemotes()
	self:refreshClassStates()

	return self
end

function ClassSelectionUI:getOrderedClassIds(): {string}
	if type(ClassTypes.ClassOrder) == "table" then
		return ClassTypes.ClassOrder
	end
	return ClassTypes.getAllClassIds()
end

function ClassSelectionUI:isClassUnlocked(classId: string): boolean
	return self.unlockedClasses[classId] == true
end

function ClassSelectionUI:getClassCost(classId: string): number
	return self.classCosts[classId] or 0
end

function ClassSelectionUI:isClassAffordable(classId: string): boolean
	local cost = self:getClassCost(classId)
	return self.currency >= cost
end

-- ── UI Creation (List + Detail Panel layout) ──

function ClassSelectionUI:createUI()
	-- Main container (initially hidden)
	local container = Instance.new("Frame")
	container.Name = "ClassSelectionContainer"
	container.Size = UDim2.new(0, 720, 0, 480)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundColor3 = COLORS.BG_PRIMARY
	container.BackgroundTransparency = 0.02
	container.BorderSizePixel = 0
	container.Visible = false
	container.Parent = self.parent
	self.container = container

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = Theme.CORNER_LG
	containerCorner.Parent = container

	-- Gradient background
	local containerGrad = Instance.new("UIGradient")
	containerGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.PANEL_GRAD_TOP),
		ColorSequenceKeypoint.new(1, Theme.PANEL_GRAD_BTM),
	})
	containerGrad.Rotation = 180
	containerGrad.Parent = container

	-- Glow stroke
	local containerStroke = Instance.new("UIStroke")
	containerStroke.Color = Theme.ACCENT_CYAN
	containerStroke.Thickness = Theme.STROKE_MED
	containerStroke.Transparency = 0.5
	containerStroke.Parent = container

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

	-- Header row
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(0, 300, 0, 40)
	header.Position = UDim2.new(0, 22, 0, 10)
	header.BackgroundTransparency = 1
	header.RichText = true
	header.Text = '<font size="20">\u{2694}</font>  <font face="GothamBold" size="24"><b>CLASSES</b></font>'
	header.TextColor3 = Theme.TEXT_PRIMARY
	header.TextSize = 24
	header.Font = Enum.Font.GothamBold
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = container

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -50, 0, 12)
	closeBtn.BackgroundColor3 = Theme.DANGER
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = ""
	closeBtn.Parent = container
	Theme.applyCorner(closeBtn, "sm")

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = Theme.DANGER
	closeStroke.Thickness = 1
	closeStroke.Transparency = 0.3
	closeStroke.Parent = closeBtn

	local closeBtnLabel = Instance.new("TextLabel")
	closeBtnLabel.Size = UDim2.new(1, 0, 1, 0)
	closeBtnLabel.BackgroundTransparency = 1
	closeBtnLabel.Text = "X"
	closeBtnLabel.TextColor3 = Theme.TEXT_ON_ACCENT
	closeBtnLabel.TextSize = 18
	closeBtnLabel.Font = Enum.Font.GothamBold
	closeBtnLabel.ZIndex = closeBtn.ZIndex + 1
	closeBtnLabel.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		self:hide()
	end)

	-- ── Left: Class List (ScrollingFrame) ──
	local classListFrame = Instance.new("ScrollingFrame")
	classListFrame.Name = "ClassListFrame"
	classListFrame.Size = UDim2.new(0, 170, 0, 360)
	classListFrame.Position = UDim2.new(0, 20, 0, 58)
	classListFrame.BackgroundColor3 = Theme.BG_OVERLAY
	classListFrame.BackgroundTransparency = 0.5
	classListFrame.BorderSizePixel = 0
	classListFrame.ScrollBarThickness = 4
	classListFrame.ScrollBarImageColor3 = Theme.TEXT_MUTED
	classListFrame.ScrollBarImageTransparency = 0.5
	classListFrame.CanvasSize = UDim2.new(0, 0, 0, 0) -- auto-sized by UIListLayout
	classListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	classListFrame.Parent = container
	Theme.applyCorner(classListFrame, "sm")

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Padding = UDim.new(0, 4)
	listLayout.Parent = classListFrame

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 4)
	listPadding.PaddingBottom = UDim.new(0, 4)
	listPadding.Parent = classListFrame

	for _, classId in ipairs(self:getOrderedClassIds()) do
		self:createClassListItem(classListFrame, classId)
	end

	-- ── Right: Detail Panel ──
	self:createDetailPanel(container)

	-- ── Bottom: Confirm button (full-width) ──
	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Name = "ConfirmButton"
	confirmBtn.Size = UDim2.new(1, -48, 0, 50)
	confirmBtn.Position = UDim2.new(0.5, 0, 1, -56)
	confirmBtn.AnchorPoint = Vector2.new(0.5, 0)
	confirmBtn.BackgroundTransparency = 1
	confirmBtn.BorderSizePixel = 0
	confirmBtn.Text = ""
	confirmBtn.Parent = container
	self.confirmButton = confirmBtn

	-- Gradient background frame
	local confirmBg = Instance.new("Frame")
	confirmBg.Name = "ConfirmBg"
	confirmBg.Size = UDim2.new(1, 0, 1, 0)
	confirmBg.BackgroundColor3 = Color3.new(1, 1, 1)
	confirmBg.BorderSizePixel = 0
	confirmBg.Parent = confirmBtn
	self.confirmBg = confirmBg

	Theme.applyCorner(confirmBg, "md")

	local confirmGradient = Instance.new("UIGradient")
	confirmGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 110, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 75, 40)),
	})
	confirmGradient.Rotation = 0
	confirmGradient.Parent = confirmBg
	self.confirmGradient = confirmGradient

	local confirmStroke = Instance.new("UIStroke")
	confirmStroke.Color = Color3.fromRGB(80, 190, 110)
	confirmStroke.Thickness = Theme.STROKE_THIN
	confirmStroke.Transparency = 0.3
	confirmStroke.Parent = confirmBg
	self.confirmStroke = confirmStroke

	-- Text label on top of gradient
	local confirmText = Instance.new("TextLabel")
	confirmText.Name = "ConfirmText"
	confirmText.Size = UDim2.new(1, 0, 1, 0)
	confirmText.BackgroundTransparency = 1
	confirmText.Text = "EQUIP"
	confirmText.TextColor3 = Theme.TEXT_ON_ACCENT
	confirmText.TextSize = 18
	confirmText.Font = Enum.Font.GothamBold
	confirmText.ZIndex = confirmBg.ZIndex + 1
	confirmText.Parent = confirmBtn
	self.confirmText = confirmText

	confirmBtn.MouseButton1Click:Connect(function()
		self:confirmSelection()
	end)

	if not (self.callbacks and self.callbacks.hideIndicator) then
		self:createCurrentClassIndicator()
	end
end

-- ── Class List Item (left sidebar) ──

function ClassSelectionUI:createClassListItem(parent: ScrollingFrame, classId: string)
	local classDef = ClassTypes.getClass(classId)
	if not classDef then
		return
	end

	local item = Instance.new("TextButton")
	item.Name = "ClassItem_" .. classId
	item.Size = UDim2.new(1, -8, 0, 72)
	item.BackgroundColor3 = COLORS.BG_CARD
	item.BackgroundTransparency = 0
	item.BorderSizePixel = 0
	item.Text = ""
	item.AutoButtonColor = false
	item.Parent = parent

	Theme.applyCorner(item, "sm")

	local itemStroke = Instance.new("UIStroke")
	itemStroke.Color = COLORS.STROKE_DEFAULT
	itemStroke.Thickness = Theme.STROKE_THIN
	itemStroke.Parent = item

	-- Left accent bar (4px wide, class color — visible when selected)
	local accentBar = Instance.new("Frame")
	accentBar.Name = "AccentBar"
	accentBar.Size = UDim2.new(0, 4, 1, -8)
	accentBar.Position = UDim2.new(0, 4, 0, 4)
	accentBar.BackgroundColor3 = classDef.color
	accentBar.BackgroundTransparency = 1 -- hidden by default
	accentBar.BorderSizePixel = 0
	accentBar.Parent = item
	Theme.applyCorner(accentBar, "sm")

	-- Icon (28px)
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 28, 0, 28)
	icon.Position = UDim2.new(0, 14, 0, 8)
	icon.BackgroundTransparency = 1
	icon.Text = classDef.icon
	icon.TextSize = 22
	icon.Parent = item

	-- Class name (14px bold)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ClassName"
	nameLabel.Size = UDim2.new(1, -50, 0, 20)
	nameLabel.Position = UDim2.new(0, 46, 0, 6)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = classDef.name
	nameLabel.TextColor3 = Theme.darkenForText(classDef.color)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = item

	-- Status pill (small text below name)
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -50, 0, 16)
	statusLabel.Position = UDim2.new(0, 46, 0, 26)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.TextColor3 = COLORS.TEXT_SECONDARY
	statusLabel.TextSize = 11
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = item

	-- Equipped badge (small green pill, bottom area)
	local equippedBadge = Instance.new("TextLabel")
	equippedBadge.Name = "EquippedBadge"
	equippedBadge.Size = UDim2.new(0, 70, 0, 16)
	equippedBadge.Position = UDim2.new(0, 46, 0, 48)
	equippedBadge.BackgroundColor3 = COLORS.STATUS_EQUIPPED
	equippedBadge.BackgroundTransparency = 0.8
	equippedBadge.BorderSizePixel = 0
	equippedBadge.Text = "EQUIPPED"
	equippedBadge.TextColor3 = COLORS.STATUS_EQUIPPED
	equippedBadge.TextSize = 9
	equippedBadge.Font = Enum.Font.GothamBold
	equippedBadge.Visible = false
	equippedBadge.Parent = item
	Theme.applyCorner(equippedBadge, "sm")

	self.classButtons[classId] = {
		button = item,
		stroke = itemStroke,
		accentBar = accentBar,
		nameLabel = nameLabel,
		statusLabel = statusLabel,
		equippedBadge = equippedBadge,
		color = classDef.color,
	}

	item.MouseButton1Click:Connect(function()
		self:selectClass(classId)
	end)

	item.MouseEnter:Connect(function()
		if self.selectedClass ~= classId then
			TweenService:Create(item, TweenInfo.new(0.12), {
				BackgroundColor3 = COLORS.INDICATOR_HOVER,
			}):Play()
		end
	end)

	item.MouseLeave:Connect(function()
		if self.selectedClass ~= classId then
			local isUnlocked = self:isClassUnlocked(classId)
			local targetBg = isUnlocked and COLORS.BG_CARD or COLORS.BG_CARD_LOCKED
			TweenService:Create(item, TweenInfo.new(0.12), {
				BackgroundColor3 = targetBg,
			}):Play()
		end
	end)
end

-- ── Detail Panel (right side) ──

function ClassSelectionUI:createDetailPanel(container: Frame)
	local panel = Instance.new("Frame")
	panel.Name = "DetailPanel"
	panel.Size = UDim2.new(0, 500, 0, 360)
	panel.Position = UDim2.new(0, 200, 0, 58)
	panel.BackgroundColor3 = COLORS.BG_CARD
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.Parent = container
	self.detailPanel = panel

	Theme.applyCorner(panel, "md")
	Theme.applyStroke(panel, COLORS.STROKE_DEFAULT, "thin", 0.3)

	-- Scrollable content inside detail panel
	local content = Instance.new("ScrollingFrame")
	content.Name = "DetailContent"
	content.Size = UDim2.new(1, 0, 1, 0)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 3
	content.ScrollBarImageColor3 = Theme.TEXT_MUTED
	content.ScrollBarImageTransparency = 0.5
	content.CanvasSize = UDim2.new(0, 0, 0, 340)
	content.Parent = panel

	-- ── Section 1: Class Header (Y=12) ──
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "DetailIcon"
	iconLabel.Size = UDim2.new(0, 48, 0, 48)
	iconLabel.Position = UDim2.new(0, 20, 0, 12)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = ""
	iconLabel.TextSize = 38
	iconLabel.Parent = content
	self.detailIcon = iconLabel

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "DetailName"
	nameLabel.Size = UDim2.new(0, 300, 0, 30)
	nameLabel.Position = UDim2.new(0, 76, 0, 12)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = ""
	nameLabel.TextColor3 = COLORS.TEXT_PRIMARY
	nameLabel.TextSize = 24
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = content
	self.detailName = nameLabel

	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "DetailDescription"
	descLabel.Size = UDim2.new(1, -96, 0, 20)
	descLabel.Position = UDim2.new(0, 76, 0, 42)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = ""
	descLabel.TextColor3 = COLORS.TEXT_SECONDARY
	descLabel.TextSize = 13
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextWrapped = true
	descLabel.Parent = content
	self.detailDescription = descLabel

	-- ── Section 2: Stat Bars (Y=80) ──
	local statsY = 80
	local function createDetailStatBar(label: string, yPos: number)
		local barLabel = Instance.new("TextLabel")
		barLabel.Size = UDim2.new(0, 60, 0, 18)
		barLabel.Position = UDim2.new(0, 20, 0, yPos)
		barLabel.BackgroundTransparency = 1
		barLabel.Text = label
		barLabel.TextColor3 = COLORS.TEXT_SECONDARY
		barLabel.TextSize = 13
		barLabel.Font = Enum.Font.GothamMedium
		barLabel.TextXAlignment = Enum.TextXAlignment.Left
		barLabel.Parent = content

		local barBg = Instance.new("Frame")
		barBg.Size = UDim2.new(0, 200, 0, 12)
		barBg.Position = UDim2.new(0, 86, 0, yPos + 3)
		barBg.BackgroundColor3 = COLORS.BAR_BG
		barBg.BorderSizePixel = 0
		barBg.Parent = content
		Theme.applyCorner(barBg, "sm")

		local barFill = Instance.new("Frame")
		barFill.Size = UDim2.new(0.5, 0, 1, 0)
		barFill.BackgroundColor3 = COLORS.BAR_NEUTRAL
		barFill.BorderSizePixel = 0
		barFill.Parent = barBg
		Theme.applyCorner(barFill, "sm")

		local pctLabel = Instance.new("TextLabel")
		pctLabel.Size = UDim2.new(0, 60, 0, 18)
		pctLabel.Position = UDim2.new(0, 296, 0, yPos)
		pctLabel.BackgroundTransparency = 1
		pctLabel.Text = "0%"
		pctLabel.TextColor3 = COLORS.BAR_NEUTRAL
		pctLabel.TextSize = 13
		pctLabel.Font = Enum.Font.GothamBold
		pctLabel.TextXAlignment = Enum.TextXAlignment.Left
		pctLabel.Parent = content

		return barFill, pctLabel
	end

	self.detailSpeedBar, self.detailSpeedPct = createDetailStatBar("Speed", statsY)
	self.detailJumpBar, self.detailJumpPct = createDetailStatBar("Jump", statsY + 26)
	self.detailResistBar, self.detailResistPct = createDetailStatBar("Resist", statsY + 52)

	-- ── Section 3: Passive Ability (Y=160) ──
	local passiveName = Instance.new("TextLabel")
	passiveName.Name = "PassiveName"
	passiveName.Size = UDim2.new(1, -40, 0, 20)
	passiveName.Position = UDim2.new(0, 20, 0, 160)
	passiveName.BackgroundTransparency = 1
	passiveName.Text = ""
	passiveName.TextColor3 = Theme.darkenForText(Theme.PRIMARY, 0.50)
	passiveName.TextSize = 14
	passiveName.Font = Enum.Font.GothamBold
	passiveName.TextXAlignment = Enum.TextXAlignment.Left
	passiveName.Parent = content
	self.detailPassiveName = passiveName

	local passiveDesc = Instance.new("TextLabel")
	passiveDesc.Name = "PassiveDesc"
	passiveDesc.Size = UDim2.new(1, -40, 0, 36)
	passiveDesc.Position = UDim2.new(0, 20, 0, 182)
	passiveDesc.BackgroundTransparency = 1
	passiveDesc.Text = ""
	passiveDesc.TextColor3 = COLORS.TEXT_SECONDARY
	passiveDesc.TextSize = 12
	passiveDesc.Font = Enum.Font.Gotham
	passiveDesc.TextXAlignment = Enum.TextXAlignment.Left
	passiveDesc.TextWrapped = true
	passiveDesc.Parent = content
	self.detailPassiveDesc = passiveDesc

	-- ── Section 4: Mastery (Y=225) ──
	local masteryLabel = Instance.new("TextLabel")
	masteryLabel.Name = "MasteryLabel"
	masteryLabel.Size = UDim2.new(0, 300, 0, 20)
	masteryLabel.Position = UDim2.new(0, 20, 0, 225)
	masteryLabel.BackgroundTransparency = 1
	masteryLabel.Text = "Mastery Lv.1"
	masteryLabel.TextColor3 = COLORS.TEXT_ACCENT
	masteryLabel.TextSize = 13
	masteryLabel.Font = Enum.Font.GothamMedium
	masteryLabel.TextXAlignment = Enum.TextXAlignment.Left
	masteryLabel.Parent = content
	self.detailMasteryLabel = masteryLabel

	-- XP bar (full-width 460px)
	local xpBarBg = Instance.new("Frame")
	xpBarBg.Name = "DetailXpBarBg"
	xpBarBg.Size = UDim2.new(1, -40, 0, 8)
	xpBarBg.Position = UDim2.new(0, 20, 0, 248)
	xpBarBg.BackgroundColor3 = COLORS.BAR_BG
	xpBarBg.BorderSizePixel = 0
	xpBarBg.Parent = content
	Theme.applyCorner(xpBarBg, "sm")

	local xpBarFill = Instance.new("Frame")
	xpBarFill.Name = "DetailXpBarFill"
	xpBarFill.Size = UDim2.new(0, 0, 1, 0)
	xpBarFill.BackgroundColor3 = COLORS.MASTERY_BAR
	xpBarFill.BorderSizePixel = 0
	xpBarFill.Parent = xpBarBg
	Theme.applyCorner(xpBarFill, "sm")
	self.detailXpBarFill = xpBarFill

	-- Ultimate skill info
	local ultimateLabel = Instance.new("TextLabel")
	ultimateLabel.Name = "UltimateLabel"
	ultimateLabel.Size = UDim2.new(1, -40, 0, 20)
	ultimateLabel.Position = UDim2.new(0, 20, 0, 262)
	ultimateLabel.BackgroundTransparency = 1
	ultimateLabel.Text = ""
	ultimateLabel.TextColor3 = COLORS.TEXT_SECONDARY
	ultimateLabel.TextSize = 12
	ultimateLabel.Font = Enum.Font.GothamMedium
	ultimateLabel.TextXAlignment = Enum.TextXAlignment.Left
	ultimateLabel.Parent = content
	self.detailUltimateLabel = ultimateLabel

	-- ── Section 5: Rewards Row (Y=290) ──
	local REWARD_ICONS = {
		{type = "Skill", icon = "\xE2\x9A\xA1", suffix = "_skill_"},
		{type = "Title", icon = "\xF0\x9F\x8F\xB7\xEF\xB8\x8F", suffix = "_title_"},
		{type = "Trail", icon = "\xE2\x9C\xA8", suffix = "_trail_"},
	}

	local rewardIconLabels = {}
	local iconSize = 24
	local iconSpacing = 12
	local iconStartX = 20

	for i, rewardDef in ipairs(REWARD_ICONS) do
		local iconFrame = Instance.new("Frame")
		iconFrame.Name = "RewardSlot_" .. rewardDef.type
		iconFrame.Size = UDim2.new(0, iconSize + 50, 0, 30)
		iconFrame.Position = UDim2.new(0, iconStartX + (i - 1) * (iconSize + 50 + iconSpacing), 0, 290)
		iconFrame.BackgroundTransparency = 1
		iconFrame.Parent = content

		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.new(0, iconSize, 0, iconSize)
		iconLabel.Position = UDim2.new(0, 0, 0, 3)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = rewardDef.icon
		iconLabel.TextSize = 18
		iconLabel.TextTransparency = 0.7
		iconLabel.Parent = iconFrame

		local rewardName = Instance.new("TextLabel")
		rewardName.Size = UDim2.new(0, 50, 0, 14)
		rewardName.Position = UDim2.new(0, iconSize + 2, 0, 8)
		rewardName.BackgroundTransparency = 1
		rewardName.Text = rewardDef.type
		rewardName.TextColor3 = COLORS.TEXT_SECONDARY
		rewardName.TextSize = 10
		rewardName.Font = Enum.Font.GothamMedium
		rewardName.TextXAlignment = Enum.TextXAlignment.Left
		rewardName.Parent = iconFrame

		table.insert(rewardIconLabels, {
			label = iconLabel,
			frame = iconFrame,
			rewardType = rewardDef.type,
			suffix = rewardDef.suffix,
		})
	end
	self.detailRewardIcons = rewardIconLabels

	local rewardsCountLabel = Instance.new("TextLabel")
	rewardsCountLabel.Name = "RewardsCount"
	rewardsCountLabel.Size = UDim2.new(0, 150, 0, 16)
	rewardsCountLabel.Position = UDim2.new(1, -170, 0, 297)
	rewardsCountLabel.BackgroundTransparency = 1
	rewardsCountLabel.Text = ""
	rewardsCountLabel.TextColor3 = COLORS.TEXT_SECONDARY
	rewardsCountLabel.TextSize = 11
	rewardsCountLabel.Font = Enum.Font.GothamMedium
	rewardsCountLabel.TextXAlignment = Enum.TextXAlignment.Right
	rewardsCountLabel.Parent = content
	self.detailRewardsCount = rewardsCountLabel
end

-- ── Update Detail Panel ──

function ClassSelectionUI:updateDetailPanel()
	local classId = self.selectedClass
	local classDef = ClassTypes.getClass(classId)
	if not classDef then
		return
	end

	-- Header
	self.detailIcon.Text = classDef.icon
	self.detailName.Text = classDef.name
	self.detailName.TextColor3 = Theme.darkenForText(classDef.color)
	self.detailDescription.Text = classDef.description

	-- Stat bars
	local function updateStatBar(barFill: Frame, pctLabel: TextLabel, mod: number)
		local fillPct = math.clamp((mod - 0.70) / 0.50, 0, 1)
		local barColor = if mod > 1.0 then COLORS.BAR_BUFF elseif mod < 1.0 then COLORS.BAR_NERF else COLORS.BAR_NEUTRAL

		barFill.Size = UDim2.new(fillPct, 0, 1, 0)
		barFill.BackgroundColor3 = barColor

		local pctSign = if mod >= 1.0 then "+" else ""
		local pctText = string.format("%s%d%%", pctSign, math.floor((mod - 1) * 100))
		if mod == 1.0 then
			pctText = "0%"
		end
		pctLabel.Text = pctText
		pctLabel.TextColor3 = Theme.darkenForText(barColor, 0.55)
	end

	updateStatBar(self.detailSpeedBar, self.detailSpeedPct, classDef.walkSpeedMod)
	updateStatBar(self.detailJumpBar, self.detailJumpPct, classDef.jumpPowerMod)

	-- KB Resist — show as 0-100% scale
	if classDef.knockbackResistance > 0 then
		self.detailResistBar.Size = UDim2.new(classDef.knockbackResistance, 0, 1, 0)
		self.detailResistBar.BackgroundColor3 = COLORS.MASTERY_MAX
		self.detailResistPct.Text = string.format("%d%%", math.floor(classDef.knockbackResistance * 100))
		self.detailResistPct.TextColor3 = Theme.darkenForText(Theme.PRIMARY, 0.50)
		self.detailResistBar.Parent.Visible = true
		self.detailResistPct.Visible = true
		-- Show the label too
		local resistLabel = self.detailResistBar.Parent.Parent:FindFirstChild("Resist_Label")
		if resistLabel then resistLabel.Visible = true end
	else
		self.detailResistBar.Size = UDim2.new(0, 0, 1, 0)
		self.detailResistBar.BackgroundColor3 = COLORS.BAR_NEUTRAL
		self.detailResistPct.Text = "0%"
		self.detailResistPct.TextColor3 = COLORS.BAR_NEUTRAL
	end

	-- Passive
	self.detailPassiveName.Text = "Passive: " .. classDef.passiveAbility.name
	self.detailPassiveDesc.Text = classDef.passiveAbility.description
	if classDef.passiveAbility.cooldown then
		self.detailPassiveDesc.Text = classDef.passiveAbility.description .. string.format(" (CD %ds)", classDef.passiveAbility.cooldown)
	end

	-- Mastery
	local masteryInfo = self.classMastery[classId]
	local masteryLevel = masteryInfo and masteryInfo.level or 1
	local masteryXp = masteryInfo and masteryInfo.xp or 0
	local masteryXpToNext = masteryInfo and masteryInfo.xpToNext or 0
	local masteryIsMax = masteryInfo and masteryInfo.isMax or false

	local ultimateUnlockLevel = Config.Mastery and Config.Mastery.UltimateUnlockLevel or 20
	local hasUltimate = masteryLevel >= ultimateUnlockLevel
	local ultimateSkillConfig = Config.Mastery and Config.Mastery.UltimateSkills and Config.Mastery.UltimateSkills[classId]

	if masteryIsMax then
		if hasUltimate and ultimateSkillConfig then
			self.detailMasteryLabel.Text = string.format("\u{1F3C6} Mastery Lv.%d (MAX) \u{26A1} %s", masteryLevel, ultimateSkillConfig.name or "ULTIMATE")
		else
			self.detailMasteryLabel.Text = string.format("\u{1F3C6} Mastery Lv.%d (MAX)", masteryLevel)
		end
		self.detailMasteryLabel.TextColor3 = COLORS.MASTERY_MAX
	elseif masteryXpToNext > 0 then
		self.detailMasteryLabel.Text = string.format("\u{1F3C6} Mastery Lv.%d   %d/%d XP", masteryLevel, masteryXp, masteryXpToNext)
		self.detailMasteryLabel.TextColor3 = COLORS.TEXT_ACCENT
	else
		self.detailMasteryLabel.Text = string.format("\u{1F3C6} Mastery Lv.%d", masteryLevel)
		self.detailMasteryLabel.TextColor3 = COLORS.TEXT_ACCENT
	end

	-- XP bar
	local fillPct = 0
	if masteryIsMax then
		fillPct = 1
	elseif masteryXpToNext > 0 then
		fillPct = math.clamp(masteryXp / masteryXpToNext, 0, 1)
	end
	self.detailXpBarFill.Size = UDim2.new(fillPct, 0, 1, 0)
	self.detailXpBarFill.BackgroundColor3 = if masteryIsMax then COLORS.MASTERY_MAX else COLORS.MASTERY_BAR

	-- Skill info
	if ultimateSkillConfig then
		if hasUltimate then
			self.detailUltimateLabel.Text = string.format("\u{26A1} Skill: %s — %s", ultimateSkillConfig.name, ultimateSkillConfig.description or "")
			self.detailUltimateLabel.TextColor3 = COLORS.MASTERY_MAX
		else
			self.detailUltimateLabel.Text = string.format("\u{26A1} Skill: %s (unlock at Lv.%d)", ultimateSkillConfig.name, ultimateUnlockLevel)
			self.detailUltimateLabel.TextColor3 = COLORS.TEXT_SECONDARY
		end
	else
		self.detailUltimateLabel.Text = ""
	end

	-- Reward icons
	if self.detailRewardIcons then
		local rewards = self.classMasteryRewards[classId] or {}
		local unlockedById = {}
		local unlockedCount = 0
		for _, reward in ipairs(rewards) do
			if reward.unlocked then
				unlockedById[reward.id] = true
				unlockedCount += 1
			end
		end

		-- Check which reward types this class has
		local classRewardDefs = Config.Mastery.Rewards[classId] or {}
		local hasRewardType = {}
		for _, rd in ipairs(classRewardDefs) do
			hasRewardType[rd.rewardType] = true
		end

		local classPrefix = string.lower(classId)
		local iconSize = 24
		local iconSpacing = 12
		local iconStartX = 20
		local visibleIndex = 0

		for _, iconData in ipairs(self.detailRewardIcons) do
			local classHasThis = hasRewardType[iconData.rewardType] == true
			iconData.frame.Visible = classHasThis

			if classHasThis then
				iconData.frame.Position = UDim2.new(0, iconStartX + visibleIndex * (iconSize + 50 + iconSpacing), 0, 290)
				visibleIndex += 1

				local isRewardUnlocked = false
				for rewardId, _ in pairs(unlockedById) do
					if string.find(rewardId, classPrefix .. iconData.suffix) then
						isRewardUnlocked = true
						break
					end
				end
				iconData.label.TextTransparency = isRewardUnlocked and 0 or 0.6
			end
		end

		local totalRewards = #classRewardDefs
		self.detailRewardsCount.Text = string.format("(%d/%d unlocked)", unlockedCount, totalRewards)
	end
end

-- ── Class Indicator HUD ──

function ClassSelectionUI:createCurrentClassIndicator()
	local indicator = Instance.new("Frame")
	indicator.Name = "ClassIndicator"
	indicator.Size = UDim2.new(0, 175, 0, 42)
	indicator.Position = UDim2.new(0, 10, 0, 138)
	indicator.BackgroundColor3 = COLORS.INDICATOR_BG
	indicator.BackgroundTransparency = 0.1
	indicator.BorderSizePixel = 0
	indicator.Parent = self.parent
	self.classIndicator = indicator

	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.CornerRadius = Theme.CORNER_LG
	indicatorCorner.Parent = indicator

	-- Class-color gradient (updated dynamically in updateIndicator)
	local indicatorGradient = Instance.new("UIGradient")
	indicatorGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLORS.INDICATOR_BG),
		ColorSequenceKeypoint.new(1, COLORS.INDICATOR_BG)
	})
	indicatorGradient.Rotation = 0
	indicatorGradient.Parent = indicator
	self.indicatorGradient = indicatorGradient

	local indicatorStroke = Instance.new("UIStroke")
	indicatorStroke.Color = COLORS.STROKE_DEFAULT
	indicatorStroke.Thickness = Theme.STROKE_MED
	indicatorStroke.Transparency = 0.3
	indicatorStroke.Parent = indicator
	self.indicatorStroke = indicatorStroke

	-- Drop shadow
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 4, 1, 4)
	shadow.Position = UDim2.new(0, -2, 0, 3)
	shadow.BackgroundColor3 = Theme.CARD_SHADOW
	shadow.BackgroundTransparency = 0.7
	shadow.BorderSizePixel = 0
	shadow.ZIndex = indicator.ZIndex - 1
	shadow.Parent = indicator

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = Theme.CORNER_LG
	shadowCorner.Parent = shadow

	-- Icon
	local indicatorIcon = Instance.new("TextLabel")
	indicatorIcon.Name = "Icon"
	indicatorIcon.Size = UDim2.new(0, 32, 0, 32)
	indicatorIcon.Position = UDim2.new(0, 5, 0.5, -16)
	indicatorIcon.BackgroundTransparency = 1
	indicatorIcon.TextSize = 22
	indicatorIcon.Parent = indicator
	self.indicatorIcon = indicatorIcon

	-- Name
	local indicatorName = Instance.new("TextLabel")
	indicatorName.Name = "Name"
	indicatorName.Size = UDim2.new(0, 70, 0, 20)
	indicatorName.Position = UDim2.new(0, 36, 0, 4)
	indicatorName.BackgroundTransparency = 1
	indicatorName.TextSize = 15
	indicatorName.Font = Enum.Font.GothamBold
	indicatorName.TextXAlignment = Enum.TextXAlignment.Left
	indicatorName.Parent = indicator
	self.indicatorName = indicatorName

	-- Name text stroke
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color = Color3.fromRGB(20, 10, 40)
	nameStroke.Thickness = 1.5
	nameStroke.Transparency = 0.4
	nameStroke.Parent = indicatorName

	-- Mini XP bar
	local xpBarBg = Instance.new("Frame")
	xpBarBg.Name = "IndicatorXpBarBg"
	xpBarBg.Size = UDim2.new(0, 55, 0, 3)
	xpBarBg.Position = UDim2.new(0, 36, 0, 26)
	xpBarBg.BackgroundColor3 = Theme.BG_ELEVATED
	xpBarBg.BorderSizePixel = 0
	xpBarBg.Parent = indicator

	local xpBarBgCorner = Instance.new("UICorner")
	xpBarBgCorner.CornerRadius = UDim.new(0, 2)
	xpBarBgCorner.Parent = xpBarBg

	local xpBarFill = Instance.new("Frame")
	xpBarFill.Name = "IndicatorXpBarFill"
	xpBarFill.Size = UDim2.new(0, 0, 1, 0)
	xpBarFill.BackgroundColor3 = Theme.ACCENT_CYAN
	xpBarFill.BorderSizePixel = 0
	xpBarFill.Parent = xpBarBg

	local xpBarFillCorner = Instance.new("UICorner")
	xpBarFillCorner.CornerRadius = UDim.new(0, 2)
	xpBarFillCorner.Parent = xpBarFill

	self.indicatorXpBarFill = xpBarFill

	-- Mastery badge
	local masteryBadge = Instance.new("TextLabel")
	masteryBadge.Name = "MasteryBadge"
	masteryBadge.Size = UDim2.new(0, 44, 0, 20)
	masteryBadge.Position = UDim2.new(0, 100, 0.5, -10)
	masteryBadge.BackgroundColor3 = Theme.BG_ELEVATED
	masteryBadge.BackgroundTransparency = 0.2
	masteryBadge.BorderSizePixel = 0
	masteryBadge.Text = "Lv.1"
	masteryBadge.TextColor3 = COLORS.TEXT_ACCENT
	masteryBadge.TextSize = 11
	masteryBadge.Font = Enum.Font.GothamBold
	masteryBadge.Parent = indicator
	self.indicatorMasteryBadge = masteryBadge

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = Theme.CORNER_SM
	badgeCorner.Parent = masteryBadge

	-- Chevron
	local chevron = Instance.new("TextLabel")
	chevron.Size = UDim2.new(0, 18, 1, 0)
	chevron.Position = UDim2.new(1, -20, 0, 0)
	chevron.BackgroundTransparency = 1
	chevron.Text = ">"
	chevron.TextColor3 = Theme.TEXT_MUTED
	chevron.TextSize = 16
	chevron.Font = Enum.Font.GothamBold
	chevron.Parent = indicator

	-- Clickable overlay
	local clickButton = Instance.new("TextButton")
	clickButton.Size = UDim2.new(1, 0, 1, 0)
	clickButton.BackgroundTransparency = 1
	clickButton.Text = ""
	clickButton.Parent = indicator

	clickButton.MouseButton1Click:Connect(function()
		-- Brief scale pulse
		TweenService:Create(indicator, TweenInfo.new(0.08), {
			Size = UDim2.new(0, 180, 0, 44),
		}):Play()
		task.delay(0.08, function()
			TweenService:Create(indicator, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
				Size = UDim2.new(0, 175, 0, 42),
			}):Play()
		end)

		self:toggle()
	end)

	-- Hover effects
	clickButton.MouseEnter:Connect(function()
		TweenService:Create(indicator, TweenInfo.new(0.12), {
			BackgroundTransparency = 0.05,
		}):Play()
		TweenService:Create(self.indicatorStroke, TweenInfo.new(0.12), {
			Transparency = 0,
		}):Play()
	end)

	clickButton.MouseLeave:Connect(function()
		TweenService:Create(indicator, TweenInfo.new(0.12), {
			BackgroundTransparency = 0.1,
		}):Play()
		TweenService:Create(self.indicatorStroke, TweenInfo.new(0.12), {
			Transparency = 0.3,
		}):Play()
	end)

	self:updateIndicator(self.currentClass)
end

-- ── State Management ──

function ClassSelectionUI:setConfirmButtonState(text: string, isEnabled: boolean, btnColor: Color3?)
	if not self.confirmButton then
		return
	end

	self.confirmButton.Active = isEnabled
	if self.confirmText then
		self.confirmText.Text = text
		self.confirmText.TextColor3 = Theme.TEXT_ON_ACCENT
	end

	-- Gradient colors per state (BackgroundColor3 stays white, UIGradient does coloring)
	if self.confirmGradient then
		if isEnabled and btnColor == COLORS.BTN_PURCHASE then
			-- BUY & EQUIP — yellow gradient
			self.confirmGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 0)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 175, 0)),
			})
			if self.confirmStroke then
				self.confirmStroke.Color = Color3.fromRGB(255, 230, 80)
				self.confirmStroke.Transparency = 0.3
			end
		elseif isEnabled then
			-- EQUIP — green gradient
			self.confirmGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 200, 100)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 170, 70)),
			})
			if self.confirmStroke then
				self.confirmStroke.Color = Color3.fromRGB(80, 220, 120)
				self.confirmStroke.Transparency = 0.3
			end
		elseif text == "EQUIPPED" then
			-- EQUIPPED — dark green gradient (disabled but styled)
			self.confirmGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 110, 60)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 75, 40)),
			})
			if self.confirmStroke then
				self.confirmStroke.Color = Color3.fromRGB(80, 190, 110)
				self.confirmStroke.Transparency = 0.3
			end
		else
			-- NOT ENOUGH — dark gray gradient
			self.confirmGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.BG_SURFACE),
				ColorSequenceKeypoint.new(1, Theme.BG_OVERLAY),
			})
			if self.confirmStroke then
				self.confirmStroke.Color = COLORS.STROKE_DEFAULT
				self.confirmStroke.Transparency = 0.6
			end
		end
	end
end

function ClassSelectionUI:refreshClassStates()
	if not ClassTypes.getClass(self.selectedClass) then
		self.selectedClass = self.currentClass
	end

	-- Update currency display
	if self.currencyLabel then
		self.currencyLabel.Text = string.format("   %d", math.floor(self.currency))
	end

	for classId, buttonData in pairs(self.classButtons) do
		local isSelected = self.selectedClass == classId
		local isEquipped = self.currentClass == classId
		local isUnlocked = self:isClassUnlocked(classId)
		local isAffordable = self:isClassAffordable(classId)

		-- List item appearance
		if isSelected then
			buttonData.button.BackgroundColor3 = Theme.BG_ELEVATED
			buttonData.stroke.Color = buttonData.color
			buttonData.stroke.Thickness = Theme.STROKE_MED
			buttonData.accentBar.BackgroundTransparency = 0
		elseif isUnlocked then
			buttonData.button.BackgroundColor3 = COLORS.BG_CARD
			buttonData.stroke.Color = COLORS.STROKE_DEFAULT
			buttonData.stroke.Thickness = Theme.STROKE_THIN
			buttonData.accentBar.BackgroundTransparency = 1
		elseif isAffordable then
			buttonData.button.BackgroundColor3 = COLORS.BG_CARD_LOCKED
			buttonData.stroke.Color = Theme.WARNING
			buttonData.stroke.Thickness = Theme.STROKE_THIN
			buttonData.accentBar.BackgroundTransparency = 1
		else
			buttonData.button.BackgroundColor3 = COLORS.BG_CARD_LOCKED
			buttonData.button.BackgroundTransparency = 0.1
			buttonData.stroke.Color = Theme.DANGER
			buttonData.stroke.Thickness = Theme.STROKE_THIN
			buttonData.accentBar.BackgroundTransparency = 1
		end

		-- Status label text
		if isEquipped then
			buttonData.statusLabel.Text = "EQUIPPED"
			buttonData.statusLabel.TextColor3 = COLORS.STATUS_EQUIPPED
		elseif isUnlocked then
			buttonData.statusLabel.Text = "UNLOCKED"
			buttonData.statusLabel.TextColor3 = COLORS.STATUS_UNLOCKED
		elseif isAffordable then
			buttonData.statusLabel.Text = "CAN BUY"
			buttonData.statusLabel.TextColor3 = COLORS.STATUS_CAN_BUY
		else
			buttonData.statusLabel.Text = "LOCKED"
			buttonData.statusLabel.TextColor3 = COLORS.STATUS_LOCKED
		end

		-- Equipped badge visibility
		buttonData.equippedBadge.Visible = isEquipped

		-- Reset transparency for unlocked items
		if isUnlocked or isSelected then
			buttonData.button.BackgroundTransparency = 0
		end
	end

	-- Update detail panel for selected class
	self:updateDetailPanel()

	-- Confirm button state
	local selectedClass = self.selectedClass
	local selectedUnlocked = self:isClassUnlocked(selectedClass)
	local classDef = ClassTypes.getClass(selectedClass)
	local className = classDef and classDef.name or selectedClass

	if selectedUnlocked then
		if selectedClass == self.currentClass then
			self:setConfirmButtonState("EQUIPPED", false)
		else
			self:setConfirmButtonState("EQUIP " .. string.upper(className), true, COLORS.BTN_EQUIP)
		end
	else
		-- Class locked — gacha only, no coin purchase
		self:setConfirmButtonState("GACHA IN SHOP", false)
	end
end

-- ── Toast Notifications ──

function ClassSelectionUI:showToast(text: string, color: Color3?)
	if self.activeToast and self.activeToast.Parent then
		self.activeToast:Destroy()
	end

	local toast = Instance.new("TextLabel")
	toast.Name = "ClassToast"
	toast.AnchorPoint = Vector2.new(0, 0)
	toast.Size = UDim2.new(0, 380, 0, 38)
	toast.Position = UDim2.new(0, 10, 0, 230)  -- Below TitleHUD (which is at Y=184)
	toast.BackgroundColor3 = COLORS.TOAST_BG
	toast.BackgroundTransparency = 0.05
	toast.BorderSizePixel = 0
	toast.Text = "  " .. text
	toast.TextColor3 = color or COLORS.TEXT_PRIMARY
	toast.TextSize = 15
	toast.Font = Enum.Font.GothamBold
	toast.TextXAlignment = Enum.TextXAlignment.Left
	toast.TextTransparency = 1
	toast.ZIndex = 1  -- Low ZIndex to not overlap other UIs
	toast.Parent = self.parent
	self.activeToast = toast

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CORNER_SM
	corner.Parent = toast

	local toastStroke = Instance.new("UIStroke")
	toastStroke.Color = COLORS.STROKE_DEFAULT
	toastStroke.Thickness = Theme.STROKE_THIN
	toastStroke.Parent = toast

	TweenService:Create(toast, TweenInfo.new(0.15), {
		TextTransparency = 0,
		BackgroundTransparency = 0.05,
	}):Play()

	task.delay(1.5, function()
		if toast.Parent then
			local fade = TweenService:Create(toast, TweenInfo.new(0.25), {
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

function ClassSelectionUI:showRewardUnlockToast(className: string, unlockedRewards: {any})
	local rewardNames = {}
	for _, reward in ipairs(unlockedRewards) do
		if type(reward) == "table" and type(reward.name) == "string" then
			table.insert(rewardNames, reward.name)
		end
	end

	if #rewardNames == 0 then
		return
	end

	self:showToast(string.format("%s reward unlocked: %s", className, table.concat(rewardNames, ", ")), Theme.PRIMARY)
end

-- ── Action Handlers ──

function ClassSelectionUI:handleAction(action: {[string]: any})
	local actionType = action.type
	local classId = action.classId
	local classDef = ClassTypes.getClass(classId)
	local className = classDef and classDef.name or classId

	if actionType == "purchase" then
		local cost = tonumber(action.cost) or 0
		self:showToast(string.format("Purchased %s for %d!", className, cost), Theme.PRIMARY)
		if self.isVisible then
			self:hide()
		end
	elseif actionType == "equip" then
		-- Stay open, no toast — UI refreshes to show new equipped state
	elseif actionType == "error" then
		local reason = action.reason
		if reason == "INSUFFICIENT_FUNDS" then
			self:showToast("Not enough currency for this class", COLORS.STATUS_LOCKED)
		elseif reason == "RATE_LIMIT" then
			self:showToast("Please wait a moment before trying again", COLORS.STATUS_CAN_BUY)
		elseif reason == "ALREADY_UNLOCKED" then
			self:showToast("Class already unlocked", COLORS.STATUS_CAN_BUY)
		elseif reason == "NOT_IN_LOBBY" then
			self:showToast("You can change class only in lobby", Theme.WARNING)
		else
			self:showToast("Class selection failed", COLORS.STATUS_LOCKED)
		end
	end
end

function ClassSelectionUI:handleTitleAction(action: {[string]: any})
	local actionType = action.type
	if actionType == "unlock" then
		if type(action.unlockedTitles) == "table" and #action.unlockedTitles > 0 then
			local names = {}
			for _, title in ipairs(action.unlockedTitles) do
				if type(title) == "table" and type(title.name) == "string" then
					table.insert(names, title.name)
				end
			end
			if #names > 0 then
				self:showToast("Unlocked title: " .. table.concat(names, ", "), Theme.PRIMARY)
			end
		end
	elseif actionType == "error" then
		local reason = action.reason
		if reason == "TITLE_LOCKED" then
			self:showToast("Title is not unlocked yet", COLORS.STATUS_LOCKED)
		elseif reason == "INVALID_TITLE" then
			self:showToast("Invalid title selection", COLORS.STATUS_LOCKED)
		else
			self:showToast("Failed to equip title", COLORS.STATUS_LOCKED)
		end
	end
end

-- ── Selection Logic ──

function ClassSelectionUI:selectClass(classId: string)
	if not ClassTypes.getClass(classId) then
		return
	end

	local prevSelected = self.selectedClass
	self.selectedClass = classId

	-- Animate selected list item highlight
	local buttonData = self.classButtons[classId]
	if buttonData then
		TweenService:Create(buttonData.button, TweenInfo.new(0.12), {
			BackgroundColor3 = Theme.BG_ELEVATED,
		}):Play()
		TweenService:Create(buttonData.accentBar, TweenInfo.new(0.12), {
			BackgroundTransparency = 0,
		}):Play()
		TweenService:Create(buttonData.stroke, TweenInfo.new(0.12), {
			Color = buttonData.color,
		}):Play()
	end

	-- Deselect previous item
	if prevSelected ~= classId then
		local prevData = self.classButtons[prevSelected]
		if prevData then
			local prevUnlocked = self:isClassUnlocked(prevSelected)
			local targetBg = prevUnlocked and COLORS.BG_CARD or COLORS.BG_CARD_LOCKED
			TweenService:Create(prevData.button, TweenInfo.new(0.12), {
				BackgroundColor3 = targetBg,
			}):Play()
			TweenService:Create(prevData.accentBar, TweenInfo.new(0.12), {
				BackgroundTransparency = 1,
			}):Play()
			TweenService:Create(prevData.stroke, TweenInfo.new(0.12), {
				Color = COLORS.STROKE_DEFAULT,
			}):Play()
		end
	end

	self:refreshClassStates()
end

function ClassSelectionUI:confirmSelection()
	if not self.confirmButton.Active then
		return
	end

	if not ClassTypes.getClass(self.selectedClass) then
		return
	end

	self.remotes.SelectClass:FireServer(self.selectedClass)
end

function ClassSelectionUI:updateIndicator(classId: string)
	if not self.classIndicator then return end
	local classDef = ClassTypes.getClass(classId)
	if not classDef then
		return
	end

	self.indicatorIcon.Text = classDef.icon
	self.indicatorName.Text = classDef.name
	self.indicatorName.TextColor3 = Theme.darkenForText(classDef.color)

	-- Update class-color gradient on indicator
	if self.indicatorGradient then
		self.indicatorGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, classDef.color),
			ColorSequenceKeypoint.new(1, COLORS.INDICATOR_BG)
		})
		self.indicatorGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.7),
			NumberSequenceKeypoint.new(1, 0)
		})
	end

	-- Update stroke to class color
	if self.indicatorStroke then
		self.indicatorStroke.Color = classDef.color
	end

	-- Update mastery badge
	local masteryInfo = self.classMastery[classId]
	local level = masteryInfo and masteryInfo.level or 1
	local isMax = masteryInfo and masteryInfo.isMax or false
	local xp = masteryInfo and masteryInfo.xp or 0
	local xpToNext = masteryInfo and masteryInfo.xpToNext or 0

	if self.indicatorMasteryBadge then
		self.indicatorMasteryBadge.Text = string.format("Lv.%d", level)
		if isMax then
			self.indicatorMasteryBadge.TextColor3 = COLORS.MASTERY_MAX
			self.indicatorMasteryBadge.BackgroundColor3 = Theme.BG_ELEVATED
		else
			self.indicatorMasteryBadge.TextColor3 = COLORS.TEXT_ACCENT
			self.indicatorMasteryBadge.BackgroundColor3 = Theme.BG_ELEVATED
		end
	end

	-- Update mini XP bar
	if self.indicatorXpBarFill then
		local fillPct = 0
		if isMax then
			fillPct = 1
		elseif xpToNext > 0 then
			fillPct = math.clamp(xp / xpToNext, 0, 1)
		end
		self.indicatorXpBarFill.Size = UDim2.new(fillPct, 0, 1, 0)
		self.indicatorXpBarFill.BackgroundColor3 = classDef.color
	end
end

-- ── Remote Events ──

function ClassSelectionUI:setupRemotes()
	self.remotes.ClassUpdate.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end

		if type(data.unlockedClasses) == "table" then
			self.unlockedClasses = cloneBooleanMap(data.unlockedClasses)
		end

		if type(data.classCosts) == "table" then
			self.classCosts = cloneNumberMap(data.classCosts)
		end

		if type(data.classMastery) == "table" then
			self.classMastery = cloneMasteryMap(data.classMastery)
		end

		if type(data.masteryRewards) == "table" then
			self.classMasteryRewards = cloneMasteryRewardsMap(data.masteryRewards)
		end

		if data.currency ~= nil then
			local incomingCurrency = tonumber(data.currency)
			if incomingCurrency then
				self.currency = incomingCurrency
			end
		end

		if type(data.classId) == "string" and ClassTypes.getClass(data.classId) then
			self.currentClass = data.classId
			self:updateIndicator(data.classId)
		end

		if type(data.action) == "table" then
			if data.action.type == "error" and type(data.action.classId) == "string" and ClassTypes.getClass(data.action.classId) then
				self.selectedClass = data.action.classId
			elseif type(data.classId) == "string" then
				self.selectedClass = data.classId
			end
			self:handleAction(data.action)
		elseif type(data.classId) == "string" then
			self.selectedClass = data.classId
		end

		self:refreshClassStates()
	end)

	self.remotes.UpdateCurrency.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end

		if data.currency ~= nil then
			local incomingCurrency = tonumber(data.currency)
			if incomingCurrency then
				self.currency = incomingCurrency
				self:refreshClassStates()
			end
		end
	end)

	self.remotes.MasteryUpdate.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end

		if type(data.classMastery) == "table" then
			self.classMastery = cloneMasteryMap(data.classMastery)
		end

		if type(data.masteryRewards) == "table" then
			self.classMasteryRewards = cloneMasteryRewardsMap(data.masteryRewards)
		end

		if type(data.action) == "table" and data.action.leveledUp == true and type(data.action.classId) == "string" then
			local classDef = ClassTypes.getClass(data.action.classId)
			local className = classDef and classDef.name or data.action.classId
			local level = self.classMastery[data.action.classId] and self.classMastery[data.action.classId].level or tonumber(data.action.newLevel) or 1
			self:showToast(string.format("%s Mastery Lv.%d!", className, level), Theme.PRIMARY)

			if type(data.action.unlockedRewards) == "table" and #data.action.unlockedRewards > 0 then
				task.delay(0.25, function()
					self:showRewardUnlockToast(className, data.action.unlockedRewards)
				end)
			end
		elseif type(data.action) == "table" and type(data.action.unlockedRewards) == "table" and type(data.action.classId) == "string" then
			local classDef = ClassTypes.getClass(data.action.classId)
			local className = classDef and classDef.name or data.action.classId
			self:showRewardUnlockToast(className, data.action.unlockedRewards)
		end

		-- Update indicator mastery badge
		if type(data.classId) == "string" then
			self:updateIndicator(data.classId)
		elseif self.currentClass then
			self:updateIndicator(self.currentClass)
		end

		self:refreshClassStates()
	end)

	self.remotes.TitleUpdate.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end

		if type(data.titleCatalog) == "table" then
			self.titleCatalog = cloneTitleList(data.titleCatalog)
			self.unlockedTitles = {}
			for _, entry in ipairs(self.titleCatalog) do
				if entry.unlocked then
					table.insert(self.unlockedTitles, entry)
				end
			end
		elseif type(data.unlockedTitles) == "table" then
			self.unlockedTitles = cloneTitleList(data.unlockedTitles)
			self.titleCatalog = self.unlockedTitles
		end

		if data.activeTitle == nil then
			self.activeTitle = nil
		else
			self.activeTitle = cloneTitleEntry(data.activeTitle)
		end

		if type(data.action) == "table" then
			self:handleTitleAction(data.action)
		end

		self:refreshClassStates()
	end)
end

-- ── Show / Hide / Toggle ──

function ClassSelectionUI:show()
	if self.callbacks and self.callbacks.onShow then
		self.callbacks.onShow()
	end

	self.isVisible = true
	self.container.Visible = true

	self.container.BackgroundTransparency = 1

	TweenService:Create(self.container, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.02,
	}):Play()

	self:refreshClassStates()
end

function ClassSelectionUI:hide()
	self.isVisible = false

	if self.callbacks and self.callbacks.onHide then
		self.callbacks.onHide()
	end

	local fadeOut = TweenService:Create(self.container, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	})
	fadeOut:Play()
	fadeOut.Completed:Connect(function()
		self.container.Visible = false
	end)
end

function ClassSelectionUI:toggle()
	if self.isVisible then
		self:hide()
	else
		self:show()
	end
end

return ClassSelectionUI
