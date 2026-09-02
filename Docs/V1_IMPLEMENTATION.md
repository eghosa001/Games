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
- [x] Rival retaliation and competitive status feedback are implemented.
- [x] Rotating region-specific opportunities are implemented.

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
Regional demand, logistics, competition, resource specialization, infrastructure and trade corridors determine where expansion is attractive and where it is risky. Rotating regional opportunities add reasons to revisit established markets.

### 7. Corporate control
Capital raises exchange ownership for growth capital. Buybacks restore founder control. Board influence and defense reduce takeover vulnerability. Strategic allies can defend the company. Once the player has enough profit, reputation and acquisitions, hostile takeover becomes an endgame path.

## Player-facing completion pass

- [x] First-business milestone is visibly celebrated.
- [x] First profit and expansion milestones are visibly celebrated.
- [x] Competitor acquisition and hostile-takeover victories receive major celebration feedback.
- [x] Daily operating results show revenue, profit/loss, cumulative profit and contract status.
- [x] A contextual next-goal prompt is always visible on the mobile HUD.
- [x] Celebration feedback uses lightweight Godot tweens rather than blocking gameplay.
- [x] Very small-screen responsive layout remains part of the mobile HUD.
- [x] The celebration layer observes state only and does not mutate the simulation.

## Automated verification

The Godot workflow runs regression, extended-function and edge-case suites. The latest celebration-overlay integration completed successfully, including project import and all three test stages.

## Final V1 acceptance run

1. RESTORE: choose Budget/Standard/Premium → Inspect → Acquire → restore all stages → Open Business.
2. BUSINESS: Buy Inputs → Produce → Hire/Upgrade/Marketing/Price → End Day repeatedly.
3. MARKET: continue until an event appears → choose an aggressive/balanced/defensive response → observe changed input economics.
4. EMPIRE: acquire and upgrade an expansion asset.
5. SUPPLY: acquire a resource site → generate/move resource → supply an expansion asset.
6. RIVALS: improve relationship → attempt alliance → use an appropriate deal → acquire an asset when ready.
7. WORLD: change region → establish → infrastructure → trade corridor → dispatch goods.
8. CORPORATE: raise capital → influence board/defense → buyback or dividend → use alliance defense.
9. SAVE/LOAD: save, change systems, load, and verify coherent state.
10. Play a long touch-only session and check Godot output for new parse/runtime errors.

## Remaining production work beyond V1

V1 gameplay systems and player-facing feedback are now complete enough for a full manual acceptance playthrough. Remaining work should be treated as production polish rather than foundational V1 implementation:

- final economy tuning from real play sessions
- authored visual assets and richer environment presentation
- final sound/music package
- additional content packs and more businesses/resources
- performance profiling on a range of Android devices
- release packaging, store metadata and monetization decisions
