-- run-tests.server.luau
-- Test runner for Jest Lua — runs inside Roblox via run-in-roblox

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevPackages = ReplicatedStorage:WaitForChild("DevPackages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Jest = require(DevPackages.Jest)

local processServiceExists, ProcessService = pcall(function()
	return game:GetService("ProcessService")
end)

-- Run Jest on the __tests__ folder inside Shared
local status, result = Jest.runCLI(Shared, {
	verbose = true,
	ci = false,
}, { Shared }):awaitStatus()

if status == "Rejected" then
	print("Test run rejected:")
	print(result)
end

if status == "Resolved" and result.results.numFailedTestSuites == 0 and result.results.numFailedTests == 0 then
	if processServiceExists then
		ProcessService:ExitAsync(0)
	end
end

if processServiceExists then
	ProcessService:ExitAsync(1)
end

return nil
