-- Stage Templates Generator
-- สร้าง 7 ด่านสำหรับ Obby (1 Easy + 2 Normal + 4 Hard)

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local StageTemplates = {}

local STAGE_LENGTH = Config.Stages.StageLength
local PLATFORM_HEIGHT = 0

-- Helper function สร้าง Part
local function createPart(properties: {[string]: any}): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Material = Enum.Material.Concrete
	
	-- เพิ่ม Friction สูงเพื่อไม่ให้ลื่น
	part.CustomPhysicalProperties = PhysicalProperties.new(
		0.7,  -- Density
		2.0,  -- Friction (สูง = ไม่ลื่น)
		0.1,  -- Elasticity (ต่ำ = ไม่เด้ง)
		1.0,  -- FrictionWeight
		0.5   -- ElasticityWeight
	)
	
	for key, value in pairs(properties) do
		(part :: any)[key] = value
	end
	
	return part
end

-- Helper function สร้าง Checkpoint (ใช้ Part แทน SpawnLocation เพื่อไม่ให้เป็นจุดเกิดเริ่มต้น)
local function createCheckpoint(position: Vector3): Part
	local checkpoint = Instance.new("Part")
	checkpoint.Name = "Checkpoint"
	checkpoint.Anchored = true
	checkpoint.Size = Vector3.new(6, 1, 6)
	checkpoint.Position = position
	checkpoint.Material = Enum.Material.SmoothPlastic
	checkpoint.Color = Color3.fromRGB(0, 255, 127)
	checkpoint.CanCollide = true
	
	-- เพิ่ม Friction สูงเพื่อไม่ให้ลื่น
	checkpoint.CustomPhysicalProperties = PhysicalProperties.new(
		0.7,  -- Density
		2.0,  -- Friction
		0.1,  -- Elasticity
		1.0,  -- FrictionWeight
		0.5   -- ElasticityWeight
	)
	
	return checkpoint
end

-- Pre-load Lucky Block model template (asset 129696127925672)
local _luckyBlockTemplate: Model? = nil
local function getLuckyBlockTemplate(): Model?
	if _luckyBlockTemplate then return _luckyBlockTemplate end
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(129696127925672)
	end)
	if ok and asset then
		local model = asset:FindFirstChildWhichIsA("Model")
		if model then
			-- Strip scripts, prompts, and other unwanted objects
			for _, desc in model:GetDescendants() do
				if desc:IsA("BaseScript") or desc:IsA("ProximityPrompt") or desc:IsA("ClickDetector") then
					desc:Destroy()
				end
			end
			model.Parent = nil
			_luckyBlockTemplate = model
			asset:Destroy()
		end
	else
		warn("[StageTemplates] Failed to load Lucky Block asset: " .. tostring(asset))
	end
	return _luckyBlockTemplate
end

-- Helper function สร้าง Item Box (Lucky Block Model)
local function createItemPickup(position: Vector3): Part
	-- Invisible hitbox Part (anchor for animation + touch detection)
	local pickup = Instance.new("Part")
	pickup.Name = "ItemBox"
	pickup.Anchored = true
	pickup.CanCollide = false
	pickup.Size = Vector3.new(3, 3, 3)
	pickup.Transparency = 1

	local raisedPosition = position + Vector3.new(0, 3, 0)
	pickup.Position = raisedPosition

	-- Attach Lucky Block model
	local template = getLuckyBlockTemplate()
	if template then
		local model = template:Clone()
		-- Scale and position the model to fit the hitbox
		model:PivotTo(CFrame.new(raisedPosition))
		model.Parent = pickup

		-- Weld all parts to the anchor so they follow animation
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = false
				part.CanCollide = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = pickup
				weld.Part1 = part
				weld.Parent = part
			end
		end
	else
		-- Fallback: visible yellow box if model failed to load
		pickup.Transparency = 0
		pickup.Material = Enum.Material.SmoothPlastic
		pickup.Color = Color3.fromRGB(255, 200, 40)
	end

	-- Subtle sparkle particles
	local particles = Instance.new("ParticleEmitter")
	particles.Lifetime = NumberRange.new(0.4, 0.8)
	particles.Rate = 6
	particles.Speed = NumberRange.new(1, 2)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0)
	})
	particles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 100)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 50)),
	})
	particles.LightEmission = 0.8
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	particles.Parent = pickup

	-- Soft warm glow
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 80)
	light.Brightness = 1
	light.Range = 8
	light.Parent = pickup

	-- Item Box attributes
	pickup:SetAttribute("IsItemBox", true)
	pickup:SetAttribute("IsCoin", false)
	pickup:SetAttribute("SpinSpeed", 2)
	pickup:SetAttribute("OriginalY", raisedPosition.Y)

	return pickup
end

-- Stage 1: Jump Platforms (ง่าย)
function StageTemplates.createStage1(startPosition: Vector3): Model
	local stage = Instance.new("Model")
	stage.Name = "Stage1_JumpPlatforms"
	
	-- Start Part (จุดเริ่มต้น)
	local startPart = createPart({
		Name = "StartPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition,
		Color = Color3.fromRGB(100, 200, 100),
	})
	startPart.Parent = stage
	
	-- Checkpoint
	local checkpoint = createCheckpoint(startPosition + Vector3.new(0, 1.5, 0))
	checkpoint.Parent = stage
	
	-- Obstacles folder
	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = stage
	
	-- ItemPickups folder
	local itemPickups = Instance.new("Folder")
	itemPickups.Name = "ItemPickups"
	itemPickups.Parent = stage
	
	-- สร้าง platforms
	local platformCount = 8
	local spacing = STAGE_LENGTH / (platformCount + 1)
	
	for i = 1, platformCount do
		local offset = Vector3.new(
			spacing * i,
			math.random(-5, 5),
			math.random(-2, 3)
		)
		local platform = createPart({
			Name = "Platform_" .. i,
			Size = Vector3.new(6, 1, 6),
			Position = startPosition + offset,
			Color = Color3.fromRGB(80, 150, 200),
		})
		platform.Parent = obstacles
	end
	
	-- Stage 1: 3 coins - กระจายตามเส้นทาง
	local coin1 = createItemPickup(startPosition + Vector3.new(STAGE_LENGTH * 0.25, 3, 0))
	coin1.Parent = itemPickups
	
	local coin2 = createItemPickup(startPosition + Vector3.new(STAGE_LENGTH * 0.5, 5, 2))
	coin2.Parent = itemPickups
	
	local coin3 = createItemPickup(startPosition + Vector3.new(STAGE_LENGTH * 0.75, 4, -1))
	coin3.Parent = itemPickups
	
	-- End Part (จุดสิ้นสุด)
	local endPart = createPart({
		Name = "EndPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition + Vector3.new(STAGE_LENGTH, 0, 0),
		Color = Color3.fromRGB(100, 200, 100),
	})
	endPart.Parent = stage
	
	return stage
end

-- Stage 2: Moving Platforms
function StageTemplates.createStage2(startPosition: Vector3): Model
	local stage = Instance.new("Model")
	stage.Name = "Stage2_MovingPlatforms"
	
	-- Start Part
	local startPart = createPart({
		Name = "StartPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition,
		Color = Color3.fromRGB(200, 150, 100),
	})
	startPart.Parent = stage
	
	-- Checkpoint
	local checkpoint = createCheckpoint(startPosition + Vector3.new(0, 1.5, 0))
	checkpoint.Parent = stage
	
	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = stage
	
	local itemPickups = Instance.new("Folder")
	itemPickups.Name = "ItemPickups"
	itemPickups.Parent = stage
	
	-- สร้าง moving platforms
	local platformCount = 6
	local spacing = STAGE_LENGTH / (platformCount + 1)
	
	for i = 1, platformCount do
		local platform = createPart({
			Name = "MovingPlatform_" .. i,
			Size = Vector3.new(8, 1, 8),
			Position = startPosition + Vector3.new(spacing * i, 0, 0),
			Color = Color3.fromRGB(255, 165, 0),
		})
		
		-- เพิ่ม attribute สำหรับ movement
		platform:SetAttribute("IsMoving", true)
		platform:SetAttribute("MoveAxis", if i % 2 == 0 then "X" else "Z")
		platform:SetAttribute("MoveDistance", 6)
		platform:SetAttribute("MoveSpeed", 2)
		
		platform.Parent = obstacles
	end
	
	-- Stage 2: 4 coins - บน moving platforms
	local coin1 = createItemPickup(startPosition + Vector3.new(spacing * 1, 5, 0))
	coin1.Parent = itemPickups
	
	local coin2 = createItemPickup(startPosition + Vector3.new(spacing * 3, 6, 2))
	coin2.Parent = itemPickups
	
	local coin3 = createItemPickup(startPosition + Vector3.new(spacing * 4, 7, -2))
	coin3.Parent = itemPickups
	
	local coin4 = createItemPickup(startPosition + Vector3.new(spacing * 6, 5, 0))
	coin4.Parent = itemPickups
	
	-- End Part
	local endPart = createPart({
		Name = "EndPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition + Vector3.new(STAGE_LENGTH, 0, 0),
		Color = Color3.fromRGB(200, 150, 100),
	})
	endPart.Parent = stage
	
	return stage
end

