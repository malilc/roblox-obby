-- StageInfo: Single source of truth for all stage metadata
-- Used by both server (MapManager, GameManager) and client (StageSelectionUI, SummaryUI)

local StageInfo = {}

export type Difficulty = "Easy" | "Normal" | "Hard"

export type StageData = {
	id: number,
	name: string,
	icon: string,
	difficulty: Difficulty,
	color: Color3,
	gradientEnd: Color3,
	reward: number,
}

StageInfo.Stages = {
	{
		id = 1,
		name = "Jump",
		icon = "🦘",
		difficulty = "Easy",
		color = Color3.fromRGB(76, 175, 80),
		gradientEnd = Color3.fromRGB(129, 199, 132),
		reward = 3,
	},
	{
		id = 2,
		name = "Moving",
		icon = "↔️",
		difficulty = "Normal",
		color = Color3.fromRGB(255, 152, 0),
		gradientEnd = Color3.fromRGB(255, 183, 77),
		reward = 4,
	},
	{
		id = 3,
		name = "Spin",
		icon = "🌀",
		difficulty = "Normal",
		color = Color3.fromRGB(156, 39, 176),
		gradientEnd = Color3.fromRGB(186, 104, 200),
		reward = 4,
	},
	{
		id = 4,
		name = "Disappear",
		icon = "💨",
		difficulty = "Hard",
		color = Color3.fromRGB(233, 30, 99),
		gradientEnd = Color3.fromRGB(240, 98, 146),
		reward = 5,
	},
	{
		id = 5,
		name = "Combo",
		icon = "⚡",
		difficulty = "Hard",
		color = Color3.fromRGB(244, 67, 54),
		gradientEnd = Color3.fromRGB(239, 154, 154),
		reward = 6,
	},
	{
		id = 6,
		name = "Lava Rise",
		icon = "🌋",
		difficulty = "Hard",
		color = Color3.fromRGB(255, 87, 34),
		gradientEnd = Color3.fromRGB(255, 138, 101),
		reward = 6,
	},
	{
		id = 7,
		name = "Narrow",
		icon = "🎯",
		difficulty = "Hard",
		color = Color3.fromRGB(183, 28, 28),
		gradientEnd = Color3.fromRGB(229, 115, 115),
		reward = 7,
	},
	{
		id = 8,
		name = "Candy Rainbow",
		icon = "🍭",
		difficulty = "Easy",
		color = Color3.fromRGB(255, 130, 170),
		gradientEnd = Color3.fromRGB(255, 200, 220),
		reward = 3,
	},
	{
		id = 9,
		name = "Rope Walk",
		icon = "🪢",
		difficulty = "Easy",
		color = Color3.fromRGB(160, 120, 70),
		gradientEnd = Color3.fromRGB(200, 165, 110),
		reward = 3,
	},
	{
		id = 10,
		name = "Rainbow Zigzag",
		icon = "🌈",
		difficulty = "Easy",
		color = Color3.fromRGB(255, 60, 60),
		gradientEnd = Color3.fromRGB(180, 80, 255),
		reward = 3,
	},
	{
		id = 11,
		name = "Lane Switch",
		icon = "🔀",
		difficulty = "Normal",
		color = Color3.fromRGB(0, 170, 255),
		gradientEnd = Color3.fromRGB(180, 80, 255),
		reward = 4,
	},
	{
		id = 12,
		name = "Pendulum",
		icon = "🔨",
		difficulty = "Normal",
		color = Color3.fromRGB(120, 120, 120),
		gradientEnd = Color3.fromRGB(180, 180, 180),
		reward = 4,
	},
}

-- Difficulty display metadata
StageInfo.DifficultyInfo = {
	Easy = {
		label = "EASY",
		color = Color3.fromRGB(76, 175, 80),
		badgeColor = Color3.fromRGB(56, 142, 60),
	},
	Normal = {
		label = "NORMAL",
		color = Color3.fromRGB(255, 193, 7),
		badgeColor = Color3.fromRGB(245, 170, 0),
	},
	Hard = {
		label = "HARD",
		color = Color3.fromRGB(244, 67, 54),
		badgeColor = Color3.fromRGB(211, 47, 47),
	},
}

-- Get stage data by ID
function StageInfo.getStage(id: number): StageData?
	return StageInfo.Stages[id]
end

-- Get all stages of a given difficulty
function StageInfo.getStagesByDifficulty(difficulty: Difficulty): {StageData}
	local result = {}
	for _, stage in ipairs(StageInfo.Stages) do
		if stage.difficulty == difficulty then
			table.insert(result, stage)
		end
	end
	return result
end

-- Get total stage count
function StageInfo.getTotalStageCount(): number
	return #StageInfo.Stages
end

return StageInfo
