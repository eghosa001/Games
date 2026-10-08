# RESTORA Quality Scorecard — 8 October 2026

**Scope:** `eghosa001/Games`, RESTORA only. **Reference:** screenshots and CI for main `3bcc0378`, plus current focused code review. **Not** a certification of a future build. Scores are judgement-based estimates, not machine measurements. **Do not award a 9+/10 simply because CI passes.**

## Baseline, before the current tablet/legibility correction

| Surface | Provisional /10 | Evidence and reason |
|---|---:|---|
| Mobile navigation | 7.5 | Five real tab buttons and working scroll; some small captions and focus/locked states remain visually weak |
| Tablet navigation | 3.0 | Five visible navigation labels are static and have no tap handlers in `_build_tablet_live` |
| Desktop navigation | 7.0 | Property card and four quick-action routes are wired, but control labels are just 9px |
| New-player instructions | 6.0 | Home next-step is grounded in simulation; the mobile description is truncated beside staged art |
| Mobile screen readability | 5.5 | Icons visually overrun 22px metric slots; secondary text is often 9–10px |
| Desktop readability | 6.5 | Main objective and values are readable, but small captions and dense button labels hold it back |
| Responsive viewport handling | 5.5 | Existing desktop/tablet canvas is not recomputed during same-layout-class resize |
| Property artwork fidelity | 7.0 | Stage-specific artwork now comes from the correct warehouse/factory/office family; detail screens still used unrelated promotional Calder art |
| Art direction / material coherence | 6.5 | Warm palette is consistent, but still relatively flat for the premium benchmark |
| Screen density / hierarchy | 6.5 | Home is well structured; desktop left portfolio and objective cards contain substantial unused space |
| Theme implementation | 7.0 | Light, dark, and system semantics exist; all detail states and contrast variants have not been rendered-review certified |
| Tutorial usability | 7.0 | Fresh desktop tutorial no longer occludes stats, and in-game guidance is navigable |
| Gameplay-to-UI state consistency | 8.0 | Focused state-change checks prove live restoration percentages and sprite-frame updates |
| Economy / transaction integrity | **Not fully scored** | Authoritative finance system and focused regression checks exist; full economic balancing and real-user trials are not evidence here |
| Long-term progression / fun | **Not yet scored** | Levels and systems exist in code, but end-to-end player retention and progression pacing are unverified |
| Save / resume / corruption recovery | **Not yet scored** | Repository tests exist, but on-device force-close and recovery checks are outstanding |
| Scrolling / animation / navigation latency | **Not yet scored** | No per-device frame-time/input-latency measurements were collected in this review |
| FPS / memory / battery / thermals | **Not yet scored** | No low/mid/high-end physical Android telemetry collected |
| Audio / haptics | **Not yet scored** | No device listening/haptics review performed |
| Ad/consent/billing integration | **Not yet scored** | No actual account/provider validation or purchase flow evidence; production integration must stay disabled until configured |
| Web build pipeline | 8.0 | Same-SHA Godot/Web/Live Browser QA gate passed on main `3bcc0378`; it does not substitute for human visual review |
| Android debug packaging | 7.5 | Debug export and checksum passed; Play-signed AAB, device installation, store declarations and physical testing are not complete |

**Interpretation:** 9+ is still **unproven** in every category. The visual scores are based on three real browser captures (desktop startup, opening loop and phone startup), code review, and narrowly relevant CI results. They are not based on exhaustive screen-by-screen phone and tablet recordings. Ratings must be reassessed from the new render, not raised automatically after changes.

## Priority fixes in progress

1. **P0 — Tablet navigation:** render genuinely tappable HOME, BUSINESS, PROPERTY, FINANCE, and MORE; obey Finance's authoritative unlock, size touch targets >=48 actual pixels, and verify Back.
2. **P1 — Visual overflow:** constrain HUD icons to their actual slots; rewrap Home description after splitting the hero around a property sprite; ensure detail screen art follows selected property type and stage.
3. **P1 — Responsive geometry:** refit desktop/tablet canvas in-place when window dimensions change without crossing breakpoints.
4. **P1 — Type readability:** increase desktop quick-action font without adding visual clutter.

## Next evidence required for true 9+/10

- Capture every core destination and representative detail screen in light/dark on 320×568, 390×844, tablet portrait and desktop, with real tap/Back/scroll input.
- Manually inspect long names, unusual money values, empty/locked/error dialogs and accessibility text scaling.
- Perform 10–15 minutes of actual new-user gameplay for clarity and pacing; track confusion and mis-taps.
- Record FPS/frame time, memory/thermal/battery, launch and navigation latency on real low/mid/high-end Android devices.
- Verify on-device lifecycle, persisted saves, ads/consent/purchases only if the corresponding providers are enabled, and the final Play-signed release.

The repository's **fast-path CI rule remains authoritative**: do not automatically run wide visual, soak, packaging or full test matrices because a scorecard mentions them. Execute broad device/release validation explicitly when the release candidate is selected.
