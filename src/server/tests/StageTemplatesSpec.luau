local StageTemplates = require(script.Parent.Parent.StageTemplates)

local function assertTrue(condition: boolean, message: string)
	if not condition then
		error(message, 2)
	end
end

local function assertVectorClose(a: Vector3, b: Vector3, tolerance: number, message: string)
	if (a - b).Magnitude > tolerance then
		error(message, 2)
	end
end

local function destroyIfExists(instance: Instance?)
	if instance then
		instance:Destroy()
	end
end

local tests = {}

tests.stage1_has_required_parts = function()
	local start = Vector3.new(0, 0, 0)
	local stage = StageTemplates.createStage1(start)

	local startPart = stage:FindFirstChild("StartPart")
	local endPart = stage:FindFirstChild("EndPart")
	local checkpoint = stage:FindFirstChild("Checkpoint")
	local obstacles = stage:FindFirstChild("Obstacles")
	local itemPickups = stage:FindFirstChild("ItemPickups")

	assertTrue(stage:IsA("Model"), "Stage1 should be a Model")
	assertTrue(startPart and startPart:IsA("BasePart"), "Stage1 should have StartPart")
	assertTrue(endPart and endPart:IsA("BasePart"), "Stage1 should have EndPart")
	assertTrue(checkpoint and checkpoint.ClassName == "Part", "Stage1 checkpoint should be a Part")
	assertTrue(obstacles and obstacles:IsA("Folder"), "Stage1 should have Obstacles folder")
	assertTrue(itemPickups and itemPickups:IsA("Folder"), "Stage1 should have ItemPickups folder")
	assertVectorClose(endPart.Position, start + Vector3.new(100, 0, 0), 0.01, "Stage1 EndPart position mismatch")

	local hasCoin = false
	for _, child in ipairs(itemPickups:GetChildren()) do
		if child:GetAttribute("IsCoin") then
			hasCoin = true
			break
		end
	end
	assertTrue(hasCoin, "Stage1 should include a coin pickup")

	destroyIfExists(stage)
end

tests.stage2_has_moving_platforms = function()
	local stage = StageTemplates.createStage2(Vector3.new(0, 0, 0))
	local obstacles = stage:FindFirstChild("Obstacles")

	assertTrue(obstacles and obstacles:IsA("Folder"), "Stage2 should have Obstacles folder")

	local movingCount = 0
	for _, child in ipairs(obstacles:GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute("IsMoving") then
			movingCount += 1
		end
	end
	assertTrue(movingCount > 0, "Stage2 should include moving platforms")

	destroyIfExists(stage)
end

tests.stage3_has_spinners = function()
	local stage = StageTemplates.createStage3(Vector3.new(0, 0, 0))
	local obstacles = stage:FindFirstChild("Obstacles")

	local spinnerCount = 0
	for _, child in ipairs(obstacles:GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute("IsSpinning") then
			assertTrue(child:GetAttribute("IsKillPart") == true, "Spinner should be a kill part")
			spinnerCount += 1
		end
	end
	assertTrue(spinnerCount > 0, "Stage3 should include spinning obstacles")

	destroyIfExists(stage)
end

tests.stage4_has_disappearing_platforms = function()
	local stage = StageTemplates.createStage4(Vector3.new(0, 0, 0))
	local obstacles = stage:FindFirstChild("Obstacles")

	local disappearingCount = 0
	for _, child in ipairs(obstacles:GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute("IsDisappearing") then
			disappearingCount += 1
		end
	end
	assertTrue(disappearingCount > 0, "Stage4 should include disappearing platforms")

	destroyIfExists(stage)
end

tests.stage5_has_finish_line = function()
	local stage = StageTemplates.createStage5(Vector3.new(0, 0, 0))

	local endPart = stage:FindFirstChild("EndPart")
	local finishBanner = stage:FindFirstChild("FinishBanner")

	assertTrue(endPart and endPart:IsA("BasePart"), "Stage5 should have EndPart")
	assertTrue(endPart:GetAttribute("IsFinishLine") == true, "Stage5 EndPart should be marked as finish line")
	assertTrue(finishBanner and finishBanner:IsA("BasePart"), "Stage5 should have a finish banner")

	destroyIfExists(stage)
end

return tests
