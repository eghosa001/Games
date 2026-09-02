# RENEW V1 Implementation

This document translates the master design plan into the first playable software slice.

## Target loop

**Restore → Business → Revenue**

The player begins with limited money and a neglected property. The first implementation goal is to make the transformation from abandoned asset to operating business understandable, satisfying, and economically meaningful.

## Current code foundation

### Core
- `Assets/Scripts/Core/GameTypes.cs` — shared enums for property, industry, resources, restoration and company progression.
- `Assets/Scripts/Core/PlayerCompany.cs` — player cash, ownership and actions.
- `Assets/Scripts/Core/RenewGameBootstrap.cs` — creates the minimum runtime economy objects when they are absent.

### Restoration
- `Assets/Scripts/Restoration/RestorableProperty.cs` — staged restoration:
  `Neglected → Cleaned → Repaired → Rebuilt → Installed → Designed → Operational`.

### Economy
- `Assets/Scripts/Economy/Company.cs` — company state and ownership stakes.
- `Assets/Scripts/Economy/Market.cs` — resource supply/demand and dynamic pricing.
- `Assets/Scripts/Economy/Business.cs` — production inputs, operating costs and customer revenue.

## Next implementation milestones

1. Build the first Unity scene and restoration interaction UI.
2. Add visual state changes for each restoration stage.
3. Add the three V1 property types: warehouse, factory and retail outlet.
4. Add the three V1 industries and five resources.
5. Add customers, employees and suppliers.
6. Add contracts and competitor reactions.
7. Add three NPC corporations with distinct personalities.
8. Add one-region progression and basic alliances.
9. Add save/load.
10. Add analytics only after the core loop is fun without monetization.

## Design guardrails

- Economic competition is the primary conflict; avoid turning the game into a generic military strategy game.
- Major systems should create a meaningful decision, emotional attachment, or reason to return.
- The player's restoration choices must have visible consequences.
- Ownership should eventually support partial stakes, investors and controlling influence.
- V1 should stay small enough to become playable before the larger world systems are added.
