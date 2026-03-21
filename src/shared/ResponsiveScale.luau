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
