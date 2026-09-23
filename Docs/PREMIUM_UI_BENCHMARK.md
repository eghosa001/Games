# RESTORA Premium UI Benchmark

This document defines the production UI target for RESTORA. The goal is not to copy another game's artwork; it is to match the clarity, hierarchy, responsiveness, tactile feedback, and authored visual identity expected from premium commercial management games.

## Reference standard

- **Anno 1800** — dense economic information is grouped around player intent, while ornamentation stays restrained enough that the city remains the focus. RESTORA should use this as the benchmark for management information hierarchy and contextual panels.
- **Frostpunk 2** — strong visual language, recognizable system states, goal-oriented navigation, and clear separation between decision surfaces and world context. RESTORA should use this as the benchmark for decision priority, modal hierarchy, and strategic atmosphere.
- **Clash Royale / premium mobile strategy UX** — large reliable touch targets, unmistakable primary actions, immediate interaction feedback, short navigation paths, and layouts that remain legible at phone widths.
- **Mini Metro / premium minimalist strategy UX** — only persistent information that earns its screen space; detail appears contextually instead of permanently competing for attention.

## Production rules

1. Every screen has one obvious primary purpose and one dominant action hierarchy.
2. Persistent HUD content is limited to information required for the current decision layer.
3. Secondary information uses progressive disclosure: drawers, focused screens, tooltips, detail panels, or contextual overlays.
4. No screen may visually resemble stock Godot controls. Buttons, panels, tabs, inputs, progress indicators, lists, scrollbars, toggles, popups, and focus states use RESTORA's authored visual system.
5. Surface depth is intentional: world/background, navigation chrome, content surface, raised card, selected/critical state.
6. Semantic color is stable across the game. Gold = primary/valuable decision, teal = positive/operational, cyan = world/information, orange = production/attention, red = danger/negative, purple = empire/network.
7. Typography uses a clear hierarchy: brand/hero, screen title, section title, metric value, body, caption. All-caps is reserved for short navigation/status labels, not paragraphs.
8. Hover, pressed, selected, disabled, focus, loading, success, failure, locked, and empty states must all be designed states rather than engine defaults.
9. Desktop and mobile are different compositions, not merely scaled copies. Phone layouts favor bottom-reachable primary navigation, fewer simultaneous controls, and 48 px or larger touch targets.
10. Motion is brief and informative. Entry/selection feedback should communicate hierarchy without blocking play.
11. Raw debug terminology, internal node names, implementation labels, placeholder copy, and development-only controls must never be player-facing in production.
12. The world remains visually present behind management layers whenever doing so does not reduce readability.

## Release acceptance

A visual pass is not complete merely because controls are themed. A release candidate must also pass the repository UI viewport matrix, interaction contracts, overflow checks, empty/error/locked states, and human review of rendered frames. The final question is: **does each screen look authored for RESTORA, or merely functional?** If the answer is merely functional, it is not release-ready.
