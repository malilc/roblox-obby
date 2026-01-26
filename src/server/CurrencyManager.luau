-- CurrencyManager: จัดการเงินในเกม

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CurrencyManager = {}
CurrencyManager.__index = CurrencyManager

export type PlayerCurrencyData = {
	currency: number,
}

function CurrencyManager.new()
	local self = setmetatable({}, CurrencyManager)
	
	self.playerData = {} :: {[Player]: PlayerCurrencyData}
	
	-- DataStore
	pcall(function()
		self.dataStore = DataStoreService:GetDataStore(Config.DataStore.Name)
	end)
	
	-- Remotes
	self.updateCurrencyRemote = ReplicatedStorage.Remotes.UpdateCurrency
	
	return self
end

-- Initialize player currency
function CurrencyManager:initPlayer(player: Player)
	self.playerData[player] = {
		currency = Config.Currency.StartingAmount,
	}
	
	-- Load from DataStore
	self:loadPlayerData(player)
end

-- Load player currency from DataStore
function CurrencyManager:loadPlayerData(player: Player)
	if not self.dataStore then 
		-- Send update even if no DataStore
		self:sendCurrencyUpdate(player)
		return 
	end
	
	local success, data = pcall(function()
		return self.dataStore:GetAsync("Player_" .. player.UserId)
	end)
	
	if success and data then
		local playerData = self.playerData[player]
		if playerData then
			playerData.currency = data.currency or Config.Currency.StartingAmount
		end
		print("[CurrencyManager] Loaded currency for", player.Name, "- Currency:", playerData.currency)
	else
		print("[CurrencyManager] No saved currency for", player.Name, "- Using starting amount")
	end
	
	-- Update client
	self:sendCurrencyUpdate(player)
end

-- Save player currency to DataStore
function CurrencyManager:savePlayerData(player: Player)
	if not self.dataStore then return end
	
	local playerData = self.playerData[player]
	if not playerData then return end
	
	local success, err = pcall(function()
		-- Get existing data first
		local existingData = self.dataStore:GetAsync("Player_" .. player.UserId) or {}
		existingData.currency = playerData.currency
		self.dataStore:SetAsync("Player_" .. player.UserId, existingData)
	end)
	
	if success then
		print("[CurrencyManager] Saved currency for", player.Name)
	else
		warn("[CurrencyManager] Failed to save currency for", player.Name, ":", err)
	end
end

-- Add currency to player
function CurrencyManager:addCurrency(player: Player, amount: number)
	local playerData = self.playerData[player]
	if not playerData then return end
	
	playerData.currency = playerData.currency + amount
	print("[CurrencyManager]", player.Name, "gained", amount, "currency - Total:", playerData.currency)
	
	-- Save to DataStore (async, don't wait)
	task.spawn(function()
		self:savePlayerData(player)
	end)
	
	-- Update client
	self:sendCurrencyUpdate(player)
end

-- Get player currency
function CurrencyManager:getCurrency(player: Player): number
	local playerData = self.playerData[player]
	return playerData and playerData.currency or 0
end

-- Send currency update to client
function CurrencyManager:sendCurrencyUpdate(player: Player)
	local playerData = self.playerData[player]
	if not playerData then return end
	
	self.updateCurrencyRemote:FireClient(player, {
		currency = playerData.currency,
	})
end

-- Remove player data
function CurrencyManager:removePlayer(player: Player)
	-- Save before removing
	self:savePlayerData(player)
	self.playerData[player] = nil
end

return CurrencyManager
