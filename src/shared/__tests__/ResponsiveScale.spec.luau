local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)

describe("ResponsiveScale", function()

	describe("calculateScale", function()

		-- Test 1: Desktop viewport, small modal -> 1.0
		it("should return 1.0 for desktop viewport with small modal", function()
			local result = ResponsiveScale.calculateScale(1920, 1080, 36, 360, 380)
			expect(result).toBe(1.0)
		end)

		-- Test 2: Desktop viewport, large modal -> 1.0
		it("should return 1.0 for desktop viewport with large modal", function()
			local result = ResponsiveScale.calculateScale(1920, 1080, 36, 780, 580)
			expect(result).toBe(1.0)
		end)

		-- Test 3: Mobile viewport, small modal -> constrained by width
		it("should return correct scale for mobile viewport with small modal", function()
			-- min of (414-80)/360=0.928, (736-36-80)/380=1.631 -> 0.928
			local result = ResponsiveScale.calculateScale(414, 736, 36, 360, 380)
			expect(result).toBeCloseTo(0.928, 2)
		end)

		-- Test 4: Mobile viewport, thin wide modal -> constrained by width
		it("should return correct scale for mobile viewport with wide thin modal", function()
			-- min of (414-80)/400=0.835, (736-36-80)/44>>1 -> 0.835
			local result = ResponsiveScale.calculateScale(414, 736, 36, 400, 44)
			expect(result).toBeCloseTo(0.835, 2)
		end)

		-- Test 5: Tiny viewport -> clamped to floor of 0.5
		it("should clamp to minimum scale floor of 0.5 for tiny viewport", function()
			local result = ResponsiveScale.calculateScale(200, 200, 36, 360, 380)
			expect(result).toBe(0.5)
		end)

		-- Test 6: Both axes constrain -> clamped to floor
		it("should clamp to 0.5 when both axes are constrained below floor", function()
			local result = ResponsiveScale.calculateScale(300, 300, 36, 360, 380)
			expect(result).toBe(0.5)
		end)

		-- Test 7: Viewport exactly matching design+padding -> 1.0
		it("should return 1.0 when viewport exactly matches design plus padding", function()
			-- (440-80)/360=1.0, (460-0-80)/380=1.0 -> 1.0
			local result = ResponsiveScale.calculateScale(440, 460, 0, 360, 380)
			expect(result).toBe(1.0)
		end)

		-- Test 8: Oversized viewport -> capped at 1.0
		it("should never exceed 1.0 even with oversized viewport", function()
			local result = ResponsiveScale.calculateScale(3840, 2160, 36, 360, 380)
			expect(result).toBe(1.0)
		end)

	end)

	describe("compensateStrokes", function()

		-- Helper: create a frame with UIStroke children for testing
		local function createTestFrame(strokeThicknesses: {number}): (Frame, {UIStroke})
			local frame = Instance.new("Frame")
			local strokes = {}
			for _, thickness in ipairs(strokeThicknesses) do
				local stroke = Instance.new("UIStroke")
				stroke.Thickness = thickness
				stroke.Parent = frame
				table.insert(strokes, stroke)
			end
			return frame, strokes
		end

		-- Test 1: scale 0.7 reduces a 2.5-thickness stroke to 1.75
		it("should reduce stroke thickness proportionally with scale 0.7", function()
			local frame, strokes = createTestFrame({ 2.5 })
			ResponsiveScale.compensateStrokes(frame, 0.7)
			expect(strokes[1].Thickness).toBeCloseTo(1.75, 2)
			frame:Destroy()
		end)

		-- Test 2: scale 1.0 leaves thickness unchanged
		it("should leave thickness unchanged at scale 1.0", function()
			local frame, strokes = createTestFrame({ 2.5, 4.0, 1.5 })
			ResponsiveScale.compensateStrokes(frame, 1.0)
			expect(strokes[1].Thickness).toBeCloseTo(2.5, 2)
			expect(strokes[2].Thickness).toBeCloseTo(4.0, 2)
			expect(strokes[3].Thickness).toBeCloseTo(1.5, 2)
			frame:Destroy()
		end)

		-- Test 3: scale 0.5 (floor) reduces a 4.0-thickness stroke to 2.0
		it("should reduce stroke thickness at scale floor 0.5", function()
			local frame, strokes = createTestFrame({ 4.0 })
			ResponsiveScale.compensateStrokes(frame, 0.5)
			expect(strokes[1].Thickness).toBeCloseTo(2.0, 2)
			frame:Destroy()
		end)

		-- Test 4: calling compensateStrokes twice on same frame does not double-compensate
		it("should not double-compensate when called twice on same frame", function()
			local frame, strokes = createTestFrame({ 2.5 })
			ResponsiveScale.compensateStrokes(frame, 0.7)
			expect(strokes[1].Thickness).toBeCloseTo(1.75, 2)
			-- Call again with same scale — should use original thickness, not modified
			ResponsiveScale.compensateStrokes(frame, 0.7)
			expect(strokes[1].Thickness).toBeCloseTo(1.75, 2)
			frame:Destroy()
		end)

	end)

end)
