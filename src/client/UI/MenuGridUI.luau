-- MenuGridUI: 2x3 menu button grid (top-left HUD)

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
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
local PANEL_H = PAD * 2 + 4 * BUTTON_H + GAP * 3        -- 306
local PANEL_X = 10
local PANEL_Y_SCALE = if IS_MOBILE then 0.40 else 0.5
local PANEL_Y_OFFSET = -math.floor(PANEL_H / 2) -- vertically centered

-- Mobile-aware dimensions (0.65x scale keeps buttons >= 44px tap target)
local IS_MOBILE = UserInputService.TouchEnabled
local MOBILE_SCALE = 0.65
local M_BUTTON_W = if IS_MOBILE then math.floor(BUTTON_W * MOBILE_SCALE) else BUTTON_W  -- 48 on mobile
local M_BUTTON_H = if IS_MOBILE then math.floor(BUTTON_H * MOBILE_SCALE) else BUTTON_H  -- 44 on mobile
local M_GAP = if IS_MOBILE then 3 else GAP
local M_PAD = if IS_MOBILE then 4 else PAD
local M_PANEL_W = M_PAD * 2 + COLS * M_BUTTON_W + M_GAP  -- ~114 on mobile vs 172 on desktop
local M_PANEL_H = M_PAD * 2 + 4 * M_BUTTON_H + M_GAP * 3 -- ~200 on mobile vs 306 on desktop
local M_PANEL_Y_OFFSET = -math.floor(M_PANEL_H / 2)

-- Button definitions
local BUTTONS = {
	{ id = "Shop",     icon = "\u{1F6D2}", label = "Shop",       color = Theme.ACCENT_CYAN },
	{ id = "Classes",  icon = "\u{2694}",  label = "Classes",    color = Theme.SUCCESS },
	{ id = "Titles",   icon = "\u{2B50}",  label = "Collection", color = Theme.ACCENT_PINK },
	{ id = "Daily",    icon = "\u{1F381}", label = "Daily",      color = Theme.PRIMARY },
	{ id = "Feedback", icon = "\u{1F4E8}", label = "Feedback",   color = Theme.INFO },
	{ id = "Invite",   icon = "\u{1F465}", label = "Invite",     color = Theme.ACCENT_CYAN },
	{ id = "Help",     icon = "\u{2753}",  label = "Help",       color = Theme.WARNING },
	{ id = "Settings", icon = "\u{2699}",  label = "Settings",   color = Theme.TEXT_MUTED },
}

function MenuGridUI.new(parent: ScreenGui, callbacks: {[string]: () -> ()})
	local self = setmetatable({}, MenuGridUI)
	self.buttons = {}
	self.callbacks = callbacks or {}

	-- Container panel
	local panel = UIFactory.createPanel(parent, {
		name = "MenuGridPanel",
		size = UDim2.new(0, M_PANEL_W, 0, M_PANEL_H),
		position = UDim2.new(0, PANEL_X, PANEL_Y_SCALE, M_PANEL_Y_OFFSET),
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
		local x = M_PAD + col * (M_BUTTON_W + M_GAP)
		local y = M_PAD + row * (M_BUTTON_H + M_GAP)

		local callbackKey = "on" .. def.id
		local btn = UIFactory.createButton(panel, {
			name = def.id .. "Btn",
			size = UDim2.new(0, M_BUTTON_W, 0, M_BUTTON_H),
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

		-- Icon label (upper area, slightly lower)
		UIFactory.createLabel(btn, {
			name = "Icon",
			size = UDim2.new(1, 0, 0.55, 0),
			position = UDim2.new(0, 0, 0, 4),
			text = def.icon,
			textSize = if IS_MOBILE then 18 else 24,
			bgTransparency = 1,
			textYAlignment = Enum.TextYAlignment.Center,
		})

		-- Name label (lower area, inside button bounds)
		UIFactory.createLabel(btn, {
			name = "Label",
			size = UDim2.new(1, -4, 0, 14),
			position = UDim2.new(0, 2, 1, -16),
			text = def.label,
			textColor = Theme.TEXT_PRIMARY,
			textSize = if IS_MOBILE then 9 else 11,
			font = Enum.Font.GothamBold,
			bgTransparency = 1,
			textYAlignment = Enum.TextYAlignment.Center,
			textTruncate = Enum.TextTruncate.AtEnd,
			clipDescendants = true,
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

function MenuGridUI:hide()
	if self.panel then
		TweenService:Create(self.panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0, -M_PANEL_W - 10, PANEL_Y_SCALE, M_PANEL_Y_OFFSET),
		}):Play()
	end
end

function MenuGridUI:show()
	if self.panel then
		TweenService:Create(self.panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, PANEL_X, PANEL_Y_SCALE, M_PANEL_Y_OFFSET),
		}):Play()
	end
end

return MenuGridUI
