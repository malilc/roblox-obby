-- MobileInputUI: Touch buttons สำหรับมือถือ (Item 1/2, Sprint, Double Jump)
-- แสดงเฉพาะบน touch-enabled devices เท่านั้น

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MobileInputUI = {}
MobileInputUI.__index = MobileInputUI

function MobileInputUI.new(parent: ScreenGui, dependencies: {
	itemUI: any,
	ultimateSkillController: any,
})
	local self = setmetatable({}, MobileInputUI)

	self.parent = parent
	self.itemUI = dependencies.itemUI
	self.ultimateController = dependencies.ultimateSkillController
	self.isTouchDevice = UserInputService.TouchEnabled

	if not self.isTouchDevice then
		print("[MobileInputUI] Not a touch device, skipping")
		return self
	end

	self:createUI()
	self:startUpdateLoop()

	print("[MobileInputUI] Touch buttons initialized")
	return self
end

function MobileInputUI:createUI()
	-- === Item Buttons (ขวาล่าง, เหนือ ItemUI container) ===
	local itemButtonContainer = Instance.new("Frame")
	itemButtonContainer.Name = "MobileItemButtons"
	itemButtonContainer.Size = UDim2.new(0, 160, 0, 70)
	itemButtonContainer.Position = UDim2.new(1, -170, 1, -210)
	itemButtonContainer.BackgroundTransparency = 1
	itemButtonContainer.Parent = self.parent

	self.itemButton1 = self:createTouchButton(itemButtonContainer, "Item1", "[1]", UDim2.new(0, 0, 0, 0), function()
		self.itemUI:useItemFromSlot(1)
	end)

	self.itemButton2 = self:createTouchButton(itemButtonContainer, "Item2", "[2]", UDim2.new(0, 80, 0, 0), function()
		self.itemUI:useItemFromSlot(2)
	end)

	-- Item emoji labels (แสดง icon ของ item ปัจจุบัน)
	self.itemEmoji1 = self:createEmojiLabel(self.itemButton1)
	self.itemEmoji2 = self:createEmojiLabel(self.itemButton2)

	-- === Ultimate Buttons (ซ้ายล่าง) ===
	local ultimateContainer = Instance.new("Frame")
	ultimateContainer.Name = "MobileUltimateButtons"
	ultimateContainer.Size = UDim2.new(0, 160, 0, 70)
	ultimateContainer.Position = UDim2.new(0, 10, 1, -90)
	ultimateContainer.BackgroundTransparency = 1
	ultimateContainer.Parent = self.parent
	self.ultimateContainer = ultimateContainer

	self.sprintButton = self:createTouchButton(ultimateContainer, "Sprint", "SPRINT", UDim2.new(0, 0, 0, 0), function()
		self.ultimateController:tryActivateSprint()
	end)
	self.sprintButton.Visible = false

	self.jumpButton = self:createTouchButton(ultimateContainer, "Jump", "JUMP", UDim2.new(0, 80, 0, 0), function()
		self.ultimateController:tryDoubleJump()
	end)
	self.jumpButton.Visible = false

	-- Sprint cooldown overlay
	self.sprintCooldownOverlay = Instance.new("Frame")
	self.sprintCooldownOverlay.Name = "CooldownOverlay"
	self.sprintCooldownOverlay.Size = UDim2.new(1, 0, 0, 0)
	self.sprintCooldownOverlay.Position = UDim2.new(0, 0, 1, 0)
	self.sprintCooldownOverlay.AnchorPoint = Vector2.new(0, 1)
	self.sprintCooldownOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	self.sprintCooldownOverlay.BackgroundTransparency = 0.5
	self.sprintCooldownOverlay.BorderSizePixel = 0
	self.sprintCooldownOverlay.ZIndex = 3
	self.sprintCooldownOverlay.Parent = self.sprintButton

	local cooldownCorner = Instance.new("UICorner")
	cooldownCorner.CornerRadius = UDim.new(0, 12)
	cooldownCorner.Parent = self.sprintCooldownOverlay
end