-- Stage 3: Spinning Obstacles
function StageTemplates.createStage3(startPosition: Vector3): Model
	local stage = Instance.new("Model")
	stage.Name = "Stage3_SpinningObstacles"
	
	-- Start Part
	local startPart = createPart({
		Name = "StartPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition,
		Color = Color3.fromRGB(150, 100, 200),
	})
	startPart.Parent = stage
	
	-- Checkpoint
	local checkpoint = createCheckpoint(startPosition + Vector3.new(0, 1.5, 0))
	checkpoint.Parent = stage
	
	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = stage
	
	local itemPickups = Instance.new("Folder")
	itemPickups.Name = "ItemPickups"
	itemPickups.Parent = stage
	
	-- สร้าง path platforms
	local platformCount = 5
	local spacing = STAGE_LENGTH / (platformCount + 1)
	
	for i = 1, platformCount do
		-- Platform
		local platform = createPart({
			Name = "Platform_" .. i,
			Size = Vector3.new(12, 2, 12),
			Position = startPosition + Vector3.new(spacing * i, 0, 0),
			Color = Color3.fromRGB(100, 100, 150),
		})
		platform.Parent = obstacles
		
		-- Spinning bar on each platform
		local spinner = createPart({
			Name = "Spinner_" .. i,
			Size = Vector3.new(20, 2, 2),
			Position = startPosition + Vector3.new(spacing * i, 3, 0),
			Color = Color3.fromRGB(255, 50, 50),
		})
		spinner:SetAttribute("IsSpinning", true)
		spinner:SetAttribute("SpinSpeed", 2 + i * 0.5) -- เร็วขึ้นเรื่อยๆ
		spinner:SetAttribute("IsKillPart", true)
		spinner.Parent = obstacles
	end
	
	-- Stage 3: 4 coins - วางบน platforms หลบ spinners
	local coin1 = createItemPickup(startPosition + Vector3.new(spacing * 1, 8, 4))
	coin1.Parent = itemPickups
	
	local coin2 = createItemPickup(startPosition + Vector3.new(spacing * 2, 9, -4))
	coin2.Parent = itemPickups
	
	local coin3 = createItemPickup(startPosition + Vector3.new(spacing * 4, 10, 3))
	coin3.Parent = itemPickups
	
	local coin4 = createItemPickup(startPosition + Vector3.new(spacing * 5, 8, -3))
	coin4.Parent = itemPickups
	
	-- End Part
	local endPart = createPart({
		Name = "EndPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition + Vector3.new(STAGE_LENGTH, 0, 0),
		Color = Color3.fromRGB(150, 100, 200),
	})
	endPart.Parent = stage
	
	return stage
end

-- Stage 4: Disappearing Platforms
function StageTemplates.createStage4(startPosition: Vector3): Model
	local stage = Instance.new("Model")
	stage.Name = "Stage4_DisappearingPlatforms"
	
	-- Start Part
	local startPart = createPart({
		Name = "StartPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition,
		Color = Color3.fromRGB(200, 100, 150),
	})
	startPart.Parent = stage
	
	-- Checkpoint
	local checkpoint = createCheckpoint(startPosition + Vector3.new(0, 1.5, 0))
	checkpoint.Parent = stage
	
	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = stage
	
	local itemPickups = Instance.new("Folder")
	itemPickups.Name = "ItemPickups"
	itemPickups.Parent = stage
	
	-- สร้าง disappearing platforms
	local platformCount = 10
	local spacing = STAGE_LENGTH / (platformCount + 1)
	
	for i = 1, platformCount do
		local offset = Vector3.new(
			spacing * i,
			math.random(-8, 8),
			math.random(-1, 2)
		)
		local platform = createPart({
			Name = "DisappearingPlatform_" .. i,
			Size = Vector3.new(5, 1, 5),
			Position = startPosition + offset,
			Color = Color3.fromRGB(255, 100, 150),
			Transparency = 0,
		})
		
		platform:SetAttribute("IsDisappearing", true)
		platform:SetAttribute("DisappearDelay", 1.5) -- หายหลังเหยียบ 1.5 วินาที
		platform:SetAttribute("ReappearDelay", 3) -- กลับมาใหม่หลัง 3 วินาที
		
		platform.Parent = obstacles
	end
	
	-- Stage 4: 5 coins - กระจายตามเส้นทาง disappearing
	local coin1 = createItemPickup(startPosition + Vector3.new(spacing * 2, 4, 0))
	coin1.Parent = itemPickups
	
	local coin2 = createItemPickup(startPosition + Vector3.new(spacing * 4, 6, 1))
	coin2.Parent = itemPickups
	
	local coin3 = createItemPickup(startPosition + Vector3.new(spacing * 5, 5, -1))
	coin3.Parent = itemPickups
	
	local coin4 = createItemPickup(startPosition + Vector3.new(spacing * 7, 7, 0))
	coin4.Parent = itemPickups
	
	local coin5 = createItemPickup(startPosition + Vector3.new(spacing * 9, 4, 1))
	coin5.Parent = itemPickups
	
	-- End Part
	local endPart = createPart({
		Name = "EndPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition + Vector3.new(STAGE_LENGTH, 0, 0),
		Color = Color3.fromRGB(200, 100, 150),
	})
	endPart.Parent = stage
	
	return stage
end

-- Stage 5: Combination (ยาก)
function StageTemplates.createStage5(startPosition: Vector3): Model
	local stage = Instance.new("Model")
	stage.Name = "Stage5_Combination"
	
	-- Start Part
	local startPart = createPart({
		Name = "StartPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition,
		Color = Color3.fromRGB(255, 50, 50),
	})
	startPart.Parent = stage
	
	-- Checkpoint
	local checkpoint = createCheckpoint(startPosition + Vector3.new(0, 1.5, 0))
	checkpoint.Parent = stage
	
	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = stage
	
	local itemPickups = Instance.new("Folder")
	itemPickups.Name = "ItemPickups"
	itemPickups.Parent = stage
	
	local sectionLength = STAGE_LENGTH / 4
	
	-- Section 1: Moving + Disappearing
	for i = 1, 3 do
		local platform = createPart({
			Name = "ComboPlat_" .. i,
			Size = Vector3.new(6, 1, 6),
			Position = startPosition + Vector3.new(sectionLength * 0.25 * i, 0, 0),
			Color = Color3.fromRGB(255, 100, 50),
		})
		platform:SetAttribute("IsMoving", true)
		platform:SetAttribute("MoveAxis", "X")
		platform:SetAttribute("MoveDistance", 8)
		platform:SetAttribute("MoveSpeed", 4)
		platform:SetAttribute("IsDisappearing", true)
		platform:SetAttribute("DisappearDelay", 2)
		platform:SetAttribute("ReappearDelay", 2)
		platform.Parent = obstacles
	end
	
	-- Section 2: Narrow path with spinners
	local narrowPath = createPart({
		Name = "NarrowPath",
		Size = Vector3.new(4, 2, 30),
		Position = startPosition + Vector3.new(sectionLength * 1.5, 0, 0),
		Color = Color3.fromRGB(100, 100, 100),
	})
	narrowPath.Parent = obstacles
	
	for i = 1, 3 do
		local spinner = createPart({
			Name = "PathSpinner_" .. i,
			Size = Vector3.new(15, 1, 1),
			Position = startPosition + Vector3.new(sectionLength + 10 * i, 3, 0),
			Color = Color3.fromRGB(255, 0, 0),
		})
		spinner:SetAttribute("IsSpinning", true)
		spinner:SetAttribute("SpinSpeed", 3)
		spinner:SetAttribute("IsKillPart", true)
		spinner.Parent = obstacles
	end
	
	-- Section 3: Jump platforms rising difficulty
	for i = 1, 5 do
		local platform = createPart({
			Name = "JumpPlat_" .. i,
			Size = Vector3.new(5 - i * 0.5, 1, 5 - i * 0.5), -- เล็กลงเรื่อยๆ
			Position = startPosition + Vector3.new(
				sectionLength * 2.5 + i * 8,
				i * 2,
				math.random(-5, 5)
			),
			Color = Color3.fromRGB(50, 200, 255),
		})
		platform.Parent = obstacles
	end
	
	-- Stage 5: 6 coins - กระจายทั่วทุก section (ด่านยากมีเหรียญมากกว่า)
	-- Section 1 coins
	local coin1 = createItemPickup(startPosition + Vector3.new(sectionLength * 0.5, 5, 2))
	coin1.Parent = itemPickups
	
	local coin2 = createItemPickup(startPosition + Vector3.new(sectionLength, 6, -2))
	coin2.Parent = itemPickups
	
	-- Section 2 coins (narrow path)
	local coin3 = createItemPickup(startPosition + Vector3.new(sectionLength * 1.3, 8, 0))
	coin3.Parent = itemPickups
	
	local coin4 = createItemPickup(startPosition + Vector3.new(sectionLength * 1.7, 7, 0))
	coin4.Parent = itemPickups
	
	-- Section 3 coins (jump platforms)
	local coin5 = createItemPickup(startPosition + Vector3.new(sectionLength * 2.7, 10, 0))
	coin5.Parent = itemPickups
	
	local coin6 = createItemPickup(startPosition + Vector3.new(sectionLength * 3.2, 12, 0))
	coin6.Parent = itemPickups
	
	-- End Part (Finish Line!)
	local endPart = createPart({
		Name = "EndPart",
		Size = Vector3.new(15, 2, 10),
		Position = startPosition + Vector3.new(STAGE_LENGTH, 0, 0),
		Color = Color3.fromRGB(0, 255, 100),
		Material = Enum.Material.SmoothPlastic,
	})
	endPart:SetAttribute("IsFinishLine", true)
	endPart.Parent = stage
	
	-- Finish banner
	local banner = createPart({
		Name = "FinishBanner",
		Size = Vector3.new(15, 10, 1),
		Position = startPosition + Vector3.new(STAGE_LENGTH + 5, 8, 0),
		Color = Color3.fromRGB(255, 215, 0),
		Transparency = 0.5,
		Material = Enum.Material.SmoothPlastic,
	})
	banner.Parent = stage
	
	return stage
