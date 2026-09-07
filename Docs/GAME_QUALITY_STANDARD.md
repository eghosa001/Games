# RENEW — Game Quality Acceptance Standard

**Status:** Active project gate  
**Purpose:** Define what “finished” means for RENEW and turn quality into measurable acceptance tests rather than subjective fixes.

> RENEW is a property-restoration, business-management, regional-economy and empire-building simulation. The target is commercial-grade presentation and reliability while maintaining a distinct RENEW identity.

---

## 1. The Master Acceptance Test

A release is acceptable only when all critical gates pass and the total quality score is at least **90/100**.

### The 10-second test

> **A new player must be able to look at the game world for 10 seconds and understand that this is a property-restoration and empire-building simulation without needing to read the UI.**

The world must communicate the core fantasy through buildings, roads, districts, activity, restoration states and visible progression.

### Automatic failure

Any of the following blocks release regardless of score:

- Main scene does not load reliably.
- A core gameplay action causes an error, crash or unrecoverable state.
- Placeholder rectangles/temporary geometry remain where final gameplay buildings should be.
- A property cannot visibly change after restoration or construction.
- UI reports an action succeeded but the world/simulation does not reflect it.
- Owned, available and unavailable properties cannot be visually distinguished.
- A core progression path is impossible to complete.
- Save/load can corrupt or duplicate core game state.
- Major simulation values can be created, destroyed or changed outside their authoritative systems in a way that breaks accounting.
- Missing resources, broken node references or script errors prevent a normal play session.

---

# 2. Quality Score — 100 Points

## A. Environment & World — 20 points

- [ ] World is visually populated rather than an empty background.
- [ ] Roads/paths and property plots form a coherent layout.
- [ ] Background scenery gives the player a sense of place and scale.
- [ ] Districts/regions have recognizable visual identity.
- [ ] Ground, roads, buildings and scenery share a coherent scale.
- [ ] There is sufficient environmental variation to avoid obvious repetition.
- [ ] Camera framing keeps important gameplay areas readable.

**Pass target: 18/20.**

## B. Buildings & Property Visuals — 25 points

- [ ] No final-gameplay building is represented only by a placeholder rectangle.
- [ ] Major property types are visually distinguishable.
- [ ] Buildings have believable proportions and silhouettes.
- [ ] Building condition is visible without opening a statistics panel.
- [ ] Restoration changes the actual building appearance.
- [ ] Restoration has multiple recognizable visual states.
- [ ] Construction creates visible structural progress.
- [ ] Completed properties look materially better than abandoned properties.
- [ ] Businesses have recognizable visual identity/signage where appropriate.
- [ ] Building sprites/models are consistent with the game's art direction.

**Pass target: 23/25.**

## C. World Life & Activity — 15 points

- [ ] Workers/NPCs are visible where appropriate.
- [ ] Customers or business activity appears around operating businesses.
- [ ] Deliveries/logistics have visible representation where appropriate.
- [ ] Ambient movement prevents the world from feeling static.
- [ ] Restoration/construction has visible activity.
- [ ] Successful businesses feel busier than abandoned properties.
- [ ] The world communicates economic activity, not just numerical statistics.

**Pass target: 13/15.**

## D. Lighting, Effects & Presentation — 10 points

- [ ] Lighting makes buildings and important objects readable.
- [ ] Shadows/highlights provide depth where supported by the chosen art style.
- [ ] Restoration produces satisfying visual feedback.
- [ ] Construction/business activity has appropriate effects or animation.
- [ ] State transitions are visually understandable.

**Pass target: 9/10.**

## E. Consistency & Art Direction — 10 points

- [ ] UI and world use a coherent visual language.
- [ ] Typography is readable and consistent.
- [ ] Colors communicate state consistently.
- [ ] Icons/assets belong to the same visual system.
- [ ] No obvious mixture of unrelated placeholder and final art remains in the same gameplay area.
- [ ] Visual hierarchy makes important objects/actions immediately recognizable.

**Pass target: 9/10.**

## F. Performance & Stability — 10 points

- [ ] No persistent script errors during normal play.
- [ ] No major frame-rate degradation during ordinary gameplay.
- [ ] No runaway timers/process loops.
- [ ] No obvious memory/resource leak during extended play.
- [ ] Scene transitions/load operations remain stable.
- [ ] Mobile/responsive presentation remains usable on supported screen sizes.

**Pass target: 9/10.**

## G. Gameplay/Simulation Integration — 10 points

