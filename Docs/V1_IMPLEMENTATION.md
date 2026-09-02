# RENEW — Master Implementation Plan

> **Status:** Authoritative implementation specification
> **Repository:** `eghosa001/Games`
> **Purpose:** Define what must be built, what is genuinely complete, what is only a foundation, and the order in which RENEW should be developed.

---

## 1. Vision

RENEW is an economic restoration and corporate strategy game built around one fantasy:

> **Find something abandoned → restore it → turn it into a business → hire people → make money → secure resources → compete → build relationships → acquire companies → expand → build an economic empire → leave a legacy.**

The player should begin small enough to understand every decision and eventually become capable of influencing entire regions and industries.

The intended long-term simulation is:

**RESTORATION → PROPERTIES → BUSINESSES → EMPLOYEES → ECONOMY → RESOURCES → CONTRACTS → COMPETITORS → OWNERSHIP → ACQUISITIONS → ALLIANCES → DIPLOMACY → INFRASTRUCTURE → TECHNOLOGY → WORLD EVENTS → RANKINGS → HEADQUARTERS/MUSEUM → GLOBAL ECONOMY**

Every later system must strengthen this chain rather than becoming an isolated minigame.

---

# 2. Development rules

These rules are mandatory.

1. **Build systems, not placeholders.** A button that changes one integer is not considered a complete system.
2. **Do not throw away working foundations.** Refactor and extend them.
3. **One source of truth.** Simulation state must not be duplicated unnecessarily across controllers.
4. **Data-driven balance.** Costs, recipes, wages, resources, events and AI parameters should eventually live in configuration/data.
5. **Every major system must affect gameplay.** UI-only systems do not count as implemented.
6. **Persistence is part of implementation.** A feature is incomplete if important state disappears after loading.
7. **NPC decisions must be state-aware.** Random flavor is not strategic AI.
8. **Mobile is a first-class platform.** Controls and layouts must remain usable on touch devices.
9. **Numbers must have consequences.** Prices, shortages, reputation, employees, debt and relationships must feed back into the simulation.
10. **The first 30–60 days must be fun before deep endgame systems are built.**

---

# 3. Status legend

- 🟢 **Implemented:** functioning repository system with gameplay effect.
- 🟡 **Foundation:** partially implemented or simplified; must be expanded.
- 🔴 **Planned:** not implemented as a genuine system.
- ⚠️ **Refactor:** exists but architecture must change before major expansion.

A system must not be marked 🟢 merely because a file, class, button or placeholder exists.

---

# 4. Current implementation status

| System | Status | Required milestone |
|---|---|---|
| Restoration | 🟢 | V1 |
| Properties | 🟡 | V1.5 |
| Businesses | 🟡 | V1.5 |
| Employees | 🟡 | V1.1 |
| Executives | 🔴 | V1.5+ |
| Company culture | 🔴 | V2 |
| Economy | 🟡 | V1.5 |
| Resources | 🟡 | V1.5 |
| Production | 🟡 | V1.5 |
| Supply chain | 🟡 | V1.5/V2 |
| Contracts | 🟡 | V1.5 |
| Competitors | 🟡 | V1.5 |
| Ownership/control | 🟡 | V2 |
| Acquisitions | 🟡 | V1.5/V2 |
| Finance/banking | 🟡 | V1.5 |
| Credit rating | 🔴 | V2 |
| Alliances | 🟡 | V2 |
| Diplomacy/treaties | 🟡 | V2 |
| Joint ventures | 🔴 | V2+ |
| Mergers | 🔴 | V2+ |
| Bankruptcy/restructuring | 🔴 | V2+ |
| Regions | 🟢/🟡 | V1.5/V2 |
| Infrastructure | 🟡 | V2 |
| Technology | 🔴 | V2+ |
| Research | 🔴 | V2+ |
| World events | 🟡 | V1.5 |
| Global rankings | 🔴 | V2+ |
| World Power | 🔴 | V2+ |
| Corporate history | 🟡 | V1.1 |
| RENEW Daily | 🟡 | V1.1 |
| Headquarters | 🟡 | V2+ |
| Corporate museum | 🔴 | V2+ |
| Collections | 🔴 | V2+ |
| Analytics | 🔴 | Post-V2 |
| Multiplayer economy | 🔴 | Post-V2 |
| LiveOps | 🔴 | Post-V2 |
| Monetization | 🔴 | Post-V2 |
| Mobile UI | 🟢 | V1 |
| Persistence | 🟡/⚠️ | V1.1 |
| Automated tests | 🟢 | Continuous |

