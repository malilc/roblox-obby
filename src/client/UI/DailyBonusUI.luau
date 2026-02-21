-- DailyBonusUI: HUD button + 7-day login calendar popup

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(ReplicatedStorage.Shared.ThemeConfig)

local COLORS = {
	GOLD        = Theme.PRIMARY,
	GREEN       = Theme.SUCCESS,
	DARK        = Theme.BG_OVERLAY,
	DIM         = Theme.BG_SURFACE,
	PAST_CARD   = Color3.fromRGB(25, 70, 45),
	SUBTITLE    = Color3.fromRGB(80, 55, 10),
	FUTURE_TEXT = Theme.TEXT_MUTED,
	CARD_BADGE  = Color3.fromRGB(80, 180, 110),
	DAY7_SPECIAL = Color3.fromRGB(120, 80, 180),
}

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
	btn.BackgroundColor3  = Theme.BG_BASE
	btn.BorderSizePixel   = 0
	btn.Image             = ""
	btn.ZIndex            = 20
	btn.Parent            = self.parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CORNER_MD
	corner.Parent = btn

	-- Gradient background
	local btnGrad = Instance.new("UIGradient")
	btnGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.BG_SURFACE),
		ColorSequenceKeypoint.new(1, Theme.BG_BASE),
	})
	btnGrad.Rotation = 135
	btnGrad.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color     = COLORS.GOLD
	stroke.Thickness = Theme.STROKE_MED
	stroke.Transparency = 0.2
	stroke.Parent    = btn
	self._hudStroke  = stroke

	-- Drop shadow
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 4, 1, 4)
	shadow.Position = UDim2.new(0, -2, 0, 3)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.7
	shadow.BorderSizePixel = 0
	shadow.ZIndex = btn.ZIndex - 1
	shadow.Parent = btn
	Theme.applyCorner(shadow, "md")

	local icon = Instance.new("TextLabel")
	icon.Size               = UDim2.new(1, 0, 0, 34)
	icon.Position           = UDim2.new(0, 0, 0, 4)
	icon.BackgroundTransparency = 1
	icon.Text               = "\u{1F381}"
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
	dayBadge.TextColor3         = COLORS.GOLD
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
	self._hudDayBadge.TextColor3 = claimed and COLORS.GREEN or COLORS.GOLD
	self._hudStroke.Color        = claimed and COLORS.GREEN or COLORS.GOLD
end

