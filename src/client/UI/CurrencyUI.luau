-- CurrencyUI: แสดงเงินในเกม

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local CurrencyUI = {}
CurrencyUI.__index = CurrencyUI

function CurrencyUI.new(parent: ScreenGui)
	local self = setmetatable({}, CurrencyUI)
	
	self.parent = parent
	self.currency = 0
	
	self:createUI()
	
	return self
end

function CurrencyUI:createUI()
	-- === CURRENCY DISPLAY (มุมบนซ้าย - ใต้ StageFrame) ===
	local currencyFrame = Instance.new("Frame")
	currencyFrame.Name = "CurrencyFrame"
	currencyFrame.Size = UDim2.new(0, 120, 0, 36)
	currencyFrame.Position = UDim2.new(0, 10, 0, 70) -- ใต้ StageFrame (ขยับขึ้น)
	currencyFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	currencyFrame.BackgroundTransparency = 0.5
	currencyFrame.BorderSizePixel = 0
	currencyFrame.Parent = self.parent
	self.currencyFrame = currencyFrame
	
	local currencyCorner = Instance.new("UICorner")
	currencyCorner.CornerRadius = UDim.new(0, 18)
	currencyCorner.Parent = currencyFrame
	
	-- Coin Icon
	local coinIcon = Instance.new("TextLabel")
	coinIcon.Name = "CoinIcon"
	coinIcon.Size = UDim2.new(0, 30, 0, 30)
	coinIcon.Position = UDim2.new(0, 3, 0.5, -15)
	coinIcon.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	coinIcon.BackgroundTransparency = 0
	coinIcon.Text = "💰"
	coinIcon.TextSize = 18
	coinIcon.Parent = currencyFrame
	
	local coinIconCorner = Instance.new("UICorner")
	coinIconCorner.CornerRadius = UDim.new(1, 0)
	coinIconCorner.Parent = coinIcon
	
	-- Coin stroke (เหรียญ)
	local coinStroke = Instance.new("UIStroke")
	coinStroke.Color = Color3.fromRGB(200, 150, 0)
	coinStroke.Thickness = 2
	coinStroke.Parent = coinIcon
	
	-- Currency Number
	local currencyLabel = Instance.new("TextLabel")
	currencyLabel.Name = "CurrencyLabel"
	currencyLabel.Size = UDim2.new(1, -40, 1, 0)
	currencyLabel.Position = UDim2.new(0, 36, 0, 0)
	currencyLabel.BackgroundTransparency = 1
	currencyLabel.Text = "0"
	currencyLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	currencyLabel.TextSize = 18
	currencyLabel.Font = Enum.Font.GothamBold
	currencyLabel.TextXAlignment = Enum.TextXAlignment.Left
	currencyLabel.Parent = currencyFrame
	self.currencyLabel = currencyLabel
end

function CurrencyUI:updateCurrency(data: {[string]: any})
	if data.currency ~= nil then
		local oldCurrency = self.currency
		self.currency = data.currency
		self.currencyLabel.Text = tostring(self.currency)
		
		-- Currency pop animation when increased
		if data.currency > oldCurrency then
			self:playCurrencyAnimation()
		end
	end
end

function CurrencyUI:playCurrencyAnimation()
	-- Scale up currency frame
	local originalSize = self.currencyFrame.Size
	
	local scaleUp = TweenService:Create(self.currencyFrame, TweenInfo.new(0.1), {
		Size = UDim2.new(0, 130, 0, 40)
	})
	scaleUp:Play()
	
	scaleUp.Completed:Connect(function()
		local scaleDown = TweenService:Create(self.currencyFrame, TweenInfo.new(0.1), {
			Size = originalSize
		})
		scaleDown:Play()
	end)
	
	-- Flash currency color
	self.currencyLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
	task.delay(0.2, function()
		local colorTween = TweenService:Create(self.currencyLabel, TweenInfo.new(0.2), {
			TextColor3 = Color3.fromRGB(255, 215, 0)
		})
		colorTween:Play()
	end)
end

return CurrencyUI
