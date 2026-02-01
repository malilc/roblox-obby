-- CurrencyUI: แสดงเงินในเกม (Enhanced Version)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local CurrencyUI = {}
CurrencyUI.__index = CurrencyUI

function CurrencyUI.new(parent: ScreenGui)
	local self = setmetatable({}, CurrencyUI)
	
	self.parent = parent
	self.currency = 0
	self.floatingTexts = {} -- Track floating texts for cleanup
	
	self:createUI()
	
	return self
end

function CurrencyUI:createUI()
	-- === CURRENCY DISPLAY (มุมบนซ้าย - ใต้ StageFrame) ===
	local currencyFrame = Instance.new("Frame")
	currencyFrame.Name = "CurrencyFrame"
	currencyFrame.Size = UDim2.new(0, 140, 0, 44)
	currencyFrame.Position = UDim2.new(0, 10, 0, 92)
	currencyFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	currencyFrame.BackgroundTransparency = 0.3
	currencyFrame.BorderSizePixel = 0
	currencyFrame.Parent = self.parent
	self.currencyFrame = currencyFrame
	
	local currencyCorner = Instance.new("UICorner")
	currencyCorner.CornerRadius = UDim.new(0, 22)
	currencyCorner.Parent = currencyFrame
	
	-- Frame Stroke (glow effect)
	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Color3.fromRGB(255, 200, 50)
	frameStroke.Thickness = 1.5
	frameStroke.Transparency = 0.5
	frameStroke.Parent = currencyFrame
	self.frameStroke = frameStroke
	
	-- Gradient background
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 35, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 30))
	})
	gradient.Rotation = 45
	gradient.Parent = currencyFrame
	
	-- Coin Icon Container (for shine effect)
	local coinContainer = Instance.new("Frame")
	coinContainer.Name = "CoinContainer"
	coinContainer.Size = UDim2.new(0, 36, 0, 36)
	coinContainer.Position = UDim2.new(0, 4, 0.5, -18)
	coinContainer.BackgroundTransparency = 1
	coinContainer.Parent = currencyFrame
	self.coinContainer = coinContainer
	
	-- Coin Icon Background (golden circle)
	local coinIcon = Instance.new("Frame")
	coinIcon.Name = "CoinIcon"
	coinIcon.Size = UDim2.new(1, 0, 1, 0)
	coinIcon.Position = UDim2.new(0, 0, 0, 0)
	coinIcon.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	coinIcon.BorderSizePixel = 0
	coinIcon.Parent = coinContainer
	self.coinIcon = coinIcon
	
	local coinIconCorner = Instance.new("UICorner")
	coinIconCorner.CornerRadius = UDim.new(1, 0)
	coinIconCorner.Parent = coinIcon
	
	-- Coin gradient (3D effect)
	local coinGradient = Instance.new("UIGradient")
	coinGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 100)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 150, 30))
	})
	coinGradient.Rotation = 135
	coinGradient.Parent = coinIcon
	
	-- Coin Inner Circle (detail)
	local coinInner = Instance.new("Frame")
	coinInner.Name = "CoinInner"
	coinInner.Size = UDim2.new(0, 24, 0, 24)
	coinInner.Position = UDim2.new(0.5, -12, 0.5, -12)
	coinInner.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	coinInner.BorderSizePixel = 0
	coinInner.Parent = coinIcon
	
	local coinInnerCorner = Instance.new("UICorner")
	coinInnerCorner.CornerRadius = UDim.new(1, 0)
	coinInnerCorner.Parent = coinInner
	
	-- Coin symbol ($)
	local coinSymbol = Instance.new("TextLabel")
	coinSymbol.Name = "CoinSymbol"
	coinSymbol.Size = UDim2.new(1, 0, 1, 0)
	coinSymbol.Position = UDim2.new(0, 0, 0, 0)
	coinSymbol.BackgroundTransparency = 1
	coinSymbol.Text = "$"
	coinSymbol.TextColor3 = Color3.fromRGB(180, 130, 0)
	coinSymbol.TextSize = 18
	coinSymbol.Font = Enum.Font.GothamBlack
	coinSymbol.Parent = coinInner
	self.coinSymbol = coinSymbol
	
	-- Coin stroke (outline)
	local coinStroke = Instance.new("UIStroke")
	coinStroke.Color = Color3.fromRGB(180, 130, 0)
	coinStroke.Thickness = 2
	coinStroke.Parent = coinIcon
	
	-- Shine effect (animated)
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.new(0.3, 0, 1.2, 0)
	shine.Position = UDim2.new(-0.3, 0, -0.1, 0)
	shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shine.BackgroundTransparency = 0.7
	shine.BorderSizePixel = 0
	shine.Rotation = 25
	shine.ClipsDescendants = false
	shine.Parent = coinIcon
	self.shine = shine
	
	-- Shine gradient
	local shineGradient = Instance.new("UIGradient")
	shineGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 1)
	})
	shineGradient.Parent = shine
	
	-- Currency Number
	local currencyLabel = Instance.new("TextLabel")
	currencyLabel.Name = "CurrencyLabel"
	currencyLabel.Size = UDim2.new(1, -50, 1, 0)
	currencyLabel.Position = UDim2.new(0, 44, 0, 0)
	currencyLabel.BackgroundTransparency = 1
	currencyLabel.Text = "0"
	currencyLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
	currencyLabel.TextSize = 22
	currencyLabel.Font = Enum.Font.GothamBlack
	currencyLabel.TextXAlignment = Enum.TextXAlignment.Left
	currencyLabel.Parent = currencyFrame
	self.currencyLabel = currencyLabel
	
	-- Text stroke for better visibility
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(100, 70, 0)
	textStroke.Thickness = 1
	textStroke.Transparency = 0.5
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
			task.wait(3)
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
			self:showFloatingText(tostring(diff), Color3.fromRGB(255, 100, 100))
		end
	end
