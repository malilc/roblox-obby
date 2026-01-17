-- Type Definitions for Obby Game

export type PlayerData = {
	UserId: number,
	RoundScore: number,
	TotalScore: number,
	HighScore: number,
	CurrentStage: number,
	PushItemCount: number,
	LastCheckpoint: Vector3?,
	IsPlaying: boolean,
}

export type StageData = {
	StageNumber: number,
	Template: Model,
	StartPosition: Vector3,
	EndPosition: Vector3,
	CheckpointPosition: Vector3,
}

export type LeaderboardEntry = {
	UserId: number,
	PlayerName: string,
	Score: number,
}

export type GameState = "Lobby" | "Playing" | "Finished"

return {}