---

# 5. V1 core loop

The first complete playable loop is:

**Inspect → Acquire → Restore → Open Business → Buy Inputs → Produce → Sell → Pay Workers/Overhead → Reinvest → Expand**

The player must always understand:

- what they own
- what they can afford
- what is profitable
- what is risky
- what to improve next
- what competitors are doing
- what opportunity is available

The loop must create meaningful choices instead of requiring the player to press buttons in a fixed order forever.

---

# 6. Restoration system

## Current foundation 🟢

The prototype supports inspection, acquisition and staged restoration.

Current intended progression:

**Neglected → Cleaned → Repaired → Rebuilt → Installed → Designed → Operational**

## Required completion

Each restoration project must eventually support:

- property discovery
- inspection cost
- purchase price
- restoration estimate
- individual restoration stages
- stage-specific costs
- construction time
- quality outcomes
- unexpected problems
- contractor choices
- material requirements
- reputation effects
- visual progression
- property history
- alternative final uses

### Restoration decisions

A player should sometimes choose between:

- cheap/fast restoration
- expensive/high-quality restoration
- preservation
- modernization
- conversion to another business type

These choices must create different downstream economics.

### Special restoration projects

Later properties may contain:

- historical buildings
- abandoned factories
- old transport facilities
- famous landmarks
- damaged industrial sites
- community assets

Special projects can unlock unique rewards, reputation, stories and collections.

---

# 7. Property system

## Definition

> **Property = physical asset.**

A property is not a business and not a branch.

## Required data

Every property should eventually have:

- unique ID
- name
- property type
- region
- district
- owner
- condition
- historical value
- market value
- acquisition cost
- operating capacity
- current use
- development level
- attached business ID
- infrastructure connections
- property history

## Actions

- inspect
- buy
- sell
- lease
- renovate
- develop
- repurpose
- specialize
- combine
- abandon
- designate as historical

## Property lifecycle

**Discovered → Inspected → Acquired → Restored → Developed → Operated → Upgraded → Repurposed/Sold**

---

# 8. Business system

## Definition

> **Business = operating company.**

A business controls operations, finances, employees, products and strategy.

A business may own or lease multiple properties and operate multiple branches.

## Required data

- company ID
- legal/brand name
- industry
- founder
- treasury
- valuation
- debt
- reputation
- employees
- properties
- branches
- products
- inventory
- contracts
- suppliers
- shareholders
- technology
- history

## Business lifecycle

**Founded → Operating → Growing → Regional → National → International → Corporate Group**

---

# 9. Branch system

## Definition

> **Branch = regional operating unit of a business.**

A branch must not become a second independent company.

A branch contains:

- parent business ID
- region
- property ID
- employees
- inventory
- local pricing
- local demand
- local revenue
- local expenses
- local reputation
- local logistics
- branch level

This distinction is mandatory:

**Property = where physical activity happens**

**Business = who owns/manages the operation**

**Branch = where that business operates regionally**

---

# 10. Employee system — V1.1 priority

The current anonymous employee count is only a foundation. It must become persistent people.

## Employee data

Each employee requires:

- unique ID
- generated/name identity
- age range
- role
- skill
- experience
- salary
- loyalty
- morale
- productivity
- personality
- ambition
- career level
- current assignment
- employer/business ID
- branch/property assignment
- hiring day
- promotion history
- notable achievements
- relationship with company

