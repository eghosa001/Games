# RENEW — Master Implementation Plan

## 1. Purpose

This document is the authoritative implementation roadmap for RENEW.

It replaces the previous V1 checklist, which treated several foundations/stubs as completed systems. Status in this document reflects the actual repository implementation rather than README claims.

The game fantasy is:

> **Find something abandoned → restore it → turn it into a business → hire people → make money → secure resources → compete → build relationships → acquire companies → expand → build an economic empire → leave a legacy.**

The long-term architecture is:

**RESTORATION → PROPERTIES → BUSINESSES → EMPLOYEES → ECONOMY → RESOURCES → CONTRACTS → COMPETITORS → OWNERSHIP → ACQUISITIONS → ALLIANCES → DIPLOMACY → INFRASTRUCTURE → TECHNOLOGY → WORLD EVENTS → LIVEOPS → RANKINGS → HEADQUARTERS/MUSEUM → GLOBAL ECONOMY**

---

# 2. Implementation status

Legend:

- 🟢 **Implemented:** functioning system in the repository.
- 🟡 **Foundation:** partially implemented; suitable for expansion but not the complete master-plan system.
- 🔴 **Planned:** not yet implemented as a genuine system.

| System | Current status | Target |
|---|---|---|
| Restoration | 🟢 | V1 |
| Properties | 🟢 | V1/V1.5 |
| Businesses | 🟢 | V1/V1.5 |
| Employees | 🟡 | V1.1 |
| Executives | 🔴 | V1.5+ |
| Company culture | 🔴 | V1.5+ |
| Economy | 🟢 | V1.5 |
| Resources | 🟢 | V1.5 |
| Production | 🟢 | V1.5 |
| Supply chain | 🟢 | V1.5/V2 |
| Contracts | 🟡 | V1.5 |
| Competitors | 🟢 | V1.5 |
| Acquisitions | 🟢 | V1.5 |
| Ownership/control | 🟡 | V2 |
| Finance/banking | 🟢 | V1.5 |
| Credit rating | 🔴 | V2 |
| Alliances | 🟡 | V2 |
| Diplomacy/treaties | 🟡 | V2 |
| Joint ventures | 🔴 | V2+ |
| Mergers | 🔴 | V2+ |
| Bankruptcy/restructuring | 🔴 | V2+ |
| Technology | 🔴 | V2+ |
| Research | 🔴 | V2+ |
| Infrastructure | 🟡 | V2+ |
| Regional economy | 🟢 | V1.5/V2 |
| Global rankings | 🔴 | V2+ |
| World Power | 🔴 | V2+ |
| World events | 🟡 | V1.5 |
| LiveOps | 🔴 | Post-V2 |
| Collections | 🔴 | V2+ |
| Corporate history | 🟡 | V1.1 |
| RENEW Daily/news | 🟡 | V1.1 |
| Headquarters | 🟡 | V2+ |
| Corporate museum | 🔴 | V2+ |
| Analytics | 🔴 | Post-V2 |
| Multiplayer economy | 🔴 | Post-V2 |
| Monetization | 🔴 | Post-V2 |
| Mobile UI | 🟢 | V1 |
| Persistence | 🟢/🟡 | V1.1 refactor |
| Automated testing | 🟢 | V1+ |

---

# 3. Current V1 foundation

The repository already contains a functional prototype covering the central RENEW loop.

## 3.1 Restoration 🟢

Current flow:

**Inspect → Acquire → Clean → Repair → Rebuild → Install → Design → Operational → Business**

Requirements:

- abandoned property discovery
- inspection
- acquisition
- staged restoration
- restoration costs
- reputation consequences
- conversion from neglected property to productive asset

### Remaining work

- richer visual restoration feedback
- more property types
- restoration choices with different costs/outcomes
- historical identity for special properties
- future restoration projects/events

---

## 3.2 Properties 🟢/🟡

