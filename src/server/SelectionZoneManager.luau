-- SelectionZoneManager: จัดการ lobby selection zone

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Logger)

local SelectionZoneManager = {}
SelectionZoneManager.__index = SelectionZoneManager

export type SelectionZoneDeps = {
	getPlayerState: (player: Player) -> string?,
	mapManager: any,
	showStageSelectionRemote: RemoteEvent,
	hideStageSelectionRemote: RemoteEvent,
	startGameWithOrder: (player: Player, stageOrder: {number}) -> (),
}

function SelectionZoneManager.new(deps: SelectionZoneDeps)
	local self = setmetatable({}, SelectionZoneManager)
	self.deps = deps
	self.playersInSelectionZone = {} :: {[Player]: boolean}
	return self
end

-- Setup selection zone detection loop
function SelectionZoneManager:setup()
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then return end

	local selectionZone = lobby:FindFirstChild("SelectionZone")
	if not selectionZone then return end

	-- Add "Select Stage" Label
	if not selectionZone:FindFirstChild("StageLabelBillboard") then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "StageLabelBillboard"
		billboard.Size = UDim2.new(0, 200, 0, 50)
		billboard.StudsOffset = Vector3.new(0, 5, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = selectionZone

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = "SELECT STAGE"
		label.TextColor3 = Color3.fromRGB(100, 200, 255)
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
		label.TextSize = 24
		label.Font = Enum.Font.GothamBold
		label.Parent = billboard
	end

	task.spawn(function()
		while true do
			task.wait(Config.Timing.SelectionZoneInterval)

			for _, player in ipairs(Players:GetPlayers()) do
				local isInZone = self:isPlayerInZone(player, selectionZone)
				local wasInZone = self.playersInSelectionZone[player]

				if isInZone and not wasInZone then
					if self.deps.getPlayerState(player) == "Lobby" then
						self.playersInSelectionZone[player] = true
						self:onPlayerEnter(player)
					end
				elseif not isInZone and wasInZone then
					self.playersInSelectionZone[player] = nil
					self:onPlayerLeave(player)
				end
			end
		end
	end)
end

-- Check if player is inside the selection zone bounding box
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

-- Player entered selection zone
function SelectionZoneManager:onPlayerEnter(player: Player)
	self.deps.showStageSelectionRemote:FireClient(player)
	Logger.debug("SelectionZoneManager", player.Name, "entered selection zone")
end

-- Player left selection zone
function SelectionZoneManager:onPlayerLeave(player: Player)
	self.deps.hideStageSelectionRemote:FireClient(player)
	Logger.debug("SelectionZoneManager", player.Name, "left selection zone")
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

-- Handle stage selection confirmation from client
function SelectionZoneManager:onStageSelectionConfirmed(player: Player, data: any)
	local state = self.deps.getPlayerState(player)
	if state ~= "Lobby" then return end

	if type(data) ~= "table" then
		Logger.warn("SelectionZoneManager", "Invalid data from", player.Name)
		return
	end

	local stageOrder: {number}

	if data.isRandom == true then
		stageOrder = self.deps.mapManager:balancedRandomStages()
	elseif data.stageOrder then
		local validated = self:validateStageOrder(data.stageOrder)
		if not validated then
			Logger.warn("SelectionZoneManager", "Invalid stageOrder from", player.Name)
			return
		end
		stageOrder = validated
	else
		stageOrder = self.deps.mapManager.globalMap.stageOrder
	end

	self.deps.hideStageSelectionRemote:FireClient(player)
	self.deps.startGameWithOrder(player, stageOrder)
end

-- Cleanup when player leaves
function SelectionZoneManager:removePlayer(player: Player)
	self.playersInSelectionZone[player] = nil
end

return SelectionZoneManager
