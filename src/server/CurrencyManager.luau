-- CurrencyManager: จัดการเงินในเกม + class unlock + class mastery

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ClassTypes = require(ReplicatedStorage.Shared.ClassTypes)
local Logger = require(ReplicatedStorage.Shared.Logger)

local CurrencyManager = {}
CurrencyManager.__index = CurrencyManager

export type ClassMasteryData = {
	level: number,
	xp: number,
}

export type ClassMasterySnapshot = {
	level: number,
	xp: number,
	xpToNext: number,
	isMax: boolean,
}

export type MasteryRewardDefinition = {
	id: string,
	level: number,
	rewardType: string,
	rarity: string,
	name: string,
	description: string?,
}

export type MasteryRewardSnapshot = {
	id: string,
	level: number,
	rewardType: string,
	rarity: string,
	name: string,
	description: string?,
	unlocked: boolean,
}

export type TitleSnapshot = {
	id: string,
	name: string,
	classId: string,
	level: number,
	rarity: string,
	description: string?,
}

export type TitleCatalogEntry = {
	id: string,
	name: string,
	classId: string,
	level: number,
	rarity: string,
	description: string?,
	unlocked: boolean,
}

export type PlayerCurrencyData = {
	currency: number,
	gems: number,
	wins: number,
	unlockedClasses: {[string]: boolean},
	equippedClass: string,
	classMastery: {[string]: ClassMasteryData},
	masteryRewards: {[string]: {[string]: boolean}},
	activeTitle: string?,
	hasSeenTutorial: boolean,
	lastLoginTime: number?,
	loginStreak: number,
}

local function getDefaultClassId(): string
	local configuredDefault = Config.Classes and Config.Classes.DefaultClass
	if type(configuredDefault) == "string" and ClassTypes.getClass(configuredDefault) then
		return configuredDefault
	end
	return ClassTypes.DefaultClass
end

local function getMasteryMaxLevel(): number
	local configuredValue = Config.Mastery and tonumber(Config.Mastery.MaxLevel)
	local maxLevel = math.floor(configuredValue or 20)
	return math.max(1, maxLevel)
end

local function getMasteryBaseXp(): number
	local configuredValue = Config.Mastery and tonumber(Config.Mastery.BaseXpPerLevel)
	local baseXp = math.floor(configuredValue or 100)
	return math.max(1, baseXp)
end

local function getMasteryGrowthMultiplier(): number
	local configuredValue = Config.Mastery and tonumber(Config.Mastery.XpGrowthMultiplier)
	local multiplier = configuredValue or 1.25
	return if multiplier > 1 then multiplier else 1
end

local function getXpRequiredForLevel(level: number): number
	local normalizedLevel = math.max(1, math.floor(level))
	local baseXp = getMasteryBaseXp()
	local growth = getMasteryGrowthMultiplier()
	local requiredXp = baseXp * (growth ^ (normalizedLevel - 1))
	return math.max(1, math.floor(requiredXp))
end

local function deriveDefaultRarity(level: number): string
	if level >= 20 then
		return "Legendary"
	elseif level >= 15 then
		return "Epic"
	elseif level >= 10 then
		return "Rare"
	end
	return "Common"
end

local function normalizeRarity(source: any, level: number): string
	if type(source) == "string" and source ~= "" then
		return source
	end
	return deriveDefaultRarity(level)
end

local function getTitleTheme(rarity: string, classColor: Color3?): {textColor: Color3, strokeColor: Color3, frameColor: Color3}
	local themes = Config.Mastery and Config.Mastery.TitleThemes
	local configuredTheme = type(themes) == "table" and themes[rarity] or nil

	local textColor = classColor or Color3.fromRGB(230, 230, 230)
	local strokeColor = Color3.fromRGB(0, 0, 0)
	local frameColor = classColor or Color3.fromRGB(95, 95, 110)

	if type(configuredTheme) == "table" then
		if typeof(configuredTheme.textColor) == "Color3" then
			textColor = configuredTheme.textColor
		end
		if typeof(configuredTheme.strokeColor) == "Color3" then
			strokeColor = configuredTheme.strokeColor
		end
		if typeof(configuredTheme.frameColor) == "Color3" then
			frameColor = configuredTheme.frameColor
		end
	end

	return {
		textColor = textColor,
		strokeColor = strokeColor,
		frameColor = frameColor,
	}
end

local function buildUnlockedClasses(source: any?): {[string]: boolean}
	local unlocked = {} :: {[string]: boolean}

	if Config.Classes and type(Config.Classes.FreeClasses) == "table" then
		for classId, isFree in pairs(Config.Classes.FreeClasses) do
			if isFree == true and ClassTypes.getClass(classId) then
				unlocked[classId] = true
			end
		end
	end

	-- Merge saved classes
	if type(source) == "table" then
		for classId, isUnlocked in pairs(source) do
			if isUnlocked == true and ClassTypes.getClass(classId) then
				unlocked[classId] = true
			end
		end
	end

	-- Ensure default class is always unlocked
	local defaultClass = getDefaultClassId()
	unlocked[defaultClass] = true

	return unlocked
end

local function sanitizeEquippedClass(savedClassId: any, unlockedClasses: {[string]: boolean}): string
	if type(savedClassId) == "string" and unlockedClasses[savedClassId] and ClassTypes.getClass(savedClassId) then
		return savedClassId
	end

	local defaultClass = getDefaultClassId()
	if unlockedClasses[defaultClass] then
		return defaultClass
	end

	-- Fallback: first unlocked valid class
	for classId, isUnlocked in pairs(unlockedClasses) do
		if isUnlocked and ClassTypes.getClass(classId) then
			return classId
		end
	end

	return ClassTypes.DefaultClass
end

