# RENEW System Ownership & Version Policy

## Purpose

This document is the architecture boundary for the RENEW prototype. Every gameplay domain has one declared generation and one ownership rule so future agents do not accidentally revive an older contract.

### Labels

- **V1 AUTHORITATIVE** — current playable contract; new gameplay code may depend on it.
- **LEGACY/MIGRATION** — retained only for old saves, compatibility, historical UI, or migration; new gameplay code must not depend on it.
- **V1.5** — implemented extension around the V1 core; it may depend on V1 authoritative systems, but V1 core must not depend on it.
- **V2** — planned/advanced systems; not a dependency of the V1 core.
- **V3** — long-term/endgame systems; not a dependency of V1/V1.5.
- **TECHNICAL** — infrastructure, orchestration, adapters, UI, persistence, or test support; it owns no independent gameplay truth.

## Current ownership registry

| Domain / system | Primary script(s) | Generation | Rule |
|---|---|---|---|
| Persistent state | `game_state.gd` | **V1 AUTHORITATIVE** | Canonical state boundary. Legacy flat saves may be migrated into it. |
| Domain adapter | `domain_system.gd` | **TECHNICAL** | Shared state access infrastructure; no gameplay rules. |
| Property / restoration | `property_system.gd` | **V1 AUTHORITATIVE** | Owns property inspection, acquisition and restoration. |
| Business | `business_system.gd` | **V1 AUTHORITATIVE** | Owns business identity and V1 industry selection/production orchestration. |
| Economy | `economy.gd` | **V1 AUTHORITATIVE** | Owns the canonical five V1 market resources: timber, iron, energy, food, electronics. |
| Production | `production_system.gd` | **V1 AUTHORITATIVE** | Owns production recipes, inventory, machines, output and quality. |
| Production compatibility facade | `production.gd` | **LEGACY/MIGRATION** | Compatibility wrapper for the old Main API. Do not use for new gameplay rules. |
| Supply chain | `supply_chain_system.gd` | **V1 AUTHORITATIVE** | Owns procurement, warehouse flow, processing and transport capacity. |
| Contracts | `contract_system.gd` | **V1 AUTHORITATIVE** | Owns contract state and execution. `contract_command_system.gd` is its command adapter. |
| Employees | `employee_system.gd` | **V1 AUTHORITATIVE** | Owns employee records and workforce rules. Command/UI files are adapters. |
| Competitors | `competitors.gd` | **V1 AUTHORITATIVE** | Owns rival state. Reaction/AI helpers must not create a second rival ledger. |
| Competitor reactions | `competitor_reaction_system.gd` | **V1 AUTHORITATIVE** | Owns reactive competitor behavior against the authoritative rival state. |
| Ownership | `ownership_system.gd` | **V1 AUTHORITATIVE** | Sole source of shares, holders, voting, board control and takeover defense. |
| Finance | `finance_system.gd` | **V1 AUTHORITATIVE** | Unified financial ledger for cash, debt, financing and solvency. |
| Acquisitions | `acquisition_system.gd` | **V1 AUTHORITATIVE** | Owns acquisition/merger transaction records. |
| Alliances | `alliance_v1_system.gd` | **V1 AUTHORITATIVE** | V1 alliance/cooperative-project contract. |
| Older alliance layers | `alliance_system.gd`, `alliance_ai.gd`, `alliance_control_system.gd`, `alliance_coup_ai.gd` | **V2** | Advanced alliance/coup behavior; not a V1-core dependency. |
| Diplomacy | `diplomacy_system.gd` and related AI/effects/bridges | **V2** | Advanced diplomatic layer. |
| Scarcity | `scarcity_system.gd` | **V1 AUTHORITATIVE** | Propagates resource scarcity into the V1 economy. |
| Demand | `demand_model.gd`, customer-segment systems | **V1 AUTHORITATIVE** | V1 market demand behavior; UI remains technical. |
| Branches / multi-region | `branches.gd`, `branch_controller.gd`, region/district systems | **V1.5** | Extension above the one-region V1 core. It may consume V1 economy/supply/production contracts. |
| Infrastructure | `infrastructure_system.gd` | **V1.5** | Regional/logistics infrastructure extension. |
| Technology | `technology_system.gd` | **V2** | Research/technology progression beyond the minimum V1 foundation. |
| World / dynamic events | `events.gd`, `dynamic_event_controller.gd`, world-event systems | **V1 AUTHORITATIVE** | V1 causal events may modify the core simulation. Advanced event layers are V2+. |
| Progression | progression/milestone systems | **V1 AUTHORITATIVE** | Player progression and V1 unlocks. |
| History | `history_system.gd` | **V1 AUTHORITATIVE** | Permanent historical record. |
| News | `news_system.gd` | **V1 AUTHORITATIVE** | Derived news presentation from actual state/events. |
| Analytics | `analytics_system.gd` | **TECHNICAL** | Telemetry/measurement only; must not make gameplay decisions. |
| Simulation | `simulation_system.gd` | **TECHNICAL** | Simulation/application orchestration; receives authoritative system instances through context. |
| Gameplay commands | `gameplay_command_system.gd` and command-system files | **TECHNICAL** | Command boundary. It routes player intent to authoritative systems. |
| Save/autosave | `save_system.gd`, `autosave.gd`, state bridge | **TECHNICAL** | Persistence infrastructure; must not become a second gameplay ledger. |
| Corporate compatibility layer | `corporate.gd` | **LEGACY/MIGRATION** | Retained while corporate UI/compatibility is migrated to `OwnershipSystem`. |
| Corporate legacy archive | `corporate_legacy_system.gd` | **LEGACY/MIGRATION** | Historical/legacy artifact collection only. New gameplay must not import it. |
| Headquarters / museum / legacy | headquarters and museum/legacy systems | **V3** | Long-term corporate legacy/endgame layer. |
| LiveOps | `liveops_system.gd` | **V2** | Post-core content/operations layer. |

## Canonical V1 contracts

The V1 economy contract is exactly five live market resources:

`timber`, `iron`, `energy`, `food`, `electronics`

The former `materials`, `packaging`, and `fuel` identifiers are migration inputs only. They must never be added back to live V1 economy state.

The V1 production authority is `production_system.gd`. `production.gd` is a compatibility facade and must not become a new gameplay dependency.

## Legacy dependency rule

New gameplay code **MUST NOT** import a `LEGACY/MIGRATION` script with `preload()` or `load()`.

Allowed exceptions are existing, explicitly temporary compatibility boundaries. Those exceptions must be documented here and must not receive new gameplay rules.

Legacy code may read or translate authoritative V1 state when performing migration. The dependency direction must remain:

`LEGACY/MIGRATION → V1 AUTHORITATIVE`

never:

`V1 AUTHORITATIVE → LEGACY/MIGRATION`

## Test-generation rule

Tests are also classified by purpose:

- architecture/integrity tests validate structure and dependency boundaries;
- V1 feature tests validate behavior;
- V1.5/V2/V3 tests validate only their declared layer;
- legacy migration tests may exercise migration adapters but must not define the current gameplay contract.

A test name such as `full_coverage` must not be interpreted as proof of behavioral coverage. Behavioral claims require feature-level tests.
