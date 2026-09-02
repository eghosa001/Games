# RENEW V1 Implementation

## Vision

**Nobody → abandoned property → first business → profit → resources → rivals → alliances → expansion → empire → corporate control → challenge the giants.**

RENEW is an economic strategy game about rebuilding neglected assets and gradually gaining enough productive capacity, relationships and ownership to compete with powerful companies.

## Stabilization pass completed

- [x] Mobile actions return clear per-click feedback and refresh after the action completes.
- [x] Mobile players can cycle rivals and expansion assets without keyboard controls.
- [x] Mobile players can move resource stock into the supply network and supply selected expansion businesses.
- [x] Expansion properties expose the fields required by the supply-chain and corporate layers (`cost`, `active`, `inputs`, `input_need`).
- [x] Expansion exposes the compatibility API used by the main game (`buy`, `upgrade`, `selected`, `unlock_from_reputation`).
- [x] Expansion management state required by save/load is present.
- [x] Owned resource sites generate stock and supply transfers consume that stock.
- [x] Corporate valuation can safely value expansion properties and resource sites.
- [x] Rival companies expand, adjust pricing/supplier pressure, negotiate alliances and strategic deals, and create acquisition pressure.
- [x] Supply contracts, resource rights and regional logistics are exposed through the mobile strategy layer.

## Gameplay architecture

### 1. Restoration
The player begins with an abandoned warehouse. Inspection reduces uncertainty, acquisition creates the first owned asset, and restoration converts neglected space into productive capital.

### 2. Business
RENEW Goods turns restoration into an operating company. Inputs, production, staffing, capacity, marketing, pricing, customer contracts and daily cash flow create the first economic feedback loop.

### 3. Rivals
- **The Giant:** capital-heavy and aggressive; pressures prices and can target the player's control.
- **The Specialist:** quality-focused; can become a customer/quality partner.
- **The Network:** supplier/logistics-focused; can create input pressure or become a supply partner.

Rivals change over time instead of remaining static opponents.

### 4. Alliances and deals
Relationship is a strategic resource. Improving trust can unlock alliances and specialized deals. Alliances provide concrete discounts, demand bonuses, supplier relief and defensive support.

### 5. Supply chain
Owned resource sites generate physical stock. Stock can be moved into the company network and allocated to owned expansion businesses. External market purchases remain available when internal supply is insufficient.

### 6. Regions
Regional demand, logistics, competition, resource specialization, infrastructure and trade corridors determine where expansion is attractive and where it is risky.

### 7. Corporate control
Capital raises exchange ownership for growth capital. Buybacks restore founder control. Board influence and defense reduce takeover vulnerability. Strategic allies can defend the company. Once the player has enough profit, reputation and acquisitions, hostile takeover becomes an endgame path.

## Full regression test — do this after pulling the latest `main`

Do **one connected run**, not isolated button tests:

1. RESTORE: choose Budget/Standard/Premium → Inspect → Acquire → restore all stages → Open Business.
2. BUSINESS: Buy Inputs → Produce → Hire/Upgrade/Marketing/Price → End Day repeatedly.
3. MARKET: continue until an event appears → choose an aggressive/balanced/defensive response → continue and observe the changed input economics.
4. EMPIRE: cycle to an expansion → acquire it → upgrade it.
5. SUPPLY: acquire a resource site → generate/move resource → supply the selected expansion asset.
6. RIVALS: cycle rival → improve relationship → attempt an alliance → try the appropriate supply/customer deal.
7. WORLD: change district/region → establish → infrastructure → trade corridor → dispatch goods.
8. CORPORATE: raise capital → board influence/defense → buyback or dividend → use alliance defense when an alliance exists.
9. SAVE/LOAD: save, change several systems, load, and verify the company returns coherently.
10. End with a long touch-only session and watch Godot output for **new** parse/runtime errors.

### Known harmless Android warning
`Image format RGBAFloat not supported by hardware, converting to RGBAHalf` is a graphics compatibility conversion warning. It is not a GDScript parse error.

## Remaining V1 polish

- Better visual feedback for major corporate victories/defeats.
- More distinct region-specific opportunities.
- More rival retaliation after acquisitions.
- Broader resource network and production chains.
- Responsive HUD layout for very small screens.
- Audio, animation, milestone celebrations and final economy balancing.
