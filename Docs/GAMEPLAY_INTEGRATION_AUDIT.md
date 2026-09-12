# RENEW Gameplay Integration Audit

**Audit basis:** `Docs/V1_IMPLEMENTATION.md`, `Docs/SYSTEM_OWNERSHIP.md`, current `main`, feature tests, release tests, long-running tests, and the Android/mobile gameplay work.

## Audit rule

A system is not treated as complete because a script, UI panel, button, state field, or test name exists. A gameplay domain is considered integrated only when it has authoritative state, real mutation rules, causal consumers/producers, persistence where applicable, player access where applicable, edge-case handling, and behavioral tests.

The intended journey is:

**Discover → Inspect → Acquire → Restore → Operate → Hire → Produce → Sell → Reinvest → Secure resources → Expand → Compete → Negotiate → Form alliances → Acquire companies → Build infrastructure → Research technology → Influence the world → Create a legacy.**

---

## 1. Core journey — causally integrated

### Property and restoration

- Inspection, acquisition and restoration are real commands against the authoritative property state.
- Restoration must reach an operational state before the normal business path proceeds.
- The release flow and player-journey tests now use real commands rather than directly injecting `owned`, `restoration`, or `Operational` state.
- Property ownership/restoration survives persistence.

**Status: integrated.**

### Business identity

- Restored property becomes a business through the BusinessSystem.
- Industry selection drives active product/production behavior.
- Property and business remain separate state domains.

**Status: integrated.**

### Employees and company culture

- Hiring creates persistent employee records rather than only incrementing an integer.
- Employee experience, morale/productivity and wages participate in daily simulation.
- Company culture is not cosmetic: its effects are consumed by employee behavior, research/technology and demand/quality paths.

**Status: integrated.**

### Resources, scarcity, production and supply chain

- Procurement feeds warehouse/input state.
- Production consumes real inputs and creates real inventory.
- Sales and contracts consume warehouse inventory rather than generating revenue from an unrelated number.
- Supply-chain/logistics modifiers are affected by infrastructure and technology.
- Scarcity/world modifiers can propagate into costs/output/demand.

**Status: integrated.**

### Demand, customers and selling

The daily demand calculation consumes multiple independent systems, including:

- player price
- competitor price
- reputation
- product quality
- marketing
- contract/customer effects
- employee productivity
- district/region effects
- competitor pressure
- alliance/deal effects
- technology
- culture
- world-event modifiers

Sales are bounded by actual available inventory.

**Status: integrated.**

### Contracts

- Contracts are simulation obligations rather than manual revenue buttons.
- Delivery consumes inventory.
- Contract income/penalties enter daily finance settlement.
- Contract state participates in progression and persistence.

**Status: integrated.**

### Finance and debt

- FinanceSystem is the authoritative cash/debt ledger.
- Operating sales, wages, overhead, contracts, loans/debt service and major strategic transactions pass through the ledger.
- Failed compound operations increasingly use capture/rollback so state cannot partially mutate while payment fails.

**Status: integrated, with transaction regressions retained as a permanent release requirement.**

### Competition

- Rival price/pressure affects demand.
- Competitors update every operating day and have strategic/reaction paths.
- Rival ownership/share paths can create dividends and strategic leverage.

**Status: integrated at the current playable layer.**

### Progression, history and news

- Meaningful gameplay events award progression rather than passive time alone.
- History records persistent company events.
- News is derived from verified state/events instead of being an unrelated random-text feed.
- Mobile guidance uses progression to expose more complex strategy progressively.

**Status: integrated.**

---

## 2. Expansion layer — integrated, with recent audit repairs

### Regions and regional operations

- Regions alter demand, labor/wages, logistics, competition, growth, infrastructure and local reputation.
- Establishing regional operations, infrastructure upgrades, freight and trade corridors settle through authoritative finance with rollback on failed payment.
- Regional charter costs are now charged by the authoritative regional system rather than duplicated by the controller.

**Status: integrated.**

### Branches

- Regional branches require regional presence.
- Launch, staffing, stocking and upgrades have economic costs.
- Stock shipments consume core inventory and freight cash.
- Daily branch profit/loss settles against FinanceSystem and rolls back branch mutation if settlement fails.

**Status: integrated.**

### Physical infrastructure

The audit found and fixed a serious integration defect: construction, upgrade and repair previously checked affordability but did not reliably debit authoritative finance.

Current behavior:

- construction charges FinanceSystem
- upgrades charge FinanceSystem
- repairs charge FinanceSystem
- maintenance charges FinanceSystem
- infrastructure ownership is registered
- active assets alter logistics/production/energy/storage/technology modifiers
- supply-chain/domain consumers read those modifiers

**Status: integrated after audit repair.**

### Headquarters

The audit connected HQ strategic capacity to downstream systems rather than leaving HQ as a presentation/endgame surface only.

- HQ research capacity affects R&D duration.
- HQ technology capacity affects research/technology capability.
- HQ remains a long-term progression layer but now has measurable strategic consequences.

**Status: causally integrated for the implemented HQ capabilities.**

---

## 3. Corporate strategy — behavioral systems present and tested

### Ownership

- Shares, holders/control and strategic ownership are represented by the authoritative OwnershipSystem.
- Share/dividend/control paths participate in finance/strategy.

