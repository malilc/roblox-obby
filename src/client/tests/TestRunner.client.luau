local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

if not RunService:IsStudio() or not RunService:IsClient() then
	return
end

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	return
end

LocalPlayer:WaitForChild("PlayerGui")

local testsFolder = script.Parent

local total = 0
local failed = 0

local function runTestModule(moduleScript: ModuleScript)
	local ok, testsOrError = pcall(require, moduleScript)
	if not ok then
		failed += 1
		warn("[ClientTests] Failed to load", moduleScript.Name, testsOrError)
		return
	end

	local tests = testsOrError
	for testName, testFn in pairs(tests) do
		if type(testFn) == "function" then
			total += 1
			local okTest, err = pcall(testFn)
			if okTest then
				print("[ClientTests] PASS", moduleScript.Name .. "." .. testName)
			else
				failed += 1
				warn("[ClientTests] FAIL", moduleScript.Name .. "." .. testName, err)
			end
		end
	end
end

for _, child in ipairs(testsFolder:GetChildren()) do
	if child:IsA("ModuleScript") and child.Name:match("Spec$") then
		runTestModule(child)
	end
end

print(string.format("[ClientTests] Completed: %d total, %d failed", total, failed))
if failed > 0 then
	error("[ClientTests] Unit tests failed")
end
