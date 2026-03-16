-- SettingsUI: Basic settings panel (Music/SFX toggles)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.ThemeConfig)
local UIFactory = require(script.Parent.UIFactory)

local SettingsUI = {}
SettingsUI.__index = SettingsUI

local PANEL_W = 260
local PANEL_H = 200
local ROW_H = 44
local PAD = 14

function SettingsUI.new(parent: ScreenGui, callbacks: {onHide: (() -> ())?}?)
	local self = setmetatable({}, SettingsUI)
	self.parent = parent
	self.isVisible = false
	self._callbacks = callbacks or {}

	-- Defaults
	self.musicEnabled = true
	self.sfxEnabled = true

	self:_build()
	return self
end

function SettingsUI:_build()
	-- Container
	self.container = UIFactory.createPanel(self.parent, {
		name = "SettingsContainer",
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

	-- Title
	UIFactory.createLabel(self.container, {
		name = "Title",
		size = UDim2.new(1, 0, 0, 36),
		position = UDim2.new(0, 0, 0, 6),
		text = "\u{2699}  Settings",
		textColor = Theme.TEXT_PRIMARY,
		textSize = 18,
		font = Enum.Font.GothamBlack,
		bgTransparency = 1,
	})

	-- Close button
	local closeBtn = UIFactory.createButton(self.container, {
		name = "CloseBtn",
		size = UDim2.new(0, 28, 0, 28),
		position = UDim2.new(1, -34, 0, 10),
		text = "X",
		textSize = 14,
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
	sep.Position = UDim2.new(0, PAD, 0, 44)
	sep.BackgroundColor3 = Theme.BG_ELEVATED
	sep.BorderSizePixel = 0
	sep.Parent = self.container

	-- Music toggle row
	local musicY = 56
	self.musicToggle = self:_createToggleRow("Music", "\u{1F3B5}", musicY, true, function(enabled)
		self.musicEnabled = enabled
		self:_applyMusicVolume()
	end)

	-- SFX toggle row
	local sfxY = musicY + ROW_H + 8
	self.sfxToggle = self:_createToggleRow("Sound Effects", "\u{1F50A}", sfxY, true, function(enabled)
		self.sfxEnabled = enabled
		self:_applySfxVolume()
	end)
end

function SettingsUI:_createToggleRow(label: string, icon: string, yPos: number, default: boolean, onChange: (boolean) -> ())
	local row = Instance.new("Frame")
	row.Name = label .. "Row"
	row.Size = UDim2.new(1, -PAD * 2, 0, ROW_H)
	row.Position = UDim2.new(0, PAD, 0, yPos)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Parent = self.container

	-- Icon + label
	UIFactory.createLabel(row, {
		name = "Label",
		size = UDim2.new(1, -80, 1, 0),
		position = UDim2.new(0, 0, 0, 0),
		text = icon .. "  " .. label,
		textColor = Theme.TEXT_PRIMARY,
		textSize = 15,
		font = Enum.Font.GothamBold,
		textXAlignment = Enum.TextXAlignment.Left,
		bgTransparency = 1,
	})

	-- Toggle button
	local enabled = default
	local toggleBg = UIFactory.createPanel(row, {
		name = "ToggleBg",
		size = UDim2.new(0, 52, 0, 28),
		position = UDim2.new(1, -52, 0.5, -14),
		bgColor = if enabled then Theme.SUCCESS else Theme.BG_SURFACE,
		cornerSize = "full",
		strokeColor = Theme.BG_ELEVATED,
		strokeWeight = "thin",
	})

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 22, 0, 22)
	knob.Position = if enabled then UDim2.new(1, -25, 0.5, -11) else UDim2.new(0, 3, 0.5, -11)
	knob.BackgroundColor3 = Theme.TEXT_PRIMARY
	knob.BorderSizePixel = 0
	knob.Parent = toggleBg

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	-- Click area over the whole toggle
	local clickArea = Instance.new("TextButton")
	clickArea.Name = "ClickArea"
	clickArea.Size = UDim2.new(1, 0, 1, 0)
	clickArea.BackgroundTransparency = 1
	clickArea.Text = ""
	clickArea.Parent = toggleBg

	clickArea.MouseButton1Click:Connect(function()
		enabled = not enabled
		local targetPos = if enabled then UDim2.new(1, -25, 0.5, -11) else UDim2.new(0, 3, 0.5, -11)
		local targetColor = if enabled then Theme.SUCCESS else Theme.BG_SURFACE

		TweenService:Create(knob, TweenInfo.new(0.15), { Position = targetPos }):Play()
		TweenService:Create(toggleBg, TweenInfo.new(0.15), { BackgroundColor3 = targetColor }):Play()

		onChange(enabled)
	end)

	return { bg = toggleBg, knob = knob, isEnabled = function() return enabled end }
end

function SettingsUI:_applyMusicVolume()
	-- Find BGM in SoundService
	local bgm = SoundService:FindFirstChild("BGM_Lobby")
	if bgm then
		bgm.Volume = if self.musicEnabled then 0.35 else 0
	end
end

function SettingsUI:_applySfxVolume()
	-- Control SFX SoundGroup volume (affects all SFX including item sounds)
	local sfxGroup = SoundService:FindFirstChild("SFX")
	if sfxGroup then
		sfxGroup.Volume = if self.sfxEnabled then 1 else 0
	end
end

function SettingsUI:show()
	self.container.Visible = true
	self.isVisible = true
end

function SettingsUI:hide()
	self.container.Visible = false
	self.isVisible = false
	if self._callbacks.onHide then
		self._callbacks.onHide()
	end
end

return SettingsUI