## Roles

Initial roles:

- Worker
- Technician
- Salesperson
- Accountant
- Supervisor
- Manager

Later:

- Regional Manager
- Director
- CEO
- COO
- CFO
- CTO
- Head of Manufacturing
- Head of Logistics

## Career ladder

**Junior → Skilled → Supervisor → Manager → Regional Director → Executive**

## Employee gameplay

Employees can:

- gain experience
- increase productivity
- request raises
- become loyal
- become dissatisfied
- leave
- be recruited by rivals
- be promoted
- mentor others
- create relationships
- become managers
- become executives
- generate stories

## Employee economics

Salary is a real operating cost.

Productivity must influence output, quality, efficiency or sales depending on role.

Morale and loyalty must influence retention and performance.

---

# 11. Executive system

Executives are specialized employees with company-wide effects.

Each executive should have:

- skill profile
- leadership
- loyalty
- compensation
- strategy preference
- strengths
- weaknesses
- relationships

Example:

**CFO:** stronger financing and cost control, weaker aggressive expansion.

**COO:** stronger production/logistics efficiency.

**CTO:** stronger research and technology.

Executives may leave, be poached or become rivals.

---

# 12. Company culture

Culture is a long-term company characteristic.

Possible axes:

- efficiency
- innovation
- employee welfare
- aggressive growth
- stability
- environmental responsibility
- customer focus

Culture affects employee loyalty, recruitment, productivity, reputation and strategic options.

---

# 13. Corporate history

Create a permanent company timeline separate from the short activity log.

History entries should contain:

- day
- category
- title
- description
- importance
- related property/business/employee/rival ID

Examples:

- Bought Old Warehouse
- Completed first restoration
- Founded RENEW Goods
- Hired first employee
- Employee promoted to manager
- First profitable month
- First major contract
- First expansion
- First alliance
- First acquisition
- First regional entry
- First hostile takeover

History must survive saves and should later power the Corporate Museum and RENEW Daily.

---

# 14. RENEW Daily / business news

RENEW Daily turns simulation state into readable news.

## Sections

### YOUR COMPANY
- revenue
- profit
- production
- new employees
- promotions
- resignations
- milestones

### MARKET
- price movement
- shortages
- demand changes
- supply conditions

### RIVALS
- expansion
- acquisitions
- price changes
- supplier actions
- alliances
- conflicts

### PEOPLE
- employee achievements
- promotions
- disputes
- departures
- executive developments

### OPPORTUNITIES
- properties
- contracts
- distressed companies
- investment opportunities
- regional opportunities

### WORLD
- major economic events
- infrastructure changes
- resource shocks
- technology breakthroughs

News must be generated from actual simulation events. Random flavor may supplement real events but cannot replace them.

---

# 15. Authoritative GameState

The repository must converge on one authoritative state boundary.

## State domains

- game metadata
- player/company identity
- day
- cash
- debt
- reputation
- properties
- businesses
- branches
- employees
- resources
- production
- contracts
- competitors
- ownership
- alliances
- regions
- infrastructure
- technology
- research
- events
- history
- news
- progression

Controllers may calculate temporary runtime values, but persistent state must be represented in the authoritative state model.

## Main coordinator

`main.gd` should progressively become an orchestrator rather than a god object containing every business rule.

---

# 16. Persistence architecture

## Requirements

One authoritative save operation must capture all persistent systems.

Required features:

- schema version
- module version data
- atomic temporary write
- backup
- fallback recovery
- migration
- validation
- deterministic load

## Migration

Existing saves must remain usable whenever practical.

Every schema change requires either:

- migration code, or
- explicit documented incompatibility.

## Save coverage

At minimum:

- company state
- restoration state
- properties
- businesses
- branches
- employees
- resources
- production inventory
- contracts
- competitors
- alliances
- regions
- infrastructure
- ownership
- debt
- history
- events affecting the world
- progression

