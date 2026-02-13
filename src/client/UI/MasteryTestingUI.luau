-- MasteryTestingUI: UI สำหรับทดสอบ Mastery Levels (Debug Only)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local ClassTypes = require(ReplicatedStorage.Shared.ClassTypes)

local MasteryTestingUI = {}
MasteryTestingUI.__index = MasteryTestingUI

function MasteryTestingUI.new(parent: ScreenGui)
	local self = setmetatable({}, MasteryTestingUI)
	
	self.parent = parent
	self.isVisible = false
	self.masteryLevels = {} -- Store current mastery levels
	
	-- Remotes
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	self.setMasteryLevelRemote = remotes:WaitForChild("SetMasteryLevel")
	self.masteryUpdateRemote = remotes:WaitForChild("MasteryUpdate")
	
	self:createUI()
	self:setupRemotes()
	
	return self
end

function MasteryTestingUI:createUI()
	-- Main Frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MasteryTestingFrame"
	mainFrame.Size = UDim2.new(0, 350, 0, 300)
	mainFrame.Position = UDim2.new(0.5, -175, 0.5, -150)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	mainFrame.BackgroundTransparency = 0.1
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = self.parent
	self.mainFrame = mainFrame
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = mainFrame
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 150, 50)
	stroke.Thickness = 2
	stroke.Parent = mainFrame
	
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 40)
	title.Position = UDim2.new(0, 10, 0, 10)
	title.BackgroundTransparency = 1
	title.Text = "MASTERY TESTING [M]"
	title.TextColor3 = Color3.fromRGB(255, 200, 100)
	title.TextSize = 22
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = mainFrame
	
	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -35, 0, 5)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 16
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = mainFrame
	
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeBtn
	
	closeBtn.MouseButton1Click:Connect(function()
		self:hide()
	end)
	
	-- Class entries container
	local container = Instance.new("Frame")
	container.Name = "ClassContainer"
	container.Size = UDim2.new(1, -20, 0, 180)
	container.Position = UDim2.new(0, 10, 0, 55)
	container.BackgroundTransparency = 1
	container.Parent = mainFrame
	self.classContainer = container
	
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 5)
	listLayout.Parent = container
	
	-- Create entries for each class
	self.classEntries = {}
	local classIds = ClassTypes.getAllClassIds()
	
	for i, classId in ipairs(classIds) do
		local classDef = ClassTypes.getClass(classId)
		if classDef then
			self:createClassEntry(container, classId, classDef, i)
		end
	end
	
	-- Bottom buttons container
	local buttonsFrame = Instance.new("Frame")
	buttonsFrame.Name = "ButtonsFrame"
	buttonsFrame.Size = UDim2.new(1, -20, 0, 40)
	buttonsFrame.Position = UDim2.new(0, 10, 1, -50)
	buttonsFrame.BackgroundTransparency = 1
	buttonsFrame.Parent = mainFrame
	
	-- Set All to LV 20 button
	local setAllBtn = Instance.new("TextButton")
	setAllBtn.Name = "SetAllButton"
	setAllBtn.Size = UDim2.new(0.48, 0, 1, 0)
	setAllBtn.Position = UDim2.new(0, 0, 0, 0)
	setAllBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	setAllBtn.BorderSizePixel = 0
	setAllBtn.Text = "SET ALL LV 20"
	setAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	setAllBtn.TextSize = 14
	setAllBtn.Font = Enum.Font.GothamBold
	setAllBtn.Parent = buttonsFrame
	
	local setAllCorner = Instance.new("UICorner")
	setAllCorner.CornerRadius = UDim.new(0, 6)
	setAllCorner.Parent = setAllBtn
	
	setAllBtn.MouseButton1Click:Connect(function()
		self:setAllLevels(20)
	end)
	
	-- Reset All button
	local resetAllBtn = Instance.new("TextButton")
	resetAllBtn.Name = "ResetAllButton"
	resetAllBtn.Size = UDim2.new(0.48, 0, 1, 0)
	resetAllBtn.Position = UDim2.new(0.52, 0, 0, 0)
	resetAllBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
	resetAllBtn.BorderSizePixel = 0
	resetAllBtn.Text = "RESET ALL"
	resetAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	resetAllBtn.TextSize = 14
	resetAllBtn.Font = Enum.Font.GothamBold
	resetAllBtn.Parent = buttonsFrame
	
	local resetAllCorner = Instance.new("UICorner")
	resetAllCorner.CornerRadius = UDim.new(0, 6)
	resetAllCorner.Parent = resetAllBtn
	
	resetAllBtn.MouseButton1Click:Connect(function()
		self:setAllLevels(1)
	end)
