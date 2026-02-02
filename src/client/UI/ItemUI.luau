-- ItemUI: แสดง Item ปัจจุบันและ Status Effects

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemTypes = require(ReplicatedStorage.Shared.ItemTypes)

local LocalPlayer = Players.LocalPlayer

local ItemUI = {}
ItemUI.__index = ItemUI

function ItemUI.new(parent: ScreenGui)
	local self = setmetatable({}, ItemUI)
	
	self.parent = parent
	self.currentItem = nil
	self.hasShield = false
	self.isBoosted = false
	self.isSlowed = false
	self.tooltipVisible = false
	
	self:createUI()
	self:setupInput()
	
	return self
end

function ItemUI:createUI()
	-- Main item container (มุมล่างขวา) - เล็กลง
	local container = Instance.new("Frame")
	container.Name = "ItemContainer"
	container.Size = UDim2.new(0, 120, 0, 115)
	container.Position = UDim2.new(1, -130, 1, -125)
	container.BackgroundTransparency = 1
	container.Parent = self.parent
	self.container = container
	
	-- Item slot frame (กลาง container) - ทำเป็น clickable
	local itemFrame = Instance.new("TextButton")
	itemFrame.Name = "ItemFrame"
	itemFrame.Size = UDim2.new(0, 80, 0, 80)
	itemFrame.Position = UDim2.new(0.5, 0, 0, 0)
	itemFrame.AnchorPoint = Vector2.new(0.5, 0)
	itemFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	itemFrame.BackgroundTransparency = 0.2
	itemFrame.BorderSizePixel = 0
	itemFrame.Text = ""
	itemFrame.AutoButtonColor = false
	itemFrame.Parent = container
	self.itemFrame = itemFrame
	
	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 12)
	frameCorner.Parent = itemFrame
	
	-- Border/glow
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 100, 100)
	stroke.Thickness = 2
	stroke.Parent = itemFrame
	self.frameStroke = stroke
	
	-- Item icon
	local iconLabel = Instance.new("ImageLabel")
	iconLabel.Name = "ItemIcon"
	iconLabel.Size = UDim2.new(0.7, 0, 0.7, 0)
	iconLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	iconLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Image = ""
	iconLabel.Visible = false
	iconLabel.Parent = itemFrame
	self.iconImage = iconLabel
	
	-- Item name fallback (text)
	local iconText = Instance.new("TextLabel")
	iconText.Name = "ItemIconText"
	iconText.Size = UDim2.new(1, -10, 0.6, 0)
	iconText.Position = UDim2.new(0.5, 0, 0.3, 0)
	iconText.AnchorPoint = Vector2.new(0.5, 0)
	iconText.BackgroundTransparency = 1
	iconText.Text = ""
	iconText.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconText.TextSize = 12
	iconText.TextScaled = true
	iconText.Font = Enum.Font.GothamBold
	iconText.Visible = false
	iconText.Parent = itemFrame
	self.iconText = iconText
	
	-- Empty slot text
	local emptyText = Instance.new("TextLabel")
	emptyText.Name = "EmptyText"
	emptyText.Size = UDim2.new(1, 0, 1, 0)
	emptyText.BackgroundTransparency = 1
	emptyText.Text = "?"
	emptyText.TextColor3 = Color3.fromRGB(100, 100, 100)
	emptyText.TextSize = 36
	emptyText.Font = Enum.Font.GothamBlack
	emptyText.Parent = itemFrame
	self.emptyText = emptyText
	
	-- Info hint (เมื่อมี item)
	local infoHint = Instance.new("TextLabel")
	infoHint.Name = "InfoHint"
	infoHint.Size = UDim2.new(0, 20, 0, 20)
	infoHint.Position = UDim2.new(1, -5, 0, 5)
	infoHint.AnchorPoint = Vector2.new(1, 0)
	infoHint.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
	infoHint.BackgroundTransparency = 0.3
	infoHint.Text = "i"
	infoHint.TextColor3 = Color3.fromRGB(255, 255, 255)
	infoHint.TextSize = 12
	infoHint.Font = Enum.Font.GothamBold
	infoHint.Visible = false
	infoHint.Parent = itemFrame
	self.infoHint = infoHint
	
	local infoCorner = Instance.new("UICorner")
	infoCorner.CornerRadius = UDim.new(1, 0)
	infoCorner.Parent = infoHint
	
	-- Tooltip popup (ซ่อนไว้ก่อน แสดงเมื่อคลิก)
	local tooltip = Instance.new("Frame")
	tooltip.Name = "ItemTooltip"
	tooltip.Size = UDim2.new(0, 200, 0, 100)
	tooltip.Position = UDim2.new(0, -210, 0, 0) -- ด้านซ้ายของ item
	tooltip.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	tooltip.BackgroundTransparency = 0.1
	tooltip.BorderSizePixel = 0
	tooltip.Visible = false
	tooltip.ZIndex = 10
	tooltip.Parent = container
	self.tooltip = tooltip
	
	local tooltipCorner = Instance.new("UICorner")
	tooltipCorner.CornerRadius = UDim.new(0, 10)
	tooltipCorner.Parent = tooltip
	
	local tooltipStroke = Instance.new("UIStroke")
	tooltipStroke.Color = Color3.fromRGB(100, 100, 100)
	tooltipStroke.Thickness = 2
	tooltipStroke.Parent = tooltip
	self.tooltipStroke = tooltipStroke
	
	-- Tooltip: Item name
	local tooltipName = Instance.new("TextLabel")
	tooltipName.Name = "ItemName"
	tooltipName.Size = UDim2.new(1, -20, 0, 25)
	tooltipName.Position = UDim2.new(0, 10, 0, 8)
	tooltipName.BackgroundTransparency = 1
	tooltipName.Text = "Item Name"
	tooltipName.TextColor3 = Color3.fromRGB(255, 255, 255)
	tooltipName.TextSize = 18
	tooltipName.Font = Enum.Font.GothamBold
	tooltipName.TextXAlignment = Enum.TextXAlignment.Left
	tooltipName.ZIndex = 11
	tooltipName.Parent = tooltip
	self.tooltipName = tooltipName
	
	-- Tooltip: Rarity
	local tooltipRarity = Instance.new("TextLabel")
	tooltipRarity.Name = "Rarity"
	tooltipRarity.Size = UDim2.new(1, -20, 0, 16)
	tooltipRarity.Position = UDim2.new(0, 10, 0, 32)
	tooltipRarity.BackgroundTransparency = 1
	tooltipRarity.Text = "Common"
	tooltipRarity.TextColor3 = Color3.fromRGB(200, 200, 200)
	tooltipRarity.TextSize = 12
	tooltipRarity.Font = Enum.Font.GothamMedium
	tooltipRarity.TextXAlignment = Enum.TextXAlignment.Left
	tooltipRarity.ZIndex = 11
	tooltipRarity.Parent = tooltip
	self.tooltipRarity = tooltipRarity
	
	-- Tooltip: Description
	local tooltipDesc = Instance.new("TextLabel")
	tooltipDesc.Name = "Description"
	tooltipDesc.Size = UDim2.new(1, -20, 0, 45)
	tooltipDesc.Position = UDim2.new(0, 10, 0, 50)
	tooltipDesc.BackgroundTransparency = 1
	tooltipDesc.Text = "Item description here..."
	tooltipDesc.TextColor3 = Color3.fromRGB(180, 180, 180)
	tooltipDesc.TextSize = 14
	tooltipDesc.Font = Enum.Font.GothamMedium
	tooltipDesc.TextXAlignment = Enum.TextXAlignment.Left
	tooltipDesc.TextYAlignment = Enum.TextYAlignment.Top
	tooltipDesc.TextWrapped = true
	tooltipDesc.ZIndex = 11
	tooltipDesc.Parent = tooltip
	self.tooltipDesc = tooltipDesc
	
	-- Click on item to toggle tooltip
	itemFrame.MouseButton1Click:Connect(function()
		if self.currentItem then
			self:toggleTooltip()
		end
	end)
	
	-- Use button (ใต้ item frame)
	local useButton = Instance.new("TextButton")
	useButton.Name = "UseButton"
	useButton.Size = UDim2.new(0, 80, 0, 28)
	useButton.Position = UDim2.new(0.5, 0, 0, 85)
	useButton.AnchorPoint = Vector2.new(0.5, 0)
	useButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	useButton.BackgroundTransparency = 0.2
	useButton.BorderSizePixel = 0
	useButton.Text = "USE [E]"
	useButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	useButton.TextSize = 12
	useButton.Font = Enum.Font.GothamBold
	useButton.Parent = container
	self.useButton = useButton
	
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = useButton
	
	-- Status effects container (ด้านซ้ายของ item slot)
	local statusContainer = Instance.new("Frame")
	statusContainer.Name = "StatusEffects"
	statusContainer.Size = UDim2.new(0, 30, 0, 90)
	statusContainer.Position = UDim2.new(0, -5, 0, 0)
	statusContainer.BackgroundTransparency = 1
	statusContainer.Parent = container
	self.statusContainer = statusContainer
	
	local statusLayout = Instance.new("UIListLayout")
	statusLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statusLayout.Padding = UDim.new(0, 5)
	statusLayout.Parent = statusContainer
	
	-- Shield status icon
	local shieldIcon = self:createStatusIcon("Shield", "🛡️", Color3.fromRGB(100, 200, 255))
	shieldIcon.Parent = statusContainer
	shieldIcon.Visible = false
	self.shieldIcon = shieldIcon
	
	-- Boost status icon
	local boostIcon = self:createStatusIcon("Boost", "⚡", Color3.fromRGB(255, 255, 100))
	boostIcon.Parent = statusContainer
	boostIcon.Visible = false
	self.boostIcon = boostIcon
	
	-- Slow status icon
	local slowIcon = self:createStatusIcon("Slow", "🐢", Color3.fromRGB(150, 100, 200))
	slowIcon.Parent = statusContainer
	slowIcon.Visible = false
	self.slowIcon = slowIcon
	
	-- Button click for USE
	useButton.MouseButton1Click:Connect(function()
		self:useItem()
	end)
	
	-- Update initial state
	self:updateItemDisplay(nil)
