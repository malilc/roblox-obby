-- StageSelectionUI: GUI สำหรับเลือกลำดับด่าน (Modern Design)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local StageSelectionUI = {}
StageSelectionUI.__index = StageSelectionUI

function StageSelectionUI.new(parent: ScreenGui)
	local self = setmetatable({}, StageSelectionUI)
	self.parent = parent
	self.selectedStages = {} :: {number}
	self.isVisible = false
	self.isVotingMode = false  -- Flag for multiplayer voting mode
	self.currentVotes = {}     -- Store votes from other players
	
	-- Remotes
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	self.showRemote = remotes:WaitForChild("ShowStageSelection")
	self.hideRemote = remotes:WaitForChild("HideStageSelection")
	self.confirmRemote = remotes:WaitForChild("ConfirmStageSelection")
	self.countdownRemote = remotes:WaitForChild("CountdownUpdate")
	
	-- Stage voting remotes
	self.voteStagesRemote = remotes:WaitForChild("VoteStages")
	self.stageVoteUpdateRemote = remotes:WaitForChild("StageVoteUpdate")
	
	-- Create UI
	self:createUI()
	
	-- Setup remote listeners
	self:setupRemotes()
	
	return self
end

-- Helper function to create gradient
local function createGradient(parent: GuiObject, color1: Color3, color2: Color3)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color1),
		ColorSequenceKeypoint.new(1, color2)
	})
	gradient.Rotation = 45
	gradient.Parent = parent
	return gradient
end

