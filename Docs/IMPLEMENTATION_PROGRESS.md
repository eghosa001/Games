# RENEW — Implementation Progress Log

> Verified implementation work on `feature/foundation-v11-implementation`.

## 2026-09-02 — Expansion resource and day mutation integration

### Fixed in this pass

- Added canonical Main-level resource-site actions for purchase, upgrade and generation using `RenewExpansionState`.
- Added keyboard access for the resource actions: `Y` buy resource site, `Z` upgrade resource site and `G` generate resource.
- Routed expansion day profit/population progression through `RenewExpansionState.advance_day()` after the existing Expansion simulation calculates the empire result.
- Canonical expansion day state is now advanced alongside the core day instead of being silently discarded by the runtime synchronization step.
- Expansion population growth from restored properties is now persisted through the canonical expansion state during the daily simulation.
- Preserved the existing Expansion API and compatibility fallback when GameState is unavailable.

### Important remaining issue

- The newly exposed Main resource actions still require a final cash/reputation projection cleanup: the canonical adapter mutates GameState funds, while the legacy Main scalar projection remains transitional. The next pass must make these actions consume the canonical returned balances without allowing `_sync_expansion_runtime()` to overwrite them.
- `Expansion.gd` itself still contains direct resource-site mutations. Full completion requires moving those runtime mutations behind the canonical boundary rather than only exposing canonical Main wrappers.

### Verified commit

- `c6fb2ca9067ece25ca7b666661bc9d3577211936` — route expansion resources and day simulation through GameState

### Verification status

Static source review only. A Godot executable is not available in the current environment, so runtime Godot tests were **not** claimed as passing.

## 2026-09-02 — Expansion purchase/upgrade mutation integration

### Fixed in this pass

- Added `RenewExpansionState` as a real mutation boundary for the player-facing expansion purchase and property-upgrade flows.
- `main.gd` now preloads `scripts/expansion_state.gd` and routes `buy_expansion()` through `RenewExpansionState.record_purchase()` instead of `Expansion.buy()`.
- `main.gd` now routes `upgrade_expansion()` through `RenewExpansionState.record_property_upgrade()` instead of `Expansion.upgrade()`.
- The canonical purchase mutation now preserves the legacy runtime effect of setting ownership, activation and restored condition to 100 while updating cash, reputation and restored-count state together.
- The canonical property-upgrade mutation now preserves level, income and value changes and records the existing management-level consequence.
- Expansion selection is synchronized immediately through the canonical expansion projection path.
- Runtime `Expansion` state is rehydrated from GameState after canonical purchase/upgrade mutations, preventing the UI/runtime projection from becoming a second source of truth for these actions.

### Architectural result

The first real expansion gameplay mutations now follow:

**Input → GameState mutation boundary → canonical persistence → runtime projection**

`Expansion.gd` remains a transitional projection for the remaining expansion operations, but purchase and property upgrade no longer need to mutate it directly from `main.gd`.

### Verified commits

- `6ead94a266af815a459b5285da099a61a0cfa979` — route expansion purchase and upgrade through GameState
- `6a32d7c21a0a6fa54e4a41d2bc5ff8c7fed76416` — preserve expansion purchase and upgrade runtime effects

### Verification status

Static source review was performed after the changes. A Godot executable is not available in the current environment, so runtime Godot tests were **not** claimed as passing.

## 2026-09-02 — Canonical expansion mutation boundary

### Fixed in this pass

- Added `scripts/expansion_state.gd` (`RenewExpansionState`) as the canonical mutation adapter for the `GameState.expansion` container.
- Added guarded mutation helpers for expansion properties and resource sites.
- Added canonical purchase helpers for expansion properties and resource sites; they validate ownership/cash and update canonical cash, reputation and restored-count state atomically.
- Added canonical property/resource upgrade helpers so level, income/value, output/risk and cash changes are recorded together in `GameState`.
- Added a canonical expansion day-advance helper for day, cash and population deltas.
- Added canonical resource generation persistence for owned resource sites.
- Kept the adapter deliberately independent of the `Expansion` Node so the durable state boundary does not depend on UI/runtime objects.
- Preserved `Expansion`'s existing public API for the current UI while this adapter becomes the controlled migration point for the next integration pass.

