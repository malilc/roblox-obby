-- ItemEffects: Client-side visual effects for items
-- Handles screen shake, flash, camera effects

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local ItemEffects = {}
ItemEffects.__index = ItemEffects

function ItemEffects.new()
	local self = setmetatable({}, ItemEffects)
	
	self.originalFOV = 70
	self.isShaking = false
	self.screenGui = nil
	self.flashFrame = nil
	
	self:createScreenOverlay()
	self:setupRemoteListeners()
	
	return self
end

-- Create screen overlay for flash effects
function ItemEffects:createScreenOverlay()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ItemEffectsOverlay"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 100
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	self.screenGui = screenGui
	
	-- Flash frame (covers entire screen)
	local flashFrame = Instance.new("Frame")
	flashFrame.Name = "FlashFrame"
	flashFrame.Size = UDim2.new(1, 0, 1, 0)
	flashFrame.Position = UDim2.new(0, 0, 0, 0)
	flashFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flashFrame.BackgroundTransparency = 1
	flashFrame.BorderSizePixel = 0
	flashFrame.Parent = screenGui
	self.flashFrame = flashFrame
end

-- Setup remote event listeners
function ItemEffects:setupRemoteListeners()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return end
	
	-- Listen for item effect events (if created)
	local itemEffectRemote = remotes:FindFirstChild("ItemEffect")
	if itemEffectRemote then
		itemEffectRemote.OnClientEvent:Connect(function(effectType, params)
			self:playEffect(effectType, params)
		end)
	end
end

-- Play effect by type
function ItemEffects:playEffect(effectType: string, params: {[string]: any}?)
	params = params or {}
	
	if effectType == "ScreenShake" then
		self:screenShake(params.intensity or 5, params.duration or 0.3)
	elseif effectType == "ScreenFlash" then
		self:screenFlash(params.color or Color3.fromRGB(255, 255, 255), params.duration or 0.2)
	elseif effectType == "CameraZoom" then
		self:cameraZoom(params.targetFOV or 50, params.duration or 0.3)
	elseif effectType == "LightningFlash" then
		self:lightningFlash()
	elseif effectType == "SpeedBoostFOV" then
		self:speedBoostFOV(params.duration or 3)
	elseif effectType == "StunEffect" then
		self:stunEffect(params.duration or 2)
	end
end

-- Screen shake effect
function ItemEffects:screenShake(intensity: number, duration: number)
	if self.isShaking then return end
	self.isShaking = true
	
	local originalCFrame = Camera.CFrame
	local startTime = tick()
	
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		if elapsed >= duration then
			Camera.CFrame = originalCFrame
			self.isShaking = false
			connection:Disconnect()
			return
		end
		
		-- Decay intensity over time
		local progress = elapsed / duration
		local currentIntensity = intensity * (1 - progress)
		
		-- Random offset
		local offsetX = (math.random() - 0.5) * currentIntensity * 0.1
		local offsetY = (math.random() - 0.5) * currentIntensity * 0.1
		local offsetZ = (math.random() - 0.5) * currentIntensity * 0.1
		
		Camera.CFrame = originalCFrame * CFrame.new(offsetX, offsetY, offsetZ)
	end)
end

-- Screen flash effect
function ItemEffects:screenFlash(color: Color3, duration: number)
	if not self.flashFrame then return end
	
	self.flashFrame.BackgroundColor3 = color
	self.flashFrame.BackgroundTransparency = 0.3
	
	local flashTween = TweenService:Create(self.flashFrame, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1
	})
	flashTween:Play()
end

-- Camera zoom effect (FOV change)
function ItemEffects:cameraZoom(targetFOV: number, duration: number)
	if not Camera then return end
	
	self.originalFOV = Camera.FieldOfView
	
	-- Zoom in
	local zoomInTween = TweenService:Create(Camera, TweenInfo.new(duration * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = targetFOV
	})
	zoomInTween:Play()
	
	-- Zoom back out
	zoomInTween.Completed:Connect(function()
		task.delay(duration * 0.4, function()
			local zoomOutTween = TweenService:Create(Camera, TweenInfo.new(duration * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				FieldOfView = self.originalFOV
			})
			zoomOutTween:Play()
		end)
	end)
end

-- Lightning flash effect (dramatic)
function ItemEffects:lightningFlash()
	if not self.flashFrame then return end
	
	-- Multiple rapid flashes
	task.spawn(function()
		for i = 1, 3 do
			self.flashFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 200)
			self.flashFrame.BackgroundTransparency = 0.2
			task.wait(0.05)
			self.flashFrame.BackgroundTransparency = 1
			task.wait(0.1)
		end
	end)
	
	-- Screen shake with lightning
	self:screenShake(8, 0.4)
end

-- Speed boost FOV effect (widened view while boosted)
function ItemEffects:speedBoostFOV(duration: number)
	if not Camera then return end
	
	self.originalFOV = Camera.FieldOfView
	local boostedFOV = self.originalFOV + 15
	
	-- Widen FOV
	local widenTween = TweenService:Create(Camera, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FieldOfView = boostedFOV
	})
	widenTween:Play()
	
	-- Return to normal after duration
	task.delay(duration - 0.3, function()
		local returnTween = TweenService:Create(Camera, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			FieldOfView = self.originalFOV
		})
		returnTween:Play()
	end)
end

-- Stun effect (dazed vision)
function ItemEffects:stunEffect(duration: number)
	if not self.flashFrame then return end
	
	-- Create blur effect (simple version with transparency)
	self.flashFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	self.flashFrame.BackgroundTransparency = 0.7
	
	-- Pulsing effect
	local connection
	local startTime = tick()
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		if elapsed >= duration then
			self.flashFrame.BackgroundTransparency = 1
			connection:Disconnect()
			return
		end
		
		-- Pulsing transparency
		local pulse = 0.6 + math.sin(elapsed * 10) * 0.15
		self.flashFrame.BackgroundTransparency = pulse
	end)
	
	-- Minor screen shake
	self:screenShake(3, duration * 0.3)
end

-- Hit effect (when player gets hit)
function ItemEffects:hitEffect()
	-- Red flash
	self:screenFlash(Color3.fromRGB(255, 50, 50), 0.3)
	
	-- Camera shake
	self:screenShake(6, 0.2)
end

-- Teleport effect (for swap)
function ItemEffects:teleportEffect()
	-- Purple flash
	self:screenFlash(Color3.fromRGB(200, 100, 255), 0.3)
	
	-- Camera zoom effect
	self:cameraZoom(40, 0.5)
end

-- Explosion effect (when missile hits near player)
function ItemEffects:explosionEffect(distance: number)
	-- Intensity based on distance
	local intensity = math.clamp(1 - (distance / 30), 0.2, 1)
	
	-- Screen shake
	self:screenShake(10 * intensity, 0.3)
	
	-- Orange flash
	self:screenFlash(Color3.fromRGB(255, 150, 50), 0.2)
end

return ItemEffects
