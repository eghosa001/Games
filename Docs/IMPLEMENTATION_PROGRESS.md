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
- `5bee414b476e847a96e4510b3dccb61d48ee86e6` — progress documentation update

## Story systems verified

The repository also contains:

- `history_system.gd` — persistent corporate history records and milestones.
- `news_system.gd` — persisted RENEW Daily editions.
- `story_controller.gd` — detects restoration/business/reputation milestones and feeds history/news into GameState.

These are **foundation implementations**, not yet the full V1.1 completion gate: employee UI management, richer event sources, full personalized news sections, deeper production staffing effects, and full history coverage still need integration.

## Still incomplete after this pass

- `main.gd` remains transitional and still contains the legacy scalar employee count, direct fixed-role hiring path, and legacy core-business payroll calculation.
- The core-business hire action has not yet been safely replaced with an EmployeeController transaction because `main.gd` is still a large transitional orchestration file and needs a controlled refactor rather than a partial string-level change.
- Employee assignment is available in the controller API but is not yet exposed through the complete mobile UI.
- Employee hiring UI does not yet expose candidates, roles, salaries, skills or personalities.
- Employee firing/promotion/training are not yet exposed through the complete mobile UI.
- Corporate History does not yet receive every important transaction/event type.
- RENEW Daily does not yet consume the full market/rival/supply-chain/news event stream.
- Property, Business and Branch are not yet fully separated into authoritative systems.
- Branch state itself still needs canonical persistence integration; current runtime branch data remains owned by `Branches` until the Property/Business/Branch refactor.
- Balance testing and Android manual validation remain outstanding.

## Next implementation target

Continue in the master implementation order:

1. remove the direct legacy hiring path from `main.gd` and route core-business hiring through EmployeeController;
2. remove the legacy core-business wage calculation once payroll is fully authoritative in EmployeeController;
3. persist branch/business state through GameState as part of the Property → Business → Branch boundary refactor;
4. finish employee management UI and history/news runtime event coverage;
5. extract data-driven balance definitions;
6. deepen resource/production/supply-chain simulation.

A feature should only be marked complete after **Code → Integration → Persistence → UI → Simulation behavior → Tests** has been verified.
