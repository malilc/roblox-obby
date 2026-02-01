-- SummaryUI: แสดง Summary เมื่อจบเกม

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SummaryUI = {}
SummaryUI.__index = SummaryUI

-- Stage names for display
local STAGE_NAMES = {
	"Easy",
	"Moving",
	"Spinning",
	"Disappearing",
	"Hard",
}

function SummaryUI.new(parent: ScreenGui)
	local self = setmetatable({}, SummaryUI)
	
	self.parent = parent
	self.isVisible = false
	
	self:createUI()
	
	return self
end

-- Format time as MM:SS
local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%d:%02d", mins, secs)
end

function SummaryUI:createUI()
	-- Main Frame (centered popup)
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "SummaryFrame"
	mainFrame.Size = UDim2.new(0, 380, 0, 510)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
	mainFrame.BackgroundTransparency = 0.1
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.ZIndex = 50
	mainFrame.Parent = self.parent
	self.mainFrame = mainFrame
	
	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 20)
	mainCorner.Parent = mainFrame
	
	-- Gradient background
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 25, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 35))
	})
	gradient.Rotation = 135
	gradient.Parent = mainFrame
	
	-- Border glow
	local borderStroke = Instance.new("UIStroke")
	borderStroke.Color = Color3.fromRGB(255, 200, 50)
	borderStroke.Thickness = 3
	borderStroke.Transparency = 0.3
	borderStroke.Parent = mainFrame
	self.borderStroke = borderStroke
	
	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -40, 0, 36)
	titleLabel.Position = UDim2.new(0, 20, 0, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🏆 GAME COMPLETE!"
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.TextSize = 22
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextStrokeColor3 = Color3.fromRGB(100, 70, 0)
	titleLabel.TextStrokeTransparency = 0.5
	titleLabel.ZIndex = 51
	titleLabel.Parent = mainFrame
	self.titleLabel = titleLabel
	
	-- Stages Container (แสดง Stage ที่เล่น)
	local stagesContainer = Instance.new("Frame")
	stagesContainer.Name = "StagesContainer"
	stagesContainer.Size = UDim2.new(1, -40, 0, 60)
	stagesContainer.Position = UDim2.new(0, 20, 0, 46)
	stagesContainer.BackgroundColor3 = Color3.fromRGB(40, 35, 55)
	stagesContainer.BackgroundTransparency = 0.5
	stagesContainer.BorderSizePixel = 0
	stagesContainer.ZIndex = 51
	stagesContainer.Parent = mainFrame
	self.stagesContainer = stagesContainer
	
	local stagesCorner = Instance.new("UICorner")
	stagesCorner.CornerRadius = UDim.new(0, 10)
	stagesCorner.Parent = stagesContainer
	
	-- Stages header
	local stagesHeader = Instance.new("TextLabel")
	stagesHeader.Name = "Header"
	stagesHeader.Size = UDim2.new(1, 0, 0, 18)
	stagesHeader.Position = UDim2.new(0, 0, 0, 4)
	stagesHeader.BackgroundTransparency = 1
	stagesHeader.Text = "📋 Stages Played"
	stagesHeader.TextColor3 = Color3.fromRGB(180, 180, 200)
	stagesHeader.TextSize = 12
	stagesHeader.Font = Enum.Font.GothamBold
	stagesHeader.ZIndex = 52
	stagesHeader.Parent = stagesContainer
	
	-- Stages list container
	local stagesList = Instance.new("Frame")
	stagesList.Name = "StagesList"
	stagesList.Size = UDim2.new(1, -16, 0, 34)
	stagesList.Position = UDim2.new(0, 8, 0, 22)
	stagesList.BackgroundTransparency = 1
	stagesList.ZIndex = 52
	stagesList.Parent = stagesContainer
	self.stagesList = stagesList
	
	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = stagesList
	
	-- ==================== STATS SECTION ====================
	local statsContainer = Instance.new("Frame")
	statsContainer.Name = "StatsContainer"
	statsContainer.Size = UDim2.new(1, -40, 0, 70)
	statsContainer.Position = UDim2.new(0, 20, 0, 112)
	statsContainer.BackgroundColor3 = Color3.fromRGB(30, 40, 50)
	statsContainer.BackgroundTransparency = 0.5
	statsContainer.BorderSizePixel = 0
	statsContainer.ZIndex = 51
	statsContainer.Parent = mainFrame
	self.statsContainer = statsContainer
	
	local statsCorner = Instance.new("UICorner")
	statsCorner.CornerRadius = UDim.new(0, 10)
	statsCorner.Parent = statsContainer
	
	-- Stats header
	local statsHeader = Instance.new("TextLabel")
	statsHeader.Size = UDim2.new(1, 0, 0, 20)
	statsHeader.Position = UDim2.new(0, 0, 0, 4)
	statsHeader.BackgroundTransparency = 1
	statsHeader.Text = "📊 STATS"
	statsHeader.TextColor3 = Color3.fromRGB(100, 180, 255)
	statsHeader.TextSize = 12
	statsHeader.Font = Enum.Font.GothamBold
	statsHeader.ZIndex = 52
	statsHeader.Parent = statsContainer
	
	-- Stats rows
	self.statsRows = {}
	local statsConfig = {
		{name = "Score", icon = "⭐", key = "scoreEarned", color = Color3.fromRGB(100, 200, 255)},
		{name = "Time", icon = "⏱️", key = "timeSpent", color = Color3.fromRGB(200, 200, 200), isTime = true},
	}
	
	for i, config in ipairs(statsConfig) do
		local row = self:createSmallRow(config, i, statsContainer, 24)
		self.statsRows[config.key] = row
	end
	
	-- ==================== CURRENCY SECTION ====================
	local currencyContainer = Instance.new("Frame")
	currencyContainer.Name = "CurrencyContainer"
	currencyContainer.Size = UDim2.new(1, -40, 0, 205)
	currencyContainer.Position = UDim2.new(0, 20, 0, 188)
	currencyContainer.BackgroundColor3 = Color3.fromRGB(40, 35, 25)
	currencyContainer.BackgroundTransparency = 0.5
	currencyContainer.BorderSizePixel = 0
	currencyContainer.ZIndex = 51
	currencyContainer.Parent = mainFrame
	self.currencyContainer = currencyContainer
	
	local currencyCorner = Instance.new("UICorner")
	currencyCorner.CornerRadius = UDim.new(0, 10)
	currencyCorner.Parent = currencyContainer
	
	-- Currency header
	local currencyHeader = Instance.new("TextLabel")
	currencyHeader.Size = UDim2.new(1, 0, 0, 22)
	currencyHeader.Position = UDim2.new(0, 0, 0, 4)
	currencyHeader.BackgroundTransparency = 1
	currencyHeader.Text = "💰 CURRENCY EARNED"
	currencyHeader.TextColor3 = Color3.fromRGB(255, 215, 0)
	currencyHeader.TextSize = 13
	currencyHeader.Font = Enum.Font.GothamBold
	currencyHeader.ZIndex = 52
	currencyHeader.Parent = currencyContainer
	
	-- Currency rows (will be created dynamically with breakdown)
	self.currencyRows = {}
	
	-- Coins row
	local coinsRow = self:createCurrencyRow("coins", "💰 Coins", 1, currencyContainer, 28)
	self.currencyRows.coins = coinsRow
	
	-- Stage Clear row
	local stageRow = self:createCurrencyRow("stage", "🏁 Stage Clear", 2, currencyContainer, 28)
	self.currencyRows.stage = stageRow
	
	-- Stage Rewards row (NEW)
	local rewardsRow = self:createCurrencyRow("rewards", "🎯 Stage Rewards", 3, currencyContainer, 28)
	self.currencyRows.rewards = rewardsRow
	
	-- Finish Bonus row
	local finishRow = self:createCurrencyRow("finish", "🎁 Finish Bonus", 4, currencyContainer, 28)
	self.currencyRows.finish = finishRow
	
	-- Divider
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(1, -20, 0, 2)
	divider.Position = UDim2.new(0, 10, 0, 157)
	divider.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	divider.BackgroundTransparency = 0.5
	divider.BorderSizePixel = 0
	divider.ZIndex = 52
	divider.Parent = currencyContainer
	
	-- Total row
	local totalRow = Instance.new("Frame")
	totalRow.Name = "TotalRow"
	totalRow.Size = UDim2.new(1, -20, 0, 38)
	totalRow.Position = UDim2.new(0, 10, 0, 162)
	totalRow.BackgroundTransparency = 1
	totalRow.ZIndex = 52
	totalRow.Parent = currencyContainer
	
	local totalLabel = Instance.new("TextLabel")
	totalLabel.Size = UDim2.new(0.5, 0, 1, 0)
	totalLabel.Position = UDim2.new(0, 0, 0, 0)
	totalLabel.BackgroundTransparency = 1
	totalLabel.Text = "✨ TOTAL EARNED"
	totalLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	totalLabel.TextSize = 15
	totalLabel.Font = Enum.Font.GothamBlack
	totalLabel.TextXAlignment = Enum.TextXAlignment.Left
	totalLabel.ZIndex = 52
	totalLabel.Parent = totalRow
	
	local totalValue = Instance.new("TextLabel")
	totalValue.Name = "Value"
	totalValue.Size = UDim2.new(0.5, 0, 1, 0)
	totalValue.Position = UDim2.new(0.5, 0, 0, 0)
	totalValue.BackgroundTransparency = 1
	totalValue.Text = "+0"
	totalValue.TextColor3 = Color3.fromRGB(255, 215, 0)
	totalValue.TextSize = 20
	totalValue.Font = Enum.Font.GothamBlack
	totalValue.TextXAlignment = Enum.TextXAlignment.Right
	totalValue.ZIndex = 52
	totalValue.Parent = totalRow
	self.totalValueLabel = totalValue
	
	-- OK Button
	local okButton = Instance.new("TextButton")
	okButton.Name = "OKButton"
	okButton.Size = UDim2.new(0, 120, 0, 42)
	okButton.Position = UDim2.new(0.5, -60, 0, 455)
	okButton.BackgroundColor3 = Color3.fromRGB(50, 180, 100)
	okButton.BorderSizePixel = 0
	okButton.Text = "OK"
	okButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	okButton.TextSize = 18
	okButton.Font = Enum.Font.GothamBold
	okButton.ZIndex = 51
	okButton.Parent = mainFrame
	self.okButton = okButton
	
	local okCorner = Instance.new("UICorner")
	okCorner.CornerRadius = UDim.new(0, 12)
	okCorner.Parent = okButton
	
	-- OK Button gradient
	local okGradient = Instance.new("UIGradient")
	okGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 220, 130)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 180, 100))
	})
	okGradient.Rotation = 90
	okGradient.Parent = okButton
	
	-- OK Button stroke
	local okStroke = Instance.new("UIStroke")
	okStroke.Color = Color3.fromRGB(100, 255, 150)
	okStroke.Thickness = 2
	okStroke.Transparency = 0.5
	okStroke.Parent = okButton
	
	-- Button click
	okButton.MouseButton1Click:Connect(function()
		self:hide()
	end)
	
	-- Hover effects
	okButton.MouseEnter:Connect(function()
		TweenService:Create(okButton, TweenInfo.new(0.2), {
			Size = UDim2.new(0, 130, 0, 46)
		}):Play()
	end)
	
	okButton.MouseLeave:Connect(function()
		TweenService:Create(okButton, TweenInfo.new(0.2), {
			Size = UDim2.new(0, 120, 0, 42)
		}):Play()
	end)