function StageSelectionUI:createUI()
	-- Background Blur (optional - can be added if needed)
	
	-- Main Frame with modern design
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "StageSelectionFrame"
	mainFrame.Size = UDim2.new(0, 580, 0, 480)
	mainFrame.Position = UDim2.new(0.5, -290, 0.5, -240)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	mainFrame.BackgroundTransparency = 0.15
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = self.parent
	self.mainFrame = mainFrame
	
	-- Add gradient background
	createGradient(mainFrame, Color3.fromRGB(20, 20, 30), Color3.fromRGB(30, 25, 40))
	
	-- Add border glow
	local borderStroke = Instance.new("UIStroke")
	borderStroke.Color = Color3.fromRGB(100, 150, 255)
	borderStroke.Thickness = 2
	borderStroke.Transparency = 0.5
	borderStroke.Parent = mainFrame
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = mainFrame
	
	-- Shadow effect (using another frame)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 4, 1, 4)
	shadow.Position = UDim2.new(0, -2, 0, -2)
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 0.7
	shadow.BorderSizePixel = 0
	shadow.ZIndex = mainFrame.ZIndex - 1
	shadow.Parent = mainFrame
	
	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 16)
	shadowCorner.Parent = shadow
	
	-- Title with gradient text effect
	local titleContainer = Instance.new("Frame")
	titleContainer.Name = "TitleContainer"
	titleContainer.Size = UDim2.new(1, -40, 0, 70)
	titleContainer.Position = UDim2.new(0, 20, 0, 20)
	titleContainer.BackgroundTransparency = 1
	titleContainer.Parent = mainFrame
	
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 1, 0)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "🎮 SELECT STAGE ORDER"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 28
	title.Font = Enum.Font.GothamBold
	title.TextStrokeTransparency = 0.8
	title.TextStrokeColor3 = Color3.fromRGB(100, 150, 255)
	title.Parent = titleContainer
	
	-- Subtitle
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, 0, 0, 20)
	subtitle.Position = UDim2.new(0, 0, 0, 50)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Click stages to build your custom order"
	subtitle.TextColor3 = Color3.fromRGB(180, 180, 200)
	subtitle.TextSize = 14
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextTransparency = 0.3
	subtitle.Parent = titleContainer
	
	-- Stage Buttons Container
	local buttonsContainer = Instance.new("Frame")
	buttonsContainer.Name = "ButtonsContainer"
	buttonsContainer.Size = UDim2.new(1, -40, 0, 240)
	buttonsContainer.Position = UDim2.new(0, 20, 0, 100)
	buttonsContainer.BackgroundTransparency = 1
	buttonsContainer.Parent = mainFrame
	self.buttonsContainer = buttonsContainer
	
	-- Stage buttons with modern design
	local stageNames = {
		"Jump",
		"Moving",
		"Spin",
		"Disappear",
		"Combo"
	}
	
	local stageIcons = {
		"🦘",
		"↔️",
		"🌀",
		"💨",
		"⚡"
	}
	
	local stageColors = {
		Color3.fromRGB(76, 175, 80),   -- Green
		Color3.fromRGB(255, 152, 0),   -- Orange
		Color3.fromRGB(156, 39, 176),  -- Purple
		Color3.fromRGB(233, 30, 99),   -- Pink
		Color3.fromRGB(244, 67, 54)    -- Red
	}
	
	local stageGradients = {
		{Color3.fromRGB(76, 175, 80), Color3.fromRGB(129, 199, 132)},
		{Color3.fromRGB(255, 152, 0), Color3.fromRGB(255, 183, 77)},
		{Color3.fromRGB(156, 39, 176), Color3.fromRGB(186, 104, 200)},
		{Color3.fromRGB(233, 30, 99), Color3.fromRGB(240, 98, 146)},
		{Color3.fromRGB(244, 67, 54), Color3.fromRGB(239, 154, 154)}
	}
	
	self.stageButtons = {}
	
	for i = 1, 5 do
		local buttonContainer = Instance.new("Frame")
		buttonContainer.Name = "Stage" .. i .. "Container"
		buttonContainer.Size = UDim2.new(0, 100, 0, 105)
		buttonContainer.Position = UDim2.new(0, ((i - 1) % 3) * 120, 0, math.floor((i - 1) / 3) * 125)
		buttonContainer.BackgroundTransparency = 1
		buttonContainer.Parent = buttonsContainer
		
		local button = Instance.new("TextButton")
		button.Name = "Stage" .. i .. "Button"
		button.Size = UDim2.new(1, 0, 1, 0)
		button.Position = UDim2.new(0, 0, 0, 0)
		button.BackgroundColor3 = stageColors[i]
		button.BackgroundTransparency = 0.2
		button.BorderSizePixel = 0
		button.Text = ""
		button.Parent = buttonContainer
		
		-- Add gradient
		createGradient(button, stageGradients[i][1], stageGradients[i][2])
		
		-- Add border
		local buttonStroke = Instance.new("UIStroke")
		buttonStroke.Color = stageColors[i]
		buttonStroke.Thickness = 2
		buttonStroke.Transparency = 0.6
		buttonStroke.Parent = button
		
		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 12)
		btnCorner.Parent = button
		
		-- Icon
		local icon = Instance.new("TextLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.new(1, 0, 0, 40)
		icon.Position = UDim2.new(0, 0, 0, 10)
		icon.BackgroundTransparency = 1
		icon.Text = stageIcons[i]
		icon.TextSize = 32
		icon.Font = Enum.Font.GothamBold
		icon.TextColor3 = Color3.fromRGB(255, 255, 255)
		icon.Parent = button
		
		-- Stage number
		local numberLabel = Instance.new("TextLabel")
		numberLabel.Name = "Number"
		numberLabel.Size = UDim2.new(1, 0, 0, 20)
		numberLabel.Position = UDim2.new(0, 0, 0, 50)
		numberLabel.BackgroundTransparency = 1
		numberLabel.Text = "[" .. i .. "]"
		numberLabel.TextSize = 16
		numberLabel.Font = Enum.Font.GothamBold
		numberLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		numberLabel.TextStrokeTransparency = 0.5
		numberLabel.Parent = button
		
		-- Stage name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.Size = UDim2.new(1, 0, 0, 16)
		nameLabel.Position = UDim2.new(0, 0, 0, 68)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = stageNames[i]
		nameLabel.TextSize = 11
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLabel.TextStrokeTransparency = 0.7
		nameLabel.Parent = button
		
		-- Stage Reward indicator (แสดงรางวัลเมื่อผ่านด่าน)
		local stageReward = Config.Currency.StageRewards[i] or 0
		local coinLabel = Instance.new("TextLabel")
		coinLabel.Name = "CoinLabel"
		coinLabel.Size = UDim2.new(1, 0, 0, 14)
		coinLabel.Position = UDim2.new(0, 0, 0, 84)
		coinLabel.BackgroundTransparency = 1
		coinLabel.Text = "💰 +" .. stageReward
		coinLabel.TextSize = 10
		coinLabel.Font = Enum.Font.GothamBold
		coinLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		coinLabel.TextStrokeTransparency = 0.5
		coinLabel.TextStrokeColor3 = Color3.fromRGB(100, 70, 0)
		coinLabel.Parent = button
		
		-- Selected indicator
		local selectedIndicator = Instance.new("Frame")
		selectedIndicator.Name = "SelectedIndicator"
		selectedIndicator.Size = UDim2.new(1, -4, 1, -4)
		selectedIndicator.Position = UDim2.new(0, 2, 0, 2)
		selectedIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		selectedIndicator.BackgroundTransparency = 0.8
		selectedIndicator.BorderSizePixel = 0
		selectedIndicator.Visible = false
		selectedIndicator.Parent = button
		
		local indicatorCorner = Instance.new("UICorner")
		indicatorCorner.CornerRadius = UDim.new(0, 10)
		indicatorCorner.Parent = selectedIndicator
		
		-- Hover effect
		button.MouseEnter:Connect(function()
			if not table.find(self.selectedStages, i) then
				local hoverTween = TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
					BackgroundTransparency = 0.1,
					Size = UDim2.new(1.1, 0, 1.1, 0),
					Position = UDim2.new(-0.05, 0, -0.05, 0)
				})
				hoverTween:Play()
			end
		end)
		
		button.MouseLeave:Connect(function()
			if not table.find(self.selectedStages, i) then
				local leaveTween = TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
					BackgroundTransparency = 0.2,
					Size = UDim2.new(1, 0, 1, 0),
					Position = UDim2.new(0, 0, 0, 0)
				})
				leaveTween:Play()
			end
		end)
		
		-- Click handler
		button.MouseButton1Click:Connect(function()
			self:toggleStage(i)
		end)
		
		self.stageButtons[i] = {
			button = button,
			container = buttonContainer,
			indicator = selectedIndicator,
			stroke = buttonStroke
		}
	end
	
	-- Selected Order Display with modern design
	local selectedContainer = Instance.new("Frame")
	selectedContainer.Name = "SelectedContainer"
	selectedContainer.Size = UDim2.new(1, -40, 0, 50)
	selectedContainer.Position = UDim2.new(0, 20, 0, 350)
	selectedContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	selectedContainer.BackgroundTransparency = 0.5
	selectedContainer.BorderSizePixel = 0
	selectedContainer.Parent = mainFrame
	
	local selectedCorner = Instance.new("UICorner")
	selectedCorner.CornerRadius = UDim.new(0, 8)
	selectedCorner.Parent = selectedContainer
	
	local selectedLabel = Instance.new("TextLabel")
	selectedLabel.Name = "SelectedLabel"
	selectedLabel.Size = UDim2.new(1, -20, 1, 0)
	selectedLabel.Position = UDim2.new(0, 10, 0, 0)
	selectedLabel.BackgroundTransparency = 1
	selectedLabel.Text = "✨ Selected: (none)"
	selectedLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
	selectedLabel.TextSize = 16
	selectedLabel.Font = Enum.Font.Gotham
	selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
	selectedLabel.Parent = selectedContainer
	self.selectedLabel = selectedLabel
	
	-- Clear Button (modern design)
	local clearButton = Instance.new("TextButton")
	clearButton.Name = "ClearButton"
	clearButton.Size = UDim2.new(0, 110, 0, 35)
	clearButton.Position = UDim2.new(1, -130, 0, 355)
	clearButton.BackgroundColor3 = Color3.fromRGB(120, 120, 140)
	clearButton.BorderSizePixel = 0
	clearButton.Text = "🗑️ Clear"
	clearButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	clearButton.TextSize = 14
	clearButton.Font = Enum.Font.GothamBold
	clearButton.Parent = mainFrame
	
	local clearCorner = Instance.new("UICorner")
	clearCorner.CornerRadius = UDim.new(0, 8)
	clearCorner.Parent = clearButton
	
	local clearStroke = Instance.new("UIStroke")
	clearStroke.Color = Color3.fromRGB(150, 150, 170)
	clearStroke.Thickness = 1
	clearStroke.Transparency = 0.5
	clearStroke.Parent = clearButton
	
	clearButton.MouseButton1Click:Connect(function()
		self:clearSelection()
	end)
	
	-- Random Button (modern gradient design)
	local randomButton = Instance.new("TextButton")
	randomButton.Name = "RandomButton"
	randomButton.Size = UDim2.new(0, 170, 0, 50)
	randomButton.Position = UDim2.new(0, 20, 0, 410)
	randomButton.BackgroundColor3 = Color3.fromRGB(138, 43, 226) -- สีม่วงเข้ม
	randomButton.BackgroundTransparency = 0
	randomButton.BorderSizePixel = 0
	randomButton.Text = "🎲 RANDOM"
	randomButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	randomButton.TextSize = 20
	randomButton.Font = Enum.Font.GothamBold
	randomButton.TextStrokeTransparency = 0.3
	randomButton.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	randomButton.ZIndex = 10
	randomButton.Parent = mainFrame
	
	-- สร้าง gradient โดยใช้ UIGradient ตรงๆ บน button
	local randomGradient = createGradient(randomButton, Color3.fromRGB(138, 43, 226), Color3.fromRGB(186, 85, 211))
	self.randomGradient = randomGradient
	
	local randomCorner = Instance.new("UICorner")
	randomCorner.CornerRadius = UDim.new(0, 10)
	randomCorner.Parent = randomButton
	
	local randomStroke = Instance.new("UIStroke")
	randomStroke.Color = Color3.fromRGB(221, 160, 221)
	randomStroke.Thickness = 2
	randomStroke.Transparency = 0.2
	randomStroke.Parent = randomButton
	
	randomButton.MouseButton1Click:Connect(function()
		self:confirmSelection(true)
	end)
	
	-- Start Button (modern gradient design)
	local startButton = Instance.new("TextButton")
	startButton.Name = "StartButton"
	startButton.Size = UDim2.new(0, 170, 0, 50)
	startButton.Position = UDim2.new(1, -190, 0, 410)
	startButton.BackgroundColor3 = Color3.fromRGB(34, 139, 34) -- สีเขียวเข้ม
	startButton.BackgroundTransparency = 0
	startButton.BorderSizePixel = 0
	startButton.Text = "🚀 START"
	startButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	startButton.TextSize = 20
	startButton.Font = Enum.Font.GothamBold
	startButton.TextStrokeTransparency = 0.3
	startButton.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	startButton.ZIndex = 10
	startButton.Parent = mainFrame
	self.startButton = startButton
	
	-- สร้าง gradient โดยใช้ UIGradient ตรงๆ บน button
	local startGradient = createGradient(startButton, Color3.fromRGB(50, 205, 50), Color3.fromRGB(34, 139, 34))
	self.startGradient = startGradient
	
	local startCorner = Instance.new("UICorner")
	startCorner.CornerRadius = UDim.new(0, 10)
	startCorner.Parent = startButton
	
	local startStroke = Instance.new("UIStroke")
	startStroke.Color = Color3.fromRGB(144, 238, 144)
	startStroke.Thickness = 2
	startStroke.Transparency = 0.2
	startStroke.Parent = startButton
	self.startStroke = startStroke
	
	-- เริ่มต้น disable ปุ่ม Start
	startButton.Active = false
	startButton.BackgroundTransparency = 0.6
	startButton.TextTransparency = 0.6
	if startStroke then
		startStroke.Transparency = 0.8
	end
	
	startButton.MouseButton1Click:Connect(function()
		if startButton.Active then
			self:confirmSelection(false)
		end
	end)
	
	-- Countdown Frame (modern design) - อยู่ตรงกลางหน้าจอ
	local countdownFrame = Instance.new("Frame")
	countdownFrame.Name = "CountdownFrame"
	countdownFrame.Size = UDim2.new(0, 350, 0, 250)
	countdownFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	countdownFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	countdownFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	countdownFrame.BackgroundTransparency = 0.4
	countdownFrame.BorderSizePixel = 0
	countdownFrame.Visible = false
	countdownFrame.ZIndex = 100 -- ให้อยู่ด้านบนสุด
	countdownFrame.Parent = self.parent
	self.countdownFrame = countdownFrame
	
	createGradient(countdownFrame, Color3.fromRGB(20, 20, 40), Color3.fromRGB(40, 20, 60))
	
	local countdownCorner = Instance.new("UICorner")
	countdownCorner.CornerRadius = UDim.new(0, 16)
	countdownCorner.Parent = countdownFrame
	
	local countdownStroke = Instance.new("UIStroke")
	countdownStroke.Color = Color3.fromRGB(100, 200, 255)
	countdownStroke.Thickness = 3
	countdownStroke.Transparency = 0.3
	countdownStroke.Parent = countdownFrame
	
	local countdownNumber = Instance.new("TextLabel")
	countdownNumber.Name = "CountdownNumber"
	countdownNumber.Size = UDim2.new(1, 0, 0, 150)
	countdownNumber.AnchorPoint = Vector2.new(0.5, 0)
	countdownNumber.Position = UDim2.new(0.5, 0, 0, 20)
	countdownNumber.BackgroundTransparency = 1
	countdownNumber.Text = "3"
	countdownNumber.TextColor3 = Color3.fromRGB(255, 255, 255)
	countdownNumber.TextSize = 120
	countdownNumber.Font = Enum.Font.GothamBold
	countdownNumber.TextStrokeTransparency = 0 -- stroke ชัดเต็มที่
	countdownNumber.TextStrokeColor3 = Color3.fromRGB(0, 0, 0) -- สีดำให้ตัดกับตัวอักษร
	countdownNumber.TextXAlignment = Enum.TextXAlignment.Center
	countdownNumber.ZIndex = 101
	countdownNumber.Parent = countdownFrame
	self.countdownNumber = countdownNumber
	
	local countdownMessage = Instance.new("TextLabel")
	countdownMessage.Name = "CountdownMessage"
	countdownMessage.Size = UDim2.new(1, 0, 0, 60)
	countdownMessage.AnchorPoint = Vector2.new(0.5, 0)
	countdownMessage.Position = UDim2.new(0.5, 0, 0, 170)
	countdownMessage.BackgroundTransparency = 1
	countdownMessage.Text = "Starting..."
	countdownMessage.TextColor3 = Color3.fromRGB(255, 255, 255)
	countdownMessage.TextSize = 24
	countdownMessage.Font = Enum.Font.GothamBold
	countdownMessage.TextStrokeTransparency = 0
	countdownMessage.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	countdownMessage.TextXAlignment = Enum.TextXAlignment.Center
	countdownMessage.ZIndex = 101
	countdownMessage.Parent = countdownFrame
	self.countdownMessage = countdownMessage