No important gameplay system should maintain an unrelated hidden save file indefinitely.

---

# 17. Economy system

The current economy foundation contains resources, prices, suppliers, stock and transactions. It must become a deeper interconnected economy.

## Data-driven definitions

Move definitions into configuration/data for:

- resource prices
- price ranges
- wages
- restoration costs
- property values
- production recipes
- transport costs
- supplier characteristics
- contracts
- competitors
- events
- upgrades
- technologies

## Market behavior

Prices should respond to:

- supply
- demand
- regional conditions
- transportation
- scarcity
- competitor behavior
- world events
- contracts
- production capacity

---

# 18. Resource system

Resources should become geographically differentiated and strategically meaningful.

Initial categories may include:

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

Resource sites should have:

- capacity
- extraction rate
- depletion/renewal model where appropriate
- ownership
- workforce
- operating cost
- transport connection
- quality
- local market conditions

Controlling an important resource region should affect downstream costs and availability.

---

# 19. Production system

Target chain:

**Extraction → Transport → Processing → Manufacturing → Distribution → Retail → Customer**

Production must support:

- multiple recipes
- intermediate goods
- machinery
- employee skill
- quality
- capacity
- efficiency
- automation
- maintenance
- technology requirements
- production failures

Example:

**Iron Mine → Railway → Steel Factory → Machine Factory → Furniture Factory → Warehouse → Retail → Customer**

A production bottleneck must be able to propagate through the chain.

---

# 20. Supply chain

The supply network must eventually model:

- extraction
- processing
- transport
- storage
- manufacturing
- distribution
- retail

Transport requires:

- capacity
- route
- distance
- cost
- travel time
- disruption risk
- infrastructure quality

Shortages should create real consequences instead of only changing a popup.

---

# 21. Contracts

Create a general contract framework.

Every contract should support:

- parties
- resource/product
- quantity
- unit price
- duration
- quality requirement
- delivery schedule
- delivery location
- penalties
- reputation impact
- renewal
- cancellation
- breach

Contract types:

- supply
- customer
- construction
- logistics
- distribution
- infrastructure
- research
- investment
- defense
- alliance

Later support player-to-player contracts.

---

# 22. Competitor AI

Current rivals are differentiated but remain largely rule-driven foundations.

## Rival profile

Each competitor should have:

- personality
- risk tolerance
- cash strategy
- industry preference
- regional preference
- relationship state
- strategic goals
- memory
- threat assessment
- resource dependencies

## Memory

Important player actions must be remembered.

Example:

> Player undercut The Giant for 12 consecutive days.

The Giant can later retaliate, negotiate, acquire a supplier, lower prices or attempt an acquisition.

## AI decision priorities

Each day competitors evaluate:

1. survival
2. profitability
3. resource security
4. regional position
5. player threat
6. strategic opportunities
7. relationships
8. long-term goals

Competitors should be capable of helping, ignoring, competing with, partnering with or attempting to destroy the player's company depending on circumstances.

---

# 23. Ownership and corporate control

The current ownership prototype must evolve into a true shareholder system.

Example:

**Player 42% · Investor A 21% · Investor B 17% · Alliance Fund 20%**

Required features:

- shareholders
- share issuance
- dilution
- share purchases
- buybacks
- dividends
- voting
- board seats
- control thresholds
- investor confidence
- takeover pressure
- defensive measures

Ownership must affect who controls strategic decisions.

---

# 24. Acquisitions

Acquisition paths:

1. direct asset purchase
2. negotiated company sale
3. auction/competitive bidding
4. hostile acquisition
5. shareholder purchase
6. full company acquisition
7. merger

Acquisitions must transfer or account for:

- employees
- properties
- branches
- resources
- contracts
- debt
- ownership
- reputation
- technology
- management

A purchased company should not simply disappear into a counter increment.

---

# 25. Finance and banking

Current loans/debt are a foundation.

Expand to:

