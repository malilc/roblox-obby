-- ItemUI: แสดง 2 Item Slots และ Status Effects

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
	self.itemSlots = {nil, nil} -- 2 item slots
	self.hasShield = false
	self.isBoosted = false
	self.isSlowed = false
	self.tooltipVisible = false
	self.activeTooltipSlot = nil
	
	-- UI references for each slot
	self.slotFrames = {}
	self.slotIcons = {}
	self.slotTexts = {}
	self.slotEmptyTexts = {}
	self.slotStrokes = {}
	self.slotLabels = {}
	
	self:createUI()
	self:setupInput()
	
	return self
end

function ItemUI:createUI()
	-- Main item container (มุมล่างขวา) - กว้างขึ้นสำหรับ 2 slots
	local container = Instance.new("Frame")
	container.Name = "ItemContainer"
	container.Size = UDim2.new(0, 210, 0, 115)
	container.Position = UDim2.new(1, -220, 1, -125)
	container.BackgroundTransparency = 1
	container.Parent = self.parent
	self.container = container
	
	-- สร้าง 2 item slots (horizontal layout)
	for slotIndex = 1, 2 do
		self:createSlot(slotIndex, container)
	end
	
	-- Tooltip popup (ซ่อนไว้ก่อน แสดงเมื่อคลิก)
	local tooltip = Instance.new("Frame")
	tooltip.Name = "ItemTooltip"
	tooltip.Size = UDim2.new(0, 200, 0, 100)
	tooltip.Position = UDim2.new(0, -10, 0, -110) -- ด้านบนของ item
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
	
	-- Status effects container (ด้านซ้ายสุด)
	local statusContainer = Instance.new("Frame")
	statusContainer.Name = "StatusEffects"
	statusContainer.Size = UDim2.new(0, 30, 0, 90)
	statusContainer.Position = UDim2.new(0, -40, 0, 0)
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
	
	-- Initialize both slots as empty
	for i = 1, 2 do
		self:updateSlotDisplay(i, nil)
	end
end

