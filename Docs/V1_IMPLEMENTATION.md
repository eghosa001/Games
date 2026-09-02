# RENEW — Master Implementation Specification

> **Status:** Authoritative engineering specification
> **Scope:** Full RENEW simulation architecture, from current prototype through the long-term world simulation
> **Rule:** A system is not considered implemented because a file, variable, UI button, or stub exists. It is implemented only when its data model, simulation rules, persistence, UI integration, edge cases, and tests work together.

---

## 1. Product vision

RENEW is a restoration-to-empire business simulation.

The player's journey is:

**Discover → Inspect → Acquire → Restore → Operate → Hire → Produce → Sell → Reinvest → Secure resources → Expand → Compete → Negotiate → Form alliances → Acquire companies → Build infrastructure → Research technology → Influence the world → Create a legacy.**

The game must make the player care about both the **company** and the **people who built it**.

The simulation must create stories rather than simply award bonuses. A supplier shortage should affect factories. A successful employee should be promotable. A competitor should remember hostile behavior. An acquisition should change the workforce, debt, assets and relationships. A regional infrastructure project should alter logistics and economic power.

### Core design principles

1. **Simulation before decoration.** Systems must cause real economic consequences.
2. **Decisions have trade-offs.** Cheap, fast, safe and prestigious options should rarely all be optimal.
3. **The world remembers.** Important actions create persistent history and relationships.
4. **People matter.** Employees are not just a number used to calculate production.
5. **Companies are entities.** Property, business and branch must remain distinct concepts.
6. **Geography matters.** Resources, customers, labor and logistics differ by region.
7. **Events are causal.** World events alter underlying systems instead of only showing popups.
8. **Player agency matters.** Major outcomes should usually have choices or strategic responses.
9. **Data drives balance.** Costs and content should not be scattered through gameplay code.
10. **Persistence is authoritative.** One save model owns the simulation state.
11. **Mobile first.** Every important action must be usable on a phone.
12. **Build in layers.** Do not build multiplayer, monetization or advanced global systems on unstable foundations.

---

## 2. Canonical architecture

The long-term architecture is:

**RESTORATION → PROPERTY → BUSINESS → BRANCH → EMPLOYEES → ECONOMY → RESOURCES → PRODUCTION → SUPPLY CHAIN → CONTRACTS → COMPETITORS → OWNERSHIP → FINANCE → ACQUISITIONS → ALLIANCES → DIPLOMACY → INFRASTRUCTURE → TECHNOLOGY → WORLD EVENTS → RANKINGS → HEADQUARTERS → MUSEUM/LEGACY → LIVEOPS → MULTIPLAYER → GLOBAL ECONOMY**

The runtime should eventually be coordinated by a small simulation/application layer rather than a giant `main.gd`.

### Required system boundaries

| System | Responsibility | Must not own |
|---|---|---|
| GameState | authoritative persistent state | presentation logic |
| PropertySystem | physical assets and restoration | company accounting |
| BusinessSystem | companies and business identity | regional branch-only state |
| BranchSystem | regional operating units | ownership rules |
| EmployeeSystem | people, careers, morale and productivity | global market prices |
| EconomySystem | prices, demand and transactions | employee careers |
| ResourceSystem | extraction and resource availability | UI |
| ProductionSystem | recipes, inputs, output and quality | corporate ownership |
| SupplyChainSystem | movement, capacity and logistics | employee identity |
| ContractSystem | agreements and obligations | rendering |
| CompetitorSystem | rival decisions and memory | player UI |
| OwnershipSystem | shares, control and voting | production calculations |
| FinanceSystem | loans, capital, debt and solvency | restoration visuals |
| AllianceSystem | alliance membership, treasury and governance | individual company cash |
| InfrastructureSystem | physical regional infrastructure | company share ownership |
| TechnologySystem | research and technology unlocks | market event presentation |
| WorldEventSystem | causal world events and modifiers | save-file transport |
| HistorySystem | permanent milestones and records | temporary news feed |
| NewsSystem | contextual RENEW Daily stories | authoritative facts |
| ProgressionSystem | goals, unlocks and milestones | core economy calculations |
| AnalyticsSystem | telemetry | gameplay decisions |

`main.gd` is transitional orchestration code. New business rules should not be added there unless they are temporary glue awaiting extraction.

---

## 3. Definition of done

A feature is **DONE** only if all applicable items below exist:

- runtime data model
- creation and mutation rules
- integration with the simulation clock
- UI access where player-facing
- persistence
- migration handling
- deterministic behavior where required
- edge-case handling
- automated tests
- mobile usability
- history/news integration when the feature is important enough to create a story
- no duplicate source of truth

A feature marked as `Foundation` is not complete until these requirements are satisfied.