- credit rating
- secured lending
- refinancing
- corporate bonds
- investor confidence
- collateral
- interest-rate changes
- restructuring
- bankruptcy protection
- asset liquidation

## Bankruptcy

Bankruptcy should create a recovery gameplay path:

**Financial distress → negotiation → restructure → asset sale/investment/downsizing/merger → recovery or failure**

Do not implement bankruptcy as an instant game-over unless a specific challenge mode requires it.

---

# 26. Alliances

Alliances must become organizations rather than simple relationship bonuses.

An alliance can eventually own:

- infrastructure
- resource operations
- warehouses
- companies
- transport networks
- research facilities

Members may contribute:

- money
- resources
- technology
- labor
- infrastructure

## Governance

- founder
- chairman
- directors
- regional leaders
- voting
- elections
- investment votes
- expansion votes
- resource allocation

## Treasury

Alliance money is separate from member company money.

---

# 27. Diplomacy and treaties

Treaties should include:

- trade
- joint venture
- research
- defense
- territory
- non-aggression
- investment
- resource access

Treaties need:

- parties
- duration
- obligations
- benefits
- breach conditions
- reputation consequences
- cancellation rules

Diplomacy should influence economic and strategic outcomes.

---

# 28. Joint ventures

A joint venture is a shared project owned by multiple companies.

Example:

**Port Project — $500M**

- Company A: 40%
- Company B: 35%
- Company C: 25%

The system must calculate:

- contributions
- ownership
- voting
- income
- costs
- obligations
- failure risk
- exit rules

---

# 29. Mergers

Mergers combine companies rather than merely buying one asset.

A merger must determine:

- surviving/new company identity
- valuation
- ownership
- debt
- employees
- executives
- properties
- branches
- technology
- contracts
- brand
- culture
- board structure

Integration can produce temporary costs and employee morale effects.

---

# 30. Regions

Regions should become economically different places rather than simple multipliers.

Each region can have:

- population
- demand
- labor supply
- wage level
- logistics quality
- infrastructure
- resource specialization
- industry specialization
- growth rate
- competition
- player presence
- rival presence
- market size
- local events

Regional control should matter to company strategy.

---

# 31. Infrastructure

Upgrade regional abstract infrastructure into physical strategic assets.

Types:

- roads
- railways
- ports
- airports
- power plants
- warehouses
- industrial zones
- technology parks

Infrastructure effects:

- transport capacity
- logistics cost
- travel time
- energy availability
- regional attractiveness
- industrial capacity
- resource access

Infrastructure projects should require money, materials, workers and time.

---

# 32. Technology tree

Technology must eventually become a real progression system.

## Manufacturing

Automation → Robotics → Smart Factories → Advanced Manufacturing

## Logistics

GPS → Optimization → Autonomous Delivery → Global Logistics

## Energy

Efficient Generation → Renewable → Storage → Advanced Energy

## Computing

Computing → AI → Advanced Computing → Next Generation

## Construction

Modern Materials → Modular → Smart Buildings → Mega Infrastructure

Technology must unlock actual gameplay capabilities.

---

# 33. Research

Research sources:

- company R&D
- alliance research
- universities
- partnerships
- joint research
- discoveries

Research requires:

- money
- researchers
- facilities
- time
- technology prerequisites

Research outputs must affect production, logistics, energy, construction, products or strategy.

---

# 34. World Event System

The repository has multiple event foundations. They must eventually converge into one `WorldEventSystem`.

Events should operate through a lifecycle:

**Trigger → Escalation → Player/NPC response → Consequence → Recovery → Long-term change**

Example:

**Energy Crisis**

→ energy prices rise

→ factory costs rise

→ weak factories cut production

→ some competitors struggle

→ alternative energy demand rises

→ investment opportunity appears

→ new technology becomes valuable

The rule is:

> **World events must change the economy, not merely reward the player with cash.**

---

# 35. Global rankings

Rank companies using multiple dimensions:

