-- CurrencyUI: แสดงเงินในเกม (Colorful Youth Style - Gold Gradient)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.ThemeConfig)
local UIFactory = require(script.Parent.UIFactory)

local LocalPlayer = Players.LocalPlayer

local CurrencyUI = {}
CurrencyUI.__index = CurrencyUI

-- Helper: create drop shadow under a pill
local function createDropShadow(pill: Frame)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 4, 1, 4)
	shadow.Position = UDim2.new(0, -2, 0, 3)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.7
	shadow.BorderSizePixel = 0
	shadow.ZIndex = pill.ZIndex - 1
	shadow.Parent = pill

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = Theme.CORNER_LG
	shadowCorner.Parent = shadow
end

function CurrencyUI.new(parent: ScreenGui)
	local self = setmetatable({}, CurrencyUI)

	self.parent = parent
	self.currency = 0
	self.floatingTexts = {} -- Track floating texts for cleanup

	self:createUI()

	return self
end

function CurrencyUI:createUI()
	-- === CURRENCY DISPLAY - Gold→Amber Gradient ===
	local currencyFrame = UIFactory.createPanel(self.parent, {
		name = "CurrencyFrame",
		size = UDim2.new(0, 140, 0, 44),
		position = UDim2.new(0, 10, 0, 58),
		bgColor = Theme.HUD_CURRENCY_START,
		bgTransparency = 0.15,
		cornerSize = "lg",
		strokeColor = Theme.HUD_GLOW_GOLD,
		strokeWeight = "med",
		strokeTransparency = 0.2,
	})
	self.currencyFrame = currencyFrame
	self.frameStroke = currencyFrame:FindFirstChildOfClass("UIStroke")

	-- Vivid gold→amber gradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.HUD_CURRENCY_START),
		ColorSequenceKeypoint.new(1, Theme.HUD_CURRENCY_END)
	})
	gradient.Rotation = 135
	gradient.Parent = currencyFrame

	-- Drop shadow
	createDropShadow(currencyFrame)

	-- Coin Icon Container
	local coinContainer = Instance.new("Frame")
	coinContainer.Name = "CoinContainer"
	coinContainer.Size = UDim2.new(0, 36, 0, 36)
	coinContainer.Position = UDim2.new(0, 4, 0.5, -18)
	coinContainer.BackgroundTransparency = 1
	coinContainer.Parent = currencyFrame
	self.coinContainer = coinContainer

	-- Coin Icon Background (golden circle - bigger)
	local coinIcon = Instance.new("Frame")
	coinIcon.Name = "CoinIcon"
	coinIcon.Size = UDim2.new(1, 0, 1, 0)
	coinIcon.Position = UDim2.new(0, 0, 0, 0)
	coinIcon.BackgroundColor3 = Theme.PRIMARY
	coinIcon.BorderSizePixel = 0
	coinIcon.Parent = coinContainer
	self.coinIcon = coinIcon

	local coinIconCorner = Instance.new("UICorner")
	coinIconCorner.CornerRadius = Theme.CORNER_FULL
	coinIconCorner.Parent = coinIcon

	-- Coin gradient (vivid 3D)
	local coinGradient = Instance.new("UIGradient")
	coinGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 180)),
		ColorSequenceKeypoint.new(0.5, Theme.PRIMARY),
		ColorSequenceKeypoint.new(1, Theme.PRIMARY_DARK)
	})
	coinGradient.Rotation = 135
	coinGradient.Parent = coinIcon

	-- Coin Inner Circle
	local coinInner = Instance.new("Frame")
	coinInner.Name = "CoinInner"
	coinInner.Size = UDim2.new(0, 24, 0, 24)
	coinInner.Position = UDim2.new(0.5, -12, 0.5, -12)
	coinInner.BackgroundColor3 = Theme.MEDAL_GOLD
	coinInner.BorderSizePixel = 0
	coinInner.Parent = coinIcon

	local coinInnerCorner = Instance.new("UICorner")
	coinInnerCorner.CornerRadius = Theme.CORNER_FULL
	coinInnerCorner.Parent = coinInner

	-- Coin symbol
	local coinSymbol = Instance.new("TextLabel")
	coinSymbol.Name = "CoinSymbol"
	coinSymbol.Size = UDim2.new(1, 0, 1, 0)
	coinSymbol.Position = UDim2.new(0, 0, 0, 0)
	coinSymbol.BackgroundTransparency = 1
	coinSymbol.Text = "$"
	coinSymbol.TextColor3 = Color3.fromRGB(160, 110, 0)
	coinSymbol.TextSize = 18
	coinSymbol.Font = Enum.Font.GothamBlack
	coinSymbol.Parent = coinInner
	self.coinSymbol = coinSymbol

	-- Coin stroke (bolder)
	local coinStroke = Instance.new("UIStroke")
	coinStroke.Color = Color3.fromRGB(180, 130, 0)
	coinStroke.Thickness = Theme.STROKE_MED
	coinStroke.Parent = coinIcon

	-- Shine effect (brighter)
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.new(0.3, 0, 1.2, 0)
	shine.Position = UDim2.new(-0.3, 0, -0.1, 0)
	shine.BackgroundColor3 = Theme.TEXT_PRIMARY
	shine.BackgroundTransparency = 0.5
	shine.BorderSizePixel = 0
	shine.Rotation = 25
	shine.ClipsDescendants = false
	shine.Parent = coinIcon
	self.shine = shine

	-- Shine gradient
	local shineGradient = Instance.new("UIGradient")
	shineGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	shineGradient.Parent = shine

	-- Currency Number (white for contrast on gold bg)
	local currencyLabel = UIFactory.createLabel(currencyFrame, {
		name = "CurrencyLabel",
		size = UDim2.new(1, -50, 1, 0),
		position = UDim2.new(0, 44, 0, 0),
		text = "0",
		textColor = Theme.TEXT_PRIMARY,
		textSize = 22,
		font = Enum.Font.GothamBlack,
		textXAlignment = Enum.TextXAlignment.Left,
	})
	self.currencyLabel = currencyLabel

	-- Bold text stroke for visibility
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(120, 80, 0)
	textStroke.Thickness = 2
	textStroke.Transparency = 0.3
	textStroke.Parent = currencyLabel

	-- Start shine animation loop
	self:startShineAnimation()
