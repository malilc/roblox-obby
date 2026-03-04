-- MenuGridUI: 2x3 menu button grid (top-left HUD)

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.ThemeConfig)
local UIFactory = require(script.Parent.UIFactory)

local MenuGridUI = {}
MenuGridUI.__index = MenuGridUI

-- Layout constants
local BUTTON_W = 74
local BUTTON_H = 68
local GAP = 6
local PAD = 8
local COLS = 2
local PANEL_W = PAD * 2 + COLS * BUTTON_W + GAP         -- 172
local PANEL_H = PAD * 2 + 3 * BUTTON_H + GAP * 2        -- 228
local PANEL_X = 10
local PANEL_Y_SCALE = 0.5
local PANEL_Y_OFFSET = -math.floor(PANEL_H / 2) -- vertically centered

-- Button definitions
local BUTTONS = {
	{ id = "Shop",     icon = "\u{1F6D2}", label = "Shop",     color = Theme.ACCENT_CYAN },
	{ id = "Classes",  icon = "\u{2694}",  label = "Classes",  color = Theme.SUCCESS },
	{ id = "Titles",   icon = "\u{1F4CB}", label = "Titles",   color = Theme.ACCENT_PINK },
	{ id = "Daily",    icon = "\u{1F381}", label = "Daily",    color = Theme.PRIMARY },
	{ id = "Help",     icon = "\u{2753}",  label = "Help",     color = Theme.INFO },
	{ id = "Settings", icon = "\u{2699}",  label = "Settings", color = Theme.TEXT_MUTED },
}

function MenuGridUI.new(parent: ScreenGui, callbacks: {[string]: () -> ()})
	local self = setmetatable({}, MenuGridUI)
	self.buttons = {}
	self.callbacks = callbacks or {}

	-- Container panel
	local panel = UIFactory.createPanel(parent, {
		name = "MenuGridPanel",
		size = UDim2.new(0, PANEL_W, 0, PANEL_H),
		position = UDim2.new(0, PANEL_X, PANEL_Y_SCALE, PANEL_Y_OFFSET),
		bgColor = Theme.BG_OVERLAY,
		bgTransparency = 0.25,
		cornerSize = "lg",
		strokeColor = Theme.BG_ELEVATED,
		strokeWeight = "thin",
		strokeTransparency = 0.3,
	})
	self.panel = panel

	-- Build grid buttons
	for i, def in ipairs(BUTTONS) do
		local col = (i - 1) % COLS
		local row = math.floor((i - 1) / COLS)
		local x = PAD + col * (BUTTON_W + GAP)
		local y = PAD + row * (BUTTON_H + GAP)

		local callbackKey = "on" .. def.id
		local btn = UIFactory.createButton(panel, {
			name = def.id .. "Btn",
			size = UDim2.new(0, BUTTON_W, 0, BUTTON_H),
			position = UDim2.new(0, x, 0, y),
			bgColor = Theme.BG_SURFACE,
			cornerSize = "md",
			strokeColor = def.color,
			strokeWeight = "thin",
			strokeTransparency = 0.4,
			text = "",
			onClick = function()
				if self.callbacks[callbackKey] then
					self.callbacks[callbackKey]()
				end
			end,
		})
		btn.AutoButtonColor = false

		-- Icon label (centered upper area)
		UIFactory.createLabel(btn, {
			name = "Icon",
			size = UDim2.new(1, 0, 0, 34),
			position = UDim2.new(0, 0, 0, 6),
			text = def.icon,
			textSize = 24,
			bgTransparency = 1,
			textYAlignment = Enum.TextYAlignment.Center,
		})

		-- Name label (centered lower area)
		UIFactory.createLabel(btn, {
			name = "Label",
			size = UDim2.new(1, 0, 0, 16),
			position = UDim2.new(0, 0, 1, -22),
			text = def.label,
			textColor = Theme.TEXT_PRIMARY,
			textSize = 12,
			font = Enum.Font.GothamBold,
			bgTransparency = 1,
			textYAlignment = Enum.TextYAlignment.Center,
		})

		self.buttons[def.id] = btn
	end

	return self
end

function MenuGridUI:setActive(id: string, active: boolean)
	local btn = self.buttons[id]
	if not btn then return end

	local targetBg = if active then Theme.BG_ELEVATED else Theme.BG_SURFACE
	local targetStrokeTransp = if active then 0 else 0.4

	TweenService:Create(btn, TweenInfo.new(0.15), {
		BackgroundColor3 = targetBg,
	}):Play()

	local stroke = btn:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(0.15), {
			Transparency = targetStrokeTransp,
		}):Play()
	end
end

function MenuGridUI:clearAllActive()
	for id, _ in pairs(self.buttons) do
		self:setActive(id, false)
	end
end

return MenuGridUI
