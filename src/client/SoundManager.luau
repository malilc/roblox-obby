-- SoundManager: จัดการ BGM และ SFX ทั้งหมดฝั่ง client

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundManager = {}
SoundManager.__index = SoundManager

-- Sound IDs — ใส่ rbxassetid://XXXXXXXXX ของ audio จาก Creator Hub
-- ตอนนี้ว่างไว้ก่อน เกมรันได้ปกติ แค่ยังไม่มีเสียง
local SOUNDS = {
	BGM_Lobby         = "", -- ใส่ ID เพลง lobby loop ที่นี่
	SFX_Countdown     = "", -- ใส่ ID เสียง countdown beep ที่นี่
	SFX_GameStart     = "", -- ใส่ ID เสียง GO! ที่นี่
	SFX_StageComplete = "", -- ใส่ ID เสียง stage clear ที่นี่
	SFX_ItemPickup    = "", -- ใส่ ID เสียง item pickup ที่นี่
}

function SoundManager.new()
	local self = setmetatable({}, SoundManager)

	self.bgm = nil
	self.sounds = {}
	self._remoteConns = {}

	self:_createSounds()
	task.spawn(function()
		self:_setupRemotes()
	end)

	return self
end

function SoundManager:_createSounds()
	-- BGM (looping lobby music)
	local bgm = Instance.new("Sound")
	bgm.Name = "BGM_Lobby"
	bgm.SoundId = SOUNDS.BGM_Lobby
	bgm.Volume = 0.35
	bgm.Looped = true
	bgm.RollOffMaxDistance = 0
	bgm.Parent = SoundService
	self.bgm = bgm

	-- SFX
	for name, id in pairs(SOUNDS) do
		if string.sub(name, 1, 3) == "SFX" then
			local sfx = Instance.new("Sound")
			sfx.Name = name
			sfx.SoundId = id
			sfx.Volume = 0.6
			sfx.Looped = false
			sfx.RollOffMaxDistance = 0
			sfx.Parent = SoundService
			self.sounds[name] = sfx
		end
	end
end

function SoundManager:playBGM()
	if self.bgm and self.bgm.SoundId ~= "" and not self.bgm.IsPlaying then
		self.bgm:Play()
	end
end

function SoundManager:stopBGM()
	if self.bgm and self.bgm.IsPlaying then
		self.bgm:Stop()
	end
end

function SoundManager:playSFX(name: string)
	local sfx = self.sounds[name]
	if sfx and sfx.SoundId ~= "" then
		sfx:Play()
	end
end

function SoundManager:_setupRemotes()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	-- Start BGM immediately
	self:playBGM()

	-- Countdown beep on each number
	local countdownRemote = remotes:WaitForChild("CountdownUpdate")
	table.insert(self._remoteConns, countdownRemote.OnClientEvent:Connect(function(data)
		if data.number and data.number > 0 then
			self:playSFX("SFX_Countdown")
		end
		if data.number == 1 then
			-- GO! — play start sound after countdown
			task.delay(0.9, function()
				self:playSFX("SFX_GameStart")
				self:stopBGM()
			end)
		end
	end))

	-- Stage complete chime
	local stageComplete = remotes:WaitForChild("StageComplete")
	table.insert(self._remoteConns, stageComplete.OnClientEvent:Connect(function(data)
		if data.finished then
			self:playSFX("SFX_GameStart")
		else
			self:playSFX("SFX_StageComplete")
		end
	end))

	-- Return to lobby — resume BGM
	local returnToLobby = remotes:WaitForChild("ReturnToLobby")
	table.insert(self._remoteConns, returnToLobby.OnClientEvent:Connect(function()
		task.delay(0.5, function()
			self:playBGM()
		end)
	end))
end

return SoundManager
