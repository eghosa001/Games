# RENEW — Implementation Progress Log

> This file records **verified code changes** on `feature/foundation-v11-implementation`. It is deliberately separate from the master specification so the specification remains the target architecture while this log records what is actually implemented.

## 2026-09-02 — Foundation / Employee integration

### Fixed

- Added a canonical `RenewGameState` employee section using `{ next_id, records }` rather than treating the employee count as the authoritative employee data.
- Added schema version 3 handling and migration for older employee save shapes.
- Added persistent employee records with identity, role, skill, experience, career level, salary, loyalty, morale, ambition, personality, productivity, specialization, assignment and history references.
- Added employee creation, firing, promotion, training and daily progression APIs.
- Integrated an `EmployeeController` into the main scene so the employee system can restore/bootstrap, reconcile the transitional legacy count, tick daily progression and expose payroll/productivity/morale metrics.
- Employee wages now use the real employee salary model; the controller reconciles the old prototype `$180 × employee count` payroll so existing gameplay does not silently double-charge or ignore the new salary model.
- Employee state and employee analytics are written into `RenewGameState`.
- Confirmed `RenewGameState` is an autoload in `project.godot`.
- Confirmed `EmployeeController` and `StoryController` are attached to `Main.tscn`.
- Converted `game_state_bridge.gd` into a compatibility bridge only; it no longer owns a second save file.
- Fixed save/load compatibility so canonical employee rosters remain dictionaries inside `GameState`, while the transitional `main.gd` load path receives an integer employee count instead of accidentally assigning a dictionary to the legacy employee variable.

### Production integration fixed

- `ProductionSystem` consumes the canonical role-aware `employee_production_efficiency` metric, with a safe fallback to average productivity for older state.
- Requested production capacity is converted into staffed production cycles using real workforce productivity.
- Low-productivity or poorly matched staffing can reduce production throughput; stronger production roles can increase it within safe bounds.
- Missing resource keys are handled safely.
- Production results expose `staffing_efficiency` and failure reasons for downstream UI/history systems.

### Role suitability integration fixed

- `EmployeeController` exposes an explicit assignment API for active employees.
- Supported assignment targets are business, property, branch, logistics, sales and management, with assignment changes recorded in employee history.
- Added `assigned_employee_ids()` and `assigned_count()` so operating systems can query the actual persistent workforce assigned to a specific unit.
- Role-aware operating metrics are calculated from actual employee records.
- Technician/Worker/Supervisor/Manager weighting is stronger for production; Sales is stronger for selling; Logistics is stronger for logistics; Accountant/Supervisor/Manager contribute more to management.
- Role metrics are published to canonical `GameState.analytics`, including production, sales, logistics and management efficiency plus role-relevant headcounts.

### Logistics integration fixed

- `SupplyChain` consumes the canonical `employee_logistics_efficiency` metric.
- Resource-site transfers use effective transport capacity derived from logistics staffing.
- Daily network updates report logistics efficiency and effective transport capacity.
- Existing transport-capacity arguments remain supported for compatibility.

### Branch workforce integration fixed

- Branch launch no longer invents a staffing count. It opens the operating unit with zero staff and the controller creates three persistent employee records assigned to that branch.
- Branch hiring now routes through `EmployeeController.hire_for_assignment()` and assigns the new employee to a concrete `branch_<index>` target.
- Existing employees from older saves whose assignment is still `renew_goods` are migrated to the existing flagship branch instead of being duplicated.
- Branch staffing projections are refreshed from actual active employee assignments before daily operations and UI rendering.
- Branch production/sales capacity reaches zero when a branch has no assigned employees, preventing a branch from generating operating output from an orphaned integer count.
- Branch P&L still includes employee wage expense, but branch cash contribution excludes payroll because `EmployeeController` charges company payroll once per day. This removes the previous double-charge while preserving wage expense in branch P&L.
- Fixed startup ordering: branch migration now waits until `EmployeeController` has completed restore/bootstrap, preventing old employees from being missed because `Main.tscn` initializes `BranchController` before `EmployeeController`.
- Branch operation results continue to expose the employee metrics used by the simulation.

### Core business workforce integration — latest

- Removed the direct scalar employee increment from `main.gd` hiring.
- Core business hiring now creates a persistent employee and assigns them to the flagship operating unit (`branch_0`).
- Core hiring cost is based on the actual assigned workforce rather than the legacy scalar count.
- Core employee count displayed by `main.gd` is synchronized from persistent assignments.
- Core production uses `EmployeeController.effective_staffing()` instead of treating the scalar employee count as authoritative.
- Removed the old `$180 × employee count` core-business wage calculation from daily profit.
- Central `EmployeeController` payroll is now the sole wage charge during normal operation.
- Core business opening migrates legacy `renew_goods` employees to the flagship operating unit before reporting its workforce.

### Canonical branch persistence — latest

- `RenewGameState.branches` is now treated as the persistent branch boundary instead of an unused placeholder.
- Branch records are stored under stable IDs (`branch_0`, `branch_1`, etc.) with selected-branch state alongside them.
- `BranchController` restores branch records from `GameState` during startup and seeds the canonical state for a genuinely new game.
- Branch selection, launch, hiring, stocking, price changes, upgrades and daily operating results now push their branch state back into `GameState`.
- Branch staffing remains derived from persistent employee assignments; the `employees` field is only a compatibility/UI projection and cannot create operating staff by itself.
- `GameState.capture()` no longer allows a transient `core["branches"]` value to overwrite canonical branch records.
- Schema migration converts legacy branch arrays into keyed canonical branch records without discarding saved branch data.

### Canonical business persistence boundary — latest

