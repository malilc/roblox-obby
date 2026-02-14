-- Roblox Obby Game - Client Entry Point
print("[Client] Starting Obby Game Client...")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Local player reference (define early for use in debug tools)
local LocalPlayer = Players.LocalPlayer

-- Initialize UI
local MainUI = require(script.UI.MainUI)
local mainUI = MainUI.new()

-- Initialize Item Effects (screen shake, flash, etc.)
local ItemEffects = require(script.ItemEffects)
local itemEffects = ItemEffects.new()

-- Debug/Testing tools (behind Config.Debug flags)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

if Config.Debug and Config.Debug.FlyMode then
	local FlyController = require(script.FlyController)
	local flyController = FlyController.new()
	flyController:setupCharacterEvents()
end

if Config.Debug and Config.Debug.ItemTesting then
	local ItemTestingUI = require(script.UI.ItemTestingUI)
	local itemTestingUI = ItemTestingUI.new()
end

-- Mastery Testing UI (Press M to toggle)
if Config.Debug and Config.Debug.MasteryTesting then
	local UserInputService = game:GetService("UserInputService")
	local MasteryTestingUI = require(script.UI.MasteryTestingUI)
	
	-- Get PlayerGui
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local gameUI = playerGui:FindFirstChild("GameUI")
	if not gameUI then
		gameUI = Instance.new("ScreenGui")
		gameUI.Name = "GameUI"
		gameUI.ResetOnSpawn = false
		gameUI.Parent = playerGui
	end
	
	local masteryTestingUI = MasteryTestingUI.new(gameUI)
	
	-- Keybind M to toggle
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.M then
			masteryTestingUI:toggle()
		end
	end)
	
	print("[Client] Mastery Testing UI enabled - Press M to toggle")
end

-- Initialize Ultimate Skill Controller (handles Sprint, Double Jump, Iron Will)
local UltimateSkillController = require(script.UltimateSkillController)
local ultimateSkillController = UltimateSkillController.new()
print("[Client] Ultimate Skill Controller initialized")

-- Initialize Mobile Touch Buttons (only shows on touch devices)
local MobileInputUI = require(script.UI.MobileInputUI)
local mobileInputUI = MobileInputUI.new(mainUI.screenGui, {
	itemUI = mainUI.itemUI,
	ultimateSkillController = ultimateSkillController,
})

print("[Client] UI and Effects initialized!")

-- Show welcome message
local function showWelcomeMessage()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	
	local welcomeGui = Instance.new("ScreenGui")
	welcomeGui.Name = "WelcomeGui"
	welcomeGui.Parent = playerGui
	
	local welcomeFrame = Instance.new("Frame")
	welcomeFrame.Size = UDim2.new(0, 500, 0, 200)
	welcomeFrame.Position = UDim2.new(0.5, -250, 0.3, 0)
	welcomeFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	welcomeFrame.BackgroundTransparency = 0.2
	welcomeFrame.BorderSizePixel = 0
	welcomeFrame.Parent = welcomeGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
	corner.Parent = welcomeFrame
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 255, 150)
	stroke.Thickness = 2
	stroke.Parent = welcomeFrame
	
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 50)
	titleLabel.Position = UDim2.new(0, 0, 0, 20)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🏃 OBBY CHALLENGE 🏃"
	titleLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
	titleLabel.TextSize = 32
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = welcomeFrame
	
	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, -40, 0, 60)
	infoLabel.Position = UDim2.new(0, 20, 0, 70)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = "Step on the BLUE ZONE to select stages!\nUse [E] to PUSH other players!\nComplete all stages to win!"
	infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	infoLabel.TextSize = 16
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextWrapped = true
	infoLabel.Parent = welcomeFrame
	
	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 100, 0, 35)
	closeButton.Position = UDim2.new(0.5, -50, 1, -50)
	closeButton.BackgroundColor3 = Color3.fromRGB(100, 255, 150)
	closeButton.Text = "GOT IT!"
	closeButton.TextColor3 = Color3.fromRGB(30, 30, 40)
	closeButton.TextSize = 16
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = welcomeFrame
	
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 8)
	buttonCorner.Parent = closeButton
	
	closeButton.MouseButton1Click:Connect(function()
		welcomeGui:Destroy()
	end)
	
	-- Auto close after 10 seconds
	task.delay(10, function()
		if welcomeGui.Parent then
			welcomeGui:Destroy()
		end
	end)
end

-- Show welcome on first spawn
LocalPlayer.CharacterAdded:Wait()
task.wait(1)
showWelcomeMessage()

print("[Client] Ready to play!")