-- Create a single item slot
function ItemUI:createSlot(slotIndex: number, parent: Frame)
	local xOffset = (slotIndex - 1) * 100 + 5 -- Slot 1 at 5, Slot 2 at 105
	
	-- Item slot frame - clickable
	local slotFrame = Instance.new("TextButton")
	slotFrame.Name = "ItemSlot" .. slotIndex
	slotFrame.Size = UDim2.new(0, 90, 0, 90)
	slotFrame.Position = UDim2.new(0, xOffset, 0, 0)
	slotFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	slotFrame.BackgroundTransparency = 0.2
	slotFrame.BorderSizePixel = 0
	slotFrame.Text = ""
	slotFrame.AutoButtonColor = false
	slotFrame.Parent = parent
	self.slotFrames[slotIndex] = slotFrame
	
	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 12)
	frameCorner.Parent = slotFrame
	
	-- Border/glow
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 100, 100)
	stroke.Thickness = 2
	stroke.Parent = slotFrame
	self.slotStrokes[slotIndex] = stroke
	
	-- Slot number label (มุมบนซ้าย)
	local slotLabel = Instance.new("TextLabel")
	slotLabel.Name = "SlotLabel"
	slotLabel.Size = UDim2.new(0, 24, 0, 24)
	slotLabel.Position = UDim2.new(0, 4, 0, 4)
	slotLabel.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	slotLabel.BackgroundTransparency = 0.3
	slotLabel.Text = tostring(slotIndex)
	slotLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	slotLabel.TextSize = 14
	slotLabel.Font = Enum.Font.GothamBold
	slotLabel.Parent = slotFrame
	self.slotLabels[slotIndex] = slotLabel
	
	local labelCorner = Instance.new("UICorner")
	labelCorner.CornerRadius = UDim.new(0, 6)
	labelCorner.Parent = slotLabel
	
	-- Item icon
	local iconImage = Instance.new("ImageLabel")
	iconImage.Name = "ItemIcon"
	iconImage.Size = UDim2.new(0.6, 0, 0.6, 0)
	iconImage.Position = UDim2.new(0.5, 0, 0.45, 0)
	iconImage.AnchorPoint = Vector2.new(0.5, 0.5)
	iconImage.BackgroundTransparency = 1
	iconImage.Image = ""
	iconImage.Visible = false
	iconImage.Parent = slotFrame
	self.slotIcons[slotIndex] = iconImage
	
	-- Item name fallback (text)
	local iconText = Instance.new("TextLabel")
	iconText.Name = "ItemIconText"
	iconText.Size = UDim2.new(1, -10, 0.4, 0)
	iconText.Position = UDim2.new(0.5, 0, 0.55, 0)
	iconText.AnchorPoint = Vector2.new(0.5, 0.5)
	iconText.BackgroundTransparency = 1
	iconText.Text = ""
	iconText.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconText.TextSize = 11
	iconText.TextScaled = true
	iconText.Font = Enum.Font.GothamBold
	iconText.Visible = false
	iconText.Parent = slotFrame
	self.slotTexts[slotIndex] = iconText
	
	-- Empty slot text
	local emptyText = Instance.new("TextLabel")
	emptyText.Name = "EmptyText"
	emptyText.Size = UDim2.new(1, 0, 1, 0)
	emptyText.BackgroundTransparency = 1
	emptyText.Text = "?"
	emptyText.TextColor3 = Color3.fromRGB(100, 100, 100)
	emptyText.TextSize = 32
	emptyText.Font = Enum.Font.GothamBlack
	emptyText.Parent = slotFrame
	self.slotEmptyTexts[slotIndex] = emptyText
	
	-- Click on slot to show tooltip
	slotFrame.MouseButton1Click:Connect(function()
		if self.itemSlots[slotIndex] then
			self:toggleTooltipForSlot(slotIndex)
		end
	end)
	
	-- Keybind hint label (ด้านล่าง)
	local keybindHint = Instance.new("TextLabel")
	keybindHint.Name = "KeybindHint"
	keybindHint.Size = UDim2.new(1, 0, 0, 18)
	keybindHint.Position = UDim2.new(0, 0, 1, 2)
	keybindHint.BackgroundTransparency = 1
	keybindHint.Text = "[" .. slotIndex .. "]"
	keybindHint.TextColor3 = Color3.fromRGB(150, 150, 150)
	keybindHint.TextSize = 12
	keybindHint.Font = Enum.Font.GothamMedium
	keybindHint.Parent = slotFrame
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
		
		-- Keybind 1 = use slot 1
		if input.KeyCode == Enum.KeyCode.One then
			self:useItemFromSlot(1)
		-- Keybind 2 = use slot 2
		elseif input.KeyCode == Enum.KeyCode.Two then
			self:useItemFromSlot(2)
		end
	end)
end

function ItemUI:useItemFromSlot(slotIndex: number)
	if not self.itemSlots[slotIndex] then return end
	
	-- Send to server with slot index
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseItem")
	remote:FireServer(slotIndex)
	
	-- Visual feedback
	self:playUseEffectForSlot(slotIndex)
end

function ItemUI:playUseEffectForSlot(slotIndex: number)
	local slotFrame = self.slotFrames[slotIndex]
	local slotStroke = self.slotStrokes[slotIndex]
	if not slotFrame or not slotStroke then return end
	
	-- Scale effect
	local originalSize = slotFrame.Size
	
	local shrinkTween = TweenService:Create(slotFrame, TweenInfo.new(0.1), {
		Size = UDim2.new(0, 80, 0, 80)
	})
	shrinkTween:Play()
	
	shrinkTween.Completed:Connect(function()
		local expandTween = TweenService:Create(slotFrame, TweenInfo.new(0.1), {
			Size = originalSize
		})
		expandTween:Play()
	end)
	
	-- Flash effect
	local flashTween = TweenService:Create(slotStroke, TweenInfo.new(0.1), {
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 4
	})
	flashTween:Play()
	
	task.delay(0.2, function()
		local itemInfo = self.itemSlots[slotIndex]
		if itemInfo then
			local itemDef = ItemTypes.getItem(itemInfo.id)
			if itemDef then
				slotStroke.Color = ItemTypes.getRarityColor(itemDef.rarity)
			end
		else
			slotStroke.Color = Color3.fromRGB(100, 100, 100)
		end
		slotStroke.Thickness = 2
	end)
