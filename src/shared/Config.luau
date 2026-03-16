-- Game Configuration
local Config = {
	-- Update log version (bump this to re-show update log to all players)
	PromoVersion = "1.0",

	-- Update log entries (newest first — shown in scrollable panel)
	UpdateLog = {
		{
			version = "1.0",
			title = "Launch Update",
			notes = {
				{heading = "Match System", items = {
					"Create & join match rooms with other players",
					"Auto-join waiting rooms from the selection zone",
					"Host can start the match when ready",
					"Stage voting system for multiplayer",
				}},
				{heading = "Race Features", items = {
					"15-minute race timer with time warnings",
					"30-second finish countdown after 1st place",
					"Live rankings display during races",
					"Spectator mode for finished players",
				}},
				{heading = "Classes & Items", items = {
					"8 unique character classes with special powers",
					"Ultimate skills: Sprint, Double Jump, Iron Will",
					"Mario Kart-style items to boost or sabotage",
					"Class mastery system with unlockable titles",
				}},
				{heading = "Progression", items = {
					"Gems & Wins tracking with leaderboards",
					"Daily login rewards (7-day streak)",
					"Shop with item purchases & class gacha",
				}},
			},
		},
	},

	-- Lobby Settings
	Lobby = {
		SpawnPosition = Vector3.new(0, 102, -8),
		TeleporterPosition = Vector3.new(0, 3, 20),
	},

	-- Match Settings (Multiplayer Race)
	Match = {
		MinPlayers = 1,        -- Solo testing enabled
		MaxPlayers = 24,       -- Maximum players per match
		WaitTime = 3,          -- Testing: 3 วิ, Production: 30-60 วิ
		IsTestingMode = true,  -- Toggle สำหรับ testing
		TimeLimit = 900,       -- 15 นาที (900 วินาที) per match
		-- แจ้งเตือนเมื่อเหลือเวลา (วินาที)
		TimeWarnings = {300, 60, 30, 10}, -- 5min, 1min, 30s, 10s
	},

	-- Stage Settings
	Stages = {
		TotalCount = 7,        -- จำนวนด่านทั้งหมดใน pool
		SelectionCount = 5,    -- จำนวนด่านที่เลือกต่อรอบ (แก้ได้เพื่อ test)
		StageLength = 100,     -- ความยาวแต่ละด่าน (studs)
		StartOffset = Vector3.new(-150, 0, 250), -- ตำแหน่งเริ่มต้นของด่านแรก
		BalancedRandom = {
			MinPerDifficulty = 1, -- การันตีอย่างน้อย 1 ด่านจากแต่ละระดับความยาก
		},
	},

	-- Gem Settings (premium currency)
	Gems = {
		FinishRace = 1,      -- +1 gem เมื่อเข้าเส้นชัย
		Top30Bonus = 5,      -- +5 gems เมื่อจบ top 30%
		DailyLoginGems = {   -- gem rewards ต่อวัน (ควบคู่กับ coins)
			[1] = 1,
			[2] = 1,
			[3] = 2,
			[4] = 2,
			[5] = 3,
			[6] = 3,
			[7] = 5,
		},
	},

	-- Currency Settings
	Currency = {
		PerStage = 5, -- โบนัสคงที่เมื่อผ่านด่าน
		PerCoin = 1, -- เงินที่ได้เมื่อเก็บเหรียญ
		FinishBonus = 25, -- โบนัสเงินเมื่อเข้าเส้นชัย
		StartingAmount = 0, -- เงินเริ่มต้นของผู้เล่นใหม่
		-- StageRewards ย้ายไป StageInfo.Stages[i].reward แล้ว
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

	-- Shop Settings
	Shop = {
		-- Item prices by rarity (coins)
		ItemPrices = {
			Common = 15,
			Uncommon = 35,
			Rare = 75,
			Epic = 150,
		},
		-- Gacha settings
		Gacha = {
			CostGems = 10,
			DuplicateGemsBack = 3,
		},
		-- Gacha class weights (higher = more likely, Normal excluded)
		GachaWeights = {
			Runner = 35,
			Jumper = 35,
			Tank = 30,
		},
		RequestCooldown = 0.5,
	},

	-- Game Pass definitions (set gamePassId to actual Roblox Game Pass IDs)
	GamePasses = {
		DoubleCoin = {
			id = "DoubleCoin",
			name = "2x Coins",
			description = "Earn double coins from every stage! Stack your riches faster.",
			icon = "\u{1F4B0}",
			gamePassId = 1740745787,
			robuxPrice = 99,
			layoutOrder = 1,
		},
		VIP = {
			id = "VIP",
			name = "VIP",
			description = "Exclusive VIP badge, special chat tag, and a golden name glow!",
			icon = "\u{2B50}",
			gamePassId = 1741108491,
			robuxPrice = 199,
			layoutOrder = 2,
		},
		ExtraSlot = {
			id = "ExtraSlot",
			name = "Extra Slot",
			description = "Unlock a 3rd item slot! Carry more items into the race.",
			icon = "\u{1F392}",
			gamePassId = 1740769746,
			robuxPrice = 149,
			layoutOrder = 3,
		},
	},
	GamePassOrder = { "DoubleCoin", "VIP", "ExtraSlot" },

	-- Class Mastery Settings
	Mastery = {
		MaxLevel = 20,
		BaseXpPerLevel = 100,
		XpGrowthMultiplier = 1.25,
		PerStageXP = 20,
		FinishBonusXP = 60,
		-- Ultimate skill unlock level
		UltimateUnlockLevel = 10,
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
		-- Mastery rewards (Skill is gameplay, Title/Trail are cosmetic)
		Rewards = {
			Normal = {
				-- No skill — Normal is the free basic class
				{id = "normal_title_balanced_cadet", level = 15, rewardType = "Title", rarity = "Epic", name = "Balanced Cadet", description = "Title for mastering the basics"},
				{id = "normal_trail_calm_flow", level = 20, rewardType = "Trail", rarity = "Legendary", name = "Calm Flow", description = "Soft white trail effect"},
			},
			Runner = {
				{id = "runner_skill_sprint", level = 10, rewardType = "Skill", rarity = "Rare", name = "Sprint", description = "Press Shift to run 50% faster for 3 seconds"},
				{id = "runner_title_quickstep", level = 15, rewardType = "Title", rarity = "Epic", name = "Quickstep", description = "Title for speed-focused players"},
				{id = "runner_trail_speed_streak", level = 20, rewardType = "Trail", rarity = "Legendary", name = "Speed Streak", description = "Fast blue streak trail"},
			},
			Jumper = {
				{id = "jumper_skill_doublejump", level = 10, rewardType = "Skill", rarity = "Rare", name = "Double Jump", description = "Jump again in mid-air"},
				{id = "jumper_title_skybound", level = 15, rewardType = "Title", rarity = "Epic", name = "Skybound", description = "Title for aerial control specialists"},
				{id = "jumper_trail_arc_glow", level = 20, rewardType = "Trail", rarity = "Legendary", name = "Arc Glow", description = "Light green arc-like trail"},
			},
			Tank = {
				{id = "tank_skill_ironwill", level = 10, rewardType = "Skill", rarity = "Rare", name = "Iron Will", description = "Immune to all item stuns"},
				{id = "tank_title_iron_stance", level = 15, rewardType = "Title", rarity = "Epic", name = "Iron Stance", description = "Title for durable playstyle"},
				{id = "tank_trail_heavy_pulse", level = 20, rewardType = "Trail", rarity = "Legendary", name = "Heavy Pulse", description = "Dense gold pulse trail"},
			},
		},
	},

	-- DataStore
	DataStore = {
		Name = "ObbyGameData_v1",
		CurrencyKey = "PlayerCurrency",
	},

	-- Kill Zone
	KillZoneY = -120, -- ความสูงที่จะตายเมื่อตกลงไป

	-- Tutorial Settings
	Tutorial = {
		Sections = {
			{id = "movement", title = "Movement", icon = "🏃", content = '<font color="#1A6B8A"><b>Controls</b></font>\n  <font color="#806000">WASD</font> — Move    <font color="#806000">Space</font> — Jump\n  <font color="#806000">Shift</font> — Sprint (if unlocked)\n\n<font color="#1A6B8A"><b>Mobile</b></font>\n  Use the joystick and jump button on screen.\n\n<font color="#1A6B8A"><b>Falling</b></font>\n  Fall off the map? No worries!\n  You\'ll respawn at the <font color="#1A7A3A">last checkpoint</font>.'},
			{id = "items", title = "Items", icon = "🎁", content = '<font color="#1A6B8A"><b>How to Get Items</b></font>\n  Run through <font color="#806000">item boxes</font> on the course to collect them.\n\n<font color="#1A6B8A"><b>Using Items</b></font>\n  Press <font color="#806000">[1]</font> or <font color="#806000">[2]</font> to use items from your slots.\n  On mobile, tap the item buttons on screen.\n\n<font color="#1A6B8A"><b>Rarities</b></font>\n  <font color="#777788">Common</font> · <font color="#2A7A2A">Uncommon</font> · <font color="#2255CC">Rare</font> · <font color="#7733AA">Epic</font>\n  Players behind get <font color="#806000">better items</font>!'},
			{id = "classes", title = "Classes", icon = "⚔️", content = '<font color="#1A6B8A"><b>Choose a Class</b></font>\n  Pick your play style in the lobby before a match.\n\n<font color="#777788"><b>Normal</b></font> — Balanced stats <font color="#1A7A3A">(Free)</font>\n<font color="#BB5511"><b>Runner</b></font> — +15% speed, -10% jump\n<font color="#1177AA"><b>Jumper</b></font> — -10% speed, +20% jump\n<font color="#806000"><b>Tank</b></font> — -15% speed, stun immunity\n\n  Unlock new classes with <font color="#806000">currency</font>!'},
			{id = "mastery", title = "Mastery & Titles", icon = "🏆", content = '<font color="#1A6B8A"><b>Mastery XP</b></font>\n  Earn XP by completing stages in matches.\n  Each class levels up independently <font color="#806000">(Lv.1 — 20)</font>.\n\n<font color="#1A6B8A"><b>Titles</b></font>\n  Unlock cosmetic titles at mastery milestones.\n  Equip titles to show off your skill!\n  Titles appear above your character.'},
			{id = "ultimates", title = "Ultimate Skills", icon = "⚡", content = '<font color="#1A6B8A"><b>How to Unlock</b></font>\n  Reach <font color="#806000">mastery level 10</font> on a class to unlock its skill!\n\n<font color="#1A6B8A"><b>Skills</b></font>\n  <font color="#BB5511"><b>Runner</b></font> — Sprint <font color="#555566">(Shift)</font>: 50% speed boost\n  <font color="#1177AA"><b>Jumper</b></font> — Double Jump <font color="#555566">(Space in air)</font>\n  <font color="#806000"><b>Tank</b></font> — Iron Will: immune to stuns'},
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

	-- Timing Settings (extracted magic numbers)
	Timing = {
		LeaderboardSendDelay = 3,       -- วินาทีก่อนส่ง leaderboard ให้ player ใหม่
		CharacterSetupDelay = 0.5,      -- วินาทีรอ character โหลด
		PositionCheckInterval = 0.5,    -- วินาทีระหว่างตรวจ player position
		SelectionZoneInterval = 0.2,    -- วินาทีระหว่างตรวจ selection zone
		AutoTeleportDelay = 5,          -- วินาทีก่อน auto-teleport กลับ lobby
		TeleportFlagClearDelay = 0.5,   -- วินาทีก่อน clear teleporting flag
		AutoSaveInterval = 30,          -- วินาทีระหว่าง auto-save
		LeaderstatsLoadDelay = 1,       -- วินาทีรอ leaderstats โหลด
	},

	-- Map Physics Settings
	Map = {
		StageGapStuds = 10,             -- ระยะห่างระหว่าง stage (studs)
		FinishLineRadius = 20,          -- ระยะตรวจจับ finish line (studs)
		PlatformServoForce = 1000000,   -- แรง servo ของ moving platform
		PlatformServoSpeed = 50,        -- ความเร็ว servo ของ moving platform
	},

	-- Feedback System (Discord Webhook)
	Feedback = {
		WebhookUrls = {
			Bug = "https://discord.com/api/webhooks/1483045557097463870/NTQtBCu94zm8xuL2ay7YYBJy9tg1ocQzU7sT1VGDCD-q2eP_NgFP9SDVCmC2WAzzmK_f",
			Suggestion = "https://discord.com/api/webhooks/1483054910374285322/n7v1ifkk5P1rwI-MbeuWWRTdl4-CucfhbwZJ5FWwFgih6QIK4-j9kuLhQKFe8bpPmsDV",
			Other = "https://discord.com/api/webhooks/1483055015009456219/v8njgEZmbxM93hZzBl0MrqgOFxi8q8-qzOUZcopqtx3lQqDDoZqE-NwOcAfVEVNJ8yn-",
		},
		MaxLength = 500,
		CooldownSeconds = 60,
	},

	-- Debug / Development Settings
	Debug = {
		Enabled = true,    -- Master toggle: set false for production
		FlyMode = true,    -- Press F to fly (client)
		ItemTesting = true, -- Toggle button for testing menu (items, mastery, solo start)
	},
}

return Config