- valuation
- revenue
- profit
- assets
- employees
- market share
- resource control
- infrastructure control
- technology
- reputation
- regional influence

Rankings should update over time and produce meaningful competition.

---

# 36. World Power

World Power is a composite measure of economic influence.

Possible components:

- capital
- resource control
- industrial capacity
- logistics
- technology
- infrastructure
- alliances
- market share
- regional control
- reputation

World Power should unlock higher-level strategic opportunities and make the player's rise visible.

---

# 37. Headquarters

Headquarters begins as a management concept and later becomes a physical progression system.

Stages may include:

**Office → Headquarters → Corporate Center → Regional HQ → Global HQ**

HQ can display:

- company achievements
- executives
- departments
- technology
- maps
- financial information
- history
- awards

HQ upgrades should feel like visible evidence of growth.

---

# 38. Corporate Museum

The museum preserves the company's journey.

It should display:

- first property
- restoration milestones
- important employees
- famous contracts
- acquisitions
- historic products
- awards
- major events
- old company logos/brands
- important rivalries
- alliance achievements

The museum is powered by Corporate History and Collections.

---

# 39. Collections

Collections are long-term optional goals.

Examples:

- restored landmarks
- historic properties
- rare machinery
- famous products
- important documents
- trophies
- unique businesses

Collections should reward exploration without becoming mandatory progression.

---

# 40. Personalized world news

The player should eventually receive a living newspaper reflecting their position in the world.

A new player should see local opportunities.

A regional company should see regional economic news.

A global company should see international events, rival boardroom stories and geopolitical/economic changes.

News priority should depend on relevance, not random selection.

---

# 41. Multiplayer economy

Multiplayer is deliberately later.

When implemented, players should interact through:

- buying/selling
- contracts
- investments
- alliances
- joint ventures
- resource markets
- acquisitions
- competition
- rankings

The simulation must be designed so that NPC and player companies can share compatible economic interfaces.

Do not build multiplayer networking before the single-player economy is stable.

---

# 42. Analytics

Later analytics should measure:

- tutorial completion
- restoration completion
- first profit
- first expansion
- first employee departure
- contract failures
- bankruptcies
- acquisition frequency
- day-30 retention
- day-90 retention
- economy balance
- most-used strategies

Analytics must respect privacy and must not become a dependency for core gameplay.

---

# 43. LiveOps

LiveOps comes after the core simulation is proven.

Possible systems:

- seasonal economic events
- limited restoration projects
- market cycles
- community goals
- special contracts
- rotating opportunities
- challenges

LiveOps content must plug into the existing WorldEventSystem rather than create a second economy.

---

# 44. Monetization

Monetization is intentionally postponed.

Do not compromise the core simulation to force monetization into early development.

When introduced, monetization should not invalidate fair strategic play.

---

# 45. Mobile UX

Mobile is a core target.

Requirements:

- large touch targets
- readable text
- responsive layouts
- scrollable information panels
- clear action feedback
- confirmation for expensive/risky actions
- compact but informative dashboards
- accessible menus
- stable performance
- no keyboard-only critical action

The desktop keyboard shortcuts can remain for development and testing, but every essential gameplay function needs a touch-accessible UI.

---

# 46. Testing strategy

Automated tests must cover simulation correctness.

## Required test groups

### New game

- initial state
- first inspection
- acquisition
- restoration
- business opening

### Economy

- purchase
- sale
- insufficient cash
- stock changes
- price changes
- supplier reliability

### Production

- recipe inputs
- output
- capacity
- employee effects
- insufficient resources

### Employees

- hire
- salary
- promotion
- productivity
- morale
- departure
- persistence

### Contracts

- creation
- delivery
- completion
- breach
- cancellation
- rewards/penalties

### Competitors

- daily decisions
- price changes
- expansion
- relationship changes
- memory

### Persistence

- save
- load
- backup
- fallback
- migration
- full-state round trip

