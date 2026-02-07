-- ClassSelectionUI: UI สำหรับเลือก/ซื้อ Character Class

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ClassTypes = require(ReplicatedStorage.Shared.ClassTypes)
local Config = require(ReplicatedStorage.Shared.Config)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ClassSelectionUI = {}
ClassSelectionUI.__index = ClassSelectionUI

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

local function getTitleTheme(rarity: string, classColor: Color3?): {textColor: Color3, strokeColor: Color3, frameColor: Color3}
	local configured = Config.Mastery and Config.Mastery.TitleThemes
	local theme = type(configured) == "table" and configured[rarity] or nil

	local result = {
		textColor = classColor or Color3.fromRGB(230, 230, 230),
		strokeColor = Color3.fromRGB(0, 0, 0),
		frameColor = classColor or Color3.fromRGB(95, 95, 110),
	}

	if type(theme) == "table" then
		if typeof(theme.textColor) == "Color3" then
			result.textColor = theme.textColor
		end
		if typeof(theme.strokeColor) == "Color3" then
			result.strokeColor = theme.strokeColor
		end
		if typeof(theme.frameColor) == "Color3" then
			result.frameColor = theme.frameColor
		end
	end

	return result
end

function ClassSelectionUI.new(parent: ScreenGui)
	local self = setmetatable({}, ClassSelectionUI)

	self.parent = parent
	self.isVisible = false

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
	self.selectedTitleIndex = 1
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

