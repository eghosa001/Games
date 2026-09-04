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
- autosave protection for long mobile sessions and application pause/close
- responsive mobile touch controls with contextual feedback and milestones

### Run it

1. Install Godot 4.x.
2. Clone/download this repository.
3. Open the repository folder in Godot.
4. Press **F6/F5** to run the project.
5. Start with **I** to inspect, **A** to acquire, then **R** repeatedly to restore.

### Automated mobile QA

Run the mobile release-gate test from the repository root:

```text
godot --headless --path . --script res://tests/mobile_qa_test.gd
```

It checks the five target viewport sizes, 44×44 touch-target minimums, control containment, tab navigation, the touch signal path through the opening operating loop, WORLD tab availability, GameState save/restore timing, disk save/load timing, and a short FPS/memory stability sample. See `Docs/MOBILE_QA.md` for the physical-device checklist. Automated QA does **not** replace real Android testing.

### Core controls

- **I** — inspect the abandoned property
- **A** — acquire it
- **R** — restore the next stage
- **O** — open RENEW Goods after restoration
- **N** — close the operating day
- **P** — cycle selling price
- **S** — buy core inputs
- **B** — produce core goods
- **H** — hire a core employee
- **U** — upgrade core capacity
- **M** — launch marketing
- **K** — sign a customer contract
- **J / V** — take loan / repay loan
- **T** — cycle supplier tier
- **F5 / F9** — save / load

### Empire controls

- **7 / 8 / 9** — select Retail / Factory / Warehouse expansion slots
- **Z** — produce selected expansion business
- **Y** — sell selected expansion inventory
- **G** — hire at selected expansion business
- **, / .** — lower/raise expansion business price
- **0** — open/pause selected expansion business
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

### World and branch controls

- **F3 / F4** — cycle world regions
- **F6** — establish presence in the selected region
- **F7** — upgrade regional infrastructure
- **F8** — dispatch goods to the selected region
- **F10** — establish a regional trade route
- **CTRL+F6** — cycle regional branch
- **CTRL+F7** — launch selected branch
- **CTRL+F8** — stock selected branch
- **CTRL+F10** — hire branch staff
- **CTRL+F11** — upgrade branch
- **CTRL+F12** — raise branch price

The branch controls use **CTRL** deliberately so F6/F7/F8 remain dedicated to world-region actions and F9 remains dedicated to loading the game.

## Development roadmap

See `Docs/V1_IMPLEMENTATION.md` for the implementation plan and current milestone status.

## Design principle

The player should become emotionally attached to businesses because they personally transformed them from neglected assets into valuable operations. Economic competition—not combat—is the primary conflict. Rivals should react to the player's growth, making expansion feel like entering a living market rather than unlocking static menus.

## Production polish

The current build is undergoing the final mobile UI, presentation, balancing and release-readiness pass. Automated regression remains the release gate.