- [ ] Every important simulation state has an understandable player-facing representation.
- [ ] Property ownership is reflected in the world.
- [ ] Restoration progress is reflected in the world.
- [ ] Business operation is reflected in the world.
- [ ] Economic growth produces understandable visible consequences.
- [ ] Expansion creates new visible opportunities/territory.
- [ ] Player actions have clear feedback and persistent consequences.

**Pass target: 9/10.**

> **Scoring rule:** 90+ is release quality. 80–89 is development/beta quality. Below 80 requires another quality pass.

---

# 3. Automated Functional Acceptance Tests

These should become executable tests wherever practical.

## Boot

- [ ] Project starts from a clean launch.
- [ ] Main scene loads without script errors.
- [ ] Required autoloads/singletons initialize correctly.
- [ ] Required resources exist.
- [ ] Required scene/node references resolve.
- [ ] No unexpected orphan nodes are created during startup.

## New Game

- [ ] New game creates a valid initial state.
- [ ] Player receives the intended starting resources/assets.
- [ ] Initial property exists and is selectable.
- [ ] Ownership is correctly established.
- [ ] Initial UI reflects the same state as the simulation.

## Restoration

- [ ] Property can enter restoration.
- [ ] Required resources/cash are validated before spending.
- [ ] Restoration progresses at a frame-rate-independent rate.
- [ ] Restoration cannot progress twice because of duplicate timers/processes.
- [ ] Each restoration stage persists correctly.
- [ ] Visual property state changes with restoration state.
- [ ] Completion unlocks the correct next gameplay state.

## Business

- [ ] A completed property can become an operating business where intended.
- [ ] Business setup validates requirements atomically.
- [ ] Operating businesses generate the intended economic effects.
- [ ] Business activity is represented in the world/UI.
- [ ] Closing/suspending a business stops the relevant effects.

## Expansion

- [ ] Available properties can be discovered.
- [ ] Purchase/acquisition validates ownership and resources.
- [ ] Failed acquisitions do not partially mutate state.
- [ ] Newly acquired properties appear correctly in the world.
- [ ] Regions unlock according to their rules.
- [ ] Expansion produces visible and simulation consequences.

## Save/Load

- [ ] Save succeeds from normal gameplay.
- [ ] Load reconstructs the same authoritative state.
- [ ] Money/resources/assets are neither duplicated nor lost unexpectedly.
- [ ] Ownership survives save/load.
- [ ] Restoration/business/expansion state survives save/load.
- [ ] Invalid or partial save data fails safely.

---

# 4. Economy & Accounting Acceptance Tests

The simulation must have a single authoritative path for important financial mutations.

- [ ] Cash cannot be mutated through uncontrolled legacy/direct paths.
- [ ] Revenue is recorded as revenue and reflected in cash through the intended transaction path.
- [ ] Expenses are recorded correctly and reflected in cash exactly once.
- [ ] Assets and liabilities are not silently treated as cash.
- [ ] Accrued amounts are not incorrectly removed from cash before payment.
- [ ] Transfers are atomic: either all required state changes happen or none happen.
- [ ] Failed transactions leave the game state unchanged.
- [ ] Repeated ticks do not duplicate transactions.
- [ ] Interest/accrual logic is frame-rate independent.
- [ ] Economic calculations use consistent time units.
- [ ] Save/load preserves accounting state without creating phantom cash.

### Accounting invariant

For every authoritative transaction:

**Opening state + transaction = valid closing state**

There must be no hidden second mutation path that changes the same balance outside the transaction.

---

# 5. Visual Progression Acceptance Test

Every important property must tell a visual story.

### Abandoned

Expected characteristics may include:

- neglected facade
- broken/damaged elements
- debris or overgrowth
- subdued activity
- visibly poor condition

### Restoration underway

Expected characteristics may include:

- scaffolding
- workers
- construction materials
- partially repaired surfaces
- visible work activity

### Restored

Expected characteristics may include:

- finished facade
- improved surroundings
- lighting/signage where appropriate
- people/activity
- visibly higher-quality presentation

### Successful business

Expected characteristics may include:

- customers or users
- employees/workers
- deliveries/logistics
- increased activity
- stronger visual identity

### Empire

As the player expands, the world should visibly communicate:

- multiple owned properties
- increasingly developed districts
- stronger corporate identity
- larger economic activity
- regional specialization
- progression from individual restoration to an organized empire

---

# 6. Major-Simulation-Game Visual Benchmark

