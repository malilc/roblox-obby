-- LeaderboardUI: stub — Leaderboard ย้ายไปเป็นป้ายกายภาพใน lobby
-- (server-side Part + SurfaceGui สร้างโดย LeaderboardManager.luau)

local LeaderboardUI = {}
LeaderboardUI.__index = LeaderboardUI

function LeaderboardUI.new(_parent: ScreenGui)
	return setmetatable({}, LeaderboardUI)
end

return LeaderboardUI
