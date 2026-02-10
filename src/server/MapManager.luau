-- MapManager: จัดการการสุ่มและสร้าง Map

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StageTemplates = require(script.Parent.StageTemplates)

local Config = require(ReplicatedStorage.Shared.Config)

local MapManager = {}
MapManager.__index = MapManager

-- Seed random เพื่อให้สุ่มได้จริง
math.randomseed(os.time() + os.clock() * 1000)

-- สร้าง MapManager ใหม่
function MapManager.new()
	local self = setmetatable({}, MapManager)
	
	self.currentStages = {} :: {Model}
	self.stageOrder = {} :: {number}
	self.stagesFolder = workspace:WaitForChild("Stages")
	self.movingParts = {} :: {Part}
	self.spinningParts = {} :: {Part}
	self.disappearingParts = {} :: {{part: Part, touched: boolean, lastTouchTime: number}}
	
	return self
end

-- สุ่มลำดับ stages
function MapManager:shuffleStages(): {number}
	local stages = {}
	for i = 1, Config.Stages.Count do
		table.insert(stages, i)
	end
	
	-- Fisher-Yates shuffle
	for i = #stages, 2, -1 do
		local j = math.random(1, i)
		stages[i], stages[j] = stages[j], stages[i]
	end
	
	return stages
end

-- สร้าง Map ใหม่
function MapManager:generateMap()
	-- สุ่มลำดับ
	self.stageOrder = self:shuffleStages()
	self:generateMapWithOrder(self.stageOrder)
end

