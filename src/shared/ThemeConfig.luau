-- ThemeConfig.luau
-- Central design token file for Fall Guys-style UI
-- All UI files MUST require this and use these tokens instead of inline Color3 values
--
-- Usage:
--   local Theme = require(ReplicatedStorage.Shared.ThemeConfig)
--   frame.BackgroundColor3 = Theme.BG_BASE

local Theme = {}

-- ============================================================
-- BACKGROUNDS (deep purple family)
-- ============================================================
Theme.BG_BASE     = Color3.fromRGB(45,  30,  75)   -- main panel background
Theme.BG_SURFACE  = Color3.fromRGB(65,  50, 105)   -- card / section background
Theme.BG_ELEVATED = Color3.fromRGB(85,  68, 135)   -- hover / selected state
Theme.BG_OVERLAY  = Color3.fromRGB(25,  15,  50)   -- modal dim overlay / darkest bg

-- ============================================================
-- BRAND COLORS
-- ============================================================
Theme.PRIMARY      = Color3.fromRGB(255, 220,   0)  -- bright yellow — main CTA buttons
Theme.PRIMARY_DARK = Color3.fromRGB(200, 165,   0)  -- darker yellow — hover / pressed
Theme.SECONDARY    = Color3.fromRGB(255,  85,  50)  -- orange-red — destructive / energy
Theme.ACCENT_CYAN  = Color3.fromRGB( 80, 220, 255)  -- cyan — info / highlight
Theme.ACCENT_PINK  = Color3.fromRGB(255, 100, 180)  -- pink — fun accent / special

-- ============================================================
-- TEXT
-- ============================================================
Theme.TEXT_PRIMARY = Color3.fromRGB(255, 255, 255)  -- white — on any dark background
Theme.TEXT_MUTED   = Color3.fromRGB(195, 178, 230)  -- light purple-white — secondary text
Theme.TEXT_DARK    = Color3.fromRGB( 45,  30,  75)  -- dark purple — for light backgrounds (rare)

-- ============================================================
-- SEMANTIC COLORS
-- ============================================================
Theme.SUCCESS = Color3.fromRGB( 80, 230, 120)  -- bright green — equip, success, positive
Theme.DANGER  = Color3.fromRGB(255,  70,  70)  -- bright red — leave, locked, danger
Theme.WARNING = Color3.fromRGB(255, 200,   0)  -- yellow — time warning, can-buy state
Theme.INFO    = Color3.fromRGB( 80, 200, 255)  -- cyan — info, mastery progress

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
Theme.HUD_SCORE_START    = Color3.fromRGB(40, 180, 255)   -- bright cyan
Theme.HUD_SCORE_END      = Color3.fromRGB(20, 80, 200)    -- deep blue
Theme.HUD_CURRENCY_START = Color3.fromRGB(255, 210, 50)   -- bright gold
Theme.HUD_CURRENCY_END   = Color3.fromRGB(230, 150, 0)    -- deep amber
Theme.HUD_GLOW_CYAN      = Color3.fromRGB(100, 230, 255)  -- score glow
Theme.HUD_GLOW_GOLD      = Color3.fromRGB(255, 230, 100)  -- currency glow

-- ============================================================
-- STRUCTURE TOKENS
-- ============================================================
-- Corner radius
Theme.CORNER_SM   = UDim.new(0,  8)   -- buttons, small badges
Theme.CORNER_MD   = UDim.new(0, 14)   -- HUD panels, cards
Theme.CORNER_LG   = UDim.new(0, 20)   -- modal containers
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
