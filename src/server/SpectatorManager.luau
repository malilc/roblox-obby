-- SpectatorManager: จัดการระบบ spectator mode

local Logger = require(game:GetService("ReplicatedStorage").Shared.Logger)

local SpectatorManager = {}
SpectatorManager.__index = SpectatorManager

export type SpectatorDeps = {
	getPlayerState: (player: Player) -> string?,
	setPlayerState: (player: Player, state: string) -> (),
	teleportToLobby: (player: Player) -> (),
	setTeleportingFlag: (player: Player, value: boolean?) -> (),
	getTeleportFlagClearDelay: () -> number,
}

function SpectatorManager.new(deps: SpectatorDeps)
	local self = setmetatable({}, SpectatorManager)
	self.deps = deps
	return self
end

function SpectatorManager:onPlayerSpectate(player: Player)
	local state = self.deps.getPlayerState(player)
	if state ~= "Finished" then return end

	self.deps.setPlayerState(player, "Spectating")

	-- Hide player's character
	local character = player.Character
	if character then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			humanoidRootPart.Anchored = true
		end
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 1
				part.CanCollide = false
			elseif part:IsA("Decal") or part:IsA("Texture") then
				part.Transparency = 1
			end
		end
	end

	Logger.debug("SpectatorManager", player.Name, "started spectating")
end

function SpectatorManager:onSpectatorLeave(player: Player)
	local state = self.deps.getPlayerState(player)
	if state ~= "Spectating" and state ~= "Finished" then return end

	-- Restore character visibility
	local character = player.Character
	if character then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			humanoidRootPart.Anchored = false
		end
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				if part.Name == "HumanoidRootPart" then
					part.Transparency = 1 -- HRP is normally transparent
				else
					part.Transparency = 0
				end
				part.CanCollide = true
			elseif part:IsA("Decal") or part:IsA("Texture") then
				part.Transparency = 0
			end
		end
	end

	-- Teleport to lobby
	self.deps.teleportToLobby(player)
	local delay = self.deps.getTeleportFlagClearDelay()
	task.delay(delay, function()
		self.deps.setTeleportingFlag(player, nil)
	end)

	Logger.debug("SpectatorManager", player.Name, "left spectator mode")
end

return SpectatorManager
