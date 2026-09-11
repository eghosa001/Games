# RENEW UI/UX Release Gate

A UI review is not complete because scripts parse or screens open. A release candidate must pass all layers below. Every bug found in manual review should become a regression assertion in one of these gates before it is considered fixed.

## 1. Structural integrity

- Main scene loads and instantiates.
- Every managed screen resolves exactly once.
- Exactly one managed modal screen may be visible at a time.
- Every screen has a deterministic open/close contract.
- Hidden descendants stay hidden when a screen opens.
- Closing one screen cannot recursively close the next screen being opened.
- All required services resolve through their canonical autoload/service-registry path.

## 2. Viewport matrix

Every managed screen and every persistent HUD command page is checked at:

- 320x568
- 360x640
- 390x844
- 412x915
- 768x1024
- 1280x720
- 1920x1080

Release blockers include interactive controls outside the viewport, overlapping buttons, zero-sized controls, inaccessible close controls, or persistent HUD/action docks outside the visible frame.

## 3. Interaction contract

- Every visible enabled button has a pressed callback.
- Primary touch targets are at least 44x44 px.
- Close controls accept real mouse and touch input at their rendered coordinates.
- ESC/back closes the active modal.
- Legacy navigation aliases still resolve.
- Screen A -> B -> C switching leaves one active screen and no stale modal state.
- Repeated open/close/switch cycles must remain stable.

## 4. Scroll and density contract

- Scroll content may extend beyond the viewport only when contained by a working ScrollContainer.
- Non-scroll interactive controls must remain almost completely inside the viewport.
- Dense phone layouts must not stack controls below the panel bottom.
- Lists must remain reachable when populated beyond one screen.
- No action row may overlap detail, status, or scroll regions.

## 5. Persistent HUD navigation

All command pages in LIVE, BUSINESS, EMPIRE and WORLD must generate usable actions. The release gate covers all 28 command pages without executing state-changing commands. Each page must contain at least one action, maintain the action-density limit, and create wired touch-sized controls.

## 6. Rendered visual evidence

CI renders every managed screen under Xvfb at 390x844 and 1280x720. Each frame must:

- produce a non-empty render texture;
- contain substantial visible content;
- contain meaningful pixel variation;
- save a PNG evidence frame under `artifacts/ui-matrix/`.

The CI artifact should be manually spot-reviewed before a release build. Automated pixel checks catch blank/failed rendering but do not replace human visual judgement.

## 7. UX/state review

For important screens, manually verify at least these states when applicable:

- empty/new-game state;
- normal populated state;
- large-list state;
- locked/unlocked state;
- insufficient cash/resources;
- service unavailable/error state;
- selected/unselected state;
- success/failure feedback;
- maximum or unusually large numeric/text values.

The action result must be visible immediately and understandable without opening another screen solely to discover whether it succeeded.

## 8. Regression policy

When a UI bug is discovered:

1. Reproduce it.
2. Add or strengthen a test that fails for the bug class, not only the exact screen.
3. Fix the implementation.
4. Run the complete UI matrix and visual matrix.
5. Keep the regression assertion permanently.

Do not weaken a gate merely to make CI green unless the assertion is proven to be a false positive and is replaced with a more accurate check.

## Required automated gates

- `tests/test_ui_architecture.gd`
- `tests/test_ui_scene_contract.gd`
- `tests/test_responsive_ui_shell.gd`
- `tests/test_exhaustive_ui_matrix.gd`
- `tests/test_visual_ui_matrix.gd`
- `tests/test_quality_gate.gd`

A release is UI/UX-ready only when the complete Godot workflow passes and the rendered UI matrix evidence has been reviewed.