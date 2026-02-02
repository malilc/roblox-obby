-- ClassManager: จัดการ Character Classes และ Abilities

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

function ClassManager.new()
	local self = setmetatable({}, ClassManager)
	
	self.playerClasses = {} :: {[Player]: PlayerClassData}
	
	-- Remotes
	self.selectClassRemote = ReplicatedStorage.Remotes.SelectClass
	self.classUpdateRemote = ReplicatedStorage.Remotes.ClassUpdate
	
	-- Setup remotes
	self:setupRemotes()
	
	return self
end

function ClassManager:setupRemotes()
	self.selectClassRemote.OnServerEvent:Connect(function(player, classId)
		self:setPlayerClass(player, classId)
	end)
end

-- Initialize player with default class
function ClassManager:initPlayer(player: Player)
	self.playerClasses[player] = {
		classId = ClassTypes.DefaultClass,
		sprintCooldown = 0,
		isChargingJump = false,
		chargeStartTime = nil,
	}
	
	-- Apply class when character spawns
	player.CharacterAdded:Connect(function(character)
		task.wait(0.1) -- Wait for character to load
		self:applyClassStats(player, character)
	end)
	
	-- Apply to existing character
	if player.Character then
		self:applyClassStats(player, player.Character)
	end
	
	-- Send initial class info
	self:sendClassUpdate(player)
end

-- Set player's class
function ClassManager:setPlayerClass(player: Player, classId: string)
	local classDef = ClassTypes.getClass(classId)
	if not classDef then
		warn("[ClassManager] Invalid class:", classId)
		return
	end
	
	local data = self.playerClasses[player]
	if not data then
		self:initPlayer(player)
		data = self.playerClasses[player]
	end
	
	local oldClass = data.classId
	data.classId = classId
	
	-- Reset ability state
	data.sprintCooldown = 0
	data.isChargingJump = false
	data.chargeStartTime = nil
	
	-- Apply new stats
	if player.Character then
		self:applyClassStats(player, player.Character)
	end
	
	print("[ClassManager]", player.Name, "changed class from", oldClass, "to", classId)
	
	-- Notify client
	self:sendClassUpdate(player)
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

-- ========== PASSIVE ABILITIES ==========

-- Runner: Sprint Burst
function ClassManager:trySprintBurst(player: Player): boolean
	local data = self.playerClasses[player]
	if not data or data.classId ~= "Runner" then return false end
	
	local now = tick()
	local classDef = ClassTypes.getClass("Runner")
	local cooldown = classDef.passiveAbility.cooldown or 15
	
	if now - data.sprintCooldown < cooldown then
		return false -- On cooldown
	end
	
	local character = player.Character
	if not character then return false end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return false end
	
	-- Apply sprint burst
	local originalSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = originalSpeed * 1.5 -- 50% boost
	
	-- Reset after 0.5 seconds
	task.delay(0.5, function()
		if humanoid.Parent then
			humanoid.WalkSpeed = originalSpeed
		end
	end)
	
	data.sprintCooldown = now
	
	print("[ClassManager]", player.Name, "used Sprint Burst!")
	
	-- Send cooldown update
	self.classUpdateRemote:FireClient(player, {
		sprintCooldownRemaining = cooldown,
	})
	
	return true
end

-- Jumper: Start charging jump
function ClassManager:startChargeJump(player: Player)
	local data = self.playerClasses[player]
	if not data or data.classId ~= "Jumper" then return end
	
	if data.isChargingJump then return end
	
	data.isChargingJump = true
	data.chargeStartTime = tick()
	
	print("[ClassManager]", player.Name, "started charging jump")
end

-- Jumper: Execute charged jump
function ClassManager:executeChargeJump(player: Player): number?
	local data = self.playerClasses[player]
	if not data or data.classId ~= "Jumper" then return nil end
	
	if not data.isChargingJump then return nil end
	
	local chargeTime = tick() - (data.chargeStartTime or tick())
	data.isChargingJump = false
	data.chargeStartTime = nil
	
	-- Calculate bonus (max 50% bonus at 1.5 seconds charge)
	local maxChargeTime = 1.5
	local chargePercent = math.min(chargeTime / maxChargeTime, 1)
	local jumpBonus = chargePercent * 0.5 -- 0-50% bonus
	
	if chargePercent < 0.3 then
		return nil -- Not enough charge
	end
	
	print("[ClassManager]", player.Name, "released charged jump with", math.floor(jumpBonus * 100), "% bonus")
	
	return 1 + jumpBonus -- Return multiplier
end

-- ========== UTILITY ==========

-- Send class update to client
function ClassManager:sendClassUpdate(player: Player)
	local data = self.playerClasses[player]
	if not data then return end
	
	local displayInfo = ClassTypes.getClassDisplayInfo(data.classId)
	
	self.classUpdateRemote:FireClient(player, {
		classId = data.classId,
		classInfo = displayInfo,
	})
end

-- Remove player
function ClassManager:removePlayer(player: Player)
	self.playerClasses[player] = nil
end

-- Reset player to default class
function ClassManager:resetPlayer(player: Player)
	local data = self.playerClasses[player]
	if data then
		data.sprintCooldown = 0
		data.isChargingJump = false
		data.chargeStartTime = nil
	end
end

return ClassManager