function DailyBonusUI:showCalendar(data)
	if self._calendarOpen then return end
	self._calendarOpen = true

	local claimedDay  = data.day or 1
	local isClaim     = data.claimed == true
	local rewards     = data.rewards or {25, 50, 75, 100, 150, 200, 500}

	-- === MODAL SCREENGUI (own layer so it covers all HUD elements) ===
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local modalGui = Instance.new("ScreenGui")
	modalGui.Name = "DailyLoginModalGui"
	modalGui.ResetOnSpawn = false
	modalGui.IgnoreGuiInset = true
	modalGui.DisplayOrder = 100
	modalGui.Parent = playerGui

	-- === OVERLAY ===
	local overlay = Instance.new("Frame")
	overlay.Name = "DailyLoginOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 1
	overlay.Parent = modalGui

	-- === MAIN PANEL ===
	local panel = Instance.new("Frame")
	panel.Name = "DailyLoginPanel"
	panel.Size = UDim2.new(0, 500, 0, 360)
	panel.Position = UDim2.new(0.5, -250, 0.5, -110)
	panel.BackgroundColor3 = Theme.BG_BASE
	panel.BorderSizePixel = 0
	panel.ZIndex = 2
	panel.BackgroundTransparency = 1
	panel.Parent = modalGui
	Theme.applyCorner(panel, "lg")

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = COLORS.GOLD
	panelStroke.Thickness = Theme.STROKE_MED
	panelStroke.Transparency = 1
	panelStroke.Parent = panel

	local panelGrad = Instance.new("UIGradient")
	panelGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.BG_SURFACE),
		ColorSequenceKeypoint.new(1, Theme.BG_BASE),
	})
	panelGrad.Rotation = 135
	panelGrad.Parent = panel

	-- Drop shadow
	local panelShadow = Instance.new("Frame")
	panelShadow.Name = "Shadow"
	panelShadow.Size = UDim2.new(1, 6, 1, 6)
	panelShadow.Position = UDim2.new(0, -3, 0, 4)
	panelShadow.BackgroundColor3 = Color3.new(0, 0, 0)
	panelShadow.BackgroundTransparency = 0.6
	panelShadow.BorderSizePixel = 0
	panelShadow.ZIndex = panel.ZIndex - 1
	panelShadow.Parent = panel
	Theme.applyCorner(panelShadow, "lg")

	-- === TITLE BAR ===
	local titleBar = Instance.new("Frame")
	titleBar.Size = UDim2.new(1, 0, 0, 58)
	titleBar.BackgroundColor3 = COLORS.GOLD
	titleBar.BorderSizePixel = 0
	titleBar.ZIndex = 62
	titleBar.Parent = panel
	Theme.applyCorner(titleBar, "md")

	-- Round only top corners by placing a fill rect to cover bottom corners
	local titleFill = Instance.new("Frame")
	titleFill.Size = UDim2.new(1, 0, 0.5, 0)
	titleFill.Position = UDim2.new(0, 0, 0.5, 0)
	titleFill.BackgroundColor3 = COLORS.GOLD
	titleFill.BorderSizePixel = 0
	titleFill.ZIndex = 62
	titleFill.Parent = titleBar

	local titleGrad = Instance.new("UIGradient")
	titleGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.PRIMARY),
		ColorSequenceKeypoint.new(1, Theme.PRIMARY_DARK),
	})
	titleGrad.Rotation = 90
	titleGrad.Parent = titleBar

	local titleIcon = Instance.new("TextLabel")
	titleIcon.BackgroundTransparency = 1
	titleIcon.Text = "\u{1F381}"
	titleIcon.TextSize = 26
	titleIcon.Font = Enum.Font.GothamBold
	titleIcon.TextColor3 = Theme.TEXT_DARK
	titleIcon.Size = UDim2.new(0, 40, 1, 0)
	titleIcon.Position = UDim2.new(0, 10, 0, 0)
	titleIcon.TextXAlignment = Enum.TextXAlignment.Center
	titleIcon.ZIndex = 63
	titleIcon.Parent = titleBar

	local titleText = Instance.new("TextLabel")
	titleText.BackgroundTransparency = 1
	titleText.Text = "DAILY LOGIN REWARD"
	titleText.TextSize = 20
	titleText.Font = Enum.Font.GothamBlack
	titleText.TextColor3 = Theme.TEXT_DARK
	titleText.Size = UDim2.new(1, -60, 0.6, 0)
	titleText.Position = UDim2.new(0, 46, 0, 4)
	titleText.TextXAlignment = Enum.TextXAlignment.Left
	titleText.ZIndex = 63
	titleText.Parent = titleBar

	local subText = Instance.new("TextLabel")
	subText.BackgroundTransparency = 1
	subText.Text = isClaim and ("Day " .. claimedDay .. " / 7  \u{2022}  +" .. tostring(rewards[claimedDay] or 0) .. " \u{1FA99}") or ("Day " .. claimedDay .. " / 7  \u{2022}  Already Claimed \u{2713}")
	subText.TextSize = 13
	subText.Font = Enum.Font.GothamBold
	subText.TextColor3 = COLORS.SUBTITLE
	subText.Size = UDim2.new(1, -60, 0.4, 0)
	subText.Position = UDim2.new(0, 46, 0.6, 0)
	subText.TextXAlignment = Enum.TextXAlignment.Left
	subText.ZIndex = 63
	subText.Parent = titleBar

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
			card.BackgroundColor3 = COLORS.GOLD
		elseif isPast then
			card.BackgroundColor3 = COLORS.PAST_CARD
		elseif day == 7 then
			card.BackgroundColor3 = COLORS.DAY7_SPECIAL
		else
			card.BackgroundColor3 = COLORS.DIM
		end
		Theme.applyCorner(card, "sm")

		if isToday then
			todayCard = card
			local cardStroke = Instance.new("UIStroke")
			cardStroke.Color = Theme.HUD_GLOW_GOLD
			cardStroke.Thickness = Theme.STROKE_MED
			cardStroke.Parent = card
		end

		-- "DAY X" label
		local dayLbl = Instance.new("TextLabel")
		dayLbl.BackgroundTransparency = 1
		dayLbl.Text = "DAY " .. day
		dayLbl.TextSize = 10
		dayLbl.Font = Enum.Font.GothamBlack
		dayLbl.TextColor3 = isToday and Theme.TEXT_DARK or (isPast and COLORS.GREEN or COLORS.FUTURE_TEXT)
		dayLbl.TextXAlignment = Enum.TextXAlignment.Center
		dayLbl.Size = UDim2.new(1, 0, 0, 20)
		dayLbl.Position = UDim2.new(0, 0, 0, 4)
		dayLbl.ZIndex = 63
		dayLbl.Parent = card

		-- Reward icon per state
		local showCheck = isPast or (isToday and not isClaim)
		local iconText, iconSize
		if showCheck then
			iconText = "\u{2705}" -- ✅
			iconSize = 22
		elseif isToday and isClaim then
			iconText = "\u{1FA99}" -- 🪙
			iconSize = 22
		elseif day == 7 then
			iconText = "\u{1F451}" -- 👑
			iconSize = 24
		else
			iconText = "\u{1F381}" -- 🎁
			iconSize = 22
		end
		local iconLbl = Instance.new("TextLabel")
		iconLbl.BackgroundTransparency = 1
		iconLbl.Text = iconText
		iconLbl.TextSize = iconSize
		iconLbl.Font = Enum.Font.GothamBold
		iconLbl.TextColor3 = showCheck and COLORS.GREEN or (isToday and Theme.TEXT_DARK or COLORS.FUTURE_TEXT)
		iconLbl.TextXAlignment = Enum.TextXAlignment.Center
		iconLbl.Size = UDim2.new(1, 0, 0, 36)
		iconLbl.Position = UDim2.new(0, 0, 0, 26)
		iconLbl.ZIndex = 63
		iconLbl.Parent = card

		-- Amount label
		local reward = rewards[day] or 0
		local amtText = isPast and "" or ("+" .. reward)
		local amtLbl = Instance.new("TextLabel")
		amtLbl.BackgroundTransparency = 1
		amtLbl.Text = amtText
		amtLbl.TextSize = 11
		amtLbl.Font = Enum.Font.GothamBold
		amtLbl.TextColor3 = isToday and Theme.TEXT_DARK or Theme.TEXT_MUTED
		amtLbl.TextXAlignment = Enum.TextXAlignment.Center
		amtLbl.Size = UDim2.new(1, 0, 0, 20)
		amtLbl.Position = UDim2.new(0, 0, 0, 62)
		amtLbl.ZIndex = 63
		amtLbl.Parent = card

		-- "CLAIMED" or "TODAY" badge
		if isToday or isPast then
			local badgeText = isToday and (isClaim and "TODAY!" or "\u{2713} claimed") or "claimed"
			local badgeColor = isToday and (isClaim and Theme.TEXT_DARK or COLORS.GREEN) or COLORS.CARD_BADGE
			local badge = Instance.new("TextLabel")
			badge.BackgroundTransparency = 1
			badge.Text = badgeText
			badge.TextSize = 9
			badge.Font = Enum.Font.GothamBold
			badge.TextColor3 = badgeColor
			badge.TextXAlignment = Enum.TextXAlignment.Center
			badge.Size = UDim2.new(1, -4, 0, 16)
			badge.Position = UDim2.new(0, 2, 1, -20)
			badge.ZIndex = 63
			badge.Parent = card
		end

		-- Dim future cards slightly
		if isFuture then
			card.BackgroundTransparency = 0.35
		end
	end

	-- === PROGRESS BAR ===
	local progressY = cardsY + cardH + 10
	local progressContainer = Instance.new("Frame")
	progressContainer.Name = "ProgressBarContainer"
	progressContainer.Size = UDim2.new(1, -40, 0, 20)
	progressContainer.Position = UDim2.new(0, 20, 0, progressY)
	progressContainer.BackgroundTransparency = 1
	progressContainer.ZIndex = 62
	progressContainer.Parent = panel

	-- Background track
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, 0, 0, 6)
	track.Position = UDim2.new(0, 0, 0.5, -3)
	track.BackgroundColor3 = Theme.BG_ELEVATED
	track.BackgroundTransparency = 0.3
	track.BorderSizePixel = 0
	track.ZIndex = 62
	track.Parent = progressContainer
	Theme.applyCorner(track, "full")

	-- Fill bar (green)
	local fillDay = claimedDay
	if isClaim then fillDay = claimedDay - 1 end
	local fillWidth = math.clamp(fillDay / 7, 0, 1)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(fillWidth, 0, 1, 0)
	fill.BackgroundColor3 = Theme.SUCCESS
	fill.BorderSizePixel = 0
	fill.ZIndex = 63
	fill.Parent = track
	Theme.applyCorner(fill, "full")

	-- 7 dot markers
	for dotDay = 1, 7 do
		local dotX = (dotDay - 0.5) / 7
		local dotSize = 10

		local dot = Instance.new("Frame")
		dot.Name = "Dot" .. dotDay
		dot.Size = UDim2.new(0, dotSize, 0, dotSize)
		dot.Position = UDim2.new(dotX, -dotSize / 2, 0.5, -dotSize / 2)
		dot.BorderSizePixel = 0
		dot.ZIndex = 64
		dot.Parent = progressContainer
		Theme.applyCorner(dot, "full")

		local isDotClaimed = dotDay < claimedDay or (dotDay == claimedDay and not isClaim)
		if isDotClaimed then
			dot.BackgroundColor3 = Theme.SUCCESS
		else
			dot.BackgroundColor3 = Theme.BG_ELEVATED
			dot.BackgroundTransparency = 0.3
		end
	end

	-- === COUNTDOWN TIMER ===
	local timerY = progressY + 24
	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "CountdownTimer"
	timerLabel.Size = UDim2.new(1, -40, 0, 18)
	timerLabel.Position = UDim2.new(0, 20, 0, timerY)
	timerLabel.BackgroundTransparency = 1
	timerLabel.TextSize = 12
	timerLabel.Font = Enum.Font.Gotham
	timerLabel.ZIndex = 63
	timerLabel.Parent = panel

	if isClaim then
		timerLabel.Text = "Claim today's reward!"
		timerLabel.TextColor3 = COLORS.GOLD
	else
		timerLabel.TextColor3 = Theme.TEXT_MUTED
		local lastLogin = data.lastLoginTime or os.time()
		local cooldownSecs = (data.cooldownHours or 20) * 3600
		local nextClaimTime = lastLogin + cooldownSecs

		task.spawn(function()
			while timerLabel and timerLabel.Parent do
				local remaining = nextClaimTime - os.time()
				if remaining <= 0 then
					timerLabel.Text = "Reward available! Re-open to claim!"
					timerLabel.TextColor3 = COLORS.GOLD
					break
				end
				local hours = math.floor(remaining / 3600)
				local mins = math.floor((remaining % 3600) / 60)
				local secs = remaining % 60
				timerLabel.Text = string.format(
					"Next reward in %02d:%02d:%02d \u{2014} come back tomorrow! \u{1F319}",
					hours, mins, secs
				)
				task.wait(1)
			end
		end)
	end

	-- === ACTION BUTTON ===
	local actionBtn = Instance.new("TextButton")
	actionBtn.Name            = "ActionButton"
	actionBtn.Size            = UDim2.new(0, 160, 0, 40)
	actionBtn.Position        = UDim2.new(0.5, -80, 1, -52)
	actionBtn.BackgroundColor3 = isClaim and COLORS.GOLD or Theme.BG_ELEVATED
	actionBtn.BorderSizePixel = 0
	actionBtn.Text            = isClaim and "\u{2728}  CLAIM!" or "OK"
	actionBtn.TextColor3      = isClaim and Theme.TEXT_DARK or Theme.TEXT_MUTED
	actionBtn.TextSize        = 16
	actionBtn.Font            = Enum.Font.GothamBlack
	actionBtn.ZIndex          = 63
	actionBtn.Parent          = panel
	Theme.applyCorner(actionBtn, "sm")

	local btnGrad = Instance.new("UIGradient")
	btnGrad.Color = isClaim and ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.PRIMARY),
		ColorSequenceKeypoint.new(1, Theme.PRIMARY_DARK),
	}) or ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.BG_ELEVATED),
		ColorSequenceKeypoint.new(1, Theme.BG_BASE),
	})
	btnGrad.Rotation = 90
	btnGrad.Parent = actionBtn

	-- Glow stroke on action button
	local actionStroke = Instance.new("UIStroke")
	actionStroke.Color = isClaim and Theme.HUD_GLOW_GOLD or Theme.BG_ELEVATED
	actionStroke.Thickness = Theme.STROKE_THIN
	actionStroke.Transparency = 0.3
	actionStroke.Parent = actionBtn

	-- === ANIMATE IN ===
	TweenService:Create(overlay, TweenInfo.new(0.25), { BackgroundTransparency = 0.55 }):Play()
	TweenService:Create(panel, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.05,
		Position = UDim2.new(0.5, -250, 0.5, -180),
	}):Play()
	TweenService:Create(panelStroke, TweenInfo.new(0.35), { Transparency = 0.2 }):Play()

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
			Position = UDim2.new(0.5, -250, 0.5, -110),
		})
		out:Play()
		out.Completed:Connect(function()
			modalGui:Destroy()
		end)
	end

	actionBtn.MouseButton1Click:Connect(function()
		if isClaim then
			-- Flash button green
			actionBtn.Text = "\u{2713}  CLAIMED!"
			TweenService:Create(actionBtn, TweenInfo.new(0.2), {
				BackgroundColor3 = COLORS.GREEN,
				TextColor3       = Theme.TEXT_DARK,
			}):Play()
			btnGrad:Destroy()

			-- Show green overlay ON the day card
			if todayCard then
				local claimOverlay = Instance.new("Frame")
				claimOverlay.Size               = UDim2.new(1, 0, 1, 0)
				claimOverlay.BackgroundColor3   = COLORS.GREEN
				claimOverlay.BackgroundTransparency = 1
				claimOverlay.BorderSizePixel    = 0
				claimOverlay.ZIndex             = 70
				claimOverlay.Parent             = todayCard
				Theme.applyCorner(claimOverlay, "sm")

				local checkLbl = Instance.new("TextLabel")
				checkLbl.Size               = UDim2.new(1, 0, 0.6, 0)
				checkLbl.Position           = UDim2.new(0, 0, 0.1, 0)
				checkLbl.BackgroundTransparency = 1
				checkLbl.Text               = "\u{2713}"
				checkLbl.TextColor3         = Theme.TEXT_DARK
				checkLbl.TextSize           = 36
				checkLbl.Font               = Enum.Font.GothamBlack
				checkLbl.ZIndex             = 71
				checkLbl.Parent             = claimOverlay

				local claimedLbl = Instance.new("TextLabel")
				claimedLbl.Size               = UDim2.new(1, 0, 0.3, 0)
				claimedLbl.Position           = UDim2.new(0, 0, 0.7, 0)
				claimedLbl.BackgroundTransparency = 1
				claimedLbl.Text               = "CLAIMED!"
				claimedLbl.TextColor3         = Theme.TEXT_DARK
				claimedLbl.TextSize           = 9
				claimedLbl.Font               = Enum.Font.GothamBlack
				claimedLbl.ZIndex             = 71
				claimedLbl.Parent             = claimOverlay

				TweenService:Create(claimOverlay, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
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
			if modalGui and modalGui.Parent then close() end
		end)
	end
end

return DailyBonusUI
