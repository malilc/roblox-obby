-- ClassTypes: นิยาม Character Classes ทั้งหมด

export type ClassDefinition = {
	id: string,
	name: string,
	description: string,
	icon: string,
	color: Color3,
	-- Stats modifiers (multipliers)
	walkSpeedMod: number,
	jumpPowerMod: number,
	-- Special abilities
	knockbackResistance: number, -- 0-1 (1 = full immunity)
	-- Passive ability info
	passiveAbility: {
		name: string,
		description: string,
		cooldown: number?,
	},
	-- Ultimate skill (unlocked at mastery LV 20)
	ultimateSkill: {
		id: string,
		name: string,
		description: string,
	}?,
}

local ClassTypes = {}

-- Class definitions
ClassTypes.Classes = {
	Normal = {
		id = "Normal",
		name = "Normal",
		description = "สมดุลทุกด้าน เหมาะสำหรับเริ่มต้น",
		icon = "⚪",
		color = Color3.fromRGB(220, 220, 220),
		-- Stats
		walkSpeedMod = 1.00, -- normal speed
		jumpPowerMod = 1.00, -- normal jump
		knockbackResistance = 0,
		-- Passive
		passiveAbility = {
			name = "Balanced",
			description = "ไม่มีข้อได้เปรียบหรือข้อเสียพิเศษ",
			cooldown = nil,
		},
	},

	Runner = {
		id = "Runner",
		name = "Runner",
		description = "เร็วกว่าปกติ แต่กระโดดต่ำกว่า",
		icon = "🏃",
		color = Color3.fromRGB(100, 200, 255),
		-- Stats
		walkSpeedMod = 1.15, -- +15% speed
		jumpPowerMod = 0.90, -- -10% jump
		knockbackResistance = 0,
		-- Passive
		passiveAbility = {
			name = "Sprint Burst",
			description = "กด W สองครั้งติดกันเพื่อ mini boost (cooldown 15 วิ)",
			cooldown = 15,
		},
	},
	
	Jumper = {
		id = "Jumper",
		name = "Jumper",
		description = "กระโดดสูงกว่าปกติ แต่เดินช้ากว่า",
		icon = "🦘",
		color = Color3.fromRGB(100, 255, 100),
		-- Stats
		walkSpeedMod = 0.90, -- -10% speed
		jumpPowerMod = 1.20, -- +20% jump
		knockbackResistance = 0,
		-- Passive
		passiveAbility = {
			name = "Charged Jump",
			description = "กด Space ค้างเพื่อ charged jump (กระโดดสูงขึ้นอีก)",
			cooldown = nil, -- no cooldown
		},
	},
	
	Tank = {
		id = "Tank",
		name = "Tank",
		description = "ทนต่อการถูกโจมตี แต่เดินช้ากว่า",
		icon = "🛡️",
		color = Color3.fromRGB(255, 200, 100),
		-- Stats
		walkSpeedMod = 0.85, -- -15% speed
		jumpPowerMod = 1.00, -- normal jump
		knockbackResistance = 0.5, -- 50% knockback reduction
		-- Passive
		passiveAbility = {
			name = "Thick Skin",
			description = "ไม่โดน stun จาก items ระดับ Common",
			cooldown = nil,
		},
	},
}

ClassTypes.ClassOrder = {"Normal", "Runner", "Jumper", "Tank"}

-- Default class
ClassTypes.DefaultClass = "Normal"

-- Get class by ID
function ClassTypes.getClass(classId: string): ClassDefinition?
	return ClassTypes.Classes[classId]
end

-- Get all class IDs
function ClassTypes.getAllClassIds(): {string}
	local ids = {}

	for _, id in ipairs(ClassTypes.ClassOrder) do
		if ClassTypes.Classes[id] then
			table.insert(ids, id)
		end
	end

	-- Fallback for any class added outside ClassOrder
	for id, _ in pairs(ClassTypes.Classes) do
		if not table.find(ids, id) then
			table.insert(ids, id)
		end
	end

	return ids
end

-- Get class display info for UI
function ClassTypes.getClassDisplayInfo(classId: string): {
	name: string,
	description: string,
	icon: string,
	color: Color3,
	stats: {string},
	passive: string,
}?
	local classDef = ClassTypes.Classes[classId]
	if not classDef then return nil end
	
	-- Build stats display
	local stats = {}
	
	if classDef.walkSpeedMod ~= 1 then
		local speedPercent = math.floor((classDef.walkSpeedMod - 1) * 100)
		if speedPercent > 0 then
			table.insert(stats, string.format("Speed: +%d%%", speedPercent))
		else
			table.insert(stats, string.format("Speed: %d%%", speedPercent))
		end
	end
	
	if classDef.jumpPowerMod ~= 1 then
		local jumpPercent = math.floor((classDef.jumpPowerMod - 1) * 100)
		if jumpPercent > 0 then
			table.insert(stats, string.format("Jump: +%d%%", jumpPercent))
		else
			table.insert(stats, string.format("Jump: %d%%", jumpPercent))
		end
	end
	
	if classDef.knockbackResistance > 0 then
		local resistPercent = math.floor(classDef.knockbackResistance * 100)
		table.insert(stats, string.format("KB Resist: %d%%", resistPercent))
	end
	
	return {
		name = classDef.name,
		description = classDef.description,
		icon = classDef.icon,
		color = classDef.color,
		stats = stats,
		passive = classDef.passiveAbility.name .. ": " .. classDef.passiveAbility.description,
	}
end

-- Calculate modified stats
function ClassTypes.calculateStats(classId: string, baseWalkSpeed: number, baseJumpPower: number): (number, number)
	local classDef = ClassTypes.Classes[classId]
	if not classDef then
		return baseWalkSpeed, baseJumpPower
	end
	
	local modifiedWalkSpeed = baseWalkSpeed * classDef.walkSpeedMod
	local modifiedJumpPower = baseJumpPower * classDef.jumpPowerMod
	
	return modifiedWalkSpeed, modifiedJumpPower
end

return ClassTypes
