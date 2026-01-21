local Players = game:GetService("Players")

local FlyController = require(script.Parent.Parent.FlyController)

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

local tests = {}

tests.initial_state_and_ui = function()
	local _ = Players.LocalPlayer:WaitForChild("PlayerGui")
	local controller = FlyController.new()

	assertTrue(controller.isFlying == false, "Fly should be disabled by default")
	assertEqual(controller.flySpeed, 50, "Default fly speed should be 50")
	assertEqual(controller.flyButton.Text, "FLY", "Fly button text should be FLY")
	assertEqual(controller.speedLabel.Text, "50", "Speed label should show default speed")

	if controller.flyButton and controller.flyButton.Parent then
		controller.flyButton.Parent:Destroy()
	end
end

return tests
