-- TutorialUI: ปุ่ม "?" เปิดคู่มือเกมแบบ tab ใน lobby

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)

local TutorialUI = {}
TutorialUI.__index = TutorialUI

function TutorialUI.new(parent: ScreenGui, callbacks: {onShow: (() -> ())?}?)
	local self = setmetatable({}, TutorialUI)

	self.parent = parent
	self.callbacks = callbacks or {}
	self.isVisible = false
	self.hasSeenTutorial = false
	self.activeTab = 1
	self.tabButtons = {}

	self:createUI()
	self:setupRemotes()

	return self
end

function TutorialUI:createUI()
	local sections = Config.Tutorial and Config.Tutorial.Sections or {}

	-- === ปุ่ม "?" (ใต้ Class Indicator HUD เพื่อไม่ทับ) ===
	local helpButton = Instance.new("TextButton")
	helpButton.Name = "HelpButton"
	helpButton.Size = UDim2.new(0, 40, 0, 40)
	helpButton.Position = UDim2.new(0, 10, 0, 240)
	helpButton.BackgroundColor3 = Theme.BG_BASE
	helpButton.BackgroundTransparency = 0.2
	helpButton.Text = "?"
	helpButton.TextColor3 = Theme.ACCENT_CYAN
	helpButton.TextSize = 22
	helpButton.Font = Enum.Font.GothamBold
	helpButton.AutoButtonColor = false
	helpButton.ZIndex = 5
	helpButton.Parent = self.parent
	self.helpButton = helpButton

	local helpCorner = Instance.new("UICorner")
	helpCorner.CornerRadius = Theme.CORNER_LG
	helpCorner.Parent = helpButton

	local helpStroke = Instance.new("UIStroke")
	helpStroke.Color = Theme.ACCENT_CYAN
	helpStroke.Thickness = Theme.STROKE_MED
	helpStroke.Transparency = 0.2
	helpStroke.Parent = helpButton

	-- Help button gradient
	local helpGradient = Instance.new("UIGradient")
	helpGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.BG_SURFACE),
		ColorSequenceKeypoint.new(1, Theme.BG_BASE)
	})
	helpGradient.Rotation = 135
	helpGradient.Parent = helpButton

	helpButton.MouseButton1Click:Connect(function()
		self:toggle()
	end)

	-- === Hint label (ผู้เล่นใหม่) ===
	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "TutorialHint"
	hintLabel.Size = UDim2.new(0, 130, 0, 28)
	hintLabel.Position = UDim2.new(0, 58, 0, 246)
	hintLabel.BackgroundColor3 = Theme.BG_BASE
	hintLabel.BackgroundTransparency = 0.2
	hintLabel.Text = "  Tap ? for help!"
	hintLabel.TextColor3 = Theme.ACCENT_CYAN
	hintLabel.TextSize = 13
	hintLabel.Font = Enum.Font.GothamBold
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.Visible = false
	hintLabel.ZIndex = 5
	hintLabel.Parent = self.parent
	self.hintLabel = hintLabel

	local hintCorner = Instance.new("UICorner")
	hintCorner.CornerRadius = Theme.CORNER_SM
	hintCorner.Parent = hintLabel

	-- === Main Panel (ซ่อนไว้) ===
	local overlay = Instance.new("TextButton")
	overlay.Name = "TutorialOverlay"
	overlay.Size = UDim2.new(2, 0, 2, 0)
	overlay.Position = UDim2.new(-0.5, 0, -0.5, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.3
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Visible = false
	overlay.ZIndex = 10
	overlay.Parent = self.parent
	self.overlay = overlay

	overlay.MouseButton1Click:Connect(function()
		self:hide()
	end)

	-- Panel ใหญ่ขึ้น (680x500)
	local panelWidth = 680
	local panelHeight = 500
	local panel = Instance.new("Frame")
	panel.Name = "TutorialPanel"
	panel.Size = UDim2.new(0, panelWidth, 0, panelHeight)
	panel.Position = UDim2.new(0.5, -panelWidth / 2, 0.5, -panelHeight / 2)
	panel.BackgroundColor3 = Theme.BG_BASE
	panel.BackgroundTransparency = 0
	panel.BorderSizePixel = 0
	panel.ZIndex = 11
	panel.Parent = overlay
	self.panel = panel

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = Theme.CORNER_LG
	panelCorner.Parent = panel

	-- Panel gradient
	local panelGradient = Instance.new("UIGradient")
	panelGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.BG_SURFACE),
		ColorSequenceKeypoint.new(1, Theme.BG_BASE)
	})
	panelGradient.Rotation = 135
	panelGradient.Parent = panel

	-- Panel glow stroke
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Theme.ACCENT_CYAN
	panelStroke.Thickness = Theme.STROKE_MED
	panelStroke.Transparency = 0.2
	panelStroke.Parent = panel

	-- Panel drop shadow
	local panelShadow = Instance.new("Frame")
	panelShadow.Name = "Shadow"
	panelShadow.Size = UDim2.new(1, 6, 1, 6)
	panelShadow.Position = UDim2.new(0, -3, 0, 4)
	panelShadow.BackgroundColor3 = Color3.new(0, 0, 0)
	panelShadow.BackgroundTransparency = 0.6
	panelShadow.BorderSizePixel = 0
	panelShadow.ZIndex = panel.ZIndex - 1
	panelShadow.Parent = panel
	Theme.applyCorner(panelShadow, "lg")

	-- Header
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, -60, 0, 44)
	header.Position = UDim2.new(0, 20, 0, 10)
	header.BackgroundTransparency = 1
	header.Text = "Game Guide"
	header.TextColor3 = Theme.TEXT_PRIMARY
	header.TextSize = 26
	header.Font = Enum.Font.GothamBold
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.ZIndex = 12
	header.Parent = panel

	local headerStroke = Instance.new("UIStroke")
	headerStroke.Color = Theme.HUD_SCORE_END
	headerStroke.Thickness = 1.5
	headerStroke.Transparency = 0.4
	headerStroke.Parent = header

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 36, 0, 36)
	closeButton.Position = UDim2.new(1, -48, 0, 14)
	closeButton.BackgroundColor3 = Theme.BG_SURFACE
	closeButton.Text = "X"
	closeButton.TextColor3 = Theme.DANGER
	closeButton.TextSize = 18
	closeButton.Font = Enum.Font.GothamBold
	closeButton.AutoButtonColor = false
	closeButton.ZIndex = 12
	closeButton.Parent = panel

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = Theme.CORNER_SM
	closeCorner.Parent = closeButton

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = Theme.DANGER
	closeStroke.Thickness = Theme.STROKE_THIN
	closeStroke.Transparency = 0.3
	closeStroke.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		self:hide()
	end)

	-- Tab bar
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, -30, 0, 42)
	tabBar.Position = UDim2.new(0, 15, 0, 58)
	tabBar.BackgroundTransparency = 1
	tabBar.ZIndex = 12
	tabBar.Parent = panel

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 5)
	tabLayout.Parent = tabBar

	-- Tab กว้างขึ้นเพื่อไม่ตัดข้อความ
	local tabWidth = math.floor((panelWidth - 30 - 5 * (#sections - 1)) / #sections)

	for i, section in ipairs(sections) do
		local tabButton = Instance.new("TextButton")
		tabButton.Name = "Tab_" .. section.id
		tabButton.Size = UDim2.new(0, tabWidth, 0, 38)
		tabButton.BackgroundColor3 = if i == 1 then Theme.BG_ELEVATED else Theme.BG_BASE
		tabButton.BackgroundTransparency = 0.1
		tabButton.Text = (section.icon or "") .. " " .. section.title
		tabButton.TextColor3 = if i == 1 then Theme.TEXT_PRIMARY else Theme.TEXT_MUTED
		tabButton.TextSize = 13
		tabButton.Font = Enum.Font.GothamBold
		tabButton.AutoButtonColor = false
		tabButton.LayoutOrder = i
		tabButton.ZIndex = 12
		tabButton.Parent = tabBar

		local tabCorner = Instance.new("UICorner")
		tabCorner.CornerRadius = Theme.CORNER_SM
		tabCorner.Parent = tabButton

		tabButton.MouseButton1Click:Connect(function()
			self:selectTab(i)
		end)

		self.tabButtons[i] = tabButton
	end

	-- Content area (ใหญ่ขึ้น + padding มากขึ้น)
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Size = UDim2.new(1, -30, 1, -120)
	contentFrame.Position = UDim2.new(0, 15, 0, 108)
	contentFrame.BackgroundColor3 = Theme.BG_OVERLAY
	contentFrame.BackgroundTransparency = 0.05
	contentFrame.BorderSizePixel = 0
	contentFrame.ZIndex = 12
	contentFrame.Parent = panel

	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = Theme.CORNER_SM
	contentCorner.Parent = contentFrame

	-- Content text (font ใหญ่ขึ้น + line height ดีขึ้น)
	local contentLabel = Instance.new("TextLabel")
	contentLabel.Name = "ContentText"
	contentLabel.Size = UDim2.new(1, -40, 1, -30)
	contentLabel.Position = UDim2.new(0, 20, 0, 15)
	contentLabel.BackgroundTransparency = 1
	contentLabel.Text = sections[1] and sections[1].content or ""
	contentLabel.TextColor3 = Theme.TEXT_PRIMARY
	contentLabel.TextSize = 17
	contentLabel.LineHeight = 1.5
	contentLabel.RichText = true
	contentLabel.Font = Enum.Font.Gotham
	contentLabel.TextWrapped = true
	contentLabel.TextXAlignment = Enum.TextXAlignment.Left
	contentLabel.TextYAlignment = Enum.TextYAlignment.Top
	contentLabel.ZIndex = 13
	contentLabel.Parent = contentFrame
	self.contentLabel = contentLabel
end

function TutorialUI:selectTab(index: number)
	local sections = Config.Tutorial and Config.Tutorial.Sections or {}
	if not sections[index] then return end

	self.activeTab = index

	-- Update tab button styles
	for i, button in ipairs(self.tabButtons) do
		if i == index then
			button.BackgroundColor3 = Theme.BG_ELEVATED
			button.TextColor3 = Theme.TEXT_PRIMARY
		else
			button.BackgroundColor3 = Theme.BG_BASE
			button.TextColor3 = Theme.TEXT_MUTED
		end
	end

	-- Update content
	self.contentLabel.Text = sections[index].content or ""
end

function TutorialUI:toggle()
	if self.isVisible then
		self:hide()
	else
		self:show()
	end
end

function TutorialUI:show()
	self.isVisible = true
	self.overlay.Visible = true

	-- Close other panels
	if self.callbacks.onShow then
		self.callbacks.onShow()
	end

	-- Animate in
	local panelWidth = 680
	local panelHeight = 500
	self.panel.Position = UDim2.new(0.5, -panelWidth / 2, 0.5, -panelHeight / 2 + 20)
	self.panel.BackgroundTransparency = 0.5
	self.helpButton.Visible = false

	TweenService:Create(self.panel, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, -panelWidth / 2, 0.5, -panelHeight / 2),
		BackgroundTransparency = 0,
	}):Play()

	-- Mark tutorial as seen
	if not self.hasSeenTutorial then
		self.hasSeenTutorial = true
		self.hintLabel.Visible = false
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local tutorialSeen = remotes and remotes:FindFirstChild("TutorialSeen")
		if tutorialSeen then
			tutorialSeen:FireServer()
		end
	end
end

function TutorialUI:hide()
	self.isVisible = false

	local panelWidth = 680
	local panelHeight = 500
	TweenService:Create(self.panel, TweenInfo.new(0.15), {
		Position = UDim2.new(0.5, -panelWidth / 2, 0.5, -panelHeight / 2 + 20),
		BackgroundTransparency = 0.5,
	}):Play()

	task.delay(0.15, function()
		if not self.isVisible then
			self.overlay.Visible = false
			self.helpButton.Visible = true
		end
	end)
end

function TutorialUI:showHint()
	self.hintLabel.Visible = true
	self.hintLabel.TextTransparency = 0

	local duration = Config.Tutorial and Config.Tutorial.HintDuration or 8
	task.delay(duration, function()
		if self.hintLabel.Visible then
			TweenService:Create(self.hintLabel, TweenInfo.new(0.5), {
				TextTransparency = 1,
				BackgroundTransparency = 1,
			}):Play()

			task.delay(0.5, function()
				self.hintLabel.Visible = false
			end)
		end
	end)
end

function TutorialUI:setupRemotes()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local updateCurrency = remotes:WaitForChild("UpdateCurrency")

	updateCurrency.OnClientEvent:Connect(function(data)
		if data.hasSeenTutorial ~= nil then
			self.hasSeenTutorial = data.hasSeenTutorial
			if not self.hasSeenTutorial then
				self:showHint()
			end
		end
	end)
end

return TutorialUI