end

function ItemUI:createStatusIcon(name: string, emoji: string, color: Color3): Frame
	local icon = Instance.new("Frame")
	icon.Name = name .. "Status"
	icon.Size = UDim2.new(0, 28, 0, 28)
	icon.BackgroundColor3 = color
	icon.BackgroundTransparency = 0.3
	icon.BorderSizePixel = 0
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = icon
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = emoji
	label.TextSize = 18
	label.Parent = icon
	
	return icon
end

function ItemUI:setupInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.E then
			self:useItem()
		end
	end)
end

function ItemUI:useItem()
	if not self.currentItem then return end
	
	-- Send to server
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseItem")
	remote:FireServer()
	
	-- Visual feedback
	self:playUseEffect()
end

function ItemUI:playUseEffect()
	-- Scale effect
	local originalSize = self.itemFrame.Size
	
	local shrinkTween = TweenService:Create(self.itemFrame, TweenInfo.new(0.1), {
		Size = UDim2.new(0, 70, 0, 70)
	})
	shrinkTween:Play()
	
	shrinkTween.Completed:Connect(function()
		local expandTween = TweenService:Create(self.itemFrame, TweenInfo.new(0.1), {
			Size = originalSize
		})
		expandTween:Play()
	end)
	
	-- Flash effect
	local flashTween = TweenService:Create(self.frameStroke, TweenInfo.new(0.1), {
		Color = Color3.fromRGB(255, 255, 255)
	})
	flashTween:Play()
	
	task.delay(0.2, function()
		if self.currentItem then
			local itemDef = ItemTypes.getItem(self.currentItem.id)
			if itemDef then
				self.frameStroke.Color = ItemTypes.getRarityColor(itemDef.rarity)
			end
		else
			self.frameStroke.Color = Color3.fromRGB(100, 100, 100)
		end
	end)
