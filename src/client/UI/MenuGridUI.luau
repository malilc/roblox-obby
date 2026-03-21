-- MenuGridUI: 2x3 menu button grid (top-left HUD)

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.ThemeConfig)
local UIFactory = require(script.Parent.UIFactory)

local MenuGridUI = {}
MenuGridUI.__index = MenuGridUI

-- IS_MOBILE evaluated inside .new() to avoid Device Emulator race condition

-- Desktop layout constants (base design size)
local BUTTON_W = 74
local BUTTON_H = 68
local GAP = 6
local PAD = 8
local COLS = 2
local PANEL_W = PAD * 2 + COLS * BUTTON_W + GAP         -- 172
local PANEL_H = PAD * 2 + 4 * BUTTON_H + GAP * 3        -- 306
local PANEL_X = 10

-- On mobile: build at desktop size, then apply UIScale to shrink responsively
-- Position: bottom-left on mobile, center-left on desktop

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
	local IS_MOBILE = UserInputService.TouchEnabled

	local self = setmetatable({}, MenuGridUI)
	self.buttons = {}
	self.callbacks = callbacks or {}

	-- Container panel (always built at desktop size, scaled on mobile via UIScale)
	local desktopPos = UDim2.new(0, PANEL_X, 0.5, -math.floor(PANEL_H / 2)) -- center-left on desktop
	-- Mobile: position calculated after UIScale is applied (see below)

	local panel = UIFactory.createPanel(parent, {
		name = "MenuGridPanel",
		size = UDim2.new(0, PANEL_W, 0, PANEL_H),
		position = desktopPos,
		bgColor = Theme.BG_OVERLAY,
		bgTransparency = 0.25,
		cornerSize = "lg",
		strokeColor = Theme.BG_ELEVATED,
		strokeWeight = "thin",
		strokeTransparency = 0.3,
	})
	self.panel = panel

	-- Responsive scaling on mobile: shrink and position center-left (above coins/gems)
	if IS_MOBILE then
		local camera = workspace.CurrentCamera
		local MOBILE_SCALE = 0.55

		local uiScale = Instance.new("UIScale")
		uiScale.Scale = MOBILE_SCALE
		uiScale.Parent = panel
		self.menuScale = uiScale

		-- Center-left position, slightly above center to leave room for coins at bottom
		local scaledH = PANEL_H * MOBILE_SCALE
		panel.Position = UDim2.new(0, 4, 0.38, -math.floor(scaledH / 2))
	end

	-- Build grid buttons (always at desktop size — UIScale handles shrinking)
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

		-- Icon label (upper area)
		UIFactory.createLabel(btn, {
			name = "Icon",
			size = UDim2.new(1, 0, 0.55, 0),
			position = UDim2.new(0, 0, 0, 4),
			text = def.icon,
			textSize = 24,
			bgTransparency = 1,
			textYAlignment = Enum.TextYAlignment.Center,
		})

		-- Name label (lower area)
		UIFactory.createLabel(btn, {
			name = "Label",
			size = UDim2.new(1, -4, 0, 14),
			position = UDim2.new(0, 2, 1, -16),
			text = def.label,
			textColor = Theme.TEXT_PRIMARY,
			textSize = 11,
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
		local currentPos = self.panel.Position
		TweenService:Create(self.panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0, -PANEL_W - 10, currentPos.Y.Scale, currentPos.Y.Offset),
		}):Play()
	end
end

function MenuGridUI:show()
	if self.panel then
		local isMobile = UserInputService.TouchEnabled
		local scale = self.menuScale and self.menuScale.Scale or 1
		local scaledH = PANEL_H * scale
		local showPos = if isMobile
			then UDim2.new(0, 4, 0.38, -math.floor(scaledH / 2))
			else UDim2.new(0, PANEL_X, 0.5, -math.floor(PANEL_H / 2))
		TweenService:Create(self.panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = showPos,
		}):Play()
	end
end

return MenuGridUI
