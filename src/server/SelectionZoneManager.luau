-- SelectionZoneManager: จัดการ dual lobby zones (PVP Race + Time Trial)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Logger)

local SelectionZoneManager = {}
SelectionZoneManager.__index = SelectionZoneManager

export type SelectionZoneDeps = {
	getPlayerState: (player: Player) -> string?,
	mapManager: any,
	matchManager: any,
	showStageSelectionRemote: RemoteEvent,
	hideStageSelectionRemote: RemoteEvent,
	startGameWithOrder: (player: Player, stageOrder: {number}) -> (),
}

function SelectionZoneManager.new(deps: SelectionZoneDeps)
	local self = setmetatable({}, SelectionZoneManager)
	self.deps = deps
	self.playersInPvpZone = {} :: {[Player]: boolean}
	self.playersInTimeTrialZone = {} :: {[Player]: boolean}
	-- Singleton room per mode: max 1 active match per game mode
	self.activeRoomIds = { Race = nil :: string?, TimeTrial = nil :: string? }

	-- Billboard status label references
	self.statusLabels = {} :: {[string]: TextLabel} -- "Race" / "TimeTrial" -> TextLabel

	-- Register onRoomClosed callback in MatchManager
	if deps.matchManager then
		deps.matchManager.onRoomClosed = function(roomId: string)
			self:onRoomClosed(roomId)
		end
	end

	return self
end

-- Setup dual zone detection loop
function SelectionZoneManager:setup()
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then return end

	local pvpZone = lobby:FindFirstChild("PvpRaceZone")
	local ttZone = lobby:FindFirstChild("TimeTrialZone")

	-- Add billboard labels
	if pvpZone then
		self:addBillboard(pvpZone, "PVP RACE", Color3.fromRGB(255, 95, 85), "Race")
	end
	if ttZone then
		self:addBillboard(ttZone, "TIME TRIAL", Color3.fromRGB(0, 200, 255), "TimeTrial")
	end

	-- Detection loop for both zones
	local billboardUpdateTimer = 0
	task.spawn(function()
		while true do
			task.wait(Config.Timing.SelectionZoneInterval)

			-- Update billboard status every ~1 second
			billboardUpdateTimer = billboardUpdateTimer + Config.Timing.SelectionZoneInterval
			if billboardUpdateTimer >= 1 then
				billboardUpdateTimer = 0
				self:updateBillboardStatus("Race")
				self:updateBillboardStatus("TimeTrial")
			end

			for _, player in ipairs(Players:GetPlayers()) do
				local state = self.deps.getPlayerState(player)

				-- PVP Race Zone
				if pvpZone then
					local isInPvp = self:isPlayerInZone(player, pvpZone)
					local wasInPvp = self.playersInPvpZone[player]

					if isInPvp and not wasInPvp then
						if state == "Lobby" then
							self.playersInPvpZone[player] = true
							self:onPlayerEnterMode(player, "Race")
						end
					elseif not isInPvp and wasInPvp then
						self.playersInPvpZone[player] = nil
						self:onPlayerLeaveMode(player, "Race")
					end
				end

				-- Time Trial Zone
				if ttZone then
					local isInTT = self:isPlayerInZone(player, ttZone)
					local wasInTT = self.playersInTimeTrialZone[player]

					if isInTT and not wasInTT then
						if state == "Lobby" then
							self.playersInTimeTrialZone[player] = true
							self:onPlayerEnterMode(player, "TimeTrial")
						end
					elseif not isInTT and wasInTT then
						self.playersInTimeTrialZone[player] = nil
						self:onPlayerLeaveMode(player, "TimeTrial")
					end
				end
			end
		end
	end)
end

-- Add billboard label above zone
function SelectionZoneManager:addBillboard(zone: Part, text: string, color: Color3, gameMode: string)
	if zone:FindFirstChild("ZoneLabelBillboard") then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabelBillboard"
	billboard.Size = UDim2.new(0, 200, 0, 70)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = zone

	local label = Instance.new("TextLabel")
	label.Name = "TitleLabel"
	label.Size = UDim2.new(1, 0, 0, 30)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextSize = 24
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	-- Status line (shows "Step in to join!" / "Racing... X players" etc.)
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, 0, 0, 20)
	statusLabel.Position = UDim2.new(0, 0, 0, 32)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Step in to join!"
	statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	statusLabel.TextStrokeTransparency = 0.3
	statusLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	statusLabel.TextSize = 14
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.Parent = billboard

	self.statusLabels[gameMode] = statusLabel
end

-- Check if player is inside a zone bounding box
function SelectionZoneManager:isPlayerInZone(player: Player, zone: Part): boolean
	local character = player.Character
	if not character then return false end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return false end

	local playerPos = humanoidRootPart.Position
	local zonePos = zone.Position
	local zoneSize = zone.Size

	local halfSize = zoneSize / 2
	local minBound = zonePos - halfSize
	local maxBound = zonePos + halfSize

	return playerPos.X >= minBound.X and playerPos.X <= maxBound.X
		and playerPos.Y >= minBound.Y - 5 and playerPos.Y <= maxBound.Y + 10
		and playerPos.Z >= minBound.Z and playerPos.Z <= maxBound.Z
end

