-- SpectatorCamera: กล้อง Follow + FreeCam สำหรับ Spectator Mode

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SpectatorCamera = {}
SpectatorCamera.__index = SpectatorCamera

function SpectatorCamera.new()
	local self = setmetatable({}, SpectatorCamera)

	self.isActive = false
	self.mode = "Follow" -- "Follow" | "FreeCam"
	self.followTarget = nil :: Player?
	self.freeCamCFrame = CFrame.new()
	self.freeCamSpeed = Config.Spectator and Config.Spectator.FreeCamSpeed or 50
	self.yaw = 0
	self.pitch = 0
	self.renderConnection = nil
	self.previousCameraType = nil
	self.previousCameraSubject = nil

	return self
end

function SpectatorCamera:start()
	local camera = workspace.CurrentCamera
	self.previousCameraType = camera.CameraType
	self.previousCameraSubject = camera.CameraSubject

	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	self.isActive = true

	self.renderConnection = RunService.RenderStepped:Connect(function(dt)
		self:update(dt)
	end)
end

function SpectatorCamera:stop()
	self.isActive = false

	if self.renderConnection then
		self.renderConnection:Disconnect()
		self.renderConnection = nil
	end

	-- Restore camera
	local camera = workspace.CurrentCamera
	camera.CameraType = self.previousCameraType or Enum.CameraType.Custom
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default

	local character = Players.LocalPlayer.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

function SpectatorCamera:setFollowMode(targetPlayer: Player)
	self.mode = "Follow"
	self.followTarget = targetPlayer
end

function SpectatorCamera:setFreeCamMode()
	self.mode = "FreeCam"
	self.followTarget = nil
	-- Initialize free cam at current camera position
	self.freeCamCFrame = workspace.CurrentCamera.CFrame
	-- Extract yaw/pitch from current CFrame
	local lookVector = self.freeCamCFrame.LookVector
	self.yaw = math.atan2(-lookVector.X, -lookVector.Z)
	self.pitch = math.asin(lookVector.Y)
end

function SpectatorCamera:update(dt: number)
	if not self.isActive then return end

	local camera = workspace.CurrentCamera

	if self.mode == "Follow" then
		self:updateFollowCamera(camera, dt)
	elseif self.mode == "FreeCam" then
		self:updateFreeCam(camera, dt)
	end
end

function SpectatorCamera:updateFollowCamera(camera: Camera, dt: number)
	if not self.followTarget then return end

	local character = self.followTarget.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local spectConfig = Config.Spectator or {}
	local followDist = spectConfig.FollowDistance or 15
	local followHeight = spectConfig.FollowHeight or 8
	local smoothness = spectConfig.CameraSmoothness or 0.1

	local targetPos = humanoidRootPart.Position
	local lookDir = humanoidRootPart.CFrame.LookVector

	-- Camera behind and above the target
	local cameraPos = targetPos - lookDir * followDist + Vector3.new(0, followHeight, 0)
	local targetCFrame = CFrame.lookAt(cameraPos, targetPos + Vector3.new(0, 2, 0))

	-- Smooth interpolation
	camera.CFrame = camera.CFrame:Lerp(targetCFrame, smoothness)
end

function SpectatorCamera:updateFreeCam(camera: Camera, dt: number)
	-- Mouse look
	local mouseDelta = UserInputService:GetMouseDelta()
	local sensitivity = 0.003
	self.yaw = self.yaw - mouseDelta.X * sensitivity
	self.pitch = math.clamp(self.pitch - mouseDelta.Y * sensitivity, -math.rad(80), math.rad(80))

	local rotation = CFrame.fromEulerAnglesYXZ(self.pitch, self.yaw, 0)

	-- WASD movement
	local moveDir = Vector3.zero

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		moveDir = moveDir + rotation.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		moveDir = moveDir - rotation.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		moveDir = moveDir - rotation.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		moveDir = moveDir + rotation.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		moveDir = moveDir + Vector3.new(0, 1, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		moveDir = moveDir - Vector3.new(0, 1, 0)
	end

	if moveDir.Magnitude > 0 then
		moveDir = moveDir.Unit
	end

	-- Apply movement
	local newPos = self.freeCamCFrame.Position + moveDir * self.freeCamSpeed * dt
	self.freeCamCFrame = CFrame.new(newPos) * rotation

	camera.CFrame = self.freeCamCFrame
end

function SpectatorCamera:isFollowTargetValid(): boolean
	if not self.followTarget then return false end
	if not self.followTarget.Parent then return false end
	if not self.followTarget.Character then return false end
	local humanoidRootPart = self.followTarget.Character:FindFirstChild("HumanoidRootPart")
	return humanoidRootPart ~= nil
end

return SpectatorCamera
