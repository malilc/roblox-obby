-- Game Configuration
local Config = {
	-- Lobby Settings
	Lobby = {
		SpawnPosition = Vector3.new(0, 102, -8),
		TeleporterPosition = Vector3.new(0, 3, 20),
	},

	-- Match Settings (Multiplayer Race)
	Match = {
		MinPlayers = 1,        -- Solo testing enabled
		MaxPlayers = 16,       -- Maximum players per match
		WaitTime = 3,          -- Testing: 3 วิ, Production: 30-60 วิ
		IsTestingMode = true,  -- Toggle สำหรับ testing
		TimeLimit = 900,       -- 15 นาที (900 วินาที) per match
		-- แจ้งเตือนเมื่อเหลือเวลา (วินาที)
		TimeWarnings = {300, 60, 30, 10}, -- 5min, 1min, 30s, 10s
	},

	-- Stage Settings
Stages = {
	Count = 5, -- จำนวนด่านที่จะสุ่ม
	StageLength = 100, -- ความยาวแต่ละด่าน (studs)
	StartOffset = Vector3.new(-150, 0, 250), -- ตำแหน่งเริ่มต้นของด่านแรก (ทางขวาและหน้า Lobby)
},

	-- Score Settings
	Score = {
		PerStage = 10, -- คะแนนต่อด่าน
		FinishBonus = 50, -- โบนัสเมื่อเข้าเส้นชัย
	},

	-- Currency Settings
	Currency = {
		PerStage = 5, -- โบนัสคงที่เมื่อผ่านด่าน
		PerCoin = 1, -- เงินที่ได้เมื่อเก็บเหรียญ
		FinishBonus = 25, -- โบนัสเงินเมื่อเข้าเส้นชัย
		StartingAmount = 0, -- เงินเริ่มต้นของผู้เล่นใหม่
		-- รางวัลเมื่อผ่านแต่ละด่าน
		StageRewards = {
			3, -- Stage 1 (Easy): 3 currency
			4, -- Stage 2 (Moving): 4 currency
			4, -- Stage 3 (Spinning): 4 currency
			5, -- Stage 4 (Disappearing): 5 currency
			6, -- Stage 5 (Hard): 6 currency
		},
	},

	-- Character Class Settings
	Classes = {
		DefaultClass = "Normal",
		-- ฟรีตั้งแต่เริ่มเกม
		FreeClasses = {
			Normal = true,
		},
		-- ราคาปลดล็อกคลาส
		Costs = {
			Runner = 300,
			Jumper = 450,
			Tank = 600,
		},
		-- กัน spam เรียก SelectClass
		RequestCooldown = 0.25,
	},

	-- Class Mastery Settings
	Mastery = {
		MaxLevel = 20,
		BaseXpPerLevel = 100,
		XpGrowthMultiplier = 1.25,
		PerStageXP = 20,
		FinishBonusXP = 60,
		-- Ultimate skill unlock level
		UltimateUnlockLevel = 20,
		-- Ultimate skills configuration
		UltimateSkills = {
			Runner = {
				id = "Sprint",
				name = "Sprint",
				description = "Press Shift to run 50% faster for 3 seconds",
				cooldown = 15,
				duration = 3,
				speedMultiplier = 1.5,
			},
			Jumper = {
				id = "DoubleJump",
				name = "Double Jump",
				description = "Jump again in mid-air",
				maxAirJumps = 1,
			},
			Tank = {
				id = "IronWill",
				name = "Iron Will",
				description = "Immune to all item stuns",
				stunImmunity = true,
			},
		},
		TitleThemes = {
			Common = {
				textColor = Color3.fromRGB(210, 210, 210),
				strokeColor = Color3.fromRGB(40, 40, 50),
				frameColor = Color3.fromRGB(80, 80, 95),
			},
			Rare = {
				textColor = Color3.fromRGB(120, 205, 255),
				strokeColor = Color3.fromRGB(25, 55, 85),
				frameColor = Color3.fromRGB(75, 135, 190),
			},
			Epic = {
				textColor = Color3.fromRGB(220, 150, 255),
				strokeColor = Color3.fromRGB(70, 30, 95),
				frameColor = Color3.fromRGB(155, 90, 215),
			},
			Legendary = {
				textColor = Color3.fromRGB(255, 220, 120),
				strokeColor = Color3.fromRGB(95, 65, 25),
				frameColor = Color3.fromRGB(220, 170, 70),
			},
		},
		-- Cosmetic-only rewards (no gameplay power)
		Rewards = {
			Normal = {
				{id = "normal_title_balanced_cadet", level = 5, rewardType = "Title", rarity = "Common", name = "Balanced Cadet", description = "Title for mastering the basics"},
				{id = "normal_trail_calm_flow", level = 10, rewardType = "Trail", rarity = "Rare", name = "Calm Flow", description = "Soft white trail effect"},
				{id = "normal_badge_specialist", level = 15, rewardType = "Badge", rarity = "Epic", name = "Normal Specialist", description = "Profile badge for Normal mastery"},
				{id = "normal_frame_master", level = 20, rewardType = "CardFrame", rarity = "Legendary", name = "Normal Master Frame", description = "Class card frame for max Normal mastery"},
			},
			Runner = {
				{id = "runner_title_quickstep", level = 5, rewardType = "Title", rarity = "Common", name = "Quickstep", description = "Title for speed-focused players"},
				{id = "runner_trail_speed_streak", level = 10, rewardType = "Trail", rarity = "Rare", name = "Speed Streak", description = "Fast blue streak trail"},
				{id = "runner_badge_specialist", level = 15, rewardType = "Badge", rarity = "Epic", name = "Runner Specialist", description = "Profile badge for Runner mastery"},
				{id = "runner_frame_master", level = 20, rewardType = "CardFrame", rarity = "Legendary", name = "Runner Master Frame", description = "Class card frame for max Runner mastery"},
			},
			Jumper = {
				{id = "jumper_title_skybound", level = 5, rewardType = "Title", rarity = "Common", name = "Skybound", description = "Title for aerial control specialists"},
				{id = "jumper_trail_arc_glow", level = 10, rewardType = "Trail", rarity = "Rare", name = "Arc Glow", description = "Light green arc-like trail"},
				{id = "jumper_badge_specialist", level = 15, rewardType = "Badge", rarity = "Epic", name = "Jumper Specialist", description = "Profile badge for Jumper mastery"},
				{id = "jumper_frame_master", level = 20, rewardType = "CardFrame", rarity = "Legendary", name = "Jumper Master Frame", description = "Class card frame for max Jumper mastery"},
			},
			Tank = {
				{id = "tank_title_iron_stance", level = 5, rewardType = "Title", rarity = "Common", name = "Iron Stance", description = "Title for durable playstyle"},
				{id = "tank_trail_heavy_pulse", level = 10, rewardType = "Trail", rarity = "Rare", name = "Heavy Pulse", description = "Dense gold pulse trail"},
				{id = "tank_badge_specialist", level = 15, rewardType = "Badge", rarity = "Epic", name = "Tank Specialist", description = "Profile badge for Tank mastery"},
				{id = "tank_frame_master", level = 20, rewardType = "CardFrame", rarity = "Legendary", name = "Tank Master Frame", description = "Class card frame for max Tank mastery"},
			},
		},
	},

	-- DataStore
	DataStore = {
		Name = "ObbyGameData_v1",
		ScoreKey = "PlayerScore",
		HighScoreKey = "HighScore",
		CurrencyKey = "PlayerCurrency",
	},

	-- Kill Zone
	KillZoneY = -120, -- ความสูงที่จะตายเมื่อตกลงไป

	-- Tutorial Settings
	Tutorial = {
		Sections = {
			{id = "movement", title = "Movement", icon = "🏃", content = '<font color="#AAD4FF"><b>Controls</b></font>\n  <font color="#FFDD77">WASD</font> — Move    <font color="#FFDD77">Space</font> — Jump\n  <font color="#FFDD77">Shift</font> — Sprint (if unlocked)\n\n<font color="#AAD4FF"><b>Mobile</b></font>\n  Use the joystick and jump button on screen.\n\n<font color="#AAD4FF"><b>Falling</b></font>\n  Fall off the map? No worries!\n  You\'ll respawn at the <font color="#77FF77">last checkpoint</font>.'},
			{id = "items", title = "Items", icon = "🎁", content = '<font color="#AAD4FF"><b>How to Get Items</b></font>\n  Run through <font color="#FFDD77">item boxes</font> on the course to collect them.\n\n<font color="#AAD4FF"><b>Using Items</b></font>\n  Press <font color="#FFDD77">[1]</font> or <font color="#FFDD77">[2]</font> to use items from your slots.\n  On mobile, tap the item buttons on screen.\n\n<font color="#AAD4FF"><b>Rarities</b></font>\n  <font color="#CCCCCC">Common</font> · <font color="#77DD77">Uncommon</font> · <font color="#7799FF">Rare</font> · <font color="#CC77FF">Epic</font>\n  Players behind get <font color="#FFDD77">better items</font>!'},
			{id = "classes", title = "Classes", icon = "⚔️", content = '<font color="#AAD4FF"><b>Choose a Class</b></font>\n  Pick your play style in the lobby before a match.\n\n<font color="#CCCCCC"><b>Normal</b></font> — Balanced stats <font color="#77FF77">(Free)</font>\n<font color="#FF9944"><b>Runner</b></font> — +15% speed, -10% jump\n<font color="#44BBFF"><b>Jumper</b></font> — -10% speed, +20% jump\n<font color="#FFDD44"><b>Tank</b></font> — -15% speed, stun immunity\n\n  Unlock new classes with <font color="#FFDD77">currency</font>!'},
			{id = "mastery", title = "Mastery & Titles", icon = "🏆", content = '<font color="#AAD4FF"><b>Mastery XP</b></font>\n  Earn XP by completing stages in matches.\n  Each class levels up independently <font color="#FFDD77">(Lv.1 — 20)</font>.\n\n<font color="#AAD4FF"><b>Titles</b></font>\n  Unlock cosmetic titles at mastery milestones.\n  Equip titles to show off your skill!\n  Titles appear above your character.'},
			{id = "ultimates", title = "Ultimate Skills", icon = "⚡", content = '<font color="#AAD4FF"><b>How to Unlock</b></font>\n  Reach <font color="#FFDD77">mastery level 20</font> on a class to unlock its ultimate!\n\n<font color="#AAD4FF"><b>Ultimate Skills</b></font>\n  <font color="#FF9944"><b>Runner</b></font> — Sprint <font color="#999999">(Shift)</font>: 50% speed boost\n  <font color="#44BBFF"><b>Jumper</b></font> — Double Jump <font color="#999999">(Space in air)</font>\n  <font color="#FFDD44"><b>Tank</b></font> — Iron Will: immune to stuns'},
		},
		HintDuration = 8,
	},

	-- Spectator Settings
	Spectator = {
		FreeCamSpeed = 50,
		FollowDistance = 15,
		FollowHeight = 8,
		CameraSmoothness = 0.1,
	},

	-- Daily Login (7-day streak)
	DailyLogin = {
		CooldownHours = 20,  -- รับได้หลังจาก 20 ชั่วโมง
		ResetHours    = 48,  -- streak reset ถ้าไม่ได้ login 48 ชั่วโมง
		Rewards = {          -- รางวัล coins แต่ละวัน (วนซ้ำหลังครบ 7 วัน)
			[1] = 25,
			[2] = 50,
			[3] = 75,
			[4] = 100,
			[5] = 150,
			[6] = 200,
			[7] = 500,
		},
	},

	-- Debug / Development Settings
	Debug = {
		Enabled = true,    -- Master toggle: set false for production
		FlyMode = true,    -- Press F to fly (client)
		ItemTesting = true, -- Press T for item test menu (client + server remotes)
		MasteryTesting = true, -- Press M for mastery test menu (client + server remotes)
	},
}

return Config
