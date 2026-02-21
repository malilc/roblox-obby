-- MapManager: จัดการการสุ่มและสร้าง Map

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StageTemplates = require(script.Parent.StageTemplates)

local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Logger)
local StageInfo = require(ReplicatedStorage.Shared.StageInfo)

local MapManager = {}
MapManager.__index = MapManager

-- Seed random เพื่อให้สุ่มได้จริง
math.randomseed(os.time() + os.clock() * 1000)

export type MatchMapData = {
	stages: {Model},
	stageOrder: {number},
	movingParts: {Part},
	spinningParts: {Part},
	disappearingParts: {{part: Part, touched: boolean, lastTouchTime: number}},
	animationConnection: RBXScriptConnection?,
	folder: Folder,
}

-- สร้าง MapManager ใหม่
function MapManager.new()
	local self = setmetatable({}, MapManager)

	-- Global map (for backwards compatibility / solo play)
	self.stagesFolder = workspace:WaitForChild("Stages")
	self.globalMap = {
		stages = {},
		stageOrder = {},
		movingParts = {},
		spinningParts = {},
		disappearingParts = {},
		animationConnection = nil,
		folder = self.stagesFolder,
	} :: MatchMapData

	-- Per-match map instances
	self.matchMaps = {} :: {[string]: MatchMapData}

	-- Create MatchInstances folder in workspace
	self.instancesFolder = workspace:FindFirstChild("MatchInstances")
	if not self.instancesFolder then
		self.instancesFolder = Instance.new("Folder")
		self.instancesFolder.Name = "MatchInstances"
		self.instancesFolder.Parent = workspace
	end

	return self
end

-- Fisher-Yates shuffle utility
local function shuffleArray(arr: {any})
	for i = #arr, 2, -1 do
		local j = math.random(1, i)
		arr[i], arr[j] = arr[j], arr[i]
	end
end

-- สุ่มลำดับ stages ทั้งหมด (utility, ไม่ balanced)
function MapManager:shuffleStages(): {number}
	local stages = {}
	for i = 1, Config.Stages.TotalCount do
		table.insert(stages, i)
	end
	shuffleArray(stages)
	return stages
end

