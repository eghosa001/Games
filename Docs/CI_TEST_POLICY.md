# RESTORA CI Test Policy

RESTORA uses **targeted CI during active development** and reserves the exhaustive suite for release-quality gates.

## Iterative changes

Normal pull-request updates run only:

1. Tests directly changed in the commit/PR.
2. Tests mapped to the changed subsystem by `ci/select_relevant_tests.py`.
3. A small architecture/release smoke set when runtime code changes.

Examples:

- UI/theme/art changes -> UI, responsive, containment and presentation tests.
- 3D/world changes -> property/district/world 3D tests plus performance coverage.
- Finance/economy changes -> finance/economy transaction tests.
- Production changes -> production tests.
- Employee changes -> employee/culture tests.
- Supply changes -> supply/scarcity tests.
- Save/state changes -> save, migration and state tests.

The exhaustive UI matrices, master game-plan gate, full visual-quality gate and soak tests do **not** run on every edit.

## Full validation

The full suite runs only when:

- code lands on `main`;
- a pull request is marked **Ready for review** (the intended final pre-merge gate); or
- a manual workflow run selects `validation_mode=full`.

This keeps normal iteration fast while preserving a full production gate before/after merge.

## Maintenance rule

When adding a new subsystem or test family, update `ci/select_relevant_tests.py` so future changes to that subsystem automatically select the right tests instead of falling back to the entire suite.
