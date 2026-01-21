local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameManager = require(script.Parent.Parent.GameManager)
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

local function makeCharacter(position: Vector3): Model
	local character = Instance.new("Model")
	character.Name = "Character"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Position = position
	root.Parent = character

	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character

	return character
end

local function makePlayer(position: Vector3)
	local player = {
		Name = "Tester",
	}
	player.Character = makeCharacter(position)
	return player
end

local tests = {}

tests.is_player_in_selection_zone = function()
	local zone = Instance.new("Part")
	zone.Size = Vector3.new(20, 10, 20)
	zone.Position = Vector3.new(0, 0, 0)
	zone.Parent = workspace

	local playerInside = makePlayer(Vector3.new(0, 0, 0))
	local playerOutside = makePlayer(Vector3.new(100, 0, 0))

	local isInside = GameManager.isPlayerInSelectionZone(GameManager, playerInside, zone)
	local isOutside = GameManager.isPlayerInSelectionZone(GameManager, playerOutside, zone)

	assertTrue(isInside, "Player inside zone should be detected")
	assertTrue(not isOutside, "Player outside zone should not be detected")

	playerInside.Character:Destroy()
	playerOutside.Character:Destroy()
	zone:Destroy()
end

tests.check_player_position_stage_complete = function()
	local player = makePlayer(Vector3.new(0, 0, 0))
	local stageCompleted = 0

	local gm = setmetatable({}, GameManager)
	gm.playerStates = {[player] = "Playing"}
	gm.teleportingToLobby = {}
	gm.mapManager = {
		getStageIndexFromPosition = function()
			return 2
		end,
		isAtFinishLine = function()
			return false
		end,
	}
	gm.scoreManager = {
		getCurrentStage = function()
			return 1
		end,
	}
	gm.onStageComplete = function(_, _, stageIndex)
		stageCompleted = stageIndex
	end
	gm.onPlayerFinished = function() end
	gm.respawnPlayer = function() end

	gm:checkPlayerPosition(player)
	assertEqual(stageCompleted, 2, "Stage completion should trigger when advancing stage")

	player.Character:Destroy()
end

tests.check_player_position_finish_line = function()
	local player = makePlayer(Vector3.new(0, 0, 0))
	local finished = false

	local gm = setmetatable({}, GameManager)
	gm.playerStates = {[player] = "Playing"}
	gm.teleportingToLobby = {}
	gm.mapManager = {
		getStageIndexFromPosition = function()
			return nil
		end,
		isAtFinishLine = function()
			return true
		end,
	}
	gm.scoreManager = {
		getCurrentStage = function()
			return 1
		end,
	}
	gm.onStageComplete = function() end
	gm.onPlayerFinished = function()
		finished = true
	end
	gm.respawnPlayer = function() end

	gm:checkPlayerPosition(player)
	assertTrue(finished, "Finish line should trigger onPlayerFinished")

	player.Character:Destroy()
end

tests.check_player_position_kill_zone = function()
	local player = makePlayer(Vector3.new(0, Config.KillZoneY - 10, 0))
	local respawned = false

	local gm = setmetatable({}, GameManager)
	gm.playerStates = {[player] = "Playing"}
	gm.teleportingToLobby = {}
	gm.mapManager = {
		getStageIndexFromPosition = function()
			return nil
		end,
		isAtFinishLine = function()
			return false
		end,
	}
	gm.scoreManager = {
		getCurrentStage = function()
			return 1
		end,
	}
	gm.onStageComplete = function() end
	gm.onPlayerFinished = function() end
	gm.respawnPlayer = function()
		respawned = true
	end

	gm:checkPlayerPosition(player)
	assertTrue(respawned, "Kill zone should trigger respawn")

	player.Character:Destroy()
end

tests.check_player_position_teleport_guard = function()
	local player = makePlayer(Vector3.new(0, 0, 0))
	local stageCompleted = 0

	local gm = setmetatable({}, GameManager)
	gm.playerStates = {[player] = "Playing"}
	gm.teleportingToLobby = {[player] = true}
	gm.mapManager = {
		getStageIndexFromPosition = function()
			return 2
		end,
		isAtFinishLine = function()
			return true
		end,
	}
	gm.scoreManager = {
		getCurrentStage = function()
			return 1
		end,
	}
	gm.onStageComplete = function(_, _, stageIndex)
		stageCompleted = stageIndex
	end
	gm.onPlayerFinished = function() end
	gm.respawnPlayer = function() end

	gm:checkPlayerPosition(player)
	assertEqual(stageCompleted, 0, "Teleport guard should skip checks")

	player.Character:Destroy()
end

return tests
