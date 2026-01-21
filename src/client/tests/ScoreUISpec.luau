local Players = game:GetService("Players")

local ScoreUI = require(script.Parent.Parent.UI.ScoreUI)

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

local function createScreenGui()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ScoreUITestGui"
	screenGui.Parent = playerGui
	return screenGui
end

local tests = {}

tests.update_score_updates_labels = function()
	local screenGui = createScreenGui()
	local ui = ScoreUI.new(screenGui)

	ui:updateScore({
		roundScore = 10,
		currentStage = 2,
		highScore = 50,
	})

	assertEqual(ui.roundScoreLabel.Text, "10", "Round score label should update")
	assertEqual(ui.stageLabel.Text, "2/5", "Stage label should update")
	assertEqual(ui.highScoreLabel.Text, "50", "High score label should update")

	screenGui:Destroy()
end

tests.show_stage_complete_creates_notification = function()
	local screenGui = createScreenGui()
	local ui = ScoreUI.new(screenGui)

	ui:showStageComplete(1, false)
	local notification = screenGui:FindFirstChild("StageNotification")
	assertTrue(notification ~= nil, "Stage complete notification should be created")

	screenGui:Destroy()
end

return tests