end

function ItemUI:updateItemDisplay(itemInfo: {id: string, name: string, description: string?, icon: string, rarity: string}?)
	self.currentItem = itemInfo
	
	-- ซ่อน tooltip เมื่อ item เปลี่ยน
	self.tooltip.Visible = false
	self.tooltipVisible = false
	
	if itemInfo then
		-- Show item
		self.emptyText.Visible = false
		self.iconText.Visible = true
		self.iconText.Text = itemInfo.name or "?"
		self.infoHint.Visible = true -- แสดง info hint
		
		-- Try to load icon
		if itemInfo.icon and itemInfo.icon ~= "" then
			self.iconImage.Image = itemInfo.icon
			self.iconImage.Visible = true
			self.iconText.Size = UDim2.new(1, -10, 0.3, 0)
			self.iconText.Position = UDim2.new(0.5, 0, 0.7, 0)
		else
			self.iconImage.Visible = false
			self.iconText.Size = UDim2.new(1, -10, 0.6, 0)
			self.iconText.Position = UDim2.new(0.5, 0, 0.3, 0)
		end
		
		-- Update tooltip content
		self.tooltipName.Text = itemInfo.name or "Unknown"
		self.tooltipRarity.Text = ItemTypes.getRarityName(itemInfo.rarity)
		self.tooltipDesc.Text = itemInfo.description or ""
		
		-- Set rarity color
		local rarityColor = ItemTypes.getRarityColor(itemInfo.rarity)
		self.frameStroke.Color = rarityColor
		self.tooltipStroke.Color = rarityColor
		self.tooltipRarity.TextColor3 = rarityColor
		self.itemFrame.BackgroundColor3 = Color3.new(
			rarityColor.R * 0.3,
			rarityColor.G * 0.3,
			rarityColor.B * 0.3
		)
		
		-- Enable button
		self.useButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
		self.useButton.BackgroundTransparency = 0.2
		self.useButton.Visible = true
	else
		-- No item
		self.emptyText.Visible = true
		self.iconText.Visible = false
		self.iconImage.Visible = false
		self.infoHint.Visible = false
		self.frameStroke.Color = Color3.fromRGB(100, 100, 100)
		self.itemFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
		
		-- Hide button when no item
		self.useButton.Visible = false
	end
