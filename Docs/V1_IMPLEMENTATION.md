# RENEW V1 Implementation

This document translates the master design plan into the first playable software slice.

## Target loop

**Restore → Business → Revenue → Supply Chain → Competition → Ownership → Empire**

The player begins with limited money and a neglected property. The implementation now extends the transformation from abandoned asset to operating business into a connected economic empire where ownership itself becomes a strategic resource.

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
- `scripts/competitors.gd` — three distinct NPC corporations, relationships, alliances, deals, expansion pressure and acquisitions.
- `scripts/events.gd` — economic events that change cash/reputation and create operating pressure.

### Empire businesses
- `scripts/expansion.gd` — three separately playable businesses:
  - Riverside Retail Unit — Consumer Goods
  - Brickworks Yard — Building Materials
  - Cold Storage Depot — Food Processing
- Every expansion business has its own staff, inventory, quality, price, operating state and level.

### Supply chain and resource ownership
- Expansion businesses require business-specific internal inputs before manual or automatic production.
- The player can acquire resource sites for materials, food and fuel.
- Resource sites generate internal stock, have disruption risk, can be upgraded, and require upkeep.
- Internal transfers add logistics cost, making network design a real trade-off.

### Headquarters and logistics
- Empire scale creates management overhead.
- Headquarters upgrades reduce coordination friction.
- Transport upgrades expand fleet capacity for the growing network.
- Districts provide different demand, logistics and competition profiles.

### Corporate ownership and capital
- `scripts/corporate.gd` adds a persistent corporate-control layer.
- Company valuation and indicative share price respond to cash, profit, reputation, businesses and acquisitions.
- The founder begins with 100% ownership.
- Growth capital can be raised from an independent investor in exchange for minority equity.
- Investors improve access to capital but reduce founder ownership and increase the importance of board trust.
- Profits can later be used for share buybacks or dividends, creating a growth-versus-control decision.
- Corporate defense can be upgraded to reduce takeover risk.
- A strong alliance can be called upon for emergency takeover defense.
- The Giant can attempt a takeover when the player's ownership/control position becomes vulnerable.
- Corporate state is persisted locally so ownership survives between sessions even though the normal economic save system remains separate.

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

### Corporate control
- `ENTER` raise capital from investors
- `-` buy back investor shares
- `=` pay shareholder dividend
- `;` strengthen takeover defense
- `'` call a strategic alliance for takeover defense

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
13. Districts, transport and regional competition — **complete**.
14. Corporate ownership, investment and takeover defense — **complete in prototype**.

## Next bottlenecks

The largest remaining risk is runtime validation. Godot is not currently available in the development environment, so the new corporate layer has been integrated through the repository but has not been executed here. Once Godot is available, the first pass should verify input constants, scene loading, draw ordering and persistence behavior, then tune balance after actually playing the loop.

After validation, the next major content layer should focus on narrative-driven corporate events and multi-region progression rather than adding disconnected mechanics.

## Design guardrails

- Economic competition is the primary conflict; avoid turning the game into a generic military strategy game.
- Major systems should create a meaningful decision, emotional attachment, or reason to return.
- The player's restoration choices must have visible consequences.
- Ownership is now a strategic resource: raising money can accelerate expansion while surrendering control.
- The Giant should be powerful but beatable through stronger economics, alliances, reputation and corporate defenses.
- Failure should create stories and consequences rather than simply ending the game.
- V1 should stay playable before adding a much larger world.
