--!strict
-- CLIENT ONLY: requires Camera and GuiService (only require from client scripts)

-- AdaptiveLayout: viewport-aware UI scaling module.
-- Pure calculation functions are safe to unit-test in isolation.
-- Runtime layer (init, applyScale, registerHUD) requires a client environment.

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
            -- Stack upward: padding from previous top, place anchor (bottom), advance to top
            cursor = cursor - el.padding
            yOffset = cursor
            cursor = cursor - scaledH
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

-- ========== MODULE STATE ==========

local camera: Camera? = nil
local screenGui: ScreenGui? = nil
local guiInsetY: number = 0
local currentScale: number = 1.0
local currentSafeArea = { width = 1920, height = 1080 }
local currentViewport = { x = 1920, y = 1080 }
local currentDeviceType: DeviceType = "Desktop"
local initialized = false
local viewportReady = false
local viewportConnection: RBXScriptConnection? = nil

local trackedModals: {{ frame: Frame, designW: number, designH: number, uiScale: UIScale }} = {}
local trackedHUD: {{ frame: Frame, zone: ZoneName, config: ZoneConfig, uiScale: UIScale }} = {}
local changeCallbacks: {() -> ()} = {}

-- ========== INTERNAL FUNCTIONS ==========

-- Resolve the actual viewport size from Camera or ScreenGui fallback.
-- Camera.ViewportSize may return (1,1) in some Studio configurations.
local function _getViewportSize(): (number, number)
    -- Prefer Camera.ViewportSize
    local cam = camera
    if cam then
        local vp = cam.ViewportSize
        if vp.X > 1 and vp.Y > 1 then
            return vp.X, vp.Y
        end
    end
    -- Fallback: derive from ScreenGui.AbsoluteSize
    -- AbsoluteSize.Y excludes the gui inset when IgnoreGuiInset=false,
    -- so add it back to get the full viewport height.
    if screenGui and screenGui.Parent then
        local abs = screenGui.AbsoluteSize
        if abs.X > 1 and abs.Y > 1 then
            return abs.X, abs.Y + guiInsetY
        end
    end
    return 0, 0
end

local function _recalculate()
    local vw, vh = _getViewportSize()
    if vw <= 1 or vh <= 1 then return end

    viewportReady = true
    currentViewport = { x = vw, y = vh }
    currentSafeArea = {
        width  = vw,
        height = vh - guiInsetY,
    }
    currentScale       = AdaptiveLayout.calculateHUDScale(vw, vh, guiInsetY)
    currentDeviceType  = AdaptiveLayout.classifyDevice(vw, vh, guiInsetY)
end

local function _cleanOrphans()
    -- Remove modals whose frames have been destroyed
    for i = #trackedModals, 1, -1 do
        if trackedModals[i].frame.Parent == nil then
            table.remove(trackedModals, i)
        end
    end
    -- Remove HUD entries whose frames have been destroyed
    for i = #trackedHUD, 1, -1 do
        if trackedHUD[i].frame.Parent == nil then
            table.remove(trackedHUD, i)
        end
    end
end

local function _compensateStrokesInternal(frame: Frame, scale: number)
    -- Walk all UIStroke descendants, store original thickness on first call,
    -- then set thickness = original * scale so strokes stay visually consistent.
    for _, desc in ipairs(frame:GetDescendants()) do
        if desc:IsA("UIStroke") then
            local stroke = desc :: UIStroke
            -- Store original thickness once via attribute
            if stroke:GetAttribute("_originalThickness") == nil then
                stroke:SetAttribute("_originalThickness", stroke.Thickness)
            end
            local original = stroke:GetAttribute("_originalThickness") :: number
            stroke.Thickness = original * scale
        end
    end
end

local function _updateModalScales()
    for _, entry in ipairs(trackedModals) do
        if entry.frame.Parent ~= nil then
            -- Use raw viewport (not safe area) — modal height margins handle inset separately
            local scale = AdaptiveLayout.calculateModalScale(
                currentViewport.x,
                currentViewport.y,
                guiInsetY,
                entry.designW,
                entry.designH
            )
            entry.uiScale.Scale = scale
            _compensateStrokesInternal(entry.frame, scale)
        end
    end
