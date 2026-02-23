-- Roblox Obby Game - Client Entry Point
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(ReplicatedStorage.Shared.Logger)
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)

Logger.info("Client", "Starting Obby Game Client...")

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

-- Initialize Sound Manager (BGM + SFX)
local SoundManager = require(script.SoundManager)
local soundManager = SoundManager.new()

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


-- Initialize Ultimate Skill Controller (handles Sprint, Double Jump, Iron Will)
local UltimateSkillController = require(script.UltimateSkillController)
local ultimateSkillController = UltimateSkillController.new()
Logger.info("Client", "Ultimate Skill Controller initialized")

-- Initialize Mobile Touch Buttons (only shows on touch devices)
local MobileInputUI = require(script.UI.MobileInputUI)
local mobileInputUI = MobileInputUI.new(mainUI.screenGui, {
	itemUI = mainUI.itemUI,
	ultimateSkillController = ultimateSkillController,
})

Logger.info("Client", "UI and Effects initialized!")

-- Show welcome message
local function showWelcomeMessage()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	local welcomeGui = Instance.new("ScreenGui")
	welcomeGui.Name = "WelcomeGui"
	welcomeGui.Parent = playerGui

	-- B5: Panel 480×240, centered with AnchorPoint
	local welcomeFrame = Instance.new("Frame")
	welcomeFrame.Size = UDim2.new(0, 480, 0, 240)
	welcomeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	welcomeFrame.Position = UDim2.new(0.5, 0, 0.4, 0)
	welcomeFrame.BackgroundColor3 = Theme.BG_SURFACE
	welcomeFrame.BackgroundTransparency = 0
	welcomeFrame.BorderSizePixel = 0
	welcomeFrame.Parent = welcomeGui

	-- B1: Gradient overlay BG_SURFACE → BG_BASE
	local bgGradient = Instance.new("UIGradient")
	bgGradient.Color = ColorSequence.new(Theme.BG_SURFACE, Theme.BG_BASE)
	bgGradient.Rotation = 135
	bgGradient.Parent = welcomeFrame

	-- B1: Corner + glow stroke
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CORNER_LG
	corner.Parent = welcomeFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.ACCENT_CYAN
	stroke.Thickness = Theme.STROKE_MED
	stroke.Transparency = 0.2
	stroke.Parent = welcomeFrame

	-- B3: Title — GothamBlack 36px with UIStroke
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 55)
	titleLabel.Position = UDim2.new(0, 0, 0, 18)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🏃 OBBY CHALLENGE 🏃"
	titleLabel.TextColor3 = Theme.ACCENT_CYAN
	titleLabel.TextSize = 36
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Parent = welcomeFrame

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Theme.HUD_SCORE_END
	titleStroke.Thickness = 1.5
	titleStroke.Transparency = 0.4
	titleStroke.Parent = titleLabel

	-- B2: RichText info with colored keywords
	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, -40, 0, 70)
	infoLabel.Position = UDim2.new(0, 20, 0, 78)
	infoLabel.BackgroundTransparency = 1
	infoLabel.RichText = true
	infoLabel.Text = 'Step on the <font color="#50DCFF"><b>BLUE ZONE</b></font> to select stages!\n'
		.. 'Use <font color="#FFC800"><b>[1]</b></font> <font color="#FFC800"><b>[2]</b></font> to use Items!\n'
		.. 'Complete all stages to <font color="#50E678"><b>win!</b></font>'
	infoLabel.TextColor3 = Theme.TEXT_MUTED
	infoLabel.TextSize = 16
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextWrapped = true
	infoLabel.Parent = welcomeFrame

	-- B4: GOT IT! button — 3-layer gradient pattern (TextButton + Frame + TextLabel)
	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.new(0, 300, 0, 45)
	closeButton.AnchorPoint = Vector2.new(0.5, 0)
	closeButton.Position = UDim2.new(0.5, 0, 1, -58)
	closeButton.BackgroundTransparency = 1
	closeButton.Text = ""
	closeButton.Parent = welcomeFrame

	local buttonBg = Instance.new("Frame")
	buttonBg.Size = UDim2.new(1, 0, 1, 0)
	buttonBg.BackgroundColor3 = Color3.new(1, 1, 1)
	buttonBg.BorderSizePixel = 0
	buttonBg.Parent = closeButton

	local buttonGradient = Instance.new("UIGradient")
	buttonGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 200, 100)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 170, 70)),
	})
	buttonGradient.Parent = buttonBg

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = Theme.CORNER_MD
	buttonCorner.Parent = buttonBg

	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Color = Theme.SUCCESS
	buttonStroke.Thickness = Theme.STROKE_THIN
	buttonStroke.Transparency = 0.3
	buttonStroke.Parent = buttonBg

	local buttonText = Instance.new("TextLabel")
	buttonText.Size = UDim2.new(1, 0, 1, 0)
	buttonText.BackgroundTransparency = 1
	buttonText.Text = "GOT IT!"
	buttonText.TextColor3 = Theme.TEXT_PRIMARY
	buttonText.TextSize = 18
	buttonText.Font = Enum.Font.GothamBold
	buttonText.ZIndex = buttonBg.ZIndex + 1
	buttonText.Parent = closeButton

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

-- Helper: snap camera to a position/orientation then return control to Custom
local function snapCamera(cframe: CFrame)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = cframe
	task.wait()
	camera.CameraType = Enum.CameraType.Custom
end

-- Reset camera to face stage direction (+X) when countdown ends (GO!)
local countdownRemote = Remotes:WaitForChild("CountdownUpdate")
countdownRemote.OnClientEvent:Connect(function(data)
	if data.number == 1 then
		task.delay(1.1, function()
			local character = LocalPlayer.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				local humanoidRootPart = character.HumanoidRootPart
				snapCamera(CFrame.lookAt(
					humanoidRootPart.Position + Vector3.new(-10, 5, 0),
					humanoidRootPart.Position
				))
			end
		end)
	end
end)

-- Reset camera to face SelectionZone (+Z) when returning to lobby
local returnToLobbyRemote = Remotes:WaitForChild("ReturnToLobby")
returnToLobbyRemote.OnClientEvent:Connect(function()
	task.wait(0.1)
	local character = LocalPlayer.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		local humanoidRootPart = character.HumanoidRootPart
		snapCamera(CFrame.lookAt(
			humanoidRootPart.Position + Vector3.new(0, 5, -12),
			humanoidRootPart.Position + Vector3.new(0, 0, 5)
		))
	end
end)

-- Snap camera on every spawn (handles initial Studio Test and respawn)
local function onCharacterSpawned()
	task.wait(0.5) -- รอให้ character โหลดเสร็จ
	local character = LocalPlayer.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		local humanoidRootPart = character.HumanoidRootPart
		-- หันตัวละครไปทาง +Z (SelectionZone)
		local pos = humanoidRootPart.Position
		humanoidRootPart.CFrame = CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1))
		-- snap กล้องตาม
		snapCamera(CFrame.lookAt(
			pos + Vector3.new(0, 5, -12),
			pos + Vector3.new(0, 0, 5)
		))
	end
end

LocalPlayer.CharacterAdded:Connect(onCharacterSpawned)

-- Show welcome on first spawn
LocalPlayer.CharacterAdded:Wait()
task.wait(1)
showWelcomeMessage()

Logger.info("Client", "Ready to play!")
