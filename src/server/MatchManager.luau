-- MatchManager: จัดการระบบ Matchmaking และ Race

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MatchManager = {}
MatchManager.__index = MatchManager

export type MatchState = "Waiting" | "Starting" | "Racing" | "Finished"

export type MatchRoom = {
	id: string,
	host: Player,
	players: {Player},
	state: MatchState,
	stageOrder: {number}?,
	startTime: number?,
	timeRemaining: number?,
	finishOrder: {Player},
	playerProgress: {[Player]: {
		currentStage: number,
		distance: number,
		finished: boolean,
		finishTime: number?,
	}},
}

function MatchManager.new(gameManager: any?)
	local self = setmetatable({}, MatchManager)
	
	self.gameManager = gameManager
	self.rooms = {} :: {[string]: MatchRoom}
	self.playerRooms = {} :: {[Player]: string} -- Player -> RoomId mapping
	self.nextRoomId = 1
	
	-- Remotes
	self.createMatchRemote = ReplicatedStorage.Remotes.CreateMatch
	self.joinMatchRemote = ReplicatedStorage.Remotes.JoinMatch
	self.leaveMatchRemote = ReplicatedStorage.Remotes.LeaveMatch
	self.matchUpdateRemote = ReplicatedStorage.Remotes.MatchUpdate
	self.matchStartRemote = ReplicatedStorage.Remotes.MatchStart
	self.matchEndRemote = ReplicatedStorage.Remotes.MatchEnd
	self.raceUpdateRemote = ReplicatedStorage.Remotes.RaceUpdate
	self.timeWarningRemote = ReplicatedStorage.Remotes.TimeWarning
	
	self:setupRemotes()
	
	return self
end

-- Setup remote event handlers
function MatchManager:setupRemotes()
	self.createMatchRemote.OnServerEvent:Connect(function(player, settings)
		self:createRoom(player, settings)
	end)
	
	self.joinMatchRemote.OnServerEvent:Connect(function(player, roomId)
		self:joinRoom(player, roomId)
	end)
	
	self.leaveMatchRemote.OnServerEvent:Connect(function(player)
		self:leaveRoom(player)
	end)
end

-- Generate unique room ID
function MatchManager:generateRoomId(): string
	local id = "ROOM_" .. self.nextRoomId
	self.nextRoomId = self.nextRoomId + 1
	return id
end

-- Create a new match room
function MatchManager:createRoom(host: Player, settings: {stageOrder: {number}?}?): string?
	-- Check if player is already in a room
	if self.playerRooms[host] then
		warn("[MatchManager]", host.Name, "is already in a room")
		return nil
	end
	
	local roomId = self:generateRoomId()
	
	local room: MatchRoom = {
		id = roomId,
		host = host,
		players = {host},
		state = "Waiting",
		stageOrder = settings and settings.stageOrder or nil,
		startTime = nil,
		timeRemaining = Config.Match.TimeLimit,
		finishOrder = {},
		playerProgress = {
			[host] = {
				currentStage = 0,
				distance = 0,
				finished = false,
				finishTime = nil,
			}
		},
	}
	
	self.rooms[roomId] = room
	self.playerRooms[host] = roomId
	
	print("[MatchManager] Room created:", roomId, "by", host.Name)
	
	-- Notify host
	self:broadcastRoomUpdate(room)
	
	-- Auto-start timer for testing mode
	if Config.Match.IsTestingMode then
		self:startWaitTimer(roomId)
	end
	
	return roomId
end

-- Join an existing room
function MatchManager:joinRoom(player: Player, roomId: string): boolean
	-- Check if player is already in a room
	if self.playerRooms[player] then
		warn("[MatchManager]", player.Name, "is already in a room")
		return false
	end
	
	local room = self.rooms[roomId]
	if not room then
		warn("[MatchManager] Room not found:", roomId)
		return false
	end
	
	if room.state ~= "Waiting" then
		warn("[MatchManager] Room", roomId, "is not accepting players")
		return false
	end
	
	if #room.players >= Config.Match.MaxPlayers then
		warn("[MatchManager] Room", roomId, "is full")
		return false
	end
	
	-- Add player to room
	table.insert(room.players, player)
	self.playerRooms[player] = roomId
	room.playerProgress[player] = {
		currentStage = 0,
		distance = 0,
		finished = false,
		finishTime = nil,
	}
	
	print("[MatchManager]", player.Name, "joined room", roomId)
	
	-- Notify all players in room
	self:broadcastRoomUpdate(room)
	
	return true
end