function ClassSelectionUI:createUI()
	-- Main container (initially hidden)
	local container = Instance.new("Frame")
	container.Name = "ClassSelectionContainer"
	container.Size = UDim2.new(0, 680, 0, 500)
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

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 150, 255)
	stroke.Thickness = 2
	stroke.Parent = container

	-- Header
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, -40, 0, 50)
	header.Position = UDim2.new(0, 20, 0, 15)
	header.BackgroundTransparency = 1
	header.Text = "SELECT YOUR CLASS"
	header.TextColor3 = Color3.fromRGB(255, 255, 255)
	header.TextSize = 28
	header.Font = Enum.Font.GothamBlack
	header.Parent = container

	local subHeader = Instance.new("TextLabel")
	subHeader.Name = "SubHeader"
	subHeader.Size = UDim2.new(1, -40, 0, 20)
	subHeader.Position = UDim2.new(0, 20, 0, 50)
	subHeader.BackgroundTransparency = 1
	subHeader.Text = "Unlocked classes can equip instantly. Locked classes require currency."
	subHeader.TextColor3 = Color3.fromRGB(180, 180, 200)
	subHeader.TextSize = 13
	subHeader.Font = Enum.Font.Gotham
	subHeader.Parent = container

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -40, 0, 15)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 16
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = container

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = UDim.new(0, 6)
	closeBtnCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		self:hide()
	end)

	-- Classes container
	local classesFrame = Instance.new("Frame")
	classesFrame.Name = "ClassesFrame"
	classesFrame.Size = UDim2.new(1, -40, 0, 230)
	classesFrame.Position = UDim2.new(0, 20, 0, 85)
	classesFrame.BackgroundTransparency = 1
	classesFrame.Parent = container

	local classLayout = Instance.new("UIListLayout")
	classLayout.FillDirection = Enum.FillDirection.Horizontal
	classLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	classLayout.Padding = UDim.new(0, 12)
	classLayout.Parent = classesFrame

	for _, classId in ipairs(self:getOrderedClassIds()) do
		self:createClassButton(classesFrame, classId)
	end

	-- Mastery rewards preview (selected class)
	local rewardsPreviewFrame = Instance.new("Frame")
	rewardsPreviewFrame.Name = "MasteryRewardsPreview"
	rewardsPreviewFrame.Size = UDim2.new(1, -40, 0, 64)
	rewardsPreviewFrame.Position = UDim2.new(0, 20, 0, 320)
	rewardsPreviewFrame.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
	rewardsPreviewFrame.BackgroundTransparency = 0.2
	rewardsPreviewFrame.BorderSizePixel = 0
	rewardsPreviewFrame.Parent = container

	local rewardsPreviewCorner = Instance.new("UICorner")
	rewardsPreviewCorner.CornerRadius = UDim.new(0, 10)
	rewardsPreviewCorner.Parent = rewardsPreviewFrame

	local rewardsPreviewStroke = Instance.new("UIStroke")
	rewardsPreviewStroke.Color = Color3.fromRGB(90, 120, 170)
	rewardsPreviewStroke.Thickness = 1
	rewardsPreviewStroke.Parent = rewardsPreviewFrame

	local rewardsTitle = Instance.new("TextLabel")
	rewardsTitle.Name = "RewardsTitle"
	rewardsTitle.Size = UDim2.new(1, -16, 0, 18)
	rewardsTitle.Position = UDim2.new(0, 8, 0, 6)
	rewardsTitle.BackgroundTransparency = 1
	rewardsTitle.Text = "MASTERY REWARDS"
	rewardsTitle.TextColor3 = Color3.fromRGB(170, 215, 255)
	rewardsTitle.TextSize = 12
	rewardsTitle.Font = Enum.Font.GothamBold
	rewardsTitle.TextXAlignment = Enum.TextXAlignment.Left
	rewardsTitle.Parent = rewardsPreviewFrame
	self.rewardsTitle = rewardsTitle

	local rewardsBody = Instance.new("TextLabel")
	rewardsBody.Name = "RewardsBody"
	rewardsBody.Size = UDim2.new(1, -16, 0, 38)
	rewardsBody.Position = UDim2.new(0, 8, 0, 23)
	rewardsBody.BackgroundTransparency = 1
	rewardsBody.Text = "No mastery rewards configured."
	rewardsBody.TextColor3 = Color3.fromRGB(220, 220, 220)
	rewardsBody.TextSize = 11
	rewardsBody.Font = Enum.Font.Gotham
	rewardsBody.TextXAlignment = Enum.TextXAlignment.Left
	rewardsBody.TextYAlignment = Enum.TextYAlignment.Top
	rewardsBody.TextWrapped = true
	rewardsBody.Parent = rewardsPreviewFrame
	self.rewardsBody = rewardsBody

	-- Title selector
	local titleFrame = Instance.new("Frame")
	titleFrame.Name = "TitleSelectionFrame"
	titleFrame.Size = UDim2.new(1, -40, 0, 52)
	titleFrame.Position = UDim2.new(0, 20, 0, 390)
	titleFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 34)
	titleFrame.BackgroundTransparency = 0.15
	titleFrame.BorderSizePixel = 0
	titleFrame.Parent = container

	local titleFrameCorner = Instance.new("UICorner")
	titleFrameCorner.CornerRadius = UDim.new(0, 8)
	titleFrameCorner.Parent = titleFrame

	local titleFrameStroke = Instance.new("UIStroke")
	titleFrameStroke.Color = Color3.fromRGB(100, 130, 180)
	titleFrameStroke.Thickness = 1
	titleFrameStroke.Parent = titleFrame

	local titleHeader = Instance.new("TextLabel")
	titleHeader.Size = UDim2.new(0, 110, 0, 18)
	titleHeader.Position = UDim2.new(0, 8, 0, 2)
	titleHeader.BackgroundTransparency = 1
	titleHeader.Text = "ACTIVE TITLE"
	titleHeader.TextColor3 = Color3.fromRGB(185, 210, 255)
	titleHeader.TextSize = 11
	titleHeader.Font = Enum.Font.GothamBold
	titleHeader.TextXAlignment = Enum.TextXAlignment.Left
	titleHeader.Parent = titleFrame

	local prevTitleBtn = Instance.new("TextButton")
	prevTitleBtn.Name = "PrevTitleButton"
	prevTitleBtn.Size = UDim2.new(0, 28, 0, 24)
	prevTitleBtn.Position = UDim2.new(0, 8, 0, 22)
	prevTitleBtn.BackgroundColor3 = Color3.fromRGB(58, 58, 72)
	prevTitleBtn.BorderSizePixel = 0
	prevTitleBtn.Text = "<"
	prevTitleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	prevTitleBtn.TextSize = 16
	prevTitleBtn.Font = Enum.Font.GothamBold
	prevTitleBtn.Parent = titleFrame
	self.prevTitleButton = prevTitleBtn

	local prevTitleCorner = Instance.new("UICorner")
	prevTitleCorner.CornerRadius = UDim.new(0, 6)
	prevTitleCorner.Parent = prevTitleBtn

	local nextTitleBtn = Instance.new("TextButton")
	nextTitleBtn.Name = "NextTitleButton"
	nextTitleBtn.Size = UDim2.new(0, 28, 0, 24)
	nextTitleBtn.Position = UDim2.new(0, 324, 0, 22)
	nextTitleBtn.BackgroundColor3 = Color3.fromRGB(58, 58, 72)
	nextTitleBtn.BorderSizePixel = 0
	nextTitleBtn.Text = ">"
	nextTitleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	nextTitleBtn.TextSize = 16
	nextTitleBtn.Font = Enum.Font.GothamBold
	nextTitleBtn.Parent = titleFrame
	self.nextTitleButton = nextTitleBtn

	local nextTitleCorner = Instance.new("UICorner")
	nextTitleCorner.CornerRadius = UDim.new(0, 6)
	nextTitleCorner.Parent = nextTitleBtn

	local titleValueLabel = Instance.new("TextLabel")
	titleValueLabel.Name = "TitleValueLabel"
	titleValueLabel.Size = UDim2.new(0, 280, 0, 24)
	titleValueLabel.Position = UDim2.new(0, 40, 0, 22)
	titleValueLabel.BackgroundTransparency = 1
	titleValueLabel.Text = "No title unlocked"
	titleValueLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
	titleValueLabel.TextSize = 12
	titleValueLabel.Font = Enum.Font.GothamMedium
	titleValueLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleValueLabel.Parent = titleFrame
	self.titleValueLabel = titleValueLabel

	local equipTitleBtn = Instance.new("TextButton")
	equipTitleBtn.Name = "EquipTitleButton"
	equipTitleBtn.Size = UDim2.new(0, 280, 0, 28)
	equipTitleBtn.Position = UDim2.new(1, -288, 0, 20)
	equipTitleBtn.BackgroundColor3 = Color3.fromRGB(55, 120, 75)
	equipTitleBtn.BorderSizePixel = 0
	equipTitleBtn.Text = "EQUIP TITLE"
	equipTitleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	equipTitleBtn.TextSize = 14
	equipTitleBtn.Font = Enum.Font.GothamBold
	equipTitleBtn.Parent = titleFrame
	self.equipTitleButton = equipTitleBtn

	local equipTitleCorner = Instance.new("UICorner")
	equipTitleCorner.CornerRadius = UDim.new(0, 6)
	equipTitleCorner.Parent = equipTitleBtn

	prevTitleBtn.MouseButton1Click:Connect(function()
		self:cycleTitleSelection(-1)
	end)

	nextTitleBtn.MouseButton1Click:Connect(function()
		self:cycleTitleSelection(1)
	end)

	equipTitleBtn.MouseButton1Click:Connect(function()
		self:confirmTitleSelection()
	end)

	-- Confirm button
	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Name = "ConfirmButton"
	confirmBtn.Size = UDim2.new(0, 260, 0, 45)
	confirmBtn.Position = UDim2.new(0.5, 0, 1, -52)
	confirmBtn.AnchorPoint = Vector2.new(0.5, 0)
	confirmBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	confirmBtn.BorderSizePixel = 0
	confirmBtn.Text = "CONFIRM"
	confirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	confirmBtn.TextSize = 20
	confirmBtn.Font = Enum.Font.GothamBold
	confirmBtn.Parent = container
	self.confirmButton = confirmBtn

	local confirmCorner = Instance.new("UICorner")
	confirmCorner.CornerRadius = UDim.new(0, 8)
	confirmCorner.Parent = confirmBtn

	confirmBtn.MouseButton1Click:Connect(function()
		self:confirmSelection()
	end)

	self:createCurrentClassIndicator()
