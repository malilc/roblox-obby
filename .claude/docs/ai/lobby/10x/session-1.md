# 10x Analysis: Lobby Experience
Session 1 | Date: 2026-03-07

## Current Value
The lobby is a 100x100 stud enclosed room where players:
1. **Spawn** at center-front (0, 102, -8)
2. **Walk to SelectionZone** (center-back) to pick 1-5 stages from Easy/Normal/Hard
3. **Walk to ShopZone** (right side) to buy items with coins or gacha pull classes with gems
4. **View leaderboards** (auto-generated boards at X=+-22, Z=30) for gems & wins
5. **Use MenuGridUI** (top-left buttons) for Shop/Classes/Titles/Daily/Help/Settings

**Core loop**: Spawn -> Select stages -> Race -> Earn coins/gems -> Return to lobby -> Repeat

**Pain points observed in codebase**:
- Lobby is static & boring — no interactive elements beyond 2 zones
- Walking to zones is tedious (no quick-action alternative)
- No social features (no way to interact with other players in lobby)
- No visual feedback of progression/stats
- New players have no guidance on what to do
- No reason to stay in lobby (just a transit area)

## The Question
What would make the lobby experience 10x more valuable — a place players WANT to be, not just pass through?

---

## Massive Opportunities

### 1. Practice/Freeplay Area
**What**: A section of the lobby with sample obstacles (jump platforms, moving platforms, spinners) where players can practice without stakes. Could include a parkour course or obstacle playground.
**Why 10x**: Players currently can only experience gameplay in actual races. A practice area turns the lobby from dead space into active play space. Players improve skills -> feel more confident -> play more races -> retain better.
**Unlocks**: Tutorial integration, skill-based matchmaking data, player engagement while waiting
**Effort**: Medium (reuse existing StageTemplates helper functions to create practice obstacles)
**Risk**: Could distract from starting actual races
**Score**: 🔥

### 2. Multiplayer Lobby Minigames
**What**: Short minigames in the lobby while waiting (tag, simon says, dance-off, king of the hill on a small platform). Auto-start when 3+ players are in the lobby.
**Why 10x**: Transforms idle waiting time into social fun. Players stay in game longer. Creates social bonds that increase retention.
**Unlocks**: Social features, competitive lobby, reason to stay online
**Effort**: High (new game logic, networking, state management)
**Risk**: Complexity, could overshadow main game
**Score**: 👍

### 3. Player Housing/Customization Showcase
**What**: Each player gets a small display pedestal in the lobby showing their character with equipped class, title, and stats. Walking near other players' pedestals shows their profile.
**Why 10x**: Social proof and aspiration. Players see what others have achieved and want to unlock the same. Drives gacha/shop engagement.
**Unlocks**: Social comparison, goal-setting, cosmetic demand
**Effort**: High (new system, dynamic instances per player)
**Risk**: Performance with many players
**Score**: 🤔

---

## Medium Opportunities

### 1. Quick-Play Button (Skip Zone Walk)
**What**: Add a "QUICK PLAY" button to the MenuGridUI that opens StageSelectionUI directly without walking to the SelectionZone. The zone still works for players who prefer walking.
**Why 10x**: Removes the #1 friction point — having to physically walk to a zone every single time. Experienced players can start games in 2 clicks instead of 5+ seconds of walking.
**Impact**: Every single play session starts faster. Compound time savings.
**Effort**: Low-Medium (wire existing StageSelectionUI to a new button in MenuGridUI)
**Score**: 🔥

### 2. Daily Challenge Board (Physical)
**What**: A visible board/screen in the lobby showing today's daily challenges with progress bars. "Complete 3 Hard stages", "Collect 50 coins", "Win a race under 2 minutes". Rewards gems.
**Why 10x**: Gives players a REASON to play every day. Creates goals beyond "just race again". Daily retention hook.
**Impact**: Daily active users increase, session length increases
**Effort**: Medium (new DailyChallengeManager, physical board, UI panel)
**Score**: 🔥

### 3. Interactive Tutorial/Guide NPC
**What**: A visible NPC or sign near spawn that new players can interact with. Explains: how to select stages, what coins/gems do, how classes work, how items help. Could be a simple billboard or animated character.
**Why 10x**: New player retention is everything. If players don't understand the game in first 60 seconds, they leave. Currently the "Help" menu button exists but is passive.
**Impact**: Drastically reduces new player confusion and churn
**Effort**: Low-Medium (billboard + touchable part + simple dialog UI)
**Score**: 🔥

### 4. Stats Showcase Podium
**What**: A physical podium/screen near spawn showing the current player's stats: total wins, favorite class, gems earned, best time, current streak. Always visible, personal.
**Why 10x**: Players feel their progress is real and visible. Creates emotional investment. "I have 47 wins and 3-day streak — I'm not quitting now."
**Impact**: Increases emotional investment and return rate
**Effort**: Medium (new UI overlay or physical board reading from CurrencyManager data)
**Score**: 👍