Current foundation includes expansion properties and resource sites with ownership, levels, income, inputs, employees, stock and upgrades.

Target property model:

> **Property = physical asset**

Properties eventually support:

- buy
- sell
- lease
- renovate
- develop
- repurpose
- combine
- specialize
- historical designation
- property history

---

## 3.3 Businesses 🟢/🟡

Current RENEW Goods loop includes:

- inputs
- production
- employees/count-based staffing
- capacity
- marketing
- pricing
- sales
- customer contracts
- daily cash flow

Target model:

> **Business = operating company**

A business must eventually own/manage properties, employ people, purchase resources, produce goods, sell products and interact with competitors and contracts.

---

# 4. V1.1 — Player story foundation

This is the immediate development priority.

## 4.1 Employees 🟡 → 🟢

Replace anonymous employee count with persistent people.

Each employee should contain:

- unique ID
- name
- role
- skill
- experience
- salary
- loyalty
- personality
- ambition
- productivity
- current assignment
- career level
- relationship with company
- relationship with other employees where relevant

Example:

> **James Carter**
> Carpenter · Skill 72 · Experience 14 · Loyalty 81 · Ambition 64

### Career progression

**Junior → Skilled → Supervisor → Manager → Regional Director → Executive**

### Gameplay consequences

Employees can:

- become more productive
- gain experience
- request raises
- become loyal
- leave
- be recruited by competitors
- receive promotions
- become managers
- influence company performance
- appear in RENEW Daily
- become permanent parts of corporate history

---

## 4.2 Executives 🔴

Later employee progression introduces named executives:

- CEO
- COO
- CFO
- CTO
- Head of Manufacturing
- Head of Logistics
- Regional Manager

Executives have strengths and weaknesses and influence different systems.

---

## 4.3 Corporate history 🟡 → 🟢

Create a permanent timeline separate from the short-lived activity log.

Examples:

- Bought Old Warehouse
- Completed first restoration
- Founded RENEW Goods
- Hired James Carter
- Made first profit
- Signed first major contract
- Bought Timber Camp
- Entered Industrial Belt
- Formed first alliance
- Acquired competitor

History must survive saves and remain attached to the company identity.

---

## 4.4 RENEW Daily 🟡 → 🟢

Transform activity logs into contextual business news.

Sections may include:

### YOUR COMPANY
Revenue, profit, production, employee changes, milestones.

### MARKET
Prices, shortages, demand changes, resource conditions.

### RIVALS
Competitor expansions, price changes, acquisitions and strategic moves.

### PEOPLE
Promotions, resignations, employee achievements and problems.

### OPPORTUNITIES
Properties, contracts, distressed assets and regional opportunities.

### WORLD
Major economic events and their consequences.

News should be generated from actual game state rather than being random flavor text.

---

# 5. Architecture stabilization

Before adding many more systems, establish a clean foundation.

## 5.1 Authoritative GameState 🟡

Create one authoritative state model containing:

- player/company identity
- cash
- debt
- reputation
- day
- properties
- businesses
- branches
- employees
- resources
- contracts
- competitors
- alliances
- regions
- ownership
- technology
- history
- events
- progression

Modules should operate on this state rather than independently owning conflicting copies.

## 5.2 Persistence consolidation 🟡

Current repository has several systems with persistence responsibilities.

Target:

> **One authoritative save state with versioned module data.**

Requirements:

- schema version
- migration support
- atomic save
- backup
- fallback recovery
- deterministic restoration of state

## 5.3 Module boundaries 🟡

Use clear responsibilities:

- `GameState` — authoritative data
- `PropertySystem` — physical assets
- `BusinessSystem` — companies
- `BranchSystem` — regional operations
- `EmployeeSystem` — people/careers
- `EconomySystem` — prices/markets
- `ResourceSystem` — extraction/resources
- `ProductionSystem` — recipes/output
- `ContractSystem` — agreements
- `CompetitorSystem` — rival companies
- `OwnershipSystem` — shares/control
- `AllianceSystem` — organizations
- `WorldEventSystem` — economic/world events
- `HistorySystem` — permanent company history
- `NewsSystem` — RENEW Daily
- `ProgressionSystem` — unlocks/goals
- `AnalyticsSystem` — telemetry

