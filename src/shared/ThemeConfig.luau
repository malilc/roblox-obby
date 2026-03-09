-- ThemeConfig.luau
-- Central design token file for Light Bright UI theme
-- All UI files MUST require this and use these tokens instead of inline Color3 values
--
-- Usage:
--   local Theme = require(ReplicatedStorage.Shared.ThemeConfig)
--   frame.BackgroundColor3 = Theme.BG_BASE

local Theme = {}

-- ============================================================
-- BACKGROUNDS (light bright family)
-- ============================================================
Theme.BG_BASE     = Color3.fromRGB(195, 225, 245)  -- light sky blue
Theme.BG_SURFACE  = Color3.fromRGB(255, 255, 255)  -- white (cards)
Theme.BG_ELEVATED = Color3.fromRGB(235, 240, 248)  -- ice blue-gray (hover)
Theme.BG_OVERLAY  = Color3.fromRGB(  0,   0,   0)  -- black (used with transparency)

-- ============================================================
-- BRAND COLORS
-- ============================================================
Theme.PRIMARY      = Color3.fromRGB(255, 220,   0)  -- bright yellow — main CTA buttons
Theme.PRIMARY_DARK = Color3.fromRGB(200, 165,   0)  -- darker yellow — hover / pressed
Theme.SECONDARY    = Color3.fromRGB(255,  85,  50)  -- orange-red — destructive / energy
Theme.ACCENT_CYAN  = Color3.fromRGB( 75, 200, 140)  -- vibrant green — accent / highlight / glow border
Theme.ACCENT_PINK  = Color3.fromRGB(255, 100, 180)  -- pink — fun accent / special

-- ============================================================
-- TEXT
-- ============================================================
Theme.TEXT_PRIMARY = Color3.fromRGB( 55,  60,  72)  -- dark charcoal — on white backgrounds
Theme.TEXT_MUTED   = Color3.fromRGB( 70,  78,  95)  -- dark slate — secondary text (high contrast on light bg)
Theme.TEXT_DARK    = Color3.fromRGB( 55,  60,  72)  -- dark charcoal — on colored bg like gold bar
Theme.TEXT_ON_ACCENT = Color3.fromRGB(255, 255, 255) -- white — on colored buttons

-- ============================================================
-- SEMANTIC COLORS
-- ============================================================
Theme.SUCCESS = Color3.fromRGB( 80, 230, 120)  -- bright green — equip, success, positive
Theme.DANGER  = Color3.fromRGB(255,  70,  70)  -- bright red — leave, locked, danger
Theme.WARNING = Color3.fromRGB(255, 200,   0)  -- yellow — time warning, can-buy state
Theme.INFO    = Color3.fromRGB( 90, 160, 230)  -- sky blue — info, mastery progress

-- ============================================================
-- RARITY COLORS (used for items, titles, rewards)
-- ============================================================
Theme.RARITY_COMMON    = Color3.fromRGB(180, 185, 200)
Theme.RARITY_UNCOMMON  = Color3.fromRGB( 80, 215, 100)
Theme.RARITY_RARE      = Color3.fromRGB( 90, 155, 255)
Theme.RARITY_EPIC      = Color3.fromRGB(200,  85, 255)
Theme.RARITY_LEGENDARY = Color3.fromRGB(255, 205,  50)

-- ============================================================
-- CLASS COLORS
-- ============================================================
Theme.CLASS_NORMAL = Color3.fromRGB(220, 220, 220)
Theme.CLASS_RUNNER = Color3.fromRGB( 80, 210, 255)
Theme.CLASS_JUMPER = Color3.fromRGB( 80, 255, 110)
Theme.CLASS_TANK   = Color3.fromRGB(255, 200,  80)

-- ============================================================
-- MEDAL COLORS (race results)
-- ============================================================
Theme.MEDAL_GOLD   = Color3.fromRGB(255, 215,   0)
Theme.MEDAL_SILVER = Color3.fromRGB(192, 192, 192)
Theme.MEDAL_BRONZE = Color3.fromRGB(205, 127,  50)

