-- FeedbackUI: Client panel for sending bug reports / suggestions

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.ThemeConfig)
local Config = require(ReplicatedStorage.Shared.Config)
local RemoteRegistry = require(ReplicatedStorage.Shared.RemoteRegistry)
local UIFactory = require(script.Parent.UIFactory)
local AdaptiveLayout = require(ReplicatedStorage.Shared.AdaptiveLayout)

local FeedbackUI = {}
FeedbackUI.__index = FeedbackUI

local PANEL_W = 360
local PANEL_H = 380
local PAD = 16
local MAX_LENGTH = 500

local CATEGORIES = {
	{ id = "Bug", icon = "\u{1F41B}", label = "Bug", color = Theme.DANGER },
	{ id = "Suggestion", icon = "\u{1F4A1}", label = "Suggestion", color = Theme.INFO },
	{ id = "Other", icon = "\u{1F4AC}", label = "Other", color = Theme.TEXT_MUTED },
}

function FeedbackUI.new(parent: ScreenGui, callbacks: {onHide: (() -> ())?}?)
	local self = setmetatable({}, FeedbackUI)
	self.parent = parent
	self.isVisible = false
	self._callbacks = callbacks or {}
	self._selectedCategory = "Bug"
	self._sending = false
	self._cooldownUntil = 0

	self:_build()
	self:_setupRemotes()
	return self
end

function FeedbackUI:_build()
	-- Container
	self.container = UIFactory.createPanel(self.parent, {
		name = "FeedbackContainer",
		size = UDim2.new(0, PANEL_W, 0, PANEL_H),
		position = UDim2.new(0.5, 0, 0.5, 0),
		anchorPoint = Vector2.new(0.5, 0.5),
		bgColor = Theme.BG_BASE,
		bgTransparency = 0.05,
		cornerSize = "lg",
		strokeColor = Theme.TEXT_MUTED,
		strokeWeight = "thin",
		visible = false,
	})
	AdaptiveLayout.applyScale(self.container, PANEL_W, PANEL_H)

	-- Title
	UIFactory.createLabel(self.container, {
		name = "Title",
		size = UDim2.new(1, 0, 0, 42),
		position = UDim2.new(0, 0, 0, 6),
		text = "\u{1F4E8}  Send Feedback",
		textColor = Theme.TEXT_PRIMARY,
		textSize = 22,
		font = Enum.Font.GothamBlack,
		bgTransparency = 1,
	})

	-- Close button
	UIFactory.createButton(self.container, {
		name = "CloseBtn",
		size = UDim2.new(0, 32, 0, 32),
		position = UDim2.new(1, -40, 0, 10),
		text = "X",
		textSize = 16,
		bgColor = Theme.BG_SURFACE,
		textColor = Theme.TEXT_MUTED,
		cornerSize = "full",
		onClick = function()
			self:hide()
		end,
	})

	-- Separator
	local sep = Instance.new("Frame")
	sep.Name = "Separator"
	sep.Size = UDim2.new(1, -PAD * 2, 0, 1)
	sep.Position = UDim2.new(0, PAD, 0, 50)
	sep.BackgroundColor3 = Theme.BG_ELEVATED
	sep.BorderSizePixel = 0
	sep.Parent = self.container

	-- Category buttons
	local catY = 60
	local catBtnW = math.floor((PANEL_W - PAD * 2 - 8) / 3)
	self._catButtons = {}

	for i, cat in ipairs(CATEGORIES) do
		local x = PAD + (i - 1) * (catBtnW + 4)
		local darkColor = Theme.darkenForText and Theme.darkenForText(cat.color, 0.45) or Theme.TEXT_PRIMARY
		local btn = UIFactory.createButton(self.container, {
			name = cat.id .. "CatBtn",
			size = UDim2.new(0, catBtnW, 0, 36),
			position = UDim2.new(0, x, 0, catY),
			text = cat.icon .. " " .. cat.label,
			textSize = 15,
			font = Enum.Font.GothamBold,
			bgColor = if self._selectedCategory == cat.id then cat.color else Theme.BG_SURFACE,
			textColor = if self._selectedCategory == cat.id then Theme.TEXT_ON_ACCENT else darkColor,
			cornerSize = "sm",
			onClick = function()
				self:_selectCategory(cat.id)
			end,
		})
		self._catButtons[cat.id] = { btn = btn, color = cat.color, darkColor = darkColor }
	end

	-- TextBox
	local textBoxY = catY + 46
	local textBoxH = 120

	local textBoxBg = UIFactory.createPanel(self.container, {
		name = "TextBoxBg",
		size = UDim2.new(1, -PAD * 2, 0, textBoxH),
		position = UDim2.new(0, PAD, 0, textBoxY),
		bgColor = Theme.BG_SURFACE,
		cornerSize = "sm",
		strokeColor = Theme.BG_ELEVATED,
		strokeWeight = "thin",
	})

	local textBox = Instance.new("TextBox")
	textBox.Name = "FeedbackInput"
	textBox.Size = UDim2.new(1, -12, 1, -12)
	textBox.Position = UDim2.new(0, 6, 0, 6)
	textBox.BackgroundTransparency = 1
	textBox.Text = ""
	textBox.PlaceholderText = "Describe the bug or your suggestion..."
	textBox.PlaceholderColor3 = Theme.TEXT_MUTED
	textBox.TextColor3 = Theme.TEXT_PRIMARY
	textBox.TextSize = 16
	textBox.Font = Enum.Font.Gotham
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.TextYAlignment = Enum.TextYAlignment.Top
	textBox.TextWrapped = true
	textBox.MultiLine = true
	textBox.ClearTextOnFocus = false
	textBox.BorderSizePixel = 0
	textBox.Parent = textBoxBg
	self._textBox = textBox

	-- Character count
	local charCountY = textBoxY + textBoxH + 4
	self._charLabel = UIFactory.createLabel(self.container, {
		name = "CharCount",
		size = UDim2.new(1, -PAD * 2, 0, 16),
		position = UDim2.new(0, PAD, 0, charCountY),
		text = "0 / " .. MAX_LENGTH,
		textColor = Theme.TEXT_MUTED,
		textSize = 11,
		font = Enum.Font.Gotham,
		textXAlignment = Enum.TextXAlignment.Right,
		bgTransparency = 1,
	})

	textBox:GetPropertyChangedSignal("Text"):Connect(function()
		local txt = textBox.Text
		if #txt > MAX_LENGTH then
			textBox.Text = string.sub(txt, 1, MAX_LENGTH)
			return
		end
		local len = #txt
		self._charLabel.Text = tostring(len) .. " / " .. MAX_LENGTH
		self._charLabel.TextColor3 = if len > MAX_LENGTH * 0.9 then Theme.WARNING else Theme.TEXT_MUTED
	end)

	-- Submit button
	local submitY = charCountY + 22
	self._submitBtn = UIFactory.createButton(self.container, {
		name = "SubmitBtn",
		size = UDim2.new(1, -PAD * 2, 0, 40),
		position = UDim2.new(0, PAD, 0, submitY),
		text = "Submit",
		textSize = 15,
		font = Enum.Font.GothamBold,
		bgColor = Theme.SUCCESS,
		textColor = Theme.TEXT_ON_ACCENT,
		cornerSize = "sm",
		onClick = function()
			self:_submit()
		end,
	})

	-- Status label (toast)
	self._statusLabel = UIFactory.createLabel(self.container, {
		name = "StatusLabel",
		size = UDim2.new(1, -PAD * 2, 0, 20),
		position = UDim2.new(0, PAD, 1, -26),
		text = "",
		textSize = 12,
		font = Enum.Font.GothamBold,
		bgTransparency = 1,
	})
