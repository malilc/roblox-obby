-- StageTracker: Lightweight per-round stage progress tracking
-- Replaces ScoreManager's stage tracking (no DataStore — transient per-round)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(ReplicatedStorage.Shared.Logger)

local StageTracker = {}
StageTracker.__index = StageTracker

function StageTracker.new()
	local self = setmetatable({}, StageTracker)
	self.playerStages = {} :: {[Player]: number}
	return self
end

function StageTracker:initPlayer(player: Player)
	self.playerStages[player] = 0
end

function StageTracker:getCurrentStage(player: Player): number
	return self.playerStages[player] or 0
end

function StageTracker:setCurrentStage(player: Player, stage: number)
	self.playerStages[player] = stage
end

-- Advance to the given stage index. Returns false if already passed.
function StageTracker:advanceStage(player: Player, stageIndex: number): boolean
	local current = self.playerStages[player] or 0
	if stageIndex <= current then
		return false
	end
	self.playerStages[player] = stageIndex
	Logger.debug("StageTracker", player.Name, "advanced to stage", stageIndex)
	return true
end

function StageTracker:resetRound(player: Player)
	self.playerStages[player] = 0
end

function StageTracker:removePlayer(player: Player)
	self.playerStages[player] = nil
end

return StageTracker
