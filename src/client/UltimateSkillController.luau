-- UltimateSkillController: จัดการ Ultimate Skills สำหรับแต่ละ Class
-- - Runner: Sprint (Shift) - วิ่งเร็วขึ้น 50% เป็นเวลา 3 วินาที
-- - Jumper: Double Jump (Space ในอากาศ) - กระโดดได้ 2 ครั้ง
-- - Tank: Iron Will (Shift) - immune ต่อ stun 5 วินาที (cooldown 20 วิ)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Logger = require(ReplicatedStorage.Shared.Logger)

local Config = require(ReplicatedStorage.Shared.Config)
local ClassTypes = require(ReplicatedStorage.Shared.ClassTypes)

local UltimateSkillController = {}
UltimateSkillController.__index = UltimateSkillController

function UltimateSkillController.new()
	local self = setmetatable({}, UltimateSkillController)

	-- State tracking
	self.currentClass = "Normal"
	self.ultimateUnlocked = false
	self.isSprintActive = false
	self.sprintCooldown = 0
	self.airJumpCount = 0
	self.maxAirJumps = 0
	self.isGrounded = true
	self.lastJumpTime = 0
	self.classMastery = nil -- Store mastery data from server

	-- Iron Will state
	self.isIronWillActive = false
	self.ironWillDuration = 0
	self.ironWillCooldown = 0

	-- Remotes
	self.ultimateSkillUpdateRemote = ReplicatedStorage.Remotes.UltimateSkillUpdate
	self.classUpdateRemote = ReplicatedStorage.Remotes.ClassUpdate
	self.masteryUpdateRemote = ReplicatedStorage.Remotes.MasteryUpdate
	self.useUltimateSkillRemote = ReplicatedStorage.Remotes.UseUltimateSkill

	-- Setup
	self:setupRemotes()
	self:setupInputHandling()

	-- Start update loop
	self:startUpdateLoop()

	Logger.info("UltimateSkill", "Initialized")
	return self
end

function UltimateSkillController:setupRemotes()
	-- Listen for class changes
	self.classUpdateRemote.OnClientEvent:Connect(function(data)
		-- ClassManager sends 'classId', not 'equippedClass'
		local classId = data.classId or data.equippedClass
		if classId then
			self:onClassChanged(classId)
		end

		-- Also store mastery data if provided
		if data.classMastery then
			self.classMastery = data.classMastery
			self:checkUltimateUnlock()
		end
	end)

	-- Listen for mastery updates (to check ultimate unlock)
	self.masteryUpdateRemote.OnClientEvent:Connect(function(data)
		if data.classMastery then
			-- Store mastery data locally
			self.classMastery = data.classMastery
			self:checkUltimateUnlock()
		elseif data.action and data.action.type == "testSet" then
			-- Handle test set - need to request fresh data or update locally
			self:checkUltimateUnlock()
		end
	end)
end

function UltimateSkillController:onClassChanged(classId: string)
	self.currentClass = classId
	self:resetSkillState()
	self:checkUltimateUnlock()

	Logger.debug("UltimateSkill", "Class changed to:", classId)
end

function UltimateSkillController:resetSkillState()
	self.isSprintActive = false
	self.sprintCooldown = 0
	self.airJumpCount = 0
	self.maxAirJumps = 0
	self.isIronWillActive = false
	self.ironWillDuration = 0
	self.ironWillCooldown = 0

	-- Reset sprint visual effects
	local character = Players.LocalPlayer.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			-- Reset walk speed to class default
			local classDef = ClassTypes.getClass(self.currentClass)
			if classDef then
				humanoid.WalkSpeed = 16 * classDef.walkSpeedMod
			end
		end
		-- Remove Iron Will visual if active
		self:showIronWillEffect(character, false)
	end
end

