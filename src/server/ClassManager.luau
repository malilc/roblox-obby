-- ClassManager: จัดการ Character Classes และ Abilities

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ClassTypes = require(ReplicatedStorage.Shared.ClassTypes)

local ClassManager = {}
ClassManager.__index = ClassManager

-- Base character stats
local BASE_WALK_SPEED = 16
local BASE_JUMP_POWER = 50

export type PlayerClassData = {
	classId: string,
	-- Passive ability state
	sprintCooldown: number, -- For Runner
	isChargingJump: boolean, -- For Jumper
	chargeStartTime: number?,
}

export type ClassAction = {
	type: "equip" | "purchase" | "error",
	classId: string,
	cost: number?,
	reason: "INSUFFICIENT_FUNDS" | "INVALID_CLASS" | "RATE_LIMIT" | "ALREADY_UNLOCKED" | "NOT_IN_LOBBY"?,
}

function ClassManager.new(currencyManager: any?, canChangeClassPredicate: ((Player) -> boolean)?)
	local self = setmetatable({}, ClassManager)
	
	self.currencyManager = currencyManager
	self.canChangeClassPredicate = canChangeClassPredicate
	self.playerClasses = {} :: {[Player]: PlayerClassData}
	self.lastClassRequestTime = {} :: {[Player]: number}
	self.playerConnections = {} :: {[Player]: {RBXScriptConnection}}
	
	-- Remotes
	self.selectClassRemote = ReplicatedStorage.Remotes.SelectClass
	self.classUpdateRemote = ReplicatedStorage.Remotes.ClassUpdate
	
	-- Setup remotes
	self:setupRemotes()
	
	return self
end

function ClassManager:getClassCosts(): {[string]: number}
	local costs = {} :: {[string]: number}
	local configuredCosts = Config.Classes and Config.Classes.Costs

	if type(configuredCosts) == "table" then
		for classId, cost in pairs(configuredCosts) do
			if type(cost) == "number" then
				costs[classId] = cost
			end
		end
	end

	return costs
end

function ClassManager:markClassRequest(player: Player): boolean
	local cooldown = Config.Classes and Config.Classes.RequestCooldown or 0
	if cooldown <= 0 then
		return true
	end

	local now = os.clock()
	local lastRequest = self.lastClassRequestTime[player] or 0
	if now - lastRequest < cooldown then
		return false
	end

	self.lastClassRequestTime[player] = now
	return true
end

function ClassManager:resetAbilityState(data: PlayerClassData)
	-- Ability state reset (reserved for future abilities)
end

function ClassManager:getInitialClass(player: Player): string
	local defaultClass = ClassTypes.DefaultClass

	if self.currencyManager then
		defaultClass = self.currencyManager:getEquippedClass(player)
	end

	if not ClassTypes.getClass(defaultClass) then
		defaultClass = ClassTypes.DefaultClass
	end

	if self.currencyManager and not self.currencyManager:isClassUnlocked(player, defaultClass) then
		defaultClass = ClassTypes.DefaultClass
		self.currencyManager:setEquippedClass(player, defaultClass)
	end

	return defaultClass
end

function ClassManager:setupRemotes()
	self.selectClassRemote.OnServerEvent:Connect(function(player, classId)
		self:setPlayerClass(player, classId)
	end)
end

-- Initialize player with default class
function ClassManager:initPlayer(player: Player)
	local initialClass = self:getInitialClass(player)

	self.playerClasses[player] = {
		classId = initialClass,
	}
	self.playerConnections[player] = {}

	-- Apply class when character spawns (store connection for cleanup)
	local charConn = player.CharacterAdded:Connect(function(character)
		task.wait(0.1) -- Wait for character to load
		self:applyClassStats(player, character)
	end)
	table.insert(self.playerConnections[player], charConn)

	-- Apply to existing character
	if player.Character then
		self:applyClassStats(player, player.Character)
	end

	-- Send initial class info
	self:sendClassUpdate(player)
end

function ClassManager:sendClassError(player: Player, classId: string, reason: "INSUFFICIENT_FUNDS" | "INVALID_CLASS" | "RATE_LIMIT" | "ALREADY_UNLOCKED" | "NOT_IN_LOBBY", cost: number?)
	self:sendClassUpdate(player, {
		type = "error",
		classId = classId,
		cost = cost,
		reason = reason,
	})
end

function ClassManager:applySelectedClass(player: Player, classId: string, action: ClassAction)
	local data = self.playerClasses[player]
	if not data then
		self:initPlayer(player)
		data = self.playerClasses[player]
	end

	local oldClass = data.classId
	data.classId = classId
	self:resetAbilityState(data)

	if self.currencyManager then
		self.currencyManager:setEquippedClass(player, classId)
	end

	-- Apply new stats
	if player.Character then
		self:applyClassStats(player, player.Character)
	end

	print("[ClassManager]", player.Name, "changed class from", oldClass, "to", classId)

	self:sendClassUpdate(player, action)
end

