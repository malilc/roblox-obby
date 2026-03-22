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

-- ========== ZONE LAYOUT ==========

local ZONE_DEFAULTS = {
    TopLeft      = { anchorX = 0,   anchorY = 0, dirDefault = "Down" },
    TopCenter    = { anchorX = 0.5, anchorY = 0, dirDefault = "Down" },
    TopRight     = { anchorX = 1,   anchorY = 0, dirDefault = "Down" },
    BottomLeft   = { anchorX = 0,   anchorY = 1, dirDefault = "Up" },
    BottomCenter = { anchorX = 0.5, anchorY = 1, dirDefault = "Up" },
    BottomRight  = { anchorX = 1,   anchorY = 1, dirDefault = "Up" },
}

-- calculateZonePositions
-- Returns a list of { x, y, anchorX, anchorY } offset records for stacking
-- HUD elements inside a named zone.
-- Positions are OFFSETS relative to the anchor point — map directly to
-- UDim2.new(anchorX, xOffset, anchorY, yOffset).
--
-- Parameters:
--   zoneName   : one of the ZoneName strings
--   elements   : array of { order, designWidth, designHeight, padding, visible }
--   scale      : UIScale value to apply to element dimensions
--   safeWidth  : usable screen width  (unused by layout math, reserved for callers)
--   safeHeight : usable screen height (unused by layout math, reserved for callers)
function AdaptiveLayout.calculateZonePositions(
    zoneName: ZoneName,
    elements: { { order: number, designWidth: number, designHeight: number, padding: number, visible: boolean } },
    scale: number,
    _safeWidth: number,
    _safeHeight: number
): { { x: number, y: number, anchorX: number, anchorY: number } }
    local zone = ZONE_DEFAULTS[zoneName]
    assert(zone, "calculateZonePositions: unknown zoneName '" .. tostring(zoneName) .. "'")

    -- Sort a copy by order ascending
    local sorted = {}
    for _, el in ipairs(elements) do
        table.insert(sorted, el)
    end
    table.sort(sorted, function(a, b) return a.order < b.order end)

    -- Determine X sign: positive for left-anchored, negative for right-anchored, 0 for centered
    local xSign: number
    if zone.anchorX == 0 then
        xSign = 1
    elseif zone.anchorX == 1 then
        xSign = -1
    else
        xSign = 0
    end

    local positions: { { x: number, y: number, anchorX: number, anchorY: number } } = {}
    local cursor = 0

    for _, el in ipairs(sorted) do
        -- Skip invisible elements
        if el.visible == false then
            continue
        end

        local scaledH = el.designHeight * scale
        local xOffset = xSign * el.padding

        local yOffset: number
        if zone.dirDefault == "Up" then
            -- Stack upward: subtract padding + height, place at new cursor
            cursor = cursor - el.padding - scaledH
            yOffset = cursor
        else
            -- Stack downward: add padding, place, then advance cursor
            cursor = cursor + el.padding
            yOffset = cursor
            cursor = cursor + scaledH
        end

        table.insert(positions, {
            x       = xOffset,
            y       = yOffset,
            anchorX = zone.anchorX,
            anchorY = zone.anchorY,
        })
    end

    return positions
end

return AdaptiveLayout