-- Leave current room
function MatchManager:leaveRoom(player: Player)
	local roomId = self.playerRooms[player]
	if not roomId then return end
	
	local room = self.rooms[roomId]
	if not room then
		self.playerRooms[player] = nil
		return
	end
	
	-- Remove player from room
	for i, p in ipairs(room.players) do
		if p == player then
			table.remove(room.players, i)
			break
		end
	end
	
	room.playerProgress[player] = nil
	self.playerRooms[player] = nil
	
	print("[MatchManager]", player.Name, "left room", roomId)
	
	-- If room is empty or host left, close room
	if #room.players == 0 or room.host == player then
		self:closeRoom(roomId)
	else
		-- Notify remaining players
		self:broadcastRoomUpdate(room)
	end
end

-- Close a room
function MatchManager:closeRoom(roomId: string)
	local room = self.rooms[roomId]
	if not room then return end
	
	-- Clear all player mappings
	for _, player in ipairs(room.players) do
		self.playerRooms[player] = nil
	end
	
	self.rooms[roomId] = nil
	print("[MatchManager] Room closed:", roomId)
end

-- Start wait timer
function MatchManager:startWaitTimer(roomId: string)
	local room = self.rooms[roomId]
	if not room then return end
	
	task.spawn(function()
		local waitTime = Config.Match.WaitTime
		
		for i = waitTime, 1, -1 do
			if not self.rooms[roomId] then return end -- Room closed
			if room.state ~= "Waiting" then return end -- Already started
			
			-- Send countdown update
			for _, player in ipairs(room.players) do
				self.matchUpdateRemote:FireClient(player, {
					type = "countdown",
					countdown = i,
					playerCount = #room.players,
					maxPlayers = Config.Match.MaxPlayers,
				})
			end
			
			task.wait(1)
		end
		
		-- Check if we have minimum players
		if room and room.state == "Waiting" and #room.players >= Config.Match.MinPlayers then
			self:startMatch(roomId)
		end
	end)
end