---

# PHASE A — FOUNDATION REPAIR

## 4. Authoritative GameState

### Current problem

The prototype has state distributed across `main.gd`, module objects, `save_system.gd`, `game_state_bridge.gd`, autosave and individual systems. This creates the possibility of divergent saves.

### Target

Create one authoritative state tree.

Recommended top-level structure:

```text
GameState
├── schema_version
├── meta
├── clock
├── player
├── company
├── properties
├── businesses
├── branches
├── employees
├── economy
├── resources
├── production
├── supply_chain
├── contracts
├── competitors
├── ownership
├── finance
├── alliances
├── diplomacy
├── regions
├── infrastructure
├── technology
├── events
├── progression
├── history
├── news
└── analytics
```

### Rules

- Runtime systems may cache calculated values.
- Persistent truth belongs in GameState.
- A cache must be rebuildable from GameState.
- UI must read through system APIs or state snapshots.
- No second save file may contain overlapping authoritative data.

### Migration

Every schema change increments `schema_version`.

Migrations must be explicit:

`V1 → V2 → V3 → ... → CURRENT`

Never silently discard unknown fields during migration.

---

## 5. Persistence consolidation

### Required save pipeline

`GameState → serialize → validate → temporary file → flush → backup previous save → replace active save`

### Required recovery order

1. active save
2. backup save
3. safe new-game state

### Save requirements

- atomic write
- backup
- schema version
- corruption detection
- migration
- explicit load result
- save timestamp
- last successful day
- recovery logging

### Remove duplication

`game_state_bridge.gd` must not remain a second independent persistence authority. Its useful branch/region/supply snapshots must be moved into the canonical save pipeline and the duplicate file eventually removed.

Autosave and manual save must call the same save service.

---

## 6. Replace `main.gd` god-object architecture

Refactor gradually. Do not rewrite the entire game in one risky change.

### Extraction order

1. EmployeeSystem
2. HistorySystem
3. NewsSystem
4. FinanceSystem
5. PropertySystem
6. BusinessSystem
7. SimulationClock
8. PlayerCommandService
9. WorldEventSystem
10. remaining economy/strategy modules

`main.gd` should eventually do approximately:

```text
initialize systems
load state
receive player commands
advance simulation
request UI refresh
save state
```

It should not contain hundreds of individual economic rules.

---

# PHASE B — PLAYER ATTACHMENT

## 7. EmployeeSystem — complete implementation

The current integer employee count is only a foundation.

### Employee record

Each employee requires:

- `id`
- `name`
- `role`
- `skill`
- `experience`
- `career_level`
- `salary`
- `loyalty`
- `morale`
- `ambition`
- `personality`
- `productivity`
- `specialization`
- `assignment_type`
- `assignment_id`
- `hire_day`
- `promotion_day`
- `status`
- `relationship_ids`
- `history_ids`

### Roles

Initial roles:

- Worker
- Technician
- Sales
- Logistics
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

### Productivity model

Base productivity should be affected by:

`skill × experience × morale × suitability × equipment × management × fatigue`

Clamp values to safe ranges. A bad employee should not produce negative output.

### Morale

Morale changes from:

- salary fairness
- workload
- successful company performance
- promotion
- recognition
- poor management
- layoffs
- missed wages
- unsafe conditions
- company reputation
- peer relationships

### Loyalty

Loyalty changes over time and from treatment. High loyalty reduces poaching risk; low loyalty increases resignation/competitor recruitment risk.

### Hiring

Hiring must create a real persistent employee record, not only increment an integer.

Candidate generation should consider:

- role
- skill
- wage expectation
- personality
- experience
- ambition
- regional labor pool

### Firing

Firing must:

- remove assignment
- create history/news where appropriate
- affect morale of remaining staff
- affect company reputation when mass or unfair
- release salary cost

### Promotion

Promotion changes:

- role
- salary
- productivity
- management capacity
- morale
- career level

### Training

Training consumes money/time but increases selected skills.

### Competitor poaching

A competitor can target valuable employees based on skill, loyalty, salary and relationship. The player can counter with raises, promotion, bonuses or culture improvements.

### Compatibility

Employee relationships should be introduced after the basic employee model is stable. They should affect teams and morale, not become a disconnected social mini-game.

---

## 8. Company culture

Introduce a company culture profile rather than a single morale number.

Possible dimensions:

- innovation
- discipline
- employee welfare
- risk tolerance
- quality
- growth ambition
- environmental responsibility

Culture is shaped by player decisions and leadership.

Culture should affect recruitment, retention, productivity, reputation and executive behavior.

---

## 9. Corporate History

History is permanent and separate from the recent activity log.

### History record