local function buildMasteryData(source: any?): {[string]: ClassMasteryData}
	local masteryData = {} :: {[string]: ClassMasteryData}
	local maxLevel = getMasteryMaxLevel()

	for _, classId in ipairs(ClassTypes.getAllClassIds()) do
		local savedEntry = nil
		if type(source) == "table" then
			savedEntry = source[classId]
		end

		local rawLevel = type(savedEntry) == "table" and tonumber(savedEntry.level) or 1
		local level = math.clamp(math.floor(rawLevel or 1), 1, maxLevel)

		local rawXp = type(savedEntry) == "table" and tonumber(savedEntry.xp) or 0
		local xp = math.max(0, math.floor(rawXp or 0))

		if level >= maxLevel then
			xp = 0
		else
			local xpToNext = getXpRequiredForLevel(level)
			xp = math.min(xp, xpToNext - 1)
		end

		masteryData[classId] = {
			level = level,
			xp = xp,
		}
	end

	return masteryData
end

local function buildMasterySnapshot(masteryData: {[string]: ClassMasteryData}): {[string]: ClassMasterySnapshot}
	local snapshot = {} :: {[string]: ClassMasterySnapshot}
	local maxLevel = getMasteryMaxLevel()

	for _, classId in ipairs(ClassTypes.getAllClassIds()) do
		local entry = masteryData[classId]
		local level = entry and entry.level or 1
		local xp = entry and entry.xp or 0
		local isMax = level >= maxLevel
		local xpToNext = if isMax then 0 else getXpRequiredForLevel(level)

		snapshot[classId] = {
			level = level,
			xp = xp,
			xpToNext = xpToNext,
			isMax = isMax,
		}
	end

	return snapshot
end

local function buildMasteryRewardCatalog(): {[string]: {MasteryRewardDefinition}}
	local catalog = {} :: {[string]: {MasteryRewardDefinition}}
	local maxLevel = getMasteryMaxLevel()
	local configuredRewards = Config.Mastery and Config.Mastery.Rewards

	for _, classId in ipairs(ClassTypes.getAllClassIds()) do
		local classRewards = {} :: {MasteryRewardDefinition}
		local sourceList = type(configuredRewards) == "table" and configuredRewards[classId] or nil

		if type(sourceList) == "table" then
			for index, entry in ipairs(sourceList) do
				if type(entry) == "table" then
					local rewardId = type(entry.id) == "string" and entry.id or string.lower(classId) .. "_reward_" .. tostring(index)
					local rawLevel = tonumber(entry.level) or 1
					local level = math.clamp(math.floor(rawLevel), 1, maxLevel)
					local rewardType = type(entry.rewardType) == "string" and entry.rewardType or "Cosmetic"
					local rarity = normalizeRarity(entry.rarity, level)
					local name = type(entry.name) == "string" and entry.name or (rewardType .. " Reward")
					local description = if type(entry.description) == "string" then entry.description else nil

					table.insert(classRewards, {
						id = rewardId,
						level = level,
						rewardType = rewardType,
						rarity = rarity,
						name = name,
						description = description,
					})
				end
			end
		end

		table.sort(classRewards, function(a, b)
			if a.level == b.level then
				return a.id < b.id
			end
			return a.level < b.level
		end)

		catalog[classId] = classRewards
	end

	return catalog
end

local MASTERY_REWARD_CATALOG = buildMasteryRewardCatalog()

local function getMasteryRewardById(rewardId: string): (MasteryRewardDefinition?, string?)
	for _, classId in ipairs(ClassTypes.getAllClassIds()) do
		local rewardList = MASTERY_REWARD_CATALOG[classId] or {}
		for _, reward in ipairs(rewardList) do
			if reward.id == rewardId then
				return reward, classId
			end
		end
	end

	return nil, nil
end

local function isRewardUnlocked(
	masteryRewards: {[string]: {[string]: boolean}},
	classId: string,
	rewardId: string
): boolean
	local unlockedByClass = masteryRewards[classId]
	if not unlockedByClass then
		return false
	end
	return unlockedByClass[rewardId] == true
end

local function isTitleUnlocked(
	masteryRewards: {[string]: {[string]: boolean}},
	titleId: string
): boolean
	local rewardDef, classId = getMasteryRewardById(titleId)
	if not rewardDef or not classId or rewardDef.rewardType ~= "Title" then
		return false
	end

	return isRewardUnlocked(masteryRewards, classId, titleId)
end

local function sanitizeActiveTitle(
	savedTitleId: any,
	masteryRewards: {[string]: {[string]: boolean}}
): string?
	if type(savedTitleId) ~= "string" then
		return nil
	end

	if savedTitleId == "" then
		return nil
	end

	if isTitleUnlocked(masteryRewards, savedTitleId) then
		return savedTitleId
	end

	return nil
end

local function buildMasteryRewardUnlocks(
	source: any?,
	masteryData: {[string]: ClassMasteryData}
): {[string]: {[string]: boolean}}
	local rewardUnlocks = {} :: {[string]: {[string]: boolean}}

	for _, classId in ipairs(ClassTypes.getAllClassIds()) do
		local unlockedByClass = {} :: {[string]: boolean}
		local savedUnlocked = type(source) == "table" and source[classId] or nil
		local currentLevel = masteryData[classId] and masteryData[classId].level or 1
		local rewardList = MASTERY_REWARD_CATALOG[classId] or {}

		for _, reward in ipairs(rewardList) do
			local isUnlockedFromSave = type(savedUnlocked) == "table" and savedUnlocked[reward.id] == true
			local isUnlockedByLevel = currentLevel >= reward.level
			if isUnlockedFromSave or isUnlockedByLevel then
				unlockedByClass[reward.id] = true
			end
		end

		rewardUnlocks[classId] = unlockedByClass
	end

	return rewardUnlocks
end

