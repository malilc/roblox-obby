-- FlyController: ระบบบินสำหรับทดสอบ (กด F เพื่อเปิด/ปิด)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Logger)

local LocalPlayer = Players.LocalPlayer

local FlyController = {}
FlyController.__index = FlyController

function FlyController.new()
	local self = setmetatable({}, FlyController)
	
	self.isFlying = false
	self.flySpeed = 50
	self.bodyGyro = nil
	self.bodyVelocity = nil
	self.connection = nil
	
	self:setupInput()
	self:createUI()
	
	return self
end

function FlyController:setupInput()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.F then
			self:toggleFly()
		end
	end)
end

function FlyController:createUI()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "FlyUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
	
	-- Fly button (เล็กลง + มุมล่างซ้าย)
	local flyButton = Instance.new("TextButton")
	flyButton.Name = "FlyButton"
	flyButton.Size = UDim2.new(0, 50, 0, 25)
	flyButton.Position = UDim2.new(0, 10, 1, -35)
	flyButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
	flyButton.BackgroundTransparency = 0.4
	flyButton.Text = "FLY"
	flyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	flyButton.TextSize = 11
	flyButton.Font = Enum.Font.GothamBold
	flyButton.Parent = screenGui
	self.flyButton = flyButton
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = flyButton
	
	-- Speed label (ข้างปุ่ม)
	local speedLabel = Instance.new("TextLabel")
	speedLabel.Name = "SpeedLabel"
	speedLabel.Size = UDim2.new(0, 40, 0, 25)
	speedLabel.Position = UDim2.new(0, 65, 1, -35)
	speedLabel.BackgroundTransparency = 1
	speedLabel.Text = "50"
	speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	speedLabel.TextSize = 11
	speedLabel.Font = Enum.Font.Gotham
	speedLabel.Parent = screenGui
	self.speedLabel = speedLabel
	
	-- Speed up button
	local speedUpBtn = Instance.new("TextButton")
	speedUpBtn.Name = "SpeedUp"
	speedUpBtn.Size = UDim2.new(0, 20, 0, 25)
	speedUpBtn.Position = UDim2.new(0, 105, 1, -35)
	speedUpBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
	speedUpBtn.BackgroundTransparency = 0.4
	speedUpBtn.Text = "+"
	speedUpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	speedUpBtn.TextSize = 14
	speedUpBtn.Font = Enum.Font.GothamBold
	speedUpBtn.Parent = screenGui
	
	local cornerUp = Instance.new("UICorner")
	cornerUp.CornerRadius = UDim.new(0, 4)
	cornerUp.Parent = speedUpBtn
	
	-- Speed down button
	local speedDownBtn = Instance.new("TextButton")
	speedDownBtn.Name = "SpeedDown"
	speedDownBtn.Size = UDim2.new(0, 20, 0, 25)
	speedDownBtn.Position = UDim2.new(0, 128, 1, -35)
	speedDownBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
	speedDownBtn.BackgroundTransparency = 0.4
	speedDownBtn.Text = "-"
	speedDownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	speedDownBtn.TextSize = 16
	speedDownBtn.Font = Enum.Font.GothamBold
	speedDownBtn.Parent = screenGui
	
	local cornerDown = Instance.new("UICorner")
	cornerDown.CornerRadius = UDim.new(0, 4)
	cornerDown.Parent = speedDownBtn
	
	-- Button events
	flyButton.MouseButton1Click:Connect(function()
		self:toggleFly()
	end)
	
	speedUpBtn.MouseButton1Click:Connect(function()
		self.flySpeed = math.min(self.flySpeed + 25, 200)
		self.speedLabel.Text = tostring(self.flySpeed)
	end)
	
	speedDownBtn.MouseButton1Click:Connect(function()
		self.flySpeed = math.max(self.flySpeed - 25, 25)
		self.speedLabel.Text = tostring(self.flySpeed)
	end)
end

function FlyController:toggleFly()
	if self.isFlying then
		self:stopFly()
	else
		self:startFly()
	end
end

function FlyController:startFly()
	local character = LocalPlayer.Character
	if not character then return end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoidRootPart or not humanoid then return end
	
	self.isFlying = true
	self.flyButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
	self.flyButton.BackgroundTransparency = 0.2
	self.flyButton.Text = "LAND"
	
	-- Create BodyGyro for rotation stability
	self.bodyGyro = Instance.new("BodyGyro")
	self.bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	self.bodyGyro.P = 10000
	self.bodyGyro.D = 500
	self.bodyGyro.Parent = humanoidRootPart
	
	-- Create BodyVelocity for movement
	self.bodyVelocity = Instance.new("BodyVelocity")
	self.bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	self.bodyVelocity.Velocity = Vector3.zero
	self.bodyVelocity.Parent = humanoidRootPart
	
	-- Disable default physics
	humanoid.PlatformStand = true
	
	-- Update loop
	self.connection = RunService.RenderStepped:Connect(function()
		self:updateFly()
	end)
	
	Logger.debug("FlyController", "Flying enabled!")
end

function FlyController:stopFly()
	local character = LocalPlayer.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.PlatformStand = false
		end
	end
	
	if self.bodyGyro then
		self.bodyGyro:Destroy()
		self.bodyGyro = nil
	end
	
	if self.bodyVelocity then
		self.bodyVelocity:Destroy()
		self.bodyVelocity = nil
	end
	
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
	
	self.isFlying = false
	self.flyButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
	self.flyButton.BackgroundTransparency = 0.4
	self.flyButton.Text = "FLY"
	
	Logger.debug("FlyController", "Flying disabled!")
end

function FlyController:updateFly()
	local character = LocalPlayer.Character
	if not character then
		self:stopFly()
		return
	end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		self:stopFly()
		return
	end
	
	local camera = workspace.CurrentCamera
	
	-- Get input
	local moveDirection = Vector3.zero
	
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		moveDirection = moveDirection + camera.CFrame.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		moveDirection = moveDirection - camera.CFrame.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		moveDirection = moveDirection - camera.CFrame.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		moveDirection = moveDirection + camera.CFrame.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		moveDirection = moveDirection + Vector3.new(0, 1, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		moveDirection = moveDirection - Vector3.new(0, 1, 0)
	end
	
	-- Apply movement
	if moveDirection.Magnitude > 0 then
		moveDirection = moveDirection.Unit
	end
	
	if self.bodyVelocity then
		self.bodyVelocity.Velocity = moveDirection * self.flySpeed
	end
	
	-- Update rotation to face camera direction
	if self.bodyGyro then
		self.bodyGyro.CFrame = CFrame.new(humanoidRootPart.Position, humanoidRootPart.Position + camera.CFrame.LookVector * Vector3.new(1, 0, 1))
	end
end

-- Cleanup on character death/respawn
function FlyController:setupCharacterEvents()
	LocalPlayer.CharacterAdded:Connect(function()
		if self.isFlying then
			self:stopFly()
		end
	end)
end

return FlyController