`main.gd` should eventually coordinate systems rather than directly own most business rules.

---

# 6. Data-driven economy

## Current 🟢/🟡

The economy already supports materials, packaging, fuel, prices, suppliers, stock, reliability, markup, market modifiers and transactions.

## Target 🟢/🟡

Move balance/content definitions out of gameplay code.

Data should define:

- resource prices
- wages
- restoration costs
- property costs
- production recipes
- recipe inputs
- output quantities
- quality rules
- transportation costs
- contract parameters
- competitor parameters
- event parameters
- upgrade costs

This allows balancing without rewriting simulation logic.

---

# 7. Production and resource economy

## 7.1 Resources 🟢/🟡

Current foundation:

- materials
- packaging
- fuel
- resource sites
- stock
- supplier market
- regional resource concepts

Target resource ecosystem:

- timber
- stone
- iron
- steel
- fuel
- energy
- agricultural goods
- chemicals
- electronics
- machinery
- construction materials
- other industry-specific resources

Resources should become strategically scarce and geographically differentiated.

## 7.2 Production 🟢/🟡

Target chain:

**Extraction → Transport → Processing → Manufacturing → Distribution → Retail → Customer**

Introduce:

- multiple recipes
- intermediate goods
- factories
- machinery
- automation
- efficiency
- quality
- capacity
- technology requirements

Example:

**Iron Mine → Railway → Steel Factory → Machine Factory → Furniture Factory → Warehouse → Retail → Customer**

---

# 8. Contracts 🟡

Expand current contracts into a general agreement framework.

Contract fields:

- parties
- quantity
- price
- duration
- quality requirements
- delivery schedule
- delivery location
- penalties
- reputation consequences
- renewal terms
- cancellation terms

Contract categories:

- supply
- customer
- construction
- distribution
- logistics
- infrastructure
- research
- alliance
- investment
- defense

Eventually support player-to-player contracts.

---

# 9. Competitors 🟢/🟡

Current competitors already have differentiated identities and can expand, alter prices, pressure suppliers, negotiate and retaliate.

Target personalities:

- aggressive
- conservative
- innovative
- opportunistic
- cooperative
- resource-focused
- expansionist

Competitors should remember important player actions.

Example:

> Player undercut The Giant for 12 consecutive days.

The Giant may remember that and retaliate later.

Competitors should make strategic decisions based on:

- cash
- assets
- resources
- regional position
- relationships
- player threat
- opportunities
- personality

---

# 10. Ownership and corporate control

## Current 🟡

The prototype already has founder/investor/treasury concepts, valuation, capital raising, board influence, buybacks and takeover pressure.

## Target

Support real ownership structures:

> You 42% · Player B 21% · Investor 17% · Alliance Fund 20%

Features:

- multiple shareholders
- share issuance
- dilution
- buybacks
- share purchases
- shareholder voting
- board seats
- control thresholds
- dividends
- hostile acquisition
- defensive measures

---

# 11. Acquisitions

## Current 🟢/🟡

Current systems support strategic asset acquisition, negotiation and hostile takeover foundations.

## Target

Four acquisition paths:

1. Direct purchase
2. Negotiated sale
3. Auction/competitive bidding
4. Hostile acquisition

Later:

5. Shareholder purchase
6. Full company acquisition
7. Merger

Acquisitions should affect:

- ownership
- debt
- employees
- properties
- resources
- reputation
- competitor relationships
- valuation

---

# 12. Finance

## Current 🟢/🟡

Loans, debt, interest and repayments exist.

## Target

Expand into:

