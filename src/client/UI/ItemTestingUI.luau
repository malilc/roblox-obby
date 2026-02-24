-- ItemTestingUI: Testing menu for selecting items (Development only)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ItemTypes = require(ReplicatedStorage.Shared.ItemTypes)
local ClassTypes = require(ReplicatedStorage.Shared.ClassTypes)
local Logger = require(ReplicatedStorage.Shared.Logger)
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)

local LocalPlayer = Players.LocalPlayer

local ItemTestingUI = {}
ItemTestingUI.__index = ItemTestingUI

function ItemTestingUI.new()
	local self = setmetatable({}, ItemTestingUI)

	self.visible = false
	self.mainFrame = nil
	self.toggleButton = nil
	self.soloWinsEnabled = false
	self.masteryLevels = {}
	self.classEntries = {}

	self:createUI()
	self:setupMasteryRemotes()

	return self
end

function ItemTestingUI:createUI()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	-- Screen GUI
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ItemTestingUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 50
	screenGui.Parent = playerGui
	self.screenGui = screenGui

	-- Toggle button (top right)
	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "ToggleButton"
	toggleButton.Size = UDim2.new(0, 120, 0, 35)
	toggleButton.Position = UDim2.new(1, -130, 0, 10)
	toggleButton.BackgroundColor3 = Theme.DANGER
	toggleButton.Text = "🧪 Testing"
	toggleButton.TextColor3 = Theme.TEXT_PRIMARY
	toggleButton.TextSize = 14
	toggleButton.Font = Enum.Font.GothamBold
	toggleButton.Parent = screenGui
	self.toggleButton = toggleButton

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = Theme.CORNER_SM
	toggleCorner.Parent = toggleButton

	-- Main panel
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainPanel"
	mainFrame.Size = UDim2.new(0, 300, 0, 400)
	mainFrame.Position = UDim2.new(1, -310, 0, 55)
	mainFrame.BackgroundColor3 = Theme.BG_BASE
	mainFrame.BackgroundTransparency = 0.1
	mainFrame.Visible = false
	mainFrame.Parent = screenGui
	self.mainFrame = mainFrame

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = Theme.CORNER_MD
	mainCorner.Parent = mainFrame

	-- Gradient background
	local mainGradient = Instance.new("UIGradient")
	mainGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.BG_SURFACE),
		ColorSequenceKeypoint.new(1, Theme.BG_BASE)
	})
	mainGradient.Rotation = 135
	mainGradient.Parent = mainFrame

	local mainStroke = Instance.new("UIStroke")
	mainStroke.Color = Theme.DANGER
	mainStroke.Thickness = Theme.STROKE_MED
	mainStroke.Transparency = 0.2
	mainStroke.Parent = mainFrame

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "🧪 Testing Menu"
	title.TextColor3 = Theme.DANGER
	title.TextSize = 18
	title.Font = Enum.Font.GothamBold
	title.Parent = mainFrame

	-- Scrolling frame for items
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ItemList"
	scrollFrame.Size = UDim2.new(1, -20, 1, -50)
	scrollFrame.Position = UDim2.new(0, 10, 0, 45)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.ScrollBarImageColor3 = Theme.DANGER
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.Parent = mainFrame
	self.scrollFrame = scrollFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scrollFrame

	-- Create item buttons
	self:createItemButtons()

	-- Update canvas size
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
	end)

	-- Toggle button click
	toggleButton.MouseButton1Click:Connect(function()
		self:toggle()
	end)
end