The target is **commercial-grade simulation presentation**, not imitation of another game's exact art style.

Use these principles as the benchmark:

- **The Sims:** readable spaces, strong visual feedback and recognizable objects.
- **Cities: Skylines:** coherent world composition, districts, infrastructure and believable activity.
- **Anno:** economic progression, production identity and visual sense of growth.
- **Two Point:** strong visual communication, readable stylization and personality.

RENEW must combine the useful quality principles while retaining its own identity:

> **Property restoration → business creation → regional economy → corporate network → empire.**

The player should feel that their economic decisions physically change the world.

---

# 7. UI/UX Acceptance

- [ ] Player always knows current objective or most useful next action.
- [ ] Important actions are visually prominent.
- [ ] Costs and expected outcomes are clear before confirmation.
- [ ] Success/failure feedback is immediate and understandable.
- [ ] Important simulation changes are surfaced without overwhelming the player.
- [ ] Desktop navigation is coherent.
- [ ] Mobile navigation is coherent.
- [ ] Touch targets are sufficiently large on mobile.
- [ ] No clipped text, overlapping controls or inaccessible panels.
- [ ] World and UI communicate the same game state.

### UI rule

Never allow the UI to claim a state that the authoritative simulation does not actually contain.

---

# 8. Technical Architecture Acceptance

- [ ] Systems have clear ownership of state.
- [ ] Node lookups use the actual scene hierarchy.
- [ ] Scene references are not assumed to be direct children when they are nested.
- [ ] Autoload/singleton dependencies are explicit.
- [ ] Timer/process ownership is clear.
- [ ] Delta-time is used correctly for continuous simulation.
- [ ] Repeated initialization is safe or prevented.
- [ ] Signals are connected once.
- [ ] Save/load boundaries are explicit.
- [ ] UI code does not silently become an alternate simulation authority.
- [ ] Legacy compatibility code is removed or isolated when it can create conflicting state.

---

# 9. Regression Gate For Every Fix

Every code fix must answer all five questions:

1. **What was wrong?**
2. **What authoritative system should own the behavior?**
3. **What was changed?**
4. **How can the behavior be tested?**
5. **What existing behavior could this change regress?**

A fix is not considered complete merely because the code compiles.

---

# 10. Release Checklist

Before declaring a build “done”:

- [ ] Clean launch test passed.
- [ ] New-game test passed.
- [ ] Restoration test passed.
- [ ] Business test passed.
- [ ] Expansion test passed.
- [ ] Economy/accounting test passed.
- [ ] Save/load test passed.
- [ ] Desktop UI test passed.
- [ ] Mobile/responsive UI test passed.
- [ ] World visual test passed.
- [ ] Building progression visual test passed.
- [ ] No placeholder final-gameplay geometry remains.
- [ ] No known broken node paths remain.
- [ ] No known duplicate mutation paths remain.
- [ ] No critical script/runtime errors remain.
- [ ] Performance/stability test passed.
- [ ] Visual score >= 90/100.
- [ ] No automatic-failure condition remains.

---

# 11. Development Rule

From this point forward, repository work should be driven by this standard.

### Priority order

**P0 — Release blockers**

Crashes, broken boot, corrupted state, impossible progression, incorrect authoritative accounting, missing core references.

**P1 — Core gameplay defects**

Restoration, property ownership, business operation, expansion, save/load, simulation timing and player feedback.

**P2 — World quality**

Buildings, districts, roads, scenery, NPC/activity, construction/restoration visuals and environmental depth.

**P3 — Presentation polish**

Animation, effects, lighting, typography, transitions, responsive refinements and micro-interactions.

### Definition of done

A feature is **not done** when its code exists.

A feature is done when:

**Simulation works + UI works + world representation works + persistence works + regression test passes.**

---

# 12. Audit Record Template

Use this template for future deep-dive passes:

```text
## Audit Pass: <name>

### Scope
- Files:
- Systems:
- Gameplay area:

### Findings
- [P0/P1/P2/P3] <finding>

### Fixes
- <change>

### Verification
- <test performed>
- <result>

### Remaining
- <known issue or none>

### Quality Score Impact
- Before:
- After:
```

---

## Final Standard

RENEW is ready for release only when the player can **see the consequences of their decisions in the world**, the simulation remains economically and technically coherent, and the presentation feels like a deliberate commercial simulation game rather than a prototype.

**Target: 90/100 minimum + zero automatic failures.**