end

function StageSelectionUI:setupRemotes()
	self.showRemote.OnClientEvent:Connect(function()
		self:show()
	end)
	
	self.hideRemote.OnClientEvent:Connect(function()
		self:hide()
	end)
	
	self.countdownRemote.OnClientEvent:Connect(function(data)
		self:updateCountdown(data)
	end)
	
	-- Stage voting update
	self.stageVoteUpdateRemote.OnClientEvent:Connect(function(data)
		self:onStageVoteUpdate(data)
	end)
end

-- Handle stage vote update from server
function StageSelectionUI:onStageVoteUpdate(data)
	if data.type == "voteUpdate" then
		self.currentVotes = data.votes
		self:updateVotesDisplay()
	end
end

-- Update votes display (show other players' votes)
function StageSelectionUI:updateVotesDisplay()
	-- For now, just update the subtitle to show vote count
	-- In a full implementation, you'd show each player's vote
	local subtitle = self.mainFrame:FindFirstChild("TitleContainer")
	if subtitle then
		local subtitleLabel = subtitle:FindFirstChild("Subtitle")
		if subtitleLabel then
			-- This would be enhanced to show actual votes
			-- For now, just indicate voting is happening
		end
	end
end

function StageSelectionUI:show()
	if self.isVisible then return end
	self.isVisible = true
	
	-- Reset state
	self.mainFrame.Size = UDim2.new(0, 580, 0, 480)
	self.mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	self.mainFrame.Visible = true
	
	-- Fade in จากโปร่งใส
	for _, child in ipairs(self.mainFrame:GetDescendants()) do
		if child:IsA("GuiObject") then
			child.Visible = true
		end
	end
	
	-- Simple fade in
	self.mainFrame.BackgroundTransparency = 1
	local fadeIn = TweenService:Create(self.mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.15
	})
	fadeIn:Play()