### Long simulation

- 365-day soak
- 1000-day soak
- bankruptcy/recovery once those systems exist
- resource shortages
- event chains

Automated tests prove correctness, not fun. Manual playtesting remains mandatory.

---

# 47. Balance and playtesting

Before adding advanced endgame systems, perform repeated 30–60 day playthroughs.

Measure:

- time to first restoration
- time to first business
- cash flow
- employee affordability
- input costs
- selling price
- competitor pressure
- contract profitability
- loan risk
- expansion timing
- player decision density

Questions to answer:

- Is the opening exciting?
- Does restoration feel rewarding?
- Is hiring meaningful?
- Can the player recover from mistakes?
- Are competitors threatening but understandable?
- Does expansion feel earned?
- Does the player have reasons to care about individual people?
- Are there several viable strategies?

---

# 48. Development phases

## Phase A — Foundation stabilization

1. Authoritative GameState
2. Save consolidation
3. Schema/migration validation
4. Property/Business/Branch boundaries
5. Main coordinator refactor
6. Data-driven balance foundations
7. Automated regression coverage

**Exit condition:** core state can be saved/loaded reliably without duplicate authoritative systems.

---

## Phase B — Player attachment

1. Real employees
2. Employee career progression
3. Employee economics
4. Corporate History
5. RENEW Daily
6. Milestone notifications
7. Employee persistence

**Exit condition:** the company feels like a group of people rather than counters.

---

## Phase C — Core fun and balance

1. 30–60 day manual playtests
2. Restoration tuning
3. Production tuning
4. wage tuning
5. pricing tuning
6. supplier tuning
7. competitor tuning
8. contract tuning
9. loan tuning
10. expansion pacing
11. restoration visual feedback

**Exit condition:** a new player can understand the loop and make meaningful choices for at least the first 30 days.

---

## Phase D — Deeper economy

1. more resources
2. multiple recipes
3. intermediate goods
4. extraction
5. processing
6. transport
7. manufacturing
8. distribution
9. regional scarcity
10. physical infrastructure

**Exit condition:** supply and demand form a genuinely interconnected economy.

---

## Phase E — Corporate strategy

1. real ownership
2. shareholders
3. control
4. credit rating
5. advanced acquisitions
6. company acquisition
7. hostile takeovers
8. executive system
9. company culture
10. bankruptcy/restructuring

**Exit condition:** growing a company requires strategic corporate decisions, not only purchasing upgrades.

---

## Phase F — Social strategy

1. Alliance 2.0
2. alliance treasury
3. alliance governance
4. treaties
5. diplomacy
6. joint ventures
7. mergers
8. shared infrastructure

**Exit condition:** relationships with companies and organizations become strategically important.

---

## Phase G — World simulation

1. technology trees
2. research
3. unified world events
4. causal event chains
5. global rankings
6. World Power
7. regional competition
8. global economic interactions

**Exit condition:** the world continues evolving independently of the player.

---

## Phase H — Legacy

1. headquarters progression
2. Corporate Museum
3. Collections
4. permanent history
5. legacy achievements
6. world recognition

**Exit condition:** the player can look back at a unique corporate story created by their decisions.

---

## Phase I — Commercial/live game

1. analytics
2. LiveOps framework
3. seasonal content
4. multiplayer economy
5. monetization
6. production hardening
7. device optimization
8. release pipeline

**Exit condition:** RENEW is stable enough for long-term operation.

---

# 49. What NOT to build yet

Do not prioritize these before Phases A–C are stable:

- multiplayer networking
- monetization
- complex global diplomacy
- huge technology trees
- massive world maps
- elaborate 3D headquarters
- live-service infrastructure
- cosmetic stores

A large feature count does not compensate for a weak core loop.

---

# 50. V1.1 completion criteria

V1.1 is complete only when all of the following are true:

