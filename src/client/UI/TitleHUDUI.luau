-- TitleHUDUI: แสดง Active Title บน HUD (Colorful Youth Style - Rarity Glow)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ClassTypes = require(ReplicatedStorage.Shared.ClassTypes)
local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local TitleHUDUI = {}
TitleHUDUI.__index = TitleHUDUI

-- Dark theme colors
local COLORS = {
	BG = Theme.BG_SURFACE,
	BG_TRANSPARENCY = 0.1,
	BG_BUTTON = Theme.BG_ELEVATED,
	BG_BUTTON_HOVER = Theme.BG_BASE,
	STROKE_DEFAULT = Theme.BG_ELEVATED,
	TEXT_HINT = Theme.TEXT_MUTED,
	TEXT_NO_TITLE = Theme.TEXT_MUTED,
}

local function cloneTitleEntry(source: any): {id: string, name: string, classId: string, level: number, rarity: string, description: string?}?
	if type(source) ~= "table" then
		return nil
	end

	if type(source.id) ~= "string" or source.id == "" then
		return nil
	end

	if type(source.name) ~= "string" or source.name == "" then
		return nil
	end

	if type(source.classId) ~= "string" or source.classId == "" then
		return nil
	end

	return {
		id = source.id,
		name = source.name,
		classId = source.classId,
		level = math.max(1, math.floor(tonumber(source.level) or 1)),
		rarity = if type(source.rarity) == "string" and source.rarity ~= "" then source.rarity else "Common",
		description = if type(source.description) == "string" then source.description else nil,
	}
end

local function getTitleTheme(rarity: string, classColor: Color3?): {textColor: Color3, strokeColor: Color3, frameColor: Color3}
	local configured = Config.Mastery and Config.Mastery.TitleThemes
	local theme = type(configured) == "table" and configured[rarity] or nil

	local result = {
		textColor = classColor or Theme.TEXT_PRIMARY,
		strokeColor = Color3.fromRGB(40, 40, 50),
		frameColor = classColor or Theme.BG_ELEVATED,
	}

	if type(theme) == "table" then
		if typeof(theme.textColor) == "Color3" then
			result.textColor = theme.textColor
		end
		if typeof(theme.strokeColor) == "Color3" then
			result.strokeColor = theme.strokeColor
		end
		if typeof(theme.frameColor) == "Color3" then
			result.frameColor = theme.frameColor
		end
	end

	return result
end

function TitleHUDUI.new(parent: ScreenGui, onOpenCollection: (() -> ())?)
	local self = setmetatable({}, TitleHUDUI)

	self.parent = parent
	self.remotes = Remotes
	self.onOpenCollection = onOpenCollection
	self.activeTitle = nil :: {id: string, name: string, classId: string, level: number, rarity: string, description: string?}?

	self:createUI()
	self:setupRemotes()
	self:updateActiveTitle(nil)

	return self
end

