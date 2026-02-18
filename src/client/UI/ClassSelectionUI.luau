-- ClassSelectionUI: UI สำหรับเลือก/ซื้อ Character Class (Redesigned)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ClassTypes = require(ReplicatedStorage.Shared.ClassTypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ClassSelectionUI = {}
ClassSelectionUI.__index = ClassSelectionUI

-- Color palette (dark theme via ThemeConfig)
local COLORS = {
	BG_PRIMARY = Theme.BG_BASE,
	BG_CARD = Theme.BG_SURFACE,
	BG_CARD_LOCKED = Theme.BG_BASE,
	TEXT_PRIMARY = Theme.TEXT_PRIMARY,
	TEXT_SECONDARY = Theme.TEXT_MUTED,
	TEXT_ACCENT = Theme.ACCENT_CYAN,
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
	MASTERY_MAX = Theme.PRIMARY,
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

-- ── UI Creation ──

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
	containerCorner.CornerRadius = Theme.CORNER_MD
	containerCorner.Parent = container

	local containerStroke = Instance.new("UIStroke")
	containerStroke.Color = COLORS.STROKE_DEFAULT
	containerStroke.Thickness = Theme.STROKE_MED
	containerStroke.Parent = container

	-- Header row
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(0.6, 0, 0, 32)
	header.Position = UDim2.new(0, 24, 0, 16)
	header.BackgroundTransparency = 1
	header.Text = "SELECT YOUR CLASS"
	header.TextColor3 = COLORS.TEXT_PRIMARY
	header.TextSize = 26
	header.Font = Enum.Font.GothamBlack
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = container

	local subHeader = Instance.new("TextLabel")
	subHeader.Name = "SubHeader"
	subHeader.Size = UDim2.new(0.6, 0, 0, 18)
	subHeader.Position = UDim2.new(0, 24, 0, 48)
	subHeader.BackgroundTransparency = 1
	subHeader.Text = "Choose your play style"
	subHeader.TextColor3 = COLORS.TEXT_SECONDARY
	subHeader.TextSize = 14
	subHeader.Font = Enum.Font.GothamMedium
	subHeader.TextXAlignment = Enum.TextXAlignment.Left
	subHeader.Parent = container

	-- Currency display (top-right)
	local currencyLabel = Instance.new("TextLabel")
	currencyLabel.Name = "CurrencyLabel"
	currencyLabel.Size = UDim2.new(0, 140, 0, 30)
	currencyLabel.Position = UDim2.new(1, -170, 0, 18)
	currencyLabel.BackgroundColor3 = Theme.BG_ELEVATED
	currencyLabel.BackgroundTransparency = 0.05
	currencyLabel.BorderSizePixel = 0
	currencyLabel.Text = "0"
	currencyLabel.TextColor3 = Theme.PRIMARY
	currencyLabel.TextSize = 16
	currencyLabel.Font = Enum.Font.GothamBold
	currencyLabel.Parent = container
	self.currencyLabel = currencyLabel

	local currencyCorner = Instance.new("UICorner")
	currencyCorner.CornerRadius = Theme.CORNER_SM
	currencyCorner.Parent = currencyLabel

	local currencyStroke = Instance.new("UIStroke")
	currencyStroke.Color = Theme.BG_ELEVATED
	currencyStroke.Thickness = Theme.STROKE_THIN
	currencyStroke.Parent = currencyLabel

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -36, 0, 18)
	closeBtn.BackgroundColor3 = Theme.DANGER
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Theme.TEXT_PRIMARY
	closeBtn.TextSize = 15
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = container

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = Theme.CORNER_SM
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		self:hide()
	end)

	-- Classes container
	local classesFrame = Instance.new("Frame")
	classesFrame.Name = "ClassesFrame"
	classesFrame.Size = UDim2.new(1, -40, 0, 280)
	classesFrame.Position = UDim2.new(0, 20, 0, 76)
	classesFrame.BackgroundTransparency = 1
	classesFrame.Parent = container

	local classLayout = Instance.new("UIListLayout")
	classLayout.FillDirection = Enum.FillDirection.Horizontal
	classLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	classLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	classLayout.Padding = UDim.new(0, 12)
	classLayout.Parent = classesFrame

	for _, classId in ipairs(self:getOrderedClassIds()) do
		self:createClassCard(classesFrame, classId)
	end

	-- Mastery rewards preview
	local rewardsFrame = Instance.new("Frame")
	rewardsFrame.Name = "MasteryRewardsPreview"
	rewardsFrame.Size = UDim2.new(1, -40, 0, 52)
	rewardsFrame.Position = UDim2.new(0, 20, 0, 362)
	rewardsFrame.BackgroundColor3 = Theme.BG_SURFACE
	rewardsFrame.BackgroundTransparency = 0.1
	rewardsFrame.BorderSizePixel = 0
	rewardsFrame.Parent = container

	local rewardsCorner = Instance.new("UICorner")
	rewardsCorner.CornerRadius = Theme.CORNER_SM
	rewardsCorner.Parent = rewardsFrame

	local rewardsStroke = Instance.new("UIStroke")
	rewardsStroke.Color = Theme.BG_ELEVATED
	rewardsStroke.Thickness = Theme.STROKE_THIN
	rewardsStroke.Parent = rewardsFrame

	local rewardsTitle = Instance.new("TextLabel")
	rewardsTitle.Name = "RewardsTitle"
	rewardsTitle.Size = UDim2.new(0.6, 0, 0, 20)
	rewardsTitle.Position = UDim2.new(0, 12, 0, 4)
	rewardsTitle.BackgroundTransparency = 1
	rewardsTitle.Text = "MASTERY REWARDS"
	rewardsTitle.TextColor3 = COLORS.TEXT_ACCENT
	rewardsTitle.TextSize = 13
	rewardsTitle.Font = Enum.Font.GothamBold
	rewardsTitle.TextXAlignment = Enum.TextXAlignment.Left
	rewardsTitle.Parent = rewardsFrame
	self.rewardsTitle = rewardsTitle

	local rewardsBody = Instance.new("TextLabel")
	rewardsBody.Name = "RewardsBody"
	rewardsBody.Size = UDim2.new(0.65, 0, 0, 22)
	rewardsBody.Position = UDim2.new(0, 12, 0, 25)
	rewardsBody.BackgroundTransparency = 1
	rewardsBody.Text = "No mastery rewards configured."
	rewardsBody.TextColor3 = COLORS.TEXT_SECONDARY
	rewardsBody.TextSize = 12
	rewardsBody.Font = Enum.Font.Gotham
	rewardsBody.TextXAlignment = Enum.TextXAlignment.Left
	rewardsBody.TextTruncate = Enum.TextTruncate.AtEnd
	rewardsBody.Parent = rewardsFrame
	self.rewardsBody = rewardsBody

	-- "VIEW ALL" button
	local viewAllBtn = Instance.new("TextButton")
	viewAllBtn.Name = "ViewAllButton"
	viewAllBtn.Size = UDim2.new(0, 100, 0, 28)
	viewAllBtn.Position = UDim2.new(1, -112, 0.5, -14)
	viewAllBtn.BackgroundColor3 = COLORS.TEXT_ACCENT
	viewAllBtn.BorderSizePixel = 0
	viewAllBtn.Text = "VIEW ALL"
	viewAllBtn.TextColor3 = Theme.TEXT_PRIMARY
	viewAllBtn.TextSize = 12
	viewAllBtn.Font = Enum.Font.GothamBold
	viewAllBtn.Parent = rewardsFrame

	local viewAllCorner = Instance.new("UICorner")
	viewAllCorner.CornerRadius = Theme.CORNER_SM
	viewAllCorner.Parent = viewAllBtn

	viewAllBtn.MouseButton1Click:Connect(function()
		if self.callbacks and self.callbacks.onOpenTitleCollection then
			self.callbacks.onOpenTitleCollection()
		end
	end)

	-- Confirm button
	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Name = "ConfirmButton"
	confirmBtn.Size = UDim2.new(0, 280, 0, 46)
	confirmBtn.Position = UDim2.new(0.5, 0, 1, -56)
	confirmBtn.AnchorPoint = Vector2.new(0.5, 0)
	confirmBtn.BackgroundColor3 = COLORS.BTN_EQUIP
	confirmBtn.BorderSizePixel = 0
	confirmBtn.Text = "EQUIP"
	confirmBtn.TextColor3 = Theme.TEXT_PRIMARY
	confirmBtn.TextSize = 18
	confirmBtn.Font = Enum.Font.GothamBold
	confirmBtn.Parent = container
	self.confirmButton = confirmBtn

	local confirmCorner = Instance.new("UICorner")
	confirmCorner.CornerRadius = Theme.CORNER_SM
	confirmCorner.Parent = confirmBtn

	local confirmStroke = Instance.new("UIStroke")
	confirmStroke.Color = Theme.SUCCESS
	confirmStroke.Thickness = Theme.STROKE_THIN
	confirmStroke.Transparency = 0.5
	confirmStroke.Parent = confirmBtn
	self.confirmStroke = confirmStroke

	confirmBtn.MouseButton1Click:Connect(function()
		self:confirmSelection()
	end)

	self:createCurrentClassIndicator()
