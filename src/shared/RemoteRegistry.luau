-- RemoteRegistry: Centralized access to RemoteEvents
-- Usage: RemoteRegistry.get("UseItem") instead of ReplicatedStorage.Remotes.UseItem

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(ReplicatedStorage.Shared.Logger)

local RemoteRegistry = {}
local cache = {} :: {[string]: RemoteEvent}

local remotesFolder: Folder? = nil

local function getRemotesFolder(): Folder?
	if not remotesFolder then
		remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
		if not remotesFolder then
			Logger.warn("RemoteRegistry", "Remotes folder not found in ReplicatedStorage")
		end
	end
	return remotesFolder
end

-- Get a RemoteEvent by name (cached, with WaitForChild fallback)
function RemoteRegistry.get(name: string): RemoteEvent?
	if cache[name] then
		return cache[name]
	end

	local folder = getRemotesFolder()
	if not folder then return nil end

	local remote = folder:FindFirstChild(name)
	if not remote then
		-- Fallback: WaitForChild with timeout
		remote = folder:WaitForChild(name, 5)
		if not remote then
			Logger.warn("RemoteRegistry", "Remote not found:", name)
			return nil
		end
	end

	cache[name] = remote :: RemoteEvent
	return remote :: RemoteEvent
end

-- Check if a remote exists without waiting
function RemoteRegistry.has(name: string): boolean
	if cache[name] then return true end

	local folder = getRemotesFolder()
	if not folder then return false end

	return folder:FindFirstChild(name) ~= nil
end

return RemoteRegistry