-- Set player's class
function ClassManager:setPlayerClass(player: Player, classId: string)
	if type(classId) ~= "string" then
		classId = self:getPlayerClass(player)
		self:sendClassError(player, classId, "INVALID_CLASS")
		return
	end

	if self.canChangeClassPredicate and self.canChangeClassPredicate(player) ~= true then
		self:sendClassError(player, classId, "NOT_IN_LOBBY")
		return
	end

	if not self:markClassRequest(player) then
		self:sendClassError(player, classId, "RATE_LIMIT")
		return
	end

	if not ClassTypes.getClass(classId) then
		warn("[ClassManager] Invalid class:", classId)
		self:sendClassError(player, classId, "INVALID_CLASS")
		return
	end
	
	local data = self.playerClasses[player]
	if not data then
		self:initPlayer(player)
		data = self.playerClasses[player]
	end

	local isUnlocked = false
	if self.currencyManager then
		isUnlocked = self.currencyManager:isClassUnlocked(player, classId)
	else
		isUnlocked = classId == ClassTypes.DefaultClass
	end

	if isUnlocked then
		if data.classId == classId then
			self:sendClassUpdate(player, {
				type = "equip",
				classId = classId,
			})
			return
		end

		self:applySelectedClass(player, classId, {
			type = "equip",
			classId = classId,
		})
		return
	end

	-- Locked class: purchase + equip
	if not self.currencyManager then
		self:sendClassError(player, classId, "INVALID_CLASS")
		return
	end

	local costs = self:getClassCosts()
	local classCost = costs[classId]
	if type(classCost) ~= "number" then
		self:sendClassError(player, classId, "INVALID_CLASS")
		return
	end

	if not self.currencyManager:canAfford(player, classCost) then
		self:sendClassError(player, classId, "INSUFFICIENT_FUNDS", classCost)
		return
	end

	local didSpend = self.currencyManager:spendCurrency(player, classCost, "ClassPurchase:" .. classId)
	if not didSpend then
		self:sendClassError(player, classId, "INSUFFICIENT_FUNDS", classCost)
		return
	end

	local didUnlock = self.currencyManager:unlockClass(player, classId)
	if not didUnlock then
		-- Safety refund in case unlock state changed between checks
		self.currencyManager:addCurrency(player, classCost)
		self:sendClassError(player, classId, "ALREADY_UNLOCKED", classCost)
		return
	end

	self:applySelectedClass(player, classId, {
		type = "purchase",
		classId = classId,
		cost = classCost,
	})
end

-- Apply class stats to character
function ClassManager:applyClassStats(player: Player, character: Model)
	local data = self.playerClasses[player]
	if not data then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	local classDef = ClassTypes.getClass(data.classId)
	if not classDef then return end
	
	-- Calculate and apply modified stats
	local walkSpeed, jumpPower = ClassTypes.calculateStats(
		data.classId,
		BASE_WALK_SPEED,
		BASE_JUMP_POWER
	)
	
	humanoid.WalkSpeed = walkSpeed
	humanoid.JumpPower = jumpPower
	
	-- Store base stats for reference
	character:SetAttribute("BaseWalkSpeed", walkSpeed)
	character:SetAttribute("BaseJumpPower", jumpPower)
	character:SetAttribute("PlayerClass", data.classId)
	
	-- Apply mastery trail if unlocked
	if self.currencyManager and self.currencyManager.applyActiveTrailToCharacter then
		self.currencyManager:applyActiveTrailToCharacter(player, character)
	end

	print("[ClassManager] Applied", data.classId, "stats to", player.Name)
	print("  WalkSpeed:", walkSpeed, "JumpPower:", jumpPower)
end

-- Get player's class
function ClassManager:getPlayerClass(player: Player): string
	local data = self.playerClasses[player]
	return data and data.classId or ClassTypes.DefaultClass
end

-- Get player's class data
function ClassManager:getPlayerClassData(player: Player): PlayerClassData?
	return self.playerClasses[player]
end

-- Check knockback resistance (called by ItemManager)
function ClassManager:getKnockbackResistance(player: Player): number
	local data = self.playerClasses[player]
	if not data then return 0 end
	
	local classDef = ClassTypes.getClass(data.classId)
	if not classDef then return 0 end
	
	return classDef.knockbackResistance
end

-- Check if player should ignore common item stun (Tank passive)
function ClassManager:shouldIgnoreCommonStun(player: Player): boolean
	local data = self.playerClasses[player]
	if not data then return false end
	
	return data.classId == "Tank"
end

-- ========== UTILITY ==========

-- Send class update to client
function ClassManager:sendClassUpdate(player: Player, action: ClassAction?)
	local data = self.playerClasses[player]
	if not data then return end
	
	local displayInfo = ClassTypes.getClassDisplayInfo(data.classId)
	local classCosts = self:getClassCosts()
	local unlockedClasses = {[ClassTypes.DefaultClass] = true}
	local currency = 0

	if self.currencyManager then
		unlockedClasses = self.currencyManager:getUnlockedClasses(player)
		currency = self.currencyManager:getCurrency(player)
	end
	
	local payload = {
		classId = data.classId,
		classInfo = displayInfo,
		unlockedClasses = unlockedClasses,
		classCosts = classCosts,
		currency = currency,
	}

	if self.currencyManager and self.currencyManager.getClassMasterySnapshot then
		payload.classMastery = self.currencyManager:getClassMasterySnapshot(player)
	end

	if self.currencyManager and self.currencyManager.getMasteryRewardsSnapshot then
		payload.masteryRewards = self.currencyManager:getMasteryRewardsSnapshot(player)
	end

	if action then
		payload.action = action
	end

	self.classUpdateRemote:FireClient(player, payload)
end

-- Remove player
function ClassManager:removePlayer(player: Player)
	-- Disconnect all event connections for this player
	for _, conn in ipairs(self.playerConnections[player] or {}) do
		conn:Disconnect()
	end
	self.playerConnections[player] = nil

	self.playerClasses[player] = nil
	self.lastClassRequestTime[player] = nil
end

-- Reset player to default class
function ClassManager:resetPlayer(player: Player)
	local data = self.playerClasses[player]
	if data then
		self:resetAbilityState(data)
	end
end

return ClassManager
