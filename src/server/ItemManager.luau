-- ItemManager: จัดการระบบ Items (แบบ Mario Kart)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemTypes = require(ReplicatedStorage.Shared.ItemTypes)

local ItemManager = {}
ItemManager.__index = ItemManager

export type PlayerItemData = {
	itemSlots: {string?}, -- Array of 2 item slots [slot1, slot2]
	lastUseTime: number,
	hasShield: boolean,
	shieldExpiry: number?,
	isSlowed: boolean,
	slowExpiry: number?,
	isBoosted: boolean,
	boostExpiry: number?,
}

function ItemManager.new(currencyManager: any?, gameManager: any?, matchManager: any?)
	local self = setmetatable({}, ItemManager)
	
	self.playerItems = {} :: {[Player]: PlayerItemData}
	self.itemPickups = {} :: {Part}
	self.pickupConnections = {} :: {[Part]: RBXScriptConnection}
	self.placedBananas = {} :: {Part} -- Track placed bananas
	self.activeProjectiles = {} :: {Part} -- Track active missiles
	
	self.currencyManager = currencyManager
	self.gameManager = gameManager
	self.matchManager = matchManager
	
	-- Remotes
	self.useItemRemote = ReplicatedStorage.Remotes.UseItem
	self.updateScoreRemote = ReplicatedStorage.Remotes.UpdateScore
	
	-- Listen for item use (with slot index)
	self.useItemRemote.OnServerEvent:Connect(function(player, slotIndex)
		self:useItem(player, slotIndex or 1)
	end)
	
	-- Setup testing remotes (for development, behind debug flag)
	if Config.Debug and Config.Debug.ItemTesting then
		self:setupTestingRemotes()
	end
	
	-- Start effect cleanup loop
	self:startEffectLoop()
	
	return self
end

-- Setup testing remotes for item testing menu
function ItemManager:setupTestingRemotes()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return end
	
	-- Create GiveTestItem remote if not exists
	local giveTestItem = remotes:FindFirstChild("GiveTestItem")
	if not giveTestItem then
		giveTestItem = Instance.new("RemoteEvent")
		giveTestItem.Name = "GiveTestItem"
		giveTestItem.Parent = remotes
	end
	
	-- Create ClearTestItems remote if not exists
	local clearTestItems = remotes:FindFirstChild("ClearTestItems")
	if not clearTestItems then
		clearTestItems = Instance.new("RemoteEvent")
		clearTestItems.Name = "ClearTestItems"
		clearTestItems.Parent = remotes
	end
	
	-- Create SpawnTestDummy remote if not exists
	local spawnDummy = remotes:FindFirstChild("SpawnTestDummy")
	if not spawnDummy then
		spawnDummy = Instance.new("RemoteEvent")
		spawnDummy.Name = "SpawnTestDummy"
		spawnDummy.Parent = remotes
	end
	
	-- Create RemoveTestDummies remote if not exists
	local removeDummies = remotes:FindFirstChild("RemoveTestDummies")
	if not removeDummies then
		removeDummies = Instance.new("RemoteEvent")
		removeDummies.Name = "RemoveTestDummies"
		removeDummies.Parent = remotes
	end
	
	-- Handle GiveTestItem
	giveTestItem.OnServerEvent:Connect(function(player, itemId)
		self:giveTestItem(player, itemId)
	end)
	
	-- Handle ClearTestItems
	clearTestItems.OnServerEvent:Connect(function(player)
		self:clearTestItems(player)
	end)
	
	-- Handle SpawnTestDummy
	spawnDummy.OnServerEvent:Connect(function(player)
		self:spawnTestDummy(player)
	end)
	
	-- Handle RemoveTestDummies
	removeDummies.OnServerEvent:Connect(function(player)
		self:removeTestDummies()
	end)
	
	print("[ItemManager] Testing remotes initialized")
end

-- Give a specific item for testing
function ItemManager:giveTestItem(player: Player, itemId: string)
	local data = self.playerItems[player]
	if not data then
		self:initPlayer(player)
		data = self.playerItems[player]
	end
	
	local itemDef = ItemTypes.getItem(itemId)
	if not itemDef then
		warn("[ItemManager] Invalid item ID for testing:", itemId)
		return
	end
	
	-- Find empty slot or replace slot 1
	local slotIndex = self:getFirstEmptySlot(player) or 1
	data.itemSlots[slotIndex] = itemId
	
	self:sendItemUpdate(player)
	print("[ItemManager] Test item given to", player.Name, ":", itemDef.name, "in slot", slotIndex)
end

-- Clear all items for testing
function ItemManager:clearTestItems(player: Player)
	local data = self.playerItems[player]
	if data then
		data.itemSlots = {nil, nil}
		data.hasShield = false
		data.shieldExpiry = nil
		data.isSlowed = false
		data.slowExpiry = nil
		data.isBoosted = false
		data.boostExpiry = nil
		
		-- Remove visual effects
		self:removeShieldVisual(player)
		self:removeBoostEffect(player)
		self:removeSlowEffect(player)
		
		self:sendItemUpdate(player)
		print("[ItemManager] Test items cleared for", player.Name)
	end
end

-- Spawn a test dummy for testing items (Missile, Swap, Lightning)
function ItemManager:spawnTestDummy(player: Player)
	local character = player.Character
	if not character then return end
	
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	-- Get or create dummies folder
	local dummiesFolder = workspace:FindFirstChild("TestDummies")
	if not dummiesFolder then
		dummiesFolder = Instance.new("Folder")
		dummiesFolder.Name = "TestDummies"
		dummiesFolder.Parent = workspace
	end
	
	-- Create dummy model
	local dummyCount = #dummiesFolder:GetChildren() + 1
	local dummy = Instance.new("Model")
	dummy.Name = "TestDummy_" .. dummyCount
	
	-- Spawn position (in front of player)
	local spawnOffset = hrp.CFrame.LookVector * 15
	local spawnPos = hrp.Position + spawnOffset + Vector3.new(0, 3, 0)
	
	-- Create body parts
	local torso = Instance.new("Part")
	torso.Name = "HumanoidRootPart"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Position = spawnPos
	torso.BrickColor = BrickColor.new("Bright blue")
	torso.Material = Enum.Material.SmoothPlastic
	torso.Anchored = false
	torso.CanCollide = true
	torso.Parent = dummy
	
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.5, 1.5, 1.5)
	head.Shape = Enum.PartType.Ball
	head.Position = spawnPos + Vector3.new(0, 2, 0)
	head.BrickColor = BrickColor.new("Bright yellow")
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = false
	head.CanCollide = true
	head.Parent = dummy
	
	-- Weld head to torso
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = torso
	headWeld.Part1 = head
	headWeld.Parent = head
	
	-- Create Humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.WalkSpeed = 8
	humanoid.JumpPower = 30
	humanoid.Parent = dummy
	
	-- Set primary part
	dummy.PrimaryPart = torso
	dummy.Parent = dummiesFolder
	
	-- Make dummy "walk" randomly
	task.spawn(function()
		while dummy and dummy.Parent do
			task.wait(math.random(2, 5))
			if dummy.PrimaryPart then
				-- Random movement
				local randomDir = Vector3.new(math.random(-1, 1), 0, math.random(-1, 1)).Unit
				local moveAttach = Instance.new("Attachment")
				moveAttach.Parent = dummy.PrimaryPart
				local moveForce = Instance.new("LinearVelocity")
				moveForce.VectorVelocity = randomDir * humanoid.WalkSpeed
				moveForce.MaxForce = 10000
				moveForce.RelativeTo = Enum.ActuatorRelativeTo.World
				moveForce.Attachment0 = moveAttach
				moveForce.Parent = dummy.PrimaryPart

				task.delay(1, function()
					if moveForce.Parent then moveForce:Destroy() end
					if moveAttach.Parent then moveAttach:Destroy() end
				end)
			end
		end
	end)
	
	-- Add name tag
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.new(0, 100, 0, 30)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = torso
	
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
	nameLabel.BackgroundTransparency = 0.3
	nameLabel.Text = "🤖 Dummy " .. dummyCount
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = billboard
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = nameLabel
	
	-- Register dummy as a "fake player" for item targeting
	self:registerDummy(dummy)
	
	print("[ItemManager] Test dummy spawned for", player.Name)
end

-- Register dummy for item targeting
function ItemManager:registerDummy(dummy: Model)
	if not self.testDummies then
		self.testDummies = {}
	end
	table.insert(self.testDummies, dummy)
	
	-- Create fake player data for the dummy
	self.playerItems[dummy] = {
		itemSlots = {nil, nil},
		hasShield = false,
		shieldExpiry = nil,
		isSlowed = false,
		slowExpiry = nil,
		isBoosted = false,
		boostExpiry = nil,
	}
end

-- Remove all test dummies
function ItemManager:removeTestDummies()
	local dummiesFolder = workspace:FindFirstChild("TestDummies")
	if dummiesFolder then
		for _, dummy in ipairs(dummiesFolder:GetChildren()) do
			-- Remove from player data
			if self.playerItems[dummy] then
				self.playerItems[dummy] = nil
			end
			dummy:Destroy()
		end
	end
	
	if self.testDummies then
		self.testDummies = {}
	end
	
	print("[ItemManager] All test dummies removed")
end

-- Get all targetable entities (players + dummies)
function ItemManager:getTargetableEntities(): {Model}
	local entities = {}
	
	-- Add real players
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(entities, player.Character)
		end
	end
	
	-- Add test dummies
	local dummiesFolder = workspace:FindFirstChild("TestDummies")
	if dummiesFolder then
		for _, dummy in ipairs(dummiesFolder:GetChildren()) do
			table.insert(entities, dummy)
		end
	end
	
	return entities
end

-- Get player's race progress (stage + distance)
function ItemManager:getPlayerProgress(player: Player): {currentStage: number, distance: number}?
	if not self.matchManager then
		return nil
	end
	
	local room = self.matchManager:getPlayerRoom(player)
	if not room then
		return nil
	end
	
	local progress = room.playerProgress[player]
	if not progress then
		return nil
	end
	
	return {
		currentStage = progress.currentStage or 0,
		distance = progress.distance or 0
	}
end

-- Check if target is ahead of player in the race
function ItemManager:isTargetAhead(myProgress: {currentStage: number, distance: number}, targetProgress: {currentStage: number, distance: number}): boolean
	-- Target is ahead if they have higher stage
	if targetProgress.currentStage > myProgress.currentStage then
		return true
	end
	-- Or same stage but greater distance
	if targetProgress.currentStage == myProgress.currentStage and targetProgress.distance > myProgress.distance then
		return true
	end
	return false
end

-- Initialize player items
function ItemManager:initPlayer(player: Player)
	self.playerItems[player] = {
		itemSlots = {nil, nil}, -- 2 item slots
		lastUseTime = 0,
		hasShield = false,
		shieldExpiry = nil,
		isSlowed = false,
		slowExpiry = nil,
		isBoosted = false,
		boostExpiry = nil,
	}
end

-- Get player's item in specific slot
function ItemManager:getItemInSlot(player: Player, slotIndex: number): string?
	local data = self.playerItems[player]
	if data and data.itemSlots then
		return data.itemSlots[slotIndex]
	end
	return nil