end

-- Shine animation loop
function CurrencyUI:startShineAnimation()
	task.spawn(function()
		while self.shine and self.shine.Parent do
			-- Reset position
			self.shine.Position = UDim2.new(-0.3, 0, -0.1, 0)

			-- Animate across
			local shineTween = TweenService:Create(self.shine, TweenInfo.new(0.8, Enum.EasingStyle.Linear), {
				Position = UDim2.new(1.1, 0, -0.1, 0)
			})
			shineTween:Play()

			-- Wait before next shine
			task.wait(1.5)
		end
	end)
end

function CurrencyUI:updateCurrency(data: {[string]: any})
	if data.currency ~= nil then
		local oldCurrency = self.currency
		local newCurrency = data.currency
		self.currency = newCurrency
		self.currencyLabel.Text = tostring(self.currency)

		-- Currency pop animation when increased
		local diff = newCurrency - oldCurrency
		if diff > 0 then
			self:playCurrencyAnimation()
			self:showFloatingText("+" .. diff)
		elseif diff < 0 then
			self:showFloatingText(tostring(diff), Theme.DANGER)
		end
	end
end

function CurrencyUI:playCurrencyAnimation()
	-- Scale up currency frame
	local originalSize = UDim2.new(0, 140, 0, 44)
	local originalStrokeTransparency = 0.2

	-- Frame scale animation
	local scaleUp = TweenService:Create(self.currencyFrame, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 155, 0, 50)
	})
	scaleUp:Play()

	-- Glow effect (brighter)
	local glowUp = TweenService:Create(self.frameStroke, TweenInfo.new(0.1), {
		Transparency = 0,
		Thickness = Theme.STROKE_BOLD
	})
	glowUp:Play()

	scaleUp.Completed:Connect(function()
		local scaleDown = TweenService:Create(self.currencyFrame, TweenInfo.new(0.15, Enum.EasingStyle.Bounce), {
			Size = originalSize
		})
		scaleDown:Play()

		local glowDown = TweenService:Create(self.frameStroke, TweenInfo.new(0.2), {
			Transparency = originalStrokeTransparency,
			Thickness = Theme.STROKE_MED
		})
		glowDown:Play()
	end)

	-- Flash currency color
	self.currencyLabel.TextColor3 = Color3.fromRGB(255, 255, 150)
	task.delay(0.15, function()
		local colorTween = TweenService:Create(self.currencyLabel, TweenInfo.new(0.25), {
			TextColor3 = Theme.TEXT_PRIMARY
		})
		colorTween:Play()
	end)

	-- Coin bounce animation
	local coinBounce = TweenService:Create(self.coinContainer, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 42, 0, 42),
		Position = UDim2.new(0, 1, 0.5, -21)
	})
	coinBounce:Play()

	coinBounce.Completed:Connect(function()
		local coinReturn = TweenService:Create(self.coinContainer, TweenInfo.new(0.15, Enum.EasingStyle.Bounce), {
			Size = UDim2.new(0, 36, 0, 36),
			Position = UDim2.new(0, 4, 0.5, -18)
		})
		coinReturn:Play()
	end)
end

-- Floating text animation
function CurrencyUI:showFloatingText(text: string, color: Color3?)
	local floatText = Instance.new("TextLabel")
	floatText.Name = "FloatingText"
	floatText.Size = UDim2.new(0, 60, 0, 30)
	floatText.Position = UDim2.new(0, 100, 0, 58)
	floatText.BackgroundTransparency = 1
	floatText.Text = text
	floatText.TextColor3 = color or Theme.SUCCESS
	floatText.TextSize = 20
	floatText.Font = Enum.Font.GothamBlack
	floatText.TextXAlignment = Enum.TextXAlignment.Center
	floatText.TextTransparency = 0
	floatText.ZIndex = 10
	floatText.Parent = self.parent

	-- Bold text stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = Theme.STROKE_MED
	stroke.Transparency = 0.2
	stroke.Parent = floatText

	-- Track for cleanup
	table.insert(self.floatingTexts, floatText)

	-- Animate up and fade out
	local floatUp = TweenService:Create(floatText, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 100, 0, 30)
	})
	floatUp:Play()

	local fadeOut = TweenService:Create(floatText, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1
	})
	fadeOut:Play()

	local strokeFade = TweenService:Create(stroke, TweenInfo.new(0.8), {
		Transparency = 1
	})
	strokeFade:Play()

	-- Cleanup after animation
	fadeOut.Completed:Connect(function()
		floatText:Destroy()
		-- Remove from tracking table
		for i, v in ipairs(self.floatingTexts) do
			if v == floatText then
				table.remove(self.floatingTexts, i)
				break
			end
		end
	end)
end

-- Cleanup function
function CurrencyUI:destroy()
	-- Clean up floating texts
	for _, text in ipairs(self.floatingTexts) do
		if text and text.Parent then
			text:Destroy()
		end
	end
	self.floatingTexts = {}

	-- Destroy main frame
	if self.currencyFrame then
		self.currencyFrame:Destroy()
	end
end

return CurrencyUI
