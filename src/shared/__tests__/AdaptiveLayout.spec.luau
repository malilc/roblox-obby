local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

local AdaptiveLayout = require(ReplicatedStorage.Shared.AdaptiveLayout)

describe("AdaptiveLayout", function()

    -- ========== calculateHUDScale ==========

    describe("calculateHUDScale", function()

        -- Desktop 1920x1080, no GUI inset → scale should be exactly 1.0
        -- min(1920/1920, 1080/1080) = min(1.0, 1.0) = 1.0
        it("should return 1.0 for a full 1920x1080 desktop viewport", function()
            local result = AdaptiveLayout.calculateHUDScale(1920, 1080, 0)
            expect(result).toBe(1.0)
        end)

        -- Phone 375x667, guiInset=48 → min(375/1920, 619/1080) = min(0.195, 0.573) = 0.195 → clamped to MIN 0.4
        it("should clamp to MIN_SCALE 0.4 for a small phone viewport", function()
            local result = AdaptiveLayout.calculateHUDScale(375, 667, 48)
            expect(result).toBe(0.4)
        end)

        -- Tablet 810x1080, guiInset=36 → min(810/1920, 1044/1080) = min(0.421875, 0.9667) = 0.421875
        it("should return ~0.421 for a tablet 810x1080 viewport", function()
            local result = AdaptiveLayout.calculateHUDScale(810, 1080, 36)
            expect(result).toBeCloseTo(0.421875, 4)
        end)

    end)

    -- ========== calculateModalScale ==========

    describe("calculateModalScale", function()

        -- Modal 780x580 on desktop 1920x1080, guiInset=36
        -- safeW=1860, safeH=984 → min(1860/780, 984/580) = min(2.384, 1.696) = 1.696 → clamped to MAX 1.0
        it("should return 1.0 for a 780x580 modal on a desktop viewport", function()
            local result = AdaptiveLayout.calculateModalScale(1920, 1080, 36, 780, 580)
            expect(result).toBe(1.0)
        end)

        -- Modal 780x580 on phone 375x667, guiInset=48
        -- safeW=315, safeH=559 → min(315/780, 559/580) = min(0.4038, 0.9638) = 0.4038
        it("should return ~0.404 for a 780x580 modal on a phone viewport", function()
            local result = AdaptiveLayout.calculateModalScale(375, 667, 48, 780, 580)
            expect(result).toBeCloseTo(0.404, 2)
        end)

        -- Modal 360x380 on phone 375x667, guiInset=48
        -- safeW=315, safeH=559 → min(315/360, 559/380) = min(0.875, 1.471) = 0.875
        it("should return ~0.875 for a 360x380 modal on a phone viewport", function()
            local result = AdaptiveLayout.calculateModalScale(375, 667, 48, 360, 380)
            expect(result).toBeCloseTo(0.875, 3)
        end)

    end)

    -- ========== classifyDevice ==========

    describe("classifyDevice", function()

        -- safeH < 500 → Phone
        -- 375x520, guiInset=48 → safeH=472 < 500
        it("should return 'Phone' when safeH is below 500", function()
            local result = AdaptiveLayout.classifyDevice(375, 520, 48)
            expect(result).toBe("Phone")
        end)

        -- 500 <= safeH <= 900 → Tablet
        -- 810x736, guiInset=36 → safeH=700
        it("should return 'Tablet' when safeH is between 500 and 900", function()
            local result = AdaptiveLayout.classifyDevice(810, 736, 36)
            expect(result).toBe("Tablet")
        end)

        -- safeH > 900 → Desktop
        -- 1920x1080, guiInset=36 → safeH=1044
        it("should return 'Desktop' when safeH is above 900", function()
            local result = AdaptiveLayout.classifyDevice(1920, 1080, 36)
            expect(result).toBe("Desktop")
        end)

    end)

    -- ========== calculateZonePositions ==========

    describe("calculateZonePositions", function()

        -- BottomLeft anchor (0,1) with 3 visible elements stacking Up at scale 0.5
        -- yOffset = anchor (bottom) of each element; cursor tracks top edge
        -- order 1: 130x44, pad=8, scaledH=22 → pad=-8, yOff=-8, cursor=-30
        -- order 2: 160x28, pad=8, scaledH=14 → pad=-38, yOff=-38, cursor=-52
        -- order 3: 130x30, pad=8, scaledH=15 → pad=-60, yOff=-60, cursor=-75
        -- xOffset = +8 (left-anchored, xSign=1)
        it("should stack 3 elements upward from BottomLeft with correct Y offsets", function()
            local elements = {
                { order = 1, designWidth = 130, designHeight = 44, padding = 8, visible = true },
                { order = 2, designWidth = 160, designHeight = 28, padding = 8, visible = true },
                { order = 3, designWidth = 130, designHeight = 30, padding = 8, visible = true },
            }
            local positions = AdaptiveLayout.calculateZonePositions("BottomLeft", elements, 0.5, 375, 667)
            expect(#positions).toBe(3)
            expect(positions[1].y).toBe(-8)
            expect(positions[2].y).toBe(-38)
            expect(positions[3].y).toBe(-60)
            expect(positions[1].x).toBe(8)
            expect(positions[1].anchorX).toBe(0)
            expect(positions[1].anchorY).toBe(1)
        end)

        -- Same 3 elements but order 2 has visible=false — should be skipped
        -- order 1: scaledH=22, pad=8 → yOff=-8, cursor=-30
        -- order 3: scaledH=15, pad=8 → yOff=-38, cursor=-53
        it("should skip invisible elements and still produce correct Y offsets", function()
            local elements = {
                { order = 1, designWidth = 130, designHeight = 44, padding = 8, visible = true },
                { order = 2, designWidth = 160, designHeight = 28, padding = 8, visible = false },
                { order = 3, designWidth = 130, designHeight = 30, padding = 8, visible = true },
            }
            local positions = AdaptiveLayout.calculateZonePositions("BottomLeft", elements, 0.5, 375, 667)
            expect(#positions).toBe(2)
            expect(positions[1].y).toBe(-8)
            expect(positions[2].y).toBe(-38)
        end)

        -- TopRight anchor (1,0) stacking Down at scale 0.55
        -- 1 element: 200x300, pad=8
        -- cursor 0 + 8 = 8, y=8, then cursor += 300*0.55 = 165
        -- xOffset = -8 (right-anchored, xSign=-1)
        it("should place 1 element at TopRight with negative X offset and positive Y offset", function()
            local elements = {
                { order = 1, designWidth = 200, designHeight = 300, padding = 8, visible = true },
            }
            local positions = AdaptiveLayout.calculateZonePositions("TopRight", elements, 0.55, 1920, 1080)
            expect(#positions).toBe(1)
            expect(positions[1].y).toBe(8)
            expect(positions[1].x).toBe(-8)
            expect(positions[1].anchorX).toBe(1)
            expect(positions[1].anchorY).toBe(0)
        end)

    end)

end)
