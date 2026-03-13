--!strict
-- Loading Screen (ReplicatedFirst)
-- Shows fullscreen loading with progress bar while preloading assets

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

-- Hardcoded colors (ReplicatedFirst can't require ThemeConfig)
local COLORS = {
	BG_TOP = Color3.fromRGB(195, 225, 245),
	BG_BTM = Color3.fromRGB(175, 235, 195),
	PRIMARY = Color3.fromRGB(255, 220, 0),
	TEXT = Color3.fromRGB(55, 60, 72),
	TEXT_MUTED = Color3.fromRGB(70, 78, 95),
	WHITE = Color3.fromRGB(255, 255, 255),
	BAR_BG = Color3.fromRGB(220, 225, 235),
}

local TIPS = {
	"\u{1F3AF} Use items to boost or sabotage other players!",
	"\u{1F3AD} 8 unique classes \u{2014} each with special abilities!",
	"\u{26A1} Ultimate skills: Sprint, Double Jump, Iron Will!",
	"\u{1F48E} Earn gems by finishing races!",
	"\u{1F3C6} Win 1st place to climb the leaderboard!",
	"\u{1F381} Log in daily for bonus rewards!",
	"\u{1F6D2} Visit the Shop to unlock new classes!",
	"\u{1F441}\u{FE0F} Spectate other players after you finish!",
}

local player = Players.LocalPlayer

-- Hide default loading screen
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoadingScreen"
screenGui.DisplayOrder = 999
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Background frame
local bg = Instance.new("Frame")
bg.Name = "Background"
bg.Size = UDim2.fromScale(1, 1)
bg.BorderSizePixel = 0
bg.BackgroundColor3 = COLORS.WHITE
bg.Parent = screenGui

local bgGradient = Instance.new("UIGradient")
bgGradient.Color = ColorSequence.new(COLORS.BG_TOP, COLORS.BG_BTM)
bgGradient.Rotation = 180
bgGradient.Parent = bg

-- Title
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(0.8, 0, 0, 60)
title.Position = UDim2.new(0.5, 0, 0.3, 0)
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.BackgroundTransparency = 1
title.Text = "\u{1F3C3} OBBY CHALLENGE \u{1F3C3}"
title.TextColor3 = COLORS.TEXT
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.Parent = bg

-- Progress bar container
local barContainer = Instance.new("Frame")
barContainer.Name = "BarContainer"
barContainer.Size = UDim2.new(0.5, 0, 0, 24)
barContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
barContainer.AnchorPoint = Vector2.new(0.5, 0.5)
barContainer.BackgroundColor3 = COLORS.BAR_BG
barContainer.BorderSizePixel = 0
barContainer.Parent = bg

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 12)
barCorner.Parent = barContainer

local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(180, 185, 200)
barStroke.Thickness = 1.5
barStroke.Parent = barContainer

-- Progress bar fill
local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = COLORS.PRIMARY
barFill.BorderSizePixel = 0
barFill.Parent = barContainer

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 12)
fillCorner.Parent = barFill

-- Progress text
local progressText = Instance.new("TextLabel")
progressText.Name = "ProgressText"
progressText.Size = UDim2.new(0.5, 0, 0, 24)
progressText.Position = UDim2.new(0.5, 0, 0.5, 22)
progressText.AnchorPoint = Vector2.new(0.5, 0)
progressText.BackgroundTransparency = 1
progressText.Text = "Loading... 0%"
progressText.TextColor3 = COLORS.TEXT_MUTED
progressText.Font = Enum.Font.GothamMedium
progressText.TextSize = 16
progressText.Parent = bg

-- Tips text
local tipsLabel = Instance.new("TextLabel")
tipsLabel.Name = "Tips"
tipsLabel.Size = UDim2.new(0.7, 0, 0, 30)
tipsLabel.Position = UDim2.new(0.5, 0, 0.65, 0)
tipsLabel.AnchorPoint = Vector2.new(0.5, 0.5)
tipsLabel.BackgroundTransparency = 1
tipsLabel.Text = TIPS[math.random(#TIPS)]
tipsLabel.TextColor3 = COLORS.TEXT_MUTED
tipsLabel.Font = Enum.Font.GothamMedium
tipsLabel.TextSize = 15
tipsLabel.TextWrapped = true
tipsLabel.Parent = bg

-- Tip rotation
local tipIndex = math.random(#TIPS)
local tipsRunning = true

task.spawn(function()
	while tipsRunning do
		task.wait(3)
		if not tipsRunning then break end
		tipIndex = tipIndex % #TIPS + 1
		-- Fade out
		local fadeOut = TweenService:Create(tipsLabel, TweenInfo.new(0.3), { TextTransparency = 1 })
		fadeOut:Play()
		fadeOut.Completed:Wait()
		if not tipsRunning then break end
		tipsLabel.Text = TIPS[tipIndex]
		-- Fade in
		local fadeIn = TweenService:Create(tipsLabel, TweenInfo.new(0.3), { TextTransparency = 0 })
		fadeIn:Play()
		fadeIn.Completed:Wait()
	end
end)

-- Animated dots on status text
local dotsRunning = true
task.spawn(function()
	local dots = { ".", "..", "..." }
	local i = 0
	while dotsRunning do
		i = i % 3 + 1
		local current = progressText.Text
		-- Strip existing dots
		local base = current:gsub("%.+$", "")
		progressText.Text = base .. dots[i]
		task.wait(0.4)
	end
end)

-- Preload assets
local totalAssets = 0
local loadedAssets = 0

local preloadTargets = {}

-- Safely add preload targets
if game:FindService("ReplicatedStorage") then
	table.insert(preloadTargets, game.ReplicatedStorage)
end
if game:FindService("Lighting") then
	table.insert(preloadTargets, game.Lighting)
end

-- Count total descendants for progress estimation
for _, target in preloadTargets do
	totalAssets += #target:GetDescendants()
end

if totalAssets == 0 then
	totalAssets = 1 -- avoid division by zero
end

local function updateProgress(pct: number)
	local clamped = math.clamp(pct, 0, 1)
	barFill.Size = UDim2.new(clamped, 0, 1, 0)
	local percent = math.floor(clamped * 100)
	progressText.Text = `Loading {percent}%`
end

-- PreloadAsync with progress callback
ContentProvider:PreloadAsync(preloadTargets, function(_contentId, _status)
	loadedAssets += 1
	updateProgress(loadedAssets / totalAssets)
end)

updateProgress(1)
progressText.Text = "Loading complete!"
dotsRunning = false

-- Wait for character (with timeout)
local character = player.Character or player.CharacterAdded:Wait()
if not character then
	-- Timeout fallback: wait max 10s for character
	local elapsed = 0
	while not player.Character and elapsed < 10 do
		task.wait(0.25)
		elapsed += 0.25
	end
end

-- Small delay so player sees 100%
task.wait(0.5)

-- Fade out
tipsRunning = false
local fadeOut = TweenService:Create(bg, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
	BackgroundTransparency = 1,
})
fadeOut:Play()

-- Fade all children too
for _, child in bg:GetDescendants() do
	if child:IsA("TextLabel") then
		TweenService:Create(child, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	elseif child:IsA("Frame") then
		TweenService:Create(child, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	elseif child:IsA("UIStroke") then
		TweenService:Create(child, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	elseif child:IsA("UIGradient") then
		-- Can't tween gradient transparency directly, handled by parent frame
	end
end

fadeOut.Completed:Wait()

-- Restore CoreGui and destroy
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
screenGui:Destroy()