function CurrencyManager.new()
	local self = setmetatable({}, CurrencyManager)

	self.playerData = {} :: {[Player]: PlayerCurrencyData}
	self.pendingSaves = {} :: {[Player]: boolean} -- Track players needing save

	-- DataStore
	pcall(function()
		self.dataStore = DataStoreService:GetDataStore(Config.DataStore.Name)
	end)

	-- Remotes
	self.updateCurrencyRemote = ReplicatedStorage.Remotes.UpdateCurrency
	self.masteryUpdateRemote = ReplicatedStorage.Remotes:WaitForChild("MasteryUpdate")
	self.titleUpdateRemote = ReplicatedStorage.Remotes:WaitForChild("TitleUpdate")
	self.setActiveTitleRemote = ReplicatedStorage.Remotes:WaitForChild("SetActiveTitle")
	self.dailyBonusRemote = ReplicatedStorage.Remotes:WaitForChild("DailyBonusClaimed")
	self.updateGemRemote = ReplicatedStorage.Remotes:WaitForChild("UpdateGems")

	self:setupRemotes()

	-- Start auto-save loop (save pending data every 30 seconds)
	self:startAutoSave()

	return self
end

function CurrencyManager:setupRemotes()
	self.setActiveTitleRemote.OnServerEvent:Connect(function(player, titleId)
		self:handleSetActiveTitleRequest(player, titleId)
	end)

	-- Tutorial seen remote
	local tutorialSeenRemote = ReplicatedStorage.Remotes:FindFirstChild("TutorialSeen")
	if tutorialSeenRemote then
		tutorialSeenRemote.OnServerEvent:Connect(function(player)
			local playerData = self.playerData[player]
			if playerData and not playerData.hasSeenTutorial then
				playerData.hasSeenTutorial = true
				self.pendingSaves[player] = true
			end
		end)
	end

	-- Setup testing remotes if in debug mode
	if Config.Debug and Config.Debug.ItemTesting then
		self.setupMasteryLevelRemote = ReplicatedStorage.Remotes:FindFirstChild("SetMasteryLevel")
		if self.setupMasteryLevelRemote then
			self.setupMasteryLevelRemote.OnServerEvent:Connect(function(player, data)
				self:handleSetMasteryLevelRequest(player, data)
			end)
			Logger.info("CurrencyManager", "SetMasteryLevel remote initialized for testing")
		end
	end

	-- Reset daily login for testing
	if Config.Debug and Config.Debug.Enabled then
		local resetDailyRemote = ReplicatedStorage.Remotes:FindFirstChild("ResetDailyLogin")
		if resetDailyRemote then
			resetDailyRemote.OnServerEvent:Connect(function(player)
				local playerData = self.playerData[player]
				if not playerData then return end
				playerData.lastLoginTime = nil
				playerData.loginStreak   = 0
				self.pendingSaves[player] = true
				self:checkDailyLogin(player)
				Logger.info("CurrencyManager", "Daily login reset (test) for", player.Name)
			end)
			Logger.info("CurrencyManager", "ResetDailyLogin remote initialized for testing")
		end
	end
end

-- Handle set mastery level request (testing only)
function CurrencyManager:handleSetMasteryLevelRequest(player: Player, data: {[string]: any})
	if not Config.Debug or not Config.Debug.ItemTesting then
		Logger.warn("CurrencyManager", "handleSetMasteryLevelRequest is only available in testing mode")
		return
	end
	
	if type(data) ~= "table" then return end
	
	-- Set all classes to same level
	if data.setAll == true then
		local level = tonumber(data.level) or 1
		self:setAllMasteryLevels(player, level)
		return
	end
	
	-- Set single class level
	local classId = data.classId
	local level = tonumber(data.level)
	
	if classId and level then
		self:setMasteryLevel(player, classId, level)
	end
end

-- Initialize player currency
function CurrencyManager:initPlayer(player: Player)
	local defaultClass = getDefaultClassId()
	local defaultMasteryData = buildMasteryData(nil)
	self.playerData[player] = {
		currency = Config.Currency.StartingAmount,
		gems = 0,
		wins = 0,
		unlockedClasses = buildUnlockedClasses(nil),
		equippedClass = defaultClass,
		classMastery = defaultMasteryData,
		masteryRewards = buildMasteryRewardUnlocks(nil, defaultMasteryData),
		activeTitle = nil,
		hasSeenTutorial = false,
		lastLoginTime = nil,
		loginStreak = 0,
	}

	-- Load from DataStore
	self:loadPlayerData(player)
end

-- Load player currency from DataStore
function CurrencyManager:loadPlayerData(player: Player)
	if not self.dataStore then
		-- Send update even if no DataStore
		self:checkDailyLogin(player)
		self:sendCurrencyUpdate(player)
		self:sendGemUpdate(player)
		self:sendMasteryUpdate(player)
		self:sendTitleUpdate(player)
		self:applyActiveTitleToCharacter(player)
		return
	end

	local success, data = pcall(function()
		return self.dataStore:GetAsync("Player_" .. player.UserId)
	end)

	local playerData = self.playerData[player]
	if success and type(data) == "table" and playerData then
		local loadedCurrency = tonumber(data.currency)
		playerData.currency = math.max(0, loadedCurrency or Config.Currency.StartingAmount)
		playerData.unlockedClasses = buildUnlockedClasses(data.unlockedClasses)
		playerData.equippedClass = sanitizeEquippedClass(data.equippedClass, playerData.unlockedClasses)
		playerData.classMastery = buildMasteryData(data.classMastery)
		playerData.masteryRewards = buildMasteryRewardUnlocks(data.masteryRewards, playerData.classMastery)
		playerData.activeTitle = sanitizeActiveTitle(data.activeTitle, playerData.masteryRewards)
		playerData.gems = math.max(0, tonumber(data.gems) or 0)
		playerData.wins = math.max(0, tonumber(data.wins) or 0)
		playerData.hasSeenTutorial = data.hasSeenTutorial == true
		playerData.lastLoginTime = tonumber(data.lastLoginTime) or nil
		playerData.loginStreak = tonumber(data.loginStreak) or 0

		Logger.debug("CurrencyManager", "Loaded profile for", player.Name, "- Currency:", playerData.currency, "- Gems:", playerData.gems, "- Wins:", playerData.wins, "- Equipped:", playerData.equippedClass)
	else
		Logger.debug("CurrencyManager", "No saved currency for", player.Name, "- Using starting amount")
	end

	-- Check and give daily login reward
	self:checkDailyLogin(player)

	-- Update client
	self:sendCurrencyUpdate(player)
	self:sendGemUpdate(player)
	self:sendMasteryUpdate(player)
	self:sendTitleUpdate(player)
	self:applyActiveTitleToCharacter(player)