end

-- Set player's item in specific slot
function ItemManager:setItemInSlot(player: Player, slotIndex: number, itemId: string?)
	local data = self.playerItems[player]
	if data and data.itemSlots then
		data.itemSlots[slotIndex] = itemId
		self:sendItemUpdate(player)
	end
end

-- Check if player has any item
function ItemManager:hasAnyItem(player: Player): boolean
	local data = self.playerItems[player]
	if data and data.itemSlots then
		return data.itemSlots[1] ~= nil or data.itemSlots[2] ~= nil
	end
	return false
end

-- Get first empty slot (returns nil if both full)
function ItemManager:getFirstEmptySlot(player: Player): number?
	local data = self.playerItems[player]
	if data and data.itemSlots then
		if data.itemSlots[1] == nil then return 1 end
		if data.itemSlots[2] == nil then return 2 end
	end
	return nil
end

-- Give random item to player based on their rank
function ItemManager:giveRandomItem(player: Player)
	local data = self.playerItems[player]
	if not data then return end
	
	-- Find first empty slot
	local emptySlot = self:getFirstEmptySlot(player)
	if not emptySlot then
		print("[ItemManager]", player.Name, "inventory full! Both slots occupied.")
		return
	end
	
	-- Get player rank from MatchManager
	local playerRank = 1
	local totalPlayers = 1
	
	if self.matchManager then
		local room = self.matchManager:getPlayerRoom(player)
		if room then
			totalPlayers = #room.players
			local rankings = self.matchManager:calculateRankings(room)
			for i, p in ipairs(rankings) do
				if p == player then
					playerRank = i
					break
				end
			end
		end
	end
	
	-- Get weighted random item
	local item = ItemTypes.getWeightedRandomItem(playerRank, totalPlayers)
	data.itemSlots[emptySlot] = item.id
	
	print("[ItemManager]", player.Name, "got item:", item.name, "in slot", emptySlot, "(Rank:", playerRank, "/", totalPlayers, ")")
	
	self:sendItemUpdate(player)
end

-- Use item from specific slot
function ItemManager:useItem(player: Player, slotIndex: number)
	local data = self.playerItems[player]
	if not data or not data.itemSlots then
		print("[ItemManager]", player.Name, "has no item data")
		return
	end
	
	-- Validate slot index
	slotIndex = slotIndex or 1
	if slotIndex < 1 or slotIndex > 2 then
		slotIndex = 1
	end
	
	local itemId = data.itemSlots[slotIndex]
	if not itemId then
		print("[ItemManager]", player.Name, "has no item in slot", slotIndex)
		return
	end
	
	local itemDef = ItemTypes.getItem(itemId)
	if not itemDef then return end
	
	-- Check cooldown
	local now = os.clock()
	if now - data.lastUseTime < itemDef.cooldown then
		print("[ItemManager]", player.Name, "item on cooldown")
		return
	end
	
	-- Execute item effect
	local success = self:executeItemEffect(player, itemDef)
	
	if success then
		-- Clear item from slot and update cooldown
		data.itemSlots[slotIndex] = nil
		data.lastUseTime = now
		
		print("[ItemManager]", player.Name, "used item:", itemDef.name, "from slot", slotIndex)
		self:sendItemUpdate(player)
	end
end

-- Execute item effect based on type
function ItemManager:executeItemEffect(player: Player, itemDef: ItemTypes.ItemDefinition): boolean
	local character = player.Character
	if not character then return false end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return false end
	
	if itemDef.id == "Missile" then
		return self:useMissile(player, humanoidRootPart, itemDef)
	elseif itemDef.id == "Banana" then
		return self:useBanana(player, humanoidRootPart, itemDef)
	elseif itemDef.id == "Shield" then
		return self:useShield(player, itemDef)
	elseif itemDef.id == "SpeedBoost" then
		return self:useSpeedBoost(player, itemDef)
	elseif itemDef.id == "Swap" then
		return self:useSwap(player, itemDef)
	elseif itemDef.id == "Lightning" then
		return self:useLightning(player, itemDef)
	end
	
	return false
end

-- ========== ITEM EFFECTS ==========

-- Check if target position is within view cone
function ItemManager:isInViewCone(myPos: Vector3, lookDir: Vector3, targetPos: Vector3, maxAngleDegrees: number): boolean
	local toTarget = (targetPos - myPos).Unit
	local dot = lookDir:Dot(toTarget)
	local angleRad = math.acos(math.clamp(dot, -1, 1))
	return math.deg(angleRad) <= maxAngleDegrees
end

-- Find the nearest target (player or dummy) within view cone for homing missile
function ItemManager:findMissileTarget(player: Player, myPos: Vector3, lookDirection: Vector3, maxAngle: number, maxRange: number): (BasePart?, Model?)
	local closestHRP: BasePart? = nil
	local closestModel: Model? = nil
	local closestDistance = maxRange
	
	-- Check all players
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			local character = otherPlayer.Character
			if character then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local distance = (hrp.Position - myPos).Magnitude
					-- Check if within range and view cone
					if distance < closestDistance and self:isInViewCone(myPos, lookDirection, hrp.Position, maxAngle) then
						closestDistance = distance
						closestHRP = hrp
						closestModel = character
					end
				end
			end
		end
	end
	
	-- Check test dummies
	local dummiesFolder = workspace:FindFirstChild("TestDummies")
	if dummiesFolder then
		for _, dummy in ipairs(dummiesFolder:GetChildren()) do
			local hrp = dummy:FindFirstChild("HumanoidRootPart")
			if hrp then
				local distance = (hrp.Position - myPos).Magnitude
				-- Check if within range and view cone
				if distance < closestDistance and self:isInViewCone(myPos, lookDirection, hrp.Position, maxAngle) then
					closestDistance = distance
					closestHRP = hrp
					closestModel = dummy
				end
			end
		end
	end
	
	return closestHRP, closestModel
end

-- Missile: ยิง homing missile ติดตามเป้าหมาย
function ItemManager:useMissile(player: Player, rootPart: Part, itemDef): boolean
	local direction = rootPart.CFrame.LookVector
	local startPos = rootPart.Position + direction * 3 + Vector3.new(0, 1, 0)
	
	-- Create missile with mesh
	local missile = Instance.new("Part")
	missile.Name = "Missile"
	missile.Size = Vector3.new(1, 1, 2)
	missile.Position = startPos
	missile.CFrame = CFrame.lookAt(startPos, startPos + direction)
	missile.Anchored = true
	missile.CanCollide = false
	missile.Material = Enum.Material.Neon
	missile.Color = Color3.fromRGB(255, 80, 30)
	missile:SetAttribute("Owner", player.UserId)
	missile.Parent = workspace
	
	-- Add rocket mesh
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://442793303" -- Rocket mesh
	mesh.Scale = Vector3.new(0.3, 0.3, 0.3)
	mesh.Parent = missile
	
	-- Fire particle trail (flames)
	local fireTrail = Instance.new("ParticleEmitter")
	fireTrail.Name = "FireTrail"
	fireTrail.Lifetime = NumberRange.new(0.3, 0.5)
	fireTrail.Rate = 120
	fireTrail.Speed = NumberRange.new(5, 15)
	fireTrail.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.5),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0)
	})
	fireTrail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 200)),
		ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 150, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 0))
	})
	fireTrail.LightEmission = 1
	fireTrail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	fireTrail.EmissionDirection = Enum.NormalId.Back
	fireTrail.Parent = missile
	
	-- Smoke trail
	local smokeTrail = Instance.new("ParticleEmitter")
	smokeTrail.Name = "SmokeTrail"
	smokeTrail.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smokeTrail.Lifetime = NumberRange.new(0.5, 1)
	smokeTrail.Rate = 50
	smokeTrail.Speed = NumberRange.new(2, 5)
	smokeTrail.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 2)
	})
	smokeTrail.Color = ColorSequence.new(Color3.fromRGB(80, 80, 80))
	smokeTrail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1)
	})
	smokeTrail.EmissionDirection = Enum.NormalId.Back
	smokeTrail.Parent = missile
	
	-- PointLight for glow
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 50)
	light.Brightness = 2
	light.Range = 8
	light.Parent = missile
	
	-- Fire sound
	local fireSound = Instance.new("Sound")
	fireSound.SoundId = "rbxassetid://287390459"
	fireSound.Volume = 0.3
	fireSound.Parent = rootPart
	fireSound:Play()
	task.delay(2, function()
		if fireSound.Parent then fireSound:Destroy() end
	end)
	
	table.insert(self.activeProjectiles, missile)
	
	-- Homing missile parameters
	local speed = itemDef.speed or 60 -- Slightly slower for homing
	local maxRange = itemDef.range or 150
	local turnSpeed = itemDef.turnSpeed or 6 -- How fast missile turns
	local viewConeAngle = itemDef.viewConeAngle or 90 -- Degrees from center
	local trackingRange = itemDef.trackingRange or 120 -- Max distance to acquire target
	local distanceTraveled = 0
	
	-- Find initial target within view cone
	local targetHRP, targetModel = self:findMissileTarget(player, startPos, direction, viewConeAngle, trackingRange)
	
	if targetHRP then
		local targetName = targetModel and targetModel.Name or "Unknown"
		print("[ItemManager] Missile locked on target:", targetName)
	else
		print("[ItemManager] Missile fired without target (straight shot)")
	end
	
	task.spawn(function()
		while missile.Parent and distanceTraveled < maxRange do
			local delta = task.wait()
			
			-- Homing behavior: gradually turn towards target
			if targetHRP and targetHRP.Parent then
				local missilePos = missile.Position
				local targetPos = targetHRP.Position
				local toTarget = (targetPos - missilePos).Unit
				
				-- Gradually turn towards target (lerp direction)
				-- turnSpeed controls how quickly the missile can turn
				local lerpFactor = math.min(turnSpeed * delta, 1)
				direction = (direction * (1 - lerpFactor) + toTarget * lerpFactor).Unit
			end
			
			-- Move in current direction
			local move = direction * speed * delta
			local newPos = missile.Position + move
			
			-- Update CFrame to face movement direction
			missile.CFrame = CFrame.lookAt(newPos, newPos + direction)
			distanceTraveled = distanceTraveled + move.Magnitude
			
			-- Check collision with players
			local hit = self:checkMissileHit(player, missile)
			if hit then
				self:applyStunWithFall(hit, itemDef.stunDuration or 2)
				self:createExplosionEffect(missile.Position)
				break
			end
		end
		
		-- Cleanup
		if missile.Parent then
			-- Missile missed - create small explosion at end
			self:createExplosionEffect(missile.Position)
			missile:Destroy()
		end
		
		-- Remove from tracking
		for i, proj in ipairs(self.activeProjectiles) do
			if proj == missile then
				table.remove(self.activeProjectiles, i)
				break
			end
		end
	end)
	
	return true
end

