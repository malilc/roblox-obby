-- TitleCollectionUI: หน้าแสดงรายการ Title ทั้งหมด (ปลดล็อก/ยังล็อก) และเลือก Active Title

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ClassTypes = require(ReplicatedStorage.Shared.ClassTypes)
local Config = require(ReplicatedStorage.Shared.Config)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local TitleCollectionUI = {}
TitleCollectionUI.__index = TitleCollectionUI

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
		unlocked = source.unlocked == true,
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

function TitleCollectionUI.new(parent: ScreenGui)
	local self = setmetatable({}, TitleCollectionUI)

	self.parent = parent
	self.remotes = Remotes
	self.isVisible = false
	self.titleCatalog = {}
	self.activeTitle = nil
	self.activeFilter = FILTER_ALL
	self.activeSort = SORT_CLASS
	self.searchText = ""
	self.filterButtons = {}
	self.activeToast = nil
	self.lastRenderedCount = nil
	self.lastRenderedTotal = nil

	self:createUI()
	self:setupRemotes()
	self:updateActiveTitleLabel()
	self:updateFilterButtons()
	self:updateSortButton()
	self:updateSearchClearButtonState()
	self:rebuildEntries()

	return self
end

function TitleCollectionUI:createUI()
	local container = Instance.new("Frame")
	container.Name = "TitleCollectionContainer"
	container.Size = UDim2.new(0, 660, 0, 460)
	container.Position = UDim2.new(0.5, 0, 0.5, 30)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
	container.BackgroundTransparency = 0.08
	container.BorderSizePixel = 0
	container.Visible = false
	container.Parent = self.parent
	self.container = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = container

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(130, 130, 165)
	stroke.Thickness = 1.5
	stroke.Parent = container

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, -110, 0, 42)
	header.Position = UDim2.new(0, 16, 0, 12)
	header.BackgroundTransparency = 1
	header.Text = "TITLE COLLECTION"
	header.TextColor3 = Color3.fromRGB(255, 255, 255)
	header.TextSize = 24
	header.Font = Enum.Font.GothamBlack
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = container

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 86, 0, 32)
	closeButton.Position = UDim2.new(1, -98, 0, 14)
	closeButton.BackgroundColor3 = Color3.fromRGB(80, 60, 60)
	closeButton.BorderSizePixel = 0
	closeButton.Text = "CLOSE"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextSize = 13
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = container
	self.closeButton = closeButton

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 7)
	closeCorner.Parent = closeButton

	local activeLabel = Instance.new("TextLabel")
	activeLabel.Name = "ActiveTitleLabel"
	activeLabel.Size = UDim2.new(1, -220, 0, 28)
	activeLabel.Position = UDim2.new(0, 16, 0, 54)
	activeLabel.BackgroundTransparency = 1
	activeLabel.Text = "Active: No Title"
	activeLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
	activeLabel.TextSize = 15
	activeLabel.Font = Enum.Font.GothamBold
	activeLabel.TextXAlignment = Enum.TextXAlignment.Left
	activeLabel.TextTruncate = Enum.TextTruncate.AtEnd
	activeLabel.Parent = container
	self.activeLabel = activeLabel

	local clearButton = Instance.new("TextButton")
	clearButton.Name = "ClearTitleButton"
	clearButton.Size = UDim2.new(0, 180, 0, 28)
	clearButton.Position = UDim2.new(1, -196, 0, 54)
	clearButton.BackgroundColor3 = Color3.fromRGB(105, 75, 65)
	clearButton.BorderSizePixel = 0
	clearButton.Text = "UNEQUIP ACTIVE TITLE"
	clearButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	clearButton.TextSize = 12
	clearButton.Font = Enum.Font.GothamBold
	clearButton.Parent = container
	self.clearButton = clearButton

	local clearCorner = Instance.new("UICorner")
	clearCorner.CornerRadius = UDim.new(0, 7)
	clearCorner.Parent = clearButton

	local searchBox = Instance.new("TextBox")
	searchBox.Name = "SearchBox"
	searchBox.Size = UDim2.new(1, -116, 0, 28)
	searchBox.Position = UDim2.new(0, 12, 0, 86)
	searchBox.BackgroundColor3 = Color3.fromRGB(34, 34, 48)
	searchBox.BackgroundTransparency = 0.15
	searchBox.BorderSizePixel = 0
	searchBox.PlaceholderText = "Search title, class, rarity..."
	searchBox.Text = ""
	searchBox.TextColor3 = Color3.fromRGB(245, 245, 245)
	searchBox.PlaceholderColor3 = Color3.fromRGB(160, 160, 175)
	searchBox.TextSize = 13
	searchBox.Font = Enum.Font.Gotham
	searchBox.ClearTextOnFocus = false
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.Parent = container
	self.searchBox = searchBox

	local searchCorner = Instance.new("UICorner")
	searchCorner.CornerRadius = UDim.new(0, 8)
	searchCorner.Parent = searchBox

	local clearSearchButton = Instance.new("TextButton")
	clearSearchButton.Name = "ClearSearchButton"
	clearSearchButton.Size = UDim2.new(0, 84, 0, 28)
	clearSearchButton.Position = UDim2.new(1, -96, 0, 86)
	clearSearchButton.BackgroundColor3 = Color3.fromRGB(82, 82, 94)
	clearSearchButton.BorderSizePixel = 0
	clearSearchButton.Text = "CLEAR"
	clearSearchButton.TextColor3 = Color3.fromRGB(245, 245, 245)
	clearSearchButton.TextSize = 12
	clearSearchButton.Font = Enum.Font.GothamBold
	clearSearchButton.Parent = container
	self.clearSearchButton = clearSearchButton

	local clearSearchCorner = Instance.new("UICorner")
	clearSearchCorner.CornerRadius = UDim.new(0, 8)
	clearSearchCorner.Parent = clearSearchButton

	local filterBar = Instance.new("Frame")
	filterBar.Name = "FilterBar"
	filterBar.Size = UDim2.new(1, -24, 0, 24)
	filterBar.Position = UDim2.new(0, 12, 0, 120)
	filterBar.BackgroundTransparency = 1
	filterBar.Parent = container

	local function createFilterButton(label: string, position: UDim2, size: UDim2)
		local button = Instance.new("TextButton")
		button.Name = "Filter" .. label
		button.Size = size
		button.Position = position
		button.BackgroundColor3 = Color3.fromRGB(60, 60, 78)
		button.BorderSizePixel = 0
		button.Text = label
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.TextSize = 12
		button.Font = Enum.Font.GothamBold
		button.Parent = filterBar

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = button

		return button
	end

	self.filterButtons[FILTER_ALL] = createFilterButton(FILTER_ALL, UDim2.new(0, 0, 0, 0), UDim2.new(0, 72, 1, 0))
	self.filterButtons[FILTER_UNLOCKED] = createFilterButton(FILTER_UNLOCKED, UDim2.new(0, 80, 0, 0), UDim2.new(0, 96, 1, 0))
	self.filterButtons[FILTER_LOCKED] = createFilterButton(FILTER_LOCKED, UDim2.new(0, 184, 0, 0), UDim2.new(0, 80, 1, 0))

	local sortButton = Instance.new("TextButton")
	sortButton.Name = "SortButton"
	sortButton.Size = UDim2.new(0, 120, 1, 0)
	sortButton.Position = UDim2.new(0, 274, 0, 0)
	sortButton.BackgroundColor3 = Color3.fromRGB(58, 84, 130)
	sortButton.BorderSizePixel = 0
	sortButton.Text = "SORT: CLASS"
	sortButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	sortButton.TextSize = 12
	sortButton.Font = Enum.Font.GothamBold
	sortButton.Parent = filterBar
	self.sortButton = sortButton

	local sortCorner = Instance.new("UICorner")
	sortCorner.CornerRadius = UDim.new(0, 6)
	sortCorner.Parent = sortButton

	local resultLabel = Instance.new("TextLabel")
	resultLabel.Name = "ResultLabel"
	resultLabel.Size = UDim2.new(1, -402, 1, 0)
	resultLabel.Position = UDim2.new(0, 402, 0, 0)
	resultLabel.BackgroundTransparency = 1
	resultLabel.Text = "0 / 0"
	resultLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	resultLabel.TextSize = 12
	resultLabel.Font = Enum.Font.Gotham
	resultLabel.TextXAlignment = Enum.TextXAlignment.Right
	resultLabel.Parent = filterBar
	self.resultLabel = resultLabel

	local listFrame = Instance.new("ScrollingFrame")
	listFrame.Name = "TitleList"
	listFrame.Size = UDim2.new(1, -24, 1, -156)
	listFrame.Position = UDim2.new(0, 12, 0, 146)
	listFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
	listFrame.BackgroundTransparency = 0.2
	listFrame.BorderSizePixel = 0
	listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	listFrame.ScrollBarThickness = 8
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
	listFrame.Parent = container
	self.listFrame = listFrame

	local listCorner = Instance.new("UICorner")
	listCorner.CornerRadius = UDim.new(0, 10)
	listCorner.Parent = listFrame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = listFrame
	self.listLayout = layout

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 8)
	listPadding.PaddingBottom = UDim.new(0, 8)
	listPadding.PaddingLeft = UDim.new(0, 8)
	listPadding.PaddingRight = UDim.new(0, 8)
	listPadding.Parent = listFrame

	local emptyLabel = Instance.new("TextLabel")
	emptyLabel.Name = "EmptyLabel"
	emptyLabel.Size = UDim2.new(1, -18, 0, 0)
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.Text = "No titles available yet"
	emptyLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	emptyLabel.TextSize = 15
	emptyLabel.Font = Enum.Font.Gotham
	emptyLabel.Visible = false
	emptyLabel.Parent = listFrame
	self.emptyLabel = emptyLabel

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self.listFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16)
	end)

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

	clearButton.MouseButton1Click:Connect(function()
		if self.activeTitle then
			self.remotes.SetActiveTitle:FireServer("")
		end
	end)