function UltimateSkillController:checkUltimateUnlock()
	-- Check if current class has ultimate unlocked
	-- This is determined by mastery level >= UltimateUnlockLevel
	local classMastery = self.classMastery

	if not classMastery then
		Logger.debug("UltimateSkill", "No classMastery data available yet")
		return
	end

	local unlockLevel = Config.Mastery and Config.Mastery.UltimateUnlockLevel or 20

	-- Check current class
	if classMastery[self.currentClass] then
		local level = classMastery[self.currentClass].level
		self.ultimateUnlocked = level >= unlockLevel

		Logger.debug("UltimateSkill", "Checking ultimate unlock for", self.currentClass, "- Level:", level, "- Unlocked:", self.ultimateUnlocked)

		if self.ultimateUnlocked then
			self:setupClassUltimate()
		end
	end

	-- Log all classes with ultimate unlocked
	for classId, mastery in pairs(classMastery) do
		if mastery.level >= unlockLevel then
			local skillConfig = Config.Mastery and Config.Mastery.UltimateSkills and Config.Mastery.UltimateSkills[classId]
			if skillConfig then
				Logger.debug("UltimateSkill", classId, "has ultimate unlocked:", skillConfig.name)
			end
		end
	end
end

function UltimateSkillController:getLocalPlayerMastery(): {[string]: any}?
	return self.classMastery
end

function UltimateSkillController:setupClassUltimate()
	local skillConfig = Config.Mastery and Config.Mastery.UltimateSkills and Config.Mastery.UltimateSkills[self.currentClass]

	if not skillConfig then return end

	if skillConfig.id == "DoubleJump" then
		self.maxAirJumps = skillConfig.maxAirJumps or 1
		Logger.debug("UltimateSkill", "Double Jump enabled - max air jumps:", self.maxAirJumps)
	elseif skillConfig.id == "Sprint" then
		Logger.debug("UltimateSkill", "Sprint enabled - press Shift")
	elseif skillConfig.id == "IronWill" then
		Logger.debug("UltimateSkill", "Iron Will enabled - press Shift to activate (5s immunity, 20s CD)")
	end
end

function UltimateSkillController:setupInputHandling()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			if self.currentClass == "Tank" then
				self:tryActivateIronWill()
			else
				self:tryActivateSprint()
			end
		elseif input.KeyCode == Enum.KeyCode.Space then
			self:tryDoubleJump()
		end
	end)
end

function UltimateSkillController:startUpdateLoop()
	RunService.Heartbeat:Connect(function(dt)
		self:update(dt)
	end)
end

function UltimateSkillController:update(dt: number)
	local character = Players.LocalPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	-- Check ground state
	self:updateGroundState(character, humanoid)

	-- Update sprint cooldown
	if self.sprintCooldown > 0 then
		self.sprintCooldown = math.max(0, self.sprintCooldown - dt)
	end

	-- Update sprint duration
	if self.isSprintActive then
		self.sprintDuration = (self.sprintDuration or 0) - dt
		if self.sprintDuration <= 0 then
			self:endSprint()
		end
	end

	-- Update Iron Will cooldown and duration
	if self.ironWillCooldown > 0 then
		self.ironWillCooldown = math.max(0, self.ironWillCooldown - dt)
	end

	if self.isIronWillActive then
		self.ironWillDuration = (self.ironWillDuration or 0) - dt
		if self.ironWillDuration <= 0 then
			self:endIronWill()
		end
	end

	-- Reset air jump count when grounded
	if self.isGrounded then
		self.airJumpCount = 0
	end
end

function UltimateSkillController:updateGroundState(character: Model, humanoid: Humanoid)
	-- Check if player is on ground
	self.isGrounded = humanoid.FloorMaterial ~= Enum.Material.Air

	-- Also check if humanoid state is Landed or Running
	if humanoid:GetState() == Enum.HumanoidStateType.Landed or
	   humanoid:GetState() == Enum.HumanoidStateType.Running then
		self.isGrounded = true
	elseif humanoid:GetState() == Enum.HumanoidStateType.Freefall or
	       humanoid:GetState() == Enum.HumanoidStateType.Jumping then
		self.isGrounded = false
	end
end

-- ============================================
-- SPRINT (Runner Ultimate)
-- ============================================

function UltimateSkillController:tryActivateSprint()
	-- Check if we have Sprint ultimate
	local skillConfig = Config.Mastery and Config.Mastery.UltimateSkills and Config.Mastery.UltimateSkills[self.currentClass]

	if not skillConfig or skillConfig.id ~= "Sprint" then return end
	if not self.ultimateUnlocked then return end
	if self.sprintCooldown > 0 then return end
	if self.isSprintActive then return end

	-- Activate sprint
	self:activateSprint(skillConfig)