-- Check if missile hit any player or dummy
function ItemManager:checkMissileHit(owner: Player, missile: Part): (Player | Model)?
	local missilePos = missile.Position
	local ownerCharacter = owner.Character
	
	-- Check real players
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= owner then
			local character = player.Character
			if character then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local distance = (hrp.Position - missilePos).Magnitude
					if distance < 4 then
						-- Check if player has shield
						local data = self.playerItems[player]
						if data and data.hasShield then
							data.hasShield = false
							data.shieldExpiry = nil
							self:removeShieldVisual(player)
							self:sendItemUpdate(player)
							print("[ItemManager]", player.Name, "'s shield blocked missile!")
							return nil -- Shield blocked
						end
						return player
					end
				end
			end
		end
	end
	
	-- Check test dummies
	local dummiesFolder = workspace:FindFirstChild("TestDummies")
	if dummiesFolder then
		for _, dummy in ipairs(dummiesFolder:GetChildren()) do
			local hrp = dummy:FindFirstChild("HumanoidRootPart")
			if hrp then
				local distance = (hrp.Position - missilePos).Magnitude
				if distance < 4 then
					-- Check if dummy has shield
					local data = self.playerItems[dummy]
					if data and data.hasShield then
						data.hasShield = false
						data.shieldExpiry = nil
						print("[ItemManager] Dummy's shield blocked missile!")
						return nil -- Shield blocked
					end
					return dummy
				end
			end
		end
	end
	
	return nil
end

-- Banana: วางบนพื้น
function ItemManager:useBanana(player: Player, rootPart: Part, itemDef): boolean
	local behindDir = -rootPart.CFrame.LookVector
	local dropPos = rootPart.Position + behindDir * 3 + Vector3.new(0, 0, 0)
	
	-- Create banana with mesh
	local banana = Instance.new("Part")
	banana.Name = "Banana"
	banana.Size = Vector3.new(3, 2, 3) -- Larger hitbox for better detection (including jumping)
	banana.Position = dropPos
	banana.Anchored = false -- Let it fall with gravity
	banana.CanCollide = true -- Collide with ground
	banana.Material = Enum.Material.SmoothPlastic
	banana.Color = Color3.fromRGB(255, 230, 50) -- Bright yellow
	banana.Transparency = 0 -- Visible so mesh renders
	banana:SetAttribute("Owner", player.UserId)
	banana:SetAttribute("ExpireTime", os.clock() + (itemDef.duration or 30))
	banana.Parent = workspace
	
	-- Use actual banana mesh
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://6407990721" -- Banana mesh
	mesh.Scale = Vector3.new(0.05, 0.05, 0.05)
	mesh.Offset = Vector3.new(0, 0.5, 0) -- Raise mesh up to align with ground
	mesh.Parent = banana
	
	-- Anchor after landing (wait for it to settle)
	task.delay(1.5, function()
		if banana and banana.Parent then
			banana.Anchored = true
			banana.CanCollide = false -- No collision with players after anchored
		end
	end)
	
	-- Sparkle effect to make it visible
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "BananaSparkle"
	sparkle.Lifetime = NumberRange.new(0.5, 1)
	sparkle.Rate = 8
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0)
	})
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 255, 100))
	sparkle.LightEmission = 1
	sparkle.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1)
	})
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = banana
	
	-- Glow to make it stand out
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 230, 100)
	glow.Brightness = 1
	glow.Range = 6
	glow.Parent = banana
	
	-- Drop sound
	local dropSound = Instance.new("Sound")
	dropSound.SoundId = "rbxassetid://70557734865364" -- Banana drop sound
	dropSound.Volume = 0.4
	dropSound.Parent = banana
	dropSound:Play()
	
	table.insert(self.placedBananas, banana)
	
	-- Track if banana is active and has been triggered
	local isActive = false
	local hasTriggered = false
	
	-- Activate banana after it lands (delay to let it settle)
	task.delay(0.5, function()
		if banana and banana.Parent then
			isActive = true
			banana:SetAttribute("Active", true)
		end
	end)
	
	-- Touch detection (anyone can slip, including owner AND dummies)
	banana.Touched:Connect(function(hit)
		-- Skip if not active yet or already triggered
		if not isActive or hasTriggered then return end
		if not banana or not banana.Parent then return end
		
		-- Check if hit is a character part (not ground/terrain)
		local character = hit.Parent
		if not character then return end
		
		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid then return end
		
		-- Check if it's a real player or a test dummy
		local hitPlayer = Players:GetPlayerFromCharacter(character)
		local isDummy = character.Parent and character.Parent.Name == "TestDummies"
		
		-- Must be either a player or a dummy
		if not hitPlayer and not isDummy then return end
		
		-- Mark as triggered to prevent multiple slips
		hasTriggered = true
		
		-- Handle dummy slip
		if isDummy then
			print("[ItemManager] Dummy", character.Name, "slipped on banana!")
			self:applyDummySlip(character, itemDef)
			-- Destroy banana
			if banana and banana.Parent then
				banana:Destroy()
			end
			return
		end
		
		-- Check if player has shield
		local data = self.playerItems[hitPlayer]
		if data and data.hasShield then
			data.hasShield = false
			data.shieldExpiry = nil
			self:removeShieldVisual(hitPlayer)
			self:sendItemUpdate(hitPlayer)
			print("[ItemManager]", hitPlayer.Name, "'s shield blocked banana!")
		else
			self:applySlip(hitPlayer, itemDef)
		end
		
		-- Remove banana
		if banana.Parent then
			self:createBananaSlipEffect(banana.Position)
			banana:Destroy()
		end
	end)
	
	return true
end

-- Apply slip effect
function ItemManager:applySlip(player: Player, itemDef)
	local character = player.Character
	if not character then return end
	
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	local slipDuration = itemDef.slipDuration or 1.5
	
	print("[ItemManager]", player.Name, "slipped on banana!")
	
	-- Save original values
	local originalWalkSpeed = humanoid.WalkSpeed
	local originalJumpPower = humanoid.JumpPower
	local originalJumpHeight = humanoid.JumpHeight
	
	-- Flag to track if slip is active
	local slipActive = true
	
	-- Simple disable: just stop movement and jumping
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	
	-- Continuous enforcement loop - keeps preventing jumps
	task.spawn(function()
		while slipActive and humanoid and humanoid.Parent do
			humanoid.JumpPower = 0
			humanoid.JumpHeight = 0
			humanoid.Jump = false
			
			-- Cap upward velocity only (prevent jumping)
			if hrp and hrp.Parent then
				local vel = hrp.AssemblyLinearVelocity
				if vel.Y > 3 then
					hrp.AssemblyLinearVelocity = Vector3.new(vel.X, 3, vel.Z)
				end
			end
			
			task.wait()
		end
	end)
	
	-- Slip sound (play immediately)
	local slipSound = Instance.new("Sound")
	slipSound.SoundId = "rbxassetid://129432532096499" -- Banana slip sound
	slipSound.Volume = 0.8
	slipSound.PlayOnRemove = false
	slipSound.Parent = hrp
	slipSound:Play()
	task.delay(3, function()
		if slipSound.Parent then slipSound:Destroy() end
	end)
	
	-- Spinning stars visual
	local starsGui = Instance.new("BillboardGui")
	starsGui.Name = "SlipStars"
	starsGui.Size = UDim2.new(0, 60, 0, 60)
	starsGui.StudsOffset = Vector3.new(0, 3, 0)
	starsGui.AlwaysOnTop = true
	starsGui.Parent = hrp
	
	local starsLabel = Instance.new("TextLabel")
	starsLabel.Size = UDim2.new(1, 0, 1, 0)
	starsLabel.BackgroundTransparency = 1
	starsLabel.Text = "⭐🌟⭐"
	starsLabel.TextSize = 24
	starsLabel.Parent = starsGui
	
	-- Spin animation
	task.spawn(function()
		local startTime = os.clock()
		while os.clock() - startTime < slipDuration and starsGui.Parent do
			starsLabel.Rotation = (os.clock() - startTime) * 360
			task.wait()
		end
		if starsGui.Parent then starsGui:Destroy() end
	end)
	
	-- Yellow slip particles (at feet level)
	local slipParticles = Instance.new("ParticleEmitter")
	slipParticles.Name = "SlipParticles"
	slipParticles.Lifetime = NumberRange.new(0.3, 0.6)
	slipParticles.Rate = 30
	slipParticles.Speed = NumberRange.new(5, 10)
	slipParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0)
	})
	slipParticles.Color = ColorSequence.new(Color3.fromRGB(255, 230, 50))
	slipParticles.LightEmission = 0.5
	slipParticles.SpreadAngle = Vector2.new(180, 180)
	slipParticles.Parent = hrp
	
	task.delay(slipDuration, function()
		if slipParticles.Parent then slipParticles:Destroy() end
	end)
	
	-- Slip effect: slide forward with lift + fall animation
	local slideDirection = hrp.CFrame.LookVector
	local forceAttach = Instance.new("Attachment")
	forceAttach.Parent = hrp
	local slideForce = Instance.new("LinearVelocity")
	slideForce.VectorVelocity = Vector3.new(
		slideDirection.X * 20,
		15, -- Lift up before falling
		slideDirection.Z * 20
	)
	slideForce.MaxForce = math.huge
	slideForce.RelativeTo = Enum.ActuatorRelativeTo.World
	slideForce.Attachment0 = forceAttach
	slideForce.Parent = hrp

	-- Add tumble rotation (fall backwards)
	local tumble = Instance.new("AngularVelocity")
	tumble.AngularVelocity = Vector3.new(
		-8, -- Rotate backwards (fall on back)
		0,
		0
	)
	tumble.MaxTorque = math.huge
	tumble.RelativeTo = Enum.ActuatorRelativeTo.World
	tumble.Attachment0 = forceAttach
	tumble.Parent = hrp
	
	-- Make character ragdoll/fall state
	humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
	
	-- Remove forces after short time
	task.delay(0.3, function()
		if slideForce.Parent then slideForce:Destroy() end
		if tumble.Parent then tumble:Destroy() end
		if forceAttach.Parent then forceAttach:Destroy() end
	end)

	-- Get up after a bit
	task.delay(0.5, function()
		if humanoid and humanoid.Parent then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)

	-- Restore after slip duration
	task.delay(slipDuration, function()
		-- Stop the enforcement loop
		slipActive = false
		
		if humanoid and humanoid.Parent then
			-- Re-enable jumping
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			
			-- Restore movement
			humanoid.WalkSpeed = originalWalkSpeed > 0 and originalWalkSpeed or 16
			humanoid.JumpPower = originalJumpPower > 0 and originalJumpPower or 50
			humanoid.JumpHeight = originalJumpHeight > 0 and originalJumpHeight or 7.2
		end
	end)
end

-- Shield: สร้างโล่ป้องกัน
function ItemManager:useShield(player: Player, itemDef): boolean
	local data = self.playerItems[player]
	if not data then return false end
	
	data.hasShield = true
	data.shieldExpiry = os.clock() + (itemDef.duration or 15)
	
	-- Create shield visual
	self:createShieldVisual(player)
	
	-- Activation sound
	local character = player.Character
	if character then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local activateSound = Instance.new("Sound")
			activateSound.SoundId = "rbxassetid://105300932320033" -- Shield activate
			activateSound.Volume = 0.5
			activateSound.Parent = hrp
			activateSound:Play()
			task.delay(2, function()
				if activateSound.Parent then activateSound:Destroy() end
			end)
		end
	end
	
	print("[ItemManager]", player.Name, "activated shield!")
	return true
