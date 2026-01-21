local Players = game:GetService("Players")

local LeaderboardUI = require(script.Parent.Parent.UI.LeaderboardUI)

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
	screenGui.Name = "LeaderboardUITestGui"
	screenGui.Parent = playerGui
	return screenGui
end

local tests = {}

tests.update_leaderboard_creates_entries = function()
	local screenGui = createScreenGui()
	local ui = LeaderboardUI.new(screenGui)

	ui:updateLeaderboard({
		{ userId = Players.LocalPlayer.UserId, name = "Tester", highScore = 100 },
		{ userId = 2, name = "Other", highScore = 50 },
	})

	local entry1 = ui.scrollFrame:FindFirstChild("Entry_1")
	local entry2 = ui.scrollFrame:FindFirstChild("Entry_2")
	assertTrue(entry1 ~= nil, "Entry 1 should be created")
	assertTrue(entry2 ~= nil, "Entry 2 should be created")

	screenGui:Destroy()
end

tests.toggle_sets_visibility = function()
	local screenGui = createScreenGui()
	local ui = LeaderboardUI.new(screenGui)

	ui:toggle()
	assertTrue(ui.isVisible, "Leaderboard should be visible after toggle")
	assertTrue(ui.frame.Visible, "Frame should be visible after toggle")

	ui:toggle()
	assertEqual(ui.isVisible, false, "Leaderboard should be hidden after second toggle")

	screenGui:Destroy()
end

return tests
