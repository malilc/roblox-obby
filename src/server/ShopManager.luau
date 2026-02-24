-- ShopManager: จัดการ Shop purchases + Class Gacha

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ItemTypes = require(ReplicatedStorage.Shared.ItemTypes)
local ClassTypes = require(ReplicatedStorage.Shared.ClassTypes)
local Logger = require(ReplicatedStorage.Shared.Logger)

local ShopManager = {}
ShopManager.__index = ShopManager

function ShopManager.new(currencyManager, itemManager, classManager, gameManager)
	local self = setmetatable({}, ShopManager)
	self.currencyManager = currencyManager
	self.itemManager = itemManager
	self.classManager = classManager
	self.gameManager = gameManager
	self.lastRequestTime = {} :: {[Player]: number}

	-- Remotes
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	self.buyShopItemRemote = remotes:WaitForChild("BuyShopItem")
	self.gachaClassPullRemote = remotes:WaitForChild("GachaClassPull")
	self.shopUpdateRemote = remotes:WaitForChild("ShopUpdate")
	self.showShopRemote = remotes:WaitForChild("ShowShop")

	self:setupRemotes()

	Logger.info("ShopManager", "Initialized")
	return self
end

function ShopManager:setupRemotes()
	self.buyShopItemRemote.OnServerEvent:Connect(function(player, data)
		self:handleBuyItem(player, data)
	end)

	self.gachaClassPullRemote.OnServerEvent:Connect(function(player)
		self:handleGachaPull(player)
	end)

	-- Send state sync when shop opens
	self.showShopRemote.OnServerEvent:Connect(function(player)
		self:sendStateSync(player)
	end)
end

-- Rate limiting
function ShopManager:isRateLimited(player: Player): boolean
	local now = os.clock()
	local lastTime = self.lastRequestTime[player]
	if lastTime and (now - lastTime) < Config.Shop.RequestCooldown then
		return true
	end
	self.lastRequestTime[player] = now
	return false
end

-- Send error to client
function ShopManager:sendError(player: Player, reason: string)
	self.shopUpdateRemote:FireClient(player, {
		type = "error",
		reason = reason,
	})
end

-- ========== ITEM PURCHASE ==========

function ShopManager:handleBuyItem(player: Player, data: any)
	if self:isRateLimited(player) then
		self:sendError(player, "RATE_LIMIT")
		return
	end

	if type(data) ~= "table" or type(data.itemId) ~= "string" then
		self:sendError(player, "INVALID_ITEM")
		return
	end

	-- Check player is in lobby
	local state = self.gameManager.playerStates[player]
	if state ~= "Lobby" then
		self:sendError(player, "NOT_IN_LOBBY")
		return
	end

	-- Validate item
	local itemDef = ItemTypes.getItem(data.itemId)
	if not itemDef then
		self:sendError(player, "INVALID_ITEM")
		return
	end

	-- Get price
	local price = Config.Shop.ItemPrices[itemDef.rarity]
	if not price then
		self:sendError(player, "INVALID_ITEM")
		return
	end

	-- Check currency
	if not self.currencyManager:canAfford(player, price) then
		self:sendError(player, "INSUFFICIENT_FUNDS")
		return
	end

	-- Check empty slot
	local slot = self.itemManager:getFirstEmptySlot(player)
	if not slot then
		self:sendError(player, "NO_EMPTY_SLOT")
		return
	end

	-- Execute purchase
	local spent = self.currencyManager:spendCurrency(player, price, "ShopBuy:" .. data.itemId)
	if not spent then
		self:sendError(player, "INSUFFICIENT_FUNDS")
		return
	end

	local placed = self.itemManager:setItemInSlot(player, slot, data.itemId)
	if not placed then
		-- Refund if item placement failed
		self.currencyManager:addCurrency(player, price)
		self:sendError(player, "NO_EMPTY_SLOT")
		return
	end

	-- Success
	self.shopUpdateRemote:FireClient(player, {
		type = "itemPurchase",
		success = true,
		itemId = data.itemId,
		slot = slot,
		currency = self.currencyManager:getCurrency(player),
	})

	Logger.info("ShopManager", player.Name, "bought", data.itemId, "for", price, "coins")
end

-- ========== CLASS GACHA ==========

function ShopManager:handleGachaPull(player: Player)
	if self:isRateLimited(player) then
		self:sendError(player, "RATE_LIMIT")
		return
	end

	-- Check player is in lobby
	local state = self.gameManager.playerStates[player]
	if state ~= "Lobby" then
		self:sendError(player, "NOT_IN_LOBBY")
		return
	end

	-- Check gems
	local cost = Config.Shop.Gacha.CostGems
	local gems = self.currencyManager:getGems(player)
	if gems < cost then
		self:sendError(player, "INSUFFICIENT_GEMS")
		return
	end

	-- Spend gems
	local spent = self.currencyManager:spendGems(player, cost, "GachaPull")
	if not spent then
		self:sendError(player, "INSUFFICIENT_GEMS")
		return
	end

	-- Roll class
	local classId = self:rollGachaClass()

	-- Check if already unlocked
	local isUnlocked = self.currencyManager:isClassUnlocked(player, classId)

	if not isUnlocked then
		-- New class unlock
		self.currencyManager:unlockClass(player, classId)

		self.shopUpdateRemote:FireClient(player, {
			type = "gachaResult",
			isNew = true,
			classId = classId,
			gems = self.currencyManager:getGems(player),
		})

		-- Also fire ClassUpdate so ClassSelectionUI updates
		self.classManager:sendClassUpdate(player)

		Logger.info("ShopManager", player.Name, "gacha NEW class:", classId)
	else
		-- Duplicate — refund partial gems
		local refund = Config.Shop.Gacha.DuplicateGemsBack
		self.currencyManager:addGems(player, refund, "GachaDuplicateRefund")

		self.shopUpdateRemote:FireClient(player, {
			type = "gachaResult",
			isNew = false,
			classId = classId,
			gemsRefunded = refund,
			gems = self.currencyManager:getGems(player),
		})

		Logger.info("ShopManager", player.Name, "gacha DUPLICATE:", classId, "refunded", refund, "gems")
	end
end

function ShopManager:rollGachaClass(): string
	local weights = Config.Shop.GachaWeights
	local totalWeight = 0
	local pool = {}

	for classId, weight in pairs(weights) do
		totalWeight += weight
		table.insert(pool, { classId = classId, cumulativeWeight = totalWeight })
	end

	local roll = math.random() * totalWeight
	for _, entry in ipairs(pool) do
		if roll <= entry.cumulativeWeight then
			return entry.classId
		end
	end

	return pool[#pool].classId
end

-- ========== STATE SYNC ==========

function ShopManager:sendStateSync(player: Player)
	self.shopUpdateRemote:FireClient(player, {
		type = "stateSync",
		currency = self.currencyManager:getCurrency(player),
		gems = self.currencyManager:getGems(player),
		unlockedClasses = self.currencyManager:getUnlockedClasses(player),
		itemSlots = self.itemManager:getPlayerSlots(player),
	})
end

-- Cleanup when player leaves
function ShopManager:removePlayer(player: Player)
	self.lastRequestTime[player] = nil
end

return ShopManager
