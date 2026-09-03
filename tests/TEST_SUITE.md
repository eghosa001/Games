# RENEW test suite

The suite is organized by test purpose. Existing focused tests remain at `tests/` for compatibility; this index is the canonical grouping until physical test-file moves are made without breaking existing runners.

## Unit
- `test_employee_system.gd`
- `test_economy_transactions.gd`
- `test_production_system.gd`
- `test_contract_system.gd`
- `test_competitor_ai.gd`
- `test_game_state.gd`

## Integration
- `test_new_game_flow.gd`
- `test_simulation_architecture.gd`
- `test_history_system.gd`
- `test_news_system.gd`
- `test_supply_chain.gd`

## Long-running
- `test_long_soak.gd`
- `test_extreme_soak.gd`

## Release
- `test_release_smoke.gd`
- `test_full_coverage.gd`

Tests that did not previously exist are tracked by name here and should be added as their corresponding system contracts are finalized; this avoids creating fake passing tests.
