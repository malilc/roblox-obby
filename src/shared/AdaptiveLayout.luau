--!strict
-- CLIENT ONLY: requires Camera and GuiService (only require from client scripts)

-- AdaptiveLayout: pure calculation functions for viewport-aware UI scaling.
-- No runtime state, no Roblox services — safe to unit-test in isolation.

local AdaptiveLayout = {}

-- ========== TYPES ==========

export type DeviceType = "Phone" | "Tablet" | "Desktop"
export type ZoneName = "TopLeft" | "TopCenter" | "TopRight" | "BottomLeft" | "BottomCenter" | "BottomRight"
export type ZoneConfig = {
    order: number,
    padding: number?,
    designWidth: number?,
    designHeight: number?,
}

-- ========== CONSTANTS ==========

local DESIGN_VIEWPORT = { width = 1920, height = 1080 }
local MIN_SCALE = 0.4
local MAX_SCALE = 1.0
local MODAL_MARGIN = 60

-- ========== PRIVATE HELPERS ==========

local function clamp(value: number, lo: number, hi: number): number
    if value < lo then return lo end
    if value > hi then return hi end
    return value
end

-- ========== PUBLIC FUNCTIONS ==========

-- calculateHUDScale
-- Returns a UIScale value for HUD elements based on the current viewport.
-- safeH excludes the top GUI inset (status bar / notch area).
function AdaptiveLayout.calculateHUDScale(viewportW: number, viewportH: number, guiInsetY: number): number
    local safeH = viewportH - guiInsetY
    local scale = clamp(math.min(viewportW / DESIGN_VIEWPORT.width, safeH / DESIGN_VIEWPORT.height), MIN_SCALE, MAX_SCALE)
    return scale
end

-- calculateModalScale
-- Returns a UIScale value for modal/popup panels so they fit within the
-- viewport with a uniform margin on all sides.
-- designW/designH are the pixel dimensions the modal was authored at.
function AdaptiveLayout.calculateModalScale(
    viewportW: number,
    viewportH: number,
    guiInsetY: number,
    designW: number,
    designH: number
): number
    local safeW = viewportW - MODAL_MARGIN
    local safeH = viewportH - guiInsetY - MODAL_MARGIN
    local scale = clamp(math.min(safeW / designW, safeH / designH), MIN_SCALE, MAX_SCALE)
    return scale
end

-- classifyDevice
-- Returns a DeviceType string based on the usable vertical space.
-- Phone : safeH < 500  (small phones in portrait)
-- Tablet : 500 <= safeH <= 900
-- Desktop: safeH > 900
function AdaptiveLayout.classifyDevice(viewportW: number, viewportH: number, guiInsetY: number): DeviceType
    local safeH = viewportH - guiInsetY
    if safeH < 500 then
        return "Phone"
    elseif safeH <= 900 then
        return "Tablet"
    else
        return "Desktop"
    end
end

return AdaptiveLayout
