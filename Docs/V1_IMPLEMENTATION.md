# RENEW V1 Implementation

This is the living roadmap for the first polished playable version.

## Vision

**Start small → restore neglected assets → build businesses → earn → secure resources → face rivals → form alliances → acquire assets → expand regions → challenge giants → control an economic empire.**

Economic competition is the primary conflict. The player's emotional attachment should come from personally transforming abandoned assets into valuable companies.

## Current playable foundation

### Restoration & first business
- [x] Staged restoration: `Neglected → Cleaned → Repaired → Rebuilt → Installed → Designed → Operational`.
- [x] Inspect → acquire → restore → open RENEW Goods.
- [x] Early-game balance adjusted so the first run is not trapped by restoration costs.
- [x] Restoration strategy choices: **Budget / Standard / Premium**.
- [x] Mobile controls expose the strategy choices before restoration work begins.

### Core business
- [x] Staffing and hiring
- [x] Production and inventory
- [x] Pricing
- [x] Marketing
- [x] Customer contracts
- [x] Loans and repayments
- [x] Daily profit/loss loop

### Living economy
- [x] Dynamic resource prices
- [x] Supplier reliability tiers
- [x] District demand modifiers
- [x] Rival supplier/customer pressure
- [x] Resource shortages and internal logistics foundation
- [x] Recurring market events: shortages, booms, price wars, regional contracts and distressed assets
- [x] Three strategic responses per market event: aggressive, balanced or defensive
- [x] Non-blocking CEO dashboard showing current market pressure
- [ ] Stronger persistent event effects on individual industries

### Empire
- [x] Multiple expansion businesses
- [x] Resource ownership
- [x] Internal logistics
- [x] Regional selection and expansion
- [x] District system
- [x] Headquarters management
- [x] Transport fleet upgrades
- [x] Long-term company objectives with rewards
- [ ] Business specialization depth
- [ ] Branch managers/delegation
- [ ] Stronger cross-region supply bottlenecks

### Corporate war
- [x] NPC corporations and relationships
- [x] Alliances
- [x] Acquisition approaches
- [x] Corporate capital, dividends, buybacks and defense foundation
- [ ] Share ownership and voting power presentation
- [ ] Board control
- [ ] Hostile takeover attempts as a complete gameplay loop
- [ ] Corporate blocs and defensive alliances
- [ ] Major corporation endgame objectives

### World & presentation
- [x] Economic world presentation layer
- [x] Restoration visual states
- [x] Mobile-first tabbed controls
- [x] Touch-safe overlay architecture
- [x] Tutorial overlay
- [x] Persistent milestone/progression system connected to Main
- [x] Long-term empire goals connected to Main
- [ ] Automatic tutorial progression after validated actions
- [ ] Stronger event-choice presentation
- [ ] Animated feedback, sound and music
- [ ] Polished milestone celebrations
- [ ] Unified save/load for every auxiliary system

## 80% completion milestone

The project is now approximately **80% complete in gameplay-system scope**. The major loop and strategic layers exist; the remaining work is increasingly about depth, presentation, balance and validation rather than foundational architecture.

The 80% milestone consists of:
- A complete first-session restoration-to-business loop.
- A functioning economy with suppliers, pricing, production and profit.
- Reactive corporations, alliances and acquisition systems.
- Multiple businesses, resources, logistics and regions.
- Corporate capital/control foundations.
- Recurring market events with player choices.
- Tutorial, milestones and long-term empire goals.
- Mobile-first controls and a non-blocking strategic HUD.

## Remaining 20%

### 80–85% — Core polish
1. Automatic tutorial progression after successful actions.
2. Stronger feedback for profit, losses, shortages and rival reactions.
3. First-hour balance pass.
4. Better event-choice presentation.

### 85–90% — Regional depth
1. Distinct regional economies.
2. Region-specific resource advantages.
3. Cross-region trade decisions.
4. Stronger logistics bottlenecks.

### 90–95% — Corporate war depth
1. Share ownership and voting power.
2. Board influence.
3. Hostile takeover gameplay.
4. Corporate blocs and defensive alliances.
5. A powerful but beatable Giant endgame opponent.

### 95–100% — Release polish
1. Animations and transitions.
2. Sound effects and music.
3. Milestone celebrations and notifications.
4. Unified save-state persistence.
5. Android performance optimization.
6. Full balance and regression testing.

## Phase F — V1 validation
- [ ] Clean first-run playthrough
- [ ] 30-minute economy balance test
- [ ] 1-hour expansion test
- [ ] Save/load regression test
- [ ] Touch-only regression test
- [ ] Low-end Android performance test
- [ ] Economy exploit/balance pass

## Current test checkpoint

After pulling the latest `main` branch, test the whole batch in Godot rather than testing every individual change:

1. Four mobile tabs respond to touch.
2. RESTORE shows Budget, Standard and Premium.
3. Choosing a plan before restoration changes the restoration costs.
4. Inspect → Acquire → Restore → Open Business still works.
5. Market events eventually appear after advancing days.
6. The WORLD tab provides three market responses.
7. Company goals and milestone messages appear as progress is made.
8. SAVE GAME and LOAD GAME still work.
9. No new GDScript parse errors appear.

The `RGBAFloat` → `RGBAHalf` message previously seen on some hardware is a graphics compatibility warning, not a GDScript parse error.

## Design guardrails

- Economic competition is the primary conflict.
- Major systems should create a meaningful decision, emotional attachment, or reason to return.
- Restoration choices must have visible consequences.
- Ownership is a strategic resource: raising money can accelerate growth while reducing control.
- World opportunities should create stories and consequences, not free rewards.
- The Giant should be powerful but beatable through economics, alliances, reputation and corporate defenses.
- Failure should create consequences and comeback opportunities rather than simply ending the game.
- Keep V1 playable before massively increasing world size.