end

function SummaryUI:createSmallRow(config: {name: string, icon: string, key: string, color: Color3, isTime: boolean?}, index: number, parent: Frame, startY: number): Frame
	local row = Instance.new("Frame")
	row.Name = config.key .. "Row"
	row.Size = UDim2.new(1, -20, 0, 22)
	row.Position = UDim2.new(0, 10, 0, startY + (index - 1) * 22)
	row.BackgroundTransparency = 1
	row.ZIndex = 52
	row.Parent = parent
	
	-- Icon + Label
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(0.6, 0, 1, 0)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = config.icon .. " " .. config.name
	label.TextColor3 = Color3.fromRGB(180, 180, 200)
	label.TextSize = 13
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 52
	label.Parent = row
	
	-- Value
	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.Size = UDim2.new(0.4, 0, 1, 0)
	value.Position = UDim2.new(0.6, 0, 0, 0)
	value.BackgroundTransparency = 1
	value.Text = "0"
	value.TextColor3 = config.color
	value.TextSize = 14
	value.Font = Enum.Font.GothamBold
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.ZIndex = 52
	value.Parent = row
	
	-- Store config
	row:SetAttribute("isTime", config.isTime or false)
	
	return row
end

function SummaryUI:createCurrencyRow(key: string, labelText: string, index: number, parent: Frame, startY: number): Frame
	local row = Instance.new("Frame")
	row.Name = key .. "Row"
	row.Size = UDim2.new(1, -20, 0, 30)
	row.Position = UDim2.new(0, 10, 0, startY + (index - 1) * 32)
	row.BackgroundTransparency = 1
	row.ZIndex = 52
	row.Parent = parent
	
	-- Label (e.g., "💰 Coins")
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(0.45, 0, 1, 0)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(200, 200, 220)
	label.TextSize = 13
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 52
	label.Parent = row
	
	-- Breakdown (e.g., "(3 x 1)")
	local breakdown = Instance.new("TextLabel")
	breakdown.Name = "Breakdown"
	breakdown.Size = UDim2.new(0.25, 0, 1, 0)
	breakdown.Position = UDim2.new(0.45, 0, 0, 0)
	breakdown.BackgroundTransparency = 1
	breakdown.Text = ""
	breakdown.TextColor3 = Color3.fromRGB(150, 150, 170)
	breakdown.TextSize = 11
	breakdown.Font = Enum.Font.Gotham
	breakdown.TextXAlignment = Enum.TextXAlignment.Center
	breakdown.ZIndex = 52
	breakdown.Parent = row
	
	-- Value (e.g., "+3")
	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.Size = UDim2.new(0.3, 0, 1, 0)
	value.Position = UDim2.new(0.7, 0, 0, 0)
	value.BackgroundTransparency = 1
	value.Text = "+0"
	value.TextColor3 = Color3.fromRGB(255, 215, 0)
	value.TextSize = 15
	value.Font = Enum.Font.GothamBold
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.ZIndex = 52
	value.Parent = row
	
	return row