end

function ClassSelectionUI:createClassButton(parent: Frame, classId: string)
	local classDef = ClassTypes.getClass(classId)
	if not classDef then
		return
	end

	local displayInfo = ClassTypes.getClassDisplayInfo(classId)
	if not displayInfo then
		return
	end

	local button = Instance.new("TextButton")
	button.Name = "Class_" .. classId
	button.Size = UDim2.new(0, 145, 0, 220)
	button.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	button.BackgroundTransparency = 0.3
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	button.Parent = parent

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 12)
	buttonCorner.Parent = button

	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Color = Color3.fromRGB(80, 80, 80)
	buttonStroke.Thickness = 2
	buttonStroke.Parent = button

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 0, 46)
	icon.Position = UDim2.new(0, 0, 0, 8)
	icon.BackgroundTransparency = 1
	icon.Text = classDef.icon
	icon.TextSize = 38
	icon.Parent = button

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -10, 0, 24)
	name.Position = UDim2.new(0, 5, 0, 54)
	name.BackgroundTransparency = 1
	name.Text = classDef.name
	name.TextColor3 = classDef.color
	name.TextSize = 18
	name.Font = Enum.Font.GothamBold
	name.Parent = button

	local stats = Instance.new("TextLabel")
	stats.Size = UDim2.new(1, -10, 0, 56)
	stats.Position = UDim2.new(0, 5, 0, 82)
	stats.BackgroundTransparency = 1
	stats.Text = table.concat(displayInfo.stats, "\n")
	stats.TextColor3 = Color3.fromRGB(200, 200, 200)
	stats.TextSize = 12
	stats.Font = Enum.Font.GothamMedium
	stats.TextXAlignment = Enum.TextXAlignment.Center
	stats.TextYAlignment = Enum.TextYAlignment.Top
	stats.Parent = button

	local passive = Instance.new("TextLabel")
	passive.Size = UDim2.new(1, -10, 0, 30)
	passive.Position = UDim2.new(0, 5, 0, 134)
	passive.BackgroundTransparency = 1
	passive.Text = classDef.passiveAbility.name
	passive.TextColor3 = Color3.fromRGB(255, 230, 150)
	passive.TextSize = 10
	passive.Font = Enum.Font.GothamMedium
	passive.TextWrapped = true
	passive.Parent = button

	local masteryLabel = Instance.new("TextLabel")
	masteryLabel.Name = "MasteryLabel"
	masteryLabel.Size = UDim2.new(1, -10, 0, 14)
	masteryLabel.Position = UDim2.new(0, 5, 0, 165)
	masteryLabel.BackgroundTransparency = 1
	masteryLabel.Text = "Mastery Lv.1"
	masteryLabel.TextColor3 = Color3.fromRGB(170, 220, 255)
	masteryLabel.TextSize = 10
	masteryLabel.Font = Enum.Font.GothamMedium
	masteryLabel.Parent = button

	local costLabel = Instance.new("TextLabel")
	costLabel.Name = "CostLabel"
	costLabel.Size = UDim2.new(1, -10, 0, 14)
	costLabel.Position = UDim2.new(0, 5, 0, 180)
	costLabel.BackgroundTransparency = 1
	costLabel.Text = ""
	costLabel.TextColor3 = Color3.fromRGB(255, 215, 110)
	costLabel.TextSize = 11
	costLabel.Font = Enum.Font.GothamBold
	costLabel.Parent = button

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -10, 0, 20)
	statusLabel.Position = UDim2.new(0, 5, 0, 194)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	statusLabel.TextSize = 12
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.Parent = button

	self.classButtons[classId] = {
		button = button,
		stroke = buttonStroke,
		color = classDef.color,
		masteryLabel = masteryLabel,
		costLabel = costLabel,
		statusLabel = statusLabel,
	}

	button.MouseButton1Click:Connect(function()
		self:selectClass(classId)
	end)

	button.MouseEnter:Connect(function()
		if self.selectedClass ~= classId then
			TweenService:Create(buttonStroke, TweenInfo.new(0.15), {
				Color = classDef.color,
			}):Play()
		end
	end)

	button.MouseLeave:Connect(function()
		self:refreshClassStates()
	end)
