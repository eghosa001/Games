# RENEW V1 Implementation

This is the living roadmap for the first polished playable version.

## Vision

**Start small → restore neglected assets → build businesses → earn → secure resources → face rivals → form alliances → acquire assets → expand regions → challenge giants → control an economic empire.**

Economic competition is the primary conflict. The player's emotional attachment should come from personally transforming abandoned assets into valuable companies.

## Current development status

RENEW now has a connected playable foundation across restoration, business, markets, expansion, regions, supply, alliances and corporate control. The current pass is focused on making those systems interact correctly before the first full regression test.

### Stabilization completed
- [x] Mobile buttons provide per-action feedback without rebuilding the pressed control mid-signal.
- [x] Market events create temporary input-price pressure.
- [x] Market responses create temporary economic consequences.
- [x] Owned resource sites generate stock.
- [x] Resource stock can be transferred into owned expansion businesses.
- [x] Resource transfer validates ownership, availability and amount.
- [x] No new GDScript parse errors are expected from the latest committed changes.

### Still to verify in the integrated playthrough
- [ ] Restoration choice consequences remain visible through the business loop.
- [ ] Pricing, marketing, staffing and capacity interact correctly.
- [ ] Rival pressure affects profitability and expansion decisions.
- [ ] Alliances produce useful economic/protection benefits.
- [ ] Regional logistics and trade corridors materially affect dispatch.
- [ ] Corporate control and takeover systems remain reachable after expansion.
- [ ] Save/load restores the connected state without regressions.
- [ ] Touch-only playthrough remains stable on Android.

## Design guardrails

- Economic competition is the primary conflict.
- Major systems should create a meaningful decision, emotional attachment, or reason to return.
- Restoration choices must have visible consequences.
- Ownership is a strategic resource: raising money can accelerate growth while reducing control.
- World opportunities should create stories and consequences, not free rewards.
- The Giant should be powerful but beatable through economics, alliances, reputation and corporate defenses.
- Failure should create consequences and comeback opportunities rather than simply ending the game.
- Keep V1 playable before massively increasing world size.

## Next development layers

1. **Core economy:** make restoration quality, staff, marketing, pricing, capacity, inventory and input costs compound into meaningful profit/loss outcomes.
2. **Rivals:** rivals react to expansion, pricing, suppliers, customers and regional entry instead of being passive numbers.
3. **Alliances:** allies provide concrete supply access, defense, discounts and opportunities while consuming relationship capital.
4. **Regions:** regional specialties, logistics bottlenecks, cross-region contracts and rival presence create different expansion strategies.
5. **Corporate war:** voting thresholds, board states, defensive blocs and the Giant endgame turn ownership into a strategic struggle.
6. **Persistence:** consolidate auxiliary system state where practical so save/load represents the whole company.
7. **Release polish:** Android performance, responsive HUD, stronger event presentation, audio, animation, milestone celebrations and final balance.

## Integrated test checkpoint

After the next stabilization batch, test one complete run rather than individual features:

1. RESTORE → choose a plan → inspect → acquire → restore → open business.
2. BUSINESS → buy inputs → produce → hire/upgrade/market/price → END DAY.
3. Advance until a market event appears; respond and verify the temporary economic effect.
4. EMPIRE → acquire a resource site → generate stock → supply an owned business.
5. Expand into a region → infrastructure → trade corridor → dispatch goods.
6. Use alliance and corporate controls once unlocked.
7. SAVE GAME → make changes → LOAD GAME → confirm the company returns consistently.
8. Repeat using touch only.
9. Watch the Godot output for parse errors, invalid calls or new runtime errors. The RGBAFloat → RGBAHalf message is a hardware compatibility warning, not a GDScript parse error.
