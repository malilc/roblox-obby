-- DataStoreHelper: Centralized DataStore utilities with retry logic
-- Provides consistent error handling, retry, and data operations

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Logger)

local DataStoreHelper = {}

local MAX_RETRIES = 3
local RETRY_DELAY_BASE = 1 -- seconds (exponential backoff: 1, 2, 4)

-- Schema version for future migration support
local SCHEMA_VERSION = 1

-- Cached DataStore instances
local datastores = {} :: {[string]: DataStore}
local orderedDatastores = {} :: {[string]: OrderedDataStore}

-- Get or create a DataStore (cached)
function DataStoreHelper.getDataStore(name: string): DataStore?
	if datastores[name] then
		return datastores[name]
	end

	local success, store = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)

	if success and store then
		datastores[name] = store
		return store
	end

	Logger.warn("DataStoreHelper", "Failed to get DataStore:", name)
	return nil
end

-- Get or create an OrderedDataStore (cached)
function DataStoreHelper.getOrderedDataStore(name: string): OrderedDataStore?
	if orderedDatastores[name] then
		return orderedDatastores[name]
	end

	local success, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)

	if success and store then
		orderedDatastores[name] = store
		return store
	end

	Logger.warn("DataStoreHelper", "Failed to get OrderedDataStore:", name)
	return nil
end

-- Load data with retry logic
function DataStoreHelper.loadAsync(storeName: string, key: string): (boolean, any?)
	local store = DataStoreHelper.getDataStore(storeName)
	if not store then
		return false, nil
	end

	for attempt = 1, MAX_RETRIES do
		local success, data = pcall(function()
			return store:GetAsync(key)
		end)

		if success then
			-- Add schema version check
			if type(data) == "table" and not data._schemaVersion then
				data._schemaVersion = SCHEMA_VERSION
			end
			return true, data
		end

		Logger.warn("DataStoreHelper", "Load attempt", attempt, "failed for key:", key, "-", data)

		if attempt < MAX_RETRIES then
			task.wait(RETRY_DELAY_BASE * (2 ^ (attempt - 1)))
		end
	end

	Logger.warn("DataStoreHelper", "All load attempts failed for key:", key)
	return false, nil
end

-- Save data with retry logic (using UpdateAsync for atomic merge)
function DataStoreHelper.saveAsync(storeName: string, key: string, updateFn: (any) -> any): boolean
	local store = DataStoreHelper.getDataStore(storeName)
	if not store then
		return false
	end

	for attempt = 1, MAX_RETRIES do
		local success, err = pcall(function()
			store:UpdateAsync(key, function(existingData)
				if type(existingData) ~= "table" then
					existingData = {}
				end
				existingData._schemaVersion = SCHEMA_VERSION
				return updateFn(existingData)
			end)
		end)

		if success then
			return true
		end

		Logger.warn("DataStoreHelper", "Save attempt", attempt, "failed for key:", key, "-", err)

		if attempt < MAX_RETRIES then
			task.wait(RETRY_DELAY_BASE * (2 ^ (attempt - 1)))
		end
	end

	Logger.warn("DataStoreHelper", "All save attempts failed for key:", key)
	return false
end

-- Update an OrderedDataStore entry with retry
function DataStoreHelper.updateOrderedAsync(storeName: string, key: string, updateFn: (any) -> any): boolean
	local store = DataStoreHelper.getOrderedDataStore(storeName)
	if not store then
		return false
	end

	for attempt = 1, MAX_RETRIES do
		local success, err = pcall(function()
			store:UpdateAsync(key, updateFn)
		end)

		if success then
			return true
		end

		Logger.warn("DataStoreHelper", "OrderedDataStore update attempt", attempt, "failed for key:", key, "-", err)

		if attempt < MAX_RETRIES then
			task.wait(RETRY_DELAY_BASE * (2 ^ (attempt - 1)))
		end
	end

	return false
end

-- Get sorted data from OrderedDataStore with retry
function DataStoreHelper.getSortedAsync(storeName: string, ascending: boolean, pageSize: number): (boolean, any?)
	local store = DataStoreHelper.getOrderedDataStore(storeName)
	if not store then
		return false, nil
	end

	for attempt = 1, MAX_RETRIES do
		local success, pages = pcall(function()
			return store:GetSortedAsync(ascending, pageSize)
		end)

		if success then
			return true, pages
		end

		Logger.warn("DataStoreHelper", "GetSortedAsync attempt", attempt, "failed -", pages)

		if attempt < MAX_RETRIES then
			task.wait(RETRY_DELAY_BASE * (2 ^ (attempt - 1)))
		end
	end

	return false, nil
end

-- Generate player data key
function DataStoreHelper.playerKey(player: Player): string
	return "Player_" .. player.UserId
end

-- Get the current schema version
function DataStoreHelper.getSchemaVersion(): number
	return SCHEMA_VERSION
end

return DataStoreHelper