end

-- Check if daily login reward is available and grant it
function CurrencyManager:checkDailyLogin(player: Player)
	local playerData = self.playerData[player]
	if not playerData then return end

	local cfg = Config.DailyLogin
	if not cfg then return end

	local now = os.time()
	local cooldownSecs = (cfg.CooldownHours or 20) * 3600
	local resetSecs    = (cfg.ResetHours    or 48) * 3600
	local lastLogin    = playerData.lastLoginTime or 0
	local elapsed      = now - lastLogin

	if elapsed < cooldownSecs then
		-- Already claimed today — send status so HUD button is up to date
		local allRewards = {}
		local cfgRewards = cfg.Rewards or {}
		for day = 1, 7 do allRewards[day] = cfgRewards[day] or 25 end
		local gemCfgNotClaimed = Config.Gems and Config.Gems.DailyLoginGems or {}
		task.delay(2, function()
			if player.Parent then
				self.dailyBonusRemote:FireClient(player, {
					claimed = false,
					day     = playerData.loginStreak or 1,
					amount  = 0,
					gemAmount = 0,
					rewards = allRewards,
					gemRewards = gemCfgNotClaimed,
					lastLoginTime = playerData.lastLoginTime,
					cooldownHours = cfg.CooldownHours or 20,
				})
			end
		end)
		return
	end

	-- Reset streak if player missed too many days
	local streak = playerData.loginStreak or 0
	if elapsed >= resetSecs then
		streak = 0
	end

	-- Advance streak day 1-7, then cycle back to 1
	streak = (streak % 7) + 1

	local rewards = cfg.Rewards or {}
	local amount = rewards[streak] or 25

	-- Gem daily reward
	local gemCfg = Config.Gems and Config.Gems.DailyLoginGems or {}
	local gemAmount = gemCfg[streak] or 0

	playerData.currency   = playerData.currency + amount
	if gemAmount > 0 then
		playerData.gems = playerData.gems + gemAmount
	end
	playerData.lastLoginTime = now
	playerData.loginStreak   = streak
	self.pendingSaves[player] = true

	Logger.info("CurrencyManager", player.Name, "claimed login day", streak, "reward:", amount, "coins +", gemAmount, "gems")

	-- Build full rewards table for UI
	local allRewards = {}
	for day = 1, 7 do
		allRewards[day] = rewards[day] or 25
	end

	-- Notify client (small delay so UI is ready)
	task.delay(2, function()
		if player.Parent then
			self.dailyBonusRemote:FireClient(player, {
				claimed = true,
				day     = streak,
				amount  = amount,
				gemAmount = gemAmount,
				rewards = allRewards,
				gemRewards = gemCfg,
				lastLoginTime = now,
				cooldownHours = cfg.CooldownHours or 20,
			})
			self:sendGemUpdate(player)
		end
	end)
end

-- Save player currency to DataStore
function CurrencyManager:savePlayerData(player: Player)
	if not self.dataStore then return end

	local playerData = self.playerData[player]
	if not playerData then return end

	local success, err = pcall(function()
		self.dataStore:UpdateAsync("Player_" .. player.UserId, function(existingData)
			if type(existingData) ~= "table" then
				existingData = {}
			end
			existingData.currency = playerData.currency
			existingData.gems = playerData.gems
			existingData.wins = playerData.wins
			existingData.unlockedClasses = self:getUnlockedClasses(player)
			existingData.equippedClass = playerData.equippedClass
			existingData.classMastery = self:getClassMasteryData(player)
			existingData.masteryRewards = self:getUnlockedMasteryRewards(player)
			existingData.activeTitle = playerData.activeTitle
			existingData.hasSeenTutorial = playerData.hasSeenTutorial
			existingData.lastLoginTime  = playerData.lastLoginTime
			existingData.loginStreak    = playerData.loginStreak
			return existingData
		end)
	end)

	if success then
		Logger.debug("CurrencyManager", "Saved currency profile for", player.Name)
	else
		Logger.warn("CurrencyManager", "Failed to save currency for", player.Name, ":", err)
	end
end

-- Add currency to player
function CurrencyManager:addCurrency(player: Player, amount: number)
	local playerData = self.playerData[player]
	if not playerData then return end
	if amount == 0 then return end

	playerData.currency = playerData.currency + amount
	Logger.debug("CurrencyManager", player.Name, "gained", amount, "currency - Total:", playerData.currency)

	-- Mark for pending save (will be saved in auto-save loop)
	self.pendingSaves[player] = true

	-- Update client immediately
	self:sendCurrencyUpdate(player)
end

-- Can player afford amount
function CurrencyManager:canAfford(player: Player, amount: number): boolean
	local playerData = self.playerData[player]
	if not playerData then return false end
	if amount < 0 then return false end
	return playerData.currency >= amount
end

-- Spend currency
function CurrencyManager:spendCurrency(player: Player, amount: number, reason: string?): boolean
	local playerData = self.playerData[player]
	if not playerData then return false end
	if amount <= 0 then return false end
	if not self:canAfford(player, amount) then
		return false
	end

	playerData.currency = playerData.currency - amount
	self.pendingSaves[player] = true

	Logger.debug("CurrencyManager", player.Name, "spent", amount, "currency - Total:", playerData.currency, if reason then "(" .. reason .. ")" else "")

	self:sendCurrencyUpdate(player)
	return true
end

-- Check if class is unlocked
function CurrencyManager:isClassUnlocked(player: Player, classId: string): boolean
	local playerData = self.playerData[player]
	if not playerData then
		-- Allow free classes as fallback while data is not initialized
		return Config.Classes
			and type(Config.Classes.FreeClasses) == "table"
			and Config.Classes.FreeClasses[classId] == true
			or false
	end

	return playerData.unlockedClasses[classId] == true
end