end

-- ── Class Card ──

function ClassSelectionUI:createClassCard(parent: Frame, classId: string)
	local classDef = ClassTypes.getClass(classId)
	if not classDef then
		return
	end

	local card = Instance.new("TextButton")
	card.Name = "Class_" .. classId
	card.Size = UDim2.new(0, 160, 0, 270)
	card.BackgroundColor3 = COLORS.BG_CARD
	card.BackgroundTransparency = 0
	card.BorderSizePixel = 0
	card.Text = ""
	card.AutoButtonColor = false
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = Theme.CORNER_MD
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = COLORS.STROKE_DEFAULT
	cardStroke.Thickness = Theme.STROKE_MED
	cardStroke.Parent = card

	-- Icon
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 0, 44)
	icon.Position = UDim2.new(0, 0, 0, 10)
	icon.BackgroundTransparency = 1
	icon.Text = classDef.icon
	icon.TextSize = 36
	icon.Parent = card

	-- Name
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -12, 0, 22)
	name.Position = UDim2.new(0, 6, 0, 54)
	name.BackgroundTransparency = 1
	name.Text = classDef.name
	name.TextColor3 = classDef.color
	name.TextSize = 17
	name.Font = Enum.Font.GothamBold
	name.Parent = card

	-- Stat bars
	local statsY = 82
	local function createStatBar(label: string, mod: number, yPos: number)
		local barLabel = Instance.new("TextLabel")
		barLabel.Size = UDim2.new(0, 46, 0, 14)
		barLabel.Position = UDim2.new(0, 8, 0, yPos)
		barLabel.BackgroundTransparency = 1
		barLabel.Text = label
		barLabel.TextColor3 = COLORS.TEXT_SECONDARY
		barLabel.TextSize = 11
		barLabel.Font = Enum.Font.GothamMedium
		barLabel.TextXAlignment = Enum.TextXAlignment.Left
		barLabel.Parent = card

		local barBg = Instance.new("Frame")
		barBg.Size = UDim2.new(0, 68, 0, 10)
		barBg.Position = UDim2.new(0, 56, 0, yPos + 2)
		barBg.BackgroundColor3 = COLORS.BAR_BG
		barBg.BorderSizePixel = 0
		barBg.Parent = card

		local barBgCorner = Instance.new("UICorner")
		barBgCorner.CornerRadius = UDim.new(0, 4)
		barBgCorner.Parent = barBg

		-- Map mod (0.85-1.20) to fill (0.0-1.0)
		local fillPct = math.clamp((mod - 0.70) / 0.50, 0, 1)
		local barColor = if mod > 1.0 then COLORS.BAR_BUFF elseif mod < 1.0 then COLORS.BAR_NERF else COLORS.BAR_NEUTRAL

		local barFill = Instance.new("Frame")
		barFill.Size = UDim2.new(fillPct, 0, 1, 0)
		barFill.BackgroundColor3 = barColor
		barFill.BorderSizePixel = 0
		barFill.Parent = barBg

		local barFillCorner = Instance.new("UICorner")
		barFillCorner.CornerRadius = UDim.new(0, 4)
		barFillCorner.Parent = barFill

		-- Percentage text
		local pctSign = if mod >= 1.0 then "+" else ""
		local pctText = string.format("%s%d%%", pctSign, math.floor((mod - 1) * 100))
		if mod == 1.0 then
			pctText = "0%"
		end

		local pctLabel = Instance.new("TextLabel")
		pctLabel.Size = UDim2.new(0, 30, 0, 14)
		pctLabel.Position = UDim2.new(0, 126, 0, yPos)
		pctLabel.BackgroundTransparency = 1
		pctLabel.Text = pctText
		pctLabel.TextColor3 = barColor
		pctLabel.TextSize = 10
		pctLabel.Font = Enum.Font.GothamBold
		pctLabel.TextXAlignment = Enum.TextXAlignment.Left
		pctLabel.Parent = card
	end

	createStatBar("Speed", classDef.walkSpeedMod, statsY)
	createStatBar("Jump", classDef.jumpPowerMod, statsY + 20)

	-- KB Resist bar (only if > 0)
	if classDef.knockbackResistance > 0 then
		local kbY = statsY + 40

		local kbLabel = Instance.new("TextLabel")
		kbLabel.Size = UDim2.new(0, 46, 0, 14)
		kbLabel.Position = UDim2.new(0, 8, 0, kbY)
		kbLabel.BackgroundTransparency = 1
		kbLabel.Text = "Resist"
		kbLabel.TextColor3 = COLORS.TEXT_SECONDARY
		kbLabel.TextSize = 11
		kbLabel.Font = Enum.Font.GothamMedium
		kbLabel.TextXAlignment = Enum.TextXAlignment.Left
		kbLabel.Parent = card

		local kbBg = Instance.new("Frame")
		kbBg.Size = UDim2.new(0, 68, 0, 10)
		kbBg.Position = UDim2.new(0, 56, 0, kbY + 2)
		kbBg.BackgroundColor3 = COLORS.BAR_BG
		kbBg.BorderSizePixel = 0
		kbBg.Parent = card

		local kbBgCorner = Instance.new("UICorner")
		kbBgCorner.CornerRadius = UDim.new(0, 4)
		kbBgCorner.Parent = kbBg

		local kbFill = Instance.new("Frame")
		kbFill.Size = UDim2.new(classDef.knockbackResistance, 0, 1, 0)
		kbFill.BackgroundColor3 = COLORS.MASTERY_MAX
		kbFill.BorderSizePixel = 0
		kbFill.Parent = kbBg

		local kbFillCorner = Instance.new("UICorner")
		kbFillCorner.CornerRadius = UDim.new(0, 4)
		kbFillCorner.Parent = kbFill

		local kbPct = Instance.new("TextLabel")
		kbPct.Size = UDim2.new(0, 30, 0, 14)
		kbPct.Position = UDim2.new(0, 126, 0, kbY)
		kbPct.BackgroundTransparency = 1
		kbPct.Text = string.format("%d%%", math.floor(classDef.knockbackResistance * 100))
		kbPct.TextColor3 = COLORS.MASTERY_MAX
		kbPct.TextSize = 10
		kbPct.Font = Enum.Font.GothamBold
		kbPct.TextXAlignment = Enum.TextXAlignment.Left
		kbPct.Parent = card
	end

	-- Passive ability
	local passive = Instance.new("TextLabel")
	passive.Size = UDim2.new(1, -16, 0, 28)
	passive.Position = UDim2.new(0, 8, 0, 150)
	passive.BackgroundTransparency = 1
	passive.Text = classDef.passiveAbility.name
	passive.TextColor3 = Theme.PRIMARY_DARK
	passive.TextSize = 11
	passive.Font = Enum.Font.GothamBold
	passive.TextWrapped = true
	passive.Parent = card

	-- Mastery level label
	local masteryLabel = Instance.new("TextLabel")
	masteryLabel.Name = "MasteryLabel"
	masteryLabel.Size = UDim2.new(1, -16, 0, 16)
	masteryLabel.Position = UDim2.new(0, 8, 0, 184)
	masteryLabel.BackgroundTransparency = 1
	masteryLabel.Text = "Mastery Lv.1"
	masteryLabel.TextColor3 = COLORS.TEXT_ACCENT
	masteryLabel.TextSize = 11
	masteryLabel.Font = Enum.Font.GothamMedium
	masteryLabel.TextXAlignment = Enum.TextXAlignment.Left
	masteryLabel.Parent = card

	-- Mastery XP bar (thin)
	local xpBarBg = Instance.new("Frame")
	xpBarBg.Name = "XpBarBg"
	xpBarBg.Size = UDim2.new(1, -16, 0, 5)
	xpBarBg.Position = UDim2.new(0, 8, 0, 202)
	xpBarBg.BackgroundColor3 = COLORS.BAR_BG
	xpBarBg.BorderSizePixel = 0
	xpBarBg.Parent = card

	local xpBarBgCorner = Instance.new("UICorner")
	xpBarBgCorner.CornerRadius = UDim.new(0, 2)
	xpBarBgCorner.Parent = xpBarBg

	local xpBarFill = Instance.new("Frame")
	xpBarFill.Name = "XpBarFill"
	xpBarFill.Size = UDim2.new(0, 0, 1, 0)
	xpBarFill.BackgroundColor3 = COLORS.MASTERY_BAR
	xpBarFill.BorderSizePixel = 0
	xpBarFill.Parent = xpBarBg

	local xpBarFillCorner = Instance.new("UICorner")
	xpBarFillCorner.CornerRadius = UDim.new(0, 2)
	xpBarFillCorner.Parent = xpBarFill

	-- Reward icons row (Title / Trail / Badge / CardFrame)
	local REWARD_ICONS = {
		{type = "Title", icon = "\xF0\x9F\x8F\xB7\xEF\xB8\x8F", suffix = "_title_"},
		{type = "Trail", icon = "\xE2\x9C\xA8", suffix = "_trail_"},
		{type = "Badge", icon = "\xF0\x9F\x8F\x85", suffix = "_badge_"},
		{type = "CardFrame", icon = "\xF0\x9F\x96\xBC\xEF\xB8\x8F", suffix = "_frame_"},
	}
	local rewardIconFrames = {}
	local iconRowY = 212
	local iconSize = 14
	local iconSpacing = 6
	local totalIconWidth = #REWARD_ICONS * iconSize + (#REWARD_ICONS - 1) * iconSpacing
	local iconStartX = math.floor((160 - totalIconWidth) / 2)

	for i, rewardDef in ipairs(REWARD_ICONS) do
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Name = "RewardIcon_" .. rewardDef.type
		iconLabel.Size = UDim2.new(0, iconSize, 0, iconSize)
		iconLabel.Position = UDim2.new(0, iconStartX + (i - 1) * (iconSize + iconSpacing), 0, iconRowY)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = rewardDef.icon
		iconLabel.TextSize = 12
		iconLabel.TextTransparency = 0.7
		iconLabel.Parent = card

		table.insert(rewardIconFrames, {
			label = iconLabel,
			rewardType = rewardDef.type,
			suffix = rewardDef.suffix,
		})
	end

	-- CardFrame mastery stroke (hidden by default, shown when CardFrame reward unlocked)
	local masteryFrameStroke = Instance.new("UIStroke")
	masteryFrameStroke.Name = "MasteryFrameStroke"
	masteryFrameStroke.Color = Config.Mastery and Config.Mastery.TitleThemes and Config.Mastery.TitleThemes.Legendary and Config.Mastery.TitleThemes.Legendary.frameColor or Color3.fromRGB(220, 170, 70)
	masteryFrameStroke.Thickness = 3
	masteryFrameStroke.Transparency = 1
	masteryFrameStroke.Parent = card

	-- Cost label
	local costLabel = Instance.new("TextLabel")
	costLabel.Name = "CostLabel"
	costLabel.Size = UDim2.new(1, -16, 0, 16)
	costLabel.Position = UDim2.new(0, 8, 0, 228)
	costLabel.BackgroundTransparency = 1
	costLabel.Text = ""
	costLabel.TextColor3 = COLORS.STATUS_CAN_BUY
	costLabel.TextSize = 12
	costLabel.Font = Enum.Font.GothamBold
	costLabel.TextXAlignment = Enum.TextXAlignment.Left
	costLabel.Parent = card

	-- Status label
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -16, 0, 22)
	statusLabel.Position = UDim2.new(0, 8, 0, 246)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.TextColor3 = COLORS.TEXT_SECONDARY
	statusLabel.TextSize = 13
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = card

	self.classButtons[classId] = {
		button = card,
		stroke = cardStroke,
		color = classDef.color,
		masteryLabel = masteryLabel,
		xpBarFill = xpBarFill,
		xpBarBg = xpBarBg,
		costLabel = costLabel,
		statusLabel = statusLabel,
		rewardIcons = rewardIconFrames,
		masteryFrameStroke = masteryFrameStroke,
	}

	card.MouseButton1Click:Connect(function()
		self:selectClass(classId)
	end)

	card.MouseEnter:Connect(function()
		if self.selectedClass ~= classId then
			TweenService:Create(cardStroke, TweenInfo.new(0.12), {
				Color = classDef.color,
			}):Play()
		end
	end)

	card.MouseLeave:Connect(function()
		if self.selectedClass ~= classId then
			local isUnlocked = self:isClassUnlocked(classId)
			local isAffordable = self:isClassAffordable(classId)
			local targetColor = COLORS.STROKE_DEFAULT
			if not isUnlocked then
				targetColor = if isAffordable then Theme.WARNING else Theme.DANGER
			end
			TweenService:Create(cardStroke, TweenInfo.new(0.12), {
				Color = targetColor,
			}):Play()
		end
	end)