end

function StageSelectionUI:hide()
	if not self.isVisible then return end
	self.isVisible = false
	
	-- Simple fade out
	local fadeOut = TweenService:Create(self.mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1
	})
	fadeOut:Play()
	fadeOut.Completed:Connect(function()
		self.mainFrame.Visible = false
	end)
end

function StageSelectionUI:toggleStage(stageNum: number)
	local index = table.find(self.selectedStages, stageNum)
	local buttonData = self.stageButtons[stageNum]
	if not buttonData then return end
	
	if index then
		-- Remove from selection
		table.remove(self.selectedStages, index)
		self:updateButtonState(stageNum, false)
	else
		-- Add to selection
		table.insert(self.selectedStages, stageNum)
		self:updateButtonState(stageNum, true)
		
		-- Pulse animation
		local pulse = TweenService:Create(buttonData.button, TweenInfo.new(0.2, Enum.EasingStyle.Elastic), {
			Size = UDim2.new(1.15, 0, 1.15, 0),
			Position = UDim2.new(-0.075, 0, -0.075, 0)
		})
		pulse:Play()
		pulse.Completed:Connect(function()
			local returnTween = TweenService:Create(buttonData.button, TweenInfo.new(0.2), {
				Size = UDim2.new(1, 0, 1, 0),
				Position = UDim2.new(0, 0, 0, 0)
			})
			returnTween:Play()
		end)
	end
	
	self:updateSelectedLabel()
