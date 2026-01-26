-- ItemManager: จัดการระบบ Push Item

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ItemManager = {}
ItemManager.__index = ItemManager

export type PlayerItemData = {
	pushCount: number,
	lastPushTime: number,
}

function ItemManager.new(currencyManager: any?)
	local self = setmetatable({}, ItemManager)
	
	self.playerItems = {} :: {[Player]: PlayerItemData}
	self.itemPickups = {} :: {Part}
	self.pickupConnections = {} :: {[Part]: RBXScriptConnection}
	self.currencyManager = currencyManager -- Reference to CurrencyManager
	
	-- Remotes
	self.useItemRemote = ReplicatedStorage.Remotes.UseItem
	
	-- Listen for item use
	self.useItemRemote.OnServerEvent:Connect(function(player)
		self:usePushItem(player)
	end)
	
	return self
end

-- Initialize player items
function ItemManager:initPlayer(player: Player)
	self.playerItems[player] = {
		pushCount = Config.PushItem.StartingAmount,
		lastPushTime = 0,
	}
end

-- Use push item
function ItemManager:usePushItem(player: Player)
	local itemData = self.playerItems[player]
	if not itemData then return end
	
	-- Check cooldown
	local now = tick()
	if now - itemData.lastPushTime < Config.PushItem.Cooldown then
		local remaining = Config.PushItem.Cooldown - (now - itemData.lastPushTime)
		print("[ItemManager] Push on cooldown for", player.Name, "- Remaining:", math.ceil(remaining), "s")
		return
	end
	
	-- Check if has items
	if itemData.pushCount <= 0 then
		print("[ItemManager]", player.Name, "has no push items")
		return
	end
	
	-- Get player character
	local character = player.Character
	if not character then return end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	
	-- Find target in range
	local target = self:findTargetInRange(player, humanoidRootPart)
	
	if target then
		-- Apply push force
		self:applyPushForce(humanoidRootPart, target)
		
		-- Use item
		itemData.pushCount = itemData.pushCount - 1
		itemData.lastPushTime = now
		
		print("[ItemManager]", player.Name, "pushed", target.Parent.Name, "- Remaining items:", itemData.pushCount)
		
		-- Update client
		self:sendItemUpdate(player)
	else
		print("[ItemManager]", player.Name, "no target in range")
	end
end

-- Find target in range
function ItemManager:findTargetInRange(player: Player, fromPart: Part): Part?
	local lookDirection = fromPart.CFrame.LookVector
	local origin = fromPart.Position
	
	local closestTarget: Part? = nil
	local closestDistance = Config.PushItem.Range
	
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			local otherCharacter = otherPlayer.Character
			if otherCharacter then
				local otherHRP = otherCharacter:FindFirstChild("HumanoidRootPart")
				if otherHRP then
					local toTarget = otherHRP.Position - origin
					local distance = toTarget.Magnitude
					
					if distance <= Config.PushItem.Range then
						-- Check if target is in front (within 90 degree cone)
						local dotProduct = lookDirection:Dot(toTarget.Unit)
						if dotProduct > 0.5 then -- ~60 degree cone
							if distance < closestDistance then
								closestDistance = distance
								closestTarget = otherHRP
							end
						end
					end
				end
			end
		end
	end
	
	return closestTarget
end

-- Apply push force to target
function ItemManager:applyPushForce(from: Part, target: Part)
	local direction = (target.Position - from.Position).Unit
	direction = Vector3.new(direction.X, 0.3, direction.Z).Unit -- Add upward push
	
	local force = direction * Config.PushItem.Force
	
	-- Create BodyVelocity for instant push
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = force
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.Parent = target
	
	-- Remove after short time
	task.delay(0.3, function()
		if bodyVelocity.Parent then
			bodyVelocity:Destroy()
		end
	end)
	
	-- Visual effect
	self:createPushEffect(from.Position, target.Position)
end