end

function TitleCollectionUI:updateFilterButtons()
	for filterId, button in pairs(self.filterButtons) do
		local isSelected = filterId == self.activeFilter
		button.BackgroundColor3 = if isSelected then Color3.fromRGB(95, 145, 230) else Color3.fromRGB(60, 60, 78)
		button.TextColor3 = if isSelected then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(220, 220, 225)
	end
end

function TitleCollectionUI:updateSortButton()
	if not self.sortButton then
		return
	end

	self.sortButton.Text = "SORT: " .. string.upper(self.activeSort)
end

function TitleCollectionUI:updateSearchClearButtonState()
	if not self.clearSearchButton then
		return
	end

	local hasSearchText = self.searchText ~= ""
	self.clearSearchButton.Active = hasSearchText
	self.clearSearchButton.AutoButtonColor = hasSearchText
	self.clearSearchButton.BackgroundColor3 = if hasSearchText then Color3.fromRGB(105, 105, 122) else Color3.fromRGB(70, 70, 82)
	self.clearSearchButton.TextColor3 = if hasSearchText then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(180, 180, 190)
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
	local titleName = string.lower(entry.name)
	local rarity = string.lower(entry.rarity)
	local description = string.lower(entry.description or "")

	return string.find(titleName, query, 1, true) ~= nil
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

