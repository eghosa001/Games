# RENEW Strict QA Protocol

The repository has many focused Godot tests, but passing feature tests alone does not prove the game is release-ready. The canonical quality gate is `tests/test_quality_gate.gd`.

## Mandatory gates

1. **Project boot** — configured main scene, autoloads and renderer must be valid.
2. **Scene composition** — Main must instantiate with World, Systems and UI roots plus the required gameplay controllers.
3. **World presentation** — the playable world must contain real visible artwork, scenery and district composition. Assets merely existing on disk are not enough.
4. **Responsive UI** — desktop and small mobile viewports must stay contained; primary touch controls must meet the 44px minimum.
5. **Gameplay path** — inspect → acquire → restore all stages → operate business → hire → produce → advance day must work through the real command boundary.
6. **Persistence** — authoritative state must capture and restore.
7. **Rendered-frame checkpoint** — the actual Godot viewport must render substantial, visually varied content and a PNG checkpoint is produced.
8. **Runtime stability** — the running scene must sustain at least 30 FPS in the automated sample and remain alive.

## No-loophole rules

- A test failure must exit with code 1 or the test is not a valid gate.
- A warning cannot substitute for a required assertion.
- Asset existence does not count as visual availability; required final assets must be visible and textured in the playable scene.
- UI existence does not count as usability; layout and touch-size constraints must be measured.
- A command existing does not count as gameplay; the strict gate executes the core progression.
- A screenshot existing does not count as quality; the gate checks that the rendered frame is non-empty and has meaningful pixel variation, while the saved image remains available for visual inspection.
- Subjective visual quality still requires human review. Automated rendering tests are a floor, not an artistic substitute.

## Screenshot checkpoints

The strict Godot gate writes `user://quality_gate/quality_gate_main.png`. CI uploads the quality-gate directory as an artifact so a failed run can be visually inspected rather than inferred from logs alone.

The separate browser QA workflow remains responsible for testing the deployed web build with real browser interaction and diagnostics.

## Release rule

**Release = all mandatory automated gates pass + no known P0/P1 defects + human visual review passes the 90/100 Game Quality Acceptance Standard.**