end

local function _updateHUDPositions()
    -- Group tracked HUD entries by zone name
    local byZone: { [ZoneName]: {{ frame: Frame, zone: ZoneName, config: ZoneConfig, uiScale: UIScale }} } = {}
    for _, entry in ipairs(trackedHUD) do
        if entry.frame.Parent ~= nil then
            if not byZone[entry.zone] then
                byZone[entry.zone] = {}
            end
            table.insert(byZone[entry.zone], entry)
        end
    end

    -- For each zone, build the elements array and calculate positions
    for zoneName, entries in pairs(byZone) do
        local calcElements: { { order: number, designWidth: number, designHeight: number, padding: number, visible: boolean } } = {}
        for _, entry in ipairs(entries) do
            local dw = entry.config.designWidth  or entry.frame.AbsoluteSize.X
            local dh = entry.config.designHeight or entry.frame.AbsoluteSize.Y
            table.insert(calcElements, {
                order       = entry.config.order,
                designWidth = dw,
                designHeight= dh,
                padding     = entry.config.padding or 8,
                visible     = entry.frame.Visible,
            })
        end

        local positions = AdaptiveLayout.calculateZonePositions(
            zoneName,
            calcElements,
            currentScale,
            currentSafeArea.width,
            currentSafeArea.height
        )

        -- Sort entries the same way (by order) so index alignment is correct
        table.sort(entries, function(a, b) return a.config.order < b.config.order end)

        -- Apply positions — positions array only contains entries for visible elements,
        -- so we must re-iterate and match by visible flag the same way calculateZonePositions does
        local posIdx = 0
        for _, entry in ipairs(entries) do
            entry.uiScale.Scale = currentScale
            if entry.frame.Visible then
                posIdx = posIdx + 1
                local pos = positions[posIdx]
                if pos then
                    entry.frame.AnchorPoint = Vector2.new(pos.anchorX, pos.anchorY)
                    entry.frame.Position    = UDim2.new(pos.anchorX, pos.x, pos.anchorY, pos.y)
                end
            end
        end
    end
end

local function _updateAll()
    _cleanOrphans()
    _recalculate()
    _updateModalScales()
    _updateHUDPositions()
    -- Notify all change listeners on separate threads to avoid re-entrancy issues
    for _, cb in ipairs(changeCallbacks) do
        task.spawn(cb)
    end
end

-- ========== PUBLIC API ==========

-- AdaptiveLayout.init
-- Must be called once from a client script (e.g. MainUI) before using any
-- runtime features. Grabs the Camera and GuiService inset, then listens for
-- viewport changes so all registered elements stay up-to-date automatically.
function AdaptiveLayout.init(gui: ScreenGui?)
    if initialized then return end
    initialized = true

    -- Store ScreenGui for viewport fallback (Camera.ViewportSize may be 1,1 in Studio)
    screenGui = gui

    local GuiService = game:GetService("GuiService")
    local inset = GuiService:GetGuiInset()
    guiInsetY = inset.Y

    local Workspace = game:GetService("Workspace")

    -- Helper: bind ViewportSize listener to a camera, cleaning up the old one
    local function connectCamera(cam: Camera)
        camera = cam
        if viewportConnection then
            viewportConnection:Disconnect()
            viewportConnection = nil
        end
        viewportConnection = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            task.wait()
            _updateAll()
        end)
        _updateAll()
    end

    -- Connect current camera if available
    local cam = Workspace.CurrentCamera
    if cam then
        connectCamera(cam)
    end

    -- Always listen for camera swap (respawn, etc.)
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        local newCam = Workspace.CurrentCamera
        if newCam then
            connectCamera(newCam)
        end
    end)

    -- Listen for ScreenGui resize (reliable fallback when Camera.ViewportSize is stale)
    if screenGui then
        screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            task.wait()
            _updateAll()
        end)
    end

    -- If viewport wasn't ready yet, poll until it becomes valid
    if not viewportReady then
        task.spawn(function()
            while not viewportReady do
                task.wait(0.1)
                _updateAll()
            end
        end)
    end
