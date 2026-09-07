# RENEW test suite

The suite is organized by test purpose. Existing focused tests remain at `tests/` for compatibility. The strict quality gate is the release-level acceptance floor.

## Strict release gates
- `test_quality_gate.gd` — canonical Godot release gate: boot, scene composition, visible world assets, responsive UI, core gameplay progression, persistence, rendered-frame checkpoint and runtime stability.
- `QUALITY_TEST_PROTOCOL.md` — rules preventing false-green/loophole tests and defining artifact review.
- `release/test_full_new_game_flow.gd` — end-to-end first-session progression.
- `test_release_smoke.gd` — release structure and architecture smoke test.
- `test_architecture_integrity.gd` — script and scene architecture integrity.

## Unit
- `test_employee_system.gd`
- `test_economy_transactions.gd`
- `test_production_system.gd`
- `test_contract_system.gd`
- `test_competitor_ai.gd`
- `test_game_state.gd`
- `test_v15_industries.gd`
- `test_v15_acquisitions.gd`
- `test_v15_executives.gd`
- `test_v15_regions.gd`
- `test_v15_alliances.gd`
- `test_v15_ownership_finance.gd`

## V2 workstreams
- `test_v21_investment.gd`
- `test_v22_shares.gd`
- `test_v23_diplomacy.gd`
- `test_v24_joint_ventures.gd`
- `test_v25_contracts.gd`
- `test_v26_trade.gd`
- `test_v27_infrastructure.gd`
- `test_v28_corporations.gd`
- `test_v29_alliance_competitions.gd`

## V3 endgame
- `test_v31_victory.gd`
- `test_v32_corporate_wars.gd`
- `test_v33_endgame_crises.gd`
- `test_v34_prestige.gd`

## V4 living world
- `test_v41_world_events.gd`
- `test_v42_event_effects.gd`
- `test_v43_seasonal_arc.gd`
- `test_v44_verified_news.gd`

## V5 UX parity
- `test_v51_ux_parity.gd`

## V6/V7 cleanup and recovery
- `test_v72_save_repair.gd`

## V8 endgame completion
- `test_v81_share_pricing.gd`
- `test_v82_property_market.gd`
- `test_v83_identities.gd`
- `test_v84_notifications.gd`
- `test_v85_listing.gd`
- `test_v86_haggling.gd`
- `test_v87_reputation.gd`
- `test_v88_motions.gd`
- `test_v89_cycles.gd`
- `test_v810_power.gd`
- `test_v811_valley.gd`

## V9 screens
- `test_v9x_panels.gd`
- `test_v95_containment.gd`
- `test_v97_modal_focus.gd`
- `test_v98_performance.gd`

## Integration
- `test_new_game_flow.gd`
- `test_simulation_architecture.gd`
- `test_history_system.gd`
- `test_news_system.gd`
- `test_supply_chain_system.gd`

## Long-running
- `test_long_soak.gd`
- `test_extreme_soak.gd`

## Release
- `release/test_full_new_game_flow.gd`
- `release/test_release_smoke.gd`
- `test_release_smoke.gd`
- `test_architecture_integrity.gd`
- `test_quality_gate.gd`

## CI policy
The main Godot workflow runs every `tests/test_*.gd`, every integration test and every
release test, excluding only the explicitly slow soak tests from the fast job. Suites that
need a real display server (the strict quality gate's frame checkpoint, real mouse/touch
dispatch in the responsive shell) run under Xvfb instead of headless. Tests must never
manufacture a passing result by skipping a required assertion. Missing systems, missing assets, broken references, failed state transitions and invalid rendered output are failures.