end

function SummaryUI:createStageTag(stageNum: number, index: number): Frame
	local stageReward = Config.Currency.StageRewards[stageNum] or 0
	
	local tag = Instance.new("Frame")
	tag.Name = "Stage" .. stageNum
	tag.Size = UDim2.new(0, 52, 0, 32)
	tag.BackgroundColor3 = Color3.fromRGB(50, 45, 70)
	tag.BorderSizePixel = 0
	tag.ZIndex = 53
	
	local tagCorner = Instance.new("UICorner")
	tagCorner.CornerRadius = UDim.new(0, 6)
	tagCorner.Parent = tag
	
	-- Stage number
	local stageLabel = Instance.new("TextLabel")
	stageLabel.Size = UDim2.new(1, 0, 0, 16)
	stageLabel.Position = UDim2.new(0, 0, 0, 1)
	stageLabel.BackgroundTransparency = 1
	stageLabel.Text = "S" .. stageNum
	stageLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
	stageLabel.TextSize = 11
	stageLabel.Font = Enum.Font.GothamBold
	stageLabel.ZIndex = 54
	stageLabel.Parent = tag
	
	-- Stage reward
	local coinLabel = Instance.new("TextLabel")
	coinLabel.Size = UDim2.new(1, 0, 0, 14)
	coinLabel.Position = UDim2.new(0, 0, 0, 16)
	coinLabel.BackgroundTransparency = 1
	coinLabel.Text = "💰+" .. stageReward
	coinLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	coinLabel.TextSize = 10
	coinLabel.Font = Enum.Font.GothamBold
	coinLabel.ZIndex = 54
	coinLabel.Parent = tag
	
	-- Start hidden for animation
	tag.BackgroundTransparency = 1
	stageLabel.TextTransparency = 1
	coinLabel.TextTransparency = 1
	
	return tag
