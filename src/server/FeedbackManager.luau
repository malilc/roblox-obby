-- FeedbackManager: Validate feedback and send to Discord webhook

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Logger)

local FeedbackManager = {}
FeedbackManager.__index = FeedbackManager

local CATEGORY_COLORS = {
	Bug = 0xE74C3C,        -- red
	Suggestion = 0x3498DB,  -- blue
	Other = 0x95A5A6,       -- gray
}

local VALID_CATEGORIES = { Bug = true, Suggestion = true, Other = true }

function FeedbackManager.new()
	local self = setmetatable({}, FeedbackManager)
	self._cooldowns = {} :: {[number]: number} -- UserId -> last send time
	self:_setupRemotes()
	self:_setupCleanup()
	return self
end

function FeedbackManager:_setupRemotes()
	local sendRemote = ReplicatedStorage.Remotes:FindFirstChild("SendFeedback")
	local responseRemote = ReplicatedStorage.Remotes:FindFirstChild("FeedbackResponse")
	if not sendRemote or not responseRemote then
		Logger.warn("FeedbackManager", "SendFeedback or FeedbackResponse remote not found")
		return
	end

	sendRemote.OnServerEvent:Connect(function(player, data)
		self:_handleFeedback(player, data, responseRemote)
	end)
end

function FeedbackManager:_setupCleanup()
	Players.PlayerRemoving:Connect(function(player)
		self._cooldowns[player.UserId] = nil
	end)
end

function FeedbackManager:_handleFeedback(player: Player, data: any, responseRemote: RemoteEvent)
	-- Validate data
	if typeof(data) ~= "table" then
		responseRemote:FireClient(player, { success = false, error = "Invalid data" })
		return
	end

	local category = data.category
	local message = data.message

	if typeof(category) ~= "string" or not VALID_CATEGORIES[category] then
		responseRemote:FireClient(player, { success = false, error = "Invalid category" })
		return
	end

	if typeof(message) ~= "string" then
		responseRemote:FireClient(player, { success = false, error = "Invalid message" })
		return
	end

	-- Trim whitespace
	message = string.match(message, "^%s*(.-)%s*$") or ""

	local maxLen = (Config.Feedback and Config.Feedback.MaxLength) or 500
	if #message == 0 then
		responseRemote:FireClient(player, { success = false, error = "Message cannot be empty" })
		return
	end
	if #message > maxLen then
		responseRemote:FireClient(player, { success = false, error = "Message too long" })
		return
	end

	-- Rate limit
	local cooldownSec = (Config.Feedback and Config.Feedback.CooldownSeconds) or 60
	local now = os.clock()
	local lastSend = self._cooldowns[player.UserId]
	if lastSend and (now - lastSend) < cooldownSec then
		local remaining = math.ceil(cooldownSec - (now - lastSend))
		responseRemote:FireClient(player, { success = false, error = "Please wait " .. remaining .. "s before sending again" })
		return
	end

	-- Record cooldown
	self._cooldowns[player.UserId] = now

	-- Send to Discord webhook (per-category)
	local webhookUrls = Config.Feedback and Config.Feedback.WebhookUrls
	local webhookUrl = webhookUrls and webhookUrls[category]
	if not webhookUrl or webhookUrl == "" then
		Logger.warn("FeedbackManager", "No webhook URL configured")
		responseRemote:FireClient(player, { success = false, error = "Feedback system not configured" })
		return
	end

	local embedColor = CATEGORY_COLORS[category] or 0x95A5A6
	local payload = HttpService:JSONEncode({
		embeds = {
			{
				title = category,
				description = message,
				color = embedColor,
				author = {
					name = player.Name .. " (" .. player.DisplayName .. ")",
				},
				footer = {
					text = "UserId: " .. tostring(player.UserId) .. " | JobId: " .. string.sub(game.JobId, 1, 8),
				},
				timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
			},
		},
	})

	local success, err = pcall(function()
		HttpService:PostAsync(webhookUrl, payload, Enum.HttpContentType.ApplicationJson)
	end)

	if success then
		Logger.info("FeedbackManager", player.Name, "sent feedback:", category)
		responseRemote:FireClient(player, { success = true })
	else
		Logger.warn("FeedbackManager", "Webhook failed:", tostring(err))
		-- Still count as sent to avoid spam retries
		responseRemote:FireClient(player, { success = false, error = "Failed to send, try again later" })
	end
end

return FeedbackManager
