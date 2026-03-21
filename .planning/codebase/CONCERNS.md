# Codebase Concerns

**Analysis Date:** 2026-03-21

## Tech Debt

**Infinite Effect Loop Without Bounded Resource Limits:**
- Issue: `ItemManager:startEffectLoop()` spawns an infinite task that runs every 0.5 seconds, iterating through all players and effects with no resource caps. In a game with many concurrent players, this loop could accumulate memory as effect tables grow without cleanup triggers.
- Files: `src/server/ItemManager.luau` (lines 2855-2895)
- Impact: Memory accumulation over long server uptime; potential server slowdown with 100+ concurrent players; no maximum effect count enforcement.
- Fix approach: Add configurable limits to effect tracking (e.g., max 50 active effects per player); implement per-map cleanup when stages reset; add memory monitoring to Logger for diagnostics.

**Touched Events on Moving Platforms Not Debounced:**
- Issue: `ItemManager:setupItemPickups()` connects raw `.Touched` events to pickup detection without debounce, causing multiple fires per collision. This is a known Roblox gotcha that can trigger duplicate item collection logic.
- Files: `src/server/ItemManager.luau` (line 2912)
- Impact: Players may collect items twice; race conditions with currency addition; inventory corruption potential.
- Fix approach: Implement `IsCollected` attribute check BEFORE firing event logic (already partially present); add a per-player pickup cooldown (0.1s minimum); use `:FindFirstDescendant()` pattern instead of `.Touched` for detection on stage pickups.

**GamePass Ownership State Out of Sync Risk:**
- Issue: `ShopManager` caches game pass ownership in `self.playerGamePasses[player]` but relies on periodic `CheckGamePass` remote to refresh. If a player purchases a game pass outside the game (web/mobile), the server won't know until they explicitly trigger the check or rejoin.
- Files: `src/server/ShopManager.luau` (line 33); `src/shared/GamePassLogic.luau`
- Impact: Player sees "not owned" in UI despite having purchased; VIP/DoubleCoin multipliers not applied; daily gem rewards calculated incorrectly.
- Fix approach: On player join, force `checkAllGamePasses(player)` with 5-second delay; add periodic re-check every 2-3 minutes; cache with TTL (time-to-live) of 60 seconds.

**DataStore Save Failures Silent on Client:**
- Issue: `DataStoreHelper.saveAsync()` returns boolean success/failure, but callers in `CurrencyManager:spendCurrency()` and `CurrencyManager:addCurrency()` don't always wait for save confirmation before telling client the transaction succeeded.
- Files: `src/server/CurrencyManager.luau` (around update operations); `src/server/DataStoreHelper.luau` (lines 92-122)
- Impact: Player thinks they spent currency but data doesn't persist; duplication attacks possible; rollback on server restart.
- Fix approach: Refactor all currency operations to `pcall(DataStore save)` before client response; queue failed saves and retry on next batch; add server-side transaction log.

**Map Cleanup Not Guaranteed on Room Close:**
- Issue: When a match room closes, `MapManager:cleanupMap(mapId)` should destroy all stage parts, but if a disconnect/error happens during cleanup, orphaned parts remain in memory consuming resources.
- Files: `src/server/MapManager.luau` (line 630-649)
- Impact: Memory leak on rapid room creation/deletion cycles; players see remnants of old stages; collision detection errors.
- Fix approach: Add `game:BindToClose()` handler to force cleanup all active maps; use `task.spawn()` with error handling in cleanup functions; implement orphan detection loop (every 10s scan for detached stage parts, destroy if > 5 minutes old).

**Remote Validation Missing in High-Volume Operations:**
- Issue: `ItemManager:useItem()` and `MatchManager:joinRoom()` validate player state but don't validate rapid-fire requests. A client can spam RemoteEvents faster than server processes them, queuing hundreds in backlog.
- Files: `src/server/ItemManager.luau` (line 58); `src/server/MatchManager.luau` (line 70)
- Impact: Items used multiple times in single server frame; match join requests race condition; item refund bugs.
- Fix approach: Add per-player request queue (max 3 pending requests); implement cooldown timers for high-frequency operations; add `Logger.warn()` if queue ever exceeds 5 items.