```text
id
company_id
day
type
title
description
importance
related_entity_ids
```

### History types

- founding
- restoration
- first sale
- first profit
- employee milestone
- contract
- property acquisition
- expansion
- resource acquisition
- alliance
- acquisition
- merger
- crisis
- bankruptcy
- technology
- infrastructure
- ranking
- world event

### Importance levels

`minor → notable → major → historic`

Historic entries should remain visible years later and feed the museum/legacy system.

---

## 10. RENEW Daily

RENEW Daily is the company's personalized newspaper, not a random text generator.

### Sections

1. Your Company
2. People
3. Market
4. Rivals
5. Supply Chain
6. Contracts
7. Opportunities
8. Regions
9. World
10. Corporate History

### Generation rules

News is generated from actual state changes and event records.

Example pipeline:

`Simulation event → event payload → NewsSystem → relevance scoring → article → Daily edition`

### Relevance

Important events should be prioritized by:

- direct player impact
- financial impact
- strategic importance
- employee importance
- relationship importance
- proximity to player operations

Do not generate contradictory articles from stale state.

---

# PHASE C — MAKE THE CORE LOOP FUN

## 11. Restoration system

### Current loop

**Inspect → Acquire → Clean → Repair → Rebuild → Install → Design → Operate**

### Complete implementation

Every restoration project needs:

- property identity
- condition
- inspection result
- estimated cost
- actual cost
- required materials
- labor requirement
- project duration
- quality outcome
- risks
- optional upgrades
- visual stage
- history

### Restoration choices

Allow meaningful choices such as:

- cheap repair
- balanced repair
- premium restoration
- preserve historical character
- modernize
- repurpose

Choices must produce different downstream consequences.

### Special properties

Some properties should contain unique stories, rare opportunities or restoration chains. These should be generated as special content, not required for the normal economy loop.

---

## 12. Property / Business / Branch separation

### Property

A physical asset:

- location
- condition
- capacity
- physical upgrades
- history
- ownership

### Business

A company:

- identity
- cash
- debt
- employees
- ownership
- strategy
- reputation
- products

### Branch

A regional operating unit of a business:

- region
- employees
- local stock
- local demand
- local pricing
- local logistics
- branch performance

A business may own multiple properties and operate multiple branches.

Do not represent all three with one dictionary.

---

## 13. Core balance pass

Before advanced features, manually play at least 30, 60, 180 and 365 in-game days.

Measure:

- restoration payback
- production margins
- employee wage burden
- supplier costs
- fuel costs
- transport costs
- marketing return
- loan burden
- expansion payback
- competitor pressure
- bankruptcy risk

The early game must contain meaningful decisions without requiring excessive grinding.

The player should normally have multiple viable strategies:

- premium quality
- low-cost volume
- resource control
- logistics advantage
- contract specialization
- aggressive expansion
- regional dominance

---

# PHASE D — DEEP ECONOMY

## 14. Data-driven economy

Create structured content/configuration for:

- resources
- materials
- products
- recipes
- wages
- property types
- restoration stages
- upgrades
- transport
- contracts
- competitors
- regions
- events
- technologies

Gameplay systems consume these definitions rather than embedding balance constants.

### Product definition

Each product should support:

- inputs
- packaging
- fuel/energy
- labor
- machinery requirement
- recipe time
- base quality
- base price
- demand category
- region modifiers
- technology requirements

---

## 15. Production system

Target chain:

**Extraction → Processing → Manufacturing → Distribution → Retail → Customer**

### Production concepts

- recipes
- intermediate goods
- machines
- factories
- capacity
- utilization
- quality
- waste
- maintenance
- automation
- technology

### Quality

Quality should influence:

- sale price
- demand
- reputation
- contract eligibility
- customer retention

### Efficiency

Efficiency should improve through:

- employee skill
- machinery
- training
- technology
- maintenance
- process upgrades

---

## 16. Resource economy

Resources should be geographically differentiated.

Initial resource families:

- timber
- stone
- iron
- fuel
- agricultural goods
- energy

Later:

- steel
- chemicals
- electronics
- machinery
- advanced materials

### Scarcity

Scarcity can result from:

- extraction limits
- regional demand
- disruptions
- competitor control
- infrastructure capacity
- weather/events
- long-term depletion where appropriate

Resource scarcity must propagate into prices and production rather than only display a warning.

---

## 17. Supply chain

Target physical chain:

**Source → Extraction → Transport → Processing → Manufacturing → Warehouse → Distribution → Retail**

Every link can have:

- capacity
- cost
- delay
- reliability
- disruption risk
- ownership/control

Transport upgrades should have measurable economic consequences.

---

## 18. Contracts

Create a reusable contract model.

Required fields:

