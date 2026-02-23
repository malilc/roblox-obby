-- ShopUI: Skeleton shop popup (triggered by ShopZone)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.ThemeConfig)

local ShopUI = {}
ShopUI.__index = ShopUI

function ShopUI.new(parent: ScreenGui, callbacks: {onShow: (() -> ())?}?)
	local self = setmetatable({}, ShopUI)
	self.parent = parent
	self.isVisible = false
	self.callbacks = callbacks or {}

	-- Remotes
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	self.showRemote = remotes:WaitForChild("ShowShop")
	self.hideRemote = remotes:WaitForChild("HideShop")

	self:createUI()
	self:setupRemotes()

	return self
end

local function createGradient(parent: GuiObject, color1: Color3, color2: Color3)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color1),
		ColorSequenceKeypoint.new(1, color2),
	})
	gradient.Rotation = 45
	gradient.Parent = parent
	return gradient
end

function ShopUI:createUI()
	-- Main frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "ShopFrame"
	mainFrame.Size = UDim2.new(0, 600, 0, 450)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainFrame.BackgroundColor3 = Theme.BG_BASE
	mainFrame.BackgroundTransparency = 0.15
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = self.parent
	self.mainFrame = mainFrame

	-- Gradient background
	createGradient(mainFrame, Theme.BG_BASE, Theme.BG_SURFACE)

	-- Glow stroke
	local borderStroke = Instance.new("UIStroke")
	borderStroke.Color = Theme.ACCENT_CYAN
	borderStroke.Thickness = Theme.STROKE_BOLD
	borderStroke.Transparency = 0.2
	borderStroke.Parent = mainFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CORNER_LG
	corner.Parent = mainFrame

	-- Drop shadow
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 6, 1, 6)
	shadow.Position = UDim2.new(0, -3, 0, 4)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.6
	shadow.BorderSizePixel = 0
	shadow.ZIndex = mainFrame.ZIndex - 1
	shadow.Parent = mainFrame
	Theme.applyCorner(shadow, "lg")

	-- Title
	local titleContainer = Instance.new("Frame")
	titleContainer.Name = "TitleContainer"
	titleContainer.Size = UDim2.new(1, -40, 0, 70)
	titleContainer.Position = UDim2.new(0, 20, 0, 20)
	titleContainer.BackgroundTransparency = 1
	titleContainer.Parent = mainFrame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundTransparency = 1
	title.Text = "\u{1F6D2} SHOP"
	title.TextColor3 = Theme.TEXT_PRIMARY
	title.TextSize = 28
	title.Font = Enum.Font.GothamBold
	title.TextStrokeTransparency = 0.8
	title.TextStrokeColor3 = Theme.ACCENT_CYAN
	title.Parent = titleContainer

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, 0, 0, 20)
	subtitle.Position = UDim2.new(0, 0, 0, 42)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Coming Soon!"
	subtitle.TextColor3 = Theme.TEXT_MUTED
	subtitle.TextSize = 14
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextTransparency = 0.3
	subtitle.Parent = titleContainer

	-- Close button (X)
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 32, 0, 32)
	closeBtn.Position = UDim2.new(1, -42, 0, 10)
	closeBtn.BackgroundColor3 = Theme.BG_OVERLAY
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = ""
	closeBtn.Parent = mainFrame

	local closeBtnCorner = Instance.new("UICorner")
	closeBtnCorner.CornerRadius = Theme.CORNER_SM
	closeBtnCorner.Parent = closeBtn

	local closeBtnLabel = Instance.new("TextLabel")
	closeBtnLabel.Size = UDim2.new(1, 0, 1, 0)
	closeBtnLabel.BackgroundTransparency = 1
	closeBtnLabel.Text = "X"
	closeBtnLabel.TextColor3 = Theme.TEXT_MUTED
	closeBtnLabel.TextSize = 16
	closeBtnLabel.Font = Enum.Font.GothamBold
	closeBtnLabel.ZIndex = closeBtn.ZIndex + 1
	closeBtnLabel.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		self:hide()
	end)

	-- Content area (scroll frame placeholder)
	local contentFrame = Instance.new("ScrollingFrame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Size = UDim2.new(1, -40, 1, -130)
	contentFrame.Position = UDim2.new(0, 20, 0, 100)
	contentFrame.BackgroundColor3 = Theme.BG_SURFACE
	contentFrame.BackgroundTransparency = 0.5
	contentFrame.BorderSizePixel = 0
	contentFrame.ScrollBarThickness = 4
	contentFrame.ScrollBarImageColor3 = Theme.ACCENT_CYAN
	contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	contentFrame.Parent = mainFrame

	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = Theme.CORNER_MD
	contentCorner.Parent = contentFrame

	-- Placeholder text
	local placeholder = Instance.new("TextLabel")
	placeholder.Name = "Placeholder"
	placeholder.Size = UDim2.new(1, 0, 1, 0)
	placeholder.BackgroundTransparency = 1
	placeholder.Text = "Items will appear here"
	placeholder.TextColor3 = Theme.TEXT_MUTED
	placeholder.TextSize = 18
	placeholder.Font = Enum.Font.Gotham
	placeholder.TextTransparency = 0.4
	placeholder.Parent = contentFrame
end

function ShopUI:setupRemotes()
	self.showRemote.OnClientEvent:Connect(function()
		self:show()
	end)

	self.hideRemote.OnClientEvent:Connect(function()
		self:hide()
	end)
end

function ShopUI:show()
	if self.isVisible then return end
	self.isVisible = true

	-- Fire onShow callback (mutual exclusion)
	if self.callbacks.onShow then
		self.callbacks.onShow()
	end

	self.mainFrame.Visible = true

	-- Fade in
	self.mainFrame.BackgroundTransparency = 1
	TweenService:Create(self.mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.15,
	}):Play()
end

function ShopUI:hide()
	if not self.isVisible then return end
	self.isVisible = false

	local fadeOut = TweenService:Create(self.mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	})
	fadeOut:Play()
	fadeOut.Completed:Connect(function()
		self.mainFrame.Visible = false
	end)
end

return ShopUI
