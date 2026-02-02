-- ItemManager: จัดการระบบ Items (แบบ Mario Kart)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemTypes = require(ReplicatedStorage.Shared.ItemTypes)

local ItemManager = {}
ItemManager.__index = ItemManager

export type PlayerItemData = {
	currentItem: string?, -- Item ID ที่ถืออยู่
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
	
	-- Listen for item use
	self.useItemRemote.OnServerEvent:Connect(function(player)
		self:useItem(player)
	end)
	
	-- Start effect cleanup loop
	self:startEffectLoop()
	
	return self
end

-- Initialize player items
function ItemManager:initPlayer(player: Player)
	self.playerItems[player] = {
		currentItem = nil,
		lastUseTime = 0,
		hasShield = false,
		shieldExpiry = nil,
		isSlowed = false,
		slowExpiry = nil,
		isBoosted = false,
		boostExpiry = nil,
	}
end

-- Get player's current item
function ItemManager:getCurrentItem(player: Player): string?
	local data = self.playerItems[player]
	return data and data.currentItem or nil
end

-- Set player's current item
function ItemManager:setCurrentItem(player: Player, itemId: string?)
	local data = self.playerItems[player]
	if data then
		data.currentItem = itemId
		self:sendItemUpdate(player)
	end
end

-- Give random item to player based on their rank
function ItemManager:giveRandomItem(player: Player)
	local data = self.playerItems[player]
	if not data then return end
	
	-- Don't give if already has item
	if data.currentItem then
		print("[ItemManager]", player.Name, "already has item:", data.currentItem)
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
	data.currentItem = item.id
	
	print("[ItemManager]", player.Name, "got item:", item.name, "(Rank:", playerRank, "/", totalPlayers, ")")
	
	self:sendItemUpdate(player)
end

-- Use current item
function ItemManager:useItem(player: Player)
	local data = self.playerItems[player]
	if not data or not data.currentItem then
		print("[ItemManager]", player.Name, "has no item to use")
		return
	end
	
	local itemId = data.currentItem
	local itemDef = ItemTypes.getItem(itemId)
	if not itemDef then return end
	
	-- Check cooldown
	local now = tick()
	if now - data.lastUseTime < itemDef.cooldown then
		print("[ItemManager]", player.Name, "item on cooldown")
		return
	end
	
	-- Execute item effect
	local success = self:executeItemEffect(player, itemDef)
	
	if success then
		-- Clear item and update cooldown
		data.currentItem = nil
		data.lastUseTime = now
		
		print("[ItemManager]", player.Name, "used item:", itemDef.name)
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

-- Missile: ยิงไปข้างหน้า
function ItemManager:useMissile(player: Player, rootPart: Part, itemDef): boolean
	local direction = rootPart.CFrame.LookVector
	local startPos = rootPart.Position + direction * 3 + Vector3.new(0, 1, 0)
	
	-- Create missile
	local missile = Instance.new("Part")
	missile.Name = "Missile"
	missile.Size = Vector3.new(1, 1, 3)
	missile.Position = startPos
	missile.CFrame = CFrame.lookAt(startPos, startPos + direction)
	missile.Anchored = true
	missile.CanCollide = false
	missile.Material = Enum.Material.Neon
	missile.Color = Color3.fromRGB(255, 100, 50)
	missile:SetAttribute("Owner", player.UserId)
	missile.Parent = workspace
	
	-- Particle trail
	local trail = Instance.new("ParticleEmitter")
	trail.Lifetime = NumberRange.new(0.3, 0.5)
	trail.Rate = 100
	trail.Speed = NumberRange.new(0, 0)
	trail.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0)
	})
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 100)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 0))
	})
	trail.LightEmission = 1
	trail.Parent = missile
	
	table.insert(self.activeProjectiles, missile)
	
	-- Move missile
	local speed = itemDef.speed or 80
	local maxRange = itemDef.range or 150
	local distanceTraveled = 0
	
	task.spawn(function()
		while missile.Parent and distanceTraveled < maxRange do
			local delta = task.wait()
			local move = direction * speed * delta
			missile.CFrame = missile.CFrame + move
			distanceTraveled = distanceTraveled + move.Magnitude
			
			-- Check collision with players
			local hit = self:checkMissileHit(player, missile)
			if hit then
				self:applyStun(hit, itemDef.stunDuration or 2)
				self:createExplosionEffect(missile.Position)
				break
			end
		end
		
		-- Cleanup
		if missile.Parent then
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

-- Check if missile hit any player
function ItemManager:checkMissileHit(owner: Player, missile: Part): Player?
	local missilePos = missile.Position
	
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
	
	return nil
end

-- Banana: วางบนพื้น
function ItemManager:useBanana(player: Player, rootPart: Part, itemDef): boolean
	local behindDir = -rootPart.CFrame.LookVector
	local dropPos = rootPart.Position + behindDir * 3 + Vector3.new(0, -2, 0)
	
	-- Create banana
	local banana = Instance.new("Part")
	banana.Name = "Banana"
	banana.Size = Vector3.new(2, 0.5, 2)
	banana.Position = dropPos
	banana.Anchored = true
	banana.CanCollide = false
	banana.Material = Enum.Material.SmoothPlastic
	banana.Color = Color3.fromRGB(255, 230, 50)
	banana.Shape = Enum.PartType.Cylinder
	banana.Orientation = Vector3.new(0, 0, 90)
	banana:SetAttribute("Owner", player.UserId)
	banana:SetAttribute("ExpireTime", tick() + (itemDef.duration or 30))
	banana.Parent = workspace
	
	table.insert(self.placedBananas, banana)
	
	-- Touch detection
	banana.Touched:Connect(function(hit)
		local humanoid = hit.Parent:FindFirstChild("Humanoid")
		if humanoid then
			local hitPlayer = Players:GetPlayerFromCharacter(hit.Parent)
			if hitPlayer and hitPlayer ~= player then
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
			end
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
	
	print("[ItemManager]", player.Name, "slipped on banana!")
	
	-- Knockback
	local knockback = Instance.new("BodyVelocity")
	knockback.Velocity = Vector3.new(
		(math.random() - 0.5) * (itemDef.knockbackForce or 50),
		30,
		(math.random() - 0.5) * (itemDef.knockbackForce or 50)
	)
	knockback.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	knockback.Parent = hrp
	
	task.delay(0.3, function()
		if knockback.Parent then
			knockback:Destroy()
		end
	end)
	
	-- Brief stun
	self:applyStun(player, itemDef.slipDuration or 1.5)
end

-- Shield: สร้างโล่ป้องกัน
function ItemManager:useShield(player: Player, itemDef): boolean
	local data = self.playerItems[player]
	if not data then return false end
	
	data.hasShield = true
	data.shieldExpiry = tick() + (itemDef.duration or 15)
	
	-- Create shield visual
	self:createShieldVisual(player)
	
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
	
	-- Create bubble
	local shield = Instance.new("Part")
	shield.Name = "ShieldVisual"
	shield.Size = Vector3.new(8, 8, 8)
	shield.Shape = Enum.PartType.Ball
	shield.Anchored = false
	shield.CanCollide = false
	shield.Massless = true
	shield.Transparency = 0.7
	shield.Material = Enum.Material.ForceField
	shield.Color = Color3.fromRGB(100, 200, 255)
	shield.Parent = hrp
	
	-- Weld to character
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = shield
	weld.Parent = shield
end

-- Remove shield visual
function ItemManager:removeShieldVisual(player: Player)
	local character = player.Character
	if not character then return end
	
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		local shield = hrp:FindFirstChild("ShieldVisual")
		if shield then
			shield:Destroy()
		end
	end
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
	data.boostExpiry = tick() + (itemDef.duration or 3)
	
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
	
	-- Speed lines particle
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "BoostParticles"
	particles.Lifetime = NumberRange.new(0.2, 0.4)
	particles.Rate = 50
	particles.Speed = NumberRange.new(10, 20)
	particles.SpreadAngle = Vector2.new(30, 30)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0)
	})
	particles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 100)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 0))
	})
	particles.LightEmission = 1
	particles.EmissionDirection = Enum.NormalId.Back
	particles.Parent = hrp
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
			local particles = hrp:FindFirstChild("BoostParticles")
			if particles then particles:Destroy() end
		end
	end
	
	data.isBoosted = false
	data.boostExpiry = nil
	data.originalWalkSpeed = nil
	data.originalJumpPower = nil