end

-- Create shield visual effect
function ItemManager:createShieldVisual(player: Player)
	local character = player.Character
	if not character then return end
	
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	-- Remove existing shield
	local existing = hrp:FindFirstChild("ShieldVisual")
	if existing then existing:Destroy() end
	
	-- Create shield container
	local shieldContainer = Instance.new("Model")
	shieldContainer.Name = "ShieldVisual"
	shieldContainer.Parent = hrp
	
	-- Main shield bubble
	local shield = Instance.new("Part")
	shield.Name = "ShieldBubble"
	shield.Size = Vector3.new(8, 8, 8)
	shield.Shape = Enum.PartType.Ball
	shield.Anchored = false
	shield.CanCollide = false
	shield.Massless = true
	shield.Transparency = 0.7
	shield.Material = Enum.Material.ForceField
	shield.Color = Color3.fromRGB(100, 200, 255)
	shield.Parent = shieldContainer
	
	-- Weld to character
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = shield
	weld.Parent = shield
	
	-- Hexagon/sparkle particles on bubble
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "ShieldParticles"
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Lifetime = NumberRange.new(0.5, 1)
	particles.Rate = 15
	particles.Speed = NumberRange.new(0, 2)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(1, 0)
	})
	particles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 220, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 180, 255))
	})
	particles.LightEmission = 1
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Parent = shield
	
	-- === AURA EFFECT ===
	-- Rising aura particles (going upward around character)
	local auraUp = Instance.new("ParticleEmitter")
	auraUp.Name = "ShieldAuraUp"
	auraUp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	auraUp.Lifetime = NumberRange.new(1, 1.5)
	auraUp.Rate = 30
	auraUp.Speed = NumberRange.new(3, 6)
	auraUp.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 0)
	})
	auraUp.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 200, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 230, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 255, 255))
	})
	auraUp.LightEmission = 1
	auraUp.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.7, 0.7),
		NumberSequenceKeypoint.new(1, 1)
	})
	auraUp.EmissionDirection = Enum.NormalId.Top
	auraUp.SpreadAngle = Vector2.new(30, 30)
	auraUp.Parent = hrp
	
	-- Swirling aura particles (around character)
	local auraSwirl = Instance.new("ParticleEmitter")
	auraSwirl.Name = "ShieldAuraSwirl"
	auraSwirl.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	auraSwirl.Lifetime = NumberRange.new(0.8, 1.2)
	auraSwirl.Rate = 25
	auraSwirl.Speed = NumberRange.new(4, 8)
	auraSwirl.RotSpeed = NumberRange.new(200, 400)
	auraSwirl.Rotation = NumberRange.new(0, 360)
	auraSwirl.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 0)
	})
	auraSwirl.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 180, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 220, 255))
	})
	auraSwirl.LightEmission = 1
	auraSwirl.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1)
	})
	auraSwirl.SpreadAngle = Vector2.new(180, 180)
	auraSwirl.Parent = hrp
	
	-- Ground aura ring particles
	local auraGround = Instance.new("ParticleEmitter")
	auraGround.Name = "ShieldAuraGround"
	auraGround.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	auraGround.Lifetime = NumberRange.new(0.5, 0.8)
	auraGround.Rate = 20
	auraGround.Speed = NumberRange.new(5, 10)
	auraGround.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0)
	})
	auraGround.Color = ColorSequence.new(Color3.fromRGB(100, 200, 255))
	auraGround.LightEmission = 1
	auraGround.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	auraGround.EmissionDirection = Enum.NormalId.Bottom
	auraGround.SpreadAngle = Vector2.new(80, 80)
	auraGround.Parent = hrp
	
	-- Shield glow (enhanced)
	local glow = Instance.new("PointLight")
	glow.Name = "ShieldGlow"
	glow.Color = Color3.fromRGB(100, 200, 255)
	glow.Brightness = 1
	glow.Range = 15
	glow.Parent = shield
	
	-- Pulsing glow animation
	task.spawn(function()
		local startTime = os.clock()
		while shieldContainer and shieldContainer.Parent and glow and glow.Parent do
			local elapsed = os.clock() - startTime
			local pulse = 0.7 + math.sin(elapsed * 3) * 0.3 -- Pulse between 0.4 and 1.0
			glow.Brightness = pulse
			shield.Transparency = 0.6 + math.sin(elapsed * 2) * 0.15 -- Pulse transparency
			task.wait()
		end
	end)
end

-- Remove shield visual with break effect
function ItemManager:removeShieldVisual(player: Player)
	local character = player.Character
	if not character then return end
	
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local shieldContainer = hrp:FindFirstChild("ShieldVisual")
		if shieldContainer then
			-- Create break effect before destroying
			self:createShieldBreakEffect(hrp.Position)
			
			-- Shield break sound
			local breakSound = Instance.new("Sound")
			breakSound.SoundId = "rbxassetid://122218831341898" -- Shield break
			breakSound.Volume = 0.6
			breakSound.Parent = hrp
			breakSound:Play()
			task.delay(2, function()
				if breakSound.Parent then breakSound:Destroy() end
			end)
			
			shieldContainer:Destroy()
		end
		
		-- Remove aura particles from hrp
		local auraUp = hrp:FindFirstChild("ShieldAuraUp")
		if auraUp then auraUp:Destroy() end
		
		local auraSwirl = hrp:FindFirstChild("ShieldAuraSwirl")
		if auraSwirl then auraSwirl:Destroy() end
		
		local auraGround = hrp:FindFirstChild("ShieldAuraGround")
		if auraGround then auraGround:Destroy() end
	end
end

-- Shield break effect
function ItemManager:createShieldBreakEffect(position: Vector3)
	local effect = Instance.new("Part")
	effect.Name = "ShieldBreakEffect"
	effect.Anchored = true
	effect.CanCollide = false
	effect.Size = Vector3.new(1, 1, 1)
	effect.Position = position
	effect.Transparency = 1
	effect.Parent = workspace
	
	-- Glass shatter particles
	local shatter = Instance.new("ParticleEmitter")
	shatter.Name = "ShatterParticles"
	shatter.Lifetime = NumberRange.new(0.5, 1)
	shatter.Rate = 0
	shatter.Speed = NumberRange.new(15, 30)
	shatter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 0)
	})
	shatter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 240, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 180, 255))
	})
	shatter.LightEmission = 1
	shatter.SpreadAngle = Vector2.new(180, 180)
	shatter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1)
	})
	shatter.Acceleration = Vector3.new(0, -30, 0)
	shatter.Parent = effect
	shatter:Emit(40)
	
	-- Blue flash
	local flash = Instance.new("PointLight")
	flash.Color = Color3.fromRGB(100, 200, 255)
	flash.Brightness = 3
	flash.Range = 15
	flash.Parent = effect
	
	task.spawn(function()
		for i = 1, 10 do
			task.wait(0.03)
			flash.Brightness = 3 * (1 - i / 10)
		end
	end)
	
	task.delay(1.5, function()
		effect:Destroy()
	end)
end

-- Speed Boost: เพิ่มความเร็ว
function ItemManager:useSpeedBoost(player: Player, itemDef): boolean
	local data = self.playerItems[player]
	if not data then return false end
	
	local character = player.Character
	if not character then return false end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return false end
	
	-- Store original values
	local originalWalkSpeed = humanoid.WalkSpeed
	local originalJumpPower = humanoid.JumpPower
	
	-- Apply boost
	humanoid.WalkSpeed = originalWalkSpeed * (itemDef.speedMultiplier or 1.5)
	humanoid.JumpPower = originalJumpPower * (itemDef.jumpMultiplier or 1.2)
	
	data.isBoosted = true
	data.boostExpiry = os.clock() + (itemDef.duration or 3)
	
	-- Speed boost sound
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local boostSound = Instance.new("Sound")
		boostSound.SoundId = "rbxassetid://105300932320033" -- Speed boost activate
		boostSound.Volume = 0.7
		boostSound.Parent = hrp
		boostSound:Play()
		task.delay(3, function()
			if boostSound.Parent then boostSound:Destroy() end
		end)
	end
	
	-- Visual effect
	self:createBoostVisual(player)
	
	-- Store original values for restoration
	data.originalWalkSpeed = originalWalkSpeed
	data.originalJumpPower = originalJumpPower
	
	print("[ItemManager]", player.Name, "activated speed boost!")
	return true
end

-- Create boost visual effect
function ItemManager:createBoostVisual(player: Player)
	local character = player.Character
	if not character then return end
	
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	-- Create container for all boost effects
	local boostContainer = Instance.new("Model")
	boostContainer.Name = "BoostEffects"
	boostContainer.Parent = hrp
	
	-- Speed lines particle (motion blur style)
	local speedLines = Instance.new("ParticleEmitter")
	speedLines.Name = "SpeedLines"
	speedLines.Lifetime = NumberRange.new(0.1, 0.2)
	speedLines.Rate = 100
	speedLines.Speed = NumberRange.new(30, 50)
	speedLines.SpreadAngle = Vector2.new(20, 20)
	speedLines.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 2)
	})
	speedLines.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 100)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 0))
	})
	speedLines.LightEmission = 1
	speedLines.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	speedLines.EmissionDirection = Enum.NormalId.Back
	speedLines.Parent = hrp
	
	-- Aura glow particles
	local auraParticles = Instance.new("ParticleEmitter")
	auraParticles.Name = "BoostAura"
	auraParticles.Lifetime = NumberRange.new(0.3, 0.5)
	auraParticles.Rate = 40
	auraParticles.Speed = NumberRange.new(2, 5)
	auraParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 0)
	})
	auraParticles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 100)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 0))
	})
	auraParticles.LightEmission = 1
	auraParticles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1)
	})
	auraParticles.SpreadAngle = Vector2.new(180, 180)
	auraParticles.Parent = hrp
	
	-- Golden glow light
	local auraGlow = Instance.new("PointLight")
	auraGlow.Name = "BoostGlow"
	auraGlow.Color = Color3.fromRGB(255, 200, 50)
	auraGlow.Brightness = 1.5
	auraGlow.Range = 10
	auraGlow.Parent = hrp
	
	-- Create trail on legs/torso if available
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if torso then
		-- Create attachments for trail
		local att0 = Instance.new("Attachment")
		att0.Name = "BoostTrailAtt0"
		att0.Position = Vector3.new(0, 1, 0)
		att0.Parent = torso
		
		local att1 = Instance.new("Attachment")
		att1.Name = "BoostTrailAtt1"
		att1.Position = Vector3.new(0, -1, 0)
		att1.Parent = torso
		
		local trail = Instance.new("Trail")
		trail.Name = "BoostTrail"
		trail.Attachment0 = att0
		trail.Attachment1 = att1
		trail.Lifetime = 0.4
		trail.MinLength = 0.1
		trail.FaceCamera = true
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 150)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 50)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 0))
		})
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.5, 0.6),
			NumberSequenceKeypoint.new(1, 1)
		})
		trail.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0.5)
		})
		trail.LightEmission = 0.5
		trail.Parent = torso
	end
end

