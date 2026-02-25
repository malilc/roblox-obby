local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

local ClassTypes = require(ReplicatedStorage.Shared.ClassTypes)

describe("ClassTypes", function()
	describe("getClass", function()
		it("should return Normal class", function()
			local class = ClassTypes.getClass("Normal")
			expect(class).toBeDefined()
			expect(class.id).toBe("Normal")
			expect(class.walkSpeedMod).toBe(1.00)
			expect(class.jumpPowerMod).toBe(1.00)
		end)

		it("should return Runner with correct modifiers", function()
			local class = ClassTypes.getClass("Runner")
			expect(class).toBeDefined()
			expect(class.walkSpeedMod).toBe(1.15)
			expect(class.jumpPowerMod).toBe(0.90)
			expect(class.knockbackResistance).toBe(0)
		end)

		it("should return Jumper with correct modifiers", function()
			local class = ClassTypes.getClass("Jumper")
			expect(class).toBeDefined()
			expect(class.walkSpeedMod).toBe(0.90)
			expect(class.jumpPowerMod).toBe(1.20)
		end)

		it("should return Tank with knockback resistance", function()
			local class = ClassTypes.getClass("Tank")
			expect(class).toBeDefined()
			expect(class.walkSpeedMod).toBe(0.85)
			expect(class.knockbackResistance).toBe(0.5)
		end)

		it("should return nil for invalid class ID", function()
			local class = ClassTypes.getClass("FakeClass")
			expect(class).toBeNil()
		end)
	end)

	describe("getAllClassIds", function()
		it("should return 4 classes", function()
			local ids = ClassTypes.getAllClassIds()
			expect(#ids).toBe(4)
		end)

		it("should follow ClassOrder", function()
			local ids = ClassTypes.getAllClassIds()
			expect(ids[1]).toBe("Normal")
			expect(ids[2]).toBe("Runner")
			expect(ids[3]).toBe("Jumper")
			expect(ids[4]).toBe("Tank")
		end)
	end)

	describe("calculateStats", function()
		it("should return unmodified stats for Normal", function()
			local speed, jump = ClassTypes.calculateStats("Normal", 16, 50)
			expect(speed).toBe(16)
			expect(jump).toBe(50)
		end)

		it("should apply Runner speed boost and jump penalty", function()
			local speed, jump = ClassTypes.calculateStats("Runner", 16, 50)
			expect(speed).toBeCloseTo(18.4, 1) -- 16 * 1.15
			expect(jump).toBeCloseTo(45, 1) -- 50 * 0.90
		end)

		it("should apply Jumper jump boost and speed penalty", function()
			local speed, jump = ClassTypes.calculateStats("Jumper", 16, 50)
			expect(speed).toBeCloseTo(14.4, 1) -- 16 * 0.90
			expect(jump).toBeCloseTo(60, 1) -- 50 * 1.20
		end)

		it("should apply Tank speed penalty", function()
			local speed, jump = ClassTypes.calculateStats("Tank", 16, 50)
			expect(speed).toBeCloseTo(13.6, 1) -- 16 * 0.85
			expect(jump).toBe(50) -- 1.00
		end)

		it("should return base stats for unknown class", function()
			local speed, jump = ClassTypes.calculateStats("Unknown", 16, 50)
			expect(speed).toBe(16)
			expect(jump).toBe(50)
		end)
	end)

	describe("getClassDisplayInfo", function()
		it("should return display info for Runner with speed stat", function()
			local info = ClassTypes.getClassDisplayInfo("Runner")
			expect(info).toBeDefined()
			expect(info.name).toBe("Runner")
			-- Runner has walkSpeedMod=1.15 (+15%) and jumpPowerMod=0.90 (-10%)
			expect(#info.stats).toBe(2)
		end)

		it("should include KB Resist for Tank", function()
			local info = ClassTypes.getClassDisplayInfo("Tank")
			expect(info).toBeDefined()
			local hasKB = false
			for _, stat in ipairs(info.stats) do
				if string.find(stat, "KB Resist") then
					hasKB = true
				end
			end
			expect(hasKB).toBe(true)
		end)

		it("should return no stats for Normal (all 1.0x)", function()
			local info = ClassTypes.getClassDisplayInfo("Normal")
			expect(info).toBeDefined()
			expect(#info.stats).toBe(0)
		end)

		it("should return nil for invalid class", function()
			local info = ClassTypes.getClassDisplayInfo("FakeClass")
			expect(info).toBeNil()
		end)
	end)
end)