end

-- Stage 6: Lava Rise (Hard) - ปีนขึ้นก่อนพื้น lava ตามทัน
function StageTemplates.createStage6(startPosition: Vector3): Model
	local stage = Instance.new("Model")
	stage.Name = "Stage6_LavaRise"

	-- Start Part
	local startPart = createPart({
		Name = "StartPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition,
		Color = Color3.fromRGB(255, 87, 34),
	})
	startPart.Parent = stage

	-- Checkpoint
	local checkpoint = createCheckpoint(startPosition + Vector3.new(0, 1.5, 0))
	checkpoint.Parent = stage

	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = stage

	local itemPickups = Instance.new("Folder")
	itemPickups.Name = "ItemPickups"
	itemPickups.Parent = stage

	-- Rising lava floor (kill part that moves upward)
	local lavaFloor = createPart({
		Name = "LavaFloor",
		Size = Vector3.new(STAGE_LENGTH + 20, 2, 30),
		Position = startPosition + Vector3.new(STAGE_LENGTH / 2, -15, 0),
		Color = Color3.fromRGB(255, 60, 0),
		Material = Enum.Material.SmoothPlastic,
	})
	lavaFloor:SetAttribute("IsKillPart", true)
	lavaFloor:SetAttribute("IsMoving", true)
	lavaFloor:SetAttribute("MoveAxis", "Y")
	lavaFloor:SetAttribute("MoveDistance", 35)
	lavaFloor:SetAttribute("MoveSpeed", 1.5)
	lavaFloor.Parent = obstacles

	-- Lava glow effect
	local lavaLight = Instance.new("PointLight")
	lavaLight.Color = Color3.fromRGB(255, 100, 0)
	lavaLight.Brightness = 3
	lavaLight.Range = 25
	lavaLight.Parent = lavaFloor

	-- Platforms zigzagging upward (10 platforms)
	local platformCount = 10
	local spacing = STAGE_LENGTH / (platformCount + 1)

	for i = 1, platformCount do
		local zOffset = if i % 2 == 0 then 5 else -5
		local yRise = i * 3 -- ค่อยๆ สูงขึ้น

		local platform = createPart({
			Name = "RisePlatform_" .. i,
			Size = Vector3.new(5, 1, 5),
			Position = startPosition + Vector3.new(spacing * i, yRise, zOffset),
			Color = Color3.fromRGB(180, 80, 30),
		})

		-- บางแพลตฟอร์ม disappear (เร็วกว่า Stage 4)
		if i % 3 == 0 then
			platform:SetAttribute("IsDisappearing", true)
			platform:SetAttribute("DisappearDelay", 1.0)
			platform:SetAttribute("ReappearDelay", 2.5)
			platform.Color = Color3.fromRGB(255, 140, 50) -- สีต่างจากปกติ
		end

		platform.Parent = obstacles
	end

	-- Item pickups บนเส้นทางเสี่ยง
	local coin1 = createItemPickup(startPosition + Vector3.new(spacing * 2, 10, 6))
	coin1.Parent = itemPickups

	local coin2 = createItemPickup(startPosition + Vector3.new(spacing * 4, 16, -6))
	coin2.Parent = itemPickups

	local coin3 = createItemPickup(startPosition + Vector3.new(spacing * 6, 22, 4))
	coin3.Parent = itemPickups

	local coin4 = createItemPickup(startPosition + Vector3.new(spacing * 8, 28, -4))
	coin4.Parent = itemPickups

	local coin5 = createItemPickup(startPosition + Vector3.new(spacing * 10, 33, 0))
	coin5.Parent = itemPickups

	-- End Part (สูง เพราะปีนขึ้นไป)
	local endPart = createPart({
		Name = "EndPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition + Vector3.new(STAGE_LENGTH, platformCount * 3, 0),
		Color = Color3.fromRGB(255, 87, 34),
	})
	endPart.Parent = stage

	return stage
end

-- Stage 7: Narrow (Hard) - แพลตฟอร์มแคบมาก + spinner + moving
function StageTemplates.createStage7(startPosition: Vector3): Model
	local stage = Instance.new("Model")
	stage.Name = "Stage7_Narrow"

	-- Start Part
	local startPart = createPart({
		Name = "StartPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition,
		Color = Color3.fromRGB(183, 28, 28),
	})
	startPart.Parent = stage

	-- Checkpoint
	local checkpoint = createCheckpoint(startPosition + Vector3.new(0, 1.5, 0))
	checkpoint.Parent = stage

	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = stage

	local itemPickups = Instance.new("Folder")
	itemPickups.Name = "ItemPickups"
	itemPickups.Parent = stage

	-- Section 1: Narrow static platforms (เล็กลงเรื่อยๆ)
	local section1Count = 5
	local section1Spacing = (STAGE_LENGTH * 0.4) / (section1Count + 1)

	for i = 1, section1Count do
		local platSize = 4 - (i - 1) * 0.4 -- 4 → 2.4 studs
		local platform = createPart({
			Name = "NarrowPlat_" .. i,
			Size = Vector3.new(platSize, 1, platSize),
			Position = startPosition + Vector3.new(section1Spacing * i, math.random(-3, 3), math.random(-3, 3)),
			Color = Color3.fromRGB(200, 50, 50),
		})
		platform.Parent = obstacles
	end

	-- Section 2: Spinner gauntlet + narrow walkway
	local section2Start = STAGE_LENGTH * 0.4
	local narrowWalk = createPart({
		Name = "NarrowWalk",
		Size = Vector3.new(30, 2, 3), -- แคบมาก 3 studs
		Position = startPosition + Vector3.new(section2Start + 15, 0, 0),
		Color = Color3.fromRGB(100, 100, 120),
	})
	narrowWalk.Parent = obstacles

	-- 3 spinners ข้าม narrow walkway
	for i = 1, 3 do
		local spinner = createPart({
			Name = "NarrowSpinner_" .. i,
			Size = Vector3.new(12, 1.5, 1.5),
			Position = startPosition + Vector3.new(section2Start + 8 * i, 3, 0),
			Color = Color3.fromRGB(255, 30, 30),
		})
		spinner:SetAttribute("IsSpinning", true)
		spinner:SetAttribute("SpinSpeed", 3 + i * 0.7) -- 3.7, 4.4, 5.1
		spinner:SetAttribute("IsKillPart", true)
		spinner.Parent = obstacles
	end

	-- Section 3: Moving narrow platforms
	local section3Start = STAGE_LENGTH * 0.7
	local section3Count = 3
	local section3Spacing = (STAGE_LENGTH * 0.3) / (section3Count + 1)

	for i = 1, section3Count do
		local platform = createPart({
			Name = "MovingNarrow_" .. i,
			Size = Vector3.new(3, 1, 3),
			Position = startPosition + Vector3.new(section3Start + section3Spacing * i, 0, 0),
			Color = Color3.fromRGB(255, 80, 80),
		})
		platform:SetAttribute("IsMoving", true)
		platform:SetAttribute("MoveAxis", "Z")
		platform:SetAttribute("MoveDistance", 6)
		platform:SetAttribute("MoveSpeed", 3 + i)
		platform.Parent = obstacles
	end

	-- Item pickups
	local coin1 = createItemPickup(startPosition + Vector3.new(section1Spacing * 2, 5, 4))
	coin1.Parent = itemPickups

	local coin2 = createItemPickup(startPosition + Vector3.new(section1Spacing * 4, 6, -3))
	coin2.Parent = itemPickups

	local coin3 = createItemPickup(startPosition + Vector3.new(section2Start + 10, 8, 3))
	coin3.Parent = itemPickups

	local coin4 = createItemPickup(startPosition + Vector3.new(section2Start + 25, 7, -3))
	coin4.Parent = itemPickups

	local coin5 = createItemPickup(startPosition + Vector3.new(section3Start + section3Spacing, 5, 5))
	coin5.Parent = itemPickups

	local coin6 = createItemPickup(startPosition + Vector3.new(section3Start + section3Spacing * 3, 6, -5))
	coin6.Parent = itemPickups

	-- End Part
	local endPart = createPart({
		Name = "EndPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition + Vector3.new(STAGE_LENGTH, 0, 0),
		Color = Color3.fromRGB(183, 28, 28),
	})
	endPart.Parent = stage

	return stage
end