end

function ClassSelectionUI:createCurrentClassIndicator()
	local indicator = Instance.new("Frame")
	indicator.Name = "ClassIndicator"
	indicator.Size = UDim2.new(0, 140, 0, 35)
	indicator.Position = UDim2.new(0, 10, 0, 140)
	indicator.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	indicator.BackgroundTransparency = 0.3
	indicator.BorderSizePixel = 0
	indicator.Parent = self.parent
	self.classIndicator = indicator

	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.CornerRadius = UDim.new(0, 8)
	indicatorCorner.Parent = indicator

	local indicatorIcon = Instance.new("TextLabel")
	indicatorIcon.Name = "Icon"
	indicatorIcon.Size = UDim2.new(0, 30, 1, 0)
	indicatorIcon.BackgroundTransparency = 1
	indicatorIcon.TextSize = 20
	indicatorIcon.Parent = indicator
	self.indicatorIcon = indicatorIcon

	local indicatorName = Instance.new("TextLabel")
	indicatorName.Name = "Name"
	indicatorName.Size = UDim2.new(1, -35, 1, 0)
	indicatorName.Position = UDim2.new(0, 32, 0, 0)
	indicatorName.BackgroundTransparency = 1
	indicatorName.TextSize = 14
	indicatorName.Font = Enum.Font.GothamBold
	indicatorName.TextXAlignment = Enum.TextXAlignment.Left
	indicatorName.Parent = indicator
	self.indicatorName = indicatorName

	local clickButton = Instance.new("TextButton")
	clickButton.Size = UDim2.new(1, 0, 1, 0)
	clickButton.BackgroundTransparency = 1
	clickButton.Text = ""
	clickButton.Parent = indicator

	clickButton.MouseButton1Click:Connect(function()
		self:toggle()
	end)

	self:updateIndicator(self.currentClass)
