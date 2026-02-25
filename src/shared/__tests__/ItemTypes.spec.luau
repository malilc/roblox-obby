local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

local ItemTypes = require(ReplicatedStorage.Shared.ItemTypes)

describe("ItemTypes", function()
	describe("getItem", function()
		it("should return Missile as Common", function()
			local item = ItemTypes.getItem("Missile")
			expect(item).toBeDefined()
			expect(item.id).toBe("Missile")
			expect(item.rarity).toBe("Common")
		end)

		it("should return Lightning as Epic", function()
			local item = ItemTypes.getItem("Lightning")
			expect(item).toBeDefined()
			expect(item.rarity).toBe("Epic")
		end)

		it("should return Swap as Rare", function()
			local item = ItemTypes.getItem("Swap")
			expect(item).toBeDefined()
			expect(item.rarity).toBe("Rare")
		end)

		it("should return nil for non-existent item", function()
			local item = ItemTypes.getItem("NonExistent")
			expect(item).toBeNil()
		end)
	end)

	describe("getItemsByRarity", function()
		it("should return 2 Common items", function()
			local items = ItemTypes.getItemsByRarity("Common")
			expect(#items).toBe(2)
		end)

		it("should return 2 Uncommon items", function()
			local items = ItemTypes.getItemsByRarity("Uncommon")
			expect(#items).toBe(2)
		end)

		it("should return 1 Rare item", function()
			local items = ItemTypes.getItemsByRarity("Rare")
			expect(#items).toBe(1)
		end)

		it("should return 1 Epic item", function()
			local items = ItemTypes.getItemsByRarity("Epic")
			expect(#items).toBe(1)
		end)

		it("should return empty for invalid rarity", function()
			local items = ItemTypes.getItemsByRarity("Mythic")
			expect(#items).toBe(0)
		end)
	end)

	describe("getRarityColor", function()
		it("should return gray for Common", function()
			local color = ItemTypes.getRarityColor("Common")
			expect(color).toBeDefined()
			expect(color.R).toBeCloseTo(200 / 255, 2)
			expect(color.G).toBeCloseTo(200 / 255, 2)
			expect(color.B).toBeCloseTo(200 / 255, 2)
		end)

		it("should return green-ish for Uncommon", function()
			local color = ItemTypes.getRarityColor("Uncommon")
			expect(color.G).toBeGreaterThan(color.R)
		end)

		it("should return blue-ish for Rare", function()
			local color = ItemTypes.getRarityColor("Rare")
			expect(color.B).toBeGreaterThan(color.R)
		end)

		it("should return purple-ish for Epic", function()
			local color = ItemTypes.getRarityColor("Epic")
			expect(color.R).toBeGreaterThan(color.G)
			expect(color.B).toBeGreaterThan(color.G)
		end)

		it("should fallback to white for unknown rarity", function()
			local color = ItemTypes.getRarityColor("Unknown")
			expect(color.R).toBeCloseTo(1, 2)
			expect(color.G).toBeCloseTo(1, 2)
			expect(color.B).toBeCloseTo(1, 2)
		end)
	end)

	describe("getRarityName", function()
		it("should return correct names", function()
			expect(ItemTypes.getRarityName("Common")).toBe("Common")
			expect(ItemTypes.getRarityName("Uncommon")).toBe("Uncommon")
			expect(ItemTypes.getRarityName("Rare")).toBe("Rare")
			expect(ItemTypes.getRarityName("Epic")).toBe("Epic")
		end)

		it("should return Unknown for invalid rarity", function()
			expect(ItemTypes.getRarityName("Mythic")).toBe("Unknown")
		end)
	end)

	describe("getWeightedRandomItem", function()
		it("should always return a valid item", function()
			for _ = 1, 20 do
				local item = ItemTypes.getWeightedRandomItem(1, 4)
				expect(item).toBeDefined()
				expect(item.id).toBeDefined()
				expect(item.rarity).toBeDefined()
			end
		end)

		it("should return items with valid rarity", function()
			local validRarities = { Common = true, Uncommon = true, Rare = true, Epic = true }
			for _ = 1, 50 do
				local item = ItemTypes.getWeightedRandomItem(3, 4)
				expect(validRarities[item.rarity]).toBe(true)
			end
		end)
	end)
end)
