# RENEW V1 Implementation

This is the living roadmap for the first polished playable version.

## Vision

**Start small → restore neglected assets → build businesses → earn → secure resources → face rivals → form alliances → acquire assets → expand regions → challenge giants → control an economic empire.**

Economic competition is the primary conflict. The player's emotional attachment should come from personally transforming abandoned assets into valuable companies.

## 80% gameplay-scope status

RENEW is being treated as **80% complete across every major gameplay part**. This does not mean release-ready; it means each major pillar has a playable foundation and the remaining work is primarily depth, polish, balancing and QA.

### Restoration & first business — 80%+
- [x] Inspect → acquire → restore → open business.
- [x] Staged restoration through Operational.
- [x] Budget / Standard / Premium restoration choices.
- [x] Early-game financing balance.
- [x] Mobile restoration controls.
- [x] Tutorial onboarding with automatic progression after validated actions.
- [ ] More property archetypes and visual restoration variety.

### Core business — 80%+
- [x] Staffing and hiring.
- [x] Production and inventory.
- [x] Pricing and marketing.
- [x] Customer contracts.
- [x] Loans and repayments.
- [x] Daily profit/loss loop.
- [x] Business upgrades and capacity growth.
- [ ] Deeper business specialization and manager delegation.

### Living economy — 80%+
- [x] Dynamic resource prices.
- [x] Supplier reliability tiers.
- [x] District demand modifiers.
- [x] Rival supplier/customer pressure.
- [x] Resource shortages and internal logistics foundation.
- [x] Recurring market events: shortages, booms, price wars, regional contracts and distressed assets.
- [x] Aggressive / balanced / defensive responses.
- [x] CEO market/goal dashboard.
- [x] Event choices create immediate financial/reputation consequences.
- [ ] More persistent industry-specific shocks and longer market cycles.

### Empire — 80%+
- [x] Multiple expansion businesses.
- [x] Resource ownership.
- [x] Internal logistics.
- [x] Regional selection and expansion.
- [x] District system.
- [x] Headquarters management.
- [x] Transport fleet upgrades.
- [x] Long-term company objectives.
- [x] Distinct regional demand, labor, competition, industry and resource modifiers.
- [x] Regional infrastructure.
- [x] Cross-region goods dispatch.
- [x] Trade corridor foundation between established regions.
- [ ] Full multi-region supply bottleneck simulation.
- [ ] Branch manager delegation.

### Corporate war — 80%+
- [x] NPC corporations and relationships.
- [x] Alliances and strategic ally defense.
- [x] Acquisition approaches.
- [x] Corporate capital raises.
- [x] Founder/investor ownership.
- [x] Buybacks and dividends.
- [x] Board trust.
- [x] Board influence.
- [x] Corporate defense.
- [x] Takeover risk.
- [x] Hostile takeover attempts with success/failure outcomes.
- [x] Takeover cooldowns and consequences.
- [ ] Corporate blocs and multi-company political conflicts.
- [ ] Final Giant endgame campaign.

### World & presentation — 80%+
- [x] Economic world presentation layer.
- [x] Restoration visual states.
- [x] Mobile-first tabbed controls.
- [x] Touch-safe overlay architecture.
- [x] Tutorial overlay.
- [x] Automatic tutorial progression.
- [x] Persistent milestone/progression system.
- [x] Long-term empire goals.
- [x] CEO strategy HUD.
- [x] Market event response UI.
- [ ] Rich event cards and stronger animations.
- [ ] Sound effects and music.
- [ ] Polished milestone celebrations.
- [ ] Unified save/load for every auxiliary system.

## What remains after the 80% milestone

### 80–85% — Core polish
1. Stronger feedback for profit, losses, shortages and rival reactions.
2. First-hour economy balancing.
3. Better event-choice presentation.
4. More visible consequences from strategic decisions.

### 85–90% — Regional depth
1. Stronger region-specific production chains.
2. Cross-region supply contracts.
3. Logistics bottlenecks that can interrupt operations.
4. Region-specific opportunities and rival behavior.

### 90–95% — Corporate war depth
1. Voting thresholds and board control states.
2. Corporate blocs and defensive alliances.
3. More sophisticated takeover negotiations.
4. Giant objectives and counter-strategies.

### 95–100% — Release polish
1. Animations and transitions.
2. Sound effects and music.
3. Milestone celebrations and notifications.
4. Unified save-state persistence.
5. Android performance optimization.
6. Full balance and regression testing.

## V1 validation checklist

- [ ] Clean first-run playthrough.
- [ ] 30-minute economy balance test.
- [ ] 1-hour expansion test.
- [ ] Regional trade test.
- [ ] Corporate ownership/takeover test.
- [ ] Save/load regression test.
- [ ] Touch-only regression test.
- [ ] Low-end Android performance test.
- [ ] Economy exploit/balance pass.
- [ ] No new GDScript parse/runtime errors.

## Current integrated test checkpoint

After pulling the latest `main`, test one complete run rather than individual features:

1. RESTORE, BUSINESS, EMPIRE and WORLD tabs respond to touch.
2. Budget, Standard and Premium restoration plans work before restoration begins.
3. Inspect → Acquire → Restore → Open Business works.
4. Produce → strategy decisions → End Day works.
5. Market events appear after advancing days and accept all three responses.
6. Regional selection, establishment, infrastructure, dispatch and trade corridor actions work.
7. Corporate capital, board influence, defense and takeover controls appear on mobile.
8. SAVE GAME / LOAD GAME work.
9. Tutorial advances as actions are completed.
10. No new GDScript parse/runtime errors appear.

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