end

function ClassSelectionUI:setConfirmButtonState(text: string, isEnabled: boolean)
	if not self.confirmButton then
		return
	end

	self.confirmButton.Text = text
	self.confirmButton.Active = isEnabled
	self.confirmButton.AutoButtonColor = isEnabled

	if isEnabled then
		self.confirmButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
		self.confirmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	else
		self.confirmButton.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
		self.confirmButton.TextColor3 = Color3.fromRGB(200, 200, 200)
	end
end

function ClassSelectionUI:setTitleSelectionIndexById(titleId: string?)
	local targetIndex = 1
	if titleId then
		for index, title in ipairs(self.unlockedTitles) do
			if title.id == titleId then
				targetIndex = index + 1
				break
			end
		end
	end

	self.selectedTitleIndex = targetIndex
end

function ClassSelectionUI:getSelectedTitleEntry(): {id: string, name: string, classId: string, level: number, rarity: string, description: string?, unlocked: boolean}?
	local titleCount = #self.unlockedTitles
	if titleCount == 0 then
		return nil
	end

	if self.selectedTitleIndex <= 1 then
		return nil
	end

	local titleIndex = self.selectedTitleIndex - 1
	return self.unlockedTitles[titleIndex]
end

function ClassSelectionUI:cycleTitleSelection(step: number)
	local maxIndex = #self.unlockedTitles + 1
	if maxIndex <= 1 then
		self.selectedTitleIndex = 1
		self:updateTitleSelector()
		return
	end

	local nextIndex = self.selectedTitleIndex + step
	if nextIndex < 1 then
		nextIndex = maxIndex
	elseif nextIndex > maxIndex then
		nextIndex = 1
	end

	self.selectedTitleIndex = nextIndex
	self:updateTitleSelector()
end