- contract ID
- parties
- start/end day
- resource/product
- quantity
- unit price
- quality requirement
- delivery schedule
- destination
- penalty
- cancellation rule
- renewal rule
- reputation impact
- status

Contract execution must be checked by the simulation, not manually assumed.

Failure can reduce cash, reputation and future opportunities.

---

# PHASE E — CORPORATE STRATEGY

## 19. Competitor AI

Current rivals are a foundation. Move from scripted reactions toward persistent strategic agents.

Each competitor needs:

- identity
- personality
- cash
- debt
- assets
- businesses
- employees
- technology
- regional presence
- supplier relationships
- customer relationships
- risk tolerance
- strategic priorities
- memory

### Memory

Record significant player actions:

- price wars
- contract betrayal
- supplier interference
- acquisitions
- cooperation
- alliance support
- territory competition

Memory affects future decisions.

### Decision loop

`Observe → Evaluate → Select strategy → Execute → Record result → Update memory`

Competitors should sometimes make imperfect decisions so the world feels alive rather than mathematically omniscient.

---

## 20. Ownership and control

Implement true share ownership.

Example:

`Founder 42% | Investor A 21% | Investor B 17% | Treasury 20%`

Required:

- share issuance
- dilution
- transfers
- buybacks
- voting
- board seats
- control thresholds
- dividends
- investor confidence
- takeover defense

Control should not simply equal the largest percentage in every case. Board structure, voting classes and agreements can affect effective control later.

---

## 21. Finance

Expand current loans into a corporate finance model.

### Instruments

- loans
- secured loans
- refinancing
- investment
- bonds
- equity
- buybacks

### Financial metrics

- revenue
- operating profit
- net profit
- cash flow
- assets
- liabilities
- debt service
- valuation
- leverage
- credit rating

### Credit rating

Rating should depend on:

- repayment history
- leverage
- cash flow
- profitability
- collateral
- company stability

Credit rating changes financing costs and available capital.

---

## 22. Acquisitions

Acquisition paths:

1. direct asset purchase
2. negotiated company sale
3. competitive auction
4. hostile acquisition
5. shareholder accumulation
6. merger

### Due diligence

Before acquisition, the player should be able to discover some combination of:

- assets
- debt
- employees
- contracts
- liabilities
- reputation
- hidden risks

Acquisition price must not be the only consequence.

---

## 23. Bankruptcy and restructuring

Bankruptcy is a strategic state, not a game-over popup.

Possible recovery path:

**Cash crisis → covenant pressure → restructuring → asset sales → investment → downsizing → refinancing → recovery**

If recovery fails:

**insolvency → administration → liquidation or acquisition**

Allow the player to lose assets and control while still giving the company a possible comeback story where appropriate.

---

# PHASE F — SOCIAL STRATEGY

## 24. Alliances 2.0

An alliance is an organization with its own persistent state.

### Alliance state

- members
- treasury
- assets
- infrastructure
- technologies
- research projects
- reputation
- trust
- governance
- treaties
- contribution records

### Contributions

Members can contribute:

- cash
- resources
- technology
- employees/labor
- infrastructure

Contributions should be recorded and visible.

---

## 25. Alliance governance

Roles:

- Founder
- Chairman
- Director
- Regional Leader
- Member

Voting should support:

- leadership
- expansion
- treasury spending
- shared infrastructure
- research
- new members
- sanctions
- treaty decisions

Alliance power must not automatically equal player power.

---

## 26. Diplomacy and treaties

Treaty types:

- trade
- supply
- research
- defense
- non-aggression
- investment
- territory
- infrastructure
- joint venture

Every treaty needs:

- parties
- terms
- duration
- obligations
- benefits
- penalties
- cancellation rules
- trust impact

Breaking treaties should affect diplomatic reputation.

---

## 27. Joint ventures

A joint venture creates a shared project/entity.

Example:

`Port project: $500M`

`Company A 40%`
`Company B 35%`
`Company C 25%`

Store:

- contributions
- ownership
- voting
- debt
- income
- expenses
- management
- exit terms

The JV must remain distinct from the parent companies.

---

## 28. Mergers

A merger combines companies while resolving:

- ownership
- valuation
- debt
- employees
- management
- properties
- branches
- contracts
- brands
- technology
- reputation

Allow negotiated merger terms rather than always creating a simple sum of assets.

---

# PHASE G — WORLD SIMULATION

## 29. Regions

Regions must have distinct economic identities.

Required dimensions:

- population/demand
- labor supply
- wage level
- logistics
- resources
- industry specialization
- growth
- competition
- infrastructure
- local reputation
- market size

The same business should perform differently in different regions.

---

## 30. Physical infrastructure

Infrastructure assets:

