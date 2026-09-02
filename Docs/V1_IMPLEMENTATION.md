# RENEW V1 Implementation

This document is the living roadmap for the first polished playable version.

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
- [ ] Stronger visible market trend feedback
- [ ] More persistent event consequences
- [ ] More player-facing rival reaction notifications

### Empire
- [x] Multiple expansion businesses
- [x] Resource ownership
- [x] Internal logistics
- [x] Regional selection and expansion
- [x] District system
- [x] Headquarters management
- [x] Transport fleet upgrades
- [ ] Business specialization depth
- [ ] Branch managers/delegation
- [ ] Stronger supply-chain bottlenecks

### Corporate war
- [x] NPC corporations and relationships
- [x] Alliances
- [x] Acquisition approaches
- [x] Corporate capital, dividends, buybacks and defense foundation
- [ ] Share ownership and voting power
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
- [ ] Automatic tutorial progression after validated actions
- [ ] Stronger event-choice presentation
- [ ] Animated feedback, sound and music
- [ ] Polished milestone celebrations
- [ ] Save/load UX polish

## Development phases

### Phase A — Make the first 30–60 minutes fun
1. Finish tutorial auto-progression.
2. Make restoration strategy visibly affect the early business.
3. Add memorable first-day events and decisions.
4. Make the first profitable day feel like an achievement.

### Phase B — Make the economy feel alive
1. Surface price trends and shortages.
2. Make rivals react visibly to the player's decisions.
3. Add events with lasting trade-offs.
4. Create reasons to change suppliers, prices and districts.

### Phase C — Build the empire
1. Deepen business specialization.
2. Add branch management.
3. Make logistics capacity and resource ownership strategically important.
4. Expand the regional map.

### Phase D — Corporate war
1. Introduce share ownership.
2. Add voting power and board control.
3. Add hostile takeover attempts.
4. Make alliances useful for both growth and defense.
5. Create a powerful but beatable giant corporation.

### Phase E — Game feel
1. Animations and transitions.
2. Sound effects and music.
3. Better notifications and milestone moments.
4. Performance pass for lower-end Android devices.

### Phase F — V1 validation
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
5. Milestone messages appear after achievements.
6. SAVE GAME and LOAD GAME still work.
7. No new GDScript parse errors appear.

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
