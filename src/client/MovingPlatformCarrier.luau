-- MovingPlatformCarrier: Client-side smooth platform movement + player carrying
-- Uses workspace:GetServerTimeNow() for synchronized time with server
-- Two-phase render step:
--   1) Move platforms + bananas BEFORE character controller
--   2) Carry player AFTER character controller

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local MovingPlatformCarrier = {}
MovingPlatformCarrier.__index = MovingPlatformCarrier

type PlatformData = {
	part: BasePart,
	originalPosition: Vector3,
	originalCFrame: CFrame,
	axis: string,
	distance: number,
	speed: number,
}

type AttachedBananaData = {
	banana: BasePart,
	platformOrigPos: Vector3,
	axis: string,
	moveDistance: number,
	moveSpeed: number,
	offset: Vector3,
}

function MovingPlatformCarrier.new()
	local self = setmetatable({}, MovingPlatformCarrier)

	self._platforms = {} :: {PlatformData}
	self._bananas = {} :: {AttachedBananaData}
	self._platformDelta = {} :: {[BasePart]: Vector3}
	self._lastPlatform = nil :: BasePart?
	self._scanTime = 0

	-- RaycastParams: exclude local character
	self._rayParams = RaycastParams.new()
	self._rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self._rayParams.FilterDescendantsInstances = {}

	-- Phase 1: Move platforms + bananas BEFORE character controller
	RunService:BindToRenderStep("MovingPlatform_Move", Enum.RenderPriority.Character.Value - 1, function()
		self:_movePlatforms()
	end)

	-- Phase 2: Carry player AFTER character controller
	RunService:BindToRenderStep("MovingPlatform_Carry", Enum.RenderPriority.Character.Value + 1, function()
		self:_carryPlayer()
	end)

	-- Update raycast filter when character spawns
	LocalPlayer.CharacterAdded:Connect(function(character)
		self._rayParams.FilterDescendantsInstances = { character }
		self._lastPlatform = nil
	end)

	if LocalPlayer.Character then
		self._rayParams.FilterDescendantsInstances = { LocalPlayer.Character }
	end

	return self
end

-- Compute platform position from params + syncTime
local function computePlatformPos(origPos: Vector3, axis: string, distance: number, speed: number, syncTime: number, phase: number?): Vector3
	local offset = math.sin(syncTime * speed + (phase or 0)) * distance
	if axis == "X" then
		return origPos + Vector3.new(offset, 0, 0)
	elseif axis == "Y" then
		return origPos + Vector3.new(0, offset, 0)
	else
		return origPos + Vector3.new(0, 0, offset)
	end
end

-- Scan workspace for IsMoving parts and attached bananas
function MovingPlatformCarrier:_scanPlatforms()
	local knownPlatforms = {}
	for _, data in ipairs(self._platforms) do
		knownPlatforms[data.part] = true
	end

	-- Scan Stages folder and MatchInstances for platforms
	local folders = {}
	local stagesFolder = workspace:FindFirstChild("Stages")
	if stagesFolder then table.insert(folders, stagesFolder) end
	local matchFolder = workspace:FindFirstChild("MatchInstances")
	if matchFolder then table.insert(folders, matchFolder) end

	for _, folder in ipairs(folders) do
		for _, descendant in ipairs(folder:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant:GetAttribute("IsMoving") and not knownPlatforms[descendant] then
				local origPos = descendant:GetAttribute("OriginalPosition")
				if origPos then
					table.insert(self._platforms, {
						part = descendant,
						originalPosition = origPos,
						originalCFrame = CFrame.new(origPos) * (descendant.CFrame - descendant.CFrame.Position),
						axis = descendant:GetAttribute("MoveAxis") or "X",
						distance = descendant:GetAttribute("MoveDistance") or 10,
						speed = descendant:GetAttribute("MoveSpeed") or 3,
						phase = descendant:GetAttribute("MovePhase") or 0,
					})
					knownPlatforms[descendant] = true
				end
			end
		end
	end

	-- Scan workspace for bananas attached to platforms
	local knownBananas = {}
	for _, data in ipairs(self._bananas) do
		knownBananas[data.banana] = true
	end

	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("BasePart") and child.Name == "Banana" and not knownBananas[child] then
			local platOrigPos = child:GetAttribute("_PlatformOrigPos")
			if platOrigPos then
				table.insert(self._bananas, {
					banana = child,
					platformOrigPos = platOrigPos,
					axis = child:GetAttribute("_PlatformAxis") or "X",
					moveDistance = child:GetAttribute("_PlatformMoveDistance") or 10,
					moveSpeed = child:GetAttribute("_PlatformMoveSpeed") or 3,
					offset = child:GetAttribute("_PlatformOffset") or Vector3.new(0, 1, 0),
				})
				knownBananas[child] = true
			end
		end
	end

	-- Remove destroyed entries
	local filteredP = {}
	for _, data in ipairs(self._platforms) do
		if data.part.Parent then table.insert(filteredP, data) end
	end
	self._platforms = filteredP

	local filteredB = {}
	for _, data in ipairs(self._bananas) do
		if data.banana.Parent then table.insert(filteredB, data) end
	end
	self._bananas = filteredB
end

-- Phase 1: Move platforms + bananas (before character controller)
function MovingPlatformCarrier:_movePlatforms()
	local syncTime = workspace:GetServerTimeNow()

	-- Rescan every 2 seconds
	local time = os.clock()
	if time - self._scanTime > 2 then
		self._scanTime = time
		self:_scanPlatforms()
	end

	-- Clear deltas
	self._platformDelta = {}

	-- Move all platforms locally
	for _, data in ipairs(self._platforms) do
		if data.part.Parent then
			local prevPos = data.part.Position
			local newPos = computePlatformPos(data.originalPosition, data.axis, data.distance, data.speed, syncTime, data.phase)
			data.part.CFrame = data.originalCFrame - data.originalPosition + newPos
			self._platformDelta[data.part] = data.part.Position - prevPos
		end
	end

	-- Move attached bananas locally
	for _, data in ipairs(self._bananas) do
		if data.banana.Parent then
			local platPos = computePlatformPos(data.platformOrigPos, data.axis, data.moveDistance, data.moveSpeed, syncTime)
			data.banana.Position = platPos + data.offset
		end
	end
end

-- Phase 2: Carry player (after character controller)
function MovingPlatformCarrier:_carryPlayer()
	local character = LocalPlayer.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid or humanoid.Health <= 0 then
		self._lastPlatform = nil
		return
	end

	-- Only carry when grounded
	local state = humanoid:GetState()
	local grounded = (state == Enum.HumanoidStateType.Running
		or state == Enum.HumanoidStateType.RunningNoPhysics
		or state == Enum.HumanoidStateType.Landed)

	if not grounded then
		self._lastPlatform = nil
		return
	end

	-- Raycast down from feet
	local rayResult = workspace:Raycast(hrp.Position, Vector3.new(0, -5, 0), self._rayParams)

	if rayResult and rayResult.Instance:GetAttribute("IsMoving") then
		local platform = rayResult.Instance
		local delta = self._platformDelta[platform]

		if self._lastPlatform == platform and delta and delta.Magnitude > 0.001 then
			hrp.CFrame = hrp.CFrame + delta
		end

		self._lastPlatform = platform
	else
		self._lastPlatform = nil
	end
end

function MovingPlatformCarrier:destroy()
	RunService:UnbindFromRenderStep("MovingPlatform_Move")
	RunService:UnbindFromRenderStep("MovingPlatform_Carry")
end

return MovingPlatformCarrier