- roads
- railways
- ports
- airports
- power plants
- warehouses
- industrial zones
- technology parks

Infrastructure should have:

- construction cost
- capacity
- maintenance
- ownership
- utilization
- location
- upgrade levels
- disruption state

Infrastructure must alter actual logistics and economic capacity.

---

## 31. Technology tree

### Manufacturing

Automation → Robotics → Smart Factories → Advanced Manufacturing

### Logistics

GPS → Optimization → Autonomous Delivery → Global Logistics

### Energy

Efficient Generation → Renewable → Storage → Advanced Energy

### Computing

Computing → AI → Advanced Computing → Next Generation

### Construction

Modern Materials → Modular Construction → Smart Buildings → Mega Infrastructure

Each technology must unlock gameplay, not merely increase a number.

Examples:

- new recipe
- lower production time
- new factory type
- new logistics option
- new infrastructure
- better quality
- new contract eligibility

---

## 32. Research

Research sources:

- company R&D
- employees
- universities
- alliances
- partnerships
- joint research
- discoveries

Research projects require:

- cost
- duration
- required skills
- facility
- uncertainty
- outcome

Rare discoveries should create unique strategic advantages without permanently breaking balance.

---

## 33. Unified WorldEventSystem

Merge the old event architectures into one event pipeline.

### Event structure

```text
id
category
start_day
duration
scope
causes
effects
choices
follow_up_events
resolution
```

### Example

**Energy Crisis**

→ energy price rises

→ factory costs rise

→ weak factories reduce output

→ some competitors struggle

→ alternative energy demand rises

→ investment opportunities appear

→ research becomes valuable

→ crisis resolves or evolves

Events must modify actual systems.

---

## 34. World event categories

Initial categories:

- economic boom
- recession
- energy crisis
- resource shortage
- construction boom
- supplier disruption
- transport disruption
- labor shortage
- technology breakthrough
- regional disaster
- major contract
- competitor crisis
- political/regulatory change
- environmental event

Events can have multiple stages and conditional outcomes.

---

# PHASE H — POWER, RANKINGS AND LEGACY

## 35. Global rankings

Rank companies using multiple dimensions rather than cash alone.

Possible scores:

- valuation
- revenue
- profit
- assets
- market share
- employees
- technology
- infrastructure
- regional presence
- reputation
- resource control
- alliance influence

Publish:

- daily/weekly snapshots
- historical ranking
- category rankings
- regional rankings

---

## 36. World Power

World Power is a composite influence system.

Components can include:

- economic power
- resource power
- industrial power
- technological power
- logistics power
- diplomatic power
- alliance power
- cultural/reputation power

World Power should be explainable: the player must know why their score changed.

---

## 37. Headquarters

HQ is a physical representation of corporate growth.

Progression:

**Small Office → Headquarters → Corporate Center → Regional HQ → Global Headquarters**

HQ can contain:

- executive offices
- meeting rooms
- research facilities
- training center
- archives
- museum
- board room
- technology center

HQ should be functional, not just cosmetic.

---

## 38. Corporate Museum

The museum presents the company's permanent story.

Display:

- first property
- restoration milestones
- first product
- historic employees
- major contracts
- major acquisitions
- failed projects
- awards
- rankings
- technologies
- alliance milestones
- crisis recoveries

The museum is driven from Corporate History and must survive saves.

---

## 39. Collections

Collections are optional long-term objectives.

Examples:

- historic properties
- rare machinery
- landmark businesses
- unique technologies
- special contracts
- famous employees
- world-event artifacts

Collections should reward exploration without becoming mandatory grinding.

---

# PHASE I — LIVE WORLD AND COMMERCIAL SYSTEMS

## 40. Multiplayer economy

Do not build direct multiplayer before the single-player simulation is stable.

Foundation requirements:

- authoritative server state
- player/company identity
- synchronized market state
- secure transactions
- contract validation
- anti-cheat validation
- conflict resolution

Player-to-player systems can later include:

- trade
- contracts
- investment
- alliances
- joint ventures
- acquisitions
- competition

Never trust client-supplied cash, ownership or transaction outcomes.

---

## 41. Analytics

Telemetry should measure gameplay health without becoming a gameplay dependency.

Useful events:

- new game
- inspection
- acquisition
- restoration stage
- business opened
- employee hired
- employee promoted
- product produced
- sale completed
- contract signed
- expansion purchased
- loan taken
- acquisition completed
- alliance joined
- technology researched
- bankruptcy/recovery
- session end

Track funnel metrics such as:

`New Game → First Restoration → First Business → First Profit → First Expansion → First Major Strategic Decision`

Analytics must not contain sensitive personal information.

---

## 42. LiveOps

LiveOps is built after the core simulation is reliable.

