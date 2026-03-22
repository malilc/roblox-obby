-- TutorialUI: ปุ่ม "?" เปิดคู่มือเกมแบบ tab ใน lobby

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)
local AdaptiveLayout = require(ReplicatedStorage.Shared.AdaptiveLayout)

local TutorialUI = {}
TutorialUI.__index = TutorialUI

local PANEL_W = 780
local PANEL_H = 580

function TutorialUI.new(parent: ScreenGui, callbacks: {onShow: (() -> ())?, onHide: (() -> ())?, hideHelpButton: boolean?}?)
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
	helpButton.TextColor3 = Theme.darkenForText(Theme.ACCENT_CYAN, 0.45)
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
		ColorSequenceKeypoint.new(0, Theme.PANEL_GRAD_TOP),
		ColorSequenceKeypoint.new(1, Theme.PANEL_GRAD_BTM)
	})
	helpGradient.Rotation = 180
	helpGradient.Parent = helpButton

	helpButton.MouseButton1Click:Connect(function()
		self:toggle()
	end)

	-- Hide help button if managed by MenuGridUI
	if self.callbacks.hideHelpButton then
		helpButton.Visible = false
	end

	-- === Main Panel (directly on ScreenGui, no overlay) ===
	local panel = Instance.new("Frame")
	panel.Name = "TutorialPanel"
	panel.Size = UDim2.new(0, 780, 0, 580)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Theme.BG_BASE
	panel.BackgroundTransparency = 0.02
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = self.parent
	self.panel = panel

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = Theme.CORNER_LG
	panelCorner.Parent = panel

	-- Panel gradient
	local panelGradient = Instance.new("UIGradient")
	panelGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.PANEL_GRAD_TOP),
		ColorSequenceKeypoint.new(1, Theme.PANEL_GRAD_BTM)
	})
	panelGradient.Rotation = 180
	panelGradient.Parent = panel

	-- Panel glow stroke
	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Theme.ACCENT_CYAN
	panelStroke.Thickness = Theme.STROKE_MED
	panelStroke.Transparency = 0.5
	panelStroke.Parent = panel

	-- Panel drop shadow
	local panelShadow = Instance.new("Frame")
	panelShadow.Name = "Shadow"
	panelShadow.Size = UDim2.new(1, 6, 1, 6)
	panelShadow.Position = UDim2.new(0, -3, 0, 4)
	panelShadow.BackgroundColor3 = Theme.CARD_SHADOW
	panelShadow.BackgroundTransparency = 0.7
	panelShadow.BorderSizePixel = 0
	panelShadow.ZIndex = panel.ZIndex - 1
	panelShadow.Parent = panel
	Theme.applyCorner(panelShadow, "lg")

	-- Header
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(0, 300, 0, 40)
	header.Position = UDim2.new(0, 22, 0, 10)
	header.BackgroundTransparency = 1
	header.RichText = true
	header.Text = '<font size="22">\u{2753}</font>  <font face="GothamBold" size="28"><b>GAME GUIDE</b></font>'
	header.TextColor3 = Theme.TEXT_PRIMARY
	header.TextSize = 28
	header.Font = Enum.Font.GothamBold
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = panel

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 40, 0, 40)
	closeButton.Position = UDim2.new(1, -54, 0, 12)
	closeButton.BackgroundColor3 = Theme.DANGER
	closeButton.BorderSizePixel = 0
	closeButton.Text = ""
	closeButton.Parent = panel
	Theme.applyCorner(closeButton, "sm")

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = Theme.DANGER
	closeStroke.Thickness = 1
	closeStroke.Transparency = 0.3
	closeStroke.Parent = closeButton

	local closeBtnLabel = Instance.new("TextLabel")
	closeBtnLabel.Size = UDim2.new(1, 0, 1, 0)
	closeBtnLabel.BackgroundTransparency = 1
	closeBtnLabel.Text = "X"
	closeBtnLabel.TextColor3 = Theme.TEXT_ON_ACCENT
	closeBtnLabel.TextSize = 20
	closeBtnLabel.Font = Enum.Font.GothamBold
	closeBtnLabel.ZIndex = closeButton.ZIndex + 1
	closeBtnLabel.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		self:hide()
	end)

	-- Tab bar
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, -30, 0, 42)
	tabBar.Position = UDim2.new(0, 15, 0, 58)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = panel

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 5)
	tabLayout.Parent = tabBar

	-- Tab กว้างขึ้นเพื่อไม่ตัดข้อความ
	local panelWidth = 780
	local tabWidth = math.floor((panelWidth - 30 - 5 * (#sections - 1)) / #sections)

	for i, section in ipairs(sections) do
		local tabButton = Instance.new("TextButton")
		tabButton.Name = "Tab_" .. section.id
		tabButton.Size = UDim2.new(0, tabWidth, 0, 38)
		tabButton.BackgroundColor3 = if i == 1 then Theme.BG_ELEVATED else Theme.BG_BASE
		tabButton.BackgroundTransparency = 0.1
		tabButton.Text = (section.icon or "") .. " " .. section.title
		tabButton.TextColor3 = if i == 1 then Theme.TEXT_PRIMARY else Theme.TEXT_MUTED
		tabButton.TextSize = 15
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
	contentFrame.BackgroundColor3 = Theme.BG_SURFACE
	contentFrame.BackgroundTransparency = 0.1
	contentFrame.BorderSizePixel = 0
	contentFrame.ZIndex = 12
	contentFrame.Parent = panel

	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = Theme.CORNER_SM
	contentCorner.Parent = contentFrame

	local contentStroke = Instance.new("UIStroke")
	contentStroke.Color = Theme.BG_ELEVATED
	contentStroke.Thickness = Theme.STROKE_THIN
	contentStroke.Transparency = 0.3
	contentStroke.Parent = contentFrame

	-- Content text (font ใหญ่ขึ้น + line height ดีขึ้น)
	local contentLabel = Instance.new("TextLabel")
	contentLabel.Name = "ContentText"
	contentLabel.Size = UDim2.new(1, -40, 1, -30)
	contentLabel.Position = UDim2.new(0, 20, 0, 15)
	contentLabel.BackgroundTransparency = 1
	contentLabel.Text = sections[1] and sections[1].content or ""
	contentLabel.TextColor3 = Theme.TEXT_PRIMARY
	contentLabel.TextSize = 18
	contentLabel.LineHeight = 1.5
	contentLabel.RichText = true
	contentLabel.Font = Enum.Font.Gotham
	contentLabel.TextWrapped = true
	contentLabel.TextXAlignment = Enum.TextXAlignment.Left
	contentLabel.TextYAlignment = Enum.TextYAlignment.Top
	contentLabel.ZIndex = 13
	contentLabel.Parent = contentFrame
	self.contentLabel = contentLabel

	-- Responsive scaling (Phase 2)
	AdaptiveLayout.applyScale(self.panel, PANEL_W, PANEL_H)
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
	self.panel.Visible = true

	-- Close other panels
	if self.callbacks.onShow then
		self.callbacks.onShow()
	end

	-- Animate in (fade only, like ShopUI)
	self.panel.BackgroundTransparency = 1

	TweenService:Create(self.panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.02,
	}):Play()

	-- Mark tutorial as seen
	if not self.hasSeenTutorial then
		self.hasSeenTutorial = true
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local tutorialSeen = remotes and remotes:FindFirstChild("TutorialSeen")
		if tutorialSeen then
			tutorialSeen:FireServer()
		end
	end
end

function TutorialUI:hide()
	self.isVisible = false

	if self.callbacks.onHide then
		self.callbacks.onHide()
	end

	local fadeOut = TweenService:Create(self.panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	})
	fadeOut:Play()
	fadeOut.Completed:Connect(function()
		if not self.isVisible then
			self.panel.Visible = false
		end
	end)
end

function TutorialUI:setupRemotes()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local updateCurrency = remotes:WaitForChild("UpdateCurrency")

	updateCurrency.OnClientEvent:Connect(function(data)
		if data.hasSeenTutorial ~= nil then
			self.hasSeenTutorial = data.hasSeenTutorial
		end
	end)
end

return TutorialUI
