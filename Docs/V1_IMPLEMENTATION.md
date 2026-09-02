# RENEW V1 Implementation Plan

This document is the executable roadmap for turning the RENEW concept into a playable Unity prototype.

## Product goal

Build a satisfying business-restoration game where the player starts small, makes difficult financial choices, restores a neglected property, opens a business, earns revenue, and begins competing with larger companies.

The first milestone is **not** a huge map or a complete economy. It is a fun, repeatable vertical slice.

## Core loop

**Discover → Inspect → Acquire → Restore → Open → Operate → Earn → Reinvest → Expand**

Every step should create a meaningful choice.

## Current foundation

- `Assets/Scripts/Core/GameTypes.cs` — shared enums for property, industry, resources, restoration and company progression.
- `Assets/Scripts/Core/PlayerCompany.cs` — player cash, ownership and actions.
- `Assets/Scripts/Core/RenewGameBootstrap.cs` — creates the minimum runtime economy objects when they are absent.
- `Assets/Scripts/Restoration/RestorableProperty.cs` — staged restoration from neglected to operational.
- `Assets/Scripts/Economy/Company.cs` — company state and ownership stakes.
- `Assets/Scripts/Economy/Market.cs` — resource supply/demand and dynamic pricing.
- `Assets/Scripts/Economy/Business.cs` — production inputs, operating costs and customer revenue.

## Milestone 0 — Make the project open and playable

**Goal:** A clean Unity project with one working scene.

- [ ] Confirm Unity version and project settings.
- [ ] Create the main scene.
- [ ] Add a simple camera and world area.
- [ ] Add the player company bootstrap.
- [ ] Add a basic HUD showing cash, reputation and current day.
- [ ] Add a simple game clock/day progression.
- [ ] Confirm the project builds without errors.

**Done when:** pressing Play produces a stable scene with visible player status.

## Milestone 1 — First restoration experience

**Goal:** Make restoring a property feel like the central fantasy.

- [ ] Place one abandoned property in the scene.
- [ ] Allow the player to inspect it.
- [ ] Show purchase/lease cost, condition, estimated renovation cost and potential value.
- [ ] Add restoration stages:
  `Neglected → Cleaned → Repaired → Rebuilt → Installed → Designed → Operational`.
- [ ] Give each stage a cost and time requirement.
- [ ] Add a progress indicator.
- [ ] Change the property's visual appearance after each major stage.
- [ ] Prevent actions when the player cannot afford them.
- [ ] Show a clear result after every restoration action.

**Done when:** the player can take one ugly property and visibly transform it into a usable asset.

## Milestone 2 — Turn the restored property into a business

**Goal:** Restoration must lead directly into business gameplay.

V1 property types:
- Warehouse
- Factory
- Retail outlet

V1 industries:
- Food processing
- Consumer goods
- Building materials

- [ ] Choose a business type after restoration.
- [ ] Define startup costs.
- [ ] Add employee requirements.
- [ ] Add supplier requirements.
- [ ] Add operating expenses.
- [ ] Add production capacity.
- [ ] Add customer demand.
- [ ] Add selling price.
- [ ] Calculate daily revenue and profit.
- [ ] Display a simple profit/loss breakdown.

**Done when:** a restored property can become a profitable or unprofitable business based on player decisions.

## Milestone 3 — Build the small economy

V1 resources:
- Raw materials
- Food ingredients
- Packaging
- Fuel
- Construction materials

- [ ] Add supply and demand.
- [ ] Connect resource prices to market conditions.
- [ ] Add supplier selection.
- [ ] Add supplier reliability and price differences.
- [ ] Add inventory.
- [ ] Add shortages and excess stock.
- [ ] Make resource decisions affect business profitability.

**Done when:** the player can improve or damage a business by managing its supply chain.

## Milestone 4 — Employees, customers and management

- [ ] Add employee roles.
- [ ] Add wages.
- [ ] Add productivity.
- [ ] Add employee morale.
- [ ] Add customer demand changes.
- [ ] Add quality/service level.
- [ ] Add simple customer satisfaction.
- [ ] Add staffing decisions.

