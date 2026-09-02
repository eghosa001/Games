# RENEW V1 Implementation

This document translates the master design plan into the first playable software slice.

## Target loop

**Restore → Business → Revenue → Supply Chain → Competition → Empire**

The player begins with limited money and a neglected property. The implementation now extends the transformation from abandoned asset to operating business into a small connected empire.

## Current playable foundation

### Restoration
- `scripts/main.gd` — staged restoration:
  `Neglected → Cleaned → Repaired → Rebuilt → Installed → Designed → Operational`.
- The first property must be inspected, acquired and restored before RENEW Goods can open.

### Core business
- `scripts/main.gd` — RENEW Goods staffing, production, pricing, marketing, customer contracts, financing and daily P&L.
- `scripts/production.gd` — production input requirements and output quality.

### Economy
- `scripts/economy.gd` — resource supply/demand, dynamic prices and supplier reliability.
- `scripts/competitors.gd` — three distinct NPC corporations, relationships, alliances and competition.
- `scripts/events.gd` — economic events that change cash/reputation and create operating pressure.

### Empire businesses
- `scripts/expansion.gd` — three separately playable businesses:
  - Riverside Retail Unit — Consumer Goods
  - Brickworks Yard — Building Materials
  - Cold Storage Depot — Food Processing
- Every expansion business has its own staff, inventory, quality, price, operating state and level.

### Supply chain and resource ownership
- Expansion businesses now require business-specific internal inputs before manual or automatic production.
- The player can acquire resource sites for **materials, food and fuel**.
- Resource sites generate internal stock, have disruption risk, can be upgraded, and require upkeep.
- `[D]` moves owned resource stock into compatible businesses.
- Retail can receive finished goods from the core RENEW Goods operation.
- Internal transfers add a small logistics cost, making network design a real trade-off.

### Headquarters management
- Empire scale now creates management overhead.
- Headquarters upgrades reduce the friction of coordinating a growing network and are persisted with the save.

### Save/load
- `scripts/save_system.gd` — JSON save/load.
- Expansion businesses, owned resource sites and headquarters management state are persisted.
- Older saves are normalized when loaded so newly introduced business fields receive safe defaults.

## Controls

### Core
- `I` inspect
- `A` acquire
- `R` restore
- `O` open business
- `S` buy core inputs
- `B` produce core goods
- `P` change core price
- `H` hire core employee
- `U` upgrade core capacity
- `M` marketing
- `N` end day
- `K` customer contract
- `J` loan
- `V` repay loan
- `T` supplier tier
- `F5` save / `F9` load

### Competition
- `1 / 2 / 3` select rival
- `L` improve relationship
- `C` alliance offer
- `X` acquire rival asset

### Empire
- `7 / 8 / 9` select Retail / Factory / Warehouse
- `Z` produce selected business
- `Y` sell selected business inventory
- `G` hire at selected business
- `, / .` lower/raise business price
- `0` open/pause selected business
- `4 / 5 / 6` select Materials / Food / Fuel site
- `W` generate resource stock
- `F` acquire resource site
- `[` upgrade resource site
- `D` dispatch internal supply
- `]` upgrade headquarters management

## Milestone status

1. First Unity scene/restoration interaction — legacy foundation exists; active playable path is Godot.
2. Visual restoration state changes — **complete in prototype UI**.
3. Three V1 property types — **complete**.
4. Three industries and core resources — **complete**.
5. Customers, employees and suppliers — **complete**.
6. Contracts and competitor reactions — **complete**.
7. Three NPC corporations — **complete**.
8. Basic alliances and progression — **complete**.
9. Save/load — **complete**.
10. Individually playable empire businesses — **complete**.
11. Internal supply chains and resource ownership — **complete**.
12. Headquarters management overhead — **complete**.

## Next bottlenecks

The remaining work is no longer a simple missing mechanic. The project needs either:

1. **A real Godot runtime validation pass** to catch engine/version-specific GDScript or input-constant issues and tune the UI after playing the loop; or
2. A larger world layer: districts, transport/logistics capacity, richer competitor AI, partial ownership/investors, narrative events and multi-region progression.

Those are deliberately held until the current prototype can be run and observed, because further systems without runtime feedback risk creating feature complexity without improving the actual game.

## Design guardrails

- Economic competition is the primary conflict; avoid turning the game into a generic military strategy game.
- Major systems should create a meaningful decision, emotional attachment, or reason to return.
- The player's restoration choices must have visible consequences.
- Ownership should eventually support partial stakes, investors and controlling influence.
- V1 should stay small enough to become playable before the larger world systems are added.