- [ ] GameState is authoritative for persistent simulation state.
- [ ] Existing saves migrate safely.
- [ ] Employees are persistent individual people.
- [ ] Hiring affects actual gameplay.
- [ ] Salaries affect cash flow.
- [ ] Skills affect productivity.
- [ ] Experience/career progression works.
- [ ] Employee changes persist through save/load.
- [ ] Corporate History records important milestones.
- [ ] History persists through save/load.
- [ ] RENEW Daily reads actual simulation events.
- [ ] Major employee events appear in news/history.
- [ ] Property/Business/Branch boundaries are defined in code.
- [ ] The duplicate persistence paths are consolidated or explicitly bridged.
- [ ] Automated regression tests pass.
- [ ] A 30–60 day manual playthrough is enjoyable.

---

# 51. Definition of a commercially viable RENEW core

Before commercial release, the core game must allow a player to:

1. discover an abandoned property
2. inspect it
3. acquire it
4. restore it
5. make meaningful restoration choices
6. create a business
7. hire named employees
8. watch employees grow
9. produce and sell goods
10. manage resources
11. negotiate contracts
12. react to market conditions
13. compete with believable rivals
14. expand into new regions
15. make meaningful financial decisions
16. form relationships
17. acquire assets/companies
18. experience consequences from decisions
19. read a personalized company/world news feed
20. see their company's history evolve

The player should finish a session thinking:

> **“This is my company. These are my people. I built this.”**

---

# 52. Long-term player fantasy

The final game should allow a player to start with almost nothing and eventually:

- own historic properties
- employ thousands of people
- control supply chains
- own resource companies
- operate factories
- build infrastructure
- influence regional economies
- compete with giant corporations
- create alliances
- negotiate treaties
- develop technologies
- acquire rivals
- merge companies
- survive economic crises
- build headquarters
- preserve corporate history
- appear in global rankings
- become a World Power
- leave a permanent legacy

The scale should grow naturally from the same original restoration loop.

---

# 53. Implementation quality gates

Every major feature must pass these gates before being called complete.

### Gate 1 — Simulation
Does it actually change game state?

### Gate 2 — Integration
Does another system respond to it?

### Gate 3 — Persistence
Does it survive save/load?

### Gate 4 — UI
Can the player understand and use it?

### Gate 5 — Balance
Does it create sensible economic consequences?

### Gate 6 — Testing
Is there automated coverage for important edge cases?

### Gate 7 — Fun
Does it create a meaningful decision or story?

If a feature fails these gates, mark it 🟡 rather than 🟢.

---

# 54. Immediate implementation queue

The next code work must follow this order:

**1. AUTHORITATIVE GAMESTATE**

→ unify persistent state

**2. EMPLOYEE INTEGRATION**

→ replace anonymous employee count with real people while retaining backward compatibility

**3. SAVE INTEGRATION**

→ employees, history, news and all existing empire state use one save boundary

**4. CORPORATE HISTORY**

→ permanent milestones generated from real actions

**5. RENEW DAILY**

→ news generated from history, market, rivals, people and opportunities

**6. PROPERTY/BUSINESS/BRANCH REFACTOR**

→ eliminate conceptual duplication

**7. DATA-DRIVEN BALANCE**

→ move hardcoded economic definitions into configuration

**8. 30–60 DAY BALANCE PASS**

→ playtest and tune the complete early loop

**9. DEEP RESOURCE/PRODUCTION ECONOMY**

→ extraction, processing, manufacturing, logistics and regional scarcity

**10. CORPORATE STRATEGY**

→ ownership, executives, acquisitions, finance and restructuring

Only after these are stable should the project proceed deeply into alliances, technology, global simulation, legacy, multiplayer and monetization.

---

# 55. Final principle

RENEW should not become a spreadsheet with a renovation theme.

It should be a living corporate world where:

**buildings have history, employees have lives, companies have personalities, markets have consequences, rivals remember, alliances matter, resources create power, crises create opportunities, and the player's decisions permanently shape the world.**

The implementation should always serve that experience.