**Done when:** running a business requires more than pressing an income button.

## Milestone 5 — Competition

The player should quickly discover that success attracts attention.

Create three NPC corporations:

1. **The Giant** — wealthy, aggressive, willing to undercut prices.
2. **The Specialist** — smaller but highly efficient in one industry.
3. **The Network** — strong supplier and distribution relationships.

- [ ] Add competitor company data.
- [ ] Give competitors cash, assets and strategic goals.
- [ ] Add competitor reactions to player expansion.
- [ ] Add price competition.
- [ ] Add supplier competition.
- [ ] Add acquisition opportunities.
- [ ] Add simple competitor news/events.

**Done when:** the player feels pressure from companies that are stronger than them.

## Milestone 6 — Alliances and relationships

Alliances are a major part of the game's identity and should provide alternatives to direct competition.

- [ ] Add company relationship score.
- [ ] Add partnership proposals.
- [ ] Add supply agreements.
- [ ] Add joint projects.
- [ ] Add preferred partners.
- [ ] Add betrayal/default consequences.
- [ ] Add alliance benefits and costs.

**Done when:** the player can choose whether to compete, cooperate, or strategically do both.

## Milestone 7 — Progression and empire building

- [ ] Add company reputation.
- [ ] Add company level/progression.
- [ ] Add unlockable property types.
- [ ] Add new districts/locations within the first region.
- [ ] Add multiple owned businesses.
- [ ] Add management overhead.
- [ ] Add investment decisions.
- [ ] Add partial ownership/investors as a later extension.

**Done when:** the player has a believable path from one restored property to a small business group.

## Milestone 8 — Events and replayability

Events should create stories rather than random punishment.

Examples:
- Supplier suddenly raises prices.
- Competitor opens next door.
- Local construction project increases demand.
- Equipment failure.
- Major customer offers a contract.
- Alliance partner needs help.
- Property owner offers another neglected site.
- Market shortage creates a temporary opportunity.

- [ ] Create event system.
- [ ] Add positive, negative and choice-based events.
- [ ] Give events economic consequences.
- [ ] Ensure events can create opportunities as well as problems.

## Milestone 9 — Save/load

- [ ] Save cash and company progression.
- [ ] Save property ownership.
- [ ] Save restoration states.
- [ ] Save business states.
- [ ] Save inventory and market state where required.
- [ ] Save relationships and alliances.
- [ ] Add manual save/load for development.

## Milestone 10 — First playable vertical slice

The prototype is successful when a new player can:

1. Start with limited cash.
2. Find a neglected property.
3. Inspect its potential.
4. Acquire it.
5. Make restoration decisions.
6. Watch it visibly improve.
7. Open a business.
8. Hire staff and choose suppliers.
9. Sell to customers.
10. Make a profit or loss.
11. Encounter a competitor.
12. Decide whether to compete or cooperate.
13. Reinvest earnings.
14. Buy/restore another opportunity.
15. Save and continue later.

## After V1

Only after the vertical slice is fun should we expand to:

- Larger regions
- More industries
- Resource ownership
- Logistics and transportation
- Corporate acquisitions
- Financing and debt
- Investors and shareholders
- Research and technology
- Global markets
- Major corporate alliances
- International expansion
- Advanced competitor AI
- Deeper narrative events
- Monetization
- Live events and long-term retention systems

## Design guardrails

1. Economic competition is the primary conflict. Do not turn the game into a generic military strategy game.
2. Restoration must remain visually and mechanically important.
3. Bigger companies should be powerful, but not unbeatable.
4. The player should have multiple paths to success: efficiency, specialization, alliances, aggressive expansion or smart resource control.
5. Failure should teach the player something and create stories rather than simply ending the game.
6. Avoid feature creep until the first restoration-to-profit loop is genuinely fun.
7. Major systems should create a meaningful decision, emotional attachment, or a reason to return.