function TitleHUDUI:createUI()
	-- Main container - bigger rounded pill with rarity glow
	local container = Instance.new("Frame")
	container.Name = "TitleHUDContainer"
	container.Size = UDim2.new(0, 210, 0, 36)
	container.Position = UDim2.new(0, 10, 0, 184)
	container.BackgroundColor3 = COLORS.BG
	container.BackgroundTransparency = COLORS.BG_TRANSPARENCY
	container.BorderSizePixel = 0
	container.Parent = self.parent
	self.container = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CORNER_LG
	corner.Parent = container

	-- Rarity gradient (updated dynamically)
	local containerGradient = Instance.new("UIGradient")
	containerGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLORS.BG),
		ColorSequenceKeypoint.new(1, COLORS.BG)
	})
	containerGradient.Rotation = 0
	containerGradient.Parent = container
	self.containerGradient = containerGradient

	-- Glow stroke (updated to rarity color)
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.STROKE_DEFAULT
	stroke.Thickness = Theme.STROKE_MED
	stroke.Transparency = 0.3
	stroke.Parent = container
	self.containerStroke = stroke

	-- Drop shadow
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 4, 1, 4)
	shadow.Position = UDim2.new(0, -2, 0, 3)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.7
	shadow.BorderSizePixel = 0
	shadow.ZIndex = container.ZIndex - 1
	shadow.Parent = container

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = Theme.CORNER_LG
	shadowCorner.Parent = shadow

	-- Title text label
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -42, 1, 0)
	titleLabel.Position = UDim2.new(0, 10, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Tap to set title"
	titleLabel.TextColor3 = COLORS.TEXT_HINT
	titleLabel.TextSize = 14
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Parent = container
	self.titleLabel = titleLabel

	-- Title text stroke
	local titleTextStroke = Instance.new("UIStroke")
	titleTextStroke.Color = Color3.fromRGB(20, 10, 40)
	titleTextStroke.Thickness = 1.5
	titleTextStroke.Transparency = 0.5
	titleTextStroke.Parent = titleLabel
	self.titleTextStroke = titleTextStroke

	-- Make the whole container clickable when no title (hint text)
	local containerButton = Instance.new("TextButton")
	containerButton.Name = "ContainerButton"
	containerButton.Size = UDim2.new(1, -40, 1, 0)
	containerButton.Position = UDim2.new(0, 0, 0, 0)
	containerButton.BackgroundTransparency = 1
	containerButton.Text = ""
	containerButton.BorderSizePixel = 0
	containerButton.Parent = container
	self.containerButton = containerButton

	containerButton.MouseButton1Click:Connect(function()
		if not self.activeTitle and self.onOpenCollection then
			self.onOpenCollection()
		end
	end)

	-- Collection button
	local openButton = Instance.new("TextButton")
	openButton.Name = "OpenCollectionButton"
	openButton.Size = UDim2.new(0, 28, 0, 28)
	openButton.Position = UDim2.new(1, -32, 0.5, -14)
	openButton.BackgroundColor3 = COLORS.BG_BUTTON
	openButton.BorderSizePixel = 0
	openButton.Text = "\u{1F4CB}"
	openButton.TextColor3 = Theme.TEXT_MUTED
	openButton.TextSize = 14
	openButton.Font = Enum.Font.GothamBold
	openButton.Parent = container
	self.openButton = openButton

	local openButtonCorner = Instance.new("UICorner")
	openButtonCorner.CornerRadius = Theme.CORNER_SM
	openButtonCorner.Parent = openButton

	-- Hover effect for collection button
	openButton.MouseEnter:Connect(function()
		TweenService:Create(openButton, TweenInfo.new(0.12), {
			BackgroundColor3 = COLORS.BG_BUTTON_HOVER,
		}):Play()
	end)

	openButton.MouseLeave:Connect(function()
		TweenService:Create(openButton, TweenInfo.new(0.12), {
			BackgroundColor3 = COLORS.BG_BUTTON,
		}):Play()
	end)

	openButton.MouseButton1Click:Connect(function()
		if self.onOpenCollection then
			self.onOpenCollection()
		end
	end)

	-- Hover effect for whole container
	container.MouseEnter:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.12), {
			Transparency = 0,
		}):Play()
	end)

	container.MouseLeave:Connect(function()
		TweenService:Create(stroke, TweenInfo.new(0.12), {
			Transparency = 0.3,
		}):Play()
	end)
end

function TitleHUDUI:updateActiveTitle(activeTitle: any)
	self.activeTitle = cloneTitleEntry(activeTitle)

	if not self.activeTitle then
		self.titleLabel.Text = "Tap to set title  \u{203A}"
		self.titleLabel.TextColor3 = COLORS.TEXT_HINT
		self.titleLabel.TextStrokeTransparency = 1
		self.containerStroke.Color = COLORS.STROKE_DEFAULT
		self.titleTextStroke.Transparency = 0.8

		-- Reset gradient to default
		if self.containerGradient then
			self.containerGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, COLORS.BG),
				ColorSequenceKeypoint.new(1, COLORS.BG)
			})
			self.containerGradient.Transparency = NumberSequence.new(0)
		end
		return
	end

	local classDef = ClassTypes.getClass(self.activeTitle.classId)
	local theme = getTitleTheme(self.activeTitle.rarity, classDef and classDef.color or nil)

	self.titleLabel.Text = string.format("[%s] %s", self.activeTitle.rarity, self.activeTitle.name)
	self.titleLabel.TextColor3 = theme.textColor
	self.titleLabel.TextStrokeTransparency = 0.5
	self.titleLabel.TextStrokeColor3 = theme.strokeColor
	self.containerStroke.Color = theme.frameColor
	self.titleTextStroke.Color = theme.strokeColor
	self.titleTextStroke.Transparency = 0.3

	-- Apply rarity gradient background
	if self.containerGradient then
		self.containerGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, theme.frameColor),
			ColorSequenceKeypoint.new(1, COLORS.BG)
		})
		self.containerGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8),
			NumberSequenceKeypoint.new(1, 0)
		})
	end
end

function TitleHUDUI:setupRemotes()
	self.remotes.TitleUpdate.OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end

		self:updateActiveTitle(data.activeTitle)
	end)
end

return TitleHUDUI
