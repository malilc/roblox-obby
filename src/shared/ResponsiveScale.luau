-- ResponsiveScale.luau
-- Centralized responsive scale computation and UIScale management
-- Computes viewport-aware scale factors so modals shrink to fit any screen
--
-- Usage:
--   local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)
--   ResponsiveScale.init() -- once at startup
--   ResponsiveScale.applyToFrame(modalFrame, 360, 380) -- per modal

local GuiService = game:GetService("GuiService")

local ResponsiveScale = {}

local MIN_SCALE = 0.5       -- minimum scale floor per D-05
local PADDING = 80           -- 40px each side per D-04, D-06

-- Tracked UIScale instances for viewport change updates
local trackedScales: {{ uiScale: UIScale, designWidth: number, designHeight: number }} = {}

-- Tracked UIStroke instances for stroke compensation on viewport change
local trackedStrokes: {{ frame: GuiObject, strokes: {{ stroke: UIStroke, originalThickness: number }} }} = {}

-- Pure function: testable without Roblox runtime services
-- All inputs as parameters for unit test isolation
function ResponsiveScale.calculateScale(
	viewportW: number,
	viewportH: number,
	guiInsetY: number,
	designW: number,
	designH: number
): number
	local availableW = viewportW - PADDING
	local availableH = viewportH - guiInsetY - PADDING
	local scaleX = availableW / designW
	local scaleY = availableH / designH
	local scale = math.min(scaleX, scaleY, 1.0)
	return math.max(scale, MIN_SCALE)
end

-- Runtime wrapper: reads Camera.ViewportSize and GuiInset, then calls calculateScale
function ResponsiveScale._getViewportScale(designW: number, designH: number): number
	local camera = workspace.CurrentCamera
	local viewport = camera.ViewportSize
	local guiInset = GuiService:GetGuiInset()
	return ResponsiveScale.calculateScale(viewport.X, viewport.Y, guiInset.Y, designW, designH)
end

-- Apply UIScale to a frame and register for viewport updates
function ResponsiveScale.applyToFrame(
	frame: GuiObject,
	designWidth: number,
	designHeight: number
): UIScale
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = ResponsiveScale._getViewportScale(designWidth, designHeight)
	uiScale.Parent = frame
	table.insert(trackedScales, {
		uiScale = uiScale,
		designWidth = designWidth,
		designHeight = designHeight,
	})
	return uiScale
end

-- Discover and compensate all UIStrokes in a frame hierarchy
-- Stores original thicknesses so viewport change recalculation uses originals (no drift)
-- Idempotent: if frame already tracked, updates strokes list without duplicates
function ResponsiveScale.compensateStrokes(frame: GuiObject, scale: number)
	-- Check if this frame is already tracked
	local existingEntry = nil
	for _, entry in ipairs(trackedStrokes) do
		if entry.frame == frame then
			existingEntry = entry
			break
		end
	end

	if existingEntry then
		-- Already tracked — recalculate from stored originals, do not re-read Thickness
		for _, strokeEntry in ipairs(existingEntry.strokes) do
			if strokeEntry.stroke.Parent then
				strokeEntry.stroke.Thickness = strokeEntry.originalThickness * scale
			end
		end
		return
	end

	-- First time — discover UIStrokes and store originals
	local strokeEntries = {}
	for _, desc in ipairs(frame:GetDescendants()) do
		if desc:IsA("UIStroke") then
			table.insert(strokeEntries, {
				stroke = desc,
				originalThickness = desc.Thickness,
			})
			desc.Thickness = desc.Thickness * scale
		end
	end
	if #strokeEntries > 0 then
		table.insert(trackedStrokes, {
			frame = frame,
			strokes = strokeEntries,
		})
	end
end

-- Recalculate all tracked UIScale instances
-- Reverse iteration for safe removal of orphaned entries
function ResponsiveScale._updateAll()
	for i = #trackedScales, 1, -1 do
		local entry = trackedScales[i]
		if entry.uiScale.Parent then
			entry.uiScale.Scale = ResponsiveScale._getViewportScale(
				entry.designWidth,
				entry.designHeight
			)
		else
			table.remove(trackedScales, i)
		end
	end

	-- Recalculate stroke compensations from stored originals
	for i = #trackedStrokes, 1, -1 do
		local entry = trackedStrokes[i]
		if entry.frame.Parent then
			-- Find the UIScale on this frame to get current scale
			local uiScale = entry.frame:FindFirstChildOfClass("UIScale")
			if uiScale then
				for _, strokeEntry in ipairs(entry.strokes) do
					if strokeEntry.stroke.Parent then
						strokeEntry.stroke.Thickness = strokeEntry.originalThickness * uiScale.Scale
					end
				end
			end
		else
			table.remove(trackedStrokes, i)
		end
	end
end

-- Initialize viewport change listener
-- Call once at startup (e.g., from client init)
function ResponsiveScale.init()
	local camera = workspace.CurrentCamera
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		task.wait() -- one frame yield for layout to settle
		ResponsiveScale._updateAll()
	end)
end

return ResponsiveScale