function ItemTestingUI:createItemButtons()
	local layoutOrder = 0

	-- Group by rarity
	local rarities = {"Common", "Uncommon", "Rare", "Epic"}

	for _, rarity in ipairs(rarities) do
		-- Rarity header
		local header = Instance.new("TextLabel")
		header.Name = rarity .. "Header"
		header.Size = UDim2.new(1, 0, 0, 25)
		header.BackgroundTransparency = 1
		header.Text = "── " .. rarity .. " ──"
		header.TextColor3 = ItemTypes.getRarityColor(rarity)
		header.TextSize = 14
		header.Font = Enum.Font.GothamBold
		header.LayoutOrder = layoutOrder
		header.Parent = self.scrollFrame
		layoutOrder = layoutOrder + 1

		-- Items in this rarity
		for itemId, itemDef in pairs(ItemTypes.Items) do
			if itemDef.rarity == rarity then
				local button = self:createItemButton(itemDef, layoutOrder)
				layoutOrder = layoutOrder + 1
			end
		end
	end

	-- === Tools Section ===
	local separator = Instance.new("TextLabel")
	separator.Name = "Separator"
	separator.Size = UDim2.new(1, 0, 0, 25)
	separator.BackgroundTransparency = 1
	separator.Text = "── Tools ──"
	separator.TextColor3 = Theme.PRIMARY
	separator.TextSize = 14
	separator.Font = Enum.Font.GothamBold
	separator.LayoutOrder = layoutOrder + 50
	separator.Parent = self.scrollFrame

	-- Spawn Dummy button
	local spawnDummyButton = Instance.new("TextButton")
	spawnDummyButton.Name = "SpawnDummyButton"
	spawnDummyButton.Size = UDim2.new(1, 0, 0, 45)
	spawnDummyButton.BackgroundColor3 = Theme.BG_ELEVATED
	spawnDummyButton.Text = "🤖 Spawn Test Dummy"
	spawnDummyButton.TextColor3 = Theme.TEXT_PRIMARY
	spawnDummyButton.TextSize = 15
	spawnDummyButton.Font = Enum.Font.GothamBold
	spawnDummyButton.LayoutOrder = layoutOrder + 51
	spawnDummyButton.Parent = self.scrollFrame

	local spawnCorner = Instance.new("UICorner")
	spawnCorner.CornerRadius = Theme.CORNER_SM
	spawnCorner.Parent = spawnDummyButton

	spawnDummyButton.MouseButton1Click:Connect(function()
		self:spawnDummy()
		self:playClickEffect(spawnDummyButton)
	end)

	-- Remove Dummy button
	local removeDummyButton = Instance.new("TextButton")
	removeDummyButton.Name = "RemoveDummyButton"
	removeDummyButton.Size = UDim2.new(1, 0, 0, 45)
	removeDummyButton.BackgroundColor3 = Theme.BG_ELEVATED
	removeDummyButton.Text = "❌ Remove All Dummies"
	removeDummyButton.TextColor3 = Theme.TEXT_PRIMARY
	removeDummyButton.TextSize = 15
	removeDummyButton.Font = Enum.Font.GothamBold
	removeDummyButton.LayoutOrder = layoutOrder + 52
	removeDummyButton.Parent = self.scrollFrame

	local removeCorner = Instance.new("UICorner")
	removeCorner.CornerRadius = Theme.CORNER_SM
	removeCorner.Parent = removeDummyButton

	removeDummyButton.MouseButton1Click:Connect(function()
		self:removeDummies()
		self:playClickEffect(removeDummyButton)
	end)

	-- Clear items button
	local clearButton = Instance.new("TextButton")
	clearButton.Name = "ClearButton"
	clearButton.Size = UDim2.new(1, 0, 0, 45)
	clearButton.BackgroundColor3 = Theme.BG_OVERLAY
	clearButton.Text = "🗑️ Clear All Items"
	clearButton.TextColor3 = Theme.TEXT_PRIMARY
	clearButton.TextSize = 15
	clearButton.Font = Enum.Font.GothamBold
	clearButton.LayoutOrder = layoutOrder + 100
	clearButton.Parent = self.scrollFrame

	local clearCorner = Instance.new("UICorner")
	clearCorner.CornerRadius = Theme.CORNER_SM
	clearCorner.Parent = clearButton

	clearButton.MouseButton1Click:Connect(function()
		self:clearItems()
	end)

	-- === Daily Login Section ===
	local dlSeparator = Instance.new("TextLabel")
	dlSeparator.Name = "DailySeparator"
	dlSeparator.Size = UDim2.new(1, 0, 0, 25)
	dlSeparator.BackgroundTransparency = 1
	dlSeparator.Text = "── Daily Login ──"
	dlSeparator.TextColor3 = Theme.PRIMARY
	dlSeparator.TextSize = 14
	dlSeparator.Font = Enum.Font.GothamBold
	dlSeparator.LayoutOrder = layoutOrder + 101
	dlSeparator.Parent = self.scrollFrame

	local dailyLoginBtn = Instance.new("TextButton")
	dailyLoginBtn.Name = "ResetDailyLoginBtn"
	dailyLoginBtn.Size = UDim2.new(1, 0, 0, 45)
	dailyLoginBtn.BackgroundColor3 = Theme.BG_ELEVATED
	dailyLoginBtn.Text = "\u{1F381} Reset Daily Login"
	dailyLoginBtn.TextColor3 = Theme.TEXT_PRIMARY
	dailyLoginBtn.TextSize = 15
	dailyLoginBtn.Font = Enum.Font.GothamBold
	dailyLoginBtn.LayoutOrder = layoutOrder + 102
	dailyLoginBtn.Parent = self.scrollFrame

	local dlCorner = Instance.new("UICorner")
	dlCorner.CornerRadius = Theme.CORNER_SM
	dlCorner.Parent = dailyLoginBtn

	dailyLoginBtn.MouseButton1Click:Connect(function()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if remotes then
			local resetRemote = remotes:FindFirstChild("ResetDailyLogin")
			if resetRemote then
				resetRemote:FireServer()
				self:playClickEffect(dailyLoginBtn)
				dailyLoginBtn.Text = "🎁 Resetting..."
				task.delay(2.5, function()
					dailyLoginBtn.Text = "🎁 Reset Daily Login"
				end)
			end
		end
	end)

	-- === Game Testing Section ===
	local soloSeparator = Instance.new("TextLabel")
	soloSeparator.Name = "SoloSeparator"
	soloSeparator.Size = UDim2.new(1, 0, 0, 25)
	soloSeparator.BackgroundTransparency = 1
	soloSeparator.Text = "── Game Testing ──"
	soloSeparator.TextColor3 = Theme.PRIMARY
	soloSeparator.TextSize = 14
	soloSeparator.Font = Enum.Font.GothamBold
	soloSeparator.LayoutOrder = layoutOrder + 200
	soloSeparator.Parent = self.scrollFrame

	-- Solo Wins Toggle
	local soloWinsBtn = Instance.new("TextButton")
	soloWinsBtn.Name = "SoloWinsBtn"
	soloWinsBtn.Size = UDim2.new(1, 0, 0, 45)
	soloWinsBtn.BackgroundColor3 = Theme.BG_ELEVATED
	soloWinsBtn.Text = "🏆 Solo Wins: OFF"
	soloWinsBtn.TextColor3 = Theme.TEXT_PRIMARY
	soloWinsBtn.TextSize = 15
	soloWinsBtn.Font = Enum.Font.GothamBold
	soloWinsBtn.LayoutOrder = layoutOrder + 201
	soloWinsBtn.Parent = self.scrollFrame

	local soloCorner = Instance.new("UICorner")
	soloCorner.CornerRadius = Theme.CORNER_SM
	soloCorner.Parent = soloWinsBtn

	soloWinsBtn.MouseButton1Click:Connect(function()
		self.soloWinsEnabled = not self.soloWinsEnabled
		if self.soloWinsEnabled then
			soloWinsBtn.Text = "🏆 Solo Wins: ON"
			soloWinsBtn.TextColor3 = Theme.MEDAL_GOLD
		else
			soloWinsBtn.Text = "🏆 Solo Wins: OFF"
			soloWinsBtn.TextColor3 = Theme.TEXT_PRIMARY
		end
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if remotes then
			local toggleRemote = remotes:FindFirstChild("ToggleSoloWins")
			if toggleRemote then
				toggleRemote:FireServer(self.soloWinsEnabled)
			end
		end
		self:playClickEffect(soloWinsBtn)
	end)

	-- Solo Start (Random) button
	local soloStartBtn = Instance.new("TextButton")
	soloStartBtn.Name = "SoloStartBtn"
	soloStartBtn.Size = UDim2.new(1, 0, 0, 45)
	soloStartBtn.BackgroundColor3 = Theme.BG_ELEVATED
	soloStartBtn.Text = "🚀 Solo Start (Random)"
	soloStartBtn.TextColor3 = Theme.TEXT_PRIMARY
	soloStartBtn.TextSize = 15
	soloStartBtn.Font = Enum.Font.GothamBold
	soloStartBtn.LayoutOrder = layoutOrder + 202
	soloStartBtn.Parent = self.scrollFrame

	local soloStartCorner = Instance.new("UICorner")
	soloStartCorner.CornerRadius = Theme.CORNER_SM
	soloStartCorner.Parent = soloStartBtn

	soloStartBtn.MouseButton1Click:Connect(function()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		if remotes then
			local confirmRemote = remotes:FindFirstChild("ConfirmStageSelection")
			if confirmRemote then
				confirmRemote:FireServer({ isRandom = true })
				self:playClickEffect(soloStartBtn)
				soloStartBtn.Text = "🚀 Starting..."
				task.delay(1, function()
					soloStartBtn.Text = "🚀 Solo Start (Random)"
				end)
			end
		end
	end)

	-- === Gems Section ===
	local gemSeparator = Instance.new("TextLabel")
	gemSeparator.Name = "GemSeparator"
	gemSeparator.Size = UDim2.new(1, 0, 0, 25)
	gemSeparator.BackgroundTransparency = 1
	gemSeparator.Text = "── Gems ──"
	gemSeparator.TextColor3 = Theme.HUD_GEM_START or Color3.fromRGB(180, 100, 255)
	gemSeparator.TextSize = 14
	gemSeparator.Font = Enum.Font.GothamBold
	gemSeparator.LayoutOrder = layoutOrder + 250
	gemSeparator.Parent = self.scrollFrame

	-- Gem display label
	local gemDisplayLabel = Instance.new("TextLabel")
	gemDisplayLabel.Name = "GemDisplayLabel"
	gemDisplayLabel.Size = UDim2.new(1, 0, 0, 25)
	gemDisplayLabel.BackgroundTransparency = 1
	gemDisplayLabel.Text = "💎 Gems: 0"
	gemDisplayLabel.TextColor3 = Theme.HUD_GEM_START or Color3.fromRGB(180, 100, 255)
	gemDisplayLabel.TextSize = 16
	gemDisplayLabel.Font = Enum.Font.GothamBold
	gemDisplayLabel.LayoutOrder = layoutOrder + 251
	gemDisplayLabel.Parent = self.scrollFrame
	self.gemDisplayLabel = gemDisplayLabel

	-- Gem amount buttons row
	local gemAmounts = {10, 100, 1000}
	for idx, amount in ipairs(gemAmounts) do
		local addGemBtn = Instance.new("TextButton")
		addGemBtn.Name = "AddGem" .. amount .. "Btn"
		addGemBtn.Size = UDim2.new(1, 0, 0, 38)
		addGemBtn.BackgroundColor3 = Theme.BG_ELEVATED
		addGemBtn.Text = "💎 +" .. amount .. " Gems"
		addGemBtn.TextColor3 = Theme.TEXT_PRIMARY
		addGemBtn.TextSize = 15
		addGemBtn.Font = Enum.Font.GothamBold
		addGemBtn.LayoutOrder = layoutOrder + 252 + idx
		addGemBtn.Parent = self.scrollFrame

		local addGemCorner = Instance.new("UICorner")
		addGemCorner.CornerRadius = Theme.CORNER_SM
		addGemCorner.Parent = addGemBtn

		addGemBtn.MouseButton1Click:Connect(function()
			self:setTestGems("add", amount)
			self:playClickEffect(addGemBtn)
		end)
	end

	-- Reset gems button
	local resetGemsBtn = Instance.new("TextButton")
	resetGemsBtn.Name = "ResetGemsBtn"
	resetGemsBtn.Size = UDim2.new(1, 0, 0, 38)
	resetGemsBtn.BackgroundColor3 = Theme.BG_OVERLAY
	resetGemsBtn.Text = "🔄 Reset Gems (0)"
	resetGemsBtn.TextColor3 = Theme.TEXT_PRIMARY
	resetGemsBtn.TextSize = 15
	resetGemsBtn.Font = Enum.Font.GothamBold
	resetGemsBtn.LayoutOrder = layoutOrder + 256
	resetGemsBtn.Parent = self.scrollFrame

	local resetGemsCorner = Instance.new("UICorner")
	resetGemsCorner.CornerRadius = Theme.CORNER_SM
	resetGemsCorner.Parent = resetGemsBtn

	resetGemsBtn.MouseButton1Click:Connect(function()
		self:setTestGems("set", 0)
		self:playClickEffect(resetGemsBtn)
	end)

	-- === Mastery Section ===
	local masterySeparator = Instance.new("TextLabel")
	masterySeparator.Name = "MasterySeparator"
	masterySeparator.Size = UDim2.new(1, 0, 0, 25)
	masterySeparator.BackgroundTransparency = 1
	masterySeparator.Text = "── Mastery ──"
	masterySeparator.TextColor3 = Theme.PRIMARY
	masterySeparator.TextSize = 14
	masterySeparator.Font = Enum.Font.GothamBold
	masterySeparator.LayoutOrder = layoutOrder + 300
	masterySeparator.Parent = self.scrollFrame

	-- Per-class mastery entries
	local classIds = ClassTypes.getAllClassIds()
	for i, classId in ipairs(classIds) do
		self.masteryLevels[classId] = 1
		self:createMasteryEntry(classId, layoutOrder + 300 + i)
	end

	-- Set All Lv 20 button
	local setAllBtn = Instance.new("TextButton")
	setAllBtn.Name = "SetAllMasteryBtn"
	setAllBtn.Size = UDim2.new(1, 0, 0, 45)
	setAllBtn.BackgroundColor3 = Theme.BG_ELEVATED
	setAllBtn.Text = "⬆️ Set All Lv 20"
	setAllBtn.TextColor3 = Theme.TEXT_PRIMARY
	setAllBtn.TextSize = 15
	setAllBtn.Font = Enum.Font.GothamBold
	setAllBtn.LayoutOrder = layoutOrder + 400
	setAllBtn.Parent = self.scrollFrame

	local setAllCorner = Instance.new("UICorner")
	setAllCorner.CornerRadius = Theme.CORNER_SM
	setAllCorner.Parent = setAllBtn

	setAllBtn.MouseButton1Click:Connect(function()
		self:setAllMasteryLevels(20)
		self:playClickEffect(setAllBtn)
	end)

	-- Reset All Lv 1 button
	local resetAllBtn = Instance.new("TextButton")
	resetAllBtn.Name = "ResetAllMasteryBtn"
	resetAllBtn.Size = UDim2.new(1, 0, 0, 45)
	resetAllBtn.BackgroundColor3 = Theme.BG_ELEVATED
	resetAllBtn.Text = "🔄 Reset All Lv 1"
	resetAllBtn.TextColor3 = Theme.TEXT_PRIMARY
	resetAllBtn.TextSize = 15
	resetAllBtn.Font = Enum.Font.GothamBold
	resetAllBtn.LayoutOrder = layoutOrder + 401
	resetAllBtn.Parent = self.scrollFrame

	local resetAllCorner = Instance.new("UICorner")
	resetAllCorner.CornerRadius = Theme.CORNER_SM
	resetAllCorner.Parent = resetAllBtn

	resetAllBtn.MouseButton1Click:Connect(function()
		self:setAllMasteryLevels(1)
		self:playClickEffect(resetAllBtn)
	end)