-- Unlock class permanently
function CurrencyManager:unlockClass(player: Player, classId: string): boolean
	local playerData = self.playerData[player]
	if not playerData then return false end
	if not ClassTypes.getClass(classId) then return false end
	if playerData.unlockedClasses[classId] then
		return false
	end

	playerData.unlockedClasses[classId] = true
	if not playerData.classMastery[classId] then
		playerData.classMastery[classId] = {
			level = 1,
			xp = 0,
		}
	end
	if not playerData.masteryRewards[classId] then
		playerData.masteryRewards[classId] = {}
	end
	local classLevel = playerData.classMastery[classId] and playerData.classMastery[classId].level or 1
	self:unlockMasteryRewardsForLevelRange(player, classId, 1, classLevel)

	self.pendingSaves[player] = true
	self:sendCurrencyUpdate(player)
	self:sendMasteryUpdate(player)
	self:sendTitleUpdate(player)

	Logger.debug("CurrencyManager", player.Name, "unlocked class:", classId)
	return true
end

-- Get unlocked classes copy
function CurrencyManager:getUnlockedClasses(player: Player): {[string]: boolean}
	local playerData = self.playerData[player]
	local result = {} :: {[string]: boolean}

	if not playerData then
		return buildUnlockedClasses(nil)
	end

	for classId, isUnlocked in pairs(playerData.unlockedClasses) do
		if isUnlocked then
			result[classId] = true
		end
	end

	return result
end

-- Get equipped class
function CurrencyManager:getEquippedClass(player: Player): string
	local playerData = self.playerData[player]
	if not playerData then
		return getDefaultClassId()
	end

	return sanitizeEquippedClass(playerData.equippedClass, playerData.unlockedClasses)
end

-- Save equipped class
function CurrencyManager:setEquippedClass(player: Player, classId: string): boolean
	local playerData = self.playerData[player]
	if not playerData then return false end
	if not ClassTypes.getClass(classId) then return false end
	if not playerData.unlockedClasses[classId] then return false end

	playerData.equippedClass = classId
	self.pendingSaves[player] = true

	-- Re-apply trail for new class
	task.delay(0.15, function()
		local character = player.Character
		if character then
			self:applyActiveTrailToCharacter(player, character)
		end
	end)
	return true
end

-- Get mastery data for saving
function CurrencyManager:getClassMasteryData(player: Player): {[string]: ClassMasteryData}
	local playerData = self.playerData[player]
	if not playerData then
		return buildMasteryData(nil)
	end

	local masteryCopy = {} :: {[string]: ClassMasteryData}
	for classId, entry in pairs(playerData.classMastery) do
		masteryCopy[classId] = {
			level = entry.level,
			xp = entry.xp,
		}
	end

	return masteryCopy
end

function CurrencyManager:getUnlockedMasteryRewards(player: Player): {[string]: {[string]: boolean}}
	local playerData = self.playerData[player]
	if not playerData then
		return buildMasteryRewardUnlocks(nil, buildMasteryData(nil))
	end

	local copy = {} :: {[string]: {[string]: boolean}}
	for classId, rewards in pairs(playerData.masteryRewards) do
		copy[classId] = {}
		for rewardId, isUnlocked in pairs(rewards) do
			if isUnlocked then
				copy[classId][rewardId] = true
			end
		end
	end

	return copy
end

function CurrencyManager:getClassMasterySnapshot(player: Player): {[string]: ClassMasterySnapshot}
	local playerData = self.playerData[player]
	if not playerData then
		return buildMasterySnapshot(buildMasteryData(nil))
	end

	return buildMasterySnapshot(playerData.classMastery)
end

function CurrencyManager:getMasteryRewardsSnapshot(player: Player): {[string]: {MasteryRewardSnapshot}}
	local playerData = self.playerData[player]
	local fallbackMastery = buildMasteryData(nil)
	local fallbackUnlocks = buildMasteryRewardUnlocks(nil, fallbackMastery)
	local unlockedSource = if playerData then playerData.masteryRewards else fallbackUnlocks
	local snapshot = {} :: {[string]: {MasteryRewardSnapshot}}

	for _, classId in ipairs(ClassTypes.getAllClassIds()) do
		local rewardEntries = {} :: {MasteryRewardSnapshot}
		local rewardList = MASTERY_REWARD_CATALOG[classId] or {}
		local unlockedByClass = unlockedSource[classId] or {}

		for _, reward in ipairs(rewardList) do
			table.insert(rewardEntries, {
				id = reward.id,
				level = reward.level,
				rewardType = reward.rewardType,
				rarity = reward.rarity,
				name = reward.name,
				description = reward.description,
				unlocked = unlockedByClass[reward.id] == true,
			})
		end

		snapshot[classId] = rewardEntries
	end

	return snapshot
end

function CurrencyManager:getTitleCatalogSnapshot(player: Player): {TitleCatalogEntry}
	local playerData = self.playerData[player]
	local catalog = {} :: {TitleCatalogEntry}
	local unlockedRewards = if playerData then playerData.masteryRewards else buildMasteryRewardUnlocks(nil, buildMasteryData(nil))

	for _, classId in ipairs(ClassTypes.getAllClassIds()) do
		local rewardList = MASTERY_REWARD_CATALOG[classId] or {}
		for _, reward in ipairs(rewardList) do
			if reward.rewardType == "Title" then
				table.insert(catalog, {
					id = reward.id,
					name = reward.name,
					classId = classId,
					level = reward.level,
					rarity = reward.rarity,
					description = reward.description,
					unlocked = isRewardUnlocked(unlockedRewards, classId, reward.id),
				})
			end
		end
	end

	return catalog
end

function CurrencyManager:getUnlockedTitles(player: Player): {TitleSnapshot}
	local titles = {} :: {TitleSnapshot}
	for _, entry in ipairs(self:getTitleCatalogSnapshot(player)) do
		if entry.unlocked then
			table.insert(titles, {
				id = entry.id,
				name = entry.name,
				classId = entry.classId,
				level = entry.level,
				rarity = entry.rarity,
				description = entry.description,
			})
		end
	end

	return titles
end

