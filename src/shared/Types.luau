-- Type Definitions for Obby Game

export type PlayerData = {
	UserId: number,
	CurrentStage: number,
	Currency: number,
	Gems: number,
	Wins: number,
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

export type GameState = "Lobby" | "Playing" | "Finished"

-- Interface types for cross-manager references (used instead of any?)
export type CurrencyManagerLike = {
	getCurrency: (self: any, player: Player) -> number,
	canAfford: (self: any, player: Player, amount: number) -> boolean,
	spendCurrency: (self: any, player: Player, amount: number, reason: string) -> boolean,
	addCurrency: (self: any, player: Player, amount: number) -> (),
	isClassUnlocked: (self: any, player: Player, classId: string) -> boolean,
	unlockClass: (self: any, player: Player, classId: string) -> boolean,
	getUnlockedClasses: (self: any, player: Player) -> {[string]: boolean},
	getEquippedClass: (self: any, player: Player) -> string,
	setEquippedClass: (self: any, player: Player, classId: string) -> (),
	getClassMasterySnapshot: ((self: any, player: Player) -> any)?,
	getMasteryRewardsSnapshot: ((self: any, player: Player) -> any)?,
}

return {}