end

function FeedbackUI:_selectCategory(catId: string)
	self._selectedCategory = catId
	for id, data in pairs(self._catButtons) do
		local isSelected = (id == catId)
		TweenService:Create(data.btn, TweenInfo.new(0.12), {
			BackgroundColor3 = if isSelected then data.color else Theme.BG_SURFACE,
		}):Play()
		data.btn.TextColor3 = if isSelected then Theme.TEXT_ON_ACCENT else data.darkColor
	end
end

function FeedbackUI:_resetButton()
	if self._submitBtn then
		self._submitBtn.BackgroundColor3 = Theme.SUCCESS
		self._submitBtn.Text = "Submit"
	end
	self._sending = false
end

function FeedbackUI:_submit()
	-- Check cooldown
	if os.clock() < self._cooldownUntil then
		local remaining = math.ceil(self._cooldownUntil - os.clock())
		self:_showStatus("Please wait " .. remaining .. "s before sending again", Theme.WARNING)
		return
	end

	if self._sending then return end

	local message = string.match(self._textBox.Text, "^%s*(.-)%s*$") or ""
	if #message == 0 then
		self:_showStatus("Please type a message first", Theme.WARNING)
		return
	end

	-- Disable submit while sending
	self._sending = true
	self._submitBtn.BackgroundColor3 = Theme.BG_SURFACE
	self._submitBtn.Text = "Sending..."

	local sendRemote = RemoteRegistry.get("SendFeedback")
	if sendRemote then
		sendRemote:FireServer({
			category = self._selectedCategory,
			message = message,
		})
	end

	-- Fallback: re-enable after 10s if server never responds
	task.delay(10, function()
		if self._sending then
			self:_showStatus("No response from server", Theme.WARNING)
			self:_resetButton()
		end
	end)
end

function FeedbackUI:_showStatus(text: string, color: Color3?)
	-- Darken color for readability on light background
	local displayColor = color or Theme.TEXT_PRIMARY
	if Theme.darkenForText then
		displayColor = Theme.darkenForText(displayColor, 0.45)
	end
	self._statusLabel.Text = text
	self._statusLabel.TextColor3 = displayColor
	self._statusLabel.TextTransparency = 0

	task.delay(4, function()
		if self._statusLabel and self._statusLabel.Text == text then
			TweenService:Create(self._statusLabel, TweenInfo.new(0.3), {
				TextTransparency = 1,
			}):Play()
		end
	end)
end

function FeedbackUI:_setupRemotes()
	local responseRemote = RemoteRegistry.get("FeedbackResponse")
	if responseRemote then
		responseRemote.OnClientEvent:Connect(function(data)
			if data.success then
				self:_showStatus("Feedback sent! Thank you!", Theme.SUCCESS)
				self._textBox.Text = ""
				-- Apply cooldown
				local cooldown = (Config.Feedback and Config.Feedback.CooldownSeconds) or 60
				self._cooldownUntil = os.clock() + cooldown
			else
				self:_showStatus(data.error or "Failed to send", Theme.DANGER)
			end
			self:_resetButton()
		end)
	end
end

function FeedbackUI:show()
	self.container.Visible = true
	self.isVisible = true
end

function FeedbackUI:hide()
	self.container.Visible = false
	self.isVisible = false
	if self._callbacks.onHide then
		self._callbacks.onHide()
	end
end

return FeedbackUI