-- Stage 8: Candy Rainbow (Easy) - บันไดสีสัน + เสารุ้ง + แพลตฟอร์มลูกอม
function StageTemplates.createStage8(startPosition: Vector3): Model
	local stage = Instance.new("Model")
	stage.Name = "Stage8_CandyRainbow"

	-- Start Part (สีชมพูอ่อน - candy theme)
	local startPart = createPart({
		Name = "StartPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition,
		Color = Color3.fromRGB(255, 182, 193),
		Material = Enum.Material.SmoothPlastic,
	})
	startPart.Parent = stage

	-- Checkpoint
	local checkpoint = createCheckpoint(startPosition + Vector3.new(0, 1.5, 0))
	checkpoint.Parent = stage

	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = stage

	local itemPickups = Instance.new("Folder")
	itemPickups.Name = "ItemPickups"
	itemPickups.Parent = stage

	-- === Section 1: Colorful Staircase Blocks (X: 0~35) ===
	-- บล็อกสีสันเรียงเป็นขั้นบันได ขึ้นไปเรื่อยๆ
	local stairColors = {
		Color3.fromRGB(255, 130, 170), -- ชมพู
		Color3.fromRGB(130, 200, 255), -- ฟ้าอ่อน
		Color3.fromRGB(245, 245, 245), -- ขาวครีม
		Color3.fromRGB(200, 140, 255), -- ม่วงอ่อน
		Color3.fromRGB(255, 190, 100), -- ส้มอ่อน
		Color3.fromRGB(170, 255, 170), -- เขียวอ่อน
	}

	for i = 1, 6 do
		local stairBlock = createPart({
			Name = "StairBlock_" .. i,
			Size = Vector3.new(5, 2, 6),
			Position = startPosition + Vector3.new(5 + i * 5, (i - 1) * 2, 0),
			Color = stairColors[i],
			Material = Enum.Material.SmoothPlastic,
		})
		stairBlock.Parent = obstacles
	end

	-- === Section 2: Rainbow Cylinders (X: 38~62) ===
	-- เสาทรงกระบอกสีรุ้งตั้งเป็นแนว มีแพลตฟอร์มเชื่อมให้กระโดด
	local rainbowColors = {
		Color3.fromRGB(255, 60, 60),   -- แดง
		Color3.fromRGB(255, 160, 40),  -- ส้ม
		Color3.fromRGB(255, 240, 60),  -- เหลือง
		Color3.fromRGB(80, 220, 80),   -- เขียว
		Color3.fromRGB(80, 150, 255),  -- ฟ้า
		Color3.fromRGB(180, 80, 255),  -- ม่วง
	}

	local cylinderStartX = 40
	for i = 1, 6 do
		-- เสาสีรุ้ง (ตกแต่ง)
		local cylinder = Instance.new("Part")
		cylinder.Name = "RainbowPillar_" .. i
		cylinder.Anchored = true
		cylinder.Shape = Enum.PartType.Cylinder
		cylinder.Size = Vector3.new(14, 3, 3) -- height=14, diameter=3
		cylinder.CFrame = CFrame.new(
			startPosition + Vector3.new(cylinderStartX + (i - 1) * 5, 7, (if i % 2 == 0 then -4 else 4))
		) * CFrame.Angles(0, 0, math.rad(90))
		cylinder.Color = rainbowColors[i]
		cylinder.Material = Enum.Material.Neon
		cylinder.CanCollide = false
		cylinder.Transparency = 0.3
		cylinder.Parent = obstacles

		-- PointLight สำหรับแต่ละเสา
		local pillarLight = Instance.new("PointLight")
		pillarLight.Color = rainbowColors[i]
		pillarLight.Brightness = 1.5
		pillarLight.Range = 8
		pillarLight.Parent = cylinder
	end

	-- แพลตฟอร์มเชื่อมระหว่างเสารุ้ง (กระโดด zigzag)
	local sectionHeight = 10 -- ความสูงหลังขึ้นบันได (6 ขั้น * 2 = 10)
	for i = 1, 5 do
		local zOffset = if i % 2 == 0 then -3 else 3
		local bridgePlat = createPart({
			Name = "RainbowPlat_" .. i,
			Size = Vector3.new(5, 1, 5),
			Position = startPosition + Vector3.new(cylinderStartX + (i - 1) * 5.5, sectionHeight + math.random(-1, 1), zOffset),
			Color = rainbowColors[i],
			Material = Enum.Material.SmoothPlastic,
		})
		bridgePlat.Parent = obstacles
	end

	-- === Section 3: Candy Swirl Platforms (X: 65~95) ===
	-- แพลตฟอร์มลูกอมสีแดง-ขาวสลับ
	local candyStartX = 68
	for i = 1, 5 do
		-- แพลตฟอร์มลูกอมทรงกลม (ใช้ Cylinder แนวนอนเป็นแผ่นกลม)
		local candyPlat = Instance.new("Part")
		candyPlat.Name = "CandyPlat_" .. i
		candyPlat.Anchored = true
		candyPlat.Shape = Enum.PartType.Cylinder
		candyPlat.Size = Vector3.new(2, 6, 6) -- แผ่นกลมแบนๆ
		candyPlat.CFrame = CFrame.new(
			startPosition + Vector3.new(candyStartX + (i - 1) * 6.5, sectionHeight - (i - 1) * 1.5, (if i % 2 == 0 then -2 else 2))
		)
		candyPlat.Color = if i % 2 == 0 then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(255, 70, 70)
		candyPlat.Material = Enum.Material.SmoothPlastic

		-- เพิ่ม Friction สูง
		candyPlat.CustomPhysicalProperties = PhysicalProperties.new(0.7, 2.0, 0.1, 1.0, 0.5)

		candyPlat.Parent = obstacles
	end

	-- === Item Pickups ===
	-- 3 item boxes กระจายตามเส้นทาง (Easy = 3 items)
	local coin1 = createItemPickup(startPosition + Vector3.new(20, 8, 2))
	coin1.Parent = itemPickups

	local coin2 = createItemPickup(startPosition + Vector3.new(50, sectionHeight + 3, -2))
	coin2.Parent = itemPickups

	local coin3 = createItemPickup(startPosition + Vector3.new(80, sectionHeight, 0))
	coin3.Parent = itemPickups

	-- End Part (สีชมพูอ่อน - candy theme)
	local endPart = createPart({
		Name = "EndPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition + Vector3.new(STAGE_LENGTH, 0, 0),
		Color = Color3.fromRGB(255, 182, 193),
		Material = Enum.Material.SmoothPlastic,
	})
	endPart.Parent = stage

	return stage
end

-- Stage 9: Rope Walk (Easy) - เดินบนเชือกข้ามไป มีเสาค้ำ + พักเป็นช่วงๆ
function StageTemplates.createStage9(startPosition: Vector3): Model
	local stage = Instance.new("Model")
	stage.Name = "Stage9_RopeWalk"

	-- Start Part (สีน้ำตาลอ่อน - rope theme)
	local startPart = createPart({
		Name = "StartPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition,
		Color = Color3.fromRGB(160, 120, 70),
		Material = Enum.Material.Wood,
	})
	startPart.Parent = stage

	-- Checkpoint
	local checkpoint = createCheckpoint(startPosition + Vector3.new(0, 1.5, 0))
	checkpoint.Parent = stage

	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = stage

	local itemPickups = Instance.new("Folder")
	itemPickups.Name = "ItemPickups"
	itemPickups.Parent = stage

	local ropeColor = Color3.fromRGB(139, 90, 43) -- สีเชือก (น้ำตาลเข้ม)
	local poleColor = Color3.fromRGB(101, 67, 33) -- สีเสา (น้ำตาลไม้)
	local platformColor = Color3.fromRGB(180, 140, 90) -- สีแท่นพัก

	-- === Section 1: เชือกตรง (X: 8~35) ===
	-- เชือกเส้นแรก ตรงยาว มีเสาสองฝั่ง
	local rope1Start = 8
	local rope1End = 35
	local rope1Length = rope1End - rope1Start

	-- เสาซ้ายต้นทาง
	local pole1L = createPart({
		Name = "Pole_1L",
		Size = Vector3.new(2, 5, 2),
		Position = startPosition + Vector3.new(rope1Start, 2.5, 0),
		Color = poleColor,
		Material = Enum.Material.Wood,
	})
	pole1L.Parent = obstacles

	-- เสาขวาปลายทาง
	local pole1R = createPart({
		Name = "Pole_1R",
		Size = Vector3.new(2, 5, 2),
		Position = startPosition + Vector3.new(rope1End, 2.5, 0),
		Color = poleColor,
		Material = Enum.Material.Wood,
	})
	pole1R.Parent = obstacles

	-- เชือก (Part แคบยาว)
	local rope1 = createPart({
		Name = "Rope_1",
		Size = Vector3.new(rope1Length, 1, 2),
		Position = startPosition + Vector3.new(rope1Start + rope1Length / 2, 0.5, 0),
		Color = ropeColor,
		Material = Enum.Material.Fabric,
	})
	rope1.Parent = obstacles

	-- เชือกราว (สำหรับดู ไม่ collide - ตกแต่ง)
	local handrail1 = Instance.new("Part")
	handrail1.Name = "Handrail_1"
	handrail1.Anchored = true
	handrail1.Size = Vector3.new(rope1Length, 0.5, 0.5)
	handrail1.Position = startPosition + Vector3.new(rope1Start + rope1Length / 2, 3.5, 0)
	handrail1.Color = ropeColor
	handrail1.Material = Enum.Material.Fabric
	handrail1.CanCollide = false
	handrail1.Transparency = 0.3
	handrail1.Parent = obstacles

	-- === แท่นพัก 1 (X: 35~40) ===
	local restPlat1 = createPart({
		Name = "RestPlatform_1",
		Size = Vector3.new(6, 2, 8),
		Position = startPosition + Vector3.new(37.5, 0, 0),
		Color = platformColor,
		Material = Enum.Material.WoodPlanks,
	})
	restPlat1.Parent = obstacles

	-- === Section 2: เชือก zigzag (X: 40~68) ===
	-- 3 เชือกสั้นๆ zigzag ซ้าย-ขวา
	local zigzagRopes = {
		{startX = 42, length = 8, z = 3, height = 0},
		{startX = 52, length = 8, z = -3, height = 0.5},
		{startX = 62, length = 8, z = 2, height = 0},
	}

	for i, ropeData in ipairs(zigzagRopes) do
		-- เสาต้นทาง
		local poleStart = createPart({
			Name = "ZigPole_" .. i .. "L",
			Size = Vector3.new(1.5, 4, 1.5),
			Position = startPosition + Vector3.new(ropeData.startX, 2 + ropeData.height, ropeData.z),
			Color = poleColor,
			Material = Enum.Material.Wood,
		})
		poleStart.Parent = obstacles

		-- เสาปลายทาง
		local poleEnd = createPart({
			Name = "ZigPole_" .. i .. "R",
			Size = Vector3.new(1.5, 4, 1.5),
			Position = startPosition + Vector3.new(ropeData.startX + ropeData.length, 2 + ropeData.height, ropeData.z),
			Color = poleColor,
			Material = Enum.Material.Wood,
		})
		poleEnd.Parent = obstacles

		-- เชือก
		local rope = createPart({
			Name = "ZigRope_" .. i,
			Size = Vector3.new(ropeData.length, 1, 1.8),
			Position = startPosition + Vector3.new(ropeData.startX + ropeData.length / 2, ropeData.height + 0.5, ropeData.z),
			Color = ropeColor,
			Material = Enum.Material.Fabric,
		})
		rope.Parent = obstacles

		-- เชือกราวตกแต่ง
		local handrail = Instance.new("Part")
		handrail.Name = "ZigHandrail_" .. i
		handrail.Anchored = true
		handrail.Size = Vector3.new(ropeData.length, 0.4, 0.4)
		handrail.Position = startPosition + Vector3.new(ropeData.startX + ropeData.length / 2, ropeData.height + 3, ropeData.z)
		handrail.Color = ropeColor
		handrail.Material = Enum.Material.Fabric
		handrail.CanCollide = false
		handrail.Transparency = 0.3
		handrail.Parent = obstacles
	end

	-- === แท่นพัก 2 (X: 70~75) ===
	local restPlat2 = createPart({
		Name = "RestPlatform_2",
		Size = Vector3.new(6, 2, 8),
		Position = startPosition + Vector3.new(72.5, 0, 0),
		Color = platformColor,
		Material = Enum.Material.WoodPlanks,
	})
	restPlat2.Parent = obstacles

	-- === Section 3: เชือกยาวสุดท้าย (X: 75~95) ===
	local rope3Start = 77
	local rope3End = 95
	local rope3Length = rope3End - rope3Start

	-- เสาต้นทาง
	local pole3L = createPart({
		Name = "Pole_3L",
		Size = Vector3.new(2, 5, 2),
		Position = startPosition + Vector3.new(rope3Start, 2.5, 0),
		Color = poleColor,
		Material = Enum.Material.Wood,
	})
	pole3L.Parent = obstacles

	-- เสาปลายทาง
	local pole3R = createPart({
		Name = "Pole_3R",
		Size = Vector3.new(2, 5, 2),
		Position = startPosition + Vector3.new(rope3End, 2.5, 0),
		Color = poleColor,
		Material = Enum.Material.Wood,
	})
	pole3R.Parent = obstacles

	-- เชือกสุดท้าย (แคบกว่าเส้นแรกนิดหน่อย)
	local rope3 = createPart({
		Name = "Rope_3",
		Size = Vector3.new(rope3Length, 1, 1.5),
		Position = startPosition + Vector3.new(rope3Start + rope3Length / 2, 0.5, 0),
		Color = ropeColor,
		Material = Enum.Material.Fabric,
	})
	rope3.Parent = obstacles

	-- เชือกราวตกแต่ง 2 เส้น (ซ้าย-ขวา)
	for side = -1, 1, 2 do
		local sideRail = Instance.new("Part")
		sideRail.Name = "FinalHandrail_" .. (if side == -1 then "L" else "R")
		sideRail.Anchored = true
		sideRail.Size = Vector3.new(rope3Length, 0.4, 0.4)
		sideRail.Position = startPosition + Vector3.new(rope3Start + rope3Length / 2, 3, side * 2)
		sideRail.Color = ropeColor
		sideRail.Material = Enum.Material.Fabric
		sideRail.CanCollide = false
		sideRail.Transparency = 0.3
		sideRail.Parent = obstacles
	end

	-- === Item Pickups ===
	local coin1 = createItemPickup(startPosition + Vector3.new(22, 2, 0))
	coin1.Parent = itemPickups

	local coin2 = createItemPickup(startPosition + Vector3.new(56, 2, -3))
	coin2.Parent = itemPickups

	local coin3 = createItemPickup(startPosition + Vector3.new(86, 2, 0))
	coin3.Parent = itemPickups

	-- End Part
	local endPart = createPart({
		Name = "EndPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition + Vector3.new(STAGE_LENGTH, 0, 0),
		Color = Color3.fromRGB(160, 120, 70),
		Material = Enum.Material.Wood,
	})
	endPart.Parent = stage

	return stage