- credit score/rating
- secured loans
- corporate bonds
- refinancing
- restructuring
- investor confidence
- bankruptcy protection
- asset liquidation
- recovery plans

### Bankruptcy 🔴

Bankruptcy is not simply loan default.

A proper system should allow:

**Restructure → sell assets → raise investment → merge → downsize → rebuild**

---

# 13. Alliances and diplomacy

## Current 🟡

Basic relationships, alliance offers and strategic benefits exist.

## Target alliance system

Alliances can own:

- infrastructure
- companies
- resource operations
- warehouses
- transport networks
- research facilities

Members can contribute:

- money
- resources
- technology
- labor
- infrastructure

### Governance

- Founder
- Chairman
- Directors
- Regional Leaders
- voting
- leadership elections
- investment votes
- expansion votes
- resource allocation

### Alliance treasury

Shared money is separate from member company money.

### Diplomacy

Treaties can cover:

- trade
- joint ventures
- research
- defense
- territory
- non-aggression
- investment

---

# 14. Joint ventures and mergers

## Joint ventures 🔴

Multiple companies contribute capital/assets/resources to a shared project.

Example:

> Port project cost: $500M
> Company A: 40%
> Company B: 35%
> Company C: 25%

Ownership, income, voting and obligations follow contribution rules.

## Mergers 🔴

**Company A + Company B → New Company**

Calculate:

- new valuation
- ownership
- debt
- management
- employees
- assets
- capabilities
- brand identity

---

# 15. Regions and infrastructure

## Regions 🟢/🟡

Current regions already contain demand, logistics, labor, competition, growth, specialization, resources, infrastructure and player/rival presence.

Target regional economy:

A region should become strategically different rather than simply providing a bonus.

Example:

> Controlling the primary timber region should affect timber availability and costs for companies operating elsewhere.

## Infrastructure 🟡

Expand regional infrastructure into physical assets:

- roads
- railways
- ports
- airports
- power plants
- warehouses
- industrial zones
- technology parks

Infrastructure should reduce logistics costs, increase capacity and change regional economic power.

---

# 16. Technology and research

## Technology 🔴

Technology trees:

### Manufacturing
Automation → Robotics → Smart Factories → Advanced Manufacturing

### Logistics
GPS → Optimization → Autonomous Delivery → Global Logistics

### Energy
Efficient Generation → Renewable → Storage → Advanced Energy

### Computing
Computing → AI → Advanced Computing → Next Generation

### Construction
Modern Materials → Modular → Smart Buildings → Mega Infrastructure

## Research 🔴

Research sources:

- company R&D
- alliance research
- universities
- partnerships
- joint research
- rare discoveries

Technology should unlock new recipes, buildings, efficiencies and strategic capabilities.

---

# 17. World events

## Current 🟡

The repository already contains dynamic event foundations and market modifiers.

## Target 🟢

Create one unified `WorldEventSystem` rather than competing event architectures.

Events should form causal chains.

Example:

**Energy Crisis**

→ energy prices rise

→ factories experience higher costs

→ weak factories reduce production

→ some competitors close

→ alternative energy demand increases

→ investment opportunity appears

→ new energy technology becomes valuable

The important rule is:

> **Events change the economy. They are not merely reward popups.**

---

# 18. Global rankings and World Power

## Global rankings 🔴

Rank companies using:

- valuation
- net worth
- revenue
- profit
- properties restored
- market share
- resources controlled
- alliance power
- technology
- global influence

## World Power 🔴

Create a composite score based on:

**Assets + Production + Revenue + Resources + Logistics + Influence + Alliances + Technology**

Rankings should update dynamically and become a long-term motivation system.

---

# 19. Headquarters and legacy

## Headquarters 🟡

Evolution:

**Tiny Office → Small Building → Corporate Office → Regional HQ → Tower → Skyscraper → Global HQ**

HQ level should reflect company scale and unlock functionality.

## Museum 🔴