end

-- AdaptiveLayout.getScale
-- Returns the current HUD scale factor (updated whenever the viewport changes).
function AdaptiveLayout.getScale(): number
    return currentScale
end

-- AdaptiveLayout.getSafeArea
-- Returns the usable screen dimensions with the GUI inset already subtracted.
function AdaptiveLayout.getSafeArea(): { width: number, height: number }
    return { width = currentSafeArea.width, height = currentSafeArea.height }
end

-- AdaptiveLayout.getDeviceType
-- Returns the classified device type for the current viewport.
function AdaptiveLayout.getDeviceType(): DeviceType
    return currentDeviceType
end

-- AdaptiveLayout.onChanged
-- Registers a callback that fires whenever the viewport changes or a layout
-- update is triggered. Returns an unsubscribe function.
function AdaptiveLayout.onChanged(callback: () -> ()): () -> ()
    table.insert(changeCallbacks, callback)
    return function()
        for i, cb in ipairs(changeCallbacks) do
            if cb == callback then
                table.remove(changeCallbacks, i)
                break
            end
        end
    end
end

-- AdaptiveLayout.applyScale
-- Attaches a UIScale to `frame` sized so the modal fits the current viewport.
-- Tracks the frame for future viewport-change updates and compensates UIStrokes.
function AdaptiveLayout.applyScale(frame: Frame, designW: number, designH: number)
    -- Reuse an existing AdaptiveScale if one was already applied
    local existing = frame:FindFirstChild("AdaptiveScale")
    local uiScale: UIScale
    if existing and existing:IsA("UIScale") then
        uiScale = existing :: UIScale
    else
        uiScale = Instance.new("UIScale")
        uiScale.Name   = "AdaptiveScale"
        uiScale.Parent = frame
    end

    local scale = AdaptiveLayout.calculateModalScale(
        currentViewport.x,
        currentViewport.y,
        guiInsetY,
        designW,
        designH
    )
    uiScale.Scale = scale

    -- Track for future updates
    table.insert(trackedModals, {
        frame   = frame,
        designW = designW,
        designH = designH,
        uiScale = uiScale,
    })

    _compensateStrokesInternal(frame, scale)
end

-- AdaptiveLayout.registerHUD
-- Registers a HUD frame into a named zone for automatic stacking and scaling.
-- Returns an unregister function that removes the frame from tracking.
function AdaptiveLayout.registerHUD(frame: Frame, zone: ZoneName, config: ZoneConfig): () -> ()
    -- Reuse an existing scale instance if present
    local existing = frame:FindFirstChild("AdaptiveHUDScale")
    local uiScale: UIScale
    if existing and existing:IsA("UIScale") then
        uiScale = existing :: UIScale
    else
        uiScale = Instance.new("UIScale")
        uiScale.Name   = "AdaptiveHUDScale"
        uiScale.Parent = frame
    end

    local entry = {
        frame   = frame,
        zone    = zone,
        config  = config,
        uiScale = uiScale,
    }
    table.insert(trackedHUD, entry)

    -- When the element hides or shows, recalculate zone stacking
    local visConn = frame:GetPropertyChangedSignal("Visible"):Connect(function()
        _updateHUDPositions()
    end)

    -- Perform an immediate layout pass
    _updateHUDPositions()

    -- Return unregister function
    return function()
        visConn:Disconnect()
        AdaptiveLayout.unregisterHUD(frame)
    end
end

-- AdaptiveLayout.unregisterHUD
-- Removes a frame from HUD tracking, destroys its UIScale, and re-runs layout.
function AdaptiveLayout.unregisterHUD(frame: Frame)
    for i, entry in ipairs(trackedHUD) do
        if entry.frame == frame then
            entry.uiScale:Destroy()
            table.remove(trackedHUD, i)
            break
        end
    end
    _updateHUDPositions()
end

-- AdaptiveLayout.compensateStrokes
-- Public wrapper: re-applies stroke-thickness compensation at the current scale.
function AdaptiveLayout.compensateStrokes(frame: Frame)
    _compensateStrokesInternal(frame, currentScale)
end

return AdaptiveLayout
