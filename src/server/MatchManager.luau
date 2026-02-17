-- MatchManager: จัดการระบบ Matchmaking และ Race

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Logger)

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
	-- Stage voting
	stageVotes: {[Player]: {number}},  -- Each player's stage vote
	selectedStageOrder: {number}?,      -- Final selected stage order after voting
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
	
	-- Stage voting remotes
	self.voteStagesRemote = ReplicatedStorage.Remotes.VoteStages
	self.stageVoteUpdateRemote = ReplicatedStorage.Remotes.StageVoteUpdate
	
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
	
	-- Stage voting
	self.voteStagesRemote.OnServerEvent:Connect(function(player, stageOrder)
		self:handleStageVote(player, stageOrder)
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
		Logger.warn("MatchManager", host.Name, "is already in a room")
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
		stageVotes = {},
		selectedStageOrder = nil,
	}
	
	self.rooms[roomId] = room
	self.playerRooms[host] = roomId
	
	Logger.info("MatchManager", "Room created:", roomId, "by", host.Name)
	
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
		Logger.warn("MatchManager", player.Name, "is already in a room")
		return false
	end
	
	local room = self.rooms[roomId]
	if not room then
		Logger.warn("MatchManager", "Room not found:", roomId)
		return false
	end
	
	if room.state ~= "Waiting" then
		Logger.warn("MatchManager", "Room", roomId, "is not accepting players")
		return false
	end
	
	if #room.players >= Config.Match.MaxPlayers then
		Logger.warn("MatchManager", "Room", roomId, "is full")
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
	
	Logger.debug("MatchManager", player.Name, "joined room", roomId)
	
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
	
	Logger.debug("MatchManager", player.Name, "left room", roomId)
	
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

	-- Clean up match touch connections in GameManager
	if self.gameManager and self.gameManager.disconnectMatchConnections then
		self.gameManager:disconnectMatchConnections(roomId)
	end

	Logger.info("MatchManager", "Room closed:", roomId)
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
	Logger.info("MatchManager", "Starting match in room", roomId, "with", #room.players, "players")
	
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
			room.startTime = os.clock()
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
			
			local elapsed = os.clock() - (room.startTime or os.clock())
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
	
	Logger.debug("MatchManager", "Time warning:", message)
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
		
		-- Build detailed ranking info for spectator support
		local rankingDetails = {}
		for i, rankedPlayer in ipairs(rankings) do
			local progress = room.playerProgress[rankedPlayer]
			table.insert(rankingDetails, {
				playerName = rankedPlayer.Name,
				position = i,
				finished = progress and progress.finished or false,
				finishTime = progress and progress.finishTime,
				stage = progress and progress.currentStage or 0,
			})
		end

		self.raceUpdateRemote:FireClient(player, {
			timeRemaining = room.timeRemaining,
			rankings = rankingDetails,
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
		progress.finishTime = os.clock() - (room.startTime or os.clock())
		table.insert(room.finishOrder, player)
		
		local position = #room.finishOrder
		Logger.debug("MatchManager", player.Name, "finished in position", position)
		
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
	Logger.info("MatchManager", "Match ended:", roomId, "- Reason:", reason)
	
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
	
	-- Teleport spectating/finished players back to lobby, then clean up
	task.delay(8, function()
		if self.gameManager then
			for _, player in ipairs(room.players) do
				local state = self.gameManager.playerStates[player]
				if state == "Spectating" or state == "Finished" then
					self.gameManager:onSpectatorLeave(player)
				end
			end
		end
	end)

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

-- Get room by ID
function MatchManager:getRoom(roomId: string): MatchRoom?
	return self.rooms[roomId]
end

-- Remove player (when they leave the game)
function MatchManager:removePlayer(player: Player)
	self:leaveRoom(player)
end

-- ============================================
-- STAGE VOTING SYSTEM
-- ============================================

-- Handle stage vote from player
function MatchManager:handleStageVote(player: Player, stageOrder: {number})
	local roomId = self.playerRooms[player]
	if not roomId then return end
	
	local room = self.rooms[roomId]
	if not room or room.state ~= "Waiting" then return end
	
	-- Validate stage order
	if type(stageOrder) ~= "table" or #stageOrder == 0 or #stageOrder > Config.Stages.Count then
		return
	end
	
	-- Validate each stage number
	local seen = {}
	for _, stageNum in ipairs(stageOrder) do
		if type(stageNum) ~= "number" or stageNum < 1 or stageNum > Config.Stages.Count then
			return
		end
		if seen[stageNum] then return end -- duplicate
		seen[stageNum] = true
	end
	
	-- Store vote
	room.stageVotes[player] = stageOrder
	
	Logger.debug("MatchManager", player.Name, "voted for stages:", table.concat(stageOrder, ", "))
	
	-- Broadcast vote update to all players
	self:broadcastStageVoteUpdate(room)
end

-- Broadcast stage vote update to all players
function MatchManager:broadcastStageVoteUpdate(room: MatchRoom)
	local voteData = {}
	for _, player in ipairs(room.players) do
		local vote = room.stageVotes[player]
		if vote then
			table.insert(voteData, {
				playerName = player.Name,
				stageOrder = vote,
			})
		end
	end
	
	for _, player in ipairs(room.players) do
		self.stageVoteUpdateRemote:FireClient(player, {
			type = "voteUpdate",
			votes = voteData,
			playerCount = #room.players,
			votedCount = #voteData,
		})
	end
end

-- Calculate final stage order from votes (weighted random)
function MatchManager:calculateFinalStageOrder(room: MatchRoom): {number}
	-- If no votes, shuffle all stages
	if #table.clear({}) == 0 and next(room.stageVotes) == nil then
		return self:shuffleAllStages()
	end
	
	-- Count votes for each stage
	local stageCounts = {}
	for i = 1, Config.Stages.Count do
		stageCounts[i] = 0
	end
	
	-- Tally votes
	for player, vote in pairs(room.stageVotes) do
		for _, stageNum in ipairs(vote) do
			stageCounts[stageNum] = (stageCounts[stageNum] or 0) + 1
		end
	end
	
	-- Build weighted pool based on votes
	-- More votes = higher chance to be selected
	local allStages = {}
	for i = 1, Config.Stages.Count do
		allStages[i] = i
	end
	
	-- Shuffle first
	for i = #allStages, 2, -1 do
		local j = math.random(1, i)
		allStages[i], allStages[j] = allStages[j], allStages[i]
	end
	
	-- Sort by vote count (descending), with randomness for ties
	table.sort(allStages, function(a, b)
		local countA = stageCounts[a] or 0
		local countB = stageCounts[b] or 0
		if countA ~= countB then
			return countA > countB
		end
		-- Random tiebreaker (already shuffled)
		return a < b
	end)
	
	-- Return all stages in vote-weighted order
	return allStages
end

-- Shuffle all stages
function MatchManager:shuffleAllStages(): {number}
	local stages = {}
	for i = 1, Config.Stages.Count do
		stages[i] = i
	end
	
	for i = #stages, 2, -1 do
		local j = math.random(1, i)
		stages[i], stages[j] = stages[j], stages[i]
	end
	
	return stages
end

-- Get stage order for a match (used by GameManager)
function MatchManager:getStageOrderForMatch(roomId: string): {number}
	local room = self.rooms[roomId]
	if not room then
		return self:shuffleAllStages()
	end
	
	-- If already selected, return it
	if room.selectedStageOrder then
		return room.selectedStageOrder
	end
	
	-- Calculate from votes
	room.selectedStageOrder = self:calculateFinalStageOrder(room)
	return room.selectedStageOrder
end

-- Set stage order for a match (used when solo player selects stages)
function MatchManager:setStageOrderForMatch(roomId: string, stageOrder: {number})
	local room = self.rooms[roomId]
	if room then
		room.selectedStageOrder = stageOrder
		room.stageOrder = stageOrder
	end
end

return MatchManager
