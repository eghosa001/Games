# RENEW — Production Readiness

## Automated release standard

RENEW now has one canonical automated release decision: `.github/workflows/renew-release-gate.yml`.

A commit on `main` is **automation-ready for the continuously deployed web release** only when all of the following succeed for the same commit SHA:

1. **RENEW Godot Tests** — core regression tests, master game-plan coverage, mobile QA and the rendered visual-quality gate. The normal per-commit workflow deliberately skips the long soak, extreme soak, exhaustive UI matrix, visual UI matrix and other long-running suites.
2. **Godot Web Export** — import, release validation, clean Web export and deployment checks.
3. **Live Browser QA** — the post-Web-export browser run against the deployed GitHub Pages build, including desktop/opening-loop/mobile screenshots, runtime-error detection and pixel-region assertions.

**RENEW Android Export is intentionally on-demand.** It is required for an Android/store release candidate, but it is not part of the always-on main-branch web gate. This keeps routine CI fast while preventing the automatic gate from waiting for an Android push run that does not exist.

The release gate deliberately requires the **post-deployment** Live Browser QA (`workflow_run`), not only the earlier push-triggered browser check. This prevents a stale Pages build from being accepted as evidence for a new commit.

Documentation, file presence and unchecked roadmap boxes are not release evidence by themselves. The matching CI result is authoritative for automated readiness.

## Test-backed readiness map

| Release concern | Primary evidence |
|---|---|
| Core restoration → operation loop | `tests/test_master_game_plan_coverage.gd`, `tests/test_new_game_flow.gd`, `tests/release/test_release_smoke.gd` |
| Architecture/service integration | `tests/test_architecture_integrity.gd`, `tests/test_production_readiness_integration.gd` |
| Persistence/save-load durability | fast regression and save-edge tests; long-soak tests are additional deep-validation evidence |
| Economy/balance over time | `tests/long_running/test_30_60_180_365_day_balance.gd` is a deep-validation suite, not part of the normal per-commit gate |
| Long-session stability | `tests/test_long_soak.gd` and `tests/test_extreme_soak.gd` are deep-validation suites, not part of the normal per-commit gate |
| Mobile layout/touch behavior | `tests/mobile_qa_test.gd`, rendered UI matrix and Live Browser QA 390×844 capture |
| Visual presentation | `tests/test_quality_gate.gd`, `tests/test_visual_ui_matrix.gd`, `scripts/visual_assertions.py` |
| Web release | `.github/workflows/web-export.yml` + post-deployment Live Browser QA |
| Android release | on-demand `.github/workflows/android-export.yml` for the exact store-candidate SHA |

## Completed production-polish work

- Polished mobile control surface with consistent touch targets and visual button states.
- Responsive geometry without the previous anchored-control size conflicts.
- Clear brand/header treatment and stronger action hierarchy.
- Existing world presentation retained: restoration progress, business health, regions and supply network remain visible.
- Existing goals, milestone celebrations and day-result reporting retained.
- Release smoke test verifies the polished mobile UI is wired into `Main.tscn`.
- Long-running 30/60/180/365-day balance validation remains available as a deep-validation suite; it is intentionally not run on every commit.
- The automatic release gate aggregates the always-on Godot, Web and deployed-browser results; Android export remains an explicit store-candidate gate.

## Human QA still required before store release

Automated readiness does **not** mean store-ready by itself. Before a public Android/store release:

1. Test 320, 360, 480, 720 and tablet widths on physical devices where possible.
2. Play the first 10–15 minutes without keyboard input.
3. Confirm every restore → operate → earn → expand decision is understandable without developer knowledge.
4. Profile memory, frame time, thermals and battery behavior on low-end Android hardware.
5. Run real play sessions to tune prices, margins, supplier pressure, loan pressure and expansion pacing; automated balance tests protect ranges but cannot prove fun.
6. Verify pause/resume, backgrounding, autosave, force-close recovery and storage behavior on Android.
7. Add/finalize authored art, sound and music without breaking simulation contracts.
8. Package signed release builds and complete store metadata, privacy disclosures and screenshots.

## Release rule

The simulation architecture is regression-gated, but a public release candidate is accepted only when:

- **RENEW Release Gate is green for the exact candidate SHA** for the continuously deployed web build,
- **RENEW Android Export is green for the exact candidate SHA** before any Android/store release,
- the deep validation appropriate to the release has been run (including long-session/balance suites for major releases), and
- the physical-device/human QA checklist for that candidate has been completed.

If any condition is missing, the build is not a release candidate yet.