Display:

- first hammer
- first blueprint
- first machine
- first contract
- employee awards
- first acquisition
- trophies
- historic properties
- alliance achievements

The museum turns progression into a physical representation of the player's story.

---

# 20. Collections

## Collections 🔴

Collect:

- properties
- vehicles
- machines
- blueprints
- technologies
- employees
- architectural styles
- artifacts
- awards

Collections should provide meaningful bonuses without becoming mandatory grind.

---

# 21. Special restoration events

## 🔴

Large-scale restoration projects:

- Flooded Town
- Historic Railway
- Abandoned Industrial District
- Historic Hotel

These can require:

- large capital
- multiple businesses
- alliances
- resources
- contracts
- infrastructure

They should create memorable stories rather than simply larger normal properties.

---

# 22. Multiplayer

## 🔴 — deliberately later

Do not build persistent multiplayer until the single-player economic loop is proven fun.

Eventually support:

- real player companies
- player contracts
- player alliances
- shared companies
- player ownership
- player negotiations
- player acquisitions
- shared infrastructure
- competitive global rankings

NPC systems should be designed so they can eventually coexist with human players.

---

# 23. Analytics

## 🔴

Eventually track:

- tutorial completion
- first inspection
- first acquisition
- first restoration
- first business
- first employee
- first profit
- first contract
- first alliance
- first acquisition
- session duration
- retention
- churn
- restoration completion
- economy decisions
- alliance participation
- monetization events

Analytics must respect privacy and platform requirements.

---

# 24. LiveOps

## 🔴/🟡

The current event foundation should evolve into recurring economic stories:

- Industrial Revolution
- Global Trade
- Energy Crisis
- Luxury Season
- Technology Race
- Historic Restoration
- Global Infrastructure

LiveOps should add new strategic situations rather than simply adding reward calendars.

---

# 25. Monetization

## 🔴 — deliberately later

Monetization must not undermine the economic strategy.

Potential categories:

- cosmetics
- premium restoration projects
- season pass
- convenience features
- rewarded ads
- expansion packs

Avoid pay-to-dominate economics.

---

# 26. Mobile UX

## 🟢

Current mobile work includes:

- touch actions
- responsive layouts
- action scrolling
- feedback
- milestone notifications
- daily reports
- dynamic goals

Next UX improvements should expose the new systems without overwhelming the player.

Priority screens:

1. Property
2. Business
3. Employees
4. Market
5. Regions
6. Contracts
7. Rivals
8. Company
9. RENEW Daily
10. History

---

# 27. Testing strategy

## Current 🟢

The repository already contains regression, extended, edge-case and long-duration testing.

Continue maintaining:

- new-game tests
- restoration tests
- economy tests
- production tests
- expansion tests
- competitor tests
- contract tests
- save/load tests
- edge cases
- 365-day soak
- 1000-day soak

Add tests whenever a new system changes the simulation state.

### New requirement

Automated tests verify correctness, but they do not prove fun.

Every major milestone therefore requires a manual 30–60 day playthrough.

---

# 28. Development order

This is the required implementation sequence.

## PHASE A — Foundation

- [ ] Authoritative GameState
- [ ] Save-state consolidation
- [ ] Module boundaries
- [ ] Data-driven balance
- [ ] Unified event architecture
- [ ] Property/Business/Branch separation

## PHASE B — Player attachment

- [ ] Individual employees
- [ ] Employee progression
- [ ] Employee events
- [ ] Corporate history
- [ ] RENEW Daily
- [ ] Story milestones

## PHASE C — Core fun/balance

- [ ] 30–60 day manual playthrough
- [ ] Restoration balance
- [ ] Production balance
- [ ] Wage balance
- [ ] Supplier balance
- [ ] Competitor balance
- [ ] Loan balance
- [ ] Expansion pacing
- [ ] Mobile usability pass

## PHASE D — Deeper economy