- Added an explicit `RenewGameState` business boundary for `renew_goods` with stable business ID and durable fields for open state, capacity, marketing, price, inventory, sales, profit and contract state.
- Added `get_business()`, `set_business_value()`, `sync_business_runtime()` and `restore_business_runtime()` APIs so future systems can stop treating `main.gd` scalars as persistent ownership.
- `GameState.capture()` no longer blindly copies business scalar fields into the canonical record when that record already exists. Legacy scalar fields are imported only when a canonical field is genuinely missing.
- Save/load now routes business synchronization through `GameState` instead of maintaining a second business save structure in `SaveSystem`.
- Load restores the complete business compatibility projection, including sales/profit totals and contract state, not only open/capacity/marketing/price/inventory.
- Older saves that contain only top-level business fields are migrated into the canonical `businesses.renew_goods` record.
- This is a persistence-boundary improvement, not a claim that the full BusinessSystem refactor is finished: `main.gd` still temporarily mutates compatibility fields at runtime.

### Save/load rehydration fixed — latest

- Loading a save now rehydrates the live `BranchController` from canonical `GameState.branches`; loaded branches no longer remain at scene defaults until a restart.
- Loading also reconstructs `main.gd`'s remaining business compatibility projection from the canonical `GameState.businesses.renew_goods` record.
- The durable business record remains under `GameState`; the top-level business values returned during load exist only as a compatibility bridge for the transitional `main.gd` runtime.
- This closes a persistence gap where business/branch data could be written to the canonical state but not fully rehydrated into the currently running scene after an in-session load.

### Commits

- `d3b2e9e625d178e4183d64bbaa77f3534c8e4ff` — employee system fix
- `3af59b2a09a7b229b617a13c80cef1bca7306b82` — canonical employee preservation in GameState
- `b834c5898a12b7d8f3f802db45c877e0e6e717dc` — save-system employee preservation
- `ef4e98b484a711daaf7b14bc1ef945a37fc30a13` — employee runtime integration
- `c94682be5be4db70ca66e5111ffe382027576843` — legacy employee-count load compatibility
- `123aec00591ffb927ea01842177fc90e4a312e13` — employee synchronization fix
- `b4df022a45aedd7700809047c4c2131db90d970b` — production staffing integration
- `0ca8372c2cc319ad841ef027b9d18e4b6796871e` — role-aware employee metrics and assignments
- `ea165da87103c6f42226d4aa5c3a872c6d7e6c3d` — production consumes role-aware staffing efficiency
- `0fc8116918f141eb081ac10338a05470b51b2cf0` — logistics staffing affects network transport capacity
- `93d40d2943edb72ae618626e61138a659e3ba0f4` — branch operations consume Sales/Logistics/Management metrics
- `26446b9a80226e90bfbb8564fd2c46c9c34d4ae4` — employee assignment query helpers and authoritative branch staffing API
- `1bf80082f449b4f924b00cc1439a32ba425bd535` — branch launch/hiring routed through persistent employee records
- `831d77cf55be4b80b5e1e390e2b7d3e153a66250` — branch payroll double-charge prevention
- `f992e66ead24d1601737892af37dfeca5dbe63f1` — startup-safe employee migration into branch assignments
- `eb845de0d1fb555b86b128104863aac1ab8c0893` — core business hiring/payroll integration
- `1985d331c3354fb6510f51ff02ab574441866d63` — GameState canonical branch persistence boundary
- `d2018c4e99df5454dc0556e323c4749095158ced` — BranchController restore/sync integration
- `b65ff9d964a5870e2fcf4f2f815719482bfa8743` — branch controller syntax correction after persistence integration
- `24584c5635a79287a7dde4112e658869c11f9009` — legacy branch-array migration
- `d0d634b78c63f667a4774b7a5cd1e6615cb828a5` — save/load rehydration for canonical business and branch state
- `dd1a662af809a816606833396c65f8344e66d932` — canonical business state boundary and migration safety
- `35ceda5aba06bc139363da95a74d6a5429b5955d` — save/load routed through canonical business boundary

## Story systems verified

The repository also contains:

- `history_system.gd` — persistent corporate history records and milestones.
- `news_system.gd` — persisted RENEW Daily editions.
- `story_controller.gd` — detects restoration/business/reputation milestones and feeds history/news into GameState.

These are **foundation implementations**, not yet the full V1.1 completion gate: employee UI management, richer event sources, full personalized news sections, deeper production staffing effects, and full history coverage still need integration.

## Still incomplete after this pass

- `main.gd` remains transitional and still contains compatibility business/workforce scalars; these are no longer intended to be persistent authority, but business mutations are still performed there at runtime.
- Employee assignment is available in the controller API but is not yet exposed through the complete mobile UI.
- Employee hiring UI does not yet expose candidates, roles, salaries, skills or personalities.
- Employee firing/promotion/training are not yet exposed through the complete mobile UI.
- Corporate History does not yet receive every important transaction/event type.
- RENEW Daily does not yet consume the full market/rival/supply-chain/news event stream.
- Property and Business state are not yet fully separated from legacy `main.gd`/runtime ownership; Branch now has a canonical persistence boundary but the full Property → Business → Branch refactor remains.
- Balance testing and Android manual validation remain outstanding.

## Next implementation target

Continue in the master implementation order:

1. replace remaining `main.gd` business mutations with canonical Business APIs while preserving compatibility UI fields;
2. complete Property → Business → Branch separation and move property lifecycle into canonical state;
3. remove remaining legacy workforce reconciliation once all migration paths are covered;
4. finish employee management UI and history/news runtime event coverage;
5. extract data-driven balance definitions;
6. deepen resource/production/supply-chain simulation;
7. add acquisition/ownership/finance consequences on top of stable canonical state.

A feature should only be marked complete after **Code → Integration → Persistence → UI → Simulation behavior → Tests** has been verified.
