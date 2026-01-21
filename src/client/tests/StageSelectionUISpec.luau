local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local StageSelectionUI = require(script.Parent.Parent.UI.StageSelectionUI)

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

	local names = {
		"ShowStageSelection",
		"HideStageSelection",
		"ConfirmStageSelection",
		"CountdownUpdate",
	}
	for _, name in ipairs(names) do
		if not remotes:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = remotes
		end
	end
end

local function createScreenGui()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StageSelectionUITestGui"
	screenGui.Parent = playerGui
	return screenGui
end

local tests = {}

tests.toggle_and_clear_selection = function()
	ensureRemotes()
	local screenGui = createScreenGui()
	local ui = StageSelectionUI.new(screenGui)

	assertTrue(ui.startButton.Active == false, "Start button should be inactive initially")

	ui:toggleStage(1)
	assertEqual(#ui.selectedStages, 1, "Selected stages should increase")
	assertTrue(ui.stageButtons[1].indicator.Visible, "Selected indicator should show")
	assertTrue(ui.startButton.Active, "Start button should activate after selection")

	ui:clearSelection()
	assertEqual(#ui.selectedStages, 0, "Selections should clear")
	assertTrue(ui.startButton.Active == false, "Start button should disable after clear")

	screenGui:Destroy()
end

tests.update_countdown_updates_text = function()
	ensureRemotes()
	local screenGui = createScreenGui()
	local ui = StageSelectionUI.new(screenGui)

	ui:updateCountdown({ number = 3, message = "Starting..." })
	assertTrue(ui.countdownFrame.Visible, "Countdown frame should be visible")
	assertEqual(ui.countdownNumber.Text, "3", "Countdown number should update")
	assertEqual(ui.countdownMessage.Text, "Starting...", "Countdown message should update")

	screenGui:Destroy()
end

return tests