function ClassSelectionUI:updateTitleSelector()
	if not self.titleValueLabel or not self.equipTitleButton then
		return
	end

	local titleCount = #self.unlockedTitles
	local selectedTitle = self:getSelectedTitleEntry()
	local activeTitleId = self.activeTitle and self.activeTitle.id or nil

	if self.prevTitleButton then
		self.prevTitleButton.Active = titleCount > 0
		self.prevTitleButton.AutoButtonColor = titleCount > 0
	end
	if self.nextTitleButton then
		self.nextTitleButton.Active = titleCount > 0
		self.nextTitleButton.AutoButtonColor = titleCount > 0
	end

	if not selectedTitle then
		if titleCount == 0 then
			self.titleValueLabel.Text = "No title unlocked yet"
		else
			self.titleValueLabel.Text = "Selected: No Title"
		end
		self.titleValueLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	else
		local classDef = ClassTypes.getClass(selectedTitle.classId)
		local className = classDef and classDef.name or selectedTitle.classId
		local theme = getTitleTheme(selectedTitle.rarity, classDef and classDef.color or nil)
		self.titleValueLabel.Text = string.format("Selected: [%s] %s (%s Lv.%d)", selectedTitle.rarity, selectedTitle.name, className, selectedTitle.level)
		self.titleValueLabel.TextColor3 = theme.textColor
	end

	if not selectedTitle then
		if activeTitleId then
			self.equipTitleButton.Text = "UNEQUIP TITLE"
			self.equipTitleButton.Active = true
			self.equipTitleButton.AutoButtonColor = true
			self.equipTitleButton.BackgroundColor3 = Color3.fromRGB(135, 90, 70)
		else
			self.equipTitleButton.Text = if titleCount == 0 then "NO TITLE UNLOCKED" else "NO TITLE"
			self.equipTitleButton.Active = false
			self.equipTitleButton.AutoButtonColor = false
			self.equipTitleButton.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
		end
		else
			local isActive = activeTitleId == selectedTitle.id
			local classDef = ClassTypes.getClass(selectedTitle.classId)
			local theme = getTitleTheme(selectedTitle.rarity, classDef and classDef.color or nil)
			if isActive then
				self.equipTitleButton.Text = "TITLE EQUIPPED"
				self.equipTitleButton.Active = false
				self.equipTitleButton.AutoButtonColor = false
				self.equipTitleButton.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
			else
				self.equipTitleButton.Text = "EQUIP TITLE"
				self.equipTitleButton.Active = true
				self.equipTitleButton.AutoButtonColor = true
				self.equipTitleButton.BackgroundColor3 = theme.frameColor
			end
		end
end