function CurrencyManager:getActiveTitle(player: Player): TitleSnapshot?
	local playerData = self.playerData[player]
	if not playerData or not playerData.activeTitle then
		return nil
	end

	local rewardDef, classId = getMasteryRewardById(playerData.activeTitle)
	if not rewardDef or not classId then
		return nil
	end
	if rewardDef.rewardType ~= "Title" then
		return nil
	end
	if not isRewardUnlocked(playerData.masteryRewards, classId, rewardDef.id) then
		return nil
	end

	return {
		id = rewardDef.id,
		name = rewardDef.name,
		classId = classId,
		level = rewardDef.level,
		rarity = rewardDef.rarity,
		description = rewardDef.description,
	}
end

function CurrencyManager:setActiveTitle(player: Player, titleId: string?): (boolean, string?)
	local playerData = self.playerData[player]
	if not playerData then
		return false, "PROFILE_NOT_READY"
	end

	if titleId == nil then
		playerData.activeTitle = nil
		self.pendingSaves[player] = true
		self:applyActiveTitleToCharacter(player)
		return true, nil
	end

	if titleId == "" then
		playerData.activeTitle = nil
		self.pendingSaves[player] = true
		self:applyActiveTitleToCharacter(player)
		return true, nil
	end

	local rewardDef, classId = getMasteryRewardById(titleId)
	if not rewardDef or not classId then
		return false, "INVALID_TITLE"
	end
	if rewardDef.rewardType ~= "Title" then
		return false, "INVALID_TITLE"
	end
	if not isRewardUnlocked(playerData.masteryRewards, classId, rewardDef.id) then
		return false, "TITLE_LOCKED"
	end

	playerData.activeTitle = rewardDef.id
	self.pendingSaves[player] = true
	self:applyActiveTitleToCharacter(player)

	return true, nil
end

function CurrencyManager:applyActiveTitleToCharacter(player: Player, character: Model?)
	local targetCharacter = character or player.Character
	if not targetCharacter then
		return
	end

	local head = targetCharacter:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	local existing = head:FindFirstChild("PlayerTitleBillboard")
	if existing then
		existing:Destroy()
	end

	local activeTitle = self:getActiveTitle(player)
	if not activeTitle then
		targetCharacter:SetAttribute("ActiveTitleId", "")
		targetCharacter:SetAttribute("ActiveTitleName", "")
		targetCharacter:SetAttribute("ActiveTitleRarity", "")
		return
	end

	targetCharacter:SetAttribute("ActiveTitleId", activeTitle.id)
	targetCharacter:SetAttribute("ActiveTitleName", activeTitle.name)
	targetCharacter:SetAttribute("ActiveTitleRarity", activeTitle.rarity)

	local classDef = ClassTypes.getClass(activeTitle.classId)
	local classColor = if classDef then classDef.color else nil
	local theme = getTitleTheme(activeTitle.rarity, classColor)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlayerTitleBillboard"
	billboard.Size = UDim2.new(0, 240, 0, 24)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.9, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Parent = head

	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
	container.BackgroundTransparency = 0.25
	container.BorderSizePixel = 0
	container.Parent = billboard

	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 6)
	containerCorner.Parent = container

	local containerStroke = Instance.new("UIStroke")
	containerStroke.Color = theme.frameColor
	containerStroke.Thickness = 1.5
	containerStroke.Transparency = 0.1
	containerStroke.Parent = container

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = string.format("[%s] %s", activeTitle.rarity, activeTitle.name)
	textLabel.TextColor3 = theme.textColor
	textLabel.TextStrokeTransparency = 0.35
	textLabel.TextStrokeColor3 = theme.strokeColor
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Parent = container
end

-- Trail colors per class (matching ClassTypes.color)
local TRAIL_COLORS = {
	Normal = Color3.fromRGB(220, 220, 220),
	Runner = Color3.fromRGB(100, 200, 255),
	Jumper = Color3.fromRGB(100, 255, 100),
	Tank = Color3.fromRGB(255, 200, 100),
}

function CurrencyManager:applyActiveTrailToCharacter(player: Player, character: Model?)
	local targetCharacter = character or player.Character
	if not targetCharacter then return end

	local humanoidRootPart = targetCharacter:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	-- Remove existing trail (attachments + trail instance on HRP)
	for _, child in ipairs(humanoidRootPart:GetChildren()) do
		if child.Name == "TrailTop" or child.Name == "TrailBottom" or child.Name == "MasteryTrailEffect" then
			child:Destroy()
		end
	end

	local playerData = self.playerData[player]
	if not playerData then return end

	local equippedClass = self:getEquippedClass(player)
	local rewards = Config.Mastery.Rewards[equippedClass]
	if not rewards then return end

	-- Find trail reward for this class
	local trailReward = nil
	for _, reward in ipairs(rewards) do
		if reward.rewardType == "Trail" then
			trailReward = reward
			break
		end
	end
	if not trailReward then return end

	-- Check if trail is unlocked
	local unlockedByClass = playerData.masteryRewards[equippedClass]
	if not unlockedByClass or not unlockedByClass[trailReward.id] then return end

	-- Create attachments on HumanoidRootPart
	local topAttach = Instance.new("Attachment")
	topAttach.Name = "TrailTop"
	topAttach.Position = Vector3.new(0, 0.5, 0)
	topAttach.Parent = humanoidRootPart

	local bottomAttach = Instance.new("Attachment")
	bottomAttach.Name = "TrailBottom"
	bottomAttach.Position = Vector3.new(0, -0.5, 0)
	bottomAttach.Parent = humanoidRootPart

	-- Create trail on HRP
	local trailColor = TRAIL_COLORS[equippedClass] or Color3.fromRGB(220, 220, 220)
	local trail = Instance.new("Trail")
	trail.Name = "MasteryTrailEffect"
	trail.Attachment0 = topAttach
	trail.Attachment1 = bottomAttach
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, trailColor),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.5
	trail.MinLength = 0.1
	trail.LightEmission = 0.5
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = humanoidRootPart
end