-- Player entered a mode zone
function SelectionZoneManager:onPlayerEnterMode(player: Player, gameMode: string)
	local matchManager = self.deps.matchManager
	local activeRoomId = self.activeRoomIds[gameMode]

	if activeRoomId then
		-- Room exists — check its state
		local room = matchManager:getRoom(activeRoomId)
		if room then
			if room.state == "Waiting" then
				-- Join existing waiting room
				local joined = matchManager:joinRoom(player, activeRoomId)
				if joined then
					self.deps.showStageSelectionRemote:FireClient(player, {
						gameMode = gameMode,
						playerCount = #room.players,
						roomId = activeRoomId,
					})
					Logger.debug("SelectionZoneManager", player.Name, "joined", gameMode, "room", activeRoomId)
					self:updateBillboardStatus(gameMode)
				end
			else
				-- Room is in progress (Starting/Racing/Finished)
				self.deps.showStageSelectionRemote:FireClient(player, {
					gameMode = gameMode,
					roomState = "InProgress",
				})
				Logger.debug("SelectionZoneManager", player.Name, "entered", gameMode, "zone but match in progress")
			end
		else
			-- Room was cleaned up, clear stale reference
			self.activeRoomIds[gameMode] = nil
			self:createNewRoom(player, gameMode)
		end
	else
		-- No active room — create one
		self:createNewRoom(player, gameMode)
	end
end

-- Create a new room for the mode
function SelectionZoneManager:createNewRoom(player: Player, gameMode: string)
	local matchManager = self.deps.matchManager
	local roomId = matchManager:createRoom(player, { gameMode = gameMode })
	if roomId then
		self.activeRoomIds[gameMode] = roomId
		matchManager:startWaitTimer(roomId)

		local room = matchManager:getRoom(roomId)
		self.deps.showStageSelectionRemote:FireClient(player, {
			gameMode = gameMode,
			playerCount = room and #room.players or 1,
			roomId = roomId,
		})
		Logger.debug("SelectionZoneManager", player.Name, "created", gameMode, "room", roomId)
		self:updateBillboardStatus(gameMode)
	end
end

-- Player left a mode zone
function SelectionZoneManager:onPlayerLeaveMode(player: Player, gameMode: string)
	self.deps.hideStageSelectionRemote:FireClient(player)

	local matchManager = self.deps.matchManager
	local activeRoomId = self.activeRoomIds[gameMode]

	if activeRoomId then
		local room = matchManager:getRoom(activeRoomId)
		if room and room.state == "Waiting" then
			-- Leave the room if still waiting
			matchManager:leaveRoom(player)

			-- Check if room is now empty
			local updatedRoom = matchManager:getRoom(activeRoomId)
			if not updatedRoom then
				self.activeRoomIds[gameMode] = nil
			end
		end
	end

	self:updateBillboardStatus(gameMode)
	Logger.debug("SelectionZoneManager", player.Name, "left", gameMode, "zone")
end

-- Called by MatchManager when a room is closed
function SelectionZoneManager:onRoomClosed(roomId: string)
	for mode, activeId in pairs(self.activeRoomIds) do
		if activeId == roomId then
			self.activeRoomIds[mode] = nil
			self:updateBillboardStatus(mode)
			Logger.debug("SelectionZoneManager", "Cleared", mode, "singleton room", roomId)
			break
		end
	end
end

-- Update billboard status text for a mode
function SelectionZoneManager:updateBillboardStatus(gameMode: string)
	local statusLabel = self.statusLabels[gameMode]
	if not statusLabel then return end

	local activeRoomId = self.activeRoomIds[gameMode]
	if not activeRoomId then
		statusLabel.Text = "Step in to join!"
		statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		return
	end

	local room = self.deps.matchManager:getRoom(activeRoomId)
	if not room then
		statusLabel.Text = "Step in to join!"
		statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		return
	end

	if room.state == "Waiting" then
		statusLabel.Text = "Waiting... " .. #room.players .. " player" .. (if #room.players > 1 then "s" else "")
		statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	elseif room.state == "Starting" or room.state == "Racing" then
		statusLabel.Text = "Racing! " .. #room.players .. " player" .. (if #room.players > 1 then "s" else "")
		statusLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
	elseif room.state == "Finished" then
		statusLabel.Text = "Finishing up..."
		statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	end
end

-- Validate stage order from client input
function SelectionZoneManager:validateStageOrder(stageOrder: any): {number}?
	if type(stageOrder) ~= "table" then return nil end
	if #stageOrder == 0 or #stageOrder > Config.Stages.SelectionCount then return nil end

	local seen = {}
	for _, stageNum in ipairs(stageOrder) do
		if type(stageNum) ~= "number" then return nil end
		stageNum = math.floor(stageNum)
		if stageNum < 1 or stageNum > Config.Stages.TotalCount then return nil end
		if seen[stageNum] then return nil end
		seen[stageNum] = true
	end

	return stageOrder
end

-- Cleanup when player leaves the game
function SelectionZoneManager:removePlayer(player: Player)
	-- If player was in a zone, handle leave
	if self.playersInPvpZone[player] then
		self.playersInPvpZone[player] = nil
		self:onPlayerLeaveMode(player, "Race")
	end
	if self.playersInTimeTrialZone[player] then
		self.playersInTimeTrialZone[player] = nil
		self:onPlayerLeaveMode(player, "TimeTrial")
	end
end

return SelectionZoneManager
