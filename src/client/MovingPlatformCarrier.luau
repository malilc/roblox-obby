-- MovingPlatformCarrier: Client-side smooth platform movement + player carrying
-- Computes platform positions locally using the same deterministic formula as server
-- This eliminates network replication jitter for buttery smooth movement

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
	prevPosition: Vector3,
}

function MovingPlatformCarrier.new()
	local self = setmetatable({}, MovingPlatformCarrier)

	self._platforms = {} :: {PlatformData}
	self._lastPlatform = nil :: BasePart?
	self._lastPlatformPosition = nil :: Vector3?
	self._scanTime = 0

	-- RaycastParams: exclude local character
	self._rayParams = RaycastParams.new()
	self._rayParams.FilterType = Enum.RaycastFilterType.Exclude
	self._rayParams.FilterDescendantsInstances = {}

	-- Bind before character controller for smoothest result
	RunService:BindToRenderStep("MovingPlatformCarrier", Enum.RenderPriority.Character.Value - 1, function()
		self:_update()
	end)

	-- Update raycast filter when character spawns
	LocalPlayer.CharacterAdded:Connect(function(character)
		self._rayParams.FilterDescendantsInstances = { character }
		self._lastPlatform = nil
		self._lastPlatformPosition = nil
	end)

	if LocalPlayer.Character then
		self._rayParams.FilterDescendantsInstances = { LocalPlayer.Character }
	end

	return self
end

-- Scan workspace for new IsMoving parts (called periodically)
function MovingPlatformCarrier:_scanPlatforms()
	local known = {}
	for _, data in ipairs(self._platforms) do
		known[data.part] = true
	end

	-- Scan Stages folder and MatchInstances
	local folders = {}
	local stagesFolder = workspace:FindFirstChild("Stages")
	if stagesFolder then table.insert(folders, stagesFolder) end
	local matchFolder = workspace:FindFirstChild("MatchInstances")
	if matchFolder then table.insert(folders, matchFolder) end

	for _, folder in ipairs(folders) do
		for _, descendant in ipairs(folder:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant:GetAttribute("IsMoving") and not known[descendant] then
				local origPos = descendant:GetAttribute("OriginalPosition")
				if origPos then
					table.insert(self._platforms, {
						part = descendant,
						originalPosition = origPos,
						originalCFrame = CFrame.new(origPos) * (descendant.CFrame - descendant.CFrame.Position),
						axis = descendant:GetAttribute("MoveAxis") or "X",
						distance = descendant:GetAttribute("MoveDistance") or 10,
						speed = descendant:GetAttribute("MoveSpeed") or 3,
						prevPosition = descendant.Position,
					})
					known[descendant] = true
				end
			end
		end
	end

	-- Remove destroyed platforms
	local filtered = {}
	for _, data in ipairs(self._platforms) do
		if data.part.Parent then
			table.insert(filtered, data)
		end
	end
	self._platforms = filtered
end

function MovingPlatformCarrier:_update()
	local time = os.clock()

	-- Rescan platforms every 2 seconds
	if time - self._scanTime > 2 then
		self._scanTime = time
		self:_scanPlatforms()
	end

	-- Move all platforms locally (deterministic, smooth)
	for _, data in ipairs(self._platforms) do
		if data.part.Parent then
			data.prevPosition = data.part.Position

			local offset = math.sin(time * data.speed) * data.distance
			local moveVector
			if data.axis == "X" then
				moveVector = Vector3.new(offset, 0, 0)
			elseif data.axis == "Y" then
				moveVector = Vector3.new(0, offset, 0)
			else
				moveVector = Vector3.new(0, 0, offset)
			end

			local newPos = data.originalPosition + moveVector
			data.part.CFrame = data.originalCFrame - data.originalPosition + newPos
		end
	end

	-- Player carrying
	local character = LocalPlayer.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid or humanoid.Health <= 0 then
		self._lastPlatform = nil
		self._lastPlatformPosition = nil
		return
	end

	-- Only carry when grounded
	local state = humanoid:GetState()
	local grounded = (state == Enum.HumanoidStateType.Running
		or state == Enum.HumanoidStateType.RunningNoPhysics
		or state == Enum.HumanoidStateType.Landed)

	if not grounded then
		self._lastPlatform = nil
		self._lastPlatformPosition = nil
		return
	end

	-- Raycast down from feet
	local rayResult = workspace:Raycast(hrp.Position, Vector3.new(0, -5, 0), self._rayParams)

	if rayResult and rayResult.Instance:GetAttribute("IsMoving") then
		local platform = rayResult.Instance
		local currentPos = platform.Position

		if self._lastPlatform == platform and self._lastPlatformPosition then
			local delta = currentPos - self._lastPlatformPosition
			if delta.Magnitude > 0.001 then
				hrp.CFrame = hrp.CFrame + delta
			end
		end

		self._lastPlatform = platform
		self._lastPlatformPosition = currentPos
	else
		self._lastPlatform = nil
		self._lastPlatformPosition = nil
	end
end

function MovingPlatformCarrier:destroy()
	RunService:UnbindFromRenderStep("MovingPlatformCarrier")
end

return MovingPlatformCarrier
