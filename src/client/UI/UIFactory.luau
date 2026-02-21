-- UIFactory: Reusable UI component builders to eliminate repeated Instance creation patterns

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.ThemeConfig)

local UIFactory = {}

-- Corner size mapping
local CORNER_SIZES = {
	sm = Theme.CORNER_SM,
	md = Theme.CORNER_MD,
	lg = Theme.CORNER_LG,
	full = Theme.CORNER_FULL,
}

-- Stroke weight mapping
local STROKE_WEIGHTS = {
	thin = Theme.STROKE_THIN,
	med = Theme.STROKE_MED,
	bold = Theme.STROKE_BOLD,
}

export type PanelOptions = {
	name: string?,
	size: UDim2,
	position: UDim2?,
	anchorPoint: Vector2?,
	bgColor: Color3?,
	bgTransparency: number?,
	cornerSize: string?,         -- "sm" | "md" | "lg" | "full"
	strokeColor: Color3?,
	strokeWeight: string?,       -- "thin" | "med" | "bold"
	strokeTransparency: number?,
	visible: boolean?,
	zIndex: number?,
}

export type ButtonOptions = {
	name: string?,
	size: UDim2,
	position: UDim2?,
	anchorPoint: Vector2?,
	text: string?,
	bgColor: Color3?,
	textColor: Color3?,
	textSize: number?,
	font: Enum.Font?,
	cornerSize: string?,
	strokeColor: Color3?,
	strokeWeight: string?,
	onClick: (() -> ())?,
	zIndex: number?,
}

export type LabelOptions = {
	name: string?,
	size: UDim2,
	position: UDim2?,
	anchorPoint: Vector2?,
	text: string?,
	textColor: Color3?,
	textSize: number?,
	font: Enum.Font?,
	textXAlignment: Enum.TextXAlignment?,
	textYAlignment: Enum.TextYAlignment?,
	richText: boolean?,
	bgColor: Color3?,
	bgTransparency: number?,
	cornerSize: string?,
	zIndex: number?,
}

-- Create a styled panel (Frame + UICorner + optional UIStroke)
function UIFactory.createPanel(parent: GuiObject, options: PanelOptions): Frame
	local frame = Instance.new("Frame")
	frame.Name = options.name or "Panel"
	frame.Size = options.size
	frame.Position = options.position or UDim2.new(0, 0, 0, 0)
	frame.AnchorPoint = options.anchorPoint or Vector2.zero
	frame.BackgroundColor3 = options.bgColor or Theme.BG_BASE
	frame.BackgroundTransparency = options.bgTransparency or 0
	frame.BorderSizePixel = 0
	if options.visible ~= nil then
		frame.Visible = options.visible
	end
	if options.zIndex then
		frame.ZIndex = options.zIndex
	end
	frame.Parent = parent

	-- Corner
	local cornerKey = options.cornerSize or "md"
	local cornerRadius = CORNER_SIZES[cornerKey]
	if cornerRadius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = cornerRadius
		corner.Parent = frame
	end

	-- Stroke
	if options.strokeColor then
		local stroke = Instance.new("UIStroke")
		stroke.Color = options.strokeColor
		stroke.Thickness = STROKE_WEIGHTS[options.strokeWeight or "thin"] or Theme.STROKE_THIN
		stroke.Transparency = options.strokeTransparency or 0
		stroke.Parent = frame
	end

	return frame
end

-- Create a styled text button (TextButton + UICorner + optional UIStroke + onClick)
function UIFactory.createButton(parent: GuiObject, options: ButtonOptions): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = options.name or "Button"
	btn.Size = options.size
	btn.Position = options.position or UDim2.new(0, 0, 0, 0)
	btn.AnchorPoint = options.anchorPoint or Vector2.zero
	btn.BackgroundColor3 = options.bgColor or Theme.PRIMARY
	btn.BorderSizePixel = 0
	btn.Text = options.text or ""
	btn.TextColor3 = options.textColor or Theme.TEXT_PRIMARY
	btn.TextSize = options.textSize or 16
	btn.Font = options.font or Enum.Font.GothamBold
	btn.AutoButtonColor = true
	if options.zIndex then
		btn.ZIndex = options.zIndex
	end
	btn.Parent = parent

	-- Corner
	local cornerKey = options.cornerSize or "sm"
	local cornerRadius = CORNER_SIZES[cornerKey]
	if cornerRadius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = cornerRadius
		corner.Parent = btn
	end

	-- Stroke
	if options.strokeColor then
		local stroke = Instance.new("UIStroke")
		stroke.Color = options.strokeColor
		stroke.Thickness = STROKE_WEIGHTS[options.strokeWeight or "thin"] or Theme.STROKE_THIN
		stroke.Parent = btn
	end

	-- Click handler
	if options.onClick then
		btn.MouseButton1Click:Connect(options.onClick)
	end

	return btn
end

-- Create a styled text label (TextLabel + optional UICorner)
function UIFactory.createLabel(parent: GuiObject, options: LabelOptions): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = options.name or "Label"
	label.Size = options.size
	label.Position = options.position or UDim2.new(0, 0, 0, 0)
	label.AnchorPoint = options.anchorPoint or Vector2.zero
	label.BackgroundTransparency = options.bgTransparency or 1
	label.Text = options.text or ""
	label.TextColor3 = options.textColor or Theme.TEXT_PRIMARY
	label.TextSize = options.textSize or 16
	label.Font = options.font or Enum.Font.GothamBold
	label.RichText = options.richText or false
	label.BorderSizePixel = 0
	if options.bgColor then
		label.BackgroundColor3 = options.bgColor
	end
	if options.textXAlignment then
		label.TextXAlignment = options.textXAlignment
	end
	if options.textYAlignment then
		label.TextYAlignment = options.textYAlignment
	end
	if options.zIndex then
		label.ZIndex = options.zIndex
	end
	label.Parent = parent

	-- Corner (for labels with backgrounds)
	if options.cornerSize then
		local cornerRadius = CORNER_SIZES[options.cornerSize]
		if cornerRadius then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = cornerRadius
			corner.Parent = label
		end
	end

	return label
end

-- Create a modal (background overlay + centered panel)
function UIFactory.createModal(parent: GuiObject, options: {
	name: string?,
	size: UDim2,
	bgColor: Color3?,
	bgTransparency: number?,
	cornerSize: string?,
	strokeColor: Color3?,
	strokeWeight: string?,
	overlayColor: Color3?,
	overlayTransparency: number?,
	overlayZIndex: number?,
	panelZIndex: number?,
}): (Frame, Frame)  -- returns (overlay, panel)
	-- Overlay
	local overlay = Instance.new("Frame")
	overlay.Name = (options.name or "Modal") .. "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = options.overlayColor or Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = options.overlayTransparency or 0.5
	overlay.BorderSizePixel = 0
	overlay.ZIndex = options.overlayZIndex or 50
	overlay.Visible = false
	overlay.Parent = parent

	-- Panel (centered)
	local panel = UIFactory.createPanel(overlay, {
		name = (options.name or "Modal") .. "Panel",
		size = options.size,
		position = UDim2.new(0.5, 0, 0.5, 0),
		anchorPoint = Vector2.new(0.5, 0.5),
		bgColor = options.bgColor or Theme.BG_BASE,
		bgTransparency = options.bgTransparency or 0.05,
		cornerSize = options.cornerSize or "md",
		strokeColor = options.strokeColor,
		strokeWeight = options.strokeWeight,
		zIndex = options.panelZIndex or 51,
	})

	return overlay, panel
end

return UIFactory
