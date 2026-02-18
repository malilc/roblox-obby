-- DailyBonusUI: HUD button + 7-day login calendar popup

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GOLD  = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(60,  200, 100)
local DARK  = Color3.fromRGB(18,  12,  38)
local DIM   = Color3.fromRGB(50,  40,  70)

local DailyBonusUI = {}
DailyBonusUI.__index = DailyBonusUI

function DailyBonusUI.new(parent: ScreenGui)
	local self = setmetatable({}, DailyBonusUI)
	self.parent        = parent
	self.lastData      = nil   -- stores last received streak data from server
	self._calendarOpen = false -- guard: prevent multiple calendar popups

	self:_createHudButton()

	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes")
		local remote  = remotes:WaitForChild("DailyBonusClaimed")
		remote.OnClientEvent:Connect(function(data)
			self.lastData = data
			self:_updateHudButton(data)
			if data.claimed then
				self:showCalendar(data)
			end
		end)
	end)

	return self
end

-- ─── HUD BUTTON ───────────────────────────────

function DailyBonusUI:_createHudButton()
	local btn = Instance.new("ImageButton")
	btn.Name              = "DailyLoginBtn"
	btn.Size              = UDim2.new(0, 58, 0, 58)
	btn.Position          = UDim2.new(0, 12, 1, -130)
	btn.BackgroundColor3  = Color3.fromRGB(30, 20, 55)
	btn.BorderSizePixel   = 0
	btn.Image             = ""
	btn.ZIndex            = 20
	btn.Parent            = self.parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color     = GOLD
	stroke.Thickness = 2
	stroke.Parent    = btn
	self._hudStroke  = stroke

	local icon = Instance.new("TextLabel")
	icon.Size               = UDim2.new(1, 0, 0, 34)
	icon.Position           = UDim2.new(0, 0, 0, 4)
	icon.BackgroundTransparency = 1
	icon.Text               = "🎁"
	icon.TextSize           = 26
	icon.Font               = Enum.Font.GothamBold
	icon.ZIndex             = 21
	icon.Parent             = btn

	local dayBadge = Instance.new("TextLabel")
	dayBadge.Name               = "DayBadge"
	dayBadge.Size               = UDim2.new(1, 0, 0, 18)
	dayBadge.Position           = UDim2.new(0, 0, 1, -20)
	dayBadge.BackgroundTransparency = 1
	dayBadge.Text               = "Day ?"
	dayBadge.TextColor3         = GOLD
	dayBadge.TextSize           = 11
	dayBadge.Font               = Enum.Font.GothamBold
	dayBadge.ZIndex             = 21
	dayBadge.Parent             = btn
	self._hudDayBadge = dayBadge

	btn.MouseButton1Click:Connect(function()
		if self._calendarOpen then return end
		local data = self.lastData or { claimed = false, day = 1, rewards = {25,50,75,100,150,200,500} }
		self:showCalendar(data)
	end)

	self._hudBtn = btn
end

function DailyBonusUI:_updateHudButton(data)
	if not self._hudDayBadge then return end
	local day     = data.day or 1
	local claimed = data.claimed
	self._hudDayBadge.Text       = "Day " .. day
	self._hudDayBadge.TextColor3 = claimed and GREEN or GOLD
	self._hudStroke.Color        = claimed and GREEN or GOLD
end

local function makeCorner(radius, parent)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function makeLabel(text, textSize, font, color, parent)
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextSize = textSize
	lbl.Font = font
	lbl.TextColor3 = color
	lbl.TextXAlignment = Enum.TextXAlignment.Center
	lbl.Parent = parent
	return lbl
end