end

function UltimateSkillController:activateSprint(skillConfig: {[string]: any})
	local character = Players.LocalPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	-- Get class base speed
	local classDef = ClassTypes.getClass(self.currentClass)
	local baseSpeed = 16 * (classDef and classDef.walkSpeedMod or 1)

	-- Apply sprint multiplier
	local sprintSpeed = baseSpeed * (skillConfig.speedMultiplier or 1.5)
	humanoid.WalkSpeed = sprintSpeed

	self.isSprintActive = true
	self.sprintDuration = skillConfig.duration or 3
	self.sprintCooldown = skillConfig.cooldown or 12

	-- Visual feedback
	self:showSprintEffect(character, true)

	Logger.debug("UltimateSkill", "Sprint activated! Speed:", sprintSpeed)
end

function UltimateSkillController:endSprint()
	local character = Players.LocalPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	-- Reset to normal speed
	local classDef = ClassTypes.getClass(self.currentClass)
	local baseSpeed = 16 * (classDef and classDef.walkSpeedMod or 1)
	humanoid.WalkSpeed = baseSpeed

	self.isSprintActive = false

	-- Remove visual effect
	self:showSprintEffect(character, false)

	Logger.debug("UltimateSkill", "Sprint ended. Cooldown:", self.sprintCooldown)
end

function UltimateSkillController:showSprintEffect(character: Model, enabled: boolean)
	-- Simple visual effect - speed lines or trail
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	if enabled then
		-- Create trail effect
		local trail = humanoidRootPart:FindFirstChild("SprintTrail")
		if not trail then
			trail = Instance.new("Trail")
			trail.Name = "SprintTrail"
			trail.Color = ColorSequence.new(Color3.fromRGB(100, 200, 255))
			trail.Transparency = NumberSequence.new(0, 0.5)
			trail.Lifetime = 0.3
			trail.MinLength = 0.1
			trail.MaxLength = 5
			trail.WidthScale = NumberSequence.new(1, 0)

			-- Create attachments
			local attachment0 = Instance.new("Attachment")
			attachment0.Name = "TrailAttachment0"
			attachment0.Position = Vector3.new(0, 0, 0.5)
			attachment0.Parent = humanoidRootPart

			local attachment1 = Instance.new("Attachment")
			attachment1.Name = "TrailAttachment1"
			attachment1.Position = Vector3.new(0, 0, -0.5)
			attachment1.Parent = humanoidRootPart

			trail.Attachment0 = attachment0
			trail.Attachment1 = attachment1
			trail.Parent = humanoidRootPart
		end
		trail.Enabled = true
	else
		local trail = humanoidRootPart:FindFirstChild("SprintTrail")
		if trail then
			trail.Enabled = false
		end
	end
end

-- ============================================
-- IRON WILL (Tank Ultimate)
-- ============================================

function UltimateSkillController:tryActivateIronWill()
	local skillConfig = Config.Mastery and Config.Mastery.UltimateSkills and Config.Mastery.UltimateSkills[self.currentClass]

	if not skillConfig or skillConfig.id ~= "IronWill" then return end
	if not self.ultimateUnlocked then return end
	if self.ironWillCooldown > 0 then return end
	if self.isIronWillActive then return end

	self:activateIronWill(skillConfig)
end

function UltimateSkillController:activateIronWill(skillConfig: {[string]: any})
	local character = Players.LocalPlayer.Character
	if not character then return end

	local duration = skillConfig.duration or 5
	local cooldown = skillConfig.cooldown or 20

	self.isIronWillActive = true
	self.ironWillDuration = duration
	self.ironWillCooldown = cooldown

	-- Notify server
	self.useUltimateSkillRemote:FireServer("IronWill")

	-- Visual feedback
	self:showIronWillEffect(character, true)

	Logger.debug("UltimateSkill", "Iron Will activated! Duration:", duration, "Cooldown:", cooldown)
end

function UltimateSkillController:endIronWill()
	local character = Players.LocalPlayer.Character

	self.isIronWillActive = false
	self.ironWillDuration = 0

	-- Remove visual effect
	if character then
		self:showIronWillEffect(character, false)
	end

	Logger.debug("UltimateSkill", "Iron Will ended. Cooldown:", self.ironWillCooldown)
end

