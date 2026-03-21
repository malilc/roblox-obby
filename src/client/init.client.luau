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


-- Initialize Moving Platform Carrier (smooth client-side platform riding)
local MovingPlatformCarrier = require(script.MovingPlatformCarrier)
local movingPlatformCarrier = MovingPlatformCarrier.new()

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

-- Update Log state
local updateLogOpen = false
local showOnceToggle = true -- ON = show every session, synced from DataStore

-- Show Update Log panel
local function showUpdateLog()
	if updateLogOpen then return end
	updateLogOpen = true

	local TweenService = game:GetService("TweenService")
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")

	local updateGui = Instance.new("ScreenGui")
	updateGui.Name = "UpdateLogGui"
	updateGui.IgnoreGuiInset = true
	updateGui.Parent = playerGui

	-- Dim overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.4
	overlay.BorderSizePixel = 0
	overlay.Parent = updateGui

	-- Main panel (inset 8px from edges to avoid stroke overlap)
	local panelW, panelH = 460, 480
	local inset = 8
	local panel = Instance.new("Frame")
	panel.Name = "UpdateLogPanel"
	panel.Size = UDim2.new(0, panelW, 0, panelH)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.45, 0)
	panel.BackgroundColor3 = Theme.BG_SURFACE
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Parent = updateGui

	local bgGradient = Instance.new("UIGradient")
	bgGradient.Color = ColorSequence.new(Theme.PANEL_GRAD_TOP, Theme.PANEL_GRAD_BTM)
	bgGradient.Rotation = 180
	bgGradient.Parent = panel

	Theme.applyCorner(panel, "lg")
	Theme.applyStroke(panel, Theme.PRIMARY, "bold", 0.1)

	-- ============ Title row (no background frame — placed directly on panel) ============
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(0, 180, 0, 36)
	titleLabel.Position = UDim2.new(0, inset + 10, 0, inset + 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "UPDATE LOG"
	titleLabel.TextColor3 = Theme.TEXT_PRIMARY
	titleLabel.TextSize = 22
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = panel

	-- Version badge
	local latestVer = Config.UpdateLog[1] and Config.UpdateLog[1].version or Config.PromoVersion
	local vBadge = Instance.new("Frame")
	vBadge.Name = "VersionBadge"
	vBadge.Size = UDim2.new(0, 52, 0, 22)
	vBadge.Position = UDim2.new(0, inset + 180, 0, inset + 11)
	vBadge.BackgroundColor3 = Theme.ACCENT_CYAN
	vBadge.BorderSizePixel = 0
	vBadge.Parent = panel
	Theme.applyCorner(vBadge, "sm")

	local vText = Instance.new("TextLabel")
	vText.Size = UDim2.new(1, 0, 1, 0)
	vText.BackgroundTransparency = 1
	vText.Text = "v" .. latestVer
	vText.TextColor3 = Theme.TEXT_ON_ACCENT
	vText.TextSize = 12
	vText.Font = Enum.Font.GothamBold
	vText.Parent = vBadge

	-- X close button (circular)
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -inset - 34, 0, inset + 7)
	closeBtn.BackgroundColor3 = Theme.DANGER
	closeBtn.BackgroundTransparency = 0.15
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.TextSize = 16
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = panel
	Theme.applyCorner(closeBtn, "full")

	-- Header separator
	local headerSepY = inset + 44
	local headerSep = Instance.new("Frame")
	headerSep.Size = UDim2.new(1, -(inset * 2 + 8), 0, 1)
	headerSep.Position = UDim2.new(0, inset + 4, 0, headerSepY)
	headerSep.BackgroundColor3 = Theme.CARD_SHADOW
	headerSep.BackgroundTransparency = 0.3
	headerSep.BorderSizePixel = 0
	headerSep.Parent = panel

	-- ============ Version tabs ============
	local tabBarHeight = 30
	local tabBarY = headerSepY + 4

	local tabBar = Instance.new("ScrollingFrame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, -(inset * 2 + 8), 0, tabBarHeight)
	tabBar.Position = UDim2.new(0, inset + 4, 0, tabBarY)
	tabBar.BackgroundTransparency = 1
	tabBar.BorderSizePixel = 0
	tabBar.ScrollBarThickness = 0
	tabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabBar.ScrollingDirection = Enum.ScrollingDirection.X
	tabBar.Parent = panel

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.Parent = tabBar

	local tabButtons = {}
	local selectedTab = 1

	for i, entry in ipairs(Config.UpdateLog) do
		local tab = Instance.new("TextButton")
		tab.Name = "Tab_v" .. entry.version
		tab.Size = UDim2.new(0, 70, 0, 26)
		tab.BackgroundColor3 = if i == 1 then Theme.ACCENT_CYAN else Theme.BG_ELEVATED
		tab.BorderSizePixel = 0
		tab.Text = "v" .. entry.version
		tab.TextColor3 = if i == 1 then Theme.TEXT_ON_ACCENT else Theme.TEXT_MUTED
		tab.TextSize = 12
		tab.Font = Enum.Font.GothamBold
		tab.LayoutOrder = i
		tab.Parent = tabBar
		Theme.applyCorner(tab, "sm")

		tabButtons[i] = tab
	end

	-- ============ Scrollable content ============
	local contentTop = tabBarY + tabBarHeight + 4
	local footerZone = 40
	local footerSepY = panelH - inset - footerZone - 4
	local contentH = footerSepY - 4 - contentTop

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Content"
	scroll.Size = UDim2.new(1, -(inset * 2 + 4), 0, contentH)
	scroll.Position = UDim2.new(0, inset + 2, 0, contentTop)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.TEXT_MUTED
	scroll.ScrollBarImageTransparency = 0.4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = panel

	-- Populate scroll with a specific version's notes
	local function showVersion(index: number)
		selectedTab = index
		-- Clear existing content
		for _, child in ipairs(scroll:GetChildren()) do
			if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
				child:Destroy()
			end
		end

		-- Update tab styles
		for i, tab in ipairs(tabButtons) do
			if i == index then
				tab.BackgroundColor3 = Theme.ACCENT_CYAN
				tab.TextColor3 = Theme.TEXT_ON_ACCENT
			else
				tab.BackgroundColor3 = Theme.BG_ELEVATED
				tab.TextColor3 = Theme.TEXT_MUTED
			end
		end

		local entry = Config.UpdateLog[index]
		if not entry then return end

		local order = 0

		-- Entry title
		local eTitle = Instance.new("TextLabel")
		eTitle.Name = "UpdateTitle"
		eTitle.Size = UDim2.new(1, 0, 0, 24)
		eTitle.BackgroundTransparency = 1
		eTitle.RichText = true
		eTitle.Text = '<font color="#1A6B8A"><b>' .. entry.title .. '</b></font>'
			.. '  <font color="#806000">v' .. entry.version .. '</font>'
		eTitle.TextSize = 15
		eTitle.Font = Enum.Font.GothamBold
		eTitle.TextXAlignment = Enum.TextXAlignment.Left
		eTitle.TextWrapped = true
		eTitle.LayoutOrder = order
		eTitle.Parent = scroll
		order += 1

		-- Thin separator
		local sep = Instance.new("Frame")
		sep.Size = UDim2.new(1, 0, 0, 1)
		sep.BackgroundColor3 = Theme.CARD_SHADOW
		sep.BackgroundTransparency = 0.4
		sep.BorderSizePixel = 0
		sep.LayoutOrder = order
		sep.Parent = scroll
		order += 1

		for _, section in ipairs(entry.notes) do
			-- Section heading
			local heading = Instance.new("TextLabel")
			heading.Name = "Heading_" .. section.heading
			heading.Size = UDim2.new(1, 0, 0, 20)
			heading.BackgroundTransparency = 1
			heading.RichText = true
			heading.Text = '<font color="#1A7A3A"><b>' .. section.heading .. '</b></font>'
			heading.TextSize = 13
			heading.Font = Enum.Font.GothamBold
			heading.TextXAlignment = Enum.TextXAlignment.Left
			heading.LayoutOrder = order
			heading.Parent = scroll
			order += 1

			-- Bullet items
			for _, item in ipairs(section.items) do
				local bullet = Instance.new("TextLabel")
				bullet.Name = "Bullet"
				bullet.Size = UDim2.new(1, -8, 0, 0)
				bullet.AutomaticSize = Enum.AutomaticSize.Y
				bullet.BackgroundTransparency = 1
				bullet.RichText = true
				bullet.Text = '<font color="#464E5F">  \xE2\x80\xA2  ' .. item .. '</font>'
				bullet.TextColor3 = Theme.TEXT_MUTED
				bullet.TextSize = 12
				bullet.Font = Enum.Font.GothamMedium
				bullet.TextXAlignment = Enum.TextXAlignment.Left
				bullet.TextWrapped = true
				bullet.LayoutOrder = order
				bullet.Parent = scroll
				order += 1
			end
		end

		scroll.CanvasPosition = Vector2.new(0, 0) -- scroll to top
	end

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = scroll

	local scrollPad = Instance.new("UIPadding")
	scrollPad.PaddingTop = UDim.new(0, 4)
	scrollPad.PaddingBottom = UDim.new(0, 6)
	scrollPad.PaddingLeft = UDim.new(0, 4)
	scrollPad.PaddingRight = UDim.new(0, 10)
	scrollPad.Parent = scroll

	-- Connect tab clicks
	for i, tab in ipairs(tabButtons) do
		tab.MouseButton1Click:Connect(function()
			if selectedTab ~= i then
				showVersion(i)
			end
		end)
	end

	-- Show latest version by default
	showVersion(1)

	-- ============ Footer separator + toggle ============
	local footerSep = Instance.new("Frame")
	footerSep.Size = UDim2.new(1, -(inset * 2 + 8), 0, 1)
	footerSep.Position = UDim2.new(0, inset + 4, 0, footerSepY)
	footerSep.BackgroundColor3 = Theme.CARD_SHADOW
	footerSep.BackgroundTransparency = 0.3
	footerSep.BorderSizePixel = 0
	footerSep.Parent = panel

	local toggleLabel = Instance.new("TextLabel")
	toggleLabel.Size = UDim2.new(0, 200, 0, footerZone)
	toggleLabel.Position = UDim2.new(1, -inset - 260, 0, footerSepY + 2)
	toggleLabel.BackgroundTransparency = 1
	toggleLabel.Text = "Show every session"
	toggleLabel.TextColor3 = Theme.TEXT_MUTED
	toggleLabel.TextSize = 12
	toggleLabel.Font = Enum.Font.GothamMedium
	toggleLabel.TextXAlignment = Enum.TextXAlignment.Right
	toggleLabel.Parent = panel

	local track = Instance.new("TextButton")
	track.Name = "ToggleTrack"
	track.Size = UDim2.new(0, 42, 0, 22)
	track.Position = UDim2.new(1, -inset - 50, 0, footerSepY + 2 + (footerZone - 22) / 2)
	track.BackgroundColor3 = if showOnceToggle then Theme.darkenForText(Theme.SUCCESS, 0.55) else Theme.CARD_SHADOW
	track.BorderSizePixel = 0
	track.Text = ""
	track.Parent = panel

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 11)
	trackCorner.Parent = track

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 18, 0, 18)
	knob.Position = if showOnceToggle then UDim2.new(0, 22, 0.5, -9) else UDim2.new(0, 2, 0.5, -9)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.Parent = track

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(0, 9)
	knobCorner.Parent = knob

	track.MouseButton1Click:Connect(function()
		showOnceToggle = not showOnceToggle
		if showOnceToggle then
			TweenService:Create(knob, TweenInfo.new(0.2), { Position = UDim2.new(0, 22, 0.5, -9) }):Play()
			TweenService:Create(track, TweenInfo.new(0.2), { BackgroundColor3 = Theme.darkenForText(Theme.SUCCESS, 0.55) }):Play()
		else
			TweenService:Create(knob, TweenInfo.new(0.2), { Position = UDim2.new(0, 2, 0.5, -9) }):Play()
			TweenService:Create(track, TweenInfo.new(0.2), { BackgroundColor3 = Theme.CARD_SHADOW }):Play()
		end
	end)

	-- ============ Animate in ============
	panel.Position = UDim2.new(0.5, 0, 0.45, 40)
	panel.BackgroundTransparency = 1
	overlay.BackgroundTransparency = 1

	TweenService:Create(overlay, TweenInfo.new(0.3), { BackgroundTransparency = 0.4 }):Play()
	TweenService:Create(panel, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, 0, 0.45, 0),
		BackgroundTransparency = 0,
	}):Play()

	-- Close handler
	local function closeLog()
		TweenService:Create(overlay, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		local fade = TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0.45, 30),
			BackgroundTransparency = 1,
		})
		fade:Play()
		fade.Completed:Connect(function()
			updateGui:Destroy()
			updateLogOpen = false
		end)
	end

	local function onClose()
		-- Toggle ON → save "" (show again next session)
		-- Toggle OFF → save PromoVersion (don't show until new version)
		local remote = ReplicatedStorage.Remotes:FindFirstChild("DismissPromo")
		if remote then remote:FireServer(showOnceToggle) end
		closeLog()
	end

	closeBtn.MouseButton1Click:Connect(onClose)
	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			onClose()
		end
	end)