end

function ItemTestingUI:createMasteryEntry(classId: string, order: number)
	local classColor = Theme.classColor(classId)

	local entry = Instance.new("Frame")
	entry.Name = classId .. "MasteryEntry"
	entry.Size = UDim2.new(1, 0, 0, 40)
	entry.BackgroundColor3 = Theme.BG_ELEVATED
	entry.BorderSizePixel = 0
	entry.LayoutOrder = order
	entry.Parent = self.scrollFrame

	local entryCorner = Instance.new("UICorner")
	entryCorner.CornerRadius = Theme.CORNER_SM
	entryCorner.Parent = entry

	-- Color bar on left
	local colorBar = Instance.new("Frame")
	colorBar.Name = "ColorBar"
	colorBar.Size = UDim2.new(0, 4, 1, -8)
	colorBar.Position = UDim2.new(0, 4, 0, 4)
	colorBar.BackgroundColor3 = classColor
	colorBar.BorderSizePixel = 0
	colorBar.Parent = entry

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 2)
	barCorner.Parent = colorBar

	-- Class name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ClassName"
	nameLabel.Size = UDim2.new(0, 70, 1, 0)
	nameLabel.Position = UDim2.new(0, 14, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = classId
	nameLabel.TextColor3 = Theme.TEXT_PRIMARY
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = entry

	-- Level label
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(0, 45, 1, 0)
	levelLabel.Position = UDim2.new(0, 85, 0, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "Lv. 1"
	levelLabel.TextColor3 = Theme.TEXT_PRIMARY
	levelLabel.TextSize = 14
	levelLabel.Font = Enum.Font.Gotham
	levelLabel.Parent = entry

	-- Decrease button (-)
	local decBtn = Instance.new("TextButton")
	decBtn.Name = "DecBtn"
	decBtn.Size = UDim2.new(0, 30, 0, 28)
	decBtn.Position = UDim2.new(1, -140, 0.5, -14)
	decBtn.BackgroundColor3 = Theme.BG_OVERLAY
	decBtn.Text = "-"
	decBtn.TextColor3 = Theme.TEXT_PRIMARY
	decBtn.TextSize = 16
	decBtn.Font = Enum.Font.GothamBold
	decBtn.Parent = entry

	local decCorner = Instance.new("UICorner")
	decCorner.CornerRadius = Theme.CORNER_SM
	decCorner.Parent = decBtn

	-- Increase button (+)
	local incBtn = Instance.new("TextButton")
	incBtn.Name = "IncBtn"
	incBtn.Size = UDim2.new(0, 30, 0, 28)
	incBtn.Position = UDim2.new(1, -105, 0.5, -14)
	incBtn.BackgroundColor3 = Theme.BG_OVERLAY
	incBtn.Text = "+"
	incBtn.TextColor3 = Theme.TEXT_PRIMARY
	incBtn.TextSize = 16
	incBtn.Font = Enum.Font.GothamBold
	incBtn.Parent = entry

	local incCorner = Instance.new("UICorner")
	incCorner.CornerRadius = Theme.CORNER_SM
	incCorner.Parent = incBtn

	-- MAX button
	local maxBtn = Instance.new("TextButton")
	maxBtn.Name = "MaxBtn"
	maxBtn.Size = UDim2.new(0, 40, 0, 28)
	maxBtn.Position = UDim2.new(1, -68, 0.5, -14)
	maxBtn.BackgroundColor3 = Theme.BG_OVERLAY
	maxBtn.Text = "MAX"
	maxBtn.TextColor3 = Theme.TEXT_PRIMARY
	maxBtn.TextSize = 11
	maxBtn.Font = Enum.Font.GothamBold
	maxBtn.Parent = entry

	local maxCorner = Instance.new("UICorner")
	maxCorner.CornerRadius = Theme.CORNER_SM
	maxCorner.Parent = maxBtn

	-- Store references for updating
	self.classEntries[classId] = {
		levelLabel = levelLabel,
		entry = entry,
	}

	-- Button handlers
	decBtn.MouseButton1Click:Connect(function()
		self:adjustMasteryLevel(classId, -1)
	end)

	incBtn.MouseButton1Click:Connect(function()
		self:adjustMasteryLevel(classId, 1)
	end)

	maxBtn.MouseButton1Click:Connect(function()
		self:setMasteryLevel(classId, 20)
	end)
end

function ItemTestingUI:adjustMasteryLevel(classId: string, delta: number)
	local current = self.masteryLevels[classId] or 1
	self:setMasteryLevel(classId, current + delta)
end

function ItemTestingUI:setMasteryLevel(classId: string, level: number)
	level = math.clamp(level, 1, 20)
	self.masteryLevels[classId] = level
	self:updateMasteryDisplay(classId)

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local setRemote = remotes:FindFirstChild("SetMasteryLevel")
		if setRemote then
			setRemote:FireServer({
				classId = classId,
				level = level,
			})
		end
	end
end

function ItemTestingUI:setAllMasteryLevels(level: number)
	level = math.clamp(level, 1, 20)
	for classId, _ in pairs(self.masteryLevels) do
		self.masteryLevels[classId] = level
		self:updateMasteryDisplay(classId)
	end

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local setRemote = remotes:FindFirstChild("SetMasteryLevel")
		if setRemote then
			setRemote:FireServer({
				setAll = true,
				level = level,
			})
		end
	end
end

function ItemTestingUI:updateMasteryDisplay(classId: string)
	local entry = self.classEntries[classId]
	if not entry then return end

	local level = self.masteryLevels[classId] or 1
	entry.levelLabel.Text = "Lv. " .. level
	if level >= 20 then
		entry.levelLabel.TextColor3 = Theme.PRIMARY
	else
		entry.levelLabel.TextColor3 = Theme.TEXT_PRIMARY
	end
end

function ItemTestingUI:setupMasteryRemotes()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return end

	local masteryUpdate = remotes:FindFirstChild("MasteryUpdate")
	if masteryUpdate then
		masteryUpdate.OnClientEvent:Connect(function(data)
			-- Server sends { classMastery = {[classId] = {level, xp, ...}}, ... }
			if data.classMastery then
				for classId, info in pairs(data.classMastery) do
					if info.level then
						self.masteryLevels[classId] = info.level
						self:updateMasteryDisplay(classId)
					end
				end
			end
		end)
	end

	-- Listen for gem updates to keep display in sync
	local updateGems = remotes:FindFirstChild("UpdateGems")
	if updateGems then
		updateGems.OnClientEvent:Connect(function(data)
			if data and data.gems ~= nil and self.gemDisplayLabel then
				self.gemDisplayLabel.Text = "💎 Gems: " .. tostring(data.gems)
			end
		end)
	end
end

function ItemTestingUI:setTestGems(action: string, amount: number)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local setGemsRemote = remotes:FindFirstChild("SetTestGems")
		if setGemsRemote then
			setGemsRemote:FireServer({ action = action, amount = amount })
			Logger.debug("ItemTestingUI", "SetTestGems:", action, amount)
		else
			Logger.warn("ItemTestingUI", "SetTestGems remote not found!")
		end
	end
end

function ItemTestingUI:createItemButton(itemDef, layoutOrder: number): TextButton
	local rarityColor = ItemTypes.getRarityColor(itemDef.rarity)

	local button = Instance.new("TextButton")
	button.Name = itemDef.id .. "Button"
	button.Size = UDim2.new(1, 0, 0, 50)
	button.BackgroundColor3 = Color3.new(rarityColor.R * 0.3, rarityColor.G * 0.3, rarityColor.B * 0.3)
	button.Text = ""
	button.LayoutOrder = layoutOrder
	button.Parent = self.scrollFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CORNER_SM
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = rarityColor
	stroke.Thickness = 1
	stroke.Parent = button

	-- Icon
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 40, 0, 40)
	icon.Position = UDim2.new(0, 5, 0.5, 0)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.BackgroundTransparency = 1
	icon.Text = itemDef.icon
	icon.TextSize = 28
	icon.Parent = button

	-- Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -60, 0, 20)
	nameLabel.Position = UDim2.new(0, 50, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemDef.name
	nameLabel.TextColor3 = Theme.TEXT_PRIMARY
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = button

	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "DescLabel"
	descLabel.Size = UDim2.new(1, -60, 0, 20)
	descLabel.Position = UDim2.new(0, 50, 0, 25)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = itemDef.description
	descLabel.TextColor3 = Theme.TEXT_MUTED
	descLabel.TextSize = 10
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextTruncate = Enum.TextTruncate.AtEnd
	descLabel.Parent = button

	-- Click to give item
	button.MouseButton1Click:Connect(function()
		self:giveItem(itemDef.id)
		self:playClickEffect(button)
	end)

	-- Hover effect
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), {
			BackgroundColor3 = Color3.new(rarityColor.R * 0.5, rarityColor.G * 0.5, rarityColor.B * 0.5)
		}):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), {
			BackgroundColor3 = Color3.new(rarityColor.R * 0.3, rarityColor.G * 0.3, rarityColor.B * 0.3)
		}):Play()
	end)

	return button