-- Remove boost effect
function ItemManager:removeBoostEffect(player: Player)
	local data = self.playerItems[player]
	if not data then return end
	
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			-- Restore original values
			humanoid.WalkSpeed = data.originalWalkSpeed or 16
			humanoid.JumpPower = data.originalJumpPower or 50
		end
		
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			-- Remove all boost effects
			local speedLines = hrp:FindFirstChild("SpeedLines")
			if speedLines then speedLines:Destroy() end
			
			local auraParticles = hrp:FindFirstChild("BoostAura")
			if auraParticles then auraParticles:Destroy() end
			
			local auraGlow = hrp:FindFirstChild("BoostGlow")
			if auraGlow then auraGlow:Destroy() end
			
			local boostContainer = hrp:FindFirstChild("BoostEffects")
			if boostContainer then boostContainer:Destroy() end
		end
		
		-- Remove trail and attachments
		local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		if torso then
			local trail = torso:FindFirstChild("BoostTrail")
			if trail then trail:Destroy() end
			
			local att0 = torso:FindFirstChild("BoostTrailAtt0")
			if att0 then att0:Destroy() end
			
			local att1 = torso:FindFirstChild("BoostTrailAtt1")
			if att1 then att1:Destroy() end
		end
	end
	
	data.isBoosted = false
	data.boostExpiry = nil
	data.originalWalkSpeed = nil
	data.originalJumpPower = nil
end

-- Swap: สลับตำแหน่งกับคนที่ 1
function ItemManager:useSwap(player: Player, itemDef): boolean
	local myChar = player.Character
	if not myChar then return false end
	
	local myHRP = myChar:FindFirstChild("HumanoidRootPart")
	if not myHRP then return false end
	
	local myPos = myHRP.Position
	
	-- Get my progress to determine who is ahead
	local myProgress = self:getPlayerProgress(player)
	
	-- Find the NEAREST target that is AHEAD of me
	local targetPlayer: Player? = nil
	local targetChar: Model? = nil
	local targetHRP: BasePart? = nil
	local closestDistance = math.huge
	
	-- Check all players (only those ahead)
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			local otherChar = otherPlayer.Character
			if otherChar then
				local otherHRP = otherChar:FindFirstChild("HumanoidRootPart")
				if otherHRP then
					-- Check if this player is ahead
					local isAhead = false
					
					if myProgress then
						-- Use race progress to determine "ahead"
						local otherProgress = self:getPlayerProgress(otherPlayer)
						if otherProgress then
							isAhead = self:isTargetAhead(myProgress, otherProgress)
						end
					else
						-- Fallback: use X position (stages progress along +X)
						isAhead = otherHRP.Position.X > myPos.X
					end
					
					if isAhead then
						local distance = (otherHRP.Position - myPos).Magnitude
						if distance < closestDistance then
							closestDistance = distance
							targetPlayer = otherPlayer
							targetChar = otherChar
							targetHRP = otherHRP
						end
					end
				end
			end
		end
	end
	
	-- Also check test dummies (use Z position for ahead check)
	local dummiesFolder = workspace:FindFirstChild("TestDummies")
	if dummiesFolder then
		for _, dummy in ipairs(dummiesFolder:GetChildren()) do
			local hrp = dummy:FindFirstChild("HumanoidRootPart")
			if hrp then
				-- Dummies use X position to determine "ahead" (stages progress along +X)
				local isAhead = hrp.Position.X > myPos.X
				
				if isAhead then
					local distance = (hrp.Position - myPos).Magnitude
					if distance < closestDistance then
						closestDistance = distance
						targetPlayer = nil -- It's a dummy, not a player
						targetChar = dummy
						targetHRP = hrp
					end
				end
			end
		end
	end
	
	-- No valid target ahead
	if not targetHRP then
		print("[ItemManager]", player.Name, "tried to swap but no one is ahead!")
		return false
	end
	
	-- Store positions
	local myCFrame = myHRP.CFrame
	local targetCFrame = targetHRP.CFrame
	
	-- Teleport charge-up sound
	local chargeSound = Instance.new("Sound")
	chargeSound.SoundId = "rbxassetid://93826112721753" -- Swap teleport
	chargeSound.Volume = 0.6
	chargeSound.PlaybackSpeed = 0.8
	chargeSound.Parent = myHRP
	chargeSound:Play()
	
	-- Visual effect before swap (portal effects)
	self:createSwapEffect(myHRP.Position)
	self:createSwapEffect(targetHRP.Position)
	
	-- Swap positions after delay
	task.delay(itemDef.swapDelay or 0.5, function()
		if myHRP.Parent and targetHRP.Parent then
			myHRP.CFrame = targetCFrame
			targetHRP.CFrame = myCFrame
			
			-- Teleport flash at new positions
			self:createSwapFlash(targetCFrame.Position)
			self:createSwapFlash(myCFrame.Position)
			
			local targetName = targetPlayer and targetPlayer.Name or targetChar.Name
			print("[ItemManager]", player.Name, "swapped positions with", targetName, "(ahead, distance:", math.floor(closestDistance), "studs)")
		end
		
		if chargeSound.Parent then chargeSound:Destroy() end
	end)
	
	return true
end

-- Lightning: ทำให้ทุกคนช้าลง
function ItemManager:useLightning(player: Player, itemDef): boolean
	print("[ItemManager]", player.Name, "used Lightning!")
	
	-- Thunder sound (global)
	local thunderSound = Instance.new("Sound")
	thunderSound.SoundId = "rbxassetid://1093102664"
	thunderSound.Volume = 0.8
	thunderSound.PlaybackSpeed = 1.2
	thunderSound.RollOffMode = Enum.RollOffMode.Linear
	thunderSound.RollOffMaxDistance = 1000
	thunderSound.Parent = workspace
	thunderSound:Play()
	task.delay(5, function()
		if thunderSound.Parent then thunderSound:Destroy() end
	end)
	
	-- Affect all other players
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			local data = self.playerItems[otherPlayer]
			if data then
				-- Check shield
				if data.hasShield then
					data.hasShield = false
					data.shieldExpiry = nil
					self:removeShieldVisual(otherPlayer)
					self:sendItemUpdate(otherPlayer)
					print("[ItemManager]", otherPlayer.Name, "'s shield blocked lightning!")
				else
					self:applyLightningSlow(otherPlayer, itemDef)
					
					-- Create lightning strike on each player
					local character = otherPlayer.Character
					if character then
						local hrp = character:FindFirstChild("HumanoidRootPart")
						if hrp then
							self:createLightningStrike(hrp.Position)
						end
					end
				end
			end
		end
	end
	
	-- Affect test dummies too
	local dummiesFolder = workspace:FindFirstChild("TestDummies")
	if dummiesFolder then
		for _, dummy in ipairs(dummiesFolder:GetChildren()) do
			local hrp = dummy:FindFirstChild("HumanoidRootPart")
			if hrp then
				self:createLightningStrike(hrp.Position)
				-- Apply stun to dummy
				self:applyDummyStun(dummy, itemDef.slowDuration or 3)
			end
		end
	end
	
	-- Global lightning effect
	self:createLightningEffect()
	
	return true
end

-- Apply lightning slow effect
function ItemManager:applyLightningSlow(player: Player, itemDef)
	local data = self.playerItems[player]
	if not data then return end
	
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	-- Store original if not already slowed
	if not data.isSlowed then
		data.originalSlowWalkSpeed = humanoid.WalkSpeed
		data.originalSlowJumpPower = humanoid.JumpPower
	end
	
	-- Apply slow
	humanoid.WalkSpeed = (data.originalSlowWalkSpeed or 16) * (itemDef.slowMultiplier or 0.5)
	humanoid.JumpPower = (data.originalSlowJumpPower or 50) * (itemDef.slowMultiplier or 0.5)
	
	data.isSlowed = true
	data.slowExpiry = os.clock() + (itemDef.duration or 3)
	
	-- Electric shock visual
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		-- Main spark particles
		local spark = Instance.new("ParticleEmitter")
		spark.Name = "LightningSpark"
		spark.Lifetime = NumberRange.new(0.1, 0.3)
		spark.Rate = 50
		spark.Speed = NumberRange.new(5, 15)
		spark.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 0)
		})
		spark.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 100)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 50))
		})
		spark.LightEmission = 1
		spark.SpreadAngle = Vector2.new(180, 180)
		spark.Parent = hrp
		
		-- Electric glow
		local electricGlow = Instance.new("PointLight")
		electricGlow.Name = "ElectricGlow"
		electricGlow.Color = Color3.fromRGB(255, 255, 150)
		electricGlow.Brightness = 1
		electricGlow.Range = 8
		electricGlow.Parent = hrp
		
		-- Flickering effect
		task.spawn(function()
			local duration = itemDef.duration or 3
			local startTime = os.clock()
			while os.clock() - startTime < duration and electricGlow.Parent do
				electricGlow.Brightness = 0.5 + math.random() * 1.5
				task.wait(0.05 + math.random() * 0.1)
			end
		end)
		
		-- Zap sound on hit
		local zapSound = Instance.new("Sound")
		zapSound.SoundId = "rbxassetid://8952019380" -- Lightning zap
		zapSound.Volume = 0.4
		zapSound.PlaybackSpeed = 1.5
		zapSound.Parent = hrp
		zapSound:Play()
		task.delay(1, function()
			if zapSound.Parent then zapSound:Destroy() end
		end)
	end
	
	print("[ItemManager]", player.Name, "struck by lightning!")
end

-- Apply stun to test dummy
function ItemManager:applyDummyStun(dummy: Model, duration: number)
	local hrp = dummy:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	local humanoid = dummy:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
	end
	
	-- Electric spark visual
	local spark = Instance.new("ParticleEmitter")
	spark.Name = "LightningSpark"
	spark.Lifetime = NumberRange.new(0.1, 0.3)
	spark.Rate = 50
	spark.Speed = NumberRange.new(5, 15)
	spark.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0)
	})
	spark.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 100)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 50))
	})
	spark.LightEmission = 1
	spark.SpreadAngle = Vector2.new(180, 180)
	spark.Parent = hrp
	
	-- Zap sound
	local zapSound = Instance.new("Sound")
	zapSound.SoundId = "rbxassetid://8952019380" -- Lightning zap
	zapSound.Volume = 0.4
	zapSound.Parent = hrp
	zapSound:Play()
	
	-- Clean up after duration
	task.delay(duration, function()
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = 8
			humanoid.JumpPower = 30
		end
		if spark.Parent then spark:Destroy() end
		if zapSound.Parent then zapSound:Destroy() end
	end)
	
	print("[ItemManager] Test dummy struck by lightning!")
end

