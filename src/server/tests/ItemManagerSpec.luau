local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemManager = require(script.Parent.Parent.ItemManager)
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

	ensureRemote("UseItem")
	ensureRemote("UpdateScore")
end

local function makePlayer(name: string)
	return {
		Name = name,
	}
end

local tests = {}

tests.init_and_add_push_item = function()
	ensureRemotes()
	local manager = ItemManager.new()
	manager.sendItemUpdate = function() end

	local player = makePlayer("Tester")
	manager:initPlayer(player)

	assertEqual(manager:getPushCount(player), Config.PushItem.StartingAmount, "Starting push count should match config")

	manager:addPushItem(player, Config.PushItem.MaxAmount)
	assertEqual(manager:getPushCount(player), Config.PushItem.MaxAmount, "Push count should clamp to max amount")
end

tests.reset_player_items = function()
	ensureRemotes()
	local manager = ItemManager.new()
	manager.sendItemUpdate = function() end

	local player = makePlayer("Tester")
	manager:initPlayer(player)
	manager:addPushItem(player, 2)
	manager:resetPlayer(player)

	assertEqual(manager:getPushCount(player), Config.PushItem.StartingAmount, "Reset should restore starting amount")
end

tests.cooldown_remaining_calculates = function()
	ensureRemotes()
	local manager = ItemManager.new()
	manager.sendItemUpdate = function() end

	local player = makePlayer("Tester")
	manager:initPlayer(player)

	manager.playerItems[player].lastPushTime = tick()
	local remaining = manager:getCooldownRemaining(player)
	assertTrue(remaining > 0, "Cooldown remaining should be positive right after push")
end

tests.apply_push_force_creates_effects = function()
	local manager = ItemManager.new()

	local from = Instance.new("Part")
	from.Name = "FromPart"
	from.Position = Vector3.new(0, 0, 0)
	from.Parent = workspace

	local target = Instance.new("Part")
	target.Name = "TargetPart"
	target.Position = Vector3.new(10, 0, 0)
	target.Parent = workspace

	manager:applyPushForce(from, target)

	local bodyVelocity = target:FindFirstChildOfClass("BodyVelocity")
	assertTrue(bodyVelocity ~= nil, "BodyVelocity should be created on target")

	local effectFound = false
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == "PushEffect" then
			effectFound = true
			child:Destroy()
			break
		end
	end
	assertTrue(effectFound, "Push effect should be created in workspace")

	from:Destroy()
	target:Destroy()
end

return tests
