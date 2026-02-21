-- TweenHelper: Reusable animation utilities for common UI patterns
-- Eliminates repeated TweenService code across UI modules

local TweenService = game:GetService("TweenService")

local TweenHelper = {}

-- Pop animation (scale up then bounce back)
function TweenHelper.pop(object: GuiObject, scaleMultiplier: number?, duration: number?)
	local originalSize = object.Size
	local scale = scaleMultiplier or 1.1
	local dur = duration or 0.1

	local targetSize = UDim2.new(
		originalSize.X.Scale * scale, math.floor(originalSize.X.Offset * scale),
		originalSize.Y.Scale * scale, math.floor(originalSize.Y.Offset * scale)
	)

	local scaleUp = TweenService:Create(object, TweenInfo.new(dur, Enum.EasingStyle.Back), {
		Size = targetSize
	})
	scaleUp:Play()

	scaleUp.Completed:Connect(function()
		local scaleDown = TweenService:Create(object, TweenInfo.new(dur * 1.5, Enum.EasingStyle.Bounce), {
			Size = originalSize
		})
		scaleDown:Play()
	end)
end

-- Fade in (from transparent to visible)
function TweenHelper.fadeIn(object: GuiObject, duration: number?): Tween
	object.BackgroundTransparency = 1
	local tween = TweenService:Create(object, TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 0
	})
	tween:Play()
	return tween
end

-- Fade out (from visible to transparent)
function TweenHelper.fadeOut(object: GuiObject, duration: number?): Tween
	local tween = TweenService:Create(object, TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 1
	})
	tween:Play()
	return tween
end

-- Slide in from a direction
function TweenHelper.slideIn(object: GuiObject, fromPosition: UDim2, toPosition: UDim2, duration: number?): Tween
	object.Position = fromPosition
	local tween = TweenService:Create(object, TweenInfo.new(duration or 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = toPosition
	})
	tween:Play()
	return tween
end

-- Glow effect on UIStroke (brighten and dim)
function TweenHelper.glowStroke(stroke: UIStroke, targetTransparency: number?, targetThickness: number?, duration: number?)
	local dur = duration or 0.1
	local glowUp = TweenService:Create(stroke, TweenInfo.new(dur), {
		Transparency = targetTransparency or 0,
		Thickness = targetThickness or stroke.Thickness * 1.5,
	})
	glowUp:Play()

	local originalTransparency = stroke.Transparency
	local originalThickness = stroke.Thickness

	glowUp.Completed:Connect(function()
		local glowDown = TweenService:Create(stroke, TweenInfo.new(dur * 2), {
			Transparency = originalTransparency,
			Thickness = originalThickness,
		})
		glowDown:Play()
	end)
end

-- Color flash (change color then return)
function TweenHelper.colorFlash(label: TextLabel, flashColor: Color3, returnColor: Color3, duration: number?)
	label.TextColor3 = flashColor
	task.delay(duration or 0.15, function()
		local tween = TweenService:Create(label, TweenInfo.new(0.25), {
			TextColor3 = returnColor
		})
		tween:Play()
	end)
end

-- Create a generic tween with common defaults
function TweenHelper.create(object: Instance, duration: number, properties: {[string]: any}, easingStyle: Enum.EasingStyle?): Tween
	local tween = TweenService:Create(
		object,
		TweenInfo.new(duration, easingStyle or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		properties
	)
	return tween
end

return TweenHelper