-- ============================================================
-- HUD GRADIENT COLORS
-- ============================================================
Theme.HUD_SCORE_START    = Color3.fromRGB(60, 180, 100)   -- fresh green
Theme.HUD_SCORE_END      = Color3.fromRGB(30, 110,  55)   -- deep green
Theme.HUD_CURRENCY_START = Color3.fromRGB(255, 210, 50)   -- bright gold
Theme.HUD_CURRENCY_END   = Color3.fromRGB(230, 150, 0)    -- deep amber
Theme.HUD_GLOW_CYAN      = Color3.fromRGB( 90, 210, 150)  -- timer glow (brighter green)
Theme.HUD_GLOW_GOLD      = Color3.fromRGB(255, 230, 100)  -- currency glow
Theme.HUD_GEM_START      = Color3.fromRGB(180,  80, 255)  -- bright purple (gem gradient)
Theme.HUD_GEM_END        = Color3.fromRGB(120,  40, 200)  -- deep purple (gem gradient)
Theme.HUD_GLOW_GEM       = Color3.fromRGB(200, 120, 255)  -- gem glow

-- ============================================================
-- PANEL GRADIENT + CARD SHADOW (light bright theme)
-- ============================================================
Theme.PANEL_GRAD_TOP = Color3.fromRGB(185, 225, 250)  -- sky blue (panel gradient top)
Theme.PANEL_GRAD_BTM = Color3.fromRGB(175, 235, 195)  -- soft green (panel gradient bottom)
Theme.CARD_SHADOW    = Color3.fromRGB(160, 170, 185)  -- soft shadow color

-- ============================================================
-- STRUCTURE TOKENS
-- ============================================================
-- Corner radius
Theme.CORNER_SM   = UDim.new(0, 10)   -- buttons, small badges
Theme.CORNER_MD   = UDim.new(0, 16)   -- HUD panels, cards
Theme.CORNER_LG   = UDim.new(0, 22)   -- modal containers
Theme.CORNER_FULL = UDim.new(1,  0)   -- circles / pills

-- Stroke thickness
Theme.STROKE_THIN = 1.5   -- default border
Theme.STROKE_MED  = 2.5   -- selected / focused
Theme.STROKE_BOLD = 4     -- emphasis / glow

-- Standard padding / spacing
Theme.PAD_SM = 6
Theme.PAD_MD = 10
Theme.PAD_LG = 16

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

--- Returns the rarity color for a given rarity string.
--- Use instead of ItemTypes.getRarityColor() in UI code.
function Theme.rarityColor(rarity: string): Color3
	if rarity == "Common" then
		return Theme.RARITY_COMMON
	elseif rarity == "Uncommon" then
		return Theme.RARITY_UNCOMMON
	elseif rarity == "Rare" then
		return Theme.RARITY_RARE
	elseif rarity == "Epic" then
		return Theme.RARITY_EPIC
	elseif rarity == "Legendary" then
		return Theme.RARITY_LEGENDARY
	end
	return Theme.RARITY_COMMON
end

--- Returns the class accent color for a given class ID string.
function Theme.classColor(classId: string): Color3
	if classId == "Runner" then
		return Theme.CLASS_RUNNER
	elseif classId == "Jumper" then
		return Theme.CLASS_JUMPER
	elseif classId == "Tank" then
		return Theme.CLASS_TANK
	end
	return Theme.CLASS_NORMAL
end

--- Darkens a bright color so it is readable as text on light backgrounds.
--- factor 0 = black, 1 = unchanged. Default 0.45.
function Theme.darkenForText(color: Color3, factor: number?): Color3
	local f = factor or 0.45
	return Color3.new(color.R * f, color.G * f, color.B * f)
end

--- Applies standard UICorner to a GuiObject.
--- size: "sm" | "md" | "lg" | "full"
function Theme.applyCorner(obj: GuiObject, size: string): UICorner
	local corner = Instance.new("UICorner")
	if size == "sm" then
		corner.CornerRadius = Theme.CORNER_SM
	elseif size == "lg" then
		corner.CornerRadius = Theme.CORNER_LG
	elseif size == "full" then
		corner.CornerRadius = Theme.CORNER_FULL
	else
		corner.CornerRadius = Theme.CORNER_MD
	end
	corner.Parent = obj
	return corner
end

--- Applies standard UIStroke to a GuiObject.
--- weight: "thin" | "med" | "bold"
function Theme.applyStroke(obj: GuiObject, color: Color3, weight: string?, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency or 0
	if weight == "med" then
		stroke.Thickness = Theme.STROKE_MED
	elseif weight == "bold" then
		stroke.Thickness = Theme.STROKE_BOLD
	else
		stroke.Thickness = Theme.STROKE_THIN
	end
	stroke.Parent = obj
	return stroke
end

return Theme