function CurrencyManager:sendTitleUpdate(player: Player, action: {[string]: any}?)
	local playerData = self.playerData[player]
	if not playerData then
		return
	end

	local payload = {
		titleCatalog = self:getTitleCatalogSnapshot(player),
		unlockedTitles = self:getUnlockedTitles(player),
		activeTitle = self:getActiveTitle(player),
	}

	if action then
		payload.action = action
	end

	self.titleUpdateRemote:FireClient(player, payload)
end

function CurrencyManager:handleSetActiveTitleRequest(player: Player, titleId: any)
	local normalizedTitleId = nil :: string?
	if type(titleId) == "string" then
		normalizedTitleId = titleId
	elseif titleId == nil then
		normalizedTitleId = nil
	else
		self:sendTitleUpdate(player, {
			type = "error",
			titleId = titleId,
			reason = "INVALID_TITLE",
		})
		return
	end

	if normalizedTitleId == "NONE" then
		normalizedTitleId = nil
	end

	local success, reason = self:setActiveTitle(player, normalizedTitleId)
	if not success then
		self:sendTitleUpdate(player, {
			type = "error",
			titleId = normalizedTitleId,
			reason = reason or "FAILED",
		})
		return
	end

	self:sendTitleUpdate(player, {
		type = if normalizedTitleId then "equip" else "clear",
		titleId = normalizedTitleId,
	})
end

function CurrencyManager:unlockMasteryRewardsForLevelRange(
	player: Player,
	classId: string,
	fromLevel: number,
	toLevel: number
): {MasteryRewardSnapshot}
	local playerData = self.playerData[player]
	if not playerData then
		return {}
	end

	if toLevel < fromLevel then
		return {}
	end

	local unlockedByClass = playerData.masteryRewards[classId]
	if not unlockedByClass then
		unlockedByClass = {}
		playerData.masteryRewards[classId] = unlockedByClass
	end

	local unlockedRewards = {} :: {MasteryRewardSnapshot}
	local rewardList = MASTERY_REWARD_CATALOG[classId] or {}

	for _, reward in ipairs(rewardList) do
		local shouldUnlock = reward.level >= fromLevel and reward.level <= toLevel
		if shouldUnlock and unlockedByClass[reward.id] ~= true then
			unlockedByClass[reward.id] = true
			table.insert(unlockedRewards, {
				id = reward.id,
				level = reward.level,
				rewardType = reward.rewardType,
				rarity = reward.rarity,
				name = reward.name,
				description = reward.description,
				unlocked = true,
			})
		end
	end

	return unlockedRewards
end

function CurrencyManager:sendMasteryUpdate(player: Player, action: {[string]: any}?)
	local playerData = self.playerData[player]
	if not playerData then return end

	local payload = {
		classMastery = self:getClassMasterySnapshot(player),
		masteryRewards = self:getMasteryRewardsSnapshot(player),
		classId = self:getEquippedClass(player),
	}

	if action then
		payload.action = action
	end

	self.masteryUpdateRemote:FireClient(player, payload)
end