function ClassSelectionUI:confirmTitleSelection()
	if not self.equipTitleButton or not self.equipTitleButton.Active then
		return
	end

	local selectedTitle = self:getSelectedTitleEntry()
	local titleId = selectedTitle and selectedTitle.id or ""
	self.remotes.SetActiveTitle:FireServer(titleId)
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
		self.rewardsBody.TextColor3 = Color3.fromRGB(210, 210, 210)
		return
	end

	local unlockedCount = 0
	local firstLockedReward = nil
	local lines = {}

	for _, reward in ipairs(rewards) do
		if reward.unlocked then
			unlockedCount += 1
		elseif not firstLockedReward then
			firstLockedReward = reward
		end

		local status = if reward.unlocked then "Unlocked" else "Locked"
		table.insert(lines, string.format("Lv.%d %s: %s (%s)", reward.level, reward.rewardType, reward.name, status))
	end

	self.rewardsTitle.Text = string.format("MASTERY REWARDS (%d/%d)", unlockedCount, #rewards)

	local previewLines = {}
	if firstLockedReward then
		table.insert(previewLines, string.format("Next: Lv.%d %s - %s", firstLockedReward.level, firstLockedReward.rewardType, firstLockedReward.name))
	else
		table.insert(previewLines, "All mastery rewards unlocked for this class.")
	end

	for index = 1, math.min(2, #lines) do
		table.insert(previewLines, lines[index])
	end

	self.rewardsBody.Text = table.concat(previewLines, "\n")
	self.rewardsBody.TextColor3 = Color3.fromRGB(230, 230, 230)
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

	self:showToast(string.format("%s reward unlocked: %s", className, table.concat(rewardNames, ", ")), Color3.fromRGB(255, 215, 130))
end

function ClassSelectionUI:refreshClassStates()
	if not ClassTypes.getClass(self.selectedClass) then
		self.selectedClass = self.currentClass
	end

	for classId, buttonData in pairs(self.classButtons) do
		local isSelected = self.selectedClass == classId
		local isEquipped = self.currentClass == classId
		local isUnlocked = self:isClassUnlocked(classId)
		local classCost = self:getClassCost(classId)
		local isAffordable = self:isClassAffordable(classId)
		local masteryInfo = self.classMastery[classId]

		if isSelected then
			buttonData.stroke.Color = buttonData.color
			buttonData.stroke.Thickness = 4
			buttonData.button.BackgroundTransparency = 0.1
		elseif isUnlocked then
			buttonData.stroke.Color = Color3.fromRGB(80, 80, 80)
			buttonData.stroke.Thickness = 2
			buttonData.button.BackgroundTransparency = 0.25
		elseif isAffordable then
			buttonData.stroke.Color = Color3.fromRGB(200, 170, 80)
			buttonData.stroke.Thickness = 2
			buttonData.button.BackgroundTransparency = 0.35
		else
			buttonData.stroke.Color = Color3.fromRGB(120, 70, 70)
			buttonData.stroke.Thickness = 2
			buttonData.button.BackgroundTransparency = 0.45
		end

		if isEquipped then
			buttonData.statusLabel.Text = "EQUIPPED"
			buttonData.statusLabel.TextColor3 = Color3.fromRGB(120, 255, 140)
		elseif isUnlocked then
			buttonData.statusLabel.Text = "UNLOCKED"
			buttonData.statusLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
		elseif isAffordable then
			buttonData.statusLabel.Text = "CAN BUY"
			buttonData.statusLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
		else
			buttonData.statusLabel.Text = "LOCKED"
			buttonData.statusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
		end

		local masteryLevel = masteryInfo and masteryInfo.level or 1
		local masteryXp = masteryInfo and masteryInfo.xp or 0
		local masteryXpToNext = masteryInfo and masteryInfo.xpToNext or 0
		local masteryIsMax = masteryInfo and masteryInfo.isMax or false

		if masteryIsMax then
			buttonData.masteryLabel.Text = string.format("Mastery Lv.%d (MAX)", masteryLevel)
			buttonData.masteryLabel.TextColor3 = Color3.fromRGB(255, 215, 120)
		elseif masteryXpToNext > 0 then
			buttonData.masteryLabel.Text = string.format("Mastery Lv.%d (%d/%d)", masteryLevel, masteryXp, masteryXpToNext)
			buttonData.masteryLabel.TextColor3 = Color3.fromRGB(170, 220, 255)
		else
			buttonData.masteryLabel.Text = string.format("Mastery Lv.%d", masteryLevel)
			buttonData.masteryLabel.TextColor3 = Color3.fromRGB(170, 220, 255)
		end

		if not isUnlocked and classCost > 0 then
			buttonData.costLabel.Text = "Cost: " .. tostring(classCost)
		else
			buttonData.costLabel.Text = ""
		end
	end

	local selectedClass = self.selectedClass
	local selectedUnlocked = self:isClassUnlocked(selectedClass)
	local selectedCost = self:getClassCost(selectedClass)
	local selectedAffordable = self:isClassAffordable(selectedClass)

	if selectedUnlocked then
		if selectedClass == self.currentClass then
			self:setConfirmButtonState("EQUIPPED", false)
		else
			self:setConfirmButtonState("EQUIP", true)
		end
	elseif selectedAffordable then
		self:setConfirmButtonState(string.format("BUY & EQUIP (%d)", selectedCost), true)
	else
		self:setConfirmButtonState(string.format("NOT ENOUGH (%d)", selectedCost), false)
	end

	self:updateRewardsPreview()
	self:updateTitleSelector()
end

function ClassSelectionUI:showToast(text: string, color: Color3?)
	if self.activeToast and self.activeToast.Parent then
		self.activeToast:Destroy()
	end

	local toast = Instance.new("TextLabel")
	toast.Name = "ClassToast"
	toast.AnchorPoint = Vector2.new(0, 0)
	toast.Size = UDim2.new(0, 360, 0, 36)
	toast.Position = UDim2.new(0, 10, 0, 180)
	toast.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	toast.BackgroundTransparency = 0.15
	toast.BorderSizePixel = 0
	toast.Text = text
	toast.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	toast.TextSize = 16
	toast.Font = Enum.Font.GothamBold
	toast.TextTransparency = 1
	toast.Parent = self.parent
	self.activeToast = toast

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = toast

	TweenService:Create(toast, TweenInfo.new(0.15), {
		TextTransparency = 0,
	}):Play()

	task.delay(1.2, function()
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

function ClassSelectionUI:handleAction(action: {[string]: any})
	local actionType = action.type
	local classId = action.classId
	local classDef = ClassTypes.getClass(classId)
	local className = classDef and classDef.name or classId

	if actionType == "purchase" then
		local cost = tonumber(action.cost) or 0
		self:showToast(string.format("Purchased %s for %d!", className, cost), Color3.fromRGB(255, 230, 120))
		if self.isVisible then
			self:hide()
		end
	elseif actionType == "equip" then
		if classId == self.currentClass then
			self:showToast("Equipped " .. className, Color3.fromRGB(140, 220, 255))
			if self.isVisible then
				self:hide()
			end
		end
	elseif actionType == "error" then
		local reason = action.reason
		if reason == "INSUFFICIENT_FUNDS" then
			self:showToast("Not enough currency for this class", Color3.fromRGB(255, 140, 140))
		elseif reason == "RATE_LIMIT" then
			self:showToast("Please wait a moment before trying again", Color3.fromRGB(255, 200, 120))
		elseif reason == "ALREADY_UNLOCKED" then
			self:showToast("Class already unlocked", Color3.fromRGB(255, 230, 120))
		elseif reason == "NOT_IN_LOBBY" then
			self:showToast("You can change class only in lobby", Color3.fromRGB(255, 180, 130))
		else
			self:showToast("Class selection failed", Color3.fromRGB(255, 140, 140))
		end
	end
end

function ClassSelectionUI:handleTitleAction(action: {[string]: any})
	local actionType = action.type
	if actionType == "equip" then
		if self.activeTitle and self.activeTitle.name then
			self:showToast("Title equipped: " .. self.activeTitle.name, Color3.fromRGB(255, 225, 140))
		else
			self:showToast("Title equipped", Color3.fromRGB(255, 225, 140))
		end
	elseif actionType == "clear" then
		self:showToast("Title unequipped", Color3.fromRGB(210, 210, 210))
	elseif actionType == "unlock" then
		if type(action.unlockedTitles) == "table" and #action.unlockedTitles > 0 then
			local names = {}
			for _, title in ipairs(action.unlockedTitles) do
				if type(title) == "table" and type(title.name) == "string" then
					table.insert(names, title.name)
				end
			end
			if #names > 0 then
				self:showToast("Unlocked title: " .. table.concat(names, ", "), Color3.fromRGB(255, 220, 140))
			end
		end
	elseif actionType == "error" then
		local reason = action.reason
		if reason == "TITLE_LOCKED" then
			self:showToast("Title is not unlocked yet", Color3.fromRGB(255, 140, 140))
		elseif reason == "INVALID_TITLE" then
			self:showToast("Invalid title selection", Color3.fromRGB(255, 140, 140))
		else
			self:showToast("Failed to equip title", Color3.fromRGB(255, 140, 140))
		end
	end
end

function ClassSelectionUI:selectClass(classId: string)
	if not ClassTypes.getClass(classId) then
		return
	end

	self.selectedClass = classId
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
end

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
			self:showToast(string.format("%s Mastery Lv.%d!", className, level), Color3.fromRGB(255, 230, 120))

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

		self:setTitleSelectionIndexById(self.activeTitle and self.activeTitle.id or nil)

		if type(data.action) == "table" then
			self:handleTitleAction(data.action)
		end

		self:refreshClassStates()
	end)
end

function ClassSelectionUI:show()
	self.isVisible = true
	self.container.Visible = true

	self.container.Position = UDim2.new(0.5, 0, 0.5, 50)
	self.container.BackgroundTransparency = 1

	TweenService:Create(self.container, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 0.1,
	}):Play()

	self:refreshClassStates()
end

function ClassSelectionUI:hide()
	self.isVisible = false

	TweenService:Create(self.container, TweenInfo.new(0.2), {
		Position = UDim2.new(0.5, 0, 0.5, 50),
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
