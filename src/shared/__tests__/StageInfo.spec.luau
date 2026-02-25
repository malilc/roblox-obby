local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local it = JestGlobals.it
local expect = JestGlobals.expect

local StageInfo = require(ReplicatedStorage.Shared.StageInfo)

describe("StageInfo", function()
	describe("getStage", function()
		it("should return stage 1 as Jump (Easy)", function()
			local stage = StageInfo.getStage(1)
			expect(stage).toBeDefined()
			expect(stage.id).toBe(1)
			expect(stage.name).toBe("Jump")
			expect(stage.difficulty).toBe("Easy")
			expect(stage.reward).toBe(3)
		end)

		it("should return stage 4 as Disappear (Hard)", function()
			local stage = StageInfo.getStage(4)
			expect(stage).toBeDefined()
			expect(stage.name).toBe("Disappear")
			expect(stage.difficulty).toBe("Hard")
			expect(stage.reward).toBe(5)
		end)

		it("should return stage 7 as Narrow (Hard)", function()
			local stage = StageInfo.getStage(7)
			expect(stage).toBeDefined()
			expect(stage.name).toBe("Narrow")
			expect(stage.difficulty).toBe("Hard")
			expect(stage.reward).toBe(7)
		end)

		it("should return nil for stage 0", function()
			expect(StageInfo.getStage(0)).toBeNil()
		end)

		it("should return nil for out-of-range stage", function()
			expect(StageInfo.getStage(100)).toBeNil()
		end)

		it("should have positive reward for every stage", function()
			for i = 1, StageInfo.getTotalStageCount() do
				local stage = StageInfo.getStage(i)
				expect(stage.reward).toBeGreaterThan(0)
			end
		end)
	end)

	describe("getStagesByDifficulty", function()
		it("should return 1 Easy stage", function()
			local stages = StageInfo.getStagesByDifficulty("Easy")
			expect(#stages).toBe(1)
			expect(stages[1].name).toBe("Jump")
		end)

		it("should return 2 Normal stages", function()
			local stages = StageInfo.getStagesByDifficulty("Normal")
			expect(#stages).toBe(2)
		end)

		it("should return 4 Hard stages", function()
			local stages = StageInfo.getStagesByDifficulty("Hard")
			expect(#stages).toBe(4)
		end)

		it("should return empty for unknown difficulty", function()
			local stages = StageInfo.getStagesByDifficulty("Impossible")
			expect(#stages).toBe(0)
		end)
	end)

	describe("getTotalStageCount", function()
		it("should return 7", function()
			expect(StageInfo.getTotalStageCount()).toBe(7)
		end)
	end)
end)