---

## Known Bugs

**Stage 6 Lava Disappearing Platforms Fall-Through:**
- Symptoms: Players sometimes fall through disappearing platforms in Stage 6 (Lava Rise) during respawn safety window.
- Files: `src/server/StageTemplates.luau` (Stage 6 construction code)
- Trigger: Rapid respawn after death in lava section; happens ~5-10% of respawns.
- Workaround: Stage teleports player to checkpoint, but checkpoint may be in falling platforms. Players must jump to avoid.
- Recent context: Commit a49bf09 added "respawn safety" but may not cover all edge cases.

**Mobile Touch Buttons Not Responsive Under High Load:**
- Symptoms: On mobile devices, sprint button and jump button become unresponsive during intense item usage or player count >20.
- Files: `src/client/UI/MobileInputUI.luau`; `src/client/UltimateSkillController.luau`
- Trigger: High server frame time causing InputService event backlog.
- Workaround: Restart the game; works fine with <10 players.

**Class Selection UI Spam-Click Crashes Client:**
- Symptoms: If player clicks class purchase button 5+ times rapidly, client UI hangs or shows duplicated purchase prompts.
- Files: `src/client/UI/ClassSelectionUI.luau` (purchase button logic)
- Trigger: Network lag + rapid clicks; button doesn't disable fast enough.
- Workaround: Wait 1 second between clicks; refresh screen with R key.

---

## Security Considerations

**Game Pass Ownership API Calls Not Rate-Limited per Session:**
- Risk: Malicious client script could call `CheckGamePass` remote repeatedly, consuming API quota. Roblox throttles these calls and may block the game's game pass checks entirely.
- Files: `src/server/ShopManager.luau` (lines 58-62)
- Current mitigation: Rate limit in `isRateLimited()` at 500ms per player; MarketplaceService itself rate-limits but could cause timeouts.
- Recommendations: (1) Cap CheckGamePass to once per 10 seconds; (2) Cache ownership for 60+ seconds; (3) Log abnormal request patterns; (4) Add telemetry to track API hit rate.

**Client Can Spoof Item Usage to Wrong Slot:**
- Risk: Modified client sends `UseItem` remote with `slotIndex=0` or `slotIndex=999`. Server doesn't validate slot bounds, causing nil item or out-of-bounds access.
- Files: `src/server/ItemManager.luau` (line 58: `useItem(player, slotIndex or 1)`)
- Current mitigation: `getFirstEmptySlot()` and array bounds are checked in item placement, but not all code paths validate slotIndex input.
- Recommendations: (1) Validate `slotIndex` is 1-3 (or 1-4 with ExtraSlot pass) at remote handler; (2) Log invalid requests; (3) Return error to client if invalid.

**No Exploit Detection for Impossible Win Times:**
- Risk: Client sends finish time of 5 seconds for a stage that normally takes 30+ seconds. Server calculates rewards without flagging anomaly. Could allow leaderboard manipulation.
- Files: `src/server/MatchManager.luau` (race finish logic); `src/server/CurrencyManager.luau` (reward calculation)
- Current mitigation: None detected.
- Recommendations: (1) Log all finish times < 50% of expected; (2) Flag suspicious completion times and don't award gems; (3) Add server-side stage timer validation.

---

## Performance Bottlenecks

**MapManager Stage Generation With 24 Players:**
- Problem: Generating 5-14 stages per player (multiplied by max 24 players = 120+ stage parts per match) causes server spike. Each stage has multiple moving parts, particles, and physics constraints.
- Files: `src/server/MapManager.luau` (stage building functions)
- Cause: No batching of part creation; each stage yields for animation setup; physics engine processes all parts simultaneously.
- Improvement path: (1) Defer part creation with staggered task.wait() calls; (2) Use `PartCache` pattern to pre-create and reuse stage components; (3) Reduce particle emitter rate on stages with many concurrent players; (4) Measure and log stage generation time.

