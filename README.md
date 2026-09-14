# RESTORA: Business Empire

**Restore what others abandoned. Build businesses. Control resources. Challenge giants. Build an empire.**

RESTORA is an economic restoration and empire-building simulation game. Its defining progression is:

**Restore → Build → Grow → Compete → Control → Empire**

The active Godot 4.x game follows the deeper operating loop:

**Inspect → Acquire → Restore → Open → Operate → Earn → Reinvest → Expand → Control Supply → Defend Your Market**

The game includes staged property restoration, business operations, staffing, production, pricing, contracts, dynamic markets, suppliers, NPC corporations, alliances, rival reactions, loans, expansion businesses, resource sites, logistics, headquarters, districts, persistence, mobile controls, corporate wars, multiple victory paths, prestige/New Game+, world events, economic cycles, reputation, IPO listings, regional expansion and management dashboards.

## Brand

**RESTORA: Business Empire** is the player-facing title. The restoration theme remains the emotional foundation: players personally transform neglected assets into valuable businesses and eventually a global economic empire.

Tagline: **RESTORE • BUILD • GROW • COMPETE • EMPIRE**

Internal legacy `Renew*` service names and some source filenames are intentionally retained for save compatibility and low-risk migration. They are implementation details, not player-facing branding.

## Test suites

```text
godot --headless --path . --script res://tests/test_runner.gd
```

The full suite lives in `tests/` and runs in CI. The strict renderer-dependent release gate is documented in `tests/QUALITY_TEST_PROTOCOL.md`.

## Run it

1. Install Godot 4.x.
2. Clone/download this repository.
3. Open the repository folder in Godot.
4. Press **F6/F5** to run the project.
5. Start by inspecting an abandoned property, acquire it, restore it and build from there.

## Design principle

The player should become emotionally attached to businesses because they personally transformed them from neglected assets into valuable operations. Economic competition—not combat—is the primary conflict. Rivals react to the player's growth, making expansion feel like entering a living market rather than unlocking static menus.