- [ ] More resources
- [ ] Multiple recipes
- [ ] Intermediate goods
- [ ] Regional scarcity
- [ ] Deeper supply chains
- [ ] Full contracts
- [ ] Stronger competitor AI

## PHASE E — Corporate strategy

- [ ] Shareholders
- [ ] Board control
- [ ] Deeper acquisitions
- [ ] Auctions
- [ ] Mergers
- [ ] Bankruptcy/restructuring

## PHASE F — Social strategy

- [ ] Alliance 2.0
- [ ] Alliance treasury
- [ ] Governance
- [ ] Voting
- [ ] Treaties
- [ ] Joint ventures

## PHASE G — World simulation

- [ ] Technology
- [ ] Research
- [ ] Infrastructure
- [ ] Regional economic control
- [ ] World events/chains
- [ ] Global rankings
- [ ] World Power

## PHASE H — Legacy

- [ ] HQ evolution
- [ ] Museum
- [ ] Collections
- [ ] Special restoration events
- [ ] Corporate legacy systems

## PHASE I — Commercial/live game

- [ ] Analytics
- [ ] LiveOps
- [ ] Multiplayer
- [ ] Monetization
- [ ] Store/release packaging

---

# 29. What NOT to build yet

Until the core single-player loop is demonstrably fun, do not prioritize:

- massive multiplayer economy
- stock market
- complex international corporations
- alliance governance at full scale
- huge infrastructure networks
- global rankings
- advanced diplomacy
- monetization
- large LiveOps framework

These systems are valuable later but create enormous complexity before the core game has been validated.

---

# 30. Definition of V1.1 complete

V1.1 is complete when:

- [ ] Existing V1 gameplay still works
- [ ] Employees are real persistent entities
- [ ] Employees participate in daily simulation
- [ ] Employees can gain experience
- [ ] Employees can be promoted
- [ ] Employee state saves/loads correctly
- [ ] Corporate history persists
- [ ] RENEW Daily reflects actual game state
- [ ] Major milestones create story entries
- [ ] No duplicate persistence systems create conflicting state
- [ ] Existing automated tests pass
- [ ] A 30–60 day manual playthrough is stable and enjoyable

---

# 31. Definition of a commercially viable RENEW core

The game should reach this state before serious multiplayer/monetization work:

> The player can start with almost nothing, restore an abandoned asset, build a profitable business, hire memorable employees, react to changing markets, compete with intelligent rivals, establish relationships, expand into new regions, and look back at a persistent history of meaningful decisions.

If players naturally say:

> **“I remember when James was my first employee.”**
>
> **“That warehouse was the beginning of everything.”**
>
> **“The Giant nearly destroyed me.”**
>
> **“We survived the energy crisis because of our supplier.”**
>
> **“That company used to be our biggest competitor; now we own it.”**

then RENEW has achieved the emotional foundation required for the much larger economic world.

---

# 32. Non-negotiable design principles

1. **Restoration remains the identity of the game.**
2. **Economic systems must create meaningful decisions, not spreadsheet complexity for its own sake.**
3. **Employees are people, not just a number.**
4. **Rivals remember and react to player behavior.**
5. **Relationships should have strategic consequences.**
6. **Events should change the world rather than merely reward the player.**
7. **The player's history should persist.**
8. **Systems should be modular and data-driven.**
9. **Mobile interaction must remain simple despite increasing simulation depth.**
10. **Multiplayer and monetization come after the single-player game is proven fun.**
11. **Do not mark a system complete because a stub or foundation exists.**
12. **Every major system must be tested both technically and through actual gameplay.**

---

# 33. Current next action

The immediate implementation target is:

**AUTHORITATIVE GAMESTATE → EMPLOYEE INTEGRATION → SAVE INTEGRATION → CORPORATE HISTORY → RENEW DAILY → BALANCE/PLAYTEST**

Only after that slice is stable should the project move into deeper economy and corporate systems.