**LeaderboardManager Queries OrderedDataStore Synchronously:**
- Problem: Every minute, leaderboard fetches top 10 from OrderedDataStore. If DataStore responds slowly, server thread blocks.
- Files: `src/server/LeaderboardManager.luau` (GetSortedAsync calls)
- Cause: No timeout on async DataStore calls; query runs on main thread.
- Improvement path: (1) Run leaderboard queries in dedicated coroutines; (2) Implement 5-second timeout on GetSortedAsync; (3) Cache results for 10 seconds; (4) Load leaderboards on demand, not on timer.

**CurrencyManager Iterates All Players for Coin Multiplier:**
- Problem: Every coin pickup triggers `getCoinMultiplier(player)` which queries game pass cache. With 100 concurrent pickups, cache lookup runs 100x.
- Files: `src/server/ItemManager.luau` (line 2943: calls `gameManager:getCoinMultiplier(player)`); `src/server/GameManager.luau`
- Cause: Multiplier computed on-demand instead of cached per session.
- Improvement path: (1) Cache multiplier in `self.playerGamePasses[player]` for 60 seconds; (2) Recompute only on game pass check; (3) Precompute at player join.

---

## Fragile Areas

**ItemManager Effect Tracking With Model Destruction:**
- Files: `src/server/ItemManager.luau` (all effect methods)
- Why fragile: Effects are stored by reference in tables. If a stage unloads mid-effect, part references become invalid. Iterator loops over playerItems could crash if player removed mid-iteration.
- Safe modification: (1) Use `if not part.Parent then continue end` in all effect loops; (2) Store effect data with creation timestamp, not part reference; (3) Add try-catch around all part property accesses.
- Test coverage: ItemManager has no unit tests for effect cleanup; only manual testing on Stage 6.

**MatchManager Room State Transitions Race Conditions:**
- Files: `src/server/MatchManager.luau` (room state changes: Waiting → Starting → Racing → Finished)
- Why fragile: Multiple remotes can fire simultaneously (e.g., HostStartMatch + JoinRoom + VoteStages). No lock prevents concurrent state modification.
- Safe modification: (1) Store "transitioning" flag to reject state changes in progress; (2) Use queued state transitions; (3) Test with rapid button clicks (hold SPACE in match UI).
- Test coverage: No integration tests for concurrent room operations.

**ClassSelectionUI Item Purchase Flow:**
- Files: `src/client/UI/ClassSelectionUI.luau` (purchase button code)
- Why fragile: Button sends remote without waiting for server response. Multiple rapid clicks queue multiple purchases before first response arrives.
- Safe modification: (1) Disable button on click, re-enable only after response received; (2) Add timeout (5 seconds) to re-enable if no response; (3) Show loading spinner.
- Test coverage: Manual testing only; no automated flow tests.

---

## Scaling Limits

**LeaderboardManager Physical Board Refresh:**
- Current capacity: Updates every 60 seconds for top 10. Works with up to ~50 concurrent players.
- Limit: With 500+ concurrent players, OrderedDataStore queries timeout; physical boards don't update; client UI shows stale data.
- Scaling path: (1) Increase cache TTL to 5 minutes; (2) Move leaderboard UI to client-side mock with periodic sync instead of physical board; (3) Use ReadAsync (snapshot) instead of GetSortedAsync (live); (4) Shard leaderboards by difficulty.

**ItemManager Projectile Tracking:**
- Current capacity: Tracks missiles, lightning, boxing gloves. With 24 players × 3 items = ~72 active projectiles before cleanup.
- Limit: Breakpoint at ~200 projectiles when iteration loop starts causing frame rate drops.
- Scaling path: (1) Implement per-player projectile limit (max 2 active); (2) Auto-destroy projectiles after 5 seconds max lifetime; (3) Use spatial indexing for collision detection instead of iterating all projectiles.

