# RESTORA Production Readiness Execution Prompt

## Mission
Act as RESTORA's lead game designer, Godot engineer, mobile UX engineer, simulation/economy engineer, QA owner, and Android release engineer. Work directly in the existing repository and finish every repository-side task that can truthfully move RESTORA from an internal release candidate to a production-ready candidate. Improve the current architecture; do not rebuild working systems.

RESTORA's long-form journey is:
**Discover → Inspect → Acquire → Restore → Operate → Hire → Produce → Sell → Reinvest → Expand → Compete → Negotiate → Form Alliances → Trade → Build Infrastructure → Research Technology → Acquire/Merge Companies → Build World Power → Develop Headquarters → Create a Legacy → Prestige / New Dynasty.**

The player must always understand what changed, why it changed, what they can do next, what it costs or risks, and which real system is affected.

## Non-negotiable architecture
- GameState and authoritative domain systems own gameplay truth.
- The UI may display state and invoke real actions; it must never become a second simulation.
- RenewFinanceSystem owns material money/debt mutations and each transaction happens exactly once.
- Preserve existing saves, package identity, public interfaces, and gameplay data unless a demonstrated production blocker requires a migration.
- Keep Godot 4.x compatibility, portrait-first mobile behavior, and GL compatibility unless deliberately changed for a proven reason.
- Do not enable ads, billing, analytics, network permissions, or production provider IDs without real account-side configuration.

## Production UX gate
Audit and fix the complete mobile journey:
- no overlapping screens, duplicate navigation, clipped important text, stale panels, or hidden critical actions;
- minimum 44×44 touch targets, preferably 48 px;
- fast vertical touch scrolling with no horizontal drift;
- bottom navigation never covers content;
- Android Back returns to the logical parent and Home Back opens the pause surface rather than corrupting state;
- only one focused deep/native screen is visible at a time;
- every visible button has a real route or authoritative action;
- same-view state-changing actions refresh immediately;
- progression-locked rows explain the unlock level and enable from the real progression system;
- Home Next Move and Company Progress remain useful through Level 10;
- light, dark, system theme, scalable text, reduced motion, and high contrast remain coherent across Figma and native screens.

## Progression gate
Use the semantic company-level progression:
1. Level 1 — restoration/core operations.
2. Level 2 — employees/contracts/finance.
3. Level 3 — regions/branches/supply chain.
4. Level 4 — competitors/ownership/alliances.
5. Level 5 — diplomacy/joint ventures/trade.
6. Level 6 — infrastructure/technology/research.
7. Level 7 — acquisitions/mergers/corporate strategy.
8. Level 8 — rankings/world power/headquarters.
9. Level 9 — museum/collections/legacy.
10. Level 10 — prestige/endgame.

For every progression route, prove that the real progression system unlocks it, the visible row becomes enabled, tapping it opens the correct destination, its data/actions come from authoritative systems, and Back returns logically.

## Gameplay/economy gate
Confirm the release-critical paths:
- inspect/acquire/restore/open business use real property and finance state;
- hiring affects payroll/capacity and assignments matter;
- procurement consumes real cash and creates only paid stock;
- production cannot run without required inputs/capacity;
- inventory never goes negative;
- sales and contract deliveries consume real goods;
- pricing/marketing/supplier choices have bounded real effects;
- bankruptcy/recovery surfaces only from real distress;
- acquisitions/mergers use AcquisitionSystem/corporation ownership logic rather than UI-only state;
- headquarters, world power, legacy, collections, victory and prestige read existing systems.

## Persistence/reliability gate
Repository-side evidence must protect:
- autosave and lifecycle interruption;
- properties/restoration;
- business state;
- employees;
- inventory/production/contracts;
- finance/debt;
- regions/branches/logistics;
- competitors/ownership/acquisitions;
- infrastructure/technology/headquarters;
- bankruptcy/recovery;
- history/collections;
- progression/prestige;
- real-time/passive timestamps without duplicate settlement.

Never silently replace a valid save with partially initialized state.

## Android and store gate
Repository-side requirements:
- Android and Play Store export presets exist;
- ARM64 release path is configured;
- min/target SDK are explicit;
- Play artifact is AAB;
- release signing is secret-driven, never committed;
- launcher/adaptive icons are configured;
- permissions match actually shipped SDKs;
- version code/name are explicit;
- privacy and terms assets exist and are wired in-game;
- production monetization remains disabled until real provider credentials/configuration exist.

Do not mark these external gates complete unless actually performed:
- release-signed AAB generation with the protected upload key;
- Play-generated install verification;
- restart save/load verification on physical devices;
- low/mid/high-end FPS, memory, thermals, battery, touch and scroll QA;
- final screenshots/feature graphic/store metadata;
- Play Console declarations and closed-testing/production-access steps;
- AdMob/UMP/Play Billing account configuration and license testing.

## Performance gate
Prioritize Android responsiveness:
- avoid full UI-tree rebuilds for small updates;
- do not poll expensive services every frame when signals/state changes suffice;
- keep transitions short;
- prevent hidden screens from processing;
- no progressive memory growth during normal play;
- target stable ≥30 FPS on supported low-end Android hardware, but only claim this after physical-device evidence.

## Test/CI rule
The repository owner's fast-path policy is mandatory and cannot be weakened:
- run only the smallest tests directly relevant to changed files/behavior;
- do not automatically run broad/full suites, exhaustive visual matrices, soak tests, unrelated browser/E2E, Android release builds, deployment validation, or duplicate CI;
- preserve Fast Policy Guard and path-scoped CI;
- stop when focused evidence proves the change.

For a navigation/progression change, the focused test should prove only:
1. authoritative level/unlock state;
2. enabled visible control;
3. correct destination;
4. correct Back path;
5. authoritative integration.

## Immediate execution order
1. Fix any known production navigation blocker first.
2. Verify critical Figma/native routes through the real progression system.
3. Correct stale release documentation without claiming external work.
4. Ensure privacy/terms and disabled-until-configured monetization accurately match the artifact.
5. Run only the directly relevant focused regression.
6. Merge only when the focused regression is green.
7. Leave device/signing/store/account tasks explicitly outstanding.

## Completion standard
Repository-side production readiness is complete only when known code-side blockers are fixed, the changed critical journey has focused passing regression evidence, release documentation matches reality, and no unrelated systems were churned.

A public Google Play release is not complete until signed AAB generation, Play-track testing, physical-device QA, store assets, and Play Console declarations are actually completed.