end

function MasteryTestingUI:createClassEntry(parent: Frame, classId: string, classDef: {[string]: any}, layoutOrder: number)
	local entry = Instance.new("Frame")
	entry.Name = classId .. "Entry"
	entry.Size = UDim2.new(1, 0, 0, 40)
	entry.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	entry.BackgroundTransparency = 0.3
	entry.BorderSizePixel = 0
	entry.LayoutOrder = layoutOrder
	entry.Parent = parent
	
	local entryCorner = Instance.new("UICorner")
	entryCorner.CornerRadius = UDim.new(0, 6)
	entryCorner.Parent = entry
	
	-- Class color indicator
	local colorIndicator = Instance.new("Frame")
	colorIndicator.Name = "ColorIndicator"
	colorIndicator.Size = UDim2.new(0, 4, 1, -4)
	colorIndicator.Position = UDim2.new(0, 2, 0, 2)
	colorIndicator.BackgroundColor3 = classDef.color or Color3.fromRGB(255, 255, 255)
	colorIndicator.BorderSizePixel = 0
	colorIndicator.Parent = entry
	
	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.CornerRadius = UDim.new(0, 2)
	indicatorCorner.Parent = colorIndicator
	
	-- Class name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ClassName"
	nameLabel.Size = UDim2.new(0, 80, 1, 0)
	nameLabel.Position = UDim2.new(0, 10, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = classDef.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = entry
	
	-- Level display
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(0, 60, 1, 0)
	levelLabel.Position = UDim2.new(0, 90, 0, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "[Lv. 1]"
	levelLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	levelLabel.TextSize = 14
	levelLabel.Font = Enum.Font.Gotham
	levelLabel.Parent = entry
	self.classEntries[classId] = self.classEntries[classId] or {}
	self.classEntries[classId].levelLabel = levelLabel
	
	-- Decrease button
	local decreaseBtn = Instance.new("TextButton")
	decreaseBtn.Name = "DecreaseButton"
	decreaseBtn.Size = UDim2.new(0, 30, 0, 30)
	decreaseBtn.Position = UDim2.new(0, 160, 0.5, 0)
	decreaseBtn.AnchorPoint = Vector2.new(0, 0.5)
	decreaseBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
	decreaseBtn.BorderSizePixel = 0
	decreaseBtn.Text = "-"
	decreaseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	decreaseBtn.TextSize = 20
	decreaseBtn.Font = Enum.Font.GothamBold
	decreaseBtn.Parent = entry
	
	local decreaseCorner = Instance.new("UICorner")
	decreaseCorner.CornerRadius = UDim.new(0, 4)
	decreaseCorner.Parent = decreaseBtn
	
	decreaseBtn.MouseButton1Click:Connect(function()
		self:adjustLevel(classId, -1)
	end)
	
	-- Increase button
	local increaseBtn = Instance.new("TextButton")
	increaseBtn.Name = "IncreaseButton"
	increaseBtn.Size = UDim2.new(0, 30, 0, 30)
	increaseBtn.Position = UDim2.new(0, 195, 0.5, 0)
	increaseBtn.AnchorPoint = Vector2.new(0, 0.5)
	increaseBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
	increaseBtn.BorderSizePixel = 0
	increaseBtn.Text = "+"
	increaseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	increaseBtn.TextSize = 20
	increaseBtn.Font = Enum.Font.GothamBold
	increaseBtn.Parent = entry
	
	local increaseCorner = Instance.new("UICorner")
	increaseCorner.CornerRadius = UDim.new(0, 4)
	increaseCorner.Parent = increaseBtn
	
	increaseBtn.MouseButton1Click:Connect(function()
		self:adjustLevel(classId, 1)
	end)
	
	-- Max button
	local maxBtn = Instance.new("TextButton")
	maxBtn.Name = "MaxButton"
	maxBtn.Size = UDim2.new(0, 50, 0, 30)
	maxBtn.Position = UDim2.new(0, 230, 0.5, 0)
	maxBtn.AnchorPoint = Vector2.new(0, 0.5)
	maxBtn.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
	maxBtn.BorderSizePixel = 0
	maxBtn.Text = "MAX"
	maxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	maxBtn.TextSize = 12
	maxBtn.Font = Enum.Font.GothamBold
	maxBtn.Parent = entry
	
	local maxCorner = Instance.new("UICorner")
	maxCorner.CornerRadius = UDim.new(0, 4)
	maxCorner.Parent = maxBtn
	
	maxBtn.MouseButton1Click:Connect(function()
		self:setLevel(classId, 20)
	end)
	
	-- Initialize mastery level
	self.masteryLevels[classId] = 1
end

function MasteryTestingUI:setupRemotes()
	self.masteryUpdateRemote.OnClientEvent:Connect(function(data)
		if data.action and data.action.type == "testSet" then
			self.masteryLevels[data.action.classId] = data.action.newLevel
			self:updateDisplay()
		elseif data.classMastery then
			-- Initial update
			for classId, snapshot in pairs(data.classMastery) do
				self.masteryLevels[classId] = snapshot.level
			end
			self:updateDisplay()
		end
	end)
end

function MasteryTestingUI:adjustLevel(classId: string, delta: number)
	local currentLevel = self.masteryLevels[classId] or 1
	local newLevel = math.clamp(currentLevel + delta, 1, 20)
	
	if newLevel ~= currentLevel then
		self:setLevel(classId, newLevel)
	end
end

function MasteryTestingUI:setLevel(classId: string, level: number)
	level = math.clamp(level, 1, 20)
	self.masteryLevels[classId] = level
	self.setMasteryLevelRemote:FireServer({
		classId = classId,
		level = level,
	})
	self:updateDisplay()
end

function MasteryTestingUI:setAllLevels(level: number)
	level = math.clamp(level, 1, 20)
	
	for classId in pairs(self.masteryLevels) do
		self.masteryLevels[classId] = level
	end
	
	self.setMasteryLevelRemote:FireServer({
		setAll = true,
		level = level,
	})
	
	self:updateDisplay()
end

function MasteryTestingUI:updateDisplay()
	for classId, entry in pairs(self.classEntries) do
		if entry.levelLabel then
			local level = self.masteryLevels[classId] or 1
			entry.levelLabel.Text = "[Lv. " .. level .. "]"
			
			-- Highlight if at max level (20 = ultimate unlock)
			if level >= 20 then
				entry.levelLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
			else
				entry.levelLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
			end
		end
	end
end

function MasteryTestingUI:show()
	if self.isVisible then return end
	self.isVisible = true
	
	self.mainFrame.Visible = true
	self.mainFrame.Position = UDim2.new(0.5, -175, 0.5, -130)
	
	local tween = TweenService:Create(self.mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
		Position = UDim2.new(0.5, -175, 0.5, -150)
	})
	tween:Play()
end

function MasteryTestingUI:hide()
	if not self.isVisible then return end
	self.isVisible = false
	
	local tween = TweenService:Create(self.mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
		Position = UDim2.new(0.5, -175, 0.5, -130)
	})
	tween:Play()
	
	tween.Completed:Connect(function()
		self.mainFrame.Visible = false
	end)
end

function MasteryTestingUI:toggle()
	if self.isVisible then
		self:hide()
	else
		self:show()
	end
end

return MasteryTestingUI