function TitleCollectionUI:getFilteredCatalog(): {{id: string, name: string, classId: string, level: number, rarity: string, description: string?, unlocked: boolean}}
	local filtered = {}
	local classOrderIndex = {} :: {[string]: number}
	for index, classId in ipairs(ClassTypes.getAllClassIds()) do
		classOrderIndex[classId] = index
	end

	for _, entry in ipairs(self.titleCatalog) do
		if self:matchesFilter(entry) then
			table.insert(filtered, entry)
		end
	end

	table.sort(filtered, function(a, b)
		return self:compareBySort(a, b, classOrderIndex)
	end)

	return filtered
end

function TitleCollectionUI:updateActiveTitleLabel()
	if not self.activeLabel then
		return
	end

	if not self.activeTitle then
		self.activeLabel.Text = "Active: No Title"
		self.activeLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
		self.activeLabel.TextStrokeTransparency = 0.4
		self.activeLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		if self.clearButton then
			self.clearButton.Active = false
			self.clearButton.AutoButtonColor = false
			self.clearButton.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
		end
		return
	end

	local classDef = ClassTypes.getClass(self.activeTitle.classId)
	local theme = getTitleTheme(self.activeTitle.rarity, classDef and classDef.color or nil)

	self.activeLabel.Text = string.format("Active: [%s] %s", self.activeTitle.rarity, self.activeTitle.name)
	self.activeLabel.TextColor3 = theme.textColor
	self.activeLabel.TextStrokeTransparency = 0.35
	self.activeLabel.TextStrokeColor3 = theme.strokeColor

	if self.clearButton then
		self.clearButton.Active = true
		self.clearButton.AutoButtonColor = true
		self.clearButton.BackgroundColor3 = Color3.fromRGB(115, 85, 70)
	end
