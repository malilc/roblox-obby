-- Stage Templates Generator
-- สร้าง 5 ด่านพื้นฐานสำหรับ Obby

local StageTemplates = {}

local STAGE_LENGTH = 100
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

-- Item Box Mesh Asset ID (ใช้ ID ที่ผู้ใช้ให้มา)
local ITEM_BOX_MESH_ID = "rbxassetid://6325349064"

-- Helper function สร้าง Item Pickup (Item Box Style)
local function createItemPickup(position: Vector3): Part
	-- สร้าง Part หลัก
	local pickup = Instance.new("Part")
	pickup.Name = "ItemPickup"
	pickup.Anchored = true
	pickup.CanCollide = false
	pickup.Size = Vector3.new(3, 3, 3)
	pickup.Transparency = 0
	pickup.Material = Enum.Material.SmoothPlastic
	pickup.Color = Color3.fromRGB(255, 215, 0) -- สีทอง base
	
	-- ยกขึ้น 3 studs
	local raisedPosition = position + Vector3.new(0, 3, 0)
	pickup.Position = raisedPosition
	
	-- เพิ่ม SpecialMesh สำหรับ Item Box
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = ITEM_BOX_MESH_ID
	-- อาจต้องใส่ TextureId ด้วยถ้ามี (เช่น rbxassetid://...)
	-- mesh.TextureId = "rbxassetid://..." 
	mesh.Scale = Vector3.new(0.30, 0.30, 0.30) -- ปรับขนาดเป็น 0.30 ตามที่ขอ
	mesh.Parent = pickup
	
	-- Add sparkle effect
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Lifetime = NumberRange.new(0.3, 0.6)
	sparkles.Rate = 8
	sparkles.Speed = NumberRange.new(0.5, 1.5)
	sparkles.Size = NumberSequence.new(0.3, 0)
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
	sparkles.LightEmission = 1
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = pickup
	
	-- Add PointLight for glow
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 50)
	light.Brightness = 0.8
	light.Range = 6
	light.Parent = pickup
	
	-- Spin animation - หมุนรอบแกน Y
	pickup:SetAttribute("IsCoin", true)
	pickup:SetAttribute("SpinSpeed", 2)
	
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
	
	-- Item pickup กลางด่าน
	local pickup = createItemPickup(startPosition + Vector3.new(STAGE_LENGTH / 2, 5, 0))
	pickup.Parent = itemPickups
	
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
	
	-- Item pickup
	local pickup = createItemPickup(startPosition + Vector3.new(STAGE_LENGTH / 2, 8, 0))
	pickup.Parent = itemPickups
	
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
	
	-- Item pickup
	local pickup = createItemPickup(startPosition + Vector3.new(STAGE_LENGTH / 2, 10, 0))
	pickup.Parent = itemPickups
	
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
	
	-- Item pickup
	local pickup = createItemPickup(startPosition + Vector3.new(STAGE_LENGTH / 2, 5, 0))
	pickup.Parent = itemPickups
	
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
	
	-- Item pickups (มากกว่าด่านอื่น)
	local pickup1 = createItemPickup(startPosition + Vector3.new(sectionLength, 5, 0))
	pickup1.Parent = itemPickups
	local pickup2 = createItemPickup(startPosition + Vector3.new(sectionLength * 3, 8, 0))
	pickup2.Parent = itemPickups
	
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

-- Get all stage creators
function StageTemplates.getStageCreators(): {(Vector3) -> Model}
	return {
		StageTemplates.createStage1,
		StageTemplates.createStage2,
		StageTemplates.createStage3,
		StageTemplates.createStage4,
		StageTemplates.createStage5,
	}
end

return StageTemplates
