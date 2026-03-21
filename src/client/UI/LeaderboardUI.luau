-- LeaderboardUI: stub -- Leaderboard is a physical billboard (server-side SurfaceGui)
-- (server-side Part + SurfaceGui created by LeaderboardManager.luau)
--
-- When client-side leaderboard UI is built, add responsive scaling:
--   local ResponsiveScale = require(ReplicatedStorage.Shared.ResponsiveScale)
--   ResponsiveScale.applyToFrame(self.container, PANEL_W, PANEL_H)

local LeaderboardUI = {}
LeaderboardUI.__index = LeaderboardUI

function LeaderboardUI.new(_parent: ScreenGui)
	return setmetatable({}, LeaderboardUI)
end

return LeaderboardUI