end

function TitleCollectionUI:clearEntryFrames()
	for _, child in ipairs(self.listFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name == "TitleEntry" then
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
	toast.Size = UDim2.new(0, 250, 0, 28)
	toast.Position = UDim2.new(1, -262, 0, 146)
	toast.BackgroundColor3 = Color3.fromRGB(26, 26, 36)
	toast.BackgroundTransparency = 0.18
	toast.BorderSizePixel = 0
	toast.Text = text
	toast.TextColor3 = color or Color3.fromRGB(235, 235, 245)
	toast.TextSize = 12
	toast.Font = Enum.Font.GothamBold
	toast.TextTransparency = 1
	toast.Parent = self.container
	self.activeToast = toast

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = toast

	TweenService:Create(toast, TweenInfo.new(0.12), {
		TextTransparency = 0,
	}):Play()

	task.delay(1.0, function()
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

	local filteredCatalog = self:getFilteredCatalog()
	if self.resultLabel then
		self.resultLabel.Text = string.format("%d / %d", #filteredCatalog, #self.titleCatalog)
	end

	local filteredCount = #filteredCatalog
	local totalCount = #self.titleCatalog
	if showFeedback and self.isVisible then
		local resultChanged = self.lastRenderedCount ~= filteredCount or self.lastRenderedTotal ~= totalCount
		if resultChanged then
			if filteredCount == 0 then
				local sourceLabel = if feedbackSource == "search" then "search"
					elseif feedbackSource == "filter" then "filter"
					elseif feedbackSource == "sort" then "sort"
					else "selection"
				self:showToast("No titles found for current " .. sourceLabel, Color3.fromRGB(255, 205, 145))
			else
				self:showToast(string.format("Showing %d of %d titles", filteredCount, totalCount), Color3.fromRGB(175, 225, 255))
			end
		end
	end

	self.lastRenderedCount = filteredCount
	self.lastRenderedTotal = totalCount

	if #self.titleCatalog == 0 then
		self.emptyLabel.Visible = true
		self.emptyLabel.LayoutOrder = 1
		self.emptyLabel.Size = UDim2.new(1, -18, 0, 30)
		self.emptyLabel.Text = "No titles available yet"
		return
	end

	if #filteredCatalog == 0 then
		self.emptyLabel.Visible = true
		self.emptyLabel.LayoutOrder = 1
		self.emptyLabel.Size = UDim2.new(1, -18, 0, 30)
		self.emptyLabel.Text = "No titles match current filter/search"
		return
	end

	self.emptyLabel.Visible = false
	self.emptyLabel.Size = UDim2.new(1, -18, 0, 0)

	local activeId = self.activeTitle and self.activeTitle.id or nil
	for index, entry in ipairs(filteredCatalog) do
		local classDef = ClassTypes.getClass(entry.classId)
		local className = classDef and classDef.name or entry.classId
		local theme = getTitleTheme(entry.rarity, classDef and classDef.color or nil)

		local card = Instance.new("Frame")
		card.Name = "TitleEntry"
		card.Size = UDim2.new(1, -8, 0, 88)
		card.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
		card.BackgroundTransparency = if entry.unlocked then 0.1 else 0.35
		card.BorderSizePixel = 0
		card.LayoutOrder = index
		card.Parent = self.listFrame

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 8)
		cardCorner.Parent = card

		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = if entry.unlocked then theme.frameColor else Color3.fromRGB(90, 90, 90)
		cardStroke.Thickness = 1.5
		cardStroke.Transparency = if entry.unlocked then 0.15 else 0.35
		cardStroke.Parent = card

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size = UDim2.new(1, -150, 0, 24)
		titleLabel.Position = UDim2.new(0, 10, 0, 8)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = string.format("[%s] %s", entry.rarity, entry.name)
		titleLabel.TextColor3 = if entry.unlocked then theme.textColor else Color3.fromRGB(170, 170, 170)
		titleLabel.TextStrokeTransparency = 0.35
		titleLabel.TextStrokeColor3 = if entry.unlocked then theme.strokeColor else Color3.fromRGB(40, 40, 40)
		titleLabel.TextSize = 16
		titleLabel.Font = Enum.Font.GothamBold
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.Parent = card

		local detailLabel = Instance.new("TextLabel")
		detailLabel.Size = UDim2.new(1, -150, 0, 20)
		detailLabel.Position = UDim2.new(0, 10, 0, 32)
		detailLabel.BackgroundTransparency = 1
		detailLabel.Text = string.format("%s | Lv.%d | %s", className, entry.level, if entry.unlocked then "Unlocked" else "Locked")
		detailLabel.TextColor3 = if entry.unlocked then Color3.fromRGB(205, 205, 220) else Color3.fromRGB(160, 130, 130)
		detailLabel.TextSize = 13
		detailLabel.Font = Enum.Font.Gotham
		detailLabel.TextXAlignment = Enum.TextXAlignment.Left
		detailLabel.Parent = card

		local description = entry.description or "No description"
		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(1, -150, 0, 28)
		descLabel.Position = UDim2.new(0, 10, 0, 52)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = description
		descLabel.TextColor3 = if entry.unlocked then Color3.fromRGB(175, 175, 190) else Color3.fromRGB(145, 145, 155)
		descLabel.TextSize = 12
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.TextWrapped = true
		descLabel.Parent = card

		local actionButton = Instance.new("TextButton")
		actionButton.Size = UDim2.new(0, 124, 0, 32)
		actionButton.Position = UDim2.new(1, -134, 0.5, -16)
		actionButton.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
		actionButton.BorderSizePixel = 0
		actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		actionButton.TextSize = 12
		actionButton.Font = Enum.Font.GothamBold
		actionButton.Parent = card

		local actionCorner = Instance.new("UICorner")
		actionCorner.CornerRadius = UDim.new(0, 7)
		actionCorner.Parent = actionButton

		if not entry.unlocked then
			actionButton.Text = "LOCKED"
			actionButton.Active = false
			actionButton.AutoButtonColor = false
			actionButton.BackgroundColor3 = Color3.fromRGB(85, 70, 70)
		else
			local isActive = activeId == entry.id
			if isActive then
				actionButton.Text = "UNEQUIP"
				actionButton.Active = true
				actionButton.AutoButtonColor = true
				actionButton.BackgroundColor3 = Color3.fromRGB(125, 85, 70)
			else
				actionButton.Text = "EQUIP"
				actionButton.Active = true
				actionButton.AutoButtonColor = true
				actionButton.BackgroundColor3 = theme.frameColor
			end

			actionButton.MouseButton1Click:Connect(function()
				if self.activeTitle and self.activeTitle.id == entry.id then
					self.remotes.SetActiveTitle:FireServer("")
				else
					self.remotes.SetActiveTitle:FireServer(entry.id)
				end
			end)
		end
	end
end

function TitleCollectionUI:applyTitleUpdatePayload(data: {[string]: any})
	if type(data.titleCatalog) == "table" then
		self.titleCatalog = cloneTitleList(data.titleCatalog)
	elseif type(data.unlockedTitles) == "table" then
		local fallbackCatalog = cloneTitleList(data.unlockedTitles)
		for _, entry in ipairs(fallbackCatalog) do
			entry.unlocked = true
		end
		self.titleCatalog = fallbackCatalog
	end

	if data.activeTitle == nil then
		self.activeTitle = nil
	else
		self.activeTitle = cloneTitleEntry(data.activeTitle)
	end

	self:updateActiveTitleLabel()
	self:rebuildEntries()
end

function TitleCollectionUI:setupRemotes()
	self.remotes.TitleUpdate.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end

		self:applyTitleUpdatePayload(data)
	end)
end

function TitleCollectionUI:show()
	if self.isVisible then
		return
	end

	self.isVisible = true
	self.container.Visible = true
	self.container.Position = UDim2.new(0.5, 0, 0.5, 24)
	self.container.BackgroundTransparency = 0.45

	TweenService:Create(self.container, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 0.08,
	}):Play()
end

function TitleCollectionUI:hide()
	if not self.isVisible then
		return
	end

	self.isVisible = false
	local tween = TweenService:Create(self.container, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, 0, 0.5, 24),
		BackgroundTransparency = 0.5,
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
