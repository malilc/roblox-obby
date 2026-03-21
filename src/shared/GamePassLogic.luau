-- GamePassLogic: Pure business logic for Game Pass system (no Roblox service dependencies)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local GamePassLogic = {}

-- Validate that a passId exists in Config.GamePasses
function GamePassLogic.isValidPassId(passId: string): boolean
	if type(passId) ~= "string" or passId == "" then
		return false
	end
	return Config.GamePasses[passId] ~= nil
end

-- Reverse lookup: numeric gamePassId -> string key (e.g., 1740745787 -> "DoubleCoin")
function GamePassLogic.getPassIdByGamePassId(numericId: number): string?
	for id, passDef in pairs(Config.GamePasses) do
		if passDef.gamePassId == numericId then
			return id
		end
	end
	return nil
end

-- Pure ownership check: return true only if passesMap[passId] == true
function GamePassLogic.hasGamePass(passesMap: {[string]: boolean}?, passId: string): boolean
	if not passesMap then return false end
	return passesMap[passId] == true
end

-- Core ownership resolution: merge savedPasses + apiResults + debug overrides
-- Priority: debug OFF override > API owned > saved state
function GamePassLogic.resolveOwnership(params: {
	savedPasses: {[string]: boolean}?,
	apiResults: {[string]: boolean}?,
	debugEnabled: boolean?,
}): {[string]: boolean}
	local savedPasses = params.savedPasses or {}
	local apiResults = params.apiResults or {}
	local debugEnabled = params.debugEnabled or false

	-- Start from a copy of savedPasses (don't mutate input)
	local result = {}
	for id, value in pairs(savedPasses) do
		result[id] = value
	end

	-- Snapshot test overrides (explicitly toggled OFF) before API merge
	local testOverrides: {[string]: boolean}? = nil
	if debugEnabled then
		testOverrides = {}
		for id, value in pairs(result) do
			if value == false then
				testOverrides[id] = true
			end
		end
	end

	-- Merge API results: if API says owned, set true
	for id, owned in pairs(apiResults) do
		if owned then
			result[id] = true
		end
	end

	-- In debug mode: re-apply explicit OFF overrides (test toggle wins over API)
	if testOverrides then
		for id in pairs(testOverrides) do
			result[id] = false
		end
	end

	return result
end

-- Calculate coin multiplier from owned passes
-- base 1 + DoubleCoin(+1) + VIP(+0.5)
function GamePassLogic.getCoinMultiplier(ownedPasses: {[string]: boolean}?): number
	local multiplier = 1
	if not ownedPasses then return multiplier end

	if ownedPasses["DoubleCoin"] == true then
		multiplier = multiplier + 1
	end
	if ownedPasses["VIP"] == true then
		multiplier = multiplier + 0.5
	end
	return multiplier
end

-- Calculate XP multiplier from owned passes
-- base 1 + DoubleXP(+1) + VIP(+0.5)
function GamePassLogic.getXPMultiplier(ownedPasses: {[string]: boolean}?): number
	local multiplier = 1
	if not ownedPasses then return multiplier end

	if ownedPasses["DoubleXP"] == true then
		multiplier = multiplier + 1
	end
	if ownedPasses["VIP"] == true then
		multiplier = multiplier + 0.5
	end
	return multiplier
end

-- Get max item slots: 2 default, 3 with ExtraSlot
function GamePassLogic.getMaxItemSlots(ownedPasses: {[string]: boolean}?): number
	if ownedPasses and ownedPasses["ExtraSlot"] == true then
		return 3
	end
	return 2
end

-- Pure time-based rate limiting check
function GamePassLogic.isRateLimited(lastTime: number?, now: number, cooldown: number): boolean
	if not lastTime then return false end
	return (now - lastTime) < cooldown
end

return GamePassLogic