end

-- Update display for a specific slot
function ItemUI:updateSlotDisplay(slotIndex: number, itemInfo: {id: string, name: string, description: string?, icon: string, rarity: string}?)
	self.itemSlots[slotIndex] = itemInfo
	
	local slotFrame = self.slotFrames[slotIndex]
	local slotIcon = self.slotIcons[slotIndex]
	local slotText = self.slotTexts[slotIndex]
	local slotEmptyText = self.slotEmptyTexts[slotIndex]
	local slotStroke = self.slotStrokes[slotIndex]
	
	if not slotFrame then return end
	
	-- Get or create emoji icon label
	local emojiIcon = slotFrame:FindFirstChild("EmojiIcon")
	if not emojiIcon then
		emojiIcon = Instance.new("TextLabel")
		emojiIcon.Name = "EmojiIcon"
		emojiIcon.Size = UDim2.new(0.8, 0, 0.5, 0)
		emojiIcon.Position = UDim2.new(0.5, 0, 0.35, 0)
		emojiIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		emojiIcon.BackgroundTransparency = 1
		emojiIcon.Text = ""
		emojiIcon.TextSize = 32
		emojiIcon.Font = Enum.Font.GothamBold
		emojiIcon.Visible = false
		emojiIcon.Parent = slotFrame
	end
	
	-- ซ่อน tooltip ถ้า slot นี้กำลังแสดงอยู่
	if self.activeTooltipSlot == slotIndex then
		self.tooltip.Visible = false
		self.tooltipVisible = false
		self.activeTooltipSlot = nil
	end
	
	if itemInfo then
		-- Show item
		slotEmptyText.Visible = false
		slotText.Visible = true
		slotText.Text = itemInfo.name or "?"
		
		-- Check if icon is emoji (not starting with "rbxassetid://")
		local isEmoji = itemInfo.icon and not string.find(itemInfo.icon, "rbxassetid://")
		
		if isEmoji then
			-- Show emoji icon
			emojiIcon.Text = itemInfo.icon
			emojiIcon.Visible = true
			slotIcon.Visible = false
			slotText.Size = UDim2.new(1, -10, 0.25, 0)
			slotText.Position = UDim2.new(0.5, 0, 0.75, 0)
		elseif itemInfo.icon and itemInfo.icon ~= "" then
			-- Try to load image icon
			slotIcon.Image = itemInfo.icon
			slotIcon.Visible = true
			emojiIcon.Visible = false
			slotText.Size = UDim2.new(1, -10, 0.25, 0)
			slotText.Position = UDim2.new(0.5, 0, 0.8, 0)
		else
			slotIcon.Visible = false
			emojiIcon.Visible = false
			slotText.Size = UDim2.new(1, -10, 0.4, 0)
			slotText.Position = UDim2.new(0.5, 0, 0.55, 0)
		end
		
		-- Set rarity color
		local rarityColor = ItemTypes.getRarityColor(itemInfo.rarity)
		slotStroke.Color = rarityColor
		slotFrame.BackgroundColor3 = Color3.new(
			rarityColor.R * 0.3,
			rarityColor.G * 0.3,
			rarityColor.B * 0.3
		)
	else
		-- No item in this slot
		slotEmptyText.Visible = true
		slotText.Visible = false
		slotIcon.Visible = false
		emojiIcon.Visible = false
		slotStroke.Color = Color3.fromRGB(100, 100, 100)
		slotFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	end
end