-- Start the match
function MatchManager:startMatch(roomId: string)
	local room = self.rooms[roomId]
	if not room then return end
	if room.state ~= "Waiting" then return end
	
	room.state = "Starting"
	print("[MatchManager] Starting match in room", roomId, "with", #room.players, "players")
	
	-- Notify all players
	for _, player in ipairs(room.players) do
		self.matchStartRemote:FireClient(player, {
			roomId = roomId,
			players = self:getPlayerNames(room.players),
			stageOrder = room.stageOrder,
		})
	end
	
	-- Let GameManager handle the actual game start
	if self.gameManager then
		task.delay(0.5, function()
			room.state = "Racing"
			room.startTime = tick()
			room.timeRemaining = Config.Match.TimeLimit
			
			-- Start race timer
			self:startRaceTimer(roomId)
		end)
	end
end

-- Start race timer (15 minute limit)
function MatchManager:startRaceTimer(roomId: string)
	local room = self.rooms[roomId]
	if not room then return end
	
	task.spawn(function()
		local warningsGiven = {}
		
		while room and room.state == "Racing" do
			if not self.rooms[roomId] then break end
			
			local elapsed = tick() - (room.startTime or tick())
			room.timeRemaining = math.max(0, Config.Match.TimeLimit - elapsed)
			
			-- Check for time warnings
			for _, warningTime in ipairs(Config.Match.TimeWarnings) do
				if room.timeRemaining <= warningTime and not warningsGiven[warningTime] then
					warningsGiven[warningTime] = true
					self:sendTimeWarning(room, warningTime)
				end
			end
			
			-- Broadcast race update every second
			self:broadcastRaceUpdate(room)
			
			-- Time's up
			if room.timeRemaining <= 0 then
				self:endMatch(roomId, "timeout")
				break
			end
			
			task.wait(1)
		end
	end)
end

-- Send time warning to all players
function MatchManager:sendTimeWarning(room: MatchRoom, secondsLeft: number)
	local message = ""
	if secondsLeft >= 60 then
		message = string.format("%d minute%s remaining!", secondsLeft / 60, secondsLeft >= 120 and "s" or "")
	else
		message = string.format("%d seconds remaining!", secondsLeft)
	end
	
	for _, player in ipairs(room.players) do
		self.timeWarningRemote:FireClient(player, {
			secondsLeft = secondsLeft,
			message = message,
			isCritical = secondsLeft <= 30,
		})
	end
	
	print("[MatchManager] Time warning:", message)
end

-- Broadcast room update to all players
function MatchManager:broadcastRoomUpdate(room: MatchRoom)
	local playerNames = self:getPlayerNames(room.players)
	
	for _, player in ipairs(room.players) do
		self.matchUpdateRemote:FireClient(player, {
			type = "roomUpdate",
			roomId = room.id,
			hostName = room.host.Name,
			players = playerNames,
			playerCount = #room.players,
			maxPlayers = Config.Match.MaxPlayers,
			state = room.state,
		})
	end
end

-- Broadcast race update (rankings, time, etc.)
function MatchManager:broadcastRaceUpdate(room: MatchRoom)
	local rankings = self:calculateRankings(room)
	
	for _, player in ipairs(room.players) do
		local playerRank = 1
		for i, rankedPlayer in ipairs(rankings) do
			if rankedPlayer == player then
				playerRank = i
				break
			end
		end
		
		self.raceUpdateRemote:FireClient(player, {
			timeRemaining = room.timeRemaining,
			rankings = self:getPlayerNames(rankings),
			yourRank = playerRank,
			totalPlayers = #room.players,
			finishedCount = #room.finishOrder,
		})
	end
end

-- Calculate current rankings
function MatchManager:calculateRankings(room: MatchRoom): {Player}
	local rankings = {}
	
	-- First add finished players in order
	for _, player in ipairs(room.finishOrder) do
		table.insert(rankings, player)
	end
	
	-- Then sort unfinished players by progress
	local unfinished = {}
	for _, player in ipairs(room.players) do
		local progress = room.playerProgress[player]
		if progress and not progress.finished then
			table.insert(unfinished, player)
		end
	end
	
	table.sort(unfinished, function(a, b)
		local progressA = room.playerProgress[a]
		local progressB = room.playerProgress[b]
		
		-- Compare by stage first, then by distance
		if progressA.currentStage ~= progressB.currentStage then
			return progressA.currentStage > progressB.currentStage
		end
		return progressA.distance > progressB.distance
	end)
	
	for _, player in ipairs(unfinished) do
		table.insert(rankings, player)
	end
	
	return rankings
end

-- Update player progress (called by GameManager)
function MatchManager:updatePlayerProgress(player: Player, stage: number, distance: number)
	local roomId = self.playerRooms[player]
	if not roomId then return end
	
	local room = self.rooms[roomId]
	if not room then return end
	
	local progress = room.playerProgress[player]
	if progress then
		progress.currentStage = stage
		progress.distance = distance
	end
end

-- Player finished (called by GameManager)
function MatchManager:playerFinished(player: Player)
	local roomId = self.playerRooms[player]
	if not roomId then return end
	
	local room = self.rooms[roomId]
	if not room then return end
	if room.state ~= "Racing" then return end
	
	local progress = room.playerProgress[player]
	if progress and not progress.finished then
		progress.finished = true
		progress.finishTime = tick() - (room.startTime or tick())
		table.insert(room.finishOrder, player)
		
		local position = #room.finishOrder
		print("[MatchManager]", player.Name, "finished in position", position)
		
		-- Check if all players finished
		if #room.finishOrder >= #room.players then
			self:endMatch(roomId, "allFinished")
		end
	end
end

-- End the match
function MatchManager:endMatch(roomId: string, reason: string)
	local room = self.rooms[roomId]
	if not room then return end
	if room.state == "Finished" then return end
	
	room.state = "Finished"
	print("[MatchManager] Match ended:", roomId, "- Reason:", reason)
	
	-- Calculate final rankings
	local rankings = self:calculateRankings(room)
	local results = {}
	
	for i, player in ipairs(rankings) do
		local progress = room.playerProgress[player]
		table.insert(results, {
			playerName = player.Name,
			position = i,
			finished = progress and progress.finished or false,
			finishTime = progress and progress.finishTime,
			stage = progress and progress.currentStage or 0,
		})
	end
	
	-- Send results to all players
	for _, player in ipairs(room.players) do
		self.matchEndRemote:FireClient(player, {
			reason = reason,
			results = results,
			winner = rankings[1] and rankings[1].Name or nil,
		})
	end
	
	-- Clean up room after delay
	task.delay(10, function()
		self:closeRoom(roomId)
	end)
end

-- Get player names array
function MatchManager:getPlayerNames(players: {Player}): {string}
	local names = {}
	for _, player in ipairs(players) do
		table.insert(names, player.Name)
	end
	return names
end

-- Get room for player
function MatchManager:getPlayerRoom(player: Player): MatchRoom?
	local roomId = self.playerRooms[player]
	if roomId then
		return self.rooms[roomId]
	end
	return nil
end

-- Get all active rooms
function MatchManager:getActiveRooms(): {MatchRoom}
	local activeRooms = {}
	for _, room in pairs(self.rooms) do
		if room.state == "Waiting" then
			table.insert(activeRooms, room)
		end
	end
	return activeRooms
end

-- Check if player is in a match
function MatchManager:isPlayerInMatch(player: Player): boolean
	return self.playerRooms[player] ~= nil
end

-- Remove player (when they leave the game)
function MatchManager:removePlayer(player: Player)
	self:leaveRoom(player)
end

return MatchManager