Use content definitions for:

- seasonal events
- limited opportunities
- rotating contracts
- world crises
- challenges
- rankings
- community goals

LiveOps content must use the same WorldEventSystem rather than creating a parallel simulation.

---

## 43. Monetization

Monetization comes after the game is fun without payment.

Rules:

- never sell mandatory progression
- never create pay-to-win economic dominance
- never hide core simulation behind excessive friction
- purchases must be clearly understood
- economy must remain balanced with monetization disabled

Possible later models:

- cosmetic HQ items
- cosmetic restoration themes
- optional expansion/content packs
- convenience that does not distort competition

---

# PHASE J — MOBILE EXPERIENCE

## 44. Mobile UI requirements

Every major system needs a compact mobile representation.

Required primary navigation:

- Home
- Property
- Business
- People
- Market
- Supply
- Regions
- Rivals
- Corporate
- News

### Interaction rules

- large touch targets
- scrollable action panels
- concise financial summaries
- confirmation for irreversible actions
- visible feedback after actions
- no critical action dependent on hover
- important alerts accessible from the home screen

### Information hierarchy

Show:

`Cash → Daily Profit/Loss → Key Risk → Main Opportunity → Next Decision`

before secondary details.

---

# PHASE K — TESTING AND QUALITY

## 45. Automated test layers

### Unit tests

Test individual systems:

- employee calculations
- production recipes
- prices
- contracts
- loans
- ownership
- event effects
- migrations

### Integration tests

Test:

- restoration to business
- hiring to production
- resource shortage to price/output
- acquisition to employee/property transfer
- alliance to shared benefit
- event to economy
- save to load

### Regression tests

Every previously fixed bug should gain a regression test where practical.

### Soak tests

Run:

- 30-day
- 365-day
- 1,000-day
- long-run multi-company simulations

Check for:

- NaN
- negative impossible quantities
- runaway cash
- runaway prices
- duplicated employees
- orphaned properties
- broken ownership totals
- memory growth
- save corruption

### Manual playtests

Automated tests cannot determine whether the game is fun.

Perform repeated fresh-start sessions and record:

- where the player becomes confused
- where decisions feel meaningless
- where progression stalls
- where the player becomes excited
- which systems create memorable stories

---

## 46. Invariants

The simulation must enforce invariants such as:

- cash is finite
- stock cannot be below zero
- ownership percentages have valid bounds
- employee IDs are unique
- property IDs are unique
- business IDs are unique
- branch references point to existing businesses
- contracts reference valid parties
- debt cannot become NaN
- production cannot consume nonexistent inputs
- alliance contributions cannot exceed available member resources
- deleted entities cannot remain as live references

Validation should run during development and save/load.

---

# PHASE L — IMPLEMENTATION ORDER

## 47. Exact execution order

### Sprint 1 — Foundation

1. finalize GameState schema
2. remove duplicate persistence authority
3. centralize save/load
4. add migration tests
5. establish system interfaces

### Sprint 2 — People

6. EmployeeSystem
7. employee generation
8. hiring/firing
9. wages
10. productivity
11. morale/loyalty
12. promotion/training
13. save/load employees

### Sprint 3 — Story

14. HistorySystem
15. milestone generation
16. NewsSystem
17. RENEW Daily UI
18. employee/company news integration

### Sprint 4 — Core economy

19. data-driven definitions
20. production recipes
21. resource scarcity
22. transport chain
23. contract execution
24. balance pass

### Sprint 5 — Corporate strategy

25. competitor memory
26. ownership/shareholders
27. FinanceSystem
28. acquisitions
29. restructuring/bankruptcy

### Sprint 6 — Social strategy

30. AllianceSystem
31. alliance treasury
32. governance
33. diplomacy
34. joint ventures
35. mergers

### Sprint 7 — World

36. regional specialization
37. physical infrastructure
38. technology tree
39. research
40. unified WorldEventSystem

### Sprint 8 — Legacy

41. rankings
42. World Power
43. HQ progression
44. museum
45. collections

### Sprint 9 — Commercial/live

46. analytics
47. LiveOps
48. multiplayer foundation
49. monetization
50. production hardening

This order is intentional. Do not jump to Sprint 8 or 9 because a feature sounds exciting while foundational systems are incomplete.

---

# 48. Current prototype-to-target mapping