function DailyBonusUI:showCalendar(data)
	if self._calendarOpen then return end
	self._calendarOpen = true

	local claimedDay  = data.day or 1
	local isClaim     = data.claimed == true
	local rewards     = data.rewards or {25, 50, 75, 100, 150, 200, 500}

	-- === OVERLAY ===
	local overlay = Instance.new("Frame")
	overlay.Name = "DailyLoginOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 60
	overlay.Parent = self.parent

	-- === MAIN PANEL ===
	local panel = Instance.new("Frame")
	panel.Name = "DailyLoginPanel"
	panel.Size = UDim2.new(0, 500, 0, 290)
	panel.Position = UDim2.new(0.5, -250, 0.5, -80)
	panel.BackgroundColor3 = DARK
	panel.BorderSizePixel = 0
	panel.ZIndex = 61
	panel.BackgroundTransparency = 1
	panel.Parent = self.parent
	makeCorner(16, panel)

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = GOLD
	panelStroke.Thickness = 2
	panelStroke.Transparency = 1
	panelStroke.Parent = panel

	local panelGrad = Instance.new("UIGradient")
	panelGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 18, 55)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 10, 32)),
	})
	panelGrad.Rotation = 135
	panelGrad.Parent = panel

	-- === TITLE BAR ===
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 58)
	titleBar.BackgroundColor3 = GOLD
	titleBar.BorderSizePixel = 0
	titleBar.ZIndex = 62
	titleBar.Parent = panel
	makeCorner(14, titleBar)

	-- Round only top corners by placing a fill rect to cover bottom corners
	local titleFill = Instance.new("Frame")
	titleFill.Size = UDim2.new(1, 0, 0.5, 0)
	titleFill.Position = UDim2.new(0, 0, 0.5, 0)
	titleFill.BackgroundColor3 = GOLD
	titleFill.BorderSizePixel = 0
	titleFill.ZIndex = 62
	titleFill.Parent = titleBar

	local titleGrad = Instance.new("UIGradient")
	titleGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 150, 20)),
	})
	titleGrad.Rotation = 90
	titleGrad.Parent = titleBar

	local titleIcon = makeLabel("🎁", 26, Enum.Font.GothamBold, DARK, titleBar)
	titleIcon.Size = UDim2.new(0, 40, 1, 0)
	titleIcon.Position = UDim2.new(0, 10, 0, 0)
	titleIcon.ZIndex = 63

	local titleText = makeLabel("DAILY LOGIN REWARD", 20, Enum.Font.GothamBlack, DARK, titleBar)
	titleText.Size = UDim2.new(1, -60, 0.6, 0)
	titleText.Position = UDim2.new(0, 46, 0, 4)
	titleText.TextXAlignment = Enum.TextXAlignment.Left
	titleText.ZIndex = 63

	local subText = makeLabel(isClaim and ("Day " .. claimedDay .. " / 7  •  +" .. tostring(rewards[claimedDay] or 0) .. " 🪙") or ("Day " .. claimedDay .. " / 7  •  Already Claimed ✓"), 13, Enum.Font.GothamBold, Color3.fromRGB(80, 55, 10), titleBar)
	subText.Size = UDim2.new(1, -60, 0.4, 0)
	subText.Position = UDim2.new(0, 46, 0.6, 0)
	subText.TextXAlignment = Enum.TextXAlignment.Left
	subText.ZIndex = 63

	-- === 7 DAY CARDS ===
	local cardW = 62
	local cardH = 120
	local cardSpacing = 6
	local cardsStartX = (500 - (7 * cardW + 6 * cardSpacing)) / 2
	local cardsY = 68
	local todayCard = nil  -- reference to the current day card for claim overlay

	for day = 1, 7 do
		local isPast    = day < claimedDay
		local isToday   = day == claimedDay
		local isFuture  = day > claimedDay

		local cardX = cardsStartX + (day - 1) * (cardW + cardSpacing)

		local card = Instance.new("Frame")
		card.Size = UDim2.new(0, cardW, 0, cardH)
		card.Position = UDim2.new(0, cardX, 0, cardsY)
		card.BorderSizePixel = 0
		card.ZIndex = 62
		card.Parent = panel

		if isToday then
			card.BackgroundColor3 = Color3.fromRGB(255, 185, 20)
		elseif isPast then
			card.BackgroundColor3 = Color3.fromRGB(25, 70, 45)
		else
			card.BackgroundColor3 = DIM
		end
		makeCorner(10, card)

		if isToday then
			todayCard = card
			local cardStroke = Instance.new("UIStroke")
			cardStroke.Color = Color3.fromRGB(255, 240, 100)
			cardStroke.Thickness = 2.5
			cardStroke.Parent = card
		end

		-- "DAY X" label
		local dayLbl = makeLabel("DAY " .. day, 10, Enum.Font.GothamBlack, isToday and DARK or (isPast and GREEN or Color3.fromRGB(140, 120, 180)), card)
		dayLbl.Size = UDim2.new(1, 0, 0, 20)
		dayLbl.Position = UDim2.new(0, 0, 0, 4)
		dayLbl.ZIndex = 63

		-- Reward icon / checkmark
		-- view mode: today = already claimed → show ✓ like past days
		local showCheck = isPast or (isToday and not isClaim)
		local iconLbl = makeLabel(showCheck and "✓" or "🪙", showCheck and 26 or 22, Enum.Font.GothamBold, showCheck and GREEN or (isToday and DARK or Color3.fromRGB(160, 140, 200)), card)
		iconLbl.Size = UDim2.new(1, 0, 0, 36)
		iconLbl.Position = UDim2.new(0, 0, 0, 26)
		iconLbl.ZIndex = 63

		-- Amount label
		local reward = rewards[day] or 0
		local amtText = isPast and "" or ("+" .. reward)
		local amtLbl = makeLabel(amtText, 11, Enum.Font.GothamBold, isToday and DARK or Color3.fromRGB(200, 180, 240), card)
		amtLbl.Size = UDim2.new(1, 0, 0, 20)
		amtLbl.Position = UDim2.new(0, 0, 0, 62)
		amtLbl.ZIndex = 63

		-- "CLAIMED" or "TODAY" badge
		if isToday or isPast then
			local badgeText = isToday and (isClaim and "TODAY!" or "✓ claimed") or "claimed"
			local badgeColor = isToday and (isClaim and DARK or GREEN) or Color3.fromRGB(80, 180, 110)
			local badge = makeLabel(badgeText, 9, Enum.Font.GothamBold, badgeColor, card)
			badge.Size = UDim2.new(1, -4, 0, 16)
			badge.Position = UDim2.new(0, 2, 1, -20)
			badge.ZIndex = 63
		end

		-- Dim future cards slightly
		if isFuture then
			card.BackgroundTransparency = 0.35
		end
	end

	-- === ACTION BUTTON ===
	local actionBtn = Instance.new("TextButton")
	actionBtn.Name            = "ActionButton"
	actionBtn.Size            = UDim2.new(0, 160, 0, 40)
	actionBtn.Position        = UDim2.new(0.5, -80, 1, -52)
	actionBtn.BackgroundColor3 = isClaim and GOLD or Color3.fromRGB(60, 45, 100)
	actionBtn.BorderSizePixel = 0
	actionBtn.Text            = isClaim and "✨  CLAIM!" or "OK"
	actionBtn.TextColor3      = isClaim and DARK or Color3.fromRGB(220, 210, 255)
	actionBtn.TextSize        = 16
	actionBtn.Font            = Enum.Font.GothamBlack
	actionBtn.ZIndex          = 63
	actionBtn.Parent          = panel
	makeCorner(10, actionBtn)

	local btnGrad = Instance.new("UIGradient")
	btnGrad.Color = isClaim and ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 225, 65)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 155, 20)),
	}) or ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 60, 130)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 38, 90)),
	})
	btnGrad.Rotation = 90
	btnGrad.Parent = actionBtn

	-- === ANIMATE IN ===
	TweenService:Create(overlay, TweenInfo.new(0.25), { BackgroundTransparency = 0.55 }):Play()
	TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.05,
		Position = UDim2.new(0.5, -250, 0.5, -145),
	}):Play()
	TweenService:Create(panelStroke, TweenInfo.new(0.35), { Transparency = 0 }):Play()

	-- === CLOSE ===
	local closing = false
	local function close()
		if closing then return end
		closing = true
		self._calendarOpen = false
		-- Mark as viewed so HUD button opens view mode next time
		if self.lastData then self.lastData.claimed = false end
		TweenService:Create(overlay, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		local out = TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, -250, 0.5, -80),
		})
		out:Play()
		out.Completed:Connect(function()
			overlay:Destroy()
			panel:Destroy()
		end)
	end

	actionBtn.MouseButton1Click:Connect(function()
		if isClaim then
			-- Flash button green
			actionBtn.Text = "✓  CLAIMED!"
			TweenService:Create(actionBtn, TweenInfo.new(0.2), {
				BackgroundColor3 = GREEN,
				TextColor3       = DARK,
			}):Play()
			btnGrad:Destroy()

			-- Show green overlay ON the day card
			if todayCard then
				local overlay = Instance.new("Frame")
				overlay.Size               = UDim2.new(1, 0, 1, 0)
				overlay.BackgroundColor3   = GREEN
				overlay.BackgroundTransparency = 1
				overlay.BorderSizePixel    = 0
				overlay.ZIndex             = 70
				overlay.Parent             = todayCard
				local oc = Instance.new("UICorner")
				oc.CornerRadius = UDim.new(0, 10)
				oc.Parent = overlay

				local checkLbl = Instance.new("TextLabel")
				checkLbl.Size               = UDim2.new(1, 0, 0.6, 0)
				checkLbl.Position           = UDim2.new(0, 0, 0.1, 0)
				checkLbl.BackgroundTransparency = 1
				checkLbl.Text               = "✓"
				checkLbl.TextColor3         = DARK
				checkLbl.TextSize           = 36
				checkLbl.Font               = Enum.Font.GothamBlack
				checkLbl.ZIndex             = 71
				checkLbl.Parent             = overlay

				local claimedLbl = Instance.new("TextLabel")
				claimedLbl.Size               = UDim2.new(1, 0, 0.3, 0)
				claimedLbl.Position           = UDim2.new(0, 0, 0.7, 0)
				claimedLbl.BackgroundTransparency = 1
				claimedLbl.Text               = "CLAIMED!"
				claimedLbl.TextColor3         = DARK
				claimedLbl.TextSize           = 9
				claimedLbl.Font               = Enum.Font.GothamBlack
				claimedLbl.ZIndex             = 71
				claimedLbl.Parent             = overlay

				TweenService:Create(overlay, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
					BackgroundTransparency = 0.15
				}):Play()
			end

			task.delay(1.2, close)
		else
			close()
		end
	end)

	-- Auto-close after 10s (only for claim popups, not view mode)
	if isClaim then
		task.delay(10, function()
			if panel.Parent then close() end
		end)
	end
end

return DailyBonusUI
