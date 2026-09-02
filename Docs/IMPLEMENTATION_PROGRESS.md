# RENEW — Implementation Progress Log

> Verified implementation work on `feature/foundation-v11-implementation`.

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

### Next integration step

- Route resource-site purchase and upgrade through the same canonical boundary.
- Route resource generation/stock mutation through GameState.
- Route expansion `operate_day()` through canonical day/economic mutations without double-applying cash/day/population changes.
- Add focused save/load regression coverage for expansion purchase, property upgrade, resource-site ownership/upgrade and legacy migration.

## 2026-09-02 — Canonical expansion mutation boundary

### Fixed in this pass

- Added `scripts/expansion_state.gd` (`RenewExpansionState`) as the canonical mutation adapter for the `GameState.expansion` container.
- Added guarded mutation helpers for expansion properties and resource sites.
- Added canonical purchase helpers for expansion properties and resource sites; they validate ownership/cash and update canonical cash, reputation and restored-count state atomically.
- Added canonical property/resource upgrade helpers so level, income/value, output/risk and cash changes are recorded together in `GameState`.
- Added a canonical expansion day-advance helper for day, cash and population deltas.
- Kept the adapter deliberately independent of the `Expansion` Node so the durable state boundary does not depend on UI/runtime objects.
- Preserved `Expansion`'s existing public API for the current UI while this adapter becomes the controlled migration point for the next integration pass.

### Architectural result

The expansion persistence boundary now has an explicit mutation API instead of requiring callers to edit the nested `GameState.expansion` dictionary directly.

**GameState** remains the durable authority.

**RenewExpansionState** is the controlled mutation boundary.

**Expansion** remains the transitional runtime/UI projection until its remaining mutation methods are routed through this boundary.

### Verified commit

- `f1231e86c962aa4360d6e2a15a1c6c2022403248` — canonical expansion mutation boundary

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
- Synchronized expansion runtime with the core Main economy around expansion actions and the daily empire simulation. This prevents `expansion.gd`'s legacy `cash`, `reputation`, and `day` fields from drifting away from the actual player state during the transitional architecture.
- On load, expansion is restored after the canonical core state and then synchronized back to the current Main projection.
- Kept Branch persistence separate from Business, Property and Expansion persistence.
- Preserved the existing persistent employee records and role-aware workforce integration.

### Important architectural result

The current transitional model has explicit persistent boundaries:

**Property** = physical restoration/acquisition lifecycle (`GameState.properties.old_warehouse`)

**Business** = company operating state (`GameState.businesses.renew_goods`)

**Branch** = regional operating unit (`GameState.branches`)

**Expansion** = owned expansion properties/resource sites and expansion-management state (`GameState.expansion`)

Main scalar fields remain compatibility projections rather than the intended durable save authority.

### Verified commits from this pass

- `dbea6c6f2ed4b449b5ddf0d8356e39ababa491c3` — GameState schema v4, canonical expansion container, migration and property activity correction
- `74638ebda5ff032d23b7a063b45ec6a7a4722771` — SaveSystem expansion capture/restore and safe explicit Main projection
- `830a96ed8f67871ec3d0802448543f5b1b150b95` — synchronize expansion runtime with Main's authoritative cash/reputation/day around gameplay mutations

### Still incomplete

- Expansion resource-site purchase/upgrade, resource generation and operating-day mutation still need canonical routing.
- The full property catalog is not yet represented canonically; the core boundary currently covers the Old Warehouse lifecycle while expansion assets live under the Expansion container.
- `main.gd` remains a large orchestration object and still owns runtime compatibility projections and several simulation rules.
- Employee management UI is incomplete.
- Corporate History and RENEW Daily still need broader real-event integration.
- Resource/production/supply-chain depth remains below the master plan target.
- Competitor memory, ownership/shareholder systems, acquisitions/mergers, finance consequences, technology, research, global rankings, HQ progression, museum, liveops and multiplayer remain incomplete.
- Automated balance tests and Android/manual playtest verification remain outstanding.

A system is not marked complete until **Code → Integration → Persistence → UI → Simulation behavior → Tests** are verified.