-- Apply slip effect to dummy (similar to player slip)
function ItemManager:applyDummySlip(dummy: Model, itemDef)
	local hrp = dummy:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	local humanoid = dummy:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	local slipDuration = itemDef.slipDuration or 1.5
	
	-- Save original values
	local originalWalkSpeed = humanoid.WalkSpeed
	local originalJumpPower = humanoid.JumpPower
	
	-- Disable movement
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	
	-- Slip sound
	local slipSound = Instance.new("Sound")
	slipSound.SoundId = "rbxassetid://129432532096499"
	slipSound.Volume = 0.8
	slipSound.Parent = hrp
	slipSound:Play()
	task.delay(3, function()
		if slipSound.Parent then slipSound:Destroy() end
	end)
	
	-- Stars visual
	local starsGui = Instance.new("BillboardGui")
	starsGui.Name = "SlipStars"
	starsGui.Size = UDim2.new(0, 60, 0, 60)
	starsGui.StudsOffset = Vector3.new(0, 3, 0)
	starsGui.AlwaysOnTop = true
	starsGui.Parent = hrp
	
	local starsLabel = Instance.new("TextLabel")
	starsLabel.Size = UDim2.new(1, 0, 1, 0)
	starsLabel.BackgroundTransparency = 1
	starsLabel.Text = "⭐🌟⭐"
	starsLabel.TextSize = 24
	starsLabel.Parent = starsGui
	
	-- Spin animation
	task.spawn(function()
		local startTime = os.clock()
		while os.clock() - startTime < slipDuration and starsGui.Parent do
			starsLabel.Rotation = (os.clock() - startTime) * 360
			task.wait()
		end
		if starsGui.Parent then starsGui:Destroy() end
	end)
	
	-- Slip particles
	local slipParticles = Instance.new("ParticleEmitter")
	slipParticles.Name = "SlipParticles"
	slipParticles.Lifetime = NumberRange.new(0.3, 0.6)
	slipParticles.Rate = 30
	slipParticles.Speed = NumberRange.new(5, 10)
	slipParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0)
	})
	slipParticles.Color = ColorSequence.new(Color3.fromRGB(255, 230, 50))
	slipParticles.LightEmission = 0.5
	slipParticles.SpreadAngle = Vector2.new(180, 180)
	slipParticles.Parent = hrp
	
	task.delay(slipDuration, function()
		if slipParticles.Parent then slipParticles:Destroy() end
	end)
	
	-- Slide + fall effect
	local slideDirection = hrp.CFrame.LookVector
	local forceAttach = Instance.new("Attachment")
	forceAttach.Parent = hrp
	local slideForce = Instance.new("LinearVelocity")
	slideForce.VectorVelocity = Vector3.new(slideDirection.X * 20, 15, slideDirection.Z * 20)
	slideForce.MaxForce = math.huge
	slideForce.RelativeTo = Enum.ActuatorRelativeTo.World
	slideForce.Attachment0 = forceAttach
	slideForce.Parent = hrp

	local tumble = Instance.new("AngularVelocity")
	tumble.AngularVelocity = Vector3.new(-8, 0, 0)
	tumble.MaxTorque = math.huge
	tumble.RelativeTo = Enum.ActuatorRelativeTo.World
	tumble.Attachment0 = forceAttach
	tumble.Parent = hrp
	
	humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
	
	task.delay(0.3, function()
		if slideForce.Parent then slideForce:Destroy() end
		if tumble.Parent then tumble:Destroy() end
		if forceAttach.Parent then forceAttach:Destroy() end
	end)

	task.delay(0.5, function()
		if humanoid and humanoid.Parent then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)

	-- Restore
	task.delay(slipDuration, function()
		if humanoid and humanoid.Parent then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			humanoid.WalkSpeed = originalWalkSpeed > 0 and originalWalkSpeed or 8
			humanoid.JumpPower = originalJumpPower > 0 and originalJumpPower or 30
		end
	end)
end

-- Apply stun with fall effect (for missile hit) - like banana slip but with explosion theme
function ItemManager:applyStunWithFall(target: Player | Model, duration: number)
	-- Handle both Player and Model (dummy)
	local character: Model?
	local targetName: string
	local isPlayer = false
	
	if typeof(target) == "Instance" and target:IsA("Player") then
		character = target.Character
		targetName = target.Name
		isPlayer = true
	elseif typeof(target) == "Instance" and target:IsA("Model") then
		character = target
		targetName = target.Name
	end
	
	if not character then return end
	
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	print("[ItemManager]", targetName, "hit by missile! Falling...")
	
	-- Save original values
	local originalWalkSpeed = humanoid.WalkSpeed
	local originalJumpPower = humanoid.JumpPower
	local originalJumpHeight = humanoid.JumpHeight or 7.2
	
	-- Flag to track if stun is active
	local stunActive = true
	
	-- Disable movement
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	
	-- Continuous enforcement loop (for players)
	if isPlayer then
		task.spawn(function()
			while stunActive and humanoid and humanoid.Parent do
				humanoid.JumpPower = 0
				humanoid.JumpHeight = 0
				humanoid.Jump = false
				if hrp and hrp.Parent then
					local vel = hrp.AssemblyLinearVelocity
					if vel.Y > 3 then
						hrp.AssemblyLinearVelocity = Vector3.new(vel.X, 3, vel.Z)
					end
				end
				task.wait()
			end
		end)
	end
	
	-- Stun stars visual (missile themed - 💥)
	local starsGui = Instance.new("BillboardGui")
	starsGui.Name = "MissileStunStars"
	starsGui.Size = UDim2.new(0, 70, 0, 70)
	starsGui.StudsOffset = Vector3.new(0, 3, 0)
	starsGui.AlwaysOnTop = true
	starsGui.Parent = hrp
	
	local starsLabel = Instance.new("TextLabel")
	starsLabel.Size = UDim2.new(1, 0, 1, 0)
	starsLabel.BackgroundTransparency = 1
	starsLabel.Text = "💥⭐💥"
	starsLabel.TextSize = 26
	starsLabel.Parent = starsGui
	
	-- Spin animation
	task.spawn(function()
		local startTime = os.clock()
		while os.clock() - startTime < duration and starsGui.Parent do
			starsLabel.Rotation = (os.clock() - startTime) * 360
			task.wait()
		end
		if starsGui.Parent then starsGui:Destroy() end
	end)
	
	-- Smoke/fire particles (missile explosion theme)
	local stunParticles = Instance.new("ParticleEmitter")
	stunParticles.Name = "MissileStunParticles"
	stunParticles.Lifetime = NumberRange.new(0.3, 0.6)
	stunParticles.Rate = 25
	stunParticles.Speed = NumberRange.new(3, 8)
	stunParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0)
	})
	stunParticles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 50)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 100, 100)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 50, 50))
	})
	stunParticles.LightEmission = 0.3
	stunParticles.SpreadAngle = Vector2.new(180, 180)
	stunParticles.Parent = hrp
	
	task.delay(duration, function()
		if stunParticles.Parent then stunParticles:Destroy() end
	end)
	
	-- Knockback + fall effect (thrown by explosion)
	local knockbackDir = hrp.CFrame.LookVector * -1 -- Thrown backwards
	local forceAttach = Instance.new("Attachment")
	forceAttach.Parent = hrp
	local knockbackForce = Instance.new("LinearVelocity")
	knockbackForce.VectorVelocity = Vector3.new(
		knockbackDir.X * 25,
		18, -- Lift up
		knockbackDir.Z * 25
	)
	knockbackForce.MaxForce = math.huge
	knockbackForce.RelativeTo = Enum.ActuatorRelativeTo.World
	knockbackForce.Attachment0 = forceAttach
	knockbackForce.Parent = hrp

	-- Tumble rotation
	local tumble = Instance.new("AngularVelocity")
	tumble.AngularVelocity = Vector3.new(-10, 0, 0) -- Fall backwards
	tumble.MaxTorque = math.huge
	tumble.RelativeTo = Enum.ActuatorRelativeTo.World
	tumble.Attachment0 = forceAttach
	tumble.Parent = hrp
	
	-- Fall state
	humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
	
	-- Remove forces
	task.delay(0.35, function()
		if knockbackForce.Parent then knockbackForce:Destroy() end
		if tumble.Parent then tumble:Destroy() end
		if forceAttach.Parent then forceAttach:Destroy() end
	end)
	
	-- Get up
	task.delay(0.6, function()
		if humanoid and humanoid.Parent then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
	
	-- Restore after duration
	task.delay(duration, function()
		stunActive = false
		
		if humanoid and humanoid.Parent then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			
			if isPlayer then
				humanoid.WalkSpeed = originalWalkSpeed > 0 and originalWalkSpeed or 16
				humanoid.JumpPower = originalJumpPower > 0 and originalJumpPower or 50
				humanoid.JumpHeight = originalJumpHeight > 0 and originalJumpHeight or 7.2
			else
				-- Dummy defaults
				humanoid.WalkSpeed = originalWalkSpeed > 0 and originalWalkSpeed or 8
				humanoid.JumpPower = originalJumpPower > 0 and originalJumpPower or 30
			end
		end
	end)
end

-- Remove slow effect
function ItemManager:removeSlowEffect(player: Player)
	local data = self.playerItems[player]
	if not data then return end
	
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = data.originalSlowWalkSpeed or 16
			humanoid.JumpPower = data.originalSlowJumpPower or 50
		end
		
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local spark = hrp:FindFirstChild("LightningSpark")
			if spark then spark:Destroy() end
			
			local electricGlow = hrp:FindFirstChild("ElectricGlow")
			if electricGlow then electricGlow:Destroy() end
		end
	end
	
	data.isSlowed = false
	data.slowExpiry = nil
	data.originalSlowWalkSpeed = nil
	data.originalSlowJumpPower = nil
end

-- Apply stun effect
function ItemManager:applyStun(target: Player | Model, duration: number)
	-- Handle both Player and Model (dummy)
	local character: Model?
	local targetName: string
	
	if typeof(target) == "Instance" and target:IsA("Player") then
		character = target.Character
		targetName = target.Name
	elseif typeof(target) == "Instance" and target:IsA("Model") then
		character = target
		targetName = target.Name
	end
	
	if not character then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	-- Check if already stunned - don't overwrite original values
	local isAlreadyStunned = character:GetAttribute("IsStunned")
	local originalWalkSpeed = character:GetAttribute("OriginalWalkSpeed") or humanoid.WalkSpeed
	local originalJumpPower = character:GetAttribute("OriginalJumpPower") or humanoid.JumpPower
	
	-- Only save original values if not already stunned
	if not isAlreadyStunned and humanoid.WalkSpeed > 0 then
		character:SetAttribute("OriginalWalkSpeed", humanoid.WalkSpeed)
		character:SetAttribute("OriginalJumpPower", humanoid.JumpPower)
		originalWalkSpeed = humanoid.WalkSpeed
		originalJumpPower = humanoid.JumpPower
	end
	
	-- Mark as stunned
	character:SetAttribute("IsStunned", true)
	
	-- Disable movement
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	
	-- Visual effect
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		-- Remove existing stun visual if any
		local existingStun = hrp:FindFirstChild("StunVisual")
		if existingStun then existingStun:Destroy() end
		
		local stunVisual = Instance.new("BillboardGui")
		stunVisual.Name = "StunVisual"
		stunVisual.Size = UDim2.new(0, 50, 0, 50)
		stunVisual.StudsOffset = Vector3.new(0, 3, 0)
		stunVisual.AlwaysOnTop = true
		stunVisual.Parent = hrp
		
		local stars = Instance.new("TextLabel")
		stars.Size = UDim2.new(1, 0, 1, 0)
		stars.BackgroundTransparency = 1
		stars.Text = "💫"
		stars.TextSize = 30
		stars.Parent = stunVisual
		
		task.delay(duration, function()
			if stunVisual.Parent then
				stunVisual:Destroy()
			end
		end)
	end
	
	-- Restore after duration
	task.delay(duration, function()
		if humanoid.Parent and character.Parent then
			-- Only restore if this is the latest stun (check attribute)
			character:SetAttribute("IsStunned", false)
			humanoid.WalkSpeed = originalWalkSpeed or 16
			humanoid.JumpPower = originalJumpPower or 50
			-- Clear stored values
			character:SetAttribute("OriginalWalkSpeed", nil)
			character:SetAttribute("OriginalJumpPower", nil)
		end
	end)
	
	print("[ItemManager]", targetName, "stunned for", duration, "seconds")
end

-- ========== VISUAL EFFECTS ==========

function ItemManager:createExplosionEffect(position: Vector3)
	-- Use Roblox built-in explosion visual (no damage)
	local builtInExplosion = Instance.new("Explosion")
	builtInExplosion.BlastRadius = 0
	builtInExplosion.BlastPressure = 0
	builtInExplosion.Position = position
	builtInExplosion.Parent = workspace
	
	-- Additional particle effects
	local effectPart = Instance.new("Part")
	effectPart.Name = "ExplosionEffect"
	effectPart.Anchored = true
	effectPart.CanCollide = false
	effectPart.Size = Vector3.new(1, 1, 1)
	effectPart.Position = position
	effectPart.Transparency = 1
	effectPart.Parent = workspace
	
	-- Fire burst particles
	local fireBurst = Instance.new("ParticleEmitter")
	fireBurst.Name = "FireBurst"
	fireBurst.Lifetime = NumberRange.new(0.3, 0.6)
	fireBurst.Rate = 0
	fireBurst.Speed = NumberRange.new(15, 40)
	fireBurst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 3),
		NumberSequenceKeypoint.new(0.5, 2),
		NumberSequenceKeypoint.new(1, 0)
	})
	fireBurst.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 200)),
		ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 150, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 0))
	})
	fireBurst.LightEmission = 1
	fireBurst.SpreadAngle = Vector2.new(180, 180)
	fireBurst.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	fireBurst.Parent = effectPart
	fireBurst:Emit(40)
	
	-- Smoke cloud
	local smokeCloud = Instance.new("ParticleEmitter")
	smokeCloud.Name = "SmokeCloud"
	smokeCloud.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smokeCloud.Lifetime = NumberRange.new(1, 2)
	smokeCloud.Rate = 0
	smokeCloud.Speed = NumberRange.new(5, 15)
	smokeCloud.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(0.5, 4),
		NumberSequenceKeypoint.new(1, 6)
	})
	smokeCloud.Color = ColorSequence.new(Color3.fromRGB(50, 50, 50))
	smokeCloud.SpreadAngle = Vector2.new(180, 180)
	smokeCloud.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	smokeCloud.Parent = effectPart
	smokeCloud:Emit(20)
	
	-- Sparks
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Lifetime = NumberRange.new(0.5, 1)
	sparks.Rate = 0
	sparks.Speed = NumberRange.new(20, 50)
	sparks.Size = NumberSequence.new(0.3, 0)
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 100))
	sparks.LightEmission = 1
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Acceleration = Vector3.new(0, -50, 0)
	sparks.Parent = effectPart
	sparks:Emit(30)
	
	-- PointLight flash
	local flash = Instance.new("PointLight")
	flash.Color = Color3.fromRGB(255, 150, 50)
	flash.Brightness = 5
	flash.Range = 20
	flash.Parent = effectPart
	
	-- Explosion sound
	local explosionSound = Instance.new("Sound")
	explosionSound.SoundId = "rbxassetid://287390954"
	explosionSound.Volume = 0.7
	explosionSound.Parent = effectPart
	explosionSound:Play()
	
	-- Fade out light
	task.spawn(function()
		for i = 1, 10 do
			task.wait(0.03)
			flash.Brightness = 5 * (1 - i / 10)
		end
	end)
	
	task.delay(2, function()
		effectPart:Destroy()
	end)
