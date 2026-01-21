local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ScoreManager = require(script.Parent.Parent.ScoreManager)
local Config = require(ReplicatedStorage.Shared.Config)

local function assertEqual(actual: any, expected: any, message: string)
	if actual ~= expected then
		error(message .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")", 2)
	end
end

local function assertTrue(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

local function ensureRemotes()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local function ensureRemote(name: string)
		local remote = remotes:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = remotes
		end
	end

	ensureRemote("UpdateScore")
	ensureRemote("UpdateLeaderboard")
end

local function makePlayer(name: string, userId: number)
	return {
		Name = name,
		UserId = userId,
	}
end

local tests = {}

tests.init_and_add_stage_score = function()
	ensureRemotes()
	local manager = ScoreManager.new()
	manager.dataStore = nil
	manager.sendScoreUpdate = function() end

	local player = makePlayer("Tester", 101)
	manager:initPlayer(player)

	local data = manager:getPlayerData(player)
	assertTrue(data ~= nil, "Player data should be initialized")
	assertEqual(data.roundScore, 0, "Initial round score should be 0")
	assertEqual(data.currentStage, 0, "Initial stage should be 0")

	manager:addStageScore(player, 1)
	assertEqual(data.currentStage, 1, "Stage should update to 1")
	assertEqual(data.roundScore, Config.Score.PerStage, "Round score should add per stage score")

	manager:addStageScore(player, 1)
	assertEqual(data.roundScore, Config.Score.PerStage, "Score should not increase for same stage")
end

tests.finish_bonus_updates_high_score = function()
	ensureRemotes()
	local manager = ScoreManager.new()
	manager.dataStore = nil
	manager.sendScoreUpdate = function() end
	manager.savePlayerData = function() end
	manager.updateLeaderboard = function() end

	local player = makePlayer("Tester", 102)
	manager:initPlayer(player)

	manager:addStageScore(player, 1)
	manager:addFinishBonus(player)

	local data = manager:getPlayerData(player)
	assertEqual(data.totalScore, data.roundScore, "Total score should include round score")
	assertEqual(data.highScore, data.roundScore, "High score should update to round score")
end

tests.reset_round_score = function()
	ensureRemotes()
	local manager = ScoreManager.new()
	manager.dataStore = nil
	manager.sendScoreUpdate = function() end

	local player = makePlayer("Tester", 103)
	manager:initPlayer(player)

	manager:addStageScore(player, 1)
	manager:resetRoundScore(player)

	local data = manager:getPlayerData(player)
	assertEqual(data.roundScore, 0, "Round score should reset to 0")
	assertEqual(data.currentStage, 0, "Current stage should reset to 0")
end

tests.update_leaderboard_inserts_and_sorts = function()
	ensureRemotes()
	local manager = ScoreManager.new()
	manager.dataStore = nil
	manager.broadcastLeaderboard = function() end
	manager.sendScoreUpdate = function() end

	local player = makePlayer("Tester", 104)
	manager:initPlayer(player)

	local data = manager:getPlayerData(player)
	data.highScore = 50
	manager:updateLeaderboard(player)

	assertEqual(#manager.leaderboard, 1, "Leaderboard should have one entry")
	assertEqual(manager.leaderboard[1].userId, 104, "Leaderboard entry should match player")

	local player2 = makePlayer("Tester2", 105)
	manager:initPlayer(player2)
	local data2 = manager:getPlayerData(player2)
	data2.highScore = 100
	manager:updateLeaderboard(player2)

	assertEqual(manager.leaderboard[1].userId, 105, "Leaderboard should be sorted by high score")
end

return tests