| Existing foundation | Required evolution |
|---|---|
| `main.gd` | coordinator, progressively decomposed |
| `economy.gd` | data-driven EconomySystem |
| `production.gd` | recipe/intermediate-goods ProductionSystem |
| `expansion.gd` | Property/Business/Branch separation |
| `competitors.gd` | persistent strategic AI |
| `supply_chain.gd` | complete physical supply network |
| `supply_contracts.gd` | generalized ContractSystem |
| `market_director.gd` + `events.gd` | unified WorldEventSystem |
| `districts.gd` | regional specialization layer |
| `regions.gd` | full RegionalEconomy |
| `region_controller.gd` | InfrastructureSystem + region orchestration |
| `branches.gd` | BranchSystem |
| `corporate.gd` | Ownership/Finance/Control systems |
| `save_system.gd` | authoritative persistence service |
| `game_state_bridge.gd` | migrate useful state, then remove duplicate authority |
| activity log | short-term operational log only |
| employee count | EmployeeSystem roster |
| progression | goals/unlocks, not simulation state |

Do not delete useful existing foundations simply because they need expansion. Refactor them behind the new boundaries.

---

# 49. Backward compatibility rules

Existing saves must not become unusable merely because a system becomes deeper.

Examples:

### Old employee count

If an old save contains `employees: 3`, migration creates three generated employee records with sensible starter attributes.

### Old branches

Old branch dictionaries are migrated into BranchSystem records.

### Old rivals

Existing rival state is preserved and extended with new memory/personality fields.

### Old events

Existing event modifiers are converted into WorldEventSystem effects where possible.

Migration must be deterministic: loading the same old save twice must produce the same state.

---

# 50. Error handling

Player-facing failures must be explicit.

Examples:

- insufficient cash
- insufficient stock
- missing employee skill
- unavailable property
- invalid contract
- insufficient alliance approval
- failed financing
- unavailable technology
- blocked route

Never silently change state when an operation fails.

Use structured result objects where practical:

```text
success
reason_code
message
changed_entities
financial_delta
history_event
news_event
```

---

# 51. Simulation clock

Create one simulation clock authority.

The clock controls:

- daily wages
- production cycles
- sales
- contracts
- loan payments
- employee progression
- competitor decisions
- resource extraction
- infrastructure maintenance
- event progression
- research
- news generation
- autosave

Do not let multiple systems independently advance the day.

---

# 52. Transaction architecture

Economic actions should use explicit transactions where money/resources change hands.

Examples:

- purchase property
- buy resource
- sell product
- pay wages
- pay loan
- sign contract
- acquire company
- alliance contribution

A transaction should record:

- day
- actor
- counterparty
- amount
- currency
- resource/product
- reason
- resulting state

This improves debugging, history and analytics.

---

# 53. Economy safety limits

The economy must prevent runaway values.

Use:

- bounded modifiers
- minimum/maximum sensible prices
- production capacity limits
- finite resource availability where intended
- debt constraints
- event expiration
- compounding safeguards

Do not use arbitrary clamps to hide broken simulation logic. When a value hits a safety bound during development, log the cause and investigate it.

---

# 54. Save-state ownership matrix

| Data | Owner |
|---|---|
| day | SimulationClock/GameState |
| cash | Finance/GameState |
| employees | EmployeeSystem/GameState |
| properties | PropertySystem/GameState |
| businesses | BusinessSystem/GameState |
| branches | BranchSystem/GameState |
| stock | Resource/Business state |
| contracts | ContractSystem/GameState |
| rivals | CompetitorSystem/GameState |
| shares | OwnershipSystem/GameState |
| loans | FinanceSystem/GameState |
| alliances | AllianceSystem/GameState |
| regions | RegionSystem/GameState |
| infrastructure | InfrastructureSystem/GameState |
| technology | TechnologySystem/GameState |
| history | HistorySystem/GameState |
| news archive | NewsSystem/GameState |
| event state | WorldEventSystem/GameState |

No other module may silently persist an overlapping copy.

---

# 55. Performance requirements

The game must remain responsive on mobile.

Avoid recalculating the entire world every frame.

Use:

- daily simulation ticks
- event-driven updates
- cached derived values
- batched competitor decisions
- lazy UI refresh
- bounded history/news retention for short-lived feeds

Permanent corporate history may grow, but should use compact records.

Large future worlds should support simulation tiers so distant entities can be simulated at lower detail when appropriate.

---

# 56. Security requirements for future multiplayer

When multiplayer is introduced:

- server owns authoritative money
- server owns ownership
- server validates contracts
- server validates inventory
- server validates production
- clients send intents, not final outcomes
- all economic mutations are audited
- rate limits prevent transaction abuse

Single-player code should be written with this separation in mind where it does not add unnecessary complexity.

---

# 57. What must NOT happen

Do not:

- add another save file for a new system
- add another event manager beside WorldEventSystem
- represent employees only as an integer after EmployeeSystem is integrated
- put new business logic into `main.gd` simply because it is convenient
- make technology a collection of isolated percentage bonuses
- make alliances a renamed relationship score
- make acquisitions only subtract cash and add an asset
- make world events only display text
- make rankings only sort by cash
- make news random when the story can be derived from state
- add multiplayer before single-player economy stability
- add monetization before the core loop is enjoyable
- mark a foundation as complete because its API exists