**Status: implemented and behavior-tested.**

### Acquisitions and mergers

- Acquisition targets contain assets, debt, employees, contracts, liabilities, reputation and hidden risk.
- Due diligence exposes strategic information.
- Company acquisitions can transfer more than price alone.
- Mergers resolve ownership, debt, employees, management, properties, branches, contracts, brands, technology, reputation and assets.
- The audit made acquisition/share settlements atomic so failed multi-system operations roll back rather than leaving partial state.

**Status: implemented and behavior-tested; retain atomicity tests as mandatory.**

### Alliances, diplomacy and joint ventures

- Dedicated systems and behavioral tests exist for alliance, diplomacy and joint-venture layers.
- These are intentionally above the minimum V1 core and should not be allowed to destabilize V1.

**Status: advanced systems implemented/tested, but not a dependency of the early-game core.**

### Bankruptcy/restructuring and endgame

- Bankruptcy, victory, corporate-war, crisis, prestige and power systems have dedicated tests in the repository.
- These are late-game systems and must continue to be validated independently from the early-game release loop.

**Status: implemented/tested as advanced layers; full human playthrough quality still requires device/playtest validation.**

---

## 4. Technology, research and world simulation

### Technology/research

- Technology has gameplay consumers in production/business, supply chain and market demand.
- Company culture and HQ capability can influence research.
- Dedicated technology tests are present.

**Status: causally integrated.**

### World events

- World events contain real effects/choices/follow-ups.
- Daily simulation consumes event modifiers and can apply cash/reputation/output/cost/demand consequences.
- Event-effect and verified-news tests exist.

**Status: causally integrated.**

### Rankings, influence, legacy and museum

- Ranking uses multiple dimensions rather than cash alone.
- History/legacy/museum systems consume actual company milestones and rankings.
- HQ/museum remain long-term/endgame presentation and progression surfaces.

**Status: implemented long-term layer; not required to block the early V1 operating loop.**

---

## 5. Persistence and authority

- GameState remains the canonical persistent state boundary.
- Save/load covers the major gameplay domains.
- Long-duration tests exercise save/load after extended simulation.
- Finance is authoritative for money and debt.
- Gameplay systems must not create a second cash ledger.
- Compound operations that touch multiple systems should use capture/rollback or mutate only after all fallible checks succeed.

**Status: strong, but authority/rollback regressions remain mandatory because this is a high-risk integration area.**

---

## 6. Automated proof currently available

The main Godot CI does all of the following:

- imports the project
- runs the master architecture/game-plan gate
- runs mobile QA automation
- runs every normal `tests/test_*.gd`, `tests/integration/test_*.gd`, and `tests/release/test_*.gd` test (except explicitly separated soak/visual jobs)
- runs a strict visual gate
- runs a rendered UI matrix
- runs long-duration/soak suites separately
- verifies tests do not modify tracked source

The long-running balance suite advances the real Main scene through **30, 60, 180 and 365 in-game days** and checks economy, workforce, resources, contracts, competition, technology availability, progression/history/news integrity and persistence.

The release new-game-flow test exercises the real Main scene through restoration, company creation, hiring, procurement, production, contracts, sales, competitors/events, history/news and save/load.

The player-journey test was strengthened during this audit so it no longer skips restoration/business creation by directly assigning gameplay state.

---

## 7. What is NOT proven by automated tests

### Physical phone usability

Automated viewport and Android export checks do not replace a real phone playtest. Remaining device checks include:

- touch-only play without keyboard fallback
- text readability at real physical DPI
- safe-area/notch behavior
- one-handed navigation and reachability
- scroll behavior on small screens
- performance/heat/battery over a real session
- visual clarity in the exported APK rather than only desktop/Xvfb rendering

This remains a required release gate because the user's real APK testing already exposed issues that automated desktop-oriented tests did not reveal.

### Full human empire playthrough

The repository has broad feature tests and long simulations, but that is not identical to a human intentionally using every strategic system in one save from first warehouse to legacy/endgame.

Before calling the entire design "perfectly integrated," perform at least one controlled full-save playthrough covering:

1. first property restoration
2. first profitable business
3. workforce growth/training/promotion
4. contracts and pricing strategy
5. resource/supply disruption response
6. regional expansion and branches
7. infrastructure construction and disruption
8. research/technology unlocks
9. competitor conflict/negotiation
10. alliance/diplomacy/joint venture
11. financing/ownership/share decisions
12. acquisition and merger
13. crisis/bankruptcy recovery path where possible
14. rankings/HQ/legacy progression
15. save/load at early, mid and late game

---

## 8. Release truth

### What can now be said confidently

The current game is no longer a collection of unrelated panels. The V1 operating economy is causally connected, the expansion/corporate layers have real system interactions, and several audit-discovered authority/transaction defects have been repaired.

### What must NOT be claimed yet

Do not claim that *every aspect interacts perfectly on every device and across every possible full-game strategy* until:

- the current CI is green,
- the newest APK passes a real-phone touch/readability session,
- and a controlled first-property-to-late-game human playthrough is completed without a disconnected system or state divergence.

That is the final standard for calling RENEW fully integrated rather than merely feature-complete.
