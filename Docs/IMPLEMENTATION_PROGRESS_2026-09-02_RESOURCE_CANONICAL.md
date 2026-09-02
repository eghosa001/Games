# RENEW — Implementation Progress Addendum

## 2026-09-02 — Canonical expansion resource API boundary

### Fixed in this pass

- Updated `scripts/expansion.gd` so its public resource-site API can operate against the authoritative `GameState` when the node is explicitly bound with `bind_game_state(state)`.
- `buy_resource_site()` now delegates to `RenewExpansionState.record_resource_purchase()` when bound instead of mutating the runtime resource site and reputation directly.
- `upgrade_resource_site()` now delegates to `RenewExpansionState.record_resource_upgrade()` when bound instead of performing a second runtime mutation.
- `generate_resource()` now delegates to `RenewExpansionState.record_resource_generation()` when bound, so generated stock is written to canonical state rather than only the runtime projection.
- Canonical mutations refresh the Expansion runtime projection after success.
- The legacy standalone behavior is preserved when no GameState is bound, keeping existing callers/tests compatible during the migration.
- Canonical purchase/upgrade paths check authoritative GameState cash rather than trusting a stale runtime cash projection.

### Regression coverage

- Extended `tests/test_expansion_state.gd` with a bound `Expansion` instance.
- Verified canonical resource ownership is visible through the bound runtime node.
- Verified bound generation writes stock to `GameState.expansion.resource_sites`.
- Verified bound upgrade changes level/output/risk in canonical state.
- Verified bound upgrade deducts canonical cash exactly once.
- Verified the legacy resource-generation argument is ignored for authoritative output calculation.
- Verified resource state survives capture/clear/restore.

### Verification status

Static source review only. The Godot executable is not available in the current environment, so runtime tests were not claimed as passing. The latest commit also has no reported CI status checks.

### Verified commits

- `b7c2fe581c85b72b5843503c1ee9354d529b41ac` — route bound expansion resource mutations through GameState
- `f7ee6d237e55ae00c23eb4a47e4131f463091e3f` — cover bound expansion resource mutation path

### Remaining work

- Route expansion operating-day calculation/mutation fully through the canonical GameState boundary.
- Remove remaining transitional runtime-only expansion mutations where their gameplay paths have canonical equivalents.
- Add Main-facing resource save/load projection coverage.
- Continue toward a single authoritative persistence boundary before deeper resource-chain simulation is built.
