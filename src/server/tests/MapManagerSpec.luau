local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapManager = require(script.Parent.Parent.MapManager)
local Config = require(ReplicatedStorage.Shared.Config)

local function assertTrue(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

local function assertEqual(a: any, b: any, message: string)
	if a ~= b then
		error(message, 2)
	end
end

local function ensureStagesFolder(): Folder
	local existing = workspace:FindFirstChild("Stages")
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = "Stages"
	folder.Parent = workspace
	return folder
end

local function withMap(order: {number}, fn: (MapManager) -> ())
	ensureStagesFolder()
	local manager = MapManager.new()
	manager:generateMapWithOrder(order)

	local ok, err = pcall(fn, manager)
	manager:clearMap()
	if not ok then
		error(err, 2)
	end
end

local tests = {}

tests.shuffle_stages_returns_all_indices = function()
	ensureStagesFolder()
	local manager = MapManager.new()
	local order = manager:shuffleStages()

	assertEqual(#order, Config.Stages.Count, "shuffleStages should return Config.Stages.Count entries")

	local seen = {}
	for _, value in ipairs(order) do
		seen[value] = (seen[value] or 0) + 1
	end

	for i = 1, Config.Stages.Count do
		assertEqual(seen[i], 1, "shuffleStages should include each stage exactly once")
	end
end

tests.generate_map_sets_stage_attributes = function()
	withMap({ 1, 2 }, function(manager)
		assertEqual(#manager.currentStages, 2, "generateMapWithOrder should create two stages")
		assertEqual(manager.stageOrder[1], 1, "stageOrder should track provided order")
		assertEqual(manager.stageOrder[2], 2, "stageOrder should track provided order")

		local firstStage = manager.currentStages[1]
		assertTrue(firstStage ~= nil, "First stage should exist")
		assertEqual(firstStage:GetAttribute("StageIndex"), 1, "StageIndex attribute should be set")
		assertEqual(firstStage:GetAttribute("StageType"), 1, "StageType attribute should be set")
	end)
end

tests.checkpoint_and_finish_helpers = function()
	withMap({ 3 }, function(manager)
		local checkpointPos = manager:getCheckpointPosition(1)
		assertTrue(checkpointPos ~= nil, "Checkpoint position should exist for stage 1")

		local stage = manager.currentStages[1]
		local startPart = stage:FindFirstChild("StartPart")
		assertTrue(startPart ~= nil, "StartPart should exist on stage")

		local stageIndex = manager:getStageIndexFromPosition(startPart.Position)
		assertEqual(stageIndex, 1, "Position inside stage should resolve to stage index")

		local finishPos = manager:getFinishLinePosition()
		assertTrue(finishPos ~= nil, "Finish line position should exist")
		assertTrue(manager:isAtFinishLine(finishPos), "Finish position should be recognized as finish line")
	end)
end

tests.collectors_return_expected_items = function()
	withMap({ 3 }, function(manager)
		local checkpoints = manager:getAllCheckpoints()
		assertEqual(#checkpoints, 1, "getAllCheckpoints should return one checkpoint")

		local pickups = manager:getAllItemPickups()
		assertTrue(#pickups > 0, "getAllItemPickups should return at least one pickup")

		local killParts = manager:getAllKillParts()
		assertTrue(#killParts > 0, "getAllKillParts should return kill parts for stage 3")
	end)
end

return tests
