-- ClassSelectionUI: UI สำหรับเลือก Character Class

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ClassTypes = require(ReplicatedStorage.Shared.ClassTypes)

local LocalPlayer = Players.LocalPlayer

local ClassSelectionUI = {}
ClassSelectionUI.__index = ClassSelectionUI

function ClassSelectionUI.new(parent: ScreenGui)
	local self = setmetatable({}, ClassSelectionUI)
	
	self.parent = parent
	self.isVisible = false
	self.selectedClass = ClassTypes.DefaultClass
	self.classButtons = {}
	
	self:createUI()
	self:setupRemotes()
	
	return self
end

function ClassSelectionUI:createUI()
	-- Main container (initially hidden)
	local container = Instance.new("Frame")
	container.Name = "ClassSelectionContainer"
	container.Size = UDim2.new(0, 500, 0, 350)
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
	
	-- Stroke
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
	classesFrame.Size = UDim2.new(1, -40, 0, 200)
	classesFrame.Position = UDim2.new(0, 20, 0, 70)
	classesFrame.BackgroundTransparency = 1
	classesFrame.Parent = container
	
	local classLayout = Instance.new("UIListLayout")
	classLayout.FillDirection = Enum.FillDirection.Horizontal
	classLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	classLayout.Padding = UDim.new(0, 15)
	classLayout.Parent = classesFrame
	
	-- Create class buttons
	for _, classId in ipairs(ClassTypes.getAllClassIds()) do
		self:createClassButton(classesFrame, classId)
	end
	
	-- Confirm button
	local confirmBtn = Instance.new("TextButton")
	confirmBtn.Name = "ConfirmButton"
	confirmBtn.Size = UDim2.new(0, 200, 0, 45)
	confirmBtn.Position = UDim2.new(0.5, 0, 1, -60)
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
	
	-- Current class indicator (shows on screen when not in selection)
	self:createCurrentClassIndicator()
end

function ClassSelectionUI:createClassButton(parent: Frame, classId: string)
	local classDef = ClassTypes.getClass(classId)
	if not classDef then return end
	
	local displayInfo = ClassTypes.getClassDisplayInfo(classId)
	
	-- Button container
	local button = Instance.new("TextButton")
	button.Name = "Class_" .. classId
	button.Size = UDim2.new(0, 140, 0, 200)
	button.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	button.BackgroundTransparency = 0.3
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	button.Parent = parent
	
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 12)
	buttonCorner.Parent = button
	
	-- Border
	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Color = Color3.fromRGB(80, 80, 80)
	buttonStroke.Thickness = 2
	buttonStroke.Parent = button
	
	-- Icon
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 0, 50)
	icon.Position = UDim2.new(0, 0, 0, 10)
	icon.BackgroundTransparency = 1
	icon.Text = classDef.icon
	icon.TextSize = 40
	icon.Parent = button
	
	-- Name
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0, 25)
	name.Position = UDim2.new(0, 0, 0, 60)
	name.BackgroundTransparency = 1
	name.Text = classDef.name
	name.TextColor3 = classDef.color
	name.TextSize = 18
	name.Font = Enum.Font.GothamBold
	name.Parent = button
	
	-- Stats
	local statsText = table.concat(displayInfo.stats, "\n")
	local stats = Instance.new("TextLabel")
	stats.Size = UDim2.new(1, -10, 0, 50)
	stats.Position = UDim2.new(0, 5, 0, 90)
	stats.BackgroundTransparency = 1
	stats.Text = statsText
	stats.TextColor3 = Color3.fromRGB(200, 200, 200)
	stats.TextSize = 12
	stats.Font = Enum.Font.GothamMedium
	stats.TextXAlignment = Enum.TextXAlignment.Center
	stats.TextYAlignment = Enum.TextYAlignment.Top
	stats.Parent = button
	
	-- Passive ability
	local passive = Instance.new("TextLabel")
	passive.Size = UDim2.new(1, -10, 0, 40)
	passive.Position = UDim2.new(0, 5, 0, 145)
	passive.BackgroundTransparency = 1
	passive.Text = classDef.passiveAbility.name
	passive.TextColor3 = Color3.fromRGB(255, 230, 150)
	passive.TextSize = 10
	passive.Font = Enum.Font.GothamMedium
	passive.TextWrapped = true
	passive.Parent = button
	
	-- Store reference
	self.classButtons[classId] = {
		button = button,
		stroke = buttonStroke,
		color = classDef.color,
	}
	
	-- Click handler
	button.MouseButton1Click:Connect(function()
		self:selectClass(classId)
	end)
	
	-- Hover effects
	button.MouseEnter:Connect(function()
		if self.selectedClass ~= classId then
			TweenService:Create(buttonStroke, TweenInfo.new(0.15), {
				Color = classDef.color,
				Thickness = 3
			}):Play()
		end
	end)
	
	button.MouseLeave:Connect(function()
		if self.selectedClass ~= classId then
			TweenService:Create(buttonStroke, TweenInfo.new(0.15), {
				Color = Color3.fromRGB(80, 80, 80),
				Thickness = 2
			}):Play()
		end
	end)
end