end

function ItemManager:createBananaSlipEffect(position: Vector3)
	local effect = Instance.new("Part")
	effect.Name = "BananaSlipEffect"
	effect.Anchored = true
	effect.CanCollide = false
	effect.Size = Vector3.new(1, 1, 1)
	effect.Position = position
	effect.Transparency = 1
	effect.Parent = workspace
	
	-- Yellow banana burst
	local bananaBurst = Instance.new("ParticleEmitter")
	bananaBurst.Name = "BananaBurst"
	bananaBurst.Lifetime = NumberRange.new(0.3, 0.6)
	bananaBurst.Rate = 0
	bananaBurst.Speed = NumberRange.new(10, 25)
	bananaBurst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0)
	})
	bananaBurst.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 150)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 50))
	})
	bananaBurst.LightEmission = 0.8
	bananaBurst.SpreadAngle = Vector2.new(180, 180)
	bananaBurst.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1)
	})
	bananaBurst.Parent = effect
	bananaBurst:Emit(25)
	
	-- Sparkle debris
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Lifetime = NumberRange.new(0.5, 1)
	sparkles.Rate = 0
	sparkles.Speed = NumberRange.new(5, 15)
	sparkles.Size = NumberSequence.new(0.3, 0)
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 255, 200))
	sparkles.LightEmission = 1
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Acceleration = Vector3.new(0, -30, 0)
	sparkles.Parent = effect
	sparkles:Emit(15)
	
	-- Brief yellow flash
	local flash = Instance.new("PointLight")
	flash.Color = Color3.fromRGB(255, 230, 100)
	flash.Brightness = 2
	flash.Range = 8
	flash.Parent = effect
	
	task.spawn(function()
		for i = 1, 5 do
			task.wait(0.05)
			flash.Brightness = 2 * (1 - i / 5)
		end
	end)
	
	task.delay(1.5, function()
		effect:Destroy()
	end)
end

function ItemManager:createSwapEffect(position: Vector3)
	-- Portal container
	local portalContainer = Instance.new("Model")
	portalContainer.Name = "SwapPortal"
	portalContainer.Parent = workspace
	
	-- Main portal ring (horizontal)
	local portalRing = Instance.new("Part")
	portalRing.Name = "PortalRing"
	portalRing.Anchored = true
	portalRing.CanCollide = false
	portalRing.Size = Vector3.new(0.5, 8, 8)
	portalRing.Shape = Enum.PartType.Cylinder
	portalRing.Position = position
	portalRing.Orientation = Vector3.new(0, 0, 90)
	portalRing.Transparency = 0.3
	portalRing.Material = Enum.Material.Neon
	portalRing.Color = Color3.fromRGB(180, 80, 255)
	portalRing.Parent = portalContainer
	
	-- Portal center glow
	local portalCenter = Instance.new("Part")
	portalCenter.Name = "PortalCenter"
	portalCenter.Anchored = true
	portalCenter.CanCollide = false
	portalCenter.Size = Vector3.new(6, 6, 6)
	portalCenter.Shape = Enum.PartType.Ball
	portalCenter.Position = position
	portalCenter.Transparency = 0.6
	portalCenter.Material = Enum.Material.Neon
	portalCenter.Color = Color3.fromRGB(150, 50, 200)
	portalCenter.Parent = portalContainer
	
	-- Swirl particles
	local swirlParticles = Instance.new("ParticleEmitter")
	swirlParticles.Name = "SwirlParticles"
	swirlParticles.Lifetime = NumberRange.new(0.5, 1)
	swirlParticles.Rate = 60
	swirlParticles.Speed = NumberRange.new(3, 8)
	swirlParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0)
	})
	swirlParticles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 100, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 50, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 50, 150))
	})
	swirlParticles.LightEmission = 1
	swirlParticles.Rotation = NumberRange.new(0, 360)
	swirlParticles.RotSpeed = NumberRange.new(180, 360)
	swirlParticles.SpreadAngle = Vector2.new(180, 180)
	swirlParticles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(1, 1)
	})
	swirlParticles.Parent = portalCenter
	
	-- Portal glow
	local portalGlow = Instance.new("PointLight")
	portalGlow.Color = Color3.fromRGB(180, 80, 255)
	portalGlow.Brightness = 3
	portalGlow.Range = 15
	portalGlow.Parent = portalCenter
	
	-- Animate portal (expand and spin)
	task.spawn(function()
		local startTime = os.clock()
		local duration = 0.6
		
		while os.clock() - startTime < duration and portalContainer.Parent do
			local progress = (os.clock() - startTime) / duration
			
			-- Spin the ring
			portalRing.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, os.clock() * 5, 0)
			
			-- Expand and fade
			local scale = 1 + progress * 0.5
			portalRing.Size = Vector3.new(0.5 * scale, 8 * scale, 8 * scale)
			portalCenter.Size = Vector3.new(6 * scale, 6 * scale, 6 * scale)
			
			portalRing.Transparency = 0.3 + progress * 0.7
			portalCenter.Transparency = 0.6 + progress * 0.4
			portalGlow.Brightness = 3 * (1 - progress)
			
			task.wait()
		end
		
		portalContainer:Destroy()
	end)
end

-- Flash effect when swap completes
function ItemManager:createSwapFlash(position: Vector3)
	local flash = Instance.new("Part")
	flash.Name = "SwapFlash"
	flash.Anchored = true
	flash.CanCollide = false
	flash.Size = Vector3.new(1, 1, 1)
	flash.Position = position
	flash.Transparency = 1
	flash.Parent = workspace
	
	-- Arrival burst
	local arrivalBurst = Instance.new("ParticleEmitter")
	arrivalBurst.Lifetime = NumberRange.new(0.3, 0.5)
	arrivalBurst.Rate = 0
	arrivalBurst.Speed = NumberRange.new(15, 30)
	arrivalBurst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 0)
	})
	arrivalBurst.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 80, 255))
	})
	arrivalBurst.LightEmission = 1
	arrivalBurst.SpreadAngle = Vector2.new(180, 180)
	arrivalBurst.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1)
	})
	arrivalBurst.Parent = flash
	arrivalBurst:Emit(30)
	
	-- Flash light
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(200, 100, 255)
	light.Brightness = 5
	light.Range = 15
	light.Parent = flash
	
	-- Fade light
	task.spawn(function()
		for i = 1, 10 do
			task.wait(0.03)
			light.Brightness = 5 * (1 - i / 10)
		end
	end)
	
	task.delay(1, function()
		flash:Destroy()
	end)
end