end

-- Swap: สลับตำแหน่งกับคนที่ 1
function ItemManager:useSwap(player: Player, itemDef): boolean
	if not self.matchManager then return false end
	
	local room = self.matchManager:getPlayerRoom(player)
	if not room then return false end
	
	local rankings = self.matchManager:calculateRankings(room)
	if #rankings < 2 then return false end
	
	-- Find first place player (that isn't self)
	local targetPlayer: Player? = nil
	for _, p in ipairs(rankings) do
		if p ~= player then
			targetPlayer = p
			break
		end
	end
	
	if not targetPlayer then return false end
	
	local myChar = player.Character
	local targetChar = targetPlayer.Character
	
	if not myChar or not targetChar then return false end
	
	local myHRP = myChar:FindFirstChild("HumanoidRootPart")
	local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
	
	if not myHRP or not targetHRP then return false end
	
	-- Store positions
	local myPos = myHRP.CFrame
	local targetPos = targetHRP.CFrame
	
	-- Visual effect before swap
	self:createSwapEffect(myHRP.Position)
	self:createSwapEffect(targetHRP.Position)
	
	-- Swap positions after delay
	task.delay(itemDef.swapDelay or 0.5, function()
		if myHRP.Parent and targetHRP.Parent then
			myHRP.CFrame = targetPos
			targetHRP.CFrame = myPos
			
			print("[ItemManager]", player.Name, "swapped positions with", targetPlayer.Name)
		end
	end)
	
	return true
end

-- Lightning: ทำให้ทุกคนช้าลง
function ItemManager:useLightning(player: Player, itemDef): boolean
	print("[ItemManager]", player.Name, "used Lightning!")
	
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
				end
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
	data.slowExpiry = tick() + (itemDef.duration or 3)
	
	-- Shrink effect
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		-- Add lightning particles
		local spark = Instance.new("ParticleEmitter")
		spark.Name = "LightningSpark"
		spark.Lifetime = NumberRange.new(0.1, 0.3)
		spark.Rate = 30
		spark.Speed = NumberRange.new(5, 10)
		spark.Size = NumberSequence.new(0.3)
		spark.Color = ColorSequence.new(Color3.fromRGB(255, 255, 100))
		spark.LightEmission = 1
		spark.Parent = hrp
	end
	
	print("[ItemManager]", player.Name, "struck by lightning!")
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
		end
	end
	
	data.isSlowed = false
	data.slowExpiry = nil
	data.originalSlowWalkSpeed = nil
	data.originalSlowJumpPower = nil
end

-- Apply stun effect
function ItemManager:applyStun(player: Player, duration: number)
	local character = player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end
	
	-- Disable movement
	local originalWalkSpeed = humanoid.WalkSpeed
	local originalJumpPower = humanoid.JumpPower
	
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	
	-- Visual effect
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
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
		if humanoid.Parent then
			humanoid.WalkSpeed = originalWalkSpeed
			humanoid.JumpPower = originalJumpPower
		end
	end)
	
	print("[ItemManager]", player.Name, "stunned for", duration, "seconds")