function UltimateSkillController:showIronWillEffect(character: Model, enabled: boolean)
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	if enabled then
		-- Create golden shield aura
		local aura = humanoidRootPart:FindFirstChild("IronWillAura")
		if not aura then
			aura = Instance.new("Part")
			aura.Name = "IronWillAura"
			aura.Shape = Enum.PartType.Ball
			aura.Size = Vector3.new(8, 8, 8)
			aura.Anchored = false
			aura.CanCollide = false
			aura.Massless = true
			aura.Transparency = 0.7
			aura.Color = Color3.fromRGB(255, 200, 50)
			aura.Material = Enum.Material.ForceField

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = humanoidRootPart
			weld.Part1 = aura
			weld.Parent = aura

			aura.CFrame = humanoidRootPart.CFrame
			aura.Parent = humanoidRootPart
		end
		aura.Transparency = 0.7
	else
		local aura = humanoidRootPart:FindFirstChild("IronWillAura")
		if aura then
			aura:Destroy()
		end
	end
end

-- ============================================
-- DOUBLE JUMP (Jumper Ultimate)
-- ============================================

function UltimateSkillController:tryDoubleJump()
	-- Check if we have Double Jump ultimate
	local skillConfig = Config.Mastery and Config.Mastery.UltimateSkills and Config.Mastery.UltimateSkills[self.currentClass]

	if not skillConfig or skillConfig.id ~= "DoubleJump" then return end
	if not self.ultimateUnlocked then return end

	-- Can't double jump if on ground or no air jumps left
	if self.isGrounded then
		self.airJumpCount = 0
		return
	end

	if self.airJumpCount >= self.maxAirJumps then return end

	-- Perform air jump
	self:performAirJump()
end

function UltimateSkillController:performAirJump()
	local character = Players.LocalPlayer.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not humanoidRootPart then return end

	-- Get class jump power
	local classDef = ClassTypes.getClass(self.currentClass)
	local jumpPower = 50 * (classDef and classDef.jumpPowerMod or 1)

	-- Apply jump velocity
	humanoidRootPart.AssemblyLinearVelocity = Vector3.new(
		humanoidRootPart.AssemblyLinearVelocity.X,
		jumpPower,
		humanoidRootPart.AssemblyLinearVelocity.Z
	)

	self.airJumpCount = self.airJumpCount + 1

	-- Visual feedback
	self:showAirJumpEffect(humanoidRootPart)

	Logger.debug("UltimateSkill", "Air jump performed! Count:", self.airJumpCount)
end

function UltimateSkillController:showAirJumpEffect(humanoidRootPart: Part)
	-- Create a burst effect
	local burst = Instance.new("Part")
	burst.Name = "AirJumpBurst"
	burst.Shape = Enum.PartType.Ball
	burst.Size = Vector3.new(2, 2, 2)
	burst.Position = humanoidRootPart.Position
	burst.Anchored = true
	burst.CanCollide = false
	burst.Transparency = 0.5
	burst.Color = Color3.fromRGB(100, 255, 100)
	burst.Material = Enum.Material.Neon
	burst.Parent = workspace

	-- Animate and remove
	task.spawn(function()
		for i = 1, 10 do
			burst.Size = Vector3.new(2 + i * 0.5, 2 + i * 0.5, 2 + i * 0.5)
			burst.Transparency = 0.5 + i * 0.05
			task.wait(0.03)
		end
		burst:Destroy()
	end)
end

-- ============================================
-- PUBLIC API
-- ============================================

-- Check if player has stun immunity (Tank Iron Will - now active skill)
function UltimateSkillController:hasStunImmunity(): boolean
	if self.currentClass ~= "Tank" then return false end
	if not self.ultimateUnlocked then return false end
	return self.isIronWillActive
end

-- Get current sprint cooldown
function UltimateSkillController:getSprintCooldown(): number
	return self.sprintCooldown
end

-- Check if sprint is active
function UltimateSkillController:isSprinting(): boolean
	return self.isSprintActive
end

-- Get Iron Will cooldown
function UltimateSkillController:getIronWillCooldown(): number
	return self.ironWillCooldown
end

-- Check if Iron Will is active
function UltimateSkillController:isIronWillActive(): boolean
	return self.isIronWillActive
end

return UltimateSkillController