end

-- ── Class Indicator HUD ──

function ClassSelectionUI:createCurrentClassIndicator()
	local indicator = Instance.new("Frame")
	indicator.Name = "ClassIndicator"
	indicator.Size = UDim2.new(0, 168, 0, 40)
	indicator.Position = UDim2.new(0, 10, 0, 140)
	indicator.BackgroundColor3 = COLORS.INDICATOR_BG
	indicator.BackgroundTransparency = 0.1
	indicator.BorderSizePixel = 0
	indicator.Parent = self.parent
	self.classIndicator = indicator

	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.CornerRadius = Theme.CORNER_SM
	indicatorCorner.Parent = indicator

	local indicatorStroke = Instance.new("UIStroke")
	indicatorStroke.Color = COLORS.STROKE_DEFAULT
	indicatorStroke.Thickness = Theme.STROKE_THIN
	indicatorStroke.Parent = indicator
	self.indicatorStroke = indicatorStroke

	-- Icon
	local indicatorIcon = Instance.new("TextLabel")
	indicatorIcon.Name = "Icon"
	indicatorIcon.Size = UDim2.new(0, 32, 1, 0)
	indicatorIcon.Position = UDim2.new(0, 4, 0, 0)
	indicatorIcon.BackgroundTransparency = 1
	indicatorIcon.TextSize = 20
	indicatorIcon.Parent = indicator
	self.indicatorIcon = indicatorIcon

	-- Name
	local indicatorName = Instance.new("TextLabel")
	indicatorName.Name = "Name"
	indicatorName.Size = UDim2.new(0, 70, 1, 0)
	indicatorName.Position = UDim2.new(0, 34, 0, 0)
	indicatorName.BackgroundTransparency = 1
	indicatorName.TextSize = 15
	indicatorName.Font = Enum.Font.GothamBold
	indicatorName.TextXAlignment = Enum.TextXAlignment.Left
	indicatorName.Parent = indicator
	self.indicatorName = indicatorName

	-- Mastery badge
	local masteryBadge = Instance.new("TextLabel")
	masteryBadge.Name = "MasteryBadge"
	masteryBadge.Size = UDim2.new(0, 40, 0, 20)
	masteryBadge.Position = UDim2.new(0, 106, 0.5, -10)
	masteryBadge.BackgroundColor3 = Theme.BG_SURFACE
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
	chevron.TextColor3 = COLORS.TEXT_SECONDARY
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
			Size = UDim2.new(0, 172, 0, 42),
		}):Play()
		task.delay(0.08, function()
			TweenService:Create(indicator, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
				Size = UDim2.new(0, 168, 0, 40),
			}):Play()
		end)

		self:toggle()
	end)

	-- Hover effects
	clickButton.MouseEnter:Connect(function()
		TweenService:Create(indicator, TweenInfo.new(0.12), {
			BackgroundColor3 = COLORS.INDICATOR_HOVER,
		}):Play()
		TweenService:Create(self.indicatorStroke, TweenInfo.new(0.12), {
			Color = COLORS.TEXT_ACCENT,
		}):Play()
	end)

	clickButton.MouseLeave:Connect(function()
		TweenService:Create(indicator, TweenInfo.new(0.12), {
			BackgroundColor3 = COLORS.INDICATOR_BG,
		}):Play()
		TweenService:Create(self.indicatorStroke, TweenInfo.new(0.12), {
			Color = COLORS.STROKE_DEFAULT,
		}):Play()
	end)

	self:updateIndicator(self.currentClass)