end

function SummaryUI:show(data: {scoreEarned: number, timeSpent: number, coinsCollected: number, coinValue: number, stagesCleared: number, stageValue: number, finishBonus: number, totalCurrency: number, stageOrder: {number}?})
	if self.isVisible then return end
	self.isVisible = true
	
	-- Clear previous stage tags
	for _, child in ipairs(self.stagesList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	-- Create stage tags
	local stageOrder = data.stageOrder or {}
	for i, stageNum in ipairs(stageOrder) do
		local tag = self:createStageTag(stageNum, i)
		tag.Parent = self.stagesList
	end
	
	-- Reset and show frame
	self.mainFrame.Size = UDim2.new(0, 0, 0, 0)
	self.mainFrame.Visible = true
	
	-- Scale in animation
	local scaleIn = TweenService:Create(self.mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 380, 0, 510)
	})
	scaleIn:Play()
	
	-- Animate border glow
	task.spawn(function()
		while self.isVisible do
			local glowUp = TweenService:Create(self.borderStroke, TweenInfo.new(0.5), {
				Transparency = 0.1
			})
			glowUp:Play()
			glowUp.Completed:Wait()
			
			local glowDown = TweenService:Create(self.borderStroke, TweenInfo.new(0.5), {
				Transparency = 0.4
			})
			glowDown:Play()
			glowDown.Completed:Wait()
		end
	end)
	
	-- Animate stage tags
	task.delay(0.3, function()
		self:animateStageTags()
	end)
	
	-- Animate stats section
	task.delay(0.5, function()
		self:animateStats(data)
	end)
	
	-- Animate currency section
	task.delay(0.8, function()
		self:animateCurrency(data)
	end)