-- สุ่มลำดับ stages แบบเฉลี่ยความยาก (balanced random)
function MapManager:balancedRandomStages(selectionCount: number?): {number}
	local count = selectionCount or Config.Stages.SelectionCount

	-- 1. แบ่ง pool ตาม difficulty
	local pools = { Easy = {}, Normal = {}, Hard = {} }
	for _, stage in ipairs(StageInfo.Stages) do
		table.insert(pools[stage.difficulty], stage.id)
	end

	-- 2. Shuffle แต่ละ pool
	for _, pool in pairs(pools) do
		shuffleArray(pool)
	end

	-- 3. การันตี MinPerDifficulty จากแต่ละระดับ
	local selected = {}
	local usedSet = {}
	local minPer = Config.Stages.BalancedRandom.MinPerDifficulty

	for _, difficulty in ipairs({"Easy", "Normal", "Hard"}) do
		local pool = pools[difficulty]
		local toTake = math.min(minPer, #pool)
		for i = 1, toTake do
			if #selected < count then
				local id = pool[i]
				table.insert(selected, id)
				usedSet[id] = true
			end
		end
	end

	-- 4. เติมที่เหลือจาก pool ที่ยังไม่ถูกเลือก
	local remaining = count - #selected
	if remaining > 0 then
		local remainingPool = {}
		for _, difficulty in ipairs({"Easy", "Normal", "Hard"}) do
			for _, id in ipairs(pools[difficulty]) do
				if not usedSet[id] then
					table.insert(remainingPool, id)
				end
			end
		end
		shuffleArray(remainingPool)

		for i = 1, math.min(remaining, #remainingPool) do
			table.insert(selected, remainingPool[i])
		end
	end

	-- 5. Shuffle ลำดับสุดท้าย
	shuffleArray(selected)

	Logger.debug("MapManager", "Balanced random stages:", table.concat(selected, ", "))
	return selected
end

-- ============================================
-- INTERNAL SHARED FUNCTIONS
-- ============================================

-- Internal: สร้าง Map ด้วย mapData + stageOrder
function MapManager:_generateMapInternal(mapData: MatchMapData, stageOrder: {number}, matchId: string?)
	mapData.stageOrder = stageOrder

	local stageCreators = StageTemplates.getStageCreators()
	local currentPosition = Config.Stages.StartOffset

	for index, stageNum in ipairs(stageOrder) do
		local creator = stageCreators[stageNum]
		if creator then
			local stage = creator(currentPosition)
			stage.Name = "Stage_" .. index .. "_Type" .. stageNum
			stage:SetAttribute("StageIndex", index)
			stage:SetAttribute("StageType", stageNum)
			if matchId then
				stage:SetAttribute("MatchId", matchId)
			end
			stage.Parent = mapData.folder

			table.insert(mapData.stages, stage)

			-- หา EndPart เพื่อคำนวณตำแหน่งถัดไป
			local endPart = stage:FindFirstChild("EndPart")
			if endPart then
				currentPosition = endPart.Position + Vector3.new(Config.Map.StageGapStuds, 0, 0) -- Gap between stages
			else
				currentPosition = currentPosition + Vector3.new(Config.Stages.StageLength + Config.Map.StageGapStuds, 0, 0)
			end

			-- Register animated parts
			self:_registerAnimatedPartsInternal(stage, mapData)
		end
	end

	-- Start animations
	self:_startAnimationsInternal(mapData)
end

-- Internal: ลงทะเบียน parts ที่ต้องมี animation
function MapManager:_registerAnimatedPartsInternal(stage: Model, mapData: MatchMapData)
	for _, descendant in ipairs(stage:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if descendant:GetAttribute("IsMoving") then
				table.insert(mapData.movingParts, descendant)
				-- เก็บตำแหน่งเริ่มต้น
				descendant:SetAttribute("OriginalPosition", descendant.Position)
				-- Setup moving platform ให้ unanchored + constraint
				self:_setupMovingPlatformConstraint(descendant)
			end

			if descendant:GetAttribute("IsSpinning") then
				table.insert(mapData.spinningParts, descendant)
			end

			if descendant:GetAttribute("IsDisappearing") then
				table.insert(mapData.disappearingParts, {
					part = descendant,
					touched = false,
					lastTouchTime = 0,
				})
				-- Setup touch detection
				self:_setupDisappearingPlatform(descendant, mapData)
			end
		end
	end
end

-- Internal: Setup moving platform ด้วย constraint (physics-based เพื่อไม่ลื่น)
function MapManager:_setupMovingPlatformConstraint(part: Part)
	local originalPos = part.Position
	local axis = part:GetAttribute("MoveAxis") or "X"
	local distance = part:GetAttribute("MoveDistance") or 10

	-- Unanchor เพื่อให้ physics ทำงาน
	part.Anchored = false

	-- สร้าง Attachment บน Part
	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "PlatformAttachment"
	attachment0.Parent = part

	-- สร้าง Attachment บน Workspace (จุดยึด)
	local anchorPart = Instance.new("Part")
	anchorPart.Name = "PlatformAnchor_" .. part.Name
	anchorPart.Anchored = true
	anchorPart.CanCollide = false
	anchorPart.Transparency = 1
	anchorPart.Size = Vector3.new(1, 1, 1)
	anchorPart.Position = originalPos
	anchorPart.Parent = part.Parent

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "AnchorAttachment"
	attachment1.Parent = anchorPart

	-- สร้าง PrismaticConstraint สำหรับเคลื่อนที่ตามแกน
	local prismatic = Instance.new("PrismaticConstraint")
	prismatic.Name = "MovementConstraint"
	prismatic.Attachment0 = attachment0
	prismatic.Attachment1 = attachment1
	prismatic.ActuatorType = Enum.ActuatorType.Servo
	prismatic.ServoMaxForce = Config.Map.PlatformServoForce
	prismatic.Speed = Config.Map.PlatformServoSpeed
	prismatic.LimitsEnabled = true
	prismatic.LowerLimit = -distance
	prismatic.UpperLimit = distance

	-- ตั้งแกนการเคลื่อนที่
	if axis == "X" then
		attachment1.Axis = Vector3.new(1, 0, 0)
	elseif axis == "Y" then
		attachment1.Axis = Vector3.new(0, 1, 0)
	else
		attachment1.Axis = Vector3.new(0, 0, 1)
	end

	prismatic.Parent = part

	-- เก็บ reference
	part:SetAttribute("_HasConstraint", true)
end

-- Internal: Setup disappearing platform
function MapManager:_setupDisappearingPlatform(part: Part, mapData: MatchMapData)
	part.Touched:Connect(function(hit)
		local humanoid = hit.Parent:FindFirstChild("Humanoid")
		if humanoid then
			for _, data in ipairs(mapData.disappearingParts) do
				if data.part == part and not data.touched then
					data.touched = true
					data.lastTouchTime = os.clock()

					local disappearDelay = part:GetAttribute("DisappearDelay") or 1.5
					local reappearDelay = part:GetAttribute("ReappearDelay") or 3

					-- Blink effect then disappear
					task.spawn(function()
						-- Blink warning
						for _ = 1, 3 do
							part.Transparency = 0.5
							task.wait(disappearDelay / 6)
							part.Transparency = 0
							task.wait(disappearDelay / 6)
						end

						-- Disappear
						part.Transparency = 1
						part.CanCollide = false

						-- Reappear
						task.wait(reappearDelay)
						part.Transparency = 0
						part.CanCollide = true
						data.touched = false
					end)

					break
				end
			end
		end
	end)
end

-- Internal: Start animations
function MapManager:_startAnimationsInternal(mapData: MatchMapData)
	-- หา Item Boxes ทั้งหมด
	local itemBoxes = {}
	for _, stage in ipairs(mapData.stages) do
		local itemPickups = stage:FindFirstChild("ItemPickups")
		if itemPickups then
			for _, box in ipairs(itemPickups:GetChildren()) do
				if box:IsA("BasePart") and (box:GetAttribute("IsItemBox") or box:GetAttribute("SpinSpeed")) then
					-- เก็บ original Y สำหรับ bobbing
					if not box:GetAttribute("OriginalY") then
						box:SetAttribute("OriginalY", box.Position.Y)
					end
					table.insert(itemBoxes, box)
				end
			end
		end
	end

	-- Animation loop
	mapData.animationConnection = RunService.Heartbeat:Connect(function(dt)
		local time = os.clock()

		-- Moving platforms (ใช้ PrismaticConstraint)
		for _, part in ipairs(mapData.movingParts) do
			if part.Parent then
				local prismatic = part:FindFirstChild("MovementConstraint")
				if prismatic and prismatic:IsA("PrismaticConstraint") then
					local distance = part:GetAttribute("MoveDistance") or 10
					local speed = part:GetAttribute("MoveSpeed") or 3

					-- คำนวณตำแหน่งเป้าหมาย (oscillate)
					local targetPosition = math.sin(time * speed) * distance
					prismatic.TargetPosition = targetPosition
				end
			end
		end

		-- Spinning parts (obstacles)
		for _, part in ipairs(mapData.spinningParts) do
			if part.Parent then
				local spinSpeed = part:GetAttribute("SpinSpeed") or 2
				part.CFrame = part.CFrame * CFrame.Angles(0, dt * spinSpeed, 0)
			end
		end

		-- Item Boxes: Spin + Bob (Neon Cube style)
		for _, box in ipairs(itemBoxes) do
			if box.Parent then
				local spinSpeed = box:GetAttribute("SpinSpeed") or 2
				local originalY = box:GetAttribute("OriginalY") or box.Position.Y

				-- Bobbing effect (ขยับขึ้นลง) + Spin
				local bobOffset = math.sin(time * 2) * 0.3
				local currentPos = box.Position

				box.CFrame = CFrame.new(currentPos.X, originalY + bobOffset, currentPos.Z) * CFrame.Angles(0, time * spinSpeed, 0)
			end
		end
	end)
end

-- Internal: Clear map data
function MapManager:_clearMapInternal(mapData: MatchMapData, destroyFolder: boolean?)
	-- Stop animations
	if mapData.animationConnection then
		mapData.animationConnection:Disconnect()
		mapData.animationConnection = nil
	end

	-- Clear stages (Destroy() automatically disconnects all Touched/event connections on each Part)
	for _, stage in ipairs(mapData.stages) do
		stage:Destroy()
	end

	mapData.stages = {}
	mapData.movingParts = {}
	mapData.spinningParts = {}
	mapData.disappearingParts = {}

	if destroyFolder and mapData.folder then
		mapData.folder:Destroy()
	end
end

-- Internal: Query helpers that operate on stages list
function MapManager._getCheckpointPositionFromStages(stages: {Model}, stageIndex: number): Vector3?
	local stage = stages[stageIndex]
	if stage then
		local checkpoint = stage:FindFirstChild("Checkpoint")
		if checkpoint then
			return checkpoint.Position + Vector3.new(0, 3, 0)
		end
	end
	return nil
end

function MapManager._getStageIndexFromPositionFromStages(stages: {Model}, position: Vector3): number?
	for index, stage in ipairs(stages) do
		local startPart = stage:FindFirstChild("StartPart")
		local endPart = stage:FindFirstChild("EndPart")

		if startPart and endPart then
			local startX = startPart.Position.X - 10
			local endX = endPart.Position.X + 10

			if position.X >= startX and position.X <= endX then
				return index
			end
		end
	end
	return nil
end

function MapManager._isAtFinishLineFromStages(stages: {Model}, position: Vector3): boolean
	local lastStage = stages[#stages]
	if lastStage then
		local endPart = lastStage:FindFirstChild("EndPart")
		if endPart then
			local distance = (position - endPart.Position).Magnitude
			return distance < Config.Map.FinishLineRadius
		end
	end
	return false
end

function MapManager._getFinishLinePositionFromStages(stages: {Model}): Vector3?
	local lastStage = stages[#stages]
	if lastStage then
		local endPart = lastStage:FindFirstChild("EndPart")
		if endPart then
			return endPart.Position
		end
	end
	return nil
end

function MapManager._getAllItemPickupsFromStages(stages: {Model}): {Part}
	local pickups = {}
	for _, stage in ipairs(stages) do
		local folder = stage:FindFirstChild("ItemPickups")
		if folder then
			for _, pickup in ipairs(folder:GetChildren()) do
				if pickup:IsA("BasePart") then
					table.insert(pickups, pickup)
				end
			end
		end
	end
	return pickups
end

function MapManager._getAllKillPartsFromStages(stages: {Model}): {Part}
	local killParts = {}
	for _, stage in ipairs(stages) do
		for _, descendant in ipairs(stage:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant:GetAttribute("IsKillPart") then
				table.insert(killParts, descendant)
			end
		end
	end
	return killParts
end

-- ============================================
-- GLOBAL MAP PUBLIC API
-- ============================================

-- สร้าง Map ใหม่
function MapManager:generateMap()
	local stageOrder = self:shuffleStages()
	self:generateMapWithOrder(stageOrder)
end

-- สร้าง Map ด้วยลำดับที่กำหนด
function MapManager:generateMapWithOrder(stageOrder: {number})
	self:clearMap()
	Logger.info("MapManager", "Stage order:", table.concat(stageOrder, ", "))
	self:_generateMapInternal(self.globalMap, stageOrder)
	Logger.info("MapManager", "Generated", #self.globalMap.stages, "stages")
end

-- Clear map
function MapManager:clearMap()
	self:_clearMapInternal(self.globalMap)
end

-- Get checkpoint position for stage
function MapManager:getCheckpointPosition(stageIndex: number): Vector3?
	return MapManager._getCheckpointPositionFromStages(self.globalMap.stages, stageIndex)
end

-- Get stage from position
function MapManager:getStageIndexFromPosition(position: Vector3): number?
	return MapManager._getStageIndexFromPositionFromStages(self.globalMap.stages, position)
end

-- Check if position is at finish line (stage สุดท้าย)
function MapManager:isAtFinishLine(position: Vector3): boolean
	return MapManager._isAtFinishLineFromStages(self.globalMap.stages, position)
end

-- Get finish line position
function MapManager:getFinishLinePosition(): Vector3?
	return MapManager._getFinishLinePositionFromStages(self.globalMap.stages)
end

-- Get all checkpoints
function MapManager:getAllCheckpoints(): {BasePart}
	local checkpoints = {}
	for _, stage in ipairs(self.globalMap.stages) do
		local checkpoint = stage:FindFirstChild("Checkpoint")
		if checkpoint and checkpoint:IsA("BasePart") then
			table.insert(checkpoints, checkpoint)
		end
	end
	return checkpoints
end

-- Get all item pickups
function MapManager:getAllItemPickups(): {Part}
	return MapManager._getAllItemPickupsFromStages(self.globalMap.stages)
end

-- Get all kill parts
function MapManager:getAllKillParts(): {Part}
	return MapManager._getAllKillPartsFromStages(self.globalMap.stages)
end

-- ============================================
-- PER-MATCH MAP PUBLIC API
-- ============================================

-- Generate map for a specific match (instanced)
function MapManager:generateMapForMatch(matchId: string, stageOrder: {number}): Folder
	-- Clear existing map for this match if any
	self:clearMapForMatch(matchId)

	-- Create folder for this match
	local matchFolder = Instance.new("Folder")
	matchFolder.Name = matchId
	matchFolder.Parent = self.instancesFolder

	-- Initialize match map data
	local matchData: MatchMapData = {
		stages = {},
		stageOrder = {},
		movingParts = {},
		spinningParts = {},
		disappearingParts = {},
		animationConnection = nil,
		folder = matchFolder,
	}

	Logger.info("MapManager", "Generating map for match:", matchId, "- Stage order:", table.concat(stageOrder, ", "))

	self:_generateMapInternal(matchData, stageOrder, matchId)

	self.matchMaps[matchId] = matchData

	Logger.info("MapManager", "Generated", #matchData.stages, "stages for match:", matchId)

	return matchFolder
end

-- Clear map for a specific match
function MapManager:clearMapForMatch(matchId: string)
	local matchData = self.matchMaps[matchId]
	if not matchData then return end

	self:_clearMapInternal(matchData, true)

	self.matchMaps[matchId] = nil
	Logger.info("MapManager", "Cleared map for match:", matchId)
end

-- Get match map data
function MapManager:getMatchMapData(matchId: string): MatchMapData?
	return self.matchMaps[matchId]
end

-- Get checkpoint position for a specific match
function MapManager:getCheckpointPositionForMatch(matchId: string, stageIndex: number): Vector3?
	local matchData = self.matchMaps[matchId]
	if not matchData then return nil end
	return MapManager._getCheckpointPositionFromStages(matchData.stages, stageIndex)
end

-- Get stage index from position for a specific match
function MapManager:getStageIndexFromPositionForMatch(matchId: string, position: Vector3): number?
	local matchData = self.matchMaps[matchId]
	if not matchData then return nil end
	return MapManager._getStageIndexFromPositionFromStages(matchData.stages, position)
end

-- Check if position is at finish line for a specific match
function MapManager:isAtFinishLineForMatch(matchId: string, position: Vector3): boolean
	local matchData = self.matchMaps[matchId]
	if not matchData then return false end
	return MapManager._isAtFinishLineFromStages(matchData.stages, position)
end

-- Get finish line position for a specific match
function MapManager:getFinishLinePositionForMatch(matchId: string): Vector3?
	local matchData = self.matchMaps[matchId]
	if not matchData then return nil end
	return MapManager._getFinishLinePositionFromStages(matchData.stages)
end

-- Get all item pickups for a specific match
function MapManager:getAllItemPickupsForMatch(matchId: string): {Part}
	local matchData = self.matchMaps[matchId]
	if not matchData then return {} end
	return MapManager._getAllItemPickupsFromStages(matchData.stages)
end

-- Get all kill parts for a specific match
function MapManager:getAllKillPartsForMatch(matchId: string): {Part}
	local matchData = self.matchMaps[matchId]
	if not matchData then return {} end
	return MapManager._getAllKillPartsFromStages(matchData.stages)
end

-- Get stage order for a specific match
function MapManager:getStageOrderForMatch(matchId: string): {number}
	local matchData = self.matchMaps[matchId]
	if matchData then
		return matchData.stageOrder
	end
	return {}
end

return MapManager
