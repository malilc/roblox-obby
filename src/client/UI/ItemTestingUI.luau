-- ItemTestingUI: Testing menu for selecting items (Development only)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ItemTypes = require(ReplicatedStorage.Shared.ItemTypes)
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
	
	self:createUI()
	self:setupInput()
	
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
	toggleButton.Text = "🧪 Test Items"
	toggleButton.TextColor3 = Theme.TEXT_PRIMARY
	toggleButton.TextSize = 14
	toggleButton.Font = Enum.Font.GothamBold
	toggleButton.Parent = screenGui
	self.toggleButton = toggleButton
	
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 8)
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
	mainCorner.CornerRadius = UDim.new(0, 12)
	mainCorner.Parent = mainFrame
	
	local mainStroke = Instance.new("UIStroke")
	mainStroke.Color = Theme.DANGER
	mainStroke.Thickness = 2
	mainStroke.Parent = mainFrame
	
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "🧪 Item Testing Menu"
	title.TextColor3 = Theme.DANGER
	title.TextSize = 18
	title.Font = Enum.Font.GothamBold
	title.Parent = mainFrame
	
	-- Subtitle
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, 0, 0, 20)
	subtitle.Position = UDim2.new(0, 0, 0, 35)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Click item to give yourself"
	subtitle.TextColor3 = Theme.TEXT_MUTED
	subtitle.TextSize = 12
	subtitle.Font = Enum.Font.Gotham
	subtitle.Parent = mainFrame
	
	-- Scrolling frame for items
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ItemList"
	scrollFrame.Size = UDim2.new(1, -20, 1, -70)
	scrollFrame.Position = UDim2.new(0, 10, 0, 60)
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
	
	-- Separator
	local separator = Instance.new("TextLabel")
	separator.Name = "Separator"
	separator.Size = UDim2.new(1, 0, 0, 25)
	separator.BackgroundTransparency = 1
	separator.Text = "── Tools ──"
	separator.TextColor3 = Color3.fromRGB(255, 200, 100)
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
	spawnDummyButton.TextColor3 = Theme.ACCENT_CYAN
	spawnDummyButton.TextSize = 14
	spawnDummyButton.Font = Enum.Font.GothamBold
	spawnDummyButton.LayoutOrder = layoutOrder + 51
	spawnDummyButton.Parent = self.scrollFrame
	
	local spawnCorner = Instance.new("UICorner")
	spawnCorner.CornerRadius = UDim.new(0, 8)
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
	removeDummyButton.TextColor3 = Theme.DANGER
	removeDummyButton.TextSize = 14
	removeDummyButton.Font = Enum.Font.GothamBold
	removeDummyButton.LayoutOrder = layoutOrder + 52
	removeDummyButton.Parent = self.scrollFrame
	
	local removeCorner = Instance.new("UICorner")
	removeCorner.CornerRadius = UDim.new(0, 8)
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
	clearButton.TextColor3 = Theme.DANGER
	clearButton.TextSize = 14
	clearButton.Font = Enum.Font.GothamBold
	clearButton.LayoutOrder = layoutOrder + 100
	clearButton.Parent = self.scrollFrame
	
	local clearCorner = Instance.new("UICorner")
	clearCorner.CornerRadius = UDim.new(0, 8)
	clearCorner.Parent = clearButton
	
	clearButton.MouseButton1Click:Connect(function()
		self:clearItems()
	end)
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
	corner.CornerRadius = UDim.new(0, 8)
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
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
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
	descLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
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
		self.toggleButton.Text = "✓ Test Items"
	else
		self.toggleButton.BackgroundColor3 = Theme.DANGER
		self.toggleButton.Text = "🧪 Test Items"
	end
end

function ItemTestingUI:setupInput()
	-- Press T to toggle menu
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.T then
			self:toggle()
		end
	end)
end

return ItemTestingUI
