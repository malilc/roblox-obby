-- TitleHUDUI: แสดง Active Title บน HUD และเปิดหน้า Title Collection

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassTypes = require(ReplicatedStorage.Shared.ClassTypes)
local Config = require(ReplicatedStorage.Shared.Config)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local TitleHUDUI = {}
TitleHUDUI.__index = TitleHUDUI

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
		textColor = classColor or Color3.fromRGB(230, 230, 230),
		strokeColor = Color3.fromRGB(0, 0, 0),
		frameColor = classColor or Color3.fromRGB(95, 95, 110),
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
	local container = Instance.new("Frame")
	container.Name = "TitleHUDContainer"
	container.Size = UDim2.new(0, 250, 0, 34)
	container.Position = UDim2.new(0, 10, 0, 220)
	container.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	container.BackgroundTransparency = 0.2
	container.BorderSizePixel = 0
	container.Parent = self.parent
	self.container = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = container

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(95, 95, 110)
	stroke.Thickness = 1.5
	stroke.Parent = container
	self.containerStroke = stroke

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -34, 1, 0)
	titleLabel.Position = UDim2.new(0, 8, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "No Title"
	titleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	titleLabel.TextSize = 13
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Parent = container
	self.titleLabel = titleLabel

	local openButton = Instance.new("TextButton")
	openButton.Name = "OpenCollectionButton"
	openButton.Size = UDim2.new(0, 26, 0, 26)
	openButton.Position = UDim2.new(1, -30, 0.5, -13)
	openButton.BackgroundColor3 = Color3.fromRGB(55, 55, 70)
	openButton.BorderSizePixel = 0
	openButton.Text = "≡"
	openButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	openButton.TextSize = 15
	openButton.Font = Enum.Font.GothamBold
	openButton.Parent = container

	local openButtonCorner = Instance.new("UICorner")
	openButtonCorner.CornerRadius = UDim.new(0, 6)
	openButtonCorner.Parent = openButton

	openButton.MouseButton1Click:Connect(function()
		if self.onOpenCollection then
			self.onOpenCollection()
		end
	end)
end

function TitleHUDUI:updateActiveTitle(activeTitle: any)
	self.activeTitle = cloneTitleEntry(activeTitle)

	if not self.activeTitle then
		self.titleLabel.Text = "No Title"
		self.titleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		self.titleLabel.TextStrokeTransparency = 0.4
		self.titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		self.containerStroke.Color = Color3.fromRGB(95, 95, 110)
		return
	end

	local classDef = ClassTypes.getClass(self.activeTitle.classId)
	local theme = getTitleTheme(self.activeTitle.rarity, classDef and classDef.color or nil)

	self.titleLabel.Text = string.format("[%s] %s", self.activeTitle.rarity, self.activeTitle.name)
	self.titleLabel.TextColor3 = theme.textColor
	self.titleLabel.TextStrokeTransparency = 0.35
	self.titleLabel.TextStrokeColor3 = theme.strokeColor
	self.containerStroke.Color = theme.frameColor
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
