-- LeaderboardUI: แสดง Leaderboard Top 10

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local LeaderboardUI = {}
LeaderboardUI.__index = LeaderboardUI

function LeaderboardUI.new(parent: ScreenGui)
	local self = setmetatable({}, LeaderboardUI)
	
	self.parent = parent
	self.entries = {}
	self.isVisible = false
	
	self:createUI()
	
	return self
end

function LeaderboardUI:createUI()
	-- Main frame (hidden by default)
	local frame = Instance.new("Frame")
	frame.Name = "LeaderboardFrame"
	frame.Size = UDim2.new(0, 300, 0, 400)
	frame.Position = UDim2.new(1, -320, 0.5, -200)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = self.parent
	self.frame = frame
	
	-- Corner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	
	-- Stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 215, 0)
	stroke.Thickness = 2
	stroke.Transparency = 0.5
	stroke.Parent = frame
	
	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	title.BackgroundTransparency = 0.8
	title.Text = "🏆 LEADERBOARD"
	title.TextColor3 = Color3.fromRGB(255, 215, 0)
	title.TextSize = 20
	title.Font = Enum.Font.GothamBold
	title.Parent = frame
	
	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 12)
	titleCorner.Parent = title
	
	-- Scroll frame for entries
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "EntriesScroll"
	scrollFrame.Size = UDim2.new(1, -20, 1, -60)
	scrollFrame.Position = UDim2.new(0, 10, 0, 50)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 4
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 215, 0)
	scrollFrame.Parent = frame
	self.scrollFrame = scrollFrame
	
	-- Layout
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 5)
	layout.Parent = scrollFrame
	
	-- Toggle button
	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "ToggleLeaderboard"
	toggleButton.Size = UDim2.new(0, 40, 0, 40)
	toggleButton.Position = UDim2.new(1, -60, 0.5, -20)
	toggleButton.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	toggleButton.BackgroundTransparency = 0.3
	toggleButton.Text = "🏆"
	toggleButton.TextSize = 24
	toggleButton.Parent = self.parent
	self.toggleButton = toggleButton
	
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 8)
	toggleCorner.Parent = toggleButton
	
	toggleButton.MouseButton1Click:Connect(function()
		self:toggle()
	end)
end

function LeaderboardUI:toggle()
	self.isVisible = not self.isVisible
	
	if self.isVisible then
		self.frame.Visible = true
		self.frame.Position = UDim2.new(1, 0, 0.5, -200)
		
		local tween = TweenService:Create(self.frame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
			Position = UDim2.new(1, -320, 0.5, -200)
		})
		tween:Play()
	else
		local tween = TweenService:Create(self.frame, TweenInfo.new(0.2), {
			Position = UDim2.new(1, 0, 0.5, -200)
		})
		tween:Play()
		tween.Completed:Connect(function()
			self.frame.Visible = false
		end)
	end
end

function LeaderboardUI:updateLeaderboard(entries: {{userId: number, name: string, highScore: number}})
	-- Clear existing entries
	for _, child in ipairs(self.scrollFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	-- Create new entries
	for rank, entry in ipairs(entries) do
		local entryFrame = self:createEntryFrame(rank, entry)
		entryFrame.Parent = self.scrollFrame
	end
	
	-- Update canvas size
	local layout = self.scrollFrame:FindFirstChild("UIListLayout")
	if layout then
		self.scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
	end
end

function LeaderboardUI:createEntryFrame(rank: number, entry: {userId: number, name: string, highScore: number}): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Entry_" .. rank
	frame.Size = UDim2.new(1, 0, 0, 35)
	frame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	frame.BackgroundTransparency = 0.5
	frame.BorderSizePixel = 0
	frame.LayoutOrder = rank
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame
	
	-- Highlight for top 3
	if rank <= 3 then
		local colors = {
			Color3.fromRGB(255, 215, 0), -- Gold
			Color3.fromRGB(192, 192, 192), -- Silver
			Color3.fromRGB(205, 127, 50), -- Bronze
		}
		frame.BackgroundColor3 = colors[rank]
		frame.BackgroundTransparency = 0.7
	end
	
	-- Highlight if local player
	if entry.userId == LocalPlayer.UserId then
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(100, 200, 255)
		stroke.Thickness = 2
		stroke.Parent = frame
	end
	
	-- Rank
	local rankLabel = Instance.new("TextLabel")
	rankLabel.Name = "Rank"
	rankLabel.Size = UDim2.new(0, 30, 1, 0)
	rankLabel.Position = UDim2.new(0, 5, 0, 0)
	rankLabel.BackgroundTransparency = 1
	rankLabel.Text = "#" .. rank
	rankLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	rankLabel.TextSize = 14
	rankLabel.Font = Enum.Font.GothamBold
	rankLabel.TextXAlignment = Enum.TextXAlignment.Left
	rankLabel.Parent = frame
	
	-- Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(0.5, -40, 1, 0)
	nameLabel.Position = UDim2.new(0, 40, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = entry.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = frame
	
	-- Score
	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "Score"
	scoreLabel.Size = UDim2.new(0.4, 0, 1, 0)
	scoreLabel.Position = UDim2.new(0.6, 0, 0, 0)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Text = tostring(entry.highScore)
	scoreLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	scoreLabel.TextSize = 14
	scoreLabel.Font = Enum.Font.GothamBold
	scoreLabel.TextXAlignment = Enum.TextXAlignment.Right
	scoreLabel.Parent = frame
	
	return frame
end

return LeaderboardUI