### Architectural result

The expansion persistence boundary now has an explicit mutation API instead of requiring callers to edit the nested `GameState.expansion` dictionary directly.

**GameState** remains the durable authority.

**RenewExpansionState** is the controlled mutation boundary.

**Expansion** remains the transitional runtime/UI projection until its remaining mutation methods are routed through this boundary.

### Verified commits

- `f1231e86c962aa4360d6e2a15a1c6c2022403248` — canonical expansion mutation boundary
- `bf4700feb13999b000619780549c494879cdbc21` — canonical resource generation mutation
- `c29c4233a2481989139c2549854174967ca2005d` — expansion state regression tests

## 2026-09-02 — Canonical state refactor continuation

### Fixed in this pass

- Added `GameState.restore()` so canonical state can be rehydrated safely during load and migration.
- Added canonical property records under `GameState.properties` with stable property ID `old_warehouse`.
- Added property mutation APIs and runtime synchronization/restoration.
- Corrected core property activity semantics: the physical property is active only when its restoration stage is `Operational`; opening the Business is a separate state.
- Routed the core `main.gd` property lifecycle through GameState instead of leaving property persistence solely in Main scalar fields.
- Routed core Business mutations through canonical GameState Business APIs while retaining scalar projections only for compatibility/UI.
- Added a canonical `GameState.expansion` boundary containing expansion properties, resource sites, management state, day, population and selected expansion.
- Added migration defaults for expansion state so older saves receive a valid expansion container without losing existing state.
- Updated `SaveSystem` to capture the live expansion runtime into GameState at save time and restore it at load time.
- Removed the unsafe `main.gd` load-time `has_variable()` dependency from the save path. SaveSystem now applies an explicit compatibility projection to Main and returns only the result contract Main expects.
- Synchronized expansion runtime with the core Main economy around expansion actions and the daily empire simulation.
- On load, expansion is restored after the canonical core state and then synchronized back to the current Main projection.
- Preserved Branch persistence separately from Business, Property and Expansion persistence.
- Preserved persistent employee records and role-aware workforce integration.

### Important architectural result

The current transitional model has explicit persistent boundaries:

**Property** = physical restoration/acquisition lifecycle (`GameState.properties.old_warehouse`)

**Business** = company operating state (`GameState.businesses.renew_goods`)

**Branch** = regional operating unit (`GameState.branches`)

**Expansion** = owned expansion properties/resource sites and expansion-management state (`GameState.expansion`)

Main scalar fields remain compatibility projections rather than the intended durable save authority.

### Still incomplete

- Final Main cash/reputation projection cleanup for canonical resource-site mutations.
- Direct `Expansion.gd` resource-site mutation removal.
- Full resource → extraction → transport → processing → manufacturing → distribution → retail → customer chain.
- Expansion operating-day mutation still has a transitional runtime calculation layer.
- The full property catalog is not yet represented canonically; the core boundary currently covers the Old Warehouse lifecycle while expansion assets live under the Expansion container.
- `main.gd` remains a large orchestration object and still owns runtime compatibility projections and several simulation rules.
- Employee management UI is incomplete.
- Corporate History and RENEW Daily still need broader real-event integration.
- Resource/production/supply-chain depth remains below the master plan target.
- Competitor memory, ownership/shareholder systems, acquisitions/mergers, finance consequences, technology, research, global rankings, HQ progression, museum, liveops and multiplayer remain incomplete.
- Automated balance tests and Android/manual playtest verification remain outstanding.

A system is not marked complete until **Code → Integration → Persistence → UI → Simulation behavior → Tests** are verified.
