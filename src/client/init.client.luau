-- Roblox Obby Game - Client Entry Point
print("[Client] Starting Obby Game Client...")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

-- Initialize UI
local MainUI = require(script.UI.MainUI)
local mainUI = MainUI.new()

-- Initialize Fly Controller (for testing)
local FlyController = require(script.FlyController)
local flyController = FlyController.new()
flyController:setupCharacterEvents()

-- Initialize Item Effects (screen shake, flash, etc.)
local ItemEffects = require(script.ItemEffects)
local itemEffects = ItemEffects.new()

-- Initialize Item Testing UI (for development)
local ItemTestingUI = require(script.UI.ItemTestingUI)
local itemTestingUI = ItemTestingUI.new()

print("[Client] UI, Effects, and Testing Menu initialized!")

-- Local player reference
local LocalPlayer = Players.LocalPlayer

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