end

function SummaryUI:animateStageTags()
	local tags = {}
	for _, child in ipairs(self.stagesList:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(tags, child)
		end
	end
	
	for i, tag in ipairs(tags) do
		task.delay((i - 1) * 0.08, function()
			-- Fade in
			TweenService:Create(tag, TweenInfo.new(0.2), {
				BackgroundTransparency = 0
			}):Play()
			
			for _, label in ipairs(tag:GetChildren()) do
				if label:IsA("TextLabel") then
					TweenService:Create(label, TweenInfo.new(0.2), {
						TextTransparency = 0
					}):Play()
				end
			end
			
			-- Pop animation
			tag.Size = UDim2.new(0, 44, 0, 28)
			TweenService:Create(tag, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
				Size = UDim2.new(0, 52, 0, 32)
			}):Play()
		end)
	end
end

function SummaryUI:animateStats(data: {scoreEarned: number, timeSpent: number})
	-- Score
	task.delay(0, function()
		local row = self.statsRows.scoreEarned
		if row then
			local valueLabel = row:FindFirstChild("Value")
			if valueLabel then
				valueLabel.Text = tostring(data.scoreEarned or 0)
				valueLabel.TextSize = 10
				TweenService:Create(valueLabel, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
					TextSize = 14
				}):Play()
			end
		end
	end)
	
	-- Time
	task.delay(0.1, function()
		local row = self.statsRows.timeSpent
		if row then
			local valueLabel = row:FindFirstChild("Value")
			if valueLabel then
				valueLabel.Text = formatTime(data.timeSpent or 0)
				valueLabel.TextSize = 10
				TweenService:Create(valueLabel, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
					TextSize = 14
				}):Play()
			end
		end
	end)