-- Toggle tooltip visibility for a specific slot
function ItemUI:toggleTooltipForSlot(slotIndex: number)
	local itemInfo = self.itemSlots[slotIndex]
	if not itemInfo then return end
	
	-- ถ้า tooltip กำลังแสดงอยู่สำหรับ slot อื่น ให้ปิดก่อน
	if self.tooltipVisible and self.activeTooltipSlot ~= slotIndex then
		self.tooltip.Visible = false
		self.tooltipVisible = false
	end
	
	self.tooltipVisible = not self.tooltipVisible
	self.activeTooltipSlot = slotIndex
	
	if self.tooltipVisible then
		-- Update tooltip content
		self.tooltipName.Text = itemInfo.name or "Unknown"
		self.tooltipRarity.Text = ItemTypes.getRarityName(itemInfo.rarity)
		self.tooltipDesc.Text = itemInfo.description or ""
		
		local rarityColor = ItemTypes.getRarityColor(itemInfo.rarity)
		self.tooltipStroke.Color = rarityColor
		self.tooltipRarity.TextColor3 = rarityColor
		
		-- Show with animation (ด้านบน)
		self.tooltip.Visible = true
		self.tooltip.Position = UDim2.new(0, -10, 0, -90)
		self.tooltip.BackgroundTransparency = 1
		
		local showTween = TweenService:Create(self.tooltip, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
			Position = UDim2.new(0, -10, 0, -110),
			BackgroundTransparency = 0.1
		})
		showTween:Play()
		
		-- Auto-hide after 6 seconds
		local currentSlot = slotIndex
		task.delay(6, function()
			if self.tooltipVisible and self.activeTooltipSlot == currentSlot then
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
	self.activeTooltipSlot = nil
	
	local hideTween = TweenService:Create(self.tooltip, TweenInfo.new(0.15), {
		Position = UDim2.new(0, -10, 0, -90),
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
	-- Update item slots (array of 2)
	-- Server ส่ง itemSlots = {slot1, slot2} โดย false = empty, table = has item
	if data.itemSlots then
		for slotIndex = 1, 2 do
			local slotData = data.itemSlots[slotIndex]
			if slotData == false then
				-- Slot is empty
				self:updateSlotDisplay(slotIndex, nil)
			elseif slotData then
				-- Has item
				self:updateSlotDisplay(slotIndex, slotData)
			end
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

-- Roulette animation when getting new item in a specific slot
function ItemUI:playRouletteAnimationForSlot(slotIndex: number, finalItem: {id: string, name: string, icon: string, rarity: string})
	-- Get all items for roulette
	local allItemIds = ItemTypes.getAllItemIds()
	
	-- Show spinning animation
	local spinDuration = 1.5
	local spinCount = 15
	local delayPerSpin = spinDuration / spinCount
	
	local slotFrame = self.slotFrames[slotIndex]
	if not slotFrame then return end
	
	task.spawn(function()
		for i = 1, spinCount do
			-- Random item display
			local randomId = allItemIds[math.random(#allItemIds)]
			local randomItem = ItemTypes.getItem(randomId)
			
			if randomItem then
				self:updateSlotDisplay(slotIndex, {
					id = randomItem.id,
					name = randomItem.name,
					icon = randomItem.icon,
					rarity = randomItem.rarity,
				})
			end
			
			-- Flash effect
			slotFrame.BackgroundTransparency = 0
			task.wait(delayPerSpin * 0.5)
			slotFrame.BackgroundTransparency = 0.2
			task.wait(delayPerSpin * 0.5)
		end
		
		-- Final item
		self:updateSlotDisplay(slotIndex, finalItem)
		
		-- Celebration effect
		self:playItemReceivedEffectForSlot(slotIndex, finalItem)
	end)
end

function ItemUI:playItemReceivedEffectForSlot(slotIndex: number, item: {rarity: string})
	local slotFrame = self.slotFrames[slotIndex]
	local slotStroke = self.slotStrokes[slotIndex]
	if not slotFrame or not slotStroke then return end
	
	local rarityColor = ItemTypes.getRarityColor(item.rarity)
	
	-- Glow effect
	local glowTween = TweenService:Create(slotStroke, TweenInfo.new(0.3), {
		Thickness = 4,
		Color = rarityColor
	})
	glowTween:Play()
	
	task.delay(0.5, function()
		TweenService:Create(slotStroke, TweenInfo.new(0.2), {
			Thickness = 2
		}):Play()
	end)
	
	-- Scale pop
	local popTween = TweenService:Create(slotFrame, TweenInfo.new(0.15, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 100, 0, 100)
	})
	popTween:Play()
	
	task.delay(0.15, function()
		TweenService:Create(slotFrame, TweenInfo.new(0.1), {
			Size = UDim2.new(0, 90, 0, 90)
		}):Play()
	end)
end

return ItemUI