end

function StageSelectionUI:updateButtonState(stageNum: number, isSelected: boolean)
	local buttonData = self.stageButtons[stageNum]
	if not buttonData then return end
	
	if isSelected then
		buttonData.button.BackgroundTransparency = 0
		buttonData.indicator.Visible = true
		buttonData.stroke.Thickness = 3
		buttonData.stroke.Transparency = 0.2
		
		-- Glow effect
		local glowTween = TweenService:Create(buttonData.stroke, TweenInfo.new(0.3), {
			Thickness = 4,
			Transparency = 0
		})
		glowTween:Play()
	else
		buttonData.button.BackgroundTransparency = 0.2
		buttonData.indicator.Visible = false
		buttonData.stroke.Thickness = 2
		buttonData.stroke.Transparency = 0.6
	end
	
	-- อัพเดทสถานะปุ่ม Start
	self:updateStartButtonState()
end

function StageSelectionUI:updateSelectedLabel()
	if #self.selectedStages == 0 then
		self.selectedLabel.Text = "✨ Selected: (none)"
	else
		local orderText = table.concat(self.selectedStages, " → ")
		
		-- คำนวณ total rewards
		local totalRewards = 0
		for _, stageNum in ipairs(self.selectedStages) do
			totalRewards = totalRewards + (Config.Currency.StageRewards[stageNum] or 0)
		end
		
		self.selectedLabel.Text = "✨ " .. orderText .. "  |  💰 +" .. totalRewards .. " rewards"
	end
	
	-- อัพเดทสถานะปุ่ม Start
	self:updateStartButtonState()
