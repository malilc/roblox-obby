local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

local GamePassLogic = require(ReplicatedStorage.Shared.GamePassLogic)

describe("GamePassLogic", function()

	-- ========== isValidPassId ==========
	describe("isValidPassId", function()
		it("should return true for DoubleCoin", function()
			expect(GamePassLogic.isValidPassId("DoubleCoin")).toBe(true)
		end)

		it("should return true for VIP", function()
			expect(GamePassLogic.isValidPassId("VIP")).toBe(true)
		end)

		it("should return true for ExtraSlot", function()
			expect(GamePassLogic.isValidPassId("ExtraSlot")).toBe(true)
		end)

		it("should return true for DoubleXP", function()
			expect(GamePassLogic.isValidPassId("DoubleXP")).toBe(true)
		end)

		it("should return false for empty string", function()
			expect(GamePassLogic.isValidPassId("")).toBe(false)
		end)

		it("should return false for unknown id", function()
			expect(GamePassLogic.isValidPassId("SuperPower")).toBe(false)
		end)
	end)

	-- ========== getPassIdByGamePassId ==========
	describe("getPassIdByGamePassId", function()
		it("should find DoubleCoin from numeric id", function()
			expect(GamePassLogic.getPassIdByGamePassId(1740745787)).toBe("DoubleCoin")
		end)

		it("should find VIP from numeric id", function()
			expect(GamePassLogic.getPassIdByGamePassId(1741108491)).toBe("VIP")
		end)

		it("should return nil for 0", function()
			expect(GamePassLogic.getPassIdByGamePassId(0)).toBeNil()
		end)

		it("should return nil for non-existent id", function()
			expect(GamePassLogic.getPassIdByGamePassId(9999999)).toBeNil()
		end)
	end)

	-- ========== hasGamePass ==========
	describe("hasGamePass", function()
		it("should return false when passesMap is nil", function()
			expect(GamePassLogic.hasGamePass(nil, "DoubleCoin")).toBe(false)
		end)

		it("should return false when passesMap is empty", function()
			expect(GamePassLogic.hasGamePass({}, "DoubleCoin")).toBe(false)
		end)

		it("should return true when explicitly true", function()
			expect(GamePassLogic.hasGamePass({ DoubleCoin = true }, "DoubleCoin")).toBe(true)
		end)

		it("should return false when explicitly false (test toggle OFF)", function()
			expect(GamePassLogic.hasGamePass({ DoubleCoin = false }, "DoubleCoin")).toBe(false)
		end)

		it("should return false for unset passId", function()
			expect(GamePassLogic.hasGamePass({ VIP = true }, "DoubleCoin")).toBe(false)
		end)
	end)

	-- ========== resolveOwnership ==========
	describe("resolveOwnership", function()
		it("should return empty table for empty input", function()
			local result = GamePassLogic.resolveOwnership({})
			expect(next(result)).toBeNil()
		end)

		it("should preserve saved passes", function()
			local result = GamePassLogic.resolveOwnership({
				savedPasses = { DoubleCoin = true, VIP = true },
			})
			expect(result.DoubleCoin).toBe(true)
			expect(result.VIP).toBe(true)
		end)

		it("should set true when API says owned", function()
			local result = GamePassLogic.resolveOwnership({
				apiResults = { DoubleCoin = true },
			})
			expect(result.DoubleCoin).toBe(true)
		end)

		it("should keep saved=false + API=true + debug ON → stays false (test override wins)", function()
			local result = GamePassLogic.resolveOwnership({
				savedPasses = { DoubleCoin = false },
				apiResults = { DoubleCoin = true },
				debugEnabled = true,
			})
			expect(result.DoubleCoin).toBe(false)
		end)

		it("should set saved=false + API=true + debug OFF → becomes true (API wins)", function()
			local result = GamePassLogic.resolveOwnership({
				savedPasses = { DoubleCoin = false },
				apiResults = { DoubleCoin = true },
				debugEnabled = false,
			})
			expect(result.DoubleCoin).toBe(true)
		end)

		it("should handle mixed scenario with 4 passes", function()
			local result = GamePassLogic.resolveOwnership({
				savedPasses = {
					DoubleCoin = true,
					VIP = false,
					ExtraSlot = false,
					DoubleXP = true,
				},
				apiResults = {
					DoubleCoin = true,
					VIP = true,
					ExtraSlot = true,
				},
				debugEnabled = true,
			})
			-- DoubleCoin: saved=true, API=true → true
			expect(result.DoubleCoin).toBe(true)
			-- VIP: saved=false (test OFF), API=true, debug ON → false (override wins)
			expect(result.VIP).toBe(false)
			-- ExtraSlot: saved=false (test OFF), API=true, debug ON → false (override wins)
			expect(result.ExtraSlot).toBe(false)
			-- DoubleXP: saved=true, no API result → true
			expect(result.DoubleXP).toBe(true)
		end)

		it("should handle mixed scenario with debug OFF", function()
			local result = GamePassLogic.resolveOwnership({
				savedPasses = {
					DoubleCoin = true,
					VIP = false,
				},
				apiResults = {
					VIP = true,
				},
				debugEnabled = false,
			})
			expect(result.DoubleCoin).toBe(true)
			expect(result.VIP).toBe(true) -- API wins when debug OFF
		end)

		it("should not mutate input savedPasses table", function()
			local saved = { DoubleCoin = false }
			GamePassLogic.resolveOwnership({
				savedPasses = saved,
				apiResults = { DoubleCoin = true },
				debugEnabled = false,
			})
			-- Original table must remain unchanged
			expect(saved.DoubleCoin).toBe(false)
		end)

		it("should not mutate input apiResults table", function()
			local api = { DoubleCoin = true }
			GamePassLogic.resolveOwnership({
				savedPasses = {},
				apiResults = api,
				debugEnabled = false,
			})
			expect(api.DoubleCoin).toBe(true)
			expect(api.VIP).toBeNil()
		end)

		it("should handle nil savedPasses and nil apiResults", function()
			local result = GamePassLogic.resolveOwnership({
				debugEnabled = true,
			})
			expect(next(result)).toBeNil()
		end)

		it("should handle API result with false value (not owned)", function()
			local result = GamePassLogic.resolveOwnership({
				apiResults = { DoubleCoin = false, VIP = true },
			})
			-- false API result should not override anything
			expect(result.DoubleCoin).toBeNil()
			expect(result.VIP).toBe(true)
		end)

		it("should only snapshot false values as overrides (true values unaffected)", function()
			local result = GamePassLogic.resolveOwnership({
				savedPasses = { DoubleCoin = true, VIP = false },
				apiResults = { DoubleCoin = true, VIP = true },
				debugEnabled = true,
			})
			-- DoubleCoin was saved as true → no override → stays true
			expect(result.DoubleCoin).toBe(true)
			-- VIP was saved as false → override → stays false despite API
			expect(result.VIP).toBe(false)
		end)
	end)

	-- ========== getCoinMultiplier ==========
	describe("getCoinMultiplier", function()
		it("should return 1 for nil passes", function()
			expect(GamePassLogic.getCoinMultiplier(nil)).toBe(1)
		end)

		it("should return 1 for empty passes", function()
			expect(GamePassLogic.getCoinMultiplier({})).toBe(1)
		end)

		it("should return 2 with DoubleCoin", function()
			expect(GamePassLogic.getCoinMultiplier({ DoubleCoin = true })).toBe(2)
		end)

		it("should return 1.5 with VIP only", function()
			expect(GamePassLogic.getCoinMultiplier({ VIP = true })).toBe(1.5)
		end)

		it("should return 2.5 with DoubleCoin + VIP", function()
			expect(GamePassLogic.getCoinMultiplier({ DoubleCoin = true, VIP = true })).toBe(2.5)
		end)

		it("should not be affected by DoubleXP or ExtraSlot", function()
			expect(GamePassLogic.getCoinMultiplier({ DoubleXP = true, ExtraSlot = true })).toBe(1)
		end)
	end)

	-- ========== getXPMultiplier ==========
	describe("getXPMultiplier", function()
		it("should return 1 for nil passes", function()
			expect(GamePassLogic.getXPMultiplier(nil)).toBe(1)
		end)

		it("should return 2 with DoubleXP", function()
			expect(GamePassLogic.getXPMultiplier({ DoubleXP = true })).toBe(2)
		end)

		it("should return 1.5 with VIP only", function()
			expect(GamePassLogic.getXPMultiplier({ VIP = true })).toBe(1.5)
		end)

		it("should return 2.5 with DoubleXP + VIP", function()
			expect(GamePassLogic.getXPMultiplier({ DoubleXP = true, VIP = true })).toBe(2.5)
		end)

		it("should not be affected by DoubleCoin or ExtraSlot", function()
			expect(GamePassLogic.getXPMultiplier({ DoubleCoin = true, ExtraSlot = true })).toBe(1)
		end)
	end)

	-- ========== getMaxItemSlots ==========
	describe("getMaxItemSlots", function()
		it("should return 2 for nil passes", function()
			expect(GamePassLogic.getMaxItemSlots(nil)).toBe(2)
		end)

		it("should return 2 for empty passes", function()
			expect(GamePassLogic.getMaxItemSlots({})).toBe(2)
		end)

		it("should return 3 with ExtraSlot", function()
			expect(GamePassLogic.getMaxItemSlots({ ExtraSlot = true })).toBe(3)
		end)

		it("should return 2 when ExtraSlot is false", function()
			expect(GamePassLogic.getMaxItemSlots({ ExtraSlot = false })).toBe(2)
		end)
	end)

	-- ========== isRateLimited ==========
	describe("isRateLimited", function()
		it("should return false when lastTime is nil", function()
			expect(GamePassLogic.isRateLimited(nil, 100, 0.5)).toBe(false)
		end)

		it("should return false when past cooldown", function()
			expect(GamePassLogic.isRateLimited(99, 100, 0.5)).toBe(false)
		end)

		it("should return true when within cooldown", function()
			expect(GamePassLogic.isRateLimited(99.8, 100, 0.5)).toBe(true)
		end)

		it("should return false when exactly at cooldown boundary", function()
			expect(GamePassLogic.isRateLimited(99.5, 100, 0.5)).toBe(false)
		end)
	end)
end)
