-- Game Configuration
local Config = {
	-- Lobby Settings
	Lobby = {
		SpawnPosition = Vector3.new(0, 5, 0),
		TeleporterPosition = Vector3.new(0, 3, 20),
	},

	-- Stage Settings
	Stages = {
		Count = 5, -- จำนวนด่านที่จะสุ่ม
		StageLength = 100, -- ความยาวแต่ละด่าน (studs)
		StartOffset = Vector3.new(0, 0, 50), -- ตำแหน่งเริ่มต้นของด่านแรก
	},

	-- Score Settings
	Score = {
		PerStage = 10, -- คะแนนต่อด่าน
		FinishBonus = 50, -- โบนัสเมื่อเข้าเส้นชัย
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
	},

	-- Kill Zone
	KillZoneY = -20, -- ความสูงที่จะตายเมื่อตกลงไป
}

return Config
