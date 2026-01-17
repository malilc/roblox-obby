-- ItemUI: แสดง Push Item และปุ่มใช้งาน

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local ItemUI = {}
ItemUI.__index = ItemUI

function ItemUI.new(parent: ScreenGui)
	local self = setmetatable({}, ItemUI)
	
	self.parent = parent
	self.pushCount = 1
	self.cooldown = 0
	self.onCooldown = false
	
	self:createUI()
	self:setupInput()
	
	return self
end

function ItemUI:createUI()
	-- Main frame
	local frame = Instance.new("Frame")
	frame.Name = "ItemFrame"
	frame.Size = UDim2.new(0, 120, 0, 140)
	frame.Position = UDim2.new(1, -140, 1, -160)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Parent = self.parent
	self.frame = frame
	
	-- Corner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	
	-- Stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 100, 100)
	stroke.Thickness = 2
	stroke.Transparency = 0.5
	stroke.Parent = frame
	
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 25)
	title.Position = UDim2.new(0, 0, 0, 5)
	title.BackgroundTransparency = 1
	title.Text = "PUSH"
	title.TextColor3 = Color3.fromRGB(255, 100, 100)
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold
	title.Parent = frame
	
	-- Push button
	local button = Instance.new("TextButton")
	button.Name = "PushButton"
	button.Size = UDim2.new(0, 80, 0, 80)
	button.Position = UDim2.new(0.5, -40, 0, 30)
	button.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	button.BorderSizePixel = 0
	button.Text = ""
	button.Parent = frame
	self.button = button
	
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 40)
	buttonCorner.Parent = button
	
	-- Icon (fist emoji alternative - using text)
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(1, 0, 0.6, 0)
	icon.Position = UDim2.new(0, 0, 0, 0)
	icon.BackgroundTransparency = 1
	icon.Text = "👊"
	icon.TextSize = 36
	icon.Parent = button
	self.icon = icon
	
	-- Count label
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "Count"
	countLabel.Size = UDim2.new(1, 0, 0.4, 0)
	countLabel.Position = UDim2.new(0, 0, 0.6, 0)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = "x1"
	countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countLabel.TextSize = 18
	countLabel.Font = Enum.Font.GothamBold
	countLabel.Parent = button
	self.countLabel = countLabel
	
	-- Cooldown overlay
	local cooldownOverlay = Instance.new("Frame")
	cooldownOverlay.Name = "CooldownOverlay"
	cooldownOverlay.Size = UDim2.new(1, 0, 0, 0)
	cooldownOverlay.Position = UDim2.new(0, 0, 1, 0)
	cooldownOverlay.AnchorPoint = Vector2.new(0, 1)
	cooldownOverlay.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	cooldownOverlay.BackgroundTransparency = 0.5
	cooldownOverlay.BorderSizePixel = 0
	cooldownOverlay.ZIndex = 2
	cooldownOverlay.Parent = button
	self.cooldownOverlay = cooldownOverlay
	
	local overlayCorner = Instance.new("UICorner")
	overlayCorner.CornerRadius = UDim.new(0, 40)
	overlayCorner.Parent = cooldownOverlay
	
	-- Hotkey hint
	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, 0, 0, 20)
	hint.Position = UDim2.new(0, 0, 1, -25)
	hint.BackgroundTransparency = 1
	hint.Text = "Press [E]"
	hint.TextColor3 = Color3.fromRGB(150, 150, 150)
	hint.TextSize = 12
	hint.Font = Enum.Font.Gotham
	hint.Parent = frame
	
	-- Button click
	button.MouseButton1Click:Connect(function()
		self:usePush()
	end)
end

function ItemUI:setupInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.E then
			self:usePush()
		end
	end)
end

function ItemUI:usePush()
	if self.onCooldown then return end
	if self.pushCount <= 0 then return end
	
	-- Send to server
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UseItem")
	remote:FireServer()
	
	-- Visual feedback
	self:playUseEffect()
end

function ItemUI:playUseEffect()
	-- Scale effect
	local originalSize = self.button.Size
	
	local shrinkTween = TweenService:Create(self.button, TweenInfo.new(0.1), {
		Size = UDim2.new(0, 70, 0, 70),
		Position = UDim2.new(0.5, -35, 0, 35)
	})
	shrinkTween:Play()
	
	shrinkTween.Completed:Connect(function()
		local expandTween = TweenService:Create(self.button, TweenInfo.new(0.1), {
			Size = UDim2.new(0, 80, 0, 80),
			Position = UDim2.new(0.5, -40, 0, 30)
		})
		expandTween:Play()
	end)
end

function ItemUI:updateItems(data: {[string]: any})
	if data.pushCount ~= nil then
		self.pushCount = data.pushCount
		self.countLabel.Text = "x" .. tostring(self.pushCount)
		
		-- Update button state
		if self.pushCount <= 0 then
			self.button.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		else
			self.button.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
		end
	end
	
	if data.pushCooldown and data.pushCooldown > 0 then
		self:startCooldown(data.pushCooldown)
	end
end

function ItemUI:startCooldown(duration: number)
	self.onCooldown = true
	self.cooldown = duration
	
	-- Animate cooldown overlay
	self.cooldownOverlay.Size = UDim2.new(1, 0, 1, 0)
	
	local tween = TweenService:Create(self.cooldownOverlay, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = UDim2.new(1, 0, 0, 0)
	})
	tween:Play()
	
	tween.Completed:Connect(function()
		self.onCooldown = false
	end)
end

return ItemUI
