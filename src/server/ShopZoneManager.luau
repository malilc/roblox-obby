-- ShopZoneManager: จัดการ lobby shop zone detection + model placement

local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Logger)

local SHOP_MODEL_ID = 2310029676

local ShopZoneManager = {}
ShopZoneManager.__index = ShopZoneManager

export type ShopZoneDeps = {
	getPlayerState: (player: Player) -> string?,
	showShopRemote: RemoteEvent,
	hideShopRemote: RemoteEvent,
}

function ShopZoneManager.new(deps: ShopZoneDeps)
	local self = setmetatable({}, ShopZoneManager)
	self.deps = deps
	self.playersInShopZone = {} :: {[Player]: boolean}
	return self
end

function ShopZoneManager:setup()
	local lobby = workspace:FindFirstChild("Lobby")
	if not lobby then return end

	local shopZone = lobby:FindFirstChild("ShopZone")
	if not shopZone then return end

	-- Add "SHOP" billboard label
	if not shopZone:FindFirstChild("ShopLabelBillboard") then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "ShopLabelBillboard"
		billboard.Size = UDim2.new(0, 200, 0, 50)
		billboard.StudsOffset = Vector3.new(0, 5, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = shopZone

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = "SHOP"
		label.TextColor3 = Color3.fromRGB(100, 200, 255)
		label.TextStrokeTransparency = 0
		label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
		label.TextSize = 24
		label.Font = Enum.Font.GothamBold
		label.Parent = billboard
	end

	-- Load shop model
	self:loadShopModel(shopZone)

	-- Start zone detection loop
	task.spawn(function()
		while true do
			task.wait(Config.Timing.SelectionZoneInterval)

			for _, player in ipairs(Players:GetPlayers()) do
				local isInZone = self:isPlayerInZone(player, shopZone)
				local wasInZone = self.playersInShopZone[player]

				if isInZone and not wasInZone then
					if self.deps.getPlayerState(player) == "Lobby" then
						self.playersInShopZone[player] = true
						self:onPlayerEnter(player)
					end
				elseif not isInZone and wasInZone then
					self.playersInShopZone[player] = nil
					self:onPlayerLeave(player)
				end
			end
		end
	end)
end

function ShopZoneManager:loadShopModel(shopZone: Part)
	local success, result = pcall(function()
		return InsertService:LoadAsset(SHOP_MODEL_ID)
	end)

	if not success then
		Logger.warn("ShopZoneManager", "InsertService:LoadAsset failed:", tostring(result))
		return
	end

	if not result then
		Logger.warn("ShopZoneManager", "LoadAsset returned nil")
		return
	end

	-- LoadAsset returns a Model container — get the actual asset inside
	local children = result:GetChildren()
	Logger.info("ShopZoneManager", "LoadAsset container has", #children, "children")

	for i, child in ipairs(children) do
		Logger.info("ShopZoneManager", "  Child", i, ":", child.Name, "class:", child.ClassName)
	end

	local model = children[1]
	if not model then
		Logger.warn("ShopZoneManager", "LoadAsset container is empty")
		result:Destroy()
		return
	end

	model.Name = "ShopModel"

	-- Position model at shop zone (floor surface Y=100, raise to sit on top)
	-- Get model bounding box to calculate correct Y offset
	local targetY = 100
	if model:IsA("Model") then
		local orientation, size = model:GetBoundingBox()
		targetY = 100 + size.Y / 2
	elseif model:IsA("BasePart") then
		targetY = 100 + model.Size.Y / 2
	end
	local targetPos = Vector3.new(shopZone.Position.X, targetY, shopZone.Position.Z)

	if model:IsA("Model") then
		-- Use PivotTo for Models (works with or without PrimaryPart)
		model:PivotTo(CFrame.new(targetPos))
		Logger.info("ShopZoneManager", "Positioned Model via PivotTo at", tostring(targetPos))
	elseif model:IsA("BasePart") then
		model.Position = targetPos
		Logger.info("ShopZoneManager", "Positioned BasePart at", tostring(targetPos))
	end

	model.Parent = workspace:FindFirstChild("Lobby")
	Logger.info("ShopZoneManager", "Shop model loaded and placed successfully")

	result:Destroy()
end

-- Check if player is inside the shop zone bounding box
function ShopZoneManager:isPlayerInZone(player: Player, zone: Part): boolean
	local character = player.Character
	if not character then return false end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return false end

	local playerPos = humanoidRootPart.Position
	local zonePos = zone.Position
	local zoneSize = zone.Size

	local halfSize = zoneSize / 2
	local minBound = zonePos - halfSize
	local maxBound = zonePos + halfSize

	return playerPos.X >= minBound.X and playerPos.X <= maxBound.X
		and playerPos.Y >= minBound.Y - 5 and playerPos.Y <= maxBound.Y + 10
		and playerPos.Z >= minBound.Z and playerPos.Z <= maxBound.Z
end

-- Player entered shop zone
function ShopZoneManager:onPlayerEnter(player: Player)
	self.deps.showShopRemote:FireClient(player)
	Logger.debug("ShopZoneManager", player.Name, "entered shop zone")
end

-- Player left shop zone
function ShopZoneManager:onPlayerLeave(player: Player)
	self.deps.hideShopRemote:FireClient(player)
	Logger.debug("ShopZoneManager", player.Name, "left shop zone")
end

-- Cleanup when player leaves
function ShopZoneManager:removePlayer(player: Player)
	self.playersInShopZone[player] = nil
end

return ShopZoneManager