end

function StageSelectionUI:updateStartButtonState()
	if not self.startButton then return end
	
	local hasSelection = #self.selectedStages > 0
	
	if hasSelection then
		-- Enable ปุ่ม Start
		self.startButton.Active = true
		
		-- Animation - enable button
		local enableTween = TweenService:Create(self.startButton, TweenInfo.new(0.2), {
			BackgroundTransparency = 0,
			TextTransparency = 0
		})
		enableTween:Play()
		
		-- Enable stroke
		if self.startStroke then
			local strokeTween = TweenService:Create(self.startStroke, TweenInfo.new(0.2), {
				Transparency = 0.2
			})
			strokeTween:Play()
		end
	else
		-- Disable ปุ่ม Start
		self.startButton.Active = false
		
		-- Animation - disable button
		local disableTween = TweenService:Create(self.startButton, TweenInfo.new(0.2), {
			BackgroundTransparency = 0.6,
			TextTransparency = 0.6
		})
		disableTween:Play()
		
		-- Disable stroke
		if self.startStroke then
			local strokeTween = TweenService:Create(self.startStroke, TweenInfo.new(0.2), {
				Transparency = 0.8
			})
			strokeTween:Play()
		end
	end
end

function StageSelectionUI:clearSelection()
	self.selectedStages = {}
	
	for i = 1, 5 do
		self:updateButtonState(i, false)
	end
	
	self:updateSelectedLabel()
	-- updateStartButtonState จะถูกเรียกจาก updateSelectedLabel แล้ว