end

-- ── State Management ──

function ClassSelectionUI:setConfirmButtonState(text: string, isEnabled: boolean, btnColor: Color3?)
	if not self.confirmButton then
		return
	end

	self.confirmButton.Text = text
	self.confirmButton.Active = isEnabled
	self.confirmButton.AutoButtonColor = isEnabled

	if isEnabled then
		self.confirmButton.BackgroundColor3 = btnColor or COLORS.BTN_EQUIP
		self.confirmButton.TextColor3 = Theme.TEXT_PRIMARY
		if self.confirmStroke then
			self.confirmStroke.Transparency = 0.5
		end
	else
		self.confirmButton.BackgroundColor3 = COLORS.BTN_DISABLED
		self.confirmButton.TextColor3 = Theme.TEXT_PRIMARY
		if self.confirmStroke then
			self.confirmStroke.Transparency = 1
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
		local classCost = self:getClassCost(classId)
		local isAffordable = self:isClassAffordable(classId)
		local masteryInfo = self.classMastery[classId]

		-- Card appearance
		if isSelected then
			buttonData.stroke.Color = buttonData.color
			buttonData.stroke.Thickness = 3
			buttonData.button.BackgroundColor3 = COLORS.BG_CARD
			buttonData.button.BackgroundTransparency = 0
		elseif isUnlocked then
			buttonData.stroke.Color = COLORS.STROKE_DEFAULT
			buttonData.stroke.Thickness = 2
			buttonData.button.BackgroundColor3 = COLORS.BG_CARD
			buttonData.button.BackgroundTransparency = 0
		elseif isAffordable then
			buttonData.stroke.Color = Theme.WARNING
			buttonData.stroke.Thickness = 2
			buttonData.button.BackgroundColor3 = COLORS.BG_CARD_LOCKED
			buttonData.button.BackgroundTransparency = 0
		else
			buttonData.stroke.Color = Theme.DANGER
			buttonData.stroke.Thickness = 2
			buttonData.button.BackgroundColor3 = COLORS.BG_CARD_LOCKED
			buttonData.button.BackgroundTransparency = 0.1
		end

		-- Status label
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

		-- Mastery info
		local masteryLevel = masteryInfo and masteryInfo.level or 1
		local masteryXp = masteryInfo and masteryInfo.xp or 0
		local masteryXpToNext = masteryInfo and masteryInfo.xpToNext or 0
		local masteryIsMax = masteryInfo and masteryInfo.isMax or false

		-- Check if ultimate is unlocked (level >= 20)
		local ultimateUnlockLevel = Config.Mastery and Config.Mastery.UltimateUnlockLevel or 20
		local hasUltimate = masteryLevel >= ultimateUnlockLevel
		local ultimateSkillConfig = Config.Mastery and Config.Mastery.UltimateSkills and Config.Mastery.UltimateSkills[classId]

		if masteryIsMax then
			if hasUltimate and ultimateSkillConfig then
				buttonData.masteryLabel.Text = string.format("Lv.%d ⚡ %s", masteryLevel, ultimateSkillConfig.name or "ULTIMATE")
			else
				buttonData.masteryLabel.Text = string.format("Mastery Lv.%d (MAX)", masteryLevel)
			end
			buttonData.masteryLabel.TextColor3 = COLORS.MASTERY_MAX
		elseif hasUltimate and ultimateSkillConfig then
			buttonData.masteryLabel.Text = string.format("Lv.%d ⚡ %s", masteryLevel, ultimateSkillConfig.name or "ULTIMATE")
			buttonData.masteryLabel.TextColor3 = COLORS.MASTERY_MAX
		elseif masteryXpToNext > 0 then
			local toUltimate = ultimateUnlockLevel - masteryLevel
			if toUltimate > 0 and toUltimate <= 5 then
				buttonData.masteryLabel.Text = string.format("Lv.%d (%d to ⚡)", masteryLevel, toUltimate)
			else
				buttonData.masteryLabel.Text = string.format("Mastery Lv.%d  %d/%d", masteryLevel, masteryXp, masteryXpToNext)
			end
			buttonData.masteryLabel.TextColor3 = COLORS.TEXT_ACCENT
		else
			buttonData.masteryLabel.Text = string.format("Mastery Lv.%d", masteryLevel)
			buttonData.masteryLabel.TextColor3 = COLORS.TEXT_ACCENT
		end

		-- XP bar fill
		if buttonData.xpBarFill then
			local fillPct = 0
			if masteryIsMax then
				fillPct = 1
			elseif masteryXpToNext > 0 then
				fillPct = math.clamp(masteryXp / masteryXpToNext, 0, 1)
			end

			buttonData.xpBarFill.Size = UDim2.new(fillPct, 0, 1, 0)
			buttonData.xpBarFill.BackgroundColor3 = if masteryIsMax then COLORS.MASTERY_MAX else COLORS.MASTERY_BAR
		end

		-- Cost label
		if not isUnlocked and classCost > 0 then
			buttonData.costLabel.Text = string.format("Cost: %d", classCost)
		else
			buttonData.costLabel.Text = ""
		end

		-- Reward icons (unlocked = vivid, locked = dim)
		if buttonData.rewardIcons then
			local rewards = self.classMasteryRewards[classId] or {}
			local unlockedById = {}
			for _, reward in ipairs(rewards) do
				if reward.unlocked then
					unlockedById[reward.id] = reward
				end
			end

			local classPrefix = string.lower(classId)
			for _, iconData in ipairs(buttonData.rewardIcons) do
				local isRewardUnlocked = false
				for rewardId, _ in pairs(unlockedById) do
					if string.find(rewardId, classPrefix .. iconData.suffix) then
						isRewardUnlocked = true
						break
					end
				end
				iconData.label.TextTransparency = isRewardUnlocked and 0 or 0.7
			end
		end

		-- CardFrame mastery stroke
		if buttonData.masteryFrameStroke then
			local hasFrame = false
			local rewards = self.classMasteryRewards[classId] or {}
			for _, reward in ipairs(rewards) do
				if reward.rewardType == "CardFrame" and reward.unlocked then
					hasFrame = true
					break
				end
			end
			buttonData.masteryFrameStroke.Transparency = hasFrame and 0 or 1
		end
	end

	-- Confirm button state
	local selectedClass = self.selectedClass
	local selectedUnlocked = self:isClassUnlocked(selectedClass)
	local selectedCost = self:getClassCost(selectedClass)
	local selectedAffordable = self:isClassAffordable(selectedClass)

	if selectedUnlocked then
		if selectedClass == self.currentClass then
			self:setConfirmButtonState("EQUIPPED", false)
		else
			self:setConfirmButtonState("EQUIP", true, COLORS.BTN_EQUIP)
		end
	elseif selectedAffordable then
		self:setConfirmButtonState(string.format("BUY & EQUIP (%d)", selectedCost), true, COLORS.BTN_PURCHASE)
	else
		self:setConfirmButtonState(string.format("NOT ENOUGH (%d)", selectedCost), false)
	end

	self:updateRewardsPreview()