-- สร้าง Map ด้วยลำดับที่กำหนด
function MapManager:generateMapWithOrder(stageOrder: {number})
	-- Clear existing stages
	self:clearMap()
	
	-- ใช้ลำดับที่กำหนด
	self.stageOrder = stageOrder
	print("[MapManager] Stage order:", table.concat(self.stageOrder, ", "))
	
	local stageCreators = StageTemplates.getStageCreators()
	local currentPosition = Config.Stages.StartOffset
	
	for index, stageNum in ipairs(self.stageOrder) do
		local creator = stageCreators[stageNum]
		if creator then
			local stage = creator(currentPosition)
			stage.Name = "Stage_" .. index .. "_Type" .. stageNum
			stage:SetAttribute("StageIndex", index)
			stage:SetAttribute("StageType", stageNum)
			stage.Parent = self.stagesFolder
			
			table.insert(self.currentStages, stage)
			
			-- หา EndPart เพื่อคำนวณตำแหน่งถัดไป
			local endPart = stage:FindFirstChild("EndPart")
			if endPart then
				currentPosition = endPart.Position + Vector3.new(10, 0, 0) -- Gap between stages
			else
				currentPosition = currentPosition + Vector3.new(Config.Stages.StageLength + 10, 0, 0)
			end
			
			-- Register animated parts
			self:registerAnimatedParts(stage)
		end
	end
	
	-- Start animations
	self:startAnimations()
	
	print("[MapManager] Generated " .. #self.currentStages .. " stages")
end

-- ลงทะเบียน parts ที่ต้องมี animation
function MapManager:registerAnimatedParts(stage: Model)
	for _, descendant in ipairs(stage:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if descendant:GetAttribute("IsMoving") then
				table.insert(self.movingParts, descendant)
				-- เก็บตำแหน่งเริ่มต้น
				descendant:SetAttribute("OriginalPosition", descendant.Position)
				-- Setup moving platform ให้ unanchored + constraint
				self:setupMovingPlatformConstraint(descendant)
			end
			
			if descendant:GetAttribute("IsSpinning") then
				table.insert(self.spinningParts, descendant)
			end
			
			if descendant:GetAttribute("IsDisappearing") then
				table.insert(self.disappearingParts, {
					part = descendant,
					touched = false,
					lastTouchTime = 0,
				})
				-- Setup touch detection
				self:setupDisappearingPlatform(descendant)
			end
		end
	end
end

-- Setup moving platform ด้วย constraint (physics-based เพื่อไม่ลื่น)
function MapManager:setupMovingPlatformConstraint(part: Part)
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
	prismatic.ServoMaxForce = 1000000
	prismatic.Speed = 50
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

-- Setup disappearing platform
function MapManager:setupDisappearingPlatform(part: Part)
	part.Touched:Connect(function(hit)
		local humanoid = hit.Parent:FindFirstChild("Humanoid")
		if humanoid then
			-- Find in disappearingParts
			for _, data in ipairs(self.disappearingParts) do
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

-- Start animations
function MapManager:startAnimations()
	-- หา Item Boxes ทั้งหมด
	local itemBoxes = {}
	for _, stage in ipairs(self.currentStages) do
		local itemPickups = stage:FindFirstChild("ItemPickups")
		if itemPickups then
			for _, box in ipairs(itemPickups:GetChildren()) do
				if box:GetAttribute("IsItemBox") or box:GetAttribute("SpinSpeed") then
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
	self.animationConnection = RunService.Heartbeat:Connect(function(dt)
		local time = os.clock()
		
		-- Moving platforms (ใช้ PrismaticConstraint)
		for _, part in ipairs(self.movingParts) do
			local prismatic = part:FindFirstChild("MovementConstraint")
			if prismatic and prismatic:IsA("PrismaticConstraint") then
				local distance = part:GetAttribute("MoveDistance") or 10
				local speed = part:GetAttribute("MoveSpeed") or 3
				
				-- คำนวณตำแหน่งเป้าหมาย (oscillate)
				local targetPosition = math.sin(time * speed) * distance
				prismatic.TargetPosition = targetPosition
			end
		end
		
		-- Spinning parts (obstacles)
		for _, part in ipairs(self.spinningParts) do
			local spinSpeed = part:GetAttribute("SpinSpeed") or 2
			part.CFrame = part.CFrame * CFrame.Angles(0, dt * spinSpeed, 0)
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

-- Clear map
function MapManager:clearMap()
	-- Stop animations
	if self.animationConnection then
		self.animationConnection:Disconnect()
		self.animationConnection = nil
	end
	
	-- Clear stages (Destroy() automatically disconnects all Touched/event connections on each Part)
	for _, stage in ipairs(self.currentStages) do
		stage:Destroy()
	end
	
	self.currentStages = {}
	self.movingParts = {}
	self.spinningParts = {}
	self.disappearingParts = {}
end

-- Get checkpoint position for stage
function MapManager:getCheckpointPosition(stageIndex: number): Vector3?
	local stage = self.currentStages[stageIndex]
	if stage then
		local checkpoint = stage:FindFirstChild("Checkpoint")
		if checkpoint then
			return checkpoint.Position + Vector3.new(0, 3, 0)
		end
	end
	return nil
end

-- Get stage from position
function MapManager:getStageIndexFromPosition(position: Vector3): number?
	for index, stage in ipairs(self.currentStages) do
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

-- Check if position is at finish line (stage สุดท้าย)
function MapManager:isAtFinishLine(position: Vector3): boolean
	local lastStage = self.currentStages[#self.currentStages]
	if lastStage then
		local endPart = lastStage:FindFirstChild("EndPart")
		if endPart then
			-- ตรวจสอบว่าอยู่บน EndPart ของ stage สุดท้าย
			local distance = (position - endPart.Position).Magnitude
			return distance < 20
		end
	end
	return false
end

-- Get finish line position
function MapManager:getFinishLinePosition(): Vector3?
	local lastStage = self.currentStages[#self.currentStages]
	if lastStage then
		local endPart = lastStage:FindFirstChild("EndPart")
		if endPart then
			return endPart.Position
		end
	end
	return nil
end

-- Get all checkpoints
function MapManager:getAllCheckpoints(): {BasePart}
	local checkpoints = {}
	for _, stage in ipairs(self.currentStages) do
		local checkpoint = stage:FindFirstChild("Checkpoint")
		if checkpoint and checkpoint:IsA("BasePart") then
			table.insert(checkpoints, checkpoint)
		end
	end
	return checkpoints
end

-- Get all item pickups
function MapManager:getAllItemPickups(): {Part}
	local pickups = {}
	for _, stage in ipairs(self.currentStages) do
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

-- Get all kill parts
function MapManager:getAllKillParts(): {Part}
	local killParts = {}
	for _, stage in ipairs(self.currentStages) do
		for _, descendant in ipairs(stage:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant:GetAttribute("IsKillPart") then
				table.insert(killParts, descendant)
			end
		end
	end
	return killParts
end

return MapManager