end

function StageSelectionUI:confirmSelection(isRandom: boolean)
	if isRandom then
		-- Send random request
		self.confirmRemote:FireServer({
			isRandom = true
		})
	else
		-- ตรวจสอบว่าต้องเลือก stage ก่อน
		if #self.selectedStages == 0 then
			-- ไม่ส่งอะไร ถ้ายังไม่เลือก (ปุ่ม Start จะ disable อยู่แล้ว)
			return
		else
			-- Send custom order
			self.confirmRemote:FireServer({
				isRandom = false,
				stageOrder = self.selectedStages
			})
			
			-- Also send vote for multiplayer matches (server will ignore if not in a match)
			self.voteStagesRemote:FireServer(self.selectedStages)
		end
	end
	
	-- Hide selection UI
	self:hide()
end

function StageSelectionUI:updateCountdown(data: {number: number, message: string})
	self.countdownFrame.Visible = true
	self.countdownNumber.Text = tostring(data.number)
	self.countdownMessage.Text = data.message
	
	-- Enhanced scale animation with rotation
	self.countdownNumber.TextSize = 80
	self.countdownNumber.Rotation = 0
	
	local scaleUp = TweenService:Create(self.countdownNumber, TweenInfo.new(0.15, Enum.EasingStyle.Elastic), {
		TextSize = 120,
		Rotation = 5
	})
	scaleUp:Play()
	
	scaleUp.Completed:Connect(function()
		local scaleDown = TweenService:Create(self.countdownNumber, TweenInfo.new(0.15, Enum.EasingStyle.Elastic), {
			TextSize = 100,
			Rotation = 0
		})
		scaleDown:Play()
	end)
	
	-- Color change based on number
	if data.number == 3 then
		self.countdownNumber.TextColor3 = Color3.fromRGB(100, 200, 255)
	elseif data.number == 2 then
		self.countdownNumber.TextColor3 = Color3.fromRGB(255, 200, 100)
	elseif data.number == 1 then
		self.countdownNumber.TextColor3 = Color3.fromRGB(100, 255, 150)
	end
	
	-- Hide after last countdown
	if data.number == 1 then
		task.delay(1, function()
			local fadeOut = TweenService:Create(self.countdownFrame, TweenInfo.new(0.3), {
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 300, 0, 200)
			})
			fadeOut:Play()
			fadeOut.Completed:Connect(function()
				self.countdownFrame.Visible = false
			end)
		end)
	end
end

return StageSelectionUI