end

function SummaryUI:animateCurrency(data: {coinsCollected: number, coinValue: number, stagesCleared: number, stageValue: number, stageRewardsTotal: number, finishBonus: number})
	local coinsCollected = data.coinsCollected or 0
	local coinValue = data.coinValue or 1
	local stagesCleared = data.stagesCleared or 0
	local stageValue = data.stageValue or 5
	local stageRewardsTotal = data.stageRewardsTotal or 0
	local finishBonus = data.finishBonus or 25
	
	-- Calculate totals
	local coinsTotal = coinsCollected * coinValue
	local stageTotal = stagesCleared * stageValue
	local grandTotal = coinsTotal + stageTotal + stageRewardsTotal + finishBonus
	
	-- Animate Coins row
	task.delay(0, function()
		local row = self.currencyRows.coins
		local breakdown = row:FindFirstChild("Breakdown")
		local value = row:FindFirstChild("Value")
		
		if breakdown and value then
			breakdown.Text = "(" .. coinsCollected .. " x " .. coinValue .. ")"
			value.Text = "+" .. coinsTotal
			
			value.TextSize = 11
			TweenService:Create(value, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
				TextSize = 15
			}):Play()
		end
	end)
	
	-- Animate Stage Clear row
	task.delay(0.1, function()
		local row = self.currencyRows.stage
		local breakdown = row:FindFirstChild("Breakdown")
		local value = row:FindFirstChild("Value")
		
		if breakdown and value then
			breakdown.Text = "(" .. stagesCleared .. " x " .. stageValue .. ")"
			value.Text = "+" .. stageTotal
			
			value.TextSize = 11
			TweenService:Create(value, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
				TextSize = 15
			}):Play()
		end
	end)
	
	-- Animate Stage Rewards row
	task.delay(0.2, function()
		local row = self.currencyRows.rewards
		local breakdown = row:FindFirstChild("Breakdown")
		local value = row:FindFirstChild("Value")
		
		if breakdown and value then
			breakdown.Text = ""
			value.Text = "+" .. stageRewardsTotal
			value.TextColor3 = Color3.fromRGB(150, 200, 255)
			
			value.TextSize = 11
			TweenService:Create(value, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
				TextSize = 15
			}):Play()
		end
	end)
	
	-- Animate Finish Bonus row
	task.delay(0.3, function()
		local row = self.currencyRows.finish
		local breakdown = row:FindFirstChild("Breakdown")
		local value = row:FindFirstChild("Value")
		
		if breakdown and value then
			breakdown.Text = ""
			value.Text = "+" .. finishBonus
			
			value.TextSize = 11
			TweenService:Create(value, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
				TextSize = 15
			}):Play()
		end
	end)
	
	-- Animate Total
	task.delay(0.45, function()
		self.totalValueLabel.Text = "+" .. grandTotal
		
		-- Flash animation
		self.totalValueLabel.TextColor3 = Color3.fromRGB(255, 255, 150)
		self.totalValueLabel.TextSize = 16
		
		TweenService:Create(self.totalValueLabel, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
			TextSize = 20,
			TextColor3 = Color3.fromRGB(255, 215, 0)
		}):Play()
	end)
end

function SummaryUI:hide()
	if not self.isVisible then return end
	self.isVisible = false
	
	-- Scale out animation
	local scaleOut = TweenService:Create(self.mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0)
	})
	scaleOut:Play()
	
	scaleOut.Completed:Connect(function()
		self.mainFrame.Visible = false
	end)
end

return SummaryUI