end

-- ========== VISUAL EFFECTS ==========

function ItemManager:createExplosionEffect(position: Vector3)
	local explosion = Instance.new("Part")
	explosion.Anchored = true
	explosion.CanCollide = false
	explosion.Size = Vector3.new(1, 1, 1)
	explosion.Position = position
	explosion.Transparency = 1
	explosion.Parent = workspace
	
	local particles = Instance.new("ParticleEmitter")
	particles.Lifetime = NumberRange.new(0.3, 0.6)
	particles.Rate = 0
	particles.Speed = NumberRange.new(10, 30)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 0)
	})
	particles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 0))
	})
	particles.LightEmission = 1
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Parent = explosion
	
	particles:Emit(30)
	
	task.delay(1, function()
		explosion:Destroy()
	end)
end

function ItemManager:createBananaSlipEffect(position: Vector3)
	local effect = Instance.new("Part")
	effect.Anchored = true
	effect.CanCollide = false
	effect.Size = Vector3.new(1, 1, 1)
	effect.Position = position
	effect.Transparency = 1
	effect.Parent = workspace
	
	local particles = Instance.new("ParticleEmitter")
	particles.Lifetime = NumberRange.new(0.3, 0.5)
	particles.Rate = 0
	particles.Speed = NumberRange.new(5, 15)
	particles.Size = NumberSequence.new(0.5)
	particles.Color = ColorSequence.new(Color3.fromRGB(255, 230, 50))
	particles.LightEmission = 0.5
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Parent = effect
	
	particles:Emit(20)
	
	task.delay(1, function()
		effect:Destroy()
	end)
end

function ItemManager:createSwapEffect(position: Vector3)
	local effect = Instance.new("Part")
	effect.Anchored = true
	effect.CanCollide = false
	effect.Size = Vector3.new(6, 6, 6)
	effect.Shape = Enum.PartType.Ball
	effect.Position = position
	effect.Transparency = 0.5
	effect.Material = Enum.Material.Neon
	effect.Color = Color3.fromRGB(200, 100, 255)
	effect.Parent = workspace
	
	task.spawn(function()
		for i = 1, 10 do
			effect.Size = effect.Size + Vector3.new(0.5, 0.5, 0.5)
			effect.Transparency = 0.5 + (0.5 * i / 10)
			task.wait(0.05)
		end
		effect:Destroy()
	end)
end

function ItemManager:createLightningEffect()
	-- Screen flash effect would be handled client-side
	-- Here we just create a brief light
	local light = Instance.new("PointLight")
	light.Brightness = 10
	light.Range = 500
	light.Color = Color3.fromRGB(255, 255, 200)
	light.Parent = workspace.CurrentCamera or workspace
	
	task.delay(0.3, function()
		if light.Parent then
			light:Destroy()
		end
	end)
end

-- ========== EFFECT MANAGEMENT ==========

-- Start loop to manage timed effects
function ItemManager:startEffectLoop()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = tick()
			
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
	
	-- ใช้ false แทน nil เพื่อให้ client รู้ว่า item หาย
	local itemInfo: any = false
	if data.currentItem then
		local itemDef = ItemTypes.getItem(data.currentItem)
		if itemDef then
			itemInfo = {
				id = itemDef.id,
				name = itemDef.name,
				description = itemDef.description, -- เพิ่ม description
				icon = itemDef.icon,
				rarity = itemDef.rarity,
				rarityColor = {ItemTypes.getRarityColor(itemDef.rarity):ToHex()},
			}
		end
	end
	
	self.updateScoreRemote:FireClient(player, {
		currentItem = itemInfo, -- false = ไม่มี item, table = มี item
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
		currentItem = nil,
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