end

-- Toggle tooltip visibility
function ItemUI:toggleTooltip()
	self.tooltipVisible = not self.tooltipVisible
	
	if self.tooltipVisible then
		-- Show with animation
		self.tooltip.Visible = true
		self.tooltip.Position = UDim2.new(0, -180, 0, 0)
		self.tooltip.BackgroundTransparency = 1
		
		local showTween = TweenService:Create(self.tooltip, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
			Position = UDim2.new(0, -210, 0, 0),
			BackgroundTransparency = 0.1
		})
		showTween:Play()
		
		-- Auto-hide after 6 seconds
		task.delay(6, function()
			if self.tooltipVisible then
				self:hideTooltip()
			end
		end)
	else
		self:hideTooltip()
	end
end

-- Hide tooltip
function ItemUI:hideTooltip()
	self.tooltipVisible = false
	
	local hideTween = TweenService:Create(self.tooltip, TweenInfo.new(0.15), {
		Position = UDim2.new(0, -180, 0, 0),
		BackgroundTransparency = 1
	})
	hideTween:Play()
	
	hideTween.Completed:Connect(function()
		if not self.tooltipVisible then
			self.tooltip.Visible = false
		end
	end)
end

function ItemUI:updateItems(data: {[string]: any})
	-- Update current item
	-- Server ส่ง false เมื่อไม่มี item, table เมื่อมี item
	if data.currentItem ~= nil then
		if data.currentItem == false then
			-- Item ถูกใช้แล้ว - หาย
			self:updateItemDisplay(nil)
		else
			-- มี item ใหม่
			self:updateItemDisplay(data.currentItem)
		end
	end
	
	-- Update status effects
	if data.hasShield ~= nil then
		self.hasShield = data.hasShield
		self.shieldIcon.Visible = data.hasShield
	end
	
	if data.isBoosted ~= nil then
		self.isBoosted = data.isBoosted
		self.boostIcon.Visible = data.isBoosted
	end
	
	if data.isSlowed ~= nil then
		self.isSlowed = data.isSlowed
		self.slowIcon.Visible = data.isSlowed
	end
end

-- Roulette animation when getting new item
function ItemUI:playRouletteAnimation(finalItem: {id: string, name: string, icon: string, rarity: string})
	-- Get all items for roulette
	local allItemIds = ItemTypes.getAllItemIds()
	
	-- Show spinning animation
	local spinDuration = 1.5
	local spinCount = 15
	local delayPerSpin = spinDuration / spinCount
	
	task.spawn(function()
		for i = 1, spinCount do
			-- Random item display
			local randomId = allItemIds[math.random(#allItemIds)]
			local randomItem = ItemTypes.getItem(randomId)
			
			if randomItem then
				self:updateItemDisplay({
					id = randomItem.id,
					name = randomItem.name,
					icon = randomItem.icon,
					rarity = randomItem.rarity,
				})
			end
			
			-- Flash effect
			self.itemFrame.BackgroundTransparency = 0
			task.wait(delayPerSpin * 0.5)
			self.itemFrame.BackgroundTransparency = 0.2
			task.wait(delayPerSpin * 0.5)
		end
		
		-- Final item
		self:updateItemDisplay(finalItem)
		
		-- Celebration effect
		self:playItemReceivedEffect(finalItem)
	end)
end

function ItemUI:playItemReceivedEffect(item: {rarity: string})
	local rarityColor = ItemTypes.getRarityColor(item.rarity)
	
	-- Glow effect
	local glowTween = TweenService:Create(self.frameStroke, TweenInfo.new(0.3), {
		Thickness = 4,
		Color = rarityColor
	})
	glowTween:Play()
	
	task.delay(0.5, function()
		TweenService:Create(self.frameStroke, TweenInfo.new(0.2), {
			Thickness = 2
		}):Play()
	end)
	
	-- Scale pop
	local popTween = TweenService:Create(self.itemFrame, TweenInfo.new(0.15, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 90, 0, 90)
	})
	popTween:Play()
	
	task.delay(0.15, function()
		TweenService:Create(self.itemFrame, TweenInfo.new(0.1), {
			Size = UDim2.new(0, 80, 0, 80)
		}):Play()
	end)
end

return ItemUI
