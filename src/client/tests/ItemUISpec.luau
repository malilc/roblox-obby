local Players = game:GetService("Players")

local ItemUI = require(script.Parent.Parent.UI.ItemUI)

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
	screenGui.Name = "ItemUITestGui"
	screenGui.Parent = playerGui
	return screenGui
end

local tests = {}

tests.update_items_changes_count_and_color = function()
	local screenGui = createScreenGui()
	local ui = ItemUI.new(screenGui)

	ui:updateItems({ pushCount = 0 })
	assertEqual(ui.countLabel.Text, "x0", "Count label should update")
	assertEqual(ui.button.BackgroundColor3, Color3.fromRGB(80, 80, 80), "Button should gray out at zero")

	ui:updateItems({ pushCount = 2 })
	assertEqual(ui.countLabel.Text, "x2", "Count label should update again")
	assertEqual(ui.button.BackgroundColor3, Color3.fromRGB(255, 80, 80), "Button should restore color")

	screenGui:Destroy()
end

tests.start_cooldown_sets_state = function()
	local screenGui = createScreenGui()
	local ui = ItemUI.new(screenGui)

	ui:startCooldown(1)
	assertTrue(ui.onCooldown, "Cooldown should be active")
	assertEqual(ui.cooldownOverlay.Size, UDim2.new(1, 0, 1, 0), "Cooldown overlay should fill")

	screenGui:Destroy()
end

return tests