end

function ItemTestingUI:giveItem(itemId: string)
	-- Fire remote to server to give item
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local giveItemRemote = remotes:FindFirstChild("GiveTestItem")
		if giveItemRemote then
			giveItemRemote:FireServer(itemId)
			Logger.debug("ItemTestingUI", "Requested item:", itemId)
		else
			Logger.warn("ItemTestingUI", "GiveTestItem remote not found!")
		end
	end
end

function ItemTestingUI:clearItems()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local clearRemote = remotes:FindFirstChild("ClearTestItems")
		if clearRemote then
			clearRemote:FireServer()
			Logger.debug("ItemTestingUI", "Cleared all items")
		else
			Logger.warn("ItemTestingUI", "ClearTestItems remote not found!")
		end
	end
end

function ItemTestingUI:spawnDummy()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local spawnRemote = remotes:FindFirstChild("SpawnTestDummy")
		if spawnRemote then
			spawnRemote:FireServer()
			Logger.debug("ItemTestingUI", "Spawning test dummy...")
		else
			Logger.warn("ItemTestingUI", "SpawnTestDummy remote not found!")
		end
	end
end

function ItemTestingUI:removeDummies()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local removeRemote = remotes:FindFirstChild("RemoveTestDummies")
		if removeRemote then
			removeRemote:FireServer()
			Logger.debug("ItemTestingUI", "Removing all test dummies...")
		else
			Logger.warn("ItemTestingUI", "RemoveTestDummies remote not found!")
		end
	end
end

function ItemTestingUI:playClickEffect(button: TextButton)
	-- Flash effect
	local originalColor = button.BackgroundColor3
	button.BackgroundColor3 = Color3.fromRGB(100, 255, 100)

	task.delay(0.1, function()
		TweenService:Create(button, TweenInfo.new(0.2), {
			BackgroundColor3 = originalColor
		}):Play()
	end)
end

function ItemTestingUI:toggle()
	self.visible = not self.visible
	self.mainFrame.Visible = self.visible

	if self.visible then
		self.toggleButton.BackgroundColor3 = Theme.SUCCESS
		self.toggleButton.Text = "✓ Testing"
	else
		self.toggleButton.BackgroundColor3 = Theme.DANGER
		self.toggleButton.Text = "🧪 Testing"
	end
end

return ItemTestingUI