### 5. Teleport Pads Instead of Walk-to Zones
**What**: Replace walking to SelectionZone/ShopZone with clearly marked teleport pads that instantly move the player and trigger the UI. Visually prominent with particle effects.
**Why 10x**: More game-like feel, faster navigation, clearer wayfinding. Players immediately know what each area does.
**Impact**: Better UX flow, faster game starts
**Effort**: Low (reposition zones, add visual effects, same detection code)
**Score**: 👍

---

## Small Gems

### 1. Lobby Ambient Music
**What**: Play a cheerful background track in the lobby (already have SoundManager infrastructure). Fade out when entering a race.
**Why powerful**: Sound sets mood. A silent lobby feels dead. Music makes it feel alive and polished.
**Effort**: Low (SoundManager already exists, just needs a lobby BGM track)
**Score**: 🔥

### 2. Animated Decorations
**What**: Add subtle animations to lobby elements — spinning coin display, floating gem crystal, bobbing items. Use existing MapManager animation patterns (bobbing, spinning via Heartbeat).
**Why powerful**: Makes the lobby feel alive instead of static. Signals quality. Players subconsciously feel "this game is polished."
**Effort**: Low (reuse existing animation patterns from StageTemplates item boxes)
**Score**: 🔥

### 3. Welcome Back Message with Stats
**What**: When returning to lobby from a race, show a brief popup: "Great run! You earned 25 coins, 3 gems. Total: 150 coins, 42 gems." Already have ReturnToLobby remote.
**Why powerful**: Positive reinforcement after every session. Players see progress accumulating.
**Effort**: Low (client-side UI on ReturnToLobby event)
**Score**: 👍

### 4. Floor Arrows/Markers to Zones
**What**: Add glowing arrows or path markers on the ground pointing toward SelectionZone and ShopZone. Like the red arrows in the reference screenshots.
**Why powerful**: Instantly solves wayfinding for new players. Zero learning curve.
**Effort**: Very Low (add arrow-shaped Parts with Neon material in project.json)
**Score**: 🔥

### 5. Spawn Celebration Effect
**What**: When a player spawns or returns to lobby, play a brief particle burst + sound effect. Makes arriving feel special.
**Why powerful**: First impression on every session. Delight costs almost nothing.
**Effort**: Very Low (ParticleEmitter + Sound on spawn)
**Score**: 👍

---

## Recommended Priority

### Do Now (Quick wins for lobby redesign)
1. **Floor Arrows/Markers** — Add directional indicators to SelectionZone and ShopZone in the new lobby layout
2. **Animated Decorations** — Add spinning/bobbing elements using existing animation patterns
3. **Lobby Ambient Music** — Configure SoundManager for lobby BGM
4. **Quick-Play Button** — Add to MenuGridUI to skip walking to SelectionZone

### Do Next (High leverage)
1. **Daily Challenge Board** — Physical board in lobby + DailyChallengeManager system
2. **Interactive Tutorial NPC/Sign** — Billboard near spawn explaining game basics
3. **Welcome Back Stats Popup** — Show earnings summary on race return
4. **Practice Area** — Small obstacle playground in corner of lobby

### Explore (Strategic bets)
1. **Multiplayer Lobby Minigames** — Tag/simon says while waiting for matchmaking
2. **Stats Showcase Podium** — Personal stats display near spawn
3. **Teleport Pads** — Replace walk-to zones with instant teleport pads

### Backlog
1. **Player Housing/Showcase** — Too complex for now, revisit after player count grows

---

## Lobby Redesign Implications

Based on this brainstorm, the outdoor park lobby redesign should include physical space/parts for:

1. **Floor arrows** pointing to SelectionZone and ShopZone (Do Now)
2. **Practice area** in one corner with a few platforms (Do Next — reserve space)
3. **Daily challenge board location** near the fountain/spawn area (Do Next — reserve space)
4. **Tutorial sign/NPC spot** near spawn (Do Next — reserve space)
5. **Animated decorations** — spinning coin/gem displays (Do Now)

These should be incorporated into the lobby JSON layout.

---

## Questions

### Answered
- **Q**: What exists in the lobby currently? **A**: 2 zones (SelectionZone, ShopZone), leaderboards, spawn — that's it
- **Q**: What's the tech stack? **A**: All Luau, project.json defines parts, server/client split, existing animation system

### Blockers
- **Q**: What lobby BGM track to use? (Need asset ID)
- **Q**: Daily challenges — what specific challenges make sense for the game? (Need design decisions)

## Next Steps
- [x] Complete 10x brainstorm
- [ ] Incorporate brainstorm findings into lobby layout (add arrow parts, reserve spaces for future features)
- [ ] Implement lobby redesign in default.project.json
- [ ] Add Quick-Play button to MenuGridUI (separate task)
- [ ] Add lobby BGM to SoundManager (separate task)