end

-- Stage 10: Rainbow Zigzag (Easy) - ทาง S-curve สีรุ้งแบบงูเลื้อย
function StageTemplates.createStage10(startPosition: Vector3): Model
	local stage = Instance.new("Model")
	stage.Name = "Stage10_RainbowZigzag"

	-- Start Part (สีแดง - เริ่มต้นสีรุ้ง)
	local startPart = createPart({
		Name = "StartPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition,
		Color = Color3.fromRGB(255, 80, 80),
		Material = Enum.Material.SmoothPlastic,
	})
	startPart.Parent = stage

	-- Checkpoint
	local checkpoint = createCheckpoint(startPosition + Vector3.new(0, 1.5, 0))
	checkpoint.Parent = stage

	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = stage

	local itemPickups = Instance.new("Folder")
	itemPickups.Name = "ItemPickups"
	itemPickups.Parent = stage

	-- สีรุ้ง 6 สี สำหรับไล่สี
	local rainbowColors = {
		Color3.fromRGB(255, 60, 60),   -- แดง
		Color3.fromRGB(255, 160, 40),  -- ส้ม
		Color3.fromRGB(255, 240, 60),  -- เหลือง
		Color3.fromRGB(80, 220, 80),   -- เขียว
		Color3.fromRGB(80, 150, 255),  -- ฟ้า
		Color3.fromRGB(180, 80, 255),  -- ม่วง
	}

	-- === ทาง S-curve แบบงูเลื้อย (sine wave) ===
	-- ใช้ segments จำนวนมาก + overlap ให้ต่อสนิทไม่มีฟันเลื่อย
	local totalSegments = 60
	local amplitude = 7
	local waves = 2
	local pathWidth = 8

	-- คำนวณจุดทั้งหมดบน sine curve (N+1 จุด)
	local points = {}
	for i = 0, totalSegments do
		local t = i / totalSegments
		local x = STAGE_LENGTH * t
		local z = amplitude * math.sin(t * waves * 2 * math.pi)
		table.insert(points, Vector3.new(x, 0, z))
	end

	-- สร้าง segment เชื่อมจุดต่อจุด + ไล่สี gradient smooth
	for i = 1, totalSegments do
		local p1 = points[i]
		local p2 = points[i + 1]
		local mid = (p1 + p2) / 2
		local length = (p2 - p1).Magnitude

		-- ไล่สี gradient: lerp ระหว่างสีรุ้งแต่ละคู่
		local t = (i - 0.5) / totalSegments -- 0~1 ตามตำแหน่ง
		local colorT = t * (#rainbowColors - 1) -- 0~5
		local idx = math.floor(colorT) + 1 -- index สีเริ่ม (1~6)
		local frac = colorT - (idx - 1) -- fraction ระหว่าง 2 สี (0~1)
		idx = math.clamp(idx, 1, #rainbowColors)
		local nextIdx = math.clamp(idx + 1, 1, #rainbowColors)
		local segColor = rainbowColors[idx]:Lerp(rainbowColors[nextIdx], frac)

		local segment = createPart({
			Name = "SnakePath_" .. i,
			Size = Vector3.new(length + 1.2, 2, pathWidth),
			Color = segColor,
			Material = Enum.Material.SmoothPlastic,
		})

		local worldMid = startPosition + mid
		local worldTarget = startPosition + p2
		local lookCF = CFrame.lookAt(worldMid, worldTarget)
		segment.CFrame = lookCF * CFrame.Angles(0, math.rad(90), 0)
		segment.Parent = obstacles
	end

	-- === Item Pickups ===
	-- วางที่จุดโค้งของ sine wave
	local coin1 = createItemPickup(startPosition + Vector3.new(STAGE_LENGTH * 0.125, 2, amplitude))
	coin1.Parent = itemPickups

	local coin2 = createItemPickup(startPosition + Vector3.new(STAGE_LENGTH * 0.5, 2, 0))
	coin2.Parent = itemPickups

	local coin3 = createItemPickup(startPosition + Vector3.new(STAGE_LENGTH * 0.875, 2, amplitude))
	coin3.Parent = itemPickups

	-- End Part (สีม่วง - จบสีรุ้ง)
	local endPart = createPart({
		Name = "EndPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition + Vector3.new(STAGE_LENGTH, 0, 0),
		Color = Color3.fromRGB(180, 80, 255),
		Material = Enum.Material.SmoothPlastic,
	})
	endPart.Parent = stage

	return stage
end

-- ============================================================
-- Stage 11: Lane Switch (Normal) — ยาว 2 เท่า (200 studs)
-- 4 เลนแบบ Checkerboard บังคับสลับเลนทุก segment
-- OFF segments แสดงเงาจางๆ (ghostly) เพื่อให้เห็นว่าจะปลอดภัยรอบถัดไป
-- มีจุดพักปลอดภัย 1 จุด ตรงกลาง
-- ============================================================
function StageTemplates.createStage11(startPosition: Vector3): Model
	local stageLength = 200 -- 2x ปกติ

	local stage = Instance.new("Model")
	stage.Name = "Stage11_LaneSwitch"

	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = stage

	local itemPickups = Instance.new("Folder")
	itemPickups.Name = "ItemPickups"
	itemPickups.Parent = stage

	-- Start Part
	local startPart = createPart({
		Name = "StartPart",
		Size = Vector3.new(5, 2, 24),
		Position = startPosition + Vector3.new(0, 0, 0),
		Color = Color3.fromRGB(100, 100, 100),
		Material = Enum.Material.Concrete,
	})
	startPart.Parent = stage

	-- Checkpoint ที่จุดเริ่ม
	local cp = createCheckpoint(startPosition + Vector3.new(0, 1, 0))
	cp.Parent = stage

	-- === Lane Config ===
	local laneColors = {
		Color3.fromRGB(0, 170, 255),   -- Lane 1: ฟ้า
		Color3.fromRGB(0, 200, 100),   -- Lane 2: เขียว
		Color3.fromRGB(180, 80, 255),  -- Lane 3: ม่วง
		Color3.fromRGB(255, 150, 30),  -- Lane 4: ส้ม
	}
	local laneZ = { -9, -3, 3, 9 }
	local laneWidth = 5.5

	-- === Segment Config ===
	local segLength = 8
	local segGap = 2
	local segStride = segLength + segGap -- 10 studs
	local numSegments = 9 -- ต่อ section

	-- === Cycling Config ===
	local onTime = 3.0
	local offTime = 3.0
	local blinkTime = 1.0

	-- === Layout: 2 sections + rest zone ตรงกลาง ===
	-- [Start 5s] [Section1: 90s] [gap] [RestZone 10s] [gap] [Section2: 90s] [End]
	local section1Start = 5
	local restZoneX = 100 -- center ของ rest zone (กลาง stage)
	local restZoneWidth = 10
	local section2Start = restZoneX + restZoneWidth / 2 + 2 -- 107

	-- === Helper: สร้าง checkerboard section ===
	-- Segment ที่ ON = สีสดใส ทึบ (ปลอดภัย กระโดดได้!)
	-- Segment ที่ OFF = เงาจางๆ สีมืด (เห็นตำแหน่ง แต่ตกทะลุ!)
	local function createSection(sectionStartX: number, label: string)
		for segIdx = 1, numSegments do
			local segX = sectionStartX + (segIdx - 1) * segStride + segLength / 2

			for laneIdx, z in ipairs(laneZ) do
				local isPhaseB = (laneIdx + segIdx) % 2 == 1

				local seg = createPart({
					Name = label .. "_Seg" .. segIdx .. "_L" .. laneIdx,
					Size = Vector3.new(segLength, 2, laneWidth),
					Position = startPosition + Vector3.new(segX, 0, z),
					Color = laneColors[laneIdx],
					Material = Enum.Material.SmoothPlastic,
				})

				seg:SetAttribute("IsAutoCycling", true)
				seg:SetAttribute("CycleOnTime", onTime)
				seg:SetAttribute("CycleOffTime", offTime)
				seg:SetAttribute("BlinkTime", blinkTime)
				seg:SetAttribute("OffTransparency", 0.75) -- เงาจางตอนปิด

				if isPhaseB then
					seg:SetAttribute("StartsOff", true)
					seg:SetAttribute("CycleOffset", onTime)
				else
					seg:SetAttribute("CycleOffset", 0)
				end

				seg.Parent = obstacles
			end
		end
	end

	-- === Checkerboard Pattern (ทั้ง 2 sections) ===
	--
	--  สีสด = ON (ปลอดภัย!)    จาง = OFF (ตกทะลุ!)
	--
	--         Seg1  Seg2  Seg3  Seg4  Seg5  Seg6  Seg7  Seg8  Seg9
	-- Lane1: [สด]  จาง  [สด]  จาง  [สด]  จาง  [สด]  จาง  [สด]
	-- Lane2:  จาง  [สด]  จาง  [สด]  จาง  [สด]  จาง  [สด]  จาง
	-- Lane3: [สด]  จาง  [สด]  จาง  [สด]  จาง  [สด]  จาง  [สด]
	-- Lane4:  จาง  [สด]  จาง  [สด]  จาง  [สด]  จาง  [สด]  จาง
	--
	-- ทุก 3 วินาที สลับเฟส: สด↔จาง
	-- ต้อง zigzag ข้ามเลนตลอด!

	-- Section 1
	createSection(section1Start, "S1")

	-- === Rest Zone (จุดพักปลอดภัย ตรงกลาง) ===
	local restPlatform = createPart({
		Name = "RestZone",
		Size = Vector3.new(restZoneWidth, 2, 24),
		Position = startPosition + Vector3.new(restZoneX, 0, 0),
		Color = Color3.fromRGB(0, 180, 80),
		Material = Enum.Material.DiamondPlate,
	})
	restPlatform.Parent = obstacles

	-- Checkpoint ที่จุดพัก
	local cpRest = createCheckpoint(startPosition + Vector3.new(restZoneX, 1, 0))
	cpRest.Parent = stage

	-- Section 2
	createSection(section2Start, "S2")

	-- === Item Pickups (4 ชิ้น กระจายทั้ง 2 sections) ===
	local itemPositions = {
		startPosition + Vector3.new(section1Start + 2 * segStride + segLength / 2, 2, laneZ[2]),
		startPosition + Vector3.new(section1Start + 6 * segStride + segLength / 2, 2, laneZ[3]),
		startPosition + Vector3.new(section2Start + 2 * segStride + segLength / 2, 2, laneZ[4]),
		startPosition + Vector3.new(section2Start + 6 * segStride + segLength / 2, 2, laneZ[1]),
	}
	for _, pos in ipairs(itemPositions) do
		local item = createItemPickup(pos)
		item.Parent = itemPickups
	end

	-- End Part
	local endPart = createPart({
		Name = "EndPart",
		Size = Vector3.new(6, 2, 24),
		Position = startPosition + Vector3.new(stageLength, 0, 0),
		Color = Color3.fromRGB(80, 80, 80),
		Material = Enum.Material.DiamondPlate,
	})
	endPart.Parent = stage

	return stage
end

-- ==================== STAGE 12: Pendulum (Normal) ====================
function StageTemplates.createStage12(startPosition: Vector3): Model
	local stage = Instance.new("Model")
	stage.Name = "Stage_Pendulum"

	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = stage

	local itemPickups = Instance.new("Folder")
	itemPickups.Name = "ItemPickups"
	itemPickups.Parent = stage

	local stageLength = 200
	local runwayWidth = 8

	-- Start Part
	local startPart = createPart({
		Name = "StartPart",
		Size = Vector3.new(6, 2, runwayWidth),
		Position = startPosition,
		Color = Color3.fromRGB(80, 80, 80),
		Material = Enum.Material.DiamondPlate,
	})
	startPart.Parent = stage

	-- Runway floor
	local runway = createPart({
		Name = "Runway",
		Size = Vector3.new(stageLength, 1, runwayWidth),
		Position = startPosition + Vector3.new(stageLength / 2, -0.5, 0),
		Color = Color3.fromRGB(140, 140, 150),
		Material = Enum.Material.Concrete,
	})
	runway.Parent = obstacles

	-- Layout: Start → Checkpoint → All 12 pendulums → End
	-- No pendulums behind spawn or checkpoint
	-- X=0: Start, X=10: Checkpoint, X=25 to X=190: 12 pendulums, X=200: End
	local beamWidth = runwayWidth + 4
	local pendulumStart = 25
	local pendulumEnd = 190

	local pendulumConfigs = {
		{ speed = 2.5, angle = 50, phase = 0,            rope = 15 },
		{ speed = 2.5, angle = 50, phase = math.pi / 2,  rope = 15 },
		{ speed = 2.8, angle = 50, phase = 0,            rope = 15 },
		{ speed = 2.8, angle = 50, phase = math.pi / 2,  rope = 16 },
		{ speed = 3.0, angle = 52, phase = 0,            rope = 16 },
		{ speed = 3.0, angle = 52, phase = math.pi / 2,  rope = 16 },
		{ speed = 3.2, angle = 52, phase = 0,            rope = 17 },
		{ speed = 3.2, angle = 52, phase = math.pi / 2,  rope = 17 },
		{ speed = 3.5, angle = 55, phase = 0,            rope = 17 },
		{ speed = 3.5, angle = 55, phase = math.pi / 2,  rope = 18 },
		{ speed = 4.0, angle = 55, phase = 0,            rope = 18 },
		{ speed = 4.0, angle = 55, phase = math.pi / 4,  rope = 18 },
	}

	local numPendulums = #pendulumConfigs
	local pendulumSpacing = (pendulumEnd - pendulumStart) / (numPendulums + 1)

	for i, config in ipairs(pendulumConfigs) do
		local xOffset = pendulumStart + pendulumSpacing * i
		local ballY = 5 -- ball radius = 5, so center at Y=5 sits on runway surface
		local beamY = startPosition.Y + ballY + config.rope + 3

		-- Pendulum ball (pushes player, NOT kill)
		local ball = Instance.new("Part")
		ball.Name = "PendulumBall_" .. i
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(10, 10, 10)
		ball.Position = startPosition + Vector3.new(xOffset, ballY, 0)
		ball.Anchored = true
		ball.Material = Enum.Material.SmoothPlastic
		ball.Color = Color3.fromRGB(200, 50, 50)
		ball.CanCollide = true
		ball:SetAttribute("IsPendulum", true)
		ball:SetAttribute("PendulumRopeLength", config.rope)
		ball:SetAttribute("PendulumMaxAngle", config.angle)
		ball:SetAttribute("PendulumSpeed", config.speed)
		ball:SetAttribute("PendulumPhaseOffset", config.phase)
		ball:SetAttribute("PendulumRopeName", "Rope_" .. i)
		ball.Parent = obstacles

		-- Rope (visual, no collision)
		local rope = createPart({
			Name = "Rope_" .. i,
			Size = Vector3.new(0.5, config.rope, 0.5),
			Position = startPosition + Vector3.new(xOffset, ballY + config.rope / 2, 0),
			Color = Color3.fromRGB(80, 80, 80),
			Material = Enum.Material.Metal,
		})
		rope.CanCollide = false
		rope.Parent = obstacles

		-- Overhead beam
		local beam = createPart({
			Name = "Beam_" .. i,
			Size = Vector3.new(2, 2, beamWidth),
			Position = startPosition + Vector3.new(xOffset, beamY, 0),
			Color = Color3.fromRGB(100, 100, 110),
			Material = Enum.Material.Metal,
		})
		beam.Parent = obstacles

	end

	-- Checkpoint right before pendulums (die → respawn here, all pendulums ahead)
	local cp = createCheckpoint(startPosition + Vector3.new(15, 1, 0))
	cp.Parent = stage

	-- Item pickups between pendulums
	local coin1 = createItemPickup(startPosition + Vector3.new(pendulumStart + pendulumSpacing * 2.5, 3, 6))
	coin1.Parent = itemPickups

	local coin2 = createItemPickup(startPosition + Vector3.new(pendulumStart + pendulumSpacing * 5.5, 3, -6))
	coin2.Parent = itemPickups

	local coin3 = createItemPickup(startPosition + Vector3.new(pendulumStart + pendulumSpacing * 8.5, 3, 6))
	coin3.Parent = itemPickups

	local coin4 = createItemPickup(startPosition + Vector3.new(pendulumStart + pendulumSpacing * 11.5, 3, -6))
	coin4.Parent = itemPickups

	-- End Part
	local endPart = createPart({
		Name = "EndPart",
		Size = Vector3.new(6, 2, runwayWidth),
		Position = startPosition + Vector3.new(stageLength, 0, 0),
		Color = Color3.fromRGB(80, 80, 80),
		Material = Enum.Material.DiamondPlate,
	})
	endPart.Parent = stage

	return stage
end

-- ==================== STAGE 13: Spinning Bars (Easy) ====================
function StageTemplates.createStage13(startPosition: Vector3): Model
	local stage = Instance.new("Model")
	stage.Name = "Stage_SpinningBars"

	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = stage

	local itemPickups = Instance.new("Folder")
	itemPickups.Name = "ItemPickups"
	itemPickups.Parent = stage

	local stageLength = STAGE_LENGTH

	-- Start Part
	local startPart = createPart({
		Name = "StartPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition,
		Color = Color3.fromRGB(60, 150, 60),
		Material = Enum.Material.DiamondPlate,
	})
	startPart.Parent = stage

	-- Checkpoint near start
	local cp = createCheckpoint(startPosition + Vector3.new(8, 1.5, 0))
	cp.Parent = stage

	-- Section configs: แต่ละ section มี platform + เสากลาง + แท่งหมุน
	-- bars: height = ความสูงจากพื้น platform, speed = ความเร็วหมุน (ลบ = ทวนเข็ม), startAngle = มุมเริ่มต้น
	-- ปรับให้พอดี STAGE_LENGTH = 100 studs
	local sections = {
		{
			xOffset = 20, platSize = 18, pillarRadius = 2.5, pillarHeight = 12,
			bars = {
				{ height = 3, speed = 1.2, startAngle = 0 },
			},
			pushForce = 3000,
		},
		{
			xOffset = 50, platSize = 20, pillarRadius = 3, pillarHeight = 14,
			bars = {
				{ height = 3, speed = 1.5, startAngle = 0 },
				{ height = 7, speed = -1.2, startAngle = math.rad(90) },
			},
			pushForce = 3500,
		},
		{
			xOffset = 80, platSize = 20, pillarRadius = 3, pillarHeight = 14,
			bars = {
				{ height = 3, speed = -1.8, startAngle = 0 },
				{ height = 7, speed = 1.5, startAngle = math.rad(45) },
			},
			pushForce = 3500,
		},
	}

	local pillarColor = Color3.fromRGB(30, 30, 40)
	local barColor = Color3.fromRGB(220, 50, 50)

	for i, sec in ipairs(sections) do
		local center = startPosition + Vector3.new(sec.xOffset, 0, 0)

		-- Platform สี่เหลี่ยม
		local platform = createPart({
			Name = "Platform_" .. i,
			Size = Vector3.new(sec.platSize, 2, sec.platSize),
			Position = center,
			Color = if i % 2 == 1 then Color3.fromRGB(80, 180, 80) else Color3.fromRGB(70, 160, 70),
			Material = Enum.Material.SmoothPlastic,
		})
		platform.Parent = obstacles

		-- เสากลาง (Cylinder ตั้งตรง)
		local pillarDiam = sec.pillarRadius * 2
		local pillar = Instance.new("Part")
		pillar.Name = "Pillar_" .. i
		pillar.Shape = Enum.PartType.Cylinder
		pillar.Size = Vector3.new(sec.pillarHeight, pillarDiam, pillarDiam)
		-- หมุน 90° รอบ Z เพื่อให้ Cylinder ตั้งตรง (ความยาวตามแกน Y)
		pillar.CFrame = CFrame.new(center + Vector3.new(0, sec.pillarHeight / 2 + 1, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		pillar.Anchored = true
		pillar.CanCollide = true
		pillar.Color = pillarColor
		pillar.Material = Enum.Material.Metal
		pillar.CustomPhysicalProperties = PhysicalProperties.new(0.7, 2.0, 0.1, 1.0, 0.5)
		pillar.Parent = obstacles

		-- แท่งหมุน (Cylinder นอน หมุนรอบแกน Y เหมือนใบพัดเฮลิคอปเตอร์)
		for j, barCfg in ipairs(sec.bars) do
			local barLength = sec.platSize + 4 -- ยาวเลยขอบ platform เล็กน้อย
			local bar = Instance.new("Part")
			bar.Name = "SpinBar_" .. i .. "_" .. j
			bar.Shape = Enum.PartType.Cylinder
			bar.Size = Vector3.new(barLength, 3, 3)
			-- ไม่หมุน Z: Cylinder ยาวตามแกน X, animation หมุนรอบ Y (กวาดแนวนอน)
			bar.CFrame = CFrame.new(center + Vector3.new(0, barCfg.height + 1, 0))
				* CFrame.Angles(0, barCfg.startAngle, 0)
			bar.Anchored = true
			bar.CanCollide = true
			bar.Color = barColor
			bar.Material = Enum.Material.SmoothPlastic
			bar:SetAttribute("IsSpinning", true)
			bar:SetAttribute("SpinSpeed", barCfg.speed)
			bar:SetAttribute("PushForce", sec.pushForce)
			bar:SetAttribute("PushUpForce", 1200)
			bar.Parent = obstacles
		end
	end

	-- ทางเดินเชื่อม: Start → Section 1
	local startEdge = 5 -- StartPart ขนาด 10, กลางที่ 0, ขอบขวาที่ 5
	local sec1Left = sections[1].xOffset - sections[1].platSize / 2
	local wLen0 = sec1Left - startEdge
	if wLen0 > 0 then
		local walkway = createPart({
			Name = "Walkway_Start",
			Size = Vector3.new(wLen0, 2, 8),
			Position = startPosition + Vector3.new(startEdge + wLen0 / 2, 0, 0),
			Color = Color3.fromRGB(100, 100, 110),
			Material = Enum.Material.DiamondPlate,
		})
		walkway.Parent = obstacles
	end

	-- ทางเดินเชื่อมระหว่าง sections
	for i = 1, #sections - 1 do
		local sec1 = sections[i]
		local sec2 = sections[i + 1]
		local x1 = sec1.xOffset + sec1.platSize / 2
		local x2 = sec2.xOffset - sec2.platSize / 2
		local wLen = x2 - x1
		if wLen > 0 then
			local walkway = createPart({
				Name = "Walkway_" .. i,
				Size = Vector3.new(wLen, 2, 8),
				Position = startPosition + Vector3.new((x1 + x2) / 2, 0, 0),
				Color = Color3.fromRGB(100, 100, 110),
				Material = Enum.Material.DiamondPlate,
			})
			walkway.Parent = obstacles
		end
	end

	-- ทางเดินเชื่อม: Section สุดท้าย → EndPart
	local secLast = sections[#sections]
	local secLastRight = secLast.xOffset + secLast.platSize / 2
	local endLeft = stageLength - 5 -- EndPart ขนาด 10, กลางที่ stageLength, ขอบซ้ายที่ -5
	local wLenEnd = endLeft - secLastRight
	if wLenEnd > 0 then
		local walkway = createPart({
			Name = "Walkway_End",
			Size = Vector3.new(wLenEnd, 2, 8),
			Position = startPosition + Vector3.new((secLastRight + endLeft) / 2, 0, 0),
			Color = Color3.fromRGB(100, 100, 110),
			Material = Enum.Material.DiamondPlate,
		})
		walkway.Parent = obstacles
	end

	-- Item pickups บนทางเดินระหว่าง sections
	for i = 1, #sections - 1 do
		local x1 = sections[i].xOffset + sections[i].platSize / 2
		local x2 = sections[i + 1].xOffset - sections[i + 1].platSize / 2
		local itemX = (x1 + x2) / 2
		local itemZ = if i % 2 == 1 then 0 else 0
		local item = createItemPickup(startPosition + Vector3.new(itemX, 3, itemZ))
		item.Parent = itemPickups
	end

	-- End Part
	local endPart = createPart({
		Name = "EndPart",
		Size = Vector3.new(10, 2, 10),
		Position = startPosition + Vector3.new(stageLength, 0, 0),
		Color = Color3.fromRGB(60, 150, 60),
		Material = Enum.Material.DiamondPlate,
	})
	endPart.Parent = stage

	return stage
end

-- ==================== STAGE 14: Boxing Glove Run (Easy) ====================
-- ทางเดินกว้าง มีนวมชกมวยแดงยื่นออกมาจากผนังชกผู้เล่นกระเด็น
-- ผู้เล่นต้องจับจังหวะ: หยุดรอเมื่อหมัดยื่นออกมา → วิ่งเมื่อหมัดหดกลับ
-- ใช้ระบบ IsPunching (CFrame-based, anchored) แทน IsMoving (physics-based)
function StageTemplates.createStage14(startPosition: Vector3): Model
	local stage = Instance.new("Model")
	stage.Name = "Stage_BoxingGloveRun"

	local obstacles = Instance.new("Folder")
	obstacles.Name = "Obstacles"
	obstacles.Parent = stage

	local itemPickups = Instance.new("Folder")
	itemPickups.Name = "ItemPickups"
	itemPickups.Parent = stage

	local stageLength = STAGE_LENGTH
	local pathWidth = 12

	-- สี (Boxing theme)
	local floorColor = Color3.fromRGB(220, 215, 200)
	local sideWallColor = Color3.fromRGB(180, 175, 165)
	local gloveRed = Color3.fromRGB(200, 35, 30)
	local armWoodColor = Color3.fromRGB(190, 150, 90)

	-- Start Part
	local startPart = createPart({
		Name = "StartPart",
		Size = Vector3.new(8, 2, 8),
		Position = startPosition,
		Color = floorColor,
		Material = Enum.Material.SmoothPlastic,
	})
	startPart.Parent = stage

	-- Checkpoint
	local cp = createCheckpoint(startPosition + Vector3.new(6, 1.5, 0))
	cp.Parent = stage

	-- === พื้นทางเดิน ===
	local pathStart = 5
	local pathEnd = 95
	local pathLength = pathEnd - pathStart
	local floor = createPart({
		Name = "Floor",
		Size = Vector3.new(pathLength, 2, pathWidth),
		Position = startPosition + Vector3.new(pathStart + pathLength / 2, -0.5, 0),
		Color = floorColor,
		Material = Enum.Material.SmoothPlastic,
	})
	floor.Parent = obstacles

	-- === ขอบพื้นสีเข้ม ===
	for _, sideZ in ipairs({-1, 1}) do
		local edgeTrim = createPart({
			Name = "EdgeTrim_" .. (sideZ == 1 and "R" or "L"),
			Size = Vector3.new(pathLength, 2.2, 0.5),
			Position = startPosition + Vector3.new(pathStart + pathLength / 2, -0.5, (pathWidth / 2 + 0.25) * sideZ),
			Color = Color3.fromRGB(160, 155, 145),
			Material = Enum.Material.SmoothPlastic,
		})
		edgeTrim.Parent = obstacles
	end

	-- === กำแพงสูง 2 ฝั่ง (ซ่อนนวม+แขนเมื่อหดกลับ) ===
	local wallHeight = 8
	local wallThickness = 4
	for _, sideZ in ipairs({-1, 1}) do
		local wall = createPart({
			Name = "Wall_" .. (sideZ == 1 and "R" or "L"),
			Size = Vector3.new(pathLength, wallHeight, wallThickness),
			Position = startPosition + Vector3.new(pathStart + pathLength / 2, wallHeight / 2, (pathWidth / 2 + wallThickness / 2) * sideZ),
			Color = sideWallColor,
			Material = Enum.Material.SmoothPlastic,
		})
		wall.Parent = obstacles
	end

	-- === Config นวมชกมวย ===
	-- นวมซ่อนหลังกำแพง (retracted) แล้วยื่นข้ามทางเต็มความกว้าง (punch)
	-- ผู้เล่นเดินแกน X, นวมขยับแกน Z (ตั้งฉากกับทางเดิน)
	-- นวม(4)+แขน(10) = 14 studs รวมกันปิดทางกว้าง 12 studs ได้หมด
	-- ทุกตัว speed เดียวกัน + phase สลับกัน 1/8 → ทีละตัวชก ไม่ชนกัน
	local gloveConfigs = {
		{ xOffset = 15, side = 1,  phase = 0.000 },
		{ xOffset = 25, side = -1, phase = 0.125 },
		{ xOffset = 35, side = 1,  phase = 0.250 },
		{ xOffset = 45, side = -1, phase = 0.375 },
		{ xOffset = 55, side = 1,  phase = 0.500 },
		{ xOffset = 65, side = -1, phase = 0.625 },
		{ xOffset = 75, side = 1,  phase = 0.750 },
		{ xOffset = 85, side = -1, phase = 0.875 },
	}

	local gloveSize = Vector3.new(4, 4, 4)
	local armSize = Vector3.new(2, 2, 10)
	local punchDistance = 14   -- นวม+แขนรวม 14 studs ปิดทาง 12 studs
	local punchSpeed = 0.5     -- 2 วินาทีต่อรอบ จังหวะชัดเจน
	local fistY = 3.5

	for i, cfg in ipairs(gloveConfigs) do
		-- ตำแหน่ง retracted: นวมซ่อนหลังกำแพง
		local retractedZ = (pathWidth / 2 + gloveSize.Z / 2 + 1) * cfg.side
		local punchDir = Vector3.new(0, 0, -cfg.side)
		local glovePos = startPosition + Vector3.new(cfg.xOffset, fistY, retractedZ)

		-- === นวมแดง (Glove) — IsPunching (CFrame-based, anchored) ===
		local glove = createPart({
			Name = "Glove_" .. i,
			Size = gloveSize,
			Position = glovePos,
			Color = gloveRed,
			Material = Enum.Material.SmoothPlastic,
		})
		glove:SetAttribute("IsPunching", true)
		glove:SetAttribute("PunchDirection", punchDir)
		glove:SetAttribute("PunchDistance", punchDistance)
		glove:SetAttribute("PunchSpeed", punchSpeed)
		glove:SetAttribute("PunchPhase", cfg.phase)
		glove:SetAttribute("PushForce", 2500)
		glove:SetAttribute("PushUpForce", 1200)
		glove.Parent = obstacles

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 80, 60)
		light.Brightness = 0.8
		light.Range = 10
		light.Parent = glove

		-- === แขนไม้ (Arm) — IsPunching ด้วย (เคลื่อนที่เหมือนนวม) ===
		local armZ = retractedZ + cfg.side * (gloveSize.Z / 2 + armSize.Z / 2)
		local arm = createPart({
			Name = "Arm_" .. i,
			Size = armSize,
			Position = startPosition + Vector3.new(cfg.xOffset, fistY, armZ),
			Color = armWoodColor,
			Material = Enum.Material.Wood,
		})
		arm:SetAttribute("IsPunching", true)
		arm:SetAttribute("PunchDirection", punchDir)
		arm:SetAttribute("PunchDistance", punchDistance)
		arm:SetAttribute("PunchSpeed", punchSpeed)
		arm:SetAttribute("PunchPhase", cfg.phase)
		arm.Parent = obstacles

		-- === เสาฐาน (static, ไม่ขยับ) ===
		local postZ = (pathWidth / 2 + wallThickness + 0.5) * cfg.side
		local post = createPart({
			Name = "Post_" .. i,
			Size = Vector3.new(3, wallHeight, 3),
			Position = startPosition + Vector3.new(cfg.xOffset, wallHeight / 2, postZ),
			Color = Color3.fromRGB(160, 155, 145),
			Material = Enum.Material.SmoothPlastic,
		})
		post.Parent = obstacles

		-- === Warning zone บนพื้น (สีแดงโปร่ง บอกตำแหน่งอันตราย) ===
		local warningZone = createPart({
			Name = "WarningZone_" .. i,
			Size = Vector3.new(gloveSize.X + 1, 0.15, pathWidth - 1),
			Position = startPosition + Vector3.new(cfg.xOffset, 0.6, 0),
			Color = Color3.fromRGB(255, 60, 40),
			Material = Enum.Material.Neon,
		})
		warningZone.Transparency = 0.7
		warningZone.CanCollide = false
		warningZone.Parent = obstacles
	end

	-- Item pickups ระหว่างกลุ่มนวม
	local itemPositions = { 20, 40, 60, 80 }
	for _, itemX in ipairs(itemPositions) do
		local item = createItemPickup(startPosition + Vector3.new(itemX, 3, 0))
		item.Parent = itemPickups
	end

	-- End Part
	local endPart = createPart({
		Name = "EndPart",
		Size = Vector3.new(8, 2, 8),
		Position = startPosition + Vector3.new(stageLength, 0, 0),
		Color = floorColor,
		Material = Enum.Material.SmoothPlastic,
	})
	endPart.Parent = stage

	return stage
end

-- Get all stage creators
function StageTemplates.getStageCreators(): {(Vector3) -> Model}
	return {
		StageTemplates.createStage1,  -- Easy: Jump
		StageTemplates.createStage2,  -- Normal: Moving
		StageTemplates.createStage3,  -- Normal: Spin
		StageTemplates.createStage4,  -- Hard: Disappear
		StageTemplates.createStage5,  -- Hard: Combo
		StageTemplates.createStage6,  -- Hard: Lava Rise
		StageTemplates.createStage7,  -- Hard: Narrow
		StageTemplates.createStage8,  -- Easy: Candy Rainbow
		StageTemplates.createStage9,  -- Easy: Rope Walk
		StageTemplates.createStage10, -- Easy: Rainbow Zigzag
		StageTemplates.createStage11, -- Normal: Lane Switch
		StageTemplates.createStage12, -- Normal: Pendulum
		StageTemplates.createStage13, -- Easy: Spinning Bars
		StageTemplates.createStage14, -- Easy: Fist Corridor
	}
end

return StageTemplates