function MobileInputUI:createTouchButton(parent: Frame, name: string, label: string, position: UDim2, callback: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.new(0, 70, 0, 70)
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
	button.BackgroundTransparency = 0.3
	button.BorderSizePixel = 0
	button.Text = label
	button.TextColor3 = Color3.fromRGB(200, 200, 200)
	button.TextSize = 14
	button.Font = Enum.Font.GothamBold
	button.AutoButtonColor = false
	button.ZIndex = 2
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 100, 120)
	stroke.Thickness = 2
	stroke.Parent = button

	-- Tap feedback
	button.MouseButton1Down:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.08), {
			Size = UDim2.new(0, 62, 0, 62),
			BackgroundTransparency = 0.1,
		}):Play()
	end)

	button.MouseButton1Up:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.08), {
			Size = UDim2.new(0, 70, 0, 70),
			BackgroundTransparency = 0.3,
		}):Play()
	end)

	button.MouseButton1Click:Connect(callback)

	return button
end

function MobileInputUI:createEmojiLabel(parent: TextButton): TextLabel
	local emoji = Instance.new("TextLabel")
	emoji.Name = "ItemEmoji"
	emoji.Size = UDim2.new(1, 0, 0.6, 0)
	emoji.Position = UDim2.new(0, 0, 0, 2)
	emoji.BackgroundTransparency = 1
	emoji.Text = ""
	emoji.TextSize = 28
	emoji.Font = Enum.Font.GothamBold
	emoji.TextColor3 = Color3.fromRGB(255, 255, 255)
	emoji.ZIndex = 3
	emoji.Visible = false
	emoji.Parent = parent
	return emoji
end

function MobileInputUI:startUpdateLoop()
	self.updateConnection = RunService.Heartbeat:Connect(function()
		self:updateItemButtons()
		self:updateUltimateButtons()
	end)
end

function MobileInputUI:updateItemButtons()
	-- อัพเดท item button 1
	local item1 = self.itemUI.itemSlots[1]
	if item1 then
		self.itemEmoji1.Text = item1.icon or ""
		self.itemEmoji1.Visible = true
		self.itemButton1.Text = ""
	else
		self.itemEmoji1.Visible = false
		self.itemButton1.Text = "[1]"
	end

	-- อัพเดท item button 2
	local item2 = self.itemUI.itemSlots[2]
	if item2 then
		self.itemEmoji2.Text = item2.icon or ""
		self.itemEmoji2.Visible = true
		self.itemButton2.Text = ""
	else
		self.itemEmoji2.Visible = false
		self.itemButton2.Text = "[2]"
	end
end

function MobileInputUI:updateUltimateButtons()
	local controller = self.ultimateController
	local currentClass = controller.currentClass
	local unlocked = controller.ultimateUnlocked

	-- Sprint button (Runner class only)
	local skillConfig = Config.Mastery and Config.Mastery.UltimateSkills and Config.Mastery.UltimateSkills[currentClass]

	if unlocked and skillConfig and skillConfig.id == "Sprint" then
		self.sprintButton.Visible = true

		-- Cooldown overlay
		local cooldown = controller:getSprintCooldown()
		local maxCooldown = skillConfig.cooldown or 15
		if cooldown > 0 then
			local ratio = cooldown / maxCooldown
			self.sprintCooldownOverlay.Size = UDim2.new(1, 0, ratio, 0)
			self.sprintCooldownOverlay.Visible = true
			self.sprintButton.TextColor3 = Color3.fromRGB(120, 120, 120)
		else
			self.sprintCooldownOverlay.Visible = false
			if controller:isSprinting() then
				self.sprintButton.TextColor3 = Color3.fromRGB(100, 200, 255)
			else
				self.sprintButton.TextColor3 = Color3.fromRGB(200, 200, 200)
			end
		end
	else
		self.sprintButton.Visible = false
	end

	-- Jump button (Jumper class only)
	if unlocked and skillConfig and skillConfig.id == "DoubleJump" then
		self.jumpButton.Visible = true
	else
		self.jumpButton.Visible = false
	end
end

return MobileInputUI