end

function CurrencyUI:playCurrencyAnimation()
	-- Scale up currency frame
	local originalSize = UDim2.new(0, 140, 0, 44)
	local originalStrokeTransparency = 0.5
	
	-- Frame scale animation
	local scaleUp = TweenService:Create(self.currencyFrame, TweenInfo.new(0.1, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 155, 0, 50)
	})
	scaleUp:Play()
	
	-- Glow effect
	local glowUp = TweenService:Create(self.frameStroke, TweenInfo.new(0.1), {
		Transparency = 0,
		Thickness = 2.5
	})
	glowUp:Play()
	
	scaleUp.Completed:Connect(function()
		local scaleDown = TweenService:Create(self.currencyFrame, TweenInfo.new(0.15, Enum.EasingStyle.Bounce), {
			Size = originalSize
		})
		scaleDown:Play()
		
		local glowDown = TweenService:Create(self.frameStroke, TweenInfo.new(0.2), {
			Transparency = originalStrokeTransparency,
			Thickness = 1.5
		})
		glowDown:Play()
	end)
	
	-- Flash currency color
	self.currencyLabel.TextColor3 = Color3.fromRGB(255, 255, 150)
	task.delay(0.15, function()
		local colorTween = TweenService:Create(self.currencyLabel, TweenInfo.new(0.25), {
			TextColor3 = Color3.fromRGB(255, 220, 100)
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

-- Floating text animation (+X)
function CurrencyUI:showFloatingText(text: string, color: Color3?)
	local floatText = Instance.new("TextLabel")
	floatText.Name = "FloatingText"
	floatText.Size = UDim2.new(0, 60, 0, 30)
	floatText.Position = UDim2.new(0, 100, 0, 92)
	floatText.BackgroundTransparency = 1
	floatText.Text = text
	floatText.TextColor3 = color or Color3.fromRGB(100, 255, 100)
	floatText.TextSize = 20
	floatText.Font = Enum.Font.GothamBlack
	floatText.TextXAlignment = Enum.TextXAlignment.Center
	floatText.TextTransparency = 0
	floatText.ZIndex = 10
	floatText.Parent = self.parent
	
	-- Text stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 2
	stroke.Transparency = 0.3
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