**DataStore Key Space:**
- Current capacity: PlayerData key = "Player_" + UserId. One save per player per session. No growth issues at current scale.
- Limit: If daily logins exceed Roblox's default 60+ keys/second per DataStore, save operations queue. At ~100,000 DAU this becomes bottleneck.
- Scaling path: (1) Implement DataStore versioning strategy (backup DataStore after outages); (2) Cache-aside pattern for reads; (3) Use UpdateAsync atomicity for currency transactions instead of separate writes.

---

## Dependencies at Risk

**MarketplaceService GamePass Ownership Check Timeout:**
- Risk: If Roblox's MarketplaceService API is slow or down, `ShopManager:checkAllGamePasses()` hangs. Server thread blocks waiting for response.
- Impact: Player joining can't check pass ownership; game pass multipliers not applied; shop doesn't load.
- Migration plan: (1) Implement 5-second timeout on MarketplaceService calls; (2) Fall back to cached ownership on timeout; (3) Retry on next player state change; (4) Log failures to external monitoring.

**DataStoreService Quota Exhaustion:**
- Risk: High-frequency currency saves (on every coin pickup × 24 players = 24 saves/sec) could exhaust DataStore quota (100 requests/minute per key in production).
- Impact: Currency saves fail silently; player data lost on server restart; currency duplication.
- Migration plan: (1) Batch currency updates (save once per 30 seconds per player); (2) Implement write queue with coalescing; (3) Add quota monitoring; (4) Move to custom backend if game grows to 10k+ CCU.

---

## Missing Critical Features

**No Server-Side Transaction Log:**
- Problem: If a DataStore save fails, there's no audit trail. Can't tell if a player lost currency due to server bug or intentional refund.
- Blocks: Debugging currency loss complaints; forensic analysis of exploits.
- Recommendation: Implement transaction logger (timestamp, player, action, amount, result) saved to separate DataStore.

**No Matchmaking Skill Rating:**
- Problem: Players can't find appropriately-skilled opponents. Weak players get demolished by pros; pros face only newbies.
- Blocks: Competitive progression; retention of mid-skill players.
- Recommendation: Add Elo/TrueSkill calculation; use for player-vs-match suggestions.

**No Anti-Cheat Detection:**
- Problem: No server-side validation of physically impossible stats (5-second stage completion, negative times, etc.).
- Blocks: Leaderboard integrity; fair play guarantee.
- Recommendation: Add anomaly detection rules; flag suspicious replays; review telemetry weekly.

---

## Test Coverage Gaps

**ItemManager Effect Cleanup Under Stage Unload:**
- What's not tested: Effect cleanup when stage parts are destroyed mid-effect (e.g., lava platform disappears during boost animation).
- Files: `src/server/ItemManager.luau` (effect loops)
- Risk: Nil reference errors; memory leaks; invisible effects.
- Priority: High

**MatchManager Concurrent State Transitions:**
- What's not tested: Multiple remotes firing simultaneously (JoinRoom + VoteStages + HostStartMatch in same frame).
- Files: `src/server/MatchManager.luau`
- Risk: Race condition corrupts room state; players in wrong stage; infinite race loop.
- Priority: High

**DataStore Failure Fallback:**
- What's not tested: DataStore offline scenario. Does game continue, does player data revert, does server crash?
- Files: `src/server/DataStoreHelper.luau`; `src/server/CurrencyManager.luau`
- Risk: Data loss; server crash; player progression reset.
- Priority: Critical

**Mobile Input Edge Cases:**
- What's not tested: Touch button responsiveness under high network latency or server load.
- Files: `src/client/UI/MobileInputUI.luau`; `src/client/UltimateSkillController.luau`
- Risk: Mobile players unable to control character; poor user experience.
- Priority: Medium

**Class Purchase Rapid-Click:**
- What's not tested: Player clicking purchase button 5+ times rapidly. Button should disable, but does it?
- Files: `src/client/UI/ClassSelectionUI.luau`
- Risk: Duplicate charge; UI hang; server confusion.
- Priority: Medium

---

*Concerns audit: 2026-03-21*