function CurrencyManager:addMasteryXP(player: Player, classId: string, amount: number, reason: string?)
	local playerData = self.playerData[player]
	if not playerData then return end
	if amount <= 0 then return end
	if not ClassTypes.getClass(classId) then return end

	local mastery = playerData.classMastery[classId]
	if not mastery then
		mastery = {level = 1, xp = 0}
		playerData.classMastery[classId] = mastery
	end

	local maxLevel = getMasteryMaxLevel()
	if mastery.level >= maxLevel then
		return
	end

	local previousLevel = mastery.level
	local xpToAdd = math.floor(amount)
	local remainingXp = xpToAdd
	local leveledUp = false

	while remainingXp > 0 and mastery.level < maxLevel do
		local xpToNext = getXpRequiredForLevel(mastery.level)
		local neededXp = xpToNext - mastery.xp

		if remainingXp >= neededXp then
			remainingXp = remainingXp - neededXp
			mastery.level += 1
			mastery.xp = 0
			leveledUp = true
		else
			mastery.xp += remainingXp
			remainingXp = 0
		end
	end

	if mastery.level >= maxLevel then
		mastery.level = maxLevel
		mastery.xp = 0
	end

	local unlockedRewards = {} :: {MasteryRewardSnapshot}
	if mastery.level > previousLevel then
		unlockedRewards = self:unlockMasteryRewardsForLevelRange(player, classId, previousLevel + 1, mastery.level)
	end

	self.pendingSaves[player] = true

	Logger.debug("CurrencyManager", player.Name, "gained", xpToAdd, "mastery XP for", classId, "- Level:", mastery.level, "XP:", mastery.xp, "- RewardsUnlocked:", #unlockedRewards, if reason then "(" .. reason .. ")" else "")

	local actionPayload = {
		type = "xp",
		classId = classId,
		xpGained = xpToAdd,
		leveledUp = leveledUp,
		newLevel = mastery.level,
		reason = reason,
	} :: {[string]: any}

	if #unlockedRewards > 0 then
		actionPayload.unlockedRewards = unlockedRewards
	end

	self:sendMasteryUpdate(player, actionPayload)

	local unlockedTitles = {} :: {MasteryRewardSnapshot}
	for _, reward in ipairs(unlockedRewards) do
		if reward.rewardType == "Title" then
			table.insert(unlockedTitles, reward)
		end
	end

	if #unlockedTitles > 0 then
		self:sendTitleUpdate(player, {
			type = "unlock",
			unlockedTitles = unlockedTitles,
		})
	end
end

-- Start auto-save loop
function CurrencyManager:startAutoSave()
	task.spawn(function()
		while true do
			task.wait(30) -- Save every 30 seconds
			self:saveAllPending()
		end
	end)
end

-- Save all pending player data
function CurrencyManager:saveAllPending()
	for player, isPending in pairs(self.pendingSaves) do
		if isPending and player.Parent then -- Player still in game
			self:savePlayerData(player)
			self.pendingSaves[player] = false
		end
	end
end

-- Get player currency
function CurrencyManager:getCurrency(player: Player): number
	local playerData = self.playerData[player]
	return playerData and playerData.currency or 0
end

-- ============================================
-- GEM & WIN METHODS
-- ============================================

-- Get player gems
function CurrencyManager:getGems(player: Player): number
	local playerData = self.playerData[player]
	return playerData and playerData.gems or 0
end

-- Add gems to player
function CurrencyManager:addGems(player: Player, amount: number, reason: string?)
	local playerData = self.playerData[player]
	if not playerData then return end
	if amount <= 0 then return end

	playerData.gems = playerData.gems + amount
	self.pendingSaves[player] = true

	Logger.debug("CurrencyManager", player.Name, "gained", amount, "gems - Total:", playerData.gems, if reason then "(" .. reason .. ")" else "")

	self:sendGemUpdate(player)
end

-- Spend gems
function CurrencyManager:spendGems(player: Player, amount: number, reason: string?): boolean
	local playerData = self.playerData[player]
	if not playerData then return false end
	if amount <= 0 then return false end
	if playerData.gems < amount then return false end

	playerData.gems = playerData.gems - amount
	self.pendingSaves[player] = true

	Logger.debug("CurrencyManager", player.Name, "spent", amount, "gems - Total:", playerData.gems, if reason then "(" .. reason .. ")" else "")

	self:sendGemUpdate(player)
	return true
end

-- Get player wins
function CurrencyManager:getWins(player: Player): number
	local playerData = self.playerData[player]
	return playerData and playerData.wins or 0
end

-- Add a win
function CurrencyManager:addWin(player: Player)
	local playerData = self.playerData[player]
	if not playerData then return end

	playerData.wins = playerData.wins + 1
	self.pendingSaves[player] = true

	Logger.debug("CurrencyManager", player.Name, "won! Total wins:", playerData.wins)

	self:sendGemUpdate(player)
end

-- Send gem + wins update to client
function CurrencyManager:sendGemUpdate(player: Player)
	local playerData = self.playerData[player]
	if not playerData then return end

	self.updateGemRemote:FireClient(player, {
		gems = playerData.gems,
		wins = playerData.wins,
	})

	-- Keep leaderstats in sync
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local gemsVal = leaderstats:FindFirstChild("Gems")
		if gemsVal then gemsVal.Value = playerData.gems end
		local winsVal = leaderstats:FindFirstChild("Wins")
		if winsVal then winsVal.Value = playerData.wins end
	end
end

-- Send currency update to client
function CurrencyManager:sendCurrencyUpdate(player: Player)
	local playerData = self.playerData[player]
	if not playerData then return end

	self.updateCurrencyRemote:FireClient(player, {
		currency = playerData.currency,
		hasSeenTutorial = playerData.hasSeenTutorial,
	})

	-- Keep leaderstats in sync
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local currencyVal = leaderstats:FindFirstChild("Currency")
		if currencyVal then currencyVal.Value = playerData.currency end
	end
end

-- Remove player data
function CurrencyManager:removePlayer(player: Player)
	-- Save before removing (important!)
	if self.pendingSaves[player] then
		self:savePlayerData(player)
	end

	-- Clear data
	self.playerData[player] = nil
	self.pendingSaves[player] = nil
end

-- ============================================
-- TESTING FUNCTIONS (Debug only)
-- ============================================

-- Set mastery level for a specific class (testing only)
function CurrencyManager:setMasteryLevel(player: Player, classId: string, level: number)
	if not Config.Debug or not Config.Debug.ItemTesting then
		Logger.warn("CurrencyManager", "setMasteryLevel is only available in testing mode")
		return false
	end
	
	local playerData = self.playerData[player]
	if not playerData then return false end
	if not ClassTypes.getClass(classId) then return false end
	
	local maxLevel = getMasteryMaxLevel()
	level = math.clamp(math.floor(level), 1, maxLevel)
	
	-- Initialize mastery if not exists
	if not playerData.classMastery[classId] then
		playerData.classMastery[classId] = {level = 1, xp = 0}
	end
	
	local previousLevel = playerData.classMastery[classId].level
	playerData.classMastery[classId].level = level
	playerData.classMastery[classId].xp = 0
	
	-- Unlock rewards for the new level
	if level > previousLevel then
		self:unlockMasteryRewardsForLevelRange(player, classId, previousLevel + 1, level)
	end
	
	self.pendingSaves[player] = true
	self:sendMasteryUpdate(player, {
		type = "testSet",
		classId = classId,
		newLevel = level,
	})
	
	Logger.debug("CurrencyManager", "TEST: Set", player.Name, classId, "mastery to level", level)
	return true
end

-- Set all mastery levels to same level (testing only)
function CurrencyManager:setAllMasteryLevels(player: Player, level: number)
	if not Config.Debug or not Config.Debug.ItemTesting then
		Logger.warn("CurrencyManager", "setAllMasteryLevels is only available in testing mode")
		return false
	end
	
	for _, classId in ipairs(ClassTypes.getAllClassIds()) do
		self:setMasteryLevel(player, classId, level)
	end
	
	return true
end

-- ============================================
-- ULTIMATE SKILL FUNCTIONS
-- ============================================

-- Check if player has ultimate skill unlocked for a class
function CurrencyManager:hasUltimateUnlocked(player: Player, classId: string): boolean
	local playerData = self.playerData[player]
	if not playerData then return false end
	
	local mastery = playerData.classMastery[classId]
	if not mastery then return false end
	
	local unlockLevel = Config.Mastery and Config.Mastery.UltimateUnlockLevel or 20
	return mastery.level >= unlockLevel
end

-- Get ultimate skill info for a class (returns nil if no ultimate or not configured)
function CurrencyManager:getUltimateSkillInfo(classId: string): {[string]: any}?
	if not Config.Mastery or not Config.Mastery.UltimateSkills then return nil end
	return Config.Mastery.UltimateSkills[classId]
end

-- Get ultimate skill unlock level
function CurrencyManager:getUltimateUnlockLevel(): number
	return Config.Mastery and Config.Mastery.UltimateUnlockLevel or 20
end

return CurrencyManager
