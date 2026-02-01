-- Game Configuration
local Config = {
	-- Lobby Settings
	Lobby = {
		SpawnPosition = Vector3.new(0, 103, 0),
		TeleporterPosition = Vector3.new(0, 3, 20),
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

	-- Push Item Settings
	PushItem = {
		StartingAmount = 1, -- จำนวน Push item เริ่มต้น
		MaxAmount = 5, -- จำนวนสูงสุดที่เก็บได้
		Range = 15, -- ระยะโจมตี (studs)
		Force = 100, -- แรงผลัก
		Cooldown = 10, -- cooldown (วินาที)
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
}

return Config
