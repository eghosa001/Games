# RENEW

**Start with nothing. Restore what others abandoned. Build businesses. Make allies. Control resources. Challenge giants. Build an empire.**

RENEW is an economic restoration and empire-building simulation game. The defining loop is:

**Restoration → Business → Economy → Competition → Alliances → Empire**

## Current status — PLAYABLE GODOT PROTOTYPE

The active game is a Godot 4.x prototype demonstrating the restoration-to-empire loop:

**Inspect → Acquire → Restore → Open → Operate → Earn → Reinvest → Expand → Control Supply → Defend Your Market**

Implemented systems now include:
- staged visual restoration of the first abandoned warehouse
- RENEW Goods production, staffing, pricing, marketing and customer contracts
- dynamic resource prices and supplier reliability choices
- three NPC corporations with relationships, alliances and reactive competitive behavior
- rivals expanding into districts and increasing local competitive pressure
- price wars, supplier wars, specialist customer pressure and acquisition approaches
- loans, repayments, events and competitor reactions
- three individually playable expansion businesses
- business-level inventory, quality, staffing, pricing and open/paused operations
- internal logistics between owned resource sites and businesses
- owned materials, food and fuel resource sites with production, risk and upgrades
- headquarters management overhead and upgrades
- district-based demand, logistics and competition modifiers
- save/load persistence for the expanded empire state

### Run it

1. Install Godot 4.x.
2. Clone/download this repository.
3. Open the repository folder in Godot.
4. Press **F6/F5** to run the project.
5. Start with **I** to inspect, **A** to acquire, then **R** repeatedly to restore.

### Empire controls

- **7 / 8 / 9** — select Retail / Factory / Warehouse
- **Z** — produce selected business
- **Y** — sell selected business inventory
- **G** — hire at selected business
- **, / .** — lower/raise business price
- **0** — open/pause selected business
- **4 / 5 / 6** — select Materials / Food / Fuel resource site
- **W** — generate resource stock
- **F** — acquire selected resource site
- **[** — upgrade selected resource site
- **D** — move internal resources into the selected business
- **]** — upgrade headquarters management
- **TAB** — cycle through unlocked districts
- **BACKSPACE** — upgrade transport fleet
- **1 / 2 / 3** — select a rival
- **L** — improve relationship with selected rival
- **C** — propose alliance
- **X** — acquire a rival asset when unlocked
- **F5 / F9** — save / load

## Development roadmap

See `Docs/V1_IMPLEMENTATION.md` for the implementation plan and current milestone status.

## Design principle

The player should become emotionally attached to businesses because they personally transformed them from neglected assets into valuable operations. Economic competition—not combat—is the primary conflict. Rivals should react to the player's growth, making expansion feel like entering a living market rather than unlocking static menus.