end

function ClassSelectionUI:updateRewardsPreview()
	if not self.rewardsTitle or not self.rewardsBody then
		return
	end

	local selectedClass = self.selectedClass
	local rewards = self.classMasteryRewards[selectedClass] or {}

	if #rewards == 0 then
		self.rewardsTitle.Text = "MASTERY REWARDS"
		self.rewardsBody.Text = "No mastery rewards configured for this class."
		return
	end

	local unlockedCount = 0
	local firstLockedReward = nil

	for _, reward in ipairs(rewards) do
		if reward.unlocked then
			unlockedCount += 1
		elseif not firstLockedReward then
			firstLockedReward = reward
		end
	end

	self.rewardsTitle.Text = string.format("MASTERY REWARDS (%d/%d)", unlockedCount, #rewards)

	if firstLockedReward then
		self.rewardsBody.Text = string.format("Next: Lv.%d %s \"%s\"", firstLockedReward.level, firstLockedReward.rewardType, firstLockedReward.name)
	else
		self.rewardsBody.Text = "All mastery rewards unlocked!"
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
	toast.Position = UDim2.new(0, 10, 0, 230)  -- Moved down to not overlap TitleHUD (which is at Y=186)
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
		if classId == self.currentClass then
			self:showToast("Equipped " .. className, COLORS.TEXT_ACCENT)
			if self.isVisible then
				self:hide()
			end
		end
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

	-- Animate selected card
	local buttonData = self.classButtons[classId]
	if buttonData then
		TweenService:Create(buttonData.button, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
			Size = UDim2.new(0, 164, 0, 274),
		}):Play()
		task.delay(0.1, function()
			TweenService:Create(buttonData.button, TweenInfo.new(0.15, Enum.EasingStyle.Back), {
				Size = UDim2.new(0, 160, 0, 270),
			}):Play()
		end)
	end

	-- Shrink previous selection back
	if prevSelected ~= classId then
		local prevData = self.classButtons[prevSelected]
		if prevData then
			TweenService:Create(prevData.button, TweenInfo.new(0.12), {
				Size = UDim2.new(0, 160, 0, 270),
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
	local classDef = ClassTypes.getClass(classId)
	if not classDef then
		return
	end

	self.indicatorIcon.Text = classDef.icon
	self.indicatorName.Text = classDef.name
	self.indicatorName.TextColor3 = classDef.color

	-- Update mastery badge
	local masteryInfo = self.classMastery[classId]
	local level = masteryInfo and masteryInfo.level or 1
	local isMax = masteryInfo and masteryInfo.isMax or false

	if self.indicatorMasteryBadge then
		self.indicatorMasteryBadge.Text = string.format("Lv.%d", level)
		if isMax then
			self.indicatorMasteryBadge.TextColor3 = COLORS.MASTERY_MAX
			self.indicatorMasteryBadge.BackgroundColor3 = Theme.BG_ELEVATED
		else
			self.indicatorMasteryBadge.TextColor3 = COLORS.TEXT_ACCENT
			self.indicatorMasteryBadge.BackgroundColor3 = Theme.BG_SURFACE
		end
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

	self.container.Position = UDim2.new(0.5, 0, 0.5, 40)
	self.container.BackgroundTransparency = 1

	TweenService:Create(self.container, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 0.02,
	}):Play()

	self:refreshClassStates()
end

function ClassSelectionUI:hide()
	self.isVisible = false

	TweenService:Create(self.container, TweenInfo.new(0.2), {
		Position = UDim2.new(0.5, 0, 0.5, 40),
		BackgroundTransparency = 1,
	}):Play()

	task.delay(0.2, function()
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
