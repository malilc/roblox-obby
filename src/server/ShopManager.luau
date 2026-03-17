-- ShopManager: จัดการ Shop purchases + Class Gacha + Game Pass

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

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
	self.gamePassUpdateRemote = remotes:WaitForChild("GamePassUpdate")
	self.checkGamePassRemote = remotes:WaitForChild("CheckGamePass")

	-- Cache of owned game passes per player
	self.playerGamePasses = {} :: {[Player]: {[string]: boolean}}

	self:setupRemotes()
	self:setupGamePassListeners()
	self:setupTestGamePassRemote()

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

	-- Client requests game pass ownership re-check (after purchase)
	self.checkGamePassRemote.OnServerEvent:Connect(function(player)
		if self:isRateLimited(player) then return end
		self:checkAllGamePasses(player)
		self:sendGamePassUpdate(player)
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

-- ========== GAME PASS ==========

function ShopManager:setupGamePassListeners()
	-- Listen for native Roblox game pass purchase completion
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if not wasPurchased then return end

		-- Find which pass was purchased
		for id, passDef in pairs(Config.GamePasses) do
			if passDef.gamePassId == passId then
				if not self.playerGamePasses[player] then
					self.playerGamePasses[player] = {}
				end
				self.playerGamePasses[player][id] = true
				self:saveGamePassesToProfile(player)
				self:sendGamePassUpdate(player)
				Logger.info("ShopManager", player.Name, "purchased game pass:", id)
				break
			end
		end
	end)
end

function ShopManager:checkAllGamePasses(player: Player)
	if not self.playerGamePasses[player] then
		self.playerGamePasses[player] = {}
	end
	local passes = self.playerGamePasses[player]

	-- Load saved passes from DataStore profile (has priority — includes test toggles)
	self:loadGamePassesFromProfile(player)

	-- Merge real ownership from Roblox API
	-- Only set true if saved state is nil (not explicitly set)
	-- saved true = owned, saved false = explicitly disabled, nil = use API
	for id, passDef in pairs(Config.GamePasses) do
		if passDef.gamePassId ~= 0 and passes[id] == nil then
			local success, hasPass = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passDef.gamePassId)
			end)
			if success and hasPass then
				passes[id] = true
			end
		end
	end
end

function ShopManager:hasGamePass(player: Player, passId: string): boolean
	local passes = self.playerGamePasses[player]
	if not passes then return false end
	return passes[passId] == true
end

function ShopManager:sendGamePassUpdate(player: Player)
	self.gamePassUpdateRemote:FireClient(player, {
		ownedPasses = self.playerGamePasses[player] or {},
	})
end

-- Save gamepass ownership to CurrencyManager profile (immediate save)
function ShopManager:saveGamePassesToProfile(player: Player)
	local passes = self.playerGamePasses[player]
	if not passes or not self.currencyManager then return end

	local playerData = self.currencyManager.playerData[player]
	if not playerData then return end

	-- Copy table (not reference) so ShopManager cleanup doesn't affect saved data
	local copy = {}
	for id, owned in pairs(passes) do
		copy[id] = owned
	end
	playerData.ownedGamePasses = copy

	-- Save immediately (not just pendingSaves — ensures data persists even if Studio stops)
	task.spawn(function()
		self.currencyManager:savePlayerData(player)
	end)
end

-- Load saved gamepass ownership from CurrencyManager profile
function ShopManager:loadGamePassesFromProfile(player: Player)
	if not self.currencyManager then return end

	local playerData = self.currencyManager.playerData[player]
	if not playerData or not playerData.ownedGamePasses then return end

	if not self.playerGamePasses[player] then
		self.playerGamePasses[player] = {}
	end

	-- Load saved state: true = owned, false = explicitly disabled
	for id, value in pairs(playerData.ownedGamePasses) do
		if Config.GamePasses[id] then
			self.playerGamePasses[player][id] = value
		end
	end
end

-- ========== TEST GAMEPASS TOGGLE (Debug only) ==========

function ShopManager:setupTestGamePassRemote()
	if not Config.Debug or not Config.Debug.Enabled then return end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local toggleRemote = remotes:FindFirstChild("ToggleTestGamePass")
	if not toggleRemote then return end

	toggleRemote.OnServerEvent:Connect(function(player, data)
		if not Config.Debug or not Config.Debug.ItemTesting then return end
		if type(data) ~= "table" or type(data.passId) ~= "string" then return end

		self:toggleTestGamePass(player, data.passId, data.enabled)
	end)

	Logger.info("ShopManager", "ToggleTestGamePass remote initialized for testing")
end

function ShopManager:toggleTestGamePass(player: Player, passId: string, enabled: boolean)
	-- Validate passId exists in Config
	if not Config.GamePasses[passId] then
		Logger.warn("ShopManager", "Invalid test gamepass:", passId)
		return
	end

	if not self.playerGamePasses[player] then
		self.playerGamePasses[player] = {}
	end

	self.playerGamePasses[player][passId] = enabled

	-- Save to DataStore
	self:saveGamePassesToProfile(player)

	-- Send updated state to client
	self:sendGamePassUpdate(player)

	-- If ExtraSlot changed, re-send item update so client updates UI
	if passId == "ExtraSlot" and self.itemManager then
		self.itemManager:sendItemUpdate(player)
	end

	-- If VIP changed, re-apply visual effects
	if passId == "VIP" and self.gameManager then
		local character = player.Character
		if character then
			self.gameManager:applyVIPEffects(player, character)
		end
	end

	Logger.info("ShopManager", player.Name, "test gamepass", passId, "=", tostring(enabled))
end

-- ========== STATE SYNC ==========

function ShopManager:sendStateSync(player: Player)
	-- Check game passes on shop open
	self:checkAllGamePasses(player)

	self.shopUpdateRemote:FireClient(player, {
		type = "stateSync",
		currency = self.currencyManager:getCurrency(player),
		gems = self.currencyManager:getGems(player),
		unlockedClasses = self.currencyManager:getUnlockedClasses(player),
		itemSlots = self.itemManager:getPlayerSlots(player),
		ownedGamePasses = self.playerGamePasses[player] or {},
	})
end

-- Cleanup when player leaves
function ShopManager:removePlayer(player: Player)
	self.lastRequestTime[player] = nil
	self.playerGamePasses[player] = nil
end

return ShopManager