function ItemManager:createLightningEffect()
	-- Global lightning flash effect
	-- Create multiple bright lights across the map for dramatic effect
	local flashContainer = Instance.new("Model")
	flashContainer.Name = "LightningFlash"
	flashContainer.Parent = workspace
	
	-- Multiple flash lights
	for i = 1, 3 do
		local light = Instance.new("PointLight")
		light.Brightness = 15
		light.Range = 1000
		light.Color = Color3.fromRGB(255, 255, 200)
		light.Parent = workspace
		
		-- Flicker effect
		task.spawn(function()
			for j = 1, 6 do
				light.Brightness = math.random(5, 20)
				task.wait(0.05)
			end
			light.Brightness = 0
		end)
		
		task.delay(0.5, function()
			if light.Parent then light:Destroy() end
		end)
	end
	
	-- Sky lighting effect (if Lighting service exists)
	local Lighting = game:GetService("Lighting")
	local originalAmbient = Lighting.Ambient
	local originalBrightness = Lighting.Brightness
	
	-- Flash the sky
	task.spawn(function()
		for i = 1, 3 do
			Lighting.Ambient = Color3.fromRGB(255, 255, 200)
			Lighting.Brightness = 3
			task.wait(0.05)
			Lighting.Ambient = originalAmbient
			Lighting.Brightness = originalBrightness
			task.wait(0.1)
		end
	end)
	
	task.delay(1, function()
		flashContainer:Destroy()
	end)
end

-- Create lightning strike effect on a specific position
function ItemManager:createLightningStrike(position: Vector3)
	local strikeContainer = Instance.new("Model")
	strikeContainer.Name = "LightningStrike"
	strikeContainer.Parent = workspace
	
	-- Lightning bolt (vertical beam effect)
	local skyHeight = 100
	local boltStart = position + Vector3.new(0, skyHeight, 0)
	local boltEnd = position
	
	-- Create multiple segments for zigzag effect
	local numSegments = 8
	local segmentHeight = skyHeight / numSegments
	local lastPos = boltStart
	
	for i = 1, numSegments do
		local segmentOffset = Vector3.new(
			(math.random() - 0.5) * 8, -- Random X offset
			0,
			(math.random() - 0.5) * 8  -- Random Z offset
		)
		
		local nextPos
		if i == numSegments then
			nextPos = boltEnd
		else
			nextPos = boltStart - Vector3.new(0, segmentHeight * i, 0) + segmentOffset
		end
		
		-- Create bolt segment
		local segment = Instance.new("Part")
		segment.Name = "BoltSegment" .. i
		segment.Anchored = true
		segment.CanCollide = false
		segment.Material = Enum.Material.Neon
		segment.Color = Color3.fromRGB(255, 255, 200)
		
		local direction = (nextPos - lastPos)
		local length = direction.Magnitude
		segment.Size = Vector3.new(0.5, length, 0.5)
		segment.CFrame = CFrame.lookAt(lastPos, nextPos) * CFrame.new(0, 0, -length/2) * CFrame.Angles(math.rad(90), 0, 0)
		segment.Parent = strikeContainer
		
		lastPos = nextPos
	end
	
	-- Impact particles at strike point
	local impactEffect = Instance.new("Part")
	impactEffect.Anchored = true
	impactEffect.CanCollide = false
	impactEffect.Size = Vector3.new(1, 1, 1)
	impactEffect.Position = position
	impactEffect.Transparency = 1
	impactEffect.Parent = strikeContainer
	
	local impactBurst = Instance.new("ParticleEmitter")
	impactBurst.Lifetime = NumberRange.new(0.3, 0.6)
	impactBurst.Rate = 0
	impactBurst.Speed = NumberRange.new(15, 30)
	impactBurst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 0)
	})
	impactBurst.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 150)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 100))
	})
	impactBurst.LightEmission = 1
	impactBurst.SpreadAngle = Vector2.new(180, 180)
	impactBurst.Parent = impactEffect
	impactBurst:Emit(30)
	
	-- Impact glow
	local impactGlow = Instance.new("PointLight")
	impactGlow.Color = Color3.fromRGB(255, 255, 200)
	impactGlow.Brightness = 5
	impactGlow.Range = 20
	impactGlow.Parent = impactEffect
	
	-- Fade out the bolt
	task.spawn(function()
		task.wait(0.1)
		for i = 1, 10 do
			for _, part in ipairs(strikeContainer:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = i / 10
				end
			end
			impactGlow.Brightness = 5 * (1 - i / 10)
			task.wait(0.03)
		end
		strikeContainer:Destroy()
	end)
end

-- ========== EFFECT MANAGEMENT ==========

-- Start loop to manage timed effects
function ItemManager:startEffectLoop()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			
			for player, data in pairs(self.playerItems) do
				-- Check shield expiry
				if data.hasShield and data.shieldExpiry and now >= data.shieldExpiry then
					data.hasShield = false
					data.shieldExpiry = nil
					self:removeShieldVisual(player)
					self:sendItemUpdate(player)
				end
				
				-- Check boost expiry
				if data.isBoosted and data.boostExpiry and now >= data.boostExpiry then
					self:removeBoostEffect(player)
					self:sendItemUpdate(player)
				end
				
				-- Check slow expiry
				if data.isSlowed and data.slowExpiry and now >= data.slowExpiry then
					self:removeSlowEffect(player)
					self:sendItemUpdate(player)
				end
			end
			
			-- Clean up expired bananas
			for i = #self.placedBananas, 1, -1 do
				local banana = self.placedBananas[i]
				if not banana.Parent then
					table.remove(self.placedBananas, i)
				elseif banana:GetAttribute("ExpireTime") and now >= banana:GetAttribute("ExpireTime") then
					banana:Destroy()
					table.remove(self.placedBananas, i)
				end
			end
		end
	end)
end

-- ========== ITEM PICKUPS (from map) ==========

-- Setup item pickups from map
function ItemManager:setupItemPickups(pickups: {Part})
	-- Clear existing
	for part, connection in pairs(self.pickupConnections) do
		connection:Disconnect()
	end
	self.pickupConnections = {}
	self.itemPickups = {}
	
	-- Setup new pickups
	for _, pickup in ipairs(pickups) do
		table.insert(self.itemPickups, pickup)
		
		local connection = pickup.Touched:Connect(function(hit)
			local humanoid = hit.Parent:FindFirstChild("Humanoid")
			if humanoid then
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player then
					self:collectPickup(player, pickup)
				end
			end
		end)
		
		self.pickupConnections[pickup] = connection
	end
end

-- Collect pickup
function ItemManager:collectPickup(player: Player, pickup: Part)
	if not pickup.Parent then return end
	if pickup:GetAttribute("IsCollected") then return end
	
	pickup:SetAttribute("IsCollected", true)
	
	local isCoin = pickup:GetAttribute("IsCoin") == true
	local pickupPosition = pickup.Position
	
	if isCoin then
		-- Coin - give currency
		if self.currencyManager then
			self.currencyManager:addCurrency(player, Config.Currency.PerCoin)
		end
		if self.gameManager then
			self.gameManager:addCoinCollected(player)
		end
		self:createCoinCollectEffect(pickupPosition)
	else
		-- Item box - give random item
		self:giveRandomItem(player)
		self:createItemCollectEffect(pickupPosition)
	end
	
	-- Hide pickup
	pickup.Transparency = 1
	pickup.CanCollide = false
	for _, child in pairs(pickup:GetDescendants()) do
		if child:IsA("BasePart") then
			child.Transparency = 1
		elseif child:IsA("ParticleEmitter") or child:IsA("Light") then
			child.Enabled = false
		end
	end
	
	-- Respawn after delay
	task.delay(10, function()
		if pickup.Parent then
			pickup.Transparency = 0
			pickup.CanCollide = false
			pickup:SetAttribute("IsCollected", false)
			for _, child in pairs(pickup:GetDescendants()) do
				if child:IsA("BasePart") then
					child.Transparency = 0
				elseif child:IsA("ParticleEmitter") or child:IsA("Light") then
					child.Enabled = true
				end
			end
		end
	end)
end

-- Create coin collect effect
function ItemManager:createCoinCollectEffect(position: Vector3)
	local effect = Instance.new("Part")
	effect.Anchored = true
	effect.CanCollide = false
	effect.Size = Vector3.new(1, 1, 1)
	effect.Position = position
	effect.Transparency = 1
	effect.Parent = workspace
	
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Lifetime = NumberRange.new(0.3, 0.6)
	sparkles.Rate = 0
	sparkles.Speed = NumberRange.new(5, 15)
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0)
	})
	sparkles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 150)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 215, 0))
	})
	sparkles.LightEmission = 1
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = effect
	
	sparkles:Emit(20)
	
	task.delay(1, function()
		effect:Destroy()
	end)
end

-- Create item collect effect
function ItemManager:createItemCollectEffect(position: Vector3)
	local effect = Instance.new("Part")
	effect.Anchored = true
	effect.CanCollide = false
	effect.Size = Vector3.new(1, 1, 1)
	effect.Position = position
	effect.Transparency = 1
	effect.Parent = workspace
	
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Lifetime = NumberRange.new(0.3, 0.5)
	sparkles.Rate = 0
	sparkles.Speed = NumberRange.new(5, 12)
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0)
	})
	sparkles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 200, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 150, 255))
	})
	sparkles.LightEmission = 1
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = effect
	
	sparkles:Emit(15)
	
	task.delay(1, function()
		effect:Destroy()
	end)
end

-- ========== UTILITY ==========

-- Send item update to client
function ItemManager:sendItemUpdate(player: Player)
	local data = self.playerItems[player]
	if not data then return end
	
	-- สร้าง array ของ 2 slots
	local itemSlots = {}
	for slotIndex = 1, 2 do
		local itemId = data.itemSlots[slotIndex]
		if itemId then
			local itemDef = ItemTypes.getItem(itemId)
			if itemDef then
				itemSlots[slotIndex] = {
					id = itemDef.id,
					name = itemDef.name,
					description = itemDef.description,
					icon = itemDef.icon,
					rarity = itemDef.rarity,
					rarityColor = {ItemTypes.getRarityColor(itemDef.rarity):ToHex()},
				}
			else
				itemSlots[slotIndex] = false -- item not found
			end
		else
			itemSlots[slotIndex] = false -- empty slot
		end
	end
	
	self.updateScoreRemote:FireClient(player, {
		itemSlots = itemSlots, -- Array of 2: false = empty, table = has item
		hasShield = data.hasShield,
		isBoosted = data.isBoosted,
		isSlowed = data.isSlowed,
	})
end

-- Reset player
function ItemManager:resetPlayer(player: Player)
	local data = self.playerItems[player]
	if data then
		-- Remove any active effects
		if data.hasShield then
			self:removeShieldVisual(player)
		end
		if data.isBoosted then
			self:removeBoostEffect(player)
		end
		if data.isSlowed then
			self:removeSlowEffect(player)
		end
	end
	
	self.playerItems[player] = {
		itemSlots = {nil, nil}, -- 2 empty slots
		lastUseTime = 0,
		hasShield = false,
		shieldExpiry = nil,
		isSlowed = false,
		slowExpiry = nil,
		isBoosted = false,
		boostExpiry = nil,
	}
	
	self:sendItemUpdate(player)
end

-- Remove player
function ItemManager:removePlayer(player: Player)
	local data = self.playerItems[player]
	if data then
		if data.hasShield then
			self:removeShieldVisual(player)
		end
		if data.isBoosted then
			self:removeBoostEffect(player)
		end
		if data.isSlowed then
			self:removeSlowEffect(player)
		end
	end
	
	self.playerItems[player] = nil
end

-- Set match manager reference
function ItemManager:setMatchManager(matchManager: any)
	self.matchManager = matchManager
end

return ItemManager