function ClassSelectionUI:createCurrentClassIndicator()
	-- Small indicator showing current class (below currency frame)
	local indicator = Instance.new("Frame")
	indicator.Name = "ClassIndicator"
	indicator.Size = UDim2.new(0, 100, 0, 35)
	indicator.Position = UDim2.new(0, 10, 0, 140) -- ใต้ Currency Frame (Y=92+44=136 + padding)
	indicator.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	indicator.BackgroundTransparency = 0.3
	indicator.BorderSizePixel = 0
	indicator.Parent = self.parent
	self.classIndicator = indicator
	
	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.CornerRadius = UDim.new(0, 8)
	indicatorCorner.Parent = indicator
	
	-- Icon
	local indicatorIcon = Instance.new("TextLabel")
	indicatorIcon.Name = "Icon"
	indicatorIcon.Size = UDim2.new(0, 30, 1, 0)
	indicatorIcon.BackgroundTransparency = 1
	indicatorIcon.Text = "🏃"
	indicatorIcon.TextSize = 20
	indicatorIcon.Parent = indicator
	self.indicatorIcon = indicatorIcon
	
	-- Name
	local indicatorName = Instance.new("TextLabel")
	indicatorName.Name = "Name"
	indicatorName.Size = UDim2.new(1, -35, 1, 0)
	indicatorName.Position = UDim2.new(0, 32, 0, 0)
	indicatorName.BackgroundTransparency = 1
	indicatorName.Text = "Runner"
	indicatorName.TextColor3 = Color3.fromRGB(100, 200, 255)
	indicatorName.TextSize = 14
	indicatorName.Font = Enum.Font.GothamBold
	indicatorName.TextXAlignment = Enum.TextXAlignment.Left
	indicatorName.Parent = indicator
	self.indicatorName = indicatorName
	
	-- Click to open selection
	local clickButton = Instance.new("TextButton")
	clickButton.Size = UDim2.new(1, 0, 1, 0)
	clickButton.BackgroundTransparency = 1
	clickButton.Text = ""
	clickButton.Parent = indicator
	
	clickButton.MouseButton1Click:Connect(function()
		self:toggle()
	end)
end

function ClassSelectionUI:selectClass(classId: string)
	local previousClass = self.selectedClass
	self.selectedClass = classId
	
	-- Update visual selection
	for id, buttonData in pairs(self.classButtons) do
		if id == classId then
			TweenService:Create(buttonData.stroke, TweenInfo.new(0.2), {
				Color = buttonData.color,
				Thickness = 4
			}):Play()
			TweenService:Create(buttonData.button, TweenInfo.new(0.2), {
				BackgroundTransparency = 0.1
			}):Play()
		else
			TweenService:Create(buttonData.stroke, TweenInfo.new(0.2), {
				Color = Color3.fromRGB(80, 80, 80),
				Thickness = 2
			}):Play()
			TweenService:Create(buttonData.button, TweenInfo.new(0.2), {
				BackgroundTransparency = 0.3
			}):Play()
		end
	end
	
	print("[ClassSelectionUI] Selected class:", classId)
end

function ClassSelectionUI:confirmSelection()
	-- Send to server
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SelectClass")
	remote:FireServer(self.selectedClass)
	
	-- Update indicator
	self:updateIndicator(self.selectedClass)
	
	-- Hide selection UI
	self:hide()
	
	print("[ClassSelectionUI] Confirmed class:", self.selectedClass)
end

function ClassSelectionUI:updateIndicator(classId: string)
	local classDef = ClassTypes.getClass(classId)
	if not classDef then return end
	
	self.indicatorIcon.Text = classDef.icon
	self.indicatorName.Text = classDef.name
	self.indicatorName.TextColor3 = classDef.color
end

function ClassSelectionUI:setupRemotes()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	
	-- Class update from server
	remotes.ClassUpdate.OnClientEvent:Connect(function(data)
		if data.classId then
			self.selectedClass = data.classId
			self:updateIndicator(data.classId)
			
			-- Update button selection visual
			for id, buttonData in pairs(self.classButtons) do
				if id == data.classId then
					buttonData.stroke.Color = buttonData.color
					buttonData.stroke.Thickness = 4
					buttonData.button.BackgroundTransparency = 0.1
				else
					buttonData.stroke.Color = Color3.fromRGB(80, 80, 80)
					buttonData.stroke.Thickness = 2
					buttonData.button.BackgroundTransparency = 0.3
				end
			end
		end
	end)
end

function ClassSelectionUI:show()
	self.isVisible = true
	self.container.Visible = true
	
	-- Animate in
	self.container.Position = UDim2.new(0.5, 0, 0.5, 50)
	self.container.BackgroundTransparency = 1
	
	TweenService:Create(self.container, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 0.1
	}):Play()
	
	-- Highlight current selection
	self:selectClass(self.selectedClass)
end

function ClassSelectionUI:hide()
	self.isVisible = false
	
	-- Animate out
	TweenService:Create(self.container, TweenInfo.new(0.2), {
		Position = UDim2.new(0.5, 0, 0.5, 50),
		BackgroundTransparency = 1
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