end

-- Persistent Update Log button (top-right, left of Testing Menu)
do
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local btnGui = Instance.new("ScreenGui")
	btnGui.Name = "UpdateLogBtnGui"
	btnGui.ResetOnSpawn = false
	btnGui.Parent = playerGui

	local btn = Instance.new("TextButton")
	btn.Name = "UpdateLogBtn"
	btn.Size = UDim2.new(0, 40, 0, 35)
	btn.Position = UDim2.new(1, -180, 0, 10)
	btn.BackgroundColor3 = Theme.BG_SURFACE
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.Parent = btnGui
	Theme.applyCorner(btn, "sm")
	Theme.applyStroke(btn, Theme.PRIMARY, "thin", 0.3)

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Text = "\xF0\x9F\x93\x8B"
	icon.TextSize = 20
	icon.Parent = btn

	btn.MouseButton1Click:Connect(function()
		showUpdateLog()
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

-- Connect UpdateCurrency handler EARLY (before CharacterAdded wait)
-- so we catch the initial event that server fires at PlayerAdded time
local receivedDismissVersion = nil -- stores first received value

Logger.info("Client", "[UpdateLog] Connecting UpdateCurrency handler...")

Remotes:WaitForChild("UpdateCurrency").OnClientEvent:Connect(function(data)
	Logger.info("Client", "[UpdateLog] UpdateCurrency received! dismissedPromoVersion=" .. tostring(data.dismissedPromoVersion))
	-- Store first received value for popup check
	if receivedDismissVersion == nil then
		receivedDismissVersion = data.dismissedPromoVersion or ""
		-- Sync toggle: if saved == current version → user turned OFF before → toggle OFF
		-- Otherwise (new version or "") → toggle ON
		showOnceToggle = (receivedDismissVersion ~= Config.PromoVersion)
	end
end)

-- Wait for character to be ready before showing popup
Logger.info("Client", "[UpdateLog] Character exists: " .. tostring(LocalPlayer.Character ~= nil))
if not LocalPlayer.Character then
	Logger.info("Client", "[UpdateLog] Waiting for CharacterAdded...")
	LocalPlayer.CharacterAdded:Wait()
end
Logger.info("Client", "[UpdateLog] Character ready, waiting 1s...")
task.wait(1)

-- Check if data already arrived (most likely — server sends at PlayerAdded)
Logger.info("Client", "[UpdateLog] receivedDismissVersion=" .. tostring(receivedDismissVersion) .. " PromoVersion=" .. Config.PromoVersion)
local promoShown = false
if receivedDismissVersion ~= nil then
	promoShown = true
	-- Auto-show if version is different (new update available)
	if receivedDismissVersion ~= Config.PromoVersion then
		Logger.info("Client", "[UpdateLog] AUTO-SHOWING popup! (dismissed=" .. receivedDismissVersion .. " current=" .. Config.PromoVersion .. ")")
		showUpdateLog()
	else
		Logger.info("Client", "[UpdateLog] Skipping auto-show (same version)")
	end
end

-- Fallback: if data hasn't arrived yet, wait for it or timeout
if not promoShown then
	Logger.info("Client", "[UpdateLog] Data not arrived yet, setting up fallback...")
	local lateConn
	lateConn = Remotes:WaitForChild("UpdateCurrency").OnClientEvent:Connect(function(data)
		if promoShown then return end
		promoShown = true
		local dismissed = data.dismissedPromoVersion or ""
		Logger.info("Client", "[UpdateLog] Late data: dismissed=" .. dismissed)
		if dismissed ~= Config.PromoVersion then
			Logger.info("Client", "[UpdateLog] LATE AUTO-SHOWING popup!")
			showUpdateLog()
		end
		if lateConn then lateConn:Disconnect() end
	end)

	task.delay(5, function()
		if not promoShown then
			promoShown = true
			Logger.info("Client", "[UpdateLog] TIMEOUT — showing popup as fallback")
			showUpdateLog()
		end
		if lateConn then lateConn:Disconnect() end
	end)
end

-- VIP Chat Tag: prepend [VIP] to chat messages from VIP players
local TextChatService = game:GetService("TextChatService")
TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local props = Instance.new("TextChatMessageProperties")
	local sender = message.TextSource
	if sender then
		local senderPlayer = Players:GetPlayerByUserId(sender.UserId)
		if senderPlayer and senderPlayer:GetAttribute("IsVIP") == true then
			props.PrefixText = '<font color="#FFD232">[VIP]</font> ' .. message.PrefixText
		end
	end
	return props
end

Logger.info("Client", "Ready to play!")
