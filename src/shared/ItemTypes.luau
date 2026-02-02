-- ItemTypes: นิยาม Item ทั้งหมดสำหรับเกม (แบบ Mario Kart)

export type ItemRarity = "Common" | "Uncommon" | "Rare" | "Epic"

export type ItemDefinition = {
	id: string,
	name: string,
	description: string,
	icon: string,
	rarity: ItemRarity,
	-- Weighted probability (สูง = โอกาสได้มากกว่า)
	weight: number,
	-- Bonus weight สำหรับคนอันดับท้าย (เช่น +5 weight ต่อทุกๆ อันดับที่ห่างจากที่ 1)
	catchUpBonus: number,
	-- Duration ของ effect (ถ้ามี)
	duration: number?,
	-- Cooldown หลังใช้
	cooldown: number,
}

local ItemTypes = {}

-- Item definitions (using emoji text icons for reliability)
ItemTypes.Items = {
	-- ========== COMMON ITEMS (พบบ่อย) ==========
	
	Missile = {
		id = "Missile",
		name = "Missile",
		description = "Fire a homing missile that tracks the nearest target ahead!",
		icon = "🚀", -- rocket emoji
		rarity = "Common",
		weight = 25,
		catchUpBonus = 0,
		duration = nil,
		cooldown = 1,
		-- Effect specifics
		speed = 60, -- studs/second (slower for homing)
		stunDuration = 2, -- seconds
		range = 150, -- max range
		-- Homing parameters
		turnSpeed = 6, -- How fast missile turns (higher = tighter tracking)
		viewConeAngle = 90, -- Degrees from center (180 degree total cone)
		trackingRange = 120, -- Max distance to acquire target
	},
	
	Banana = {
		id = "Banana",
		name = "Banana",
		description = "Drop a banana behind you. Makes players slip!",
		icon = "🍌", -- banana emoji
		rarity = "Common",
		weight = 25,
		catchUpBonus = 0,
		duration = 30,
		cooldown = 0.5,
		-- Effect specifics
		slipDuration = 1.5, -- seconds
		knockbackForce = 50,
	},
	
	-- ========== UNCOMMON ITEMS ==========
	
	Shield = {
		id = "Shield",
		name = "Shield",
		description = "Create a shield that blocks 1 attack.",
		icon = "🛡️", -- shield emoji
		rarity = "Uncommon",
		weight = 20,
		catchUpBonus = 1,
		duration = 15,
		cooldown = 0.5,
		-- Effect specifics
		blocksCount = 1,
	},
	
	SpeedBoost = {
		id = "SpeedBoost",
		name = "Speed Boost",
		description = "+50% speed for 3 seconds!",
		icon = "⚡", -- lightning bolt emoji
		rarity = "Uncommon",
		weight = 18,
		catchUpBonus = 2,
		duration = 3, -- seconds
		cooldown = 0.5,
		-- Effect specifics
		speedMultiplier = 1.5,
		jumpMultiplier = 1.2,
	},
	
	-- ========== RARE ITEMS ==========
	
	Swap = {
		id = "Swap",
		name = "Swap",
		description = "Swap positions with the nearest player ahead of you!",
		icon = "🔄", -- swap arrows emoji
		rarity = "Rare",
		weight = 8,
		catchUpBonus = 5,
		duration = nil,
		cooldown = 2,
		-- Effect specifics
		swapDelay = 0.5,
	},
	
	-- ========== EPIC ITEMS ==========
	
	Lightning = {
		id = "Lightning",
		name = "Lightning",
		description = "Slows ALL other players for 3 sec!",
		icon = "⚡🌩️", -- lightning bolt emoji
		rarity = "Epic",
		weight = 4,
		catchUpBonus = 8,
		duration = 3, -- seconds
		cooldown = 1,
		-- Effect specifics
		slowMultiplier = 0.5,
		shrinkScale = 0.7,
	},
}

-- Get item by ID
function ItemTypes.getItem(itemId: string): ItemDefinition?
	return ItemTypes.Items[itemId]
end

-- Get all item IDs
function ItemTypes.getAllItemIds(): {string}
	local ids = {}
	for id, _ in pairs(ItemTypes.Items) do
		table.insert(ids, id)
	end
	return ids
end

-- Get items by rarity
function ItemTypes.getItemsByRarity(rarity: ItemRarity): {ItemDefinition}
	local items = {}
	for _, item in pairs(ItemTypes.Items) do
		if item.rarity == rarity then
			table.insert(items, item)
		end
	end
	return items
end

-- Calculate weighted random selection based on player rank
function ItemTypes.getWeightedRandomItem(playerRank: number, totalPlayers: number): ItemDefinition
	-- Calculate catch-up factor (0 for 1st place, higher for lower ranks)
	local rankFromLast = totalPlayers - playerRank + 1
	local catchUpFactor = math.max(0, rankFromLast - 1) -- 0 for 1st, 1 for 2nd, etc.
	
	-- Build weighted pool
	local weightedPool = {}
	local totalWeight = 0
	
	for _, item in pairs(ItemTypes.Items) do
		local weight = item.weight + (item.catchUpBonus * catchUpFactor)
		totalWeight = totalWeight + weight
		table.insert(weightedPool, {
			item = item,
			weight = weight,
			cumulativeWeight = totalWeight,
		})
	end
	
	-- Random selection
	local roll = math.random() * totalWeight
	
	for _, entry in ipairs(weightedPool) do
		if roll <= entry.cumulativeWeight then
			return entry.item
		end
	end
	
	-- Fallback (should never happen)
	return ItemTypes.Items.Missile
end

-- Get rarity color
function ItemTypes.getRarityColor(rarity: ItemRarity): Color3
	if rarity == "Common" then
		return Color3.fromRGB(200, 200, 200) -- Gray/White
	elseif rarity == "Uncommon" then
		return Color3.fromRGB(100, 200, 100) -- Green
	elseif rarity == "Rare" then
		return Color3.fromRGB(100, 150, 255) -- Blue
	elseif rarity == "Epic" then
		return Color3.fromRGB(200, 100, 255) -- Purple
	end
	return Color3.fromRGB(255, 255, 255)
end

-- Get rarity display name
function ItemTypes.getRarityName(rarity: ItemRarity): string
	if rarity == "Common" then
		return "Common"
	elseif rarity == "Uncommon" then
		return "Uncommon"
	elseif rarity == "Rare" then
		return "Rare"
	elseif rarity == "Epic" then
		return "Epic"
	end
	return "Unknown"
end

return ItemTypes