-- Create push visual effect
function ItemManager:createPushEffect(fromPos: Vector3, toPos: Vector3)
	local midPoint = (fromPos + toPos) / 2
	local distance = (toPos - fromPos).Magnitude
	
	local effect = Instance.new("Part")
	effect.Name = "PushEffect"
	effect.Anchored = true
	effect.CanCollide = false
	effect.Size = Vector3.new(0.5, 0.5, distance)
	effect.CFrame = CFrame.lookAt(fromPos, toPos) * CFrame.new(0, 0, -distance / 2)
	effect.Material = Enum.Material.Neon
	effect.Color = Color3.fromRGB(255, 100, 100)
	effect.Transparency = 0.3
	effect.Parent = workspace
	
	-- Fade out
	task.spawn(function()
		for i = 1, 10 do
			effect.Transparency = 0.3 + (0.7 * i / 10)
			task.wait(0.03)
		end
		effect:Destroy()
	end)
end

-- Add push item
function ItemManager:addPushItem(player: Player, amount: number?)
	local itemData = self.playerItems[player]
	if not itemData then return end
	
	amount = amount or 1
	itemData.pushCount = math.min(itemData.pushCount + amount, Config.PushItem.MaxAmount)
	
	print("[ItemManager]", player.Name, "picked up push item - Total:", itemData.pushCount)
	
	self:sendItemUpdate(player)
end

-- Get push count
function ItemManager:getPushCount(player: Player): number
	local itemData = self.playerItems[player]
	return itemData and itemData.pushCount or 0
end

-- Get cooldown remaining
function ItemManager:getCooldownRemaining(player: Player): number
	local itemData = self.playerItems[player]
	if not itemData then return 0 end
	
	local elapsed = tick() - itemData.lastPushTime
	return math.max(0, Config.PushItem.Cooldown - elapsed)
end

-- Send item update to client
function ItemManager:sendItemUpdate(player: Player)
	local itemData = self.playerItems[player]
	if not itemData then return end
	
	-- ใช้ RemoteEvent สำหรับ item update (reuse UpdateScore event)
	ReplicatedStorage.Remotes.UpdateScore:FireClient(player, {
		pushCount = itemData.pushCount,
		pushCooldown = self:getCooldownRemaining(player),
	})
end

-- Setup item pickups
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
	if not pickup.Parent then return end -- Already collected
	if pickup:GetAttribute("IsCollected") then return end -- Prevent double collection
	
	-- Mark as collected
	pickup:SetAttribute("IsCollected", true)
	
	-- Check if it's a coin or push item
	local isCoin = pickup:GetAttribute("IsCoin") == true
	
	if isCoin then
		-- Collect coin - give currency
		if self.currencyManager then
			self.currencyManager:addCurrency(player, Config.Currency.PerCoin)
			print("[ItemManager]", player.Name, "collected coin - Gained", Config.Currency.PerCoin, "currency")
		end
	else
		-- Collect push item
		self:addPushItem(player, 1)
	end
	
	-- Temporarily hide pickup and all its children
	pickup.Transparency = 1
	pickup.CanCollide = false
	
	-- ซ่อน children ด้วย (เช่น Mesh, ParticleEmitter)
	for _, child in pairs(pickup:GetDescendants()) do
		if child:IsA("BasePart") then
			child.Transparency = 1
		elseif child:IsA("ParticleEmitter") then
			child.Enabled = false
		elseif child:IsA("Light") then
			child.Enabled = false
		end
	end
	
	-- Respawn after delay
	task.delay(15, function()
		if pickup.Parent then
			-- Show pickup again
			pickup.Transparency = 0
			pickup.CanCollide = false
			pickup:SetAttribute("IsCollected", false)
			
			-- แสดง children กลับมา
			for _, child in pairs(pickup:GetDescendants()) do
				if child:IsA("BasePart") then
					child.Transparency = 0
				elseif child:IsA("ParticleEmitter") then
					child.Enabled = true
				elseif child:IsA("Light") then
					child.Enabled = true
				end
			end
		end
	end)
end

-- Reset player items
function ItemManager:resetPlayer(player: Player)
	self.playerItems[player] = {
		pushCount = Config.PushItem.StartingAmount,
		lastPushTime = 0,
	}
	self:sendItemUpdate(player)
end

-- Remove player
function ItemManager:removePlayer(player: Player)
	self.playerItems[player] = nil
end

return ItemManager