---

# 58. V1.1 completion gate

V1.1 is complete only when:

- [ ] employee count has been replaced by persistent employee records
- [ ] employees affect wages and productivity
- [ ] employees can be hired and fired
- [ ] employees gain experience
- [ ] morale and loyalty affect outcomes
- [ ] promotions work
- [ ] employees persist through save/load
- [ ] corporate history is permanent
- [ ] major milestones create history entries
- [ ] RENEW Daily is generated from real state changes
- [ ] GameState is the authoritative save boundary
- [ ] duplicate persistence is removed
- [ ] old saves migrate correctly
- [ ] restoration/business flow remains functional
- [ ] 30/60/180/365-day playtests are balanced
- [ ] automated regression suite passes
- [ ] Android/mobile interaction has been manually tested

---

# 59. V2 completion gate

V2 requires, in addition to V1.1:

- [ ] deeper production chain
- [ ] resource scarcity
- [ ] meaningful regional specialization
- [ ] persistent competitor memory
- [ ] real ownership/control
- [ ] expanded finance
- [ ] acquisitions with consequences
- [ ] alliances with treasury/governance
- [ ] diplomacy/treaties
- [ ] joint ventures
- [ ] mergers
- [ ] bankruptcy/restructuring
- [ ] physical infrastructure
- [ ] technology tree
- [ ] research
- [ ] causal world events
- [ ] global rankings
- [ ] World Power
- [ ] headquarters progression
- [ ] corporate museum
- [ ] collections

---

# 60. Commercial-quality gate

RENEW is ready for serious commercial/live development only when a fresh player can:

1. understand the first restoration without external instructions;
2. experience a satisfying restoration transformation;
3. open a business and understand its economics;
4. care about at least one employee or company relationship;
5. encounter a meaningful strategic problem;
6. make a decision with a real trade-off;
7. see the world react to that decision;
8. return later and discover that the company has changed;
9. understand why they succeeded or failed;
10. want to continue because a future goal is personally meaningful.

The game must generate memorable stories such as:

> “James joined me when I had almost nothing. He became my first manager, helped survive the energy crisis, and eventually ran the branch I built in the north.”

That type of story is a core product outcome, not optional flavor.

---

# 61. Immediate implementation queue

The next code work must be executed in this exact order unless a blocking defect requires otherwise:

### A. Foundation

1. Audit current GameState implementation against this specification.
2. Integrate every currently authoritative scalar into GameState.
3. Move employees into EmployeeSystem.
4. Remove duplicate extended-save authority.
5. Add migration tests.

### B. Player attachment

6. Integrate employee hiring/firing into gameplay.
7. Replace wage calculation with employee records.
8. Replace production staffing calculation with employee productivity.
9. Add morale/loyalty/experience progression.
10. Add corporate history events.
11. Add RENEW Daily generation from actual events.

### C. Core economy

12. Extract balance definitions.
13. Complete production recipes.
14. Complete resource/transport chain.
15. Complete contract execution.
16. Run balance playtests.

### D. Strategy

17. Competitor memory.
18. Ownership/control.
19. Finance expansion.
20. Acquisition consequences.

Only after these are stable should the implementation move into advanced alliances, infrastructure, technology and world-power systems.

---

# 62. Engineering rule for every future prompt

When asked to “continue implementation,” inspect the actual repository first and continue from the current committed state.

Do not assume that a checklist item is implemented because:

- a file exists;
- a variable exists;
- a button exists;
- a function is named correctly;
- a README says it is complete;
- a system returns placeholder data.

For every claimed completion, verify:

**Code → Integration → Persistence → UI → Simulation behavior → Tests.**

If any layer is missing, report the feature as a foundation and continue implementing it.

---

# 63. Final architectural objective

The finished RENEW simulation should behave as one connected world:

**A player restores a property.**

That creates a business.

The business hires people.

Those people improve or struggle.

The business needs resources.

Resources come from regions and supply chains.

Production turns resources into goods.

Customers and contracts create revenue.

Competitors respond.

The player expands.

Expansion changes regional economics.

Ownership creates investors and control problems.

Finance enables growth but creates risk.

Acquisitions reshape companies and careers.

Alliances create shared power.

Infrastructure changes geography.

Technology changes what companies can produce.

World events disrupt and create opportunities.

Rankings measure the resulting power.

The headquarters and museum preserve the story.

The company becomes more than a collection of numbers: **it becomes a history the player created.**

That is the standard this implementation must ultimately meet.
