-- Stage Templates Generator
-- สร้าง 7 ด่านสำหรับ Obby (1 Easy + 2 Normal + 4 Hard)

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
	checkpoint.Material = Enum.Material.Neon
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

-- Helper function สร้าง Item Box (Neon Cube Style - Cyberpunk)
local function createItemPickup(position: Vector3): Part
	-- สร้าง Part หลัก - Neon Cube
	local pickup = Instance.new("Part")
	pickup.Name = "ItemBox"
	pickup.Anchored = true
	pickup.CanCollide = false
	pickup.Size = Vector3.new(3, 3, 3)
	pickup.Transparency = 0
	pickup.Material = Enum.Material.Neon
	pickup.Color = Color3.fromRGB(150, 100, 255) -- สีม่วง-ฟ้า (cyberpunk style)
	
	-- ยกขึ้น 3 studs
	local raisedPosition = position + Vector3.new(0, 3, 0)
	pickup.Position = raisedPosition
	
	-- เพิ่ม Friction สูงเพื่อไม่ให้ลื่น
	pickup.CustomPhysicalProperties = PhysicalProperties.new(
		0.7,  -- Density
		2.0,  -- Friction
		0.1,  -- Elasticity
		1.0,  -- FrictionWeight
		0.5   -- ElasticityWeight
	)
	
	-- Particle effect - สีน้ำเงิน/ม่วง cyberpunk
	local particles = Instance.new("ParticleEmitter")
	particles.Lifetime = NumberRange.new(0.5, 1)
	particles.Rate = 15
	particles.Speed = NumberRange.new(2, 5)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0)
	})
	particles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 150, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 100, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 200, 255)),
	})
	particles.LightEmission = 1
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1)
	})
	particles.Parent = pickup
	
	-- PointLight สีฟ้า-ม่วง
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(100, 150, 255)
	light.Brightness = 2
	light.Range = 10
	light.Parent = pickup
	
	-- Item Box attributes (ไม่ใช่ Coin - จะได้ random item)
	pickup:SetAttribute("IsItemBox", true)
	pickup:SetAttribute("IsCoin", false) -- ไม่ใช่เหรียญ - จะได้ item แทน
	pickup:SetAttribute("SpinSpeed", 2)
	pickup:SetAttribute("OriginalY", raisedPosition.Y) -- สำหรับ bobbing animation
	
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
		platform:SetAttribute("MoveAxis", if i % 2 == 0 then "X" else "Y")
		platform:SetAttribute("MoveDistance", 10)
		platform:SetAttribute("MoveSpeed", 3)
		
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
		Material = Enum.Material.Neon,
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
		Material = Enum.Material.Neon,
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
		Material = Enum.Material.Neon,
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
	}
end

return StageTemplates
