# RENEW — Production Readiness

## Completed in this pass

- Polished mobile control surface with consistent touch targets and visual button states.
- Responsive geometry without the previous anchored-control size conflicts.
- Clear brand/header treatment and stronger action hierarchy.
- Existing world presentation retained: restoration progress, business health, regions and supply network remain visible.
- Existing goals, milestone celebrations and day-result reporting retained.
- Release smoke test now verifies the polished mobile UI is actually wired into `Main.tscn`.

## Human QA before store release

1. Test 320, 360, 480, 720 and tablet widths.
2. Play the first 10–15 minutes without keyboard input.
3. Confirm every restore → operate → earn → expand decision is understandable.
4. Profile memory and frame time on low-end Android hardware.
5. Tune prices, margins, supplier pressure and expansion pacing from real play sessions.
6. Add authored art, sound and music without changing simulation contracts.
7. Package Android builds and complete store metadata.

The simulation architecture is already regression-gated; the remaining release work is human device QA, content production and economy tuning rather than a foundational rewrite.
