# RENEW Game Design Integration Audit

**Audit date:** 2026-09-12

## Executive verdict

RENEW has a real interconnected economic simulation core. The normal day loop already moves consequences through staff productivity, production, demand, inventory, contracts, wages, debt, rivals, alliances, events, regions, reputation and expansion.

It is **not yet accurate to claim that every system in the full design is perfectly integrated into the natural player journey**. Previous coverage sometimes treated three different states as equivalent:

1. a service/file/UI exists;
2. a system has direct behavioral tests;
3. the system is reached naturally in normal play and causally changes other systems.

This audit treats the third state as the standard for full game-design integration.

## Intended long-form player journey

**Discover → Inspect → Acquire → Restore → Operate → Hire → Produce → Sell → Reinvest → Secure resources → Expand → Compete → Negotiate → Form alliances → Create joint ventures → Acquire/merge companies → Build infrastructure → Research technology → Influence the world → Build headquarters/power → Create a legacy → Prestige/endgame.**

A system is fully integrated only when the player can discover it at the right stage and its decisions change later constraints, opportunities, economics or relationships.

## Proof levels

- **CAUSAL / PROVEN** — meaningful runtime producers and consumers exist, with behavioral or integration evidence.
- **IMPLEMENTED / PARTIAL** — meaningful logic exists, usually with targeted tests, but natural progression, UI exposure, breadth or cross-system consequences remain fragmented.
- **FOUNDATION** — service/data/UI exists, but present evidence is mainly existence/wiring rather than enough normal-play causality.
- **FUTURE SCOPE** — intentionally beyond the current shipped gameplay contract and must not be counted as current completeness.

## Integration matrix

| Area | Status | Audit result |
|---|---|---|
| Property discovery / inspection / acquisition | CAUSAL / PROVEN | Real opening prerequisites with financial and state consequences. |
| Restoration | CAUSAL / PROVEN | Consumes capital, changes property state, unlocks operations and feeds progression. |
| Business creation | CAUSAL / PROVEN | Converts the restored property into an operating company; industry choice affects operations. |
| Employees | CAUSAL / PROVEN | Hiring, wages and productivity feed operating economics. |
| Company culture | CAUSAL / PROVEN | Culture modifiers are consumed by employee, demand/quality and research/technology paths. |
| Production and inventory | CAUSAL / PROVEN | Inputs, production capacity, finished goods and sales participate in the daily economy. |
| Demand / pricing / reputation | CAUSAL / PROVEN | Price and non-price modifiers affect sales; outcomes feed reputation and later demand. |
| Finance / debt | CAUSAL / PROVEN | Finance is authoritative for material cash movement and debt service. |
| Supply chain / scarcity | CAUSAL / PROVEN | Resource availability, purchasing and supply conditions constrain production. |
| Contracts | CAUSAL / PROVEN | Contracts have signing/completion consequences and participate in progression/economics. |
| Competitors | CAUSAL / PROVEN | Rival pressure and competitor state influence the operating simulation. |
| Regions / branches / expansion | CAUSAL / PROVEN | Expansion creates additional economic exposure and regional operating effects. |
| Alliances | CAUSAL / PROVEN | Alliance mechanics have economic/strategic effects and dedicated behavior tests. |
| Diplomacy / treaties | CAUSAL / PROVEN | Treaty state changes relationships and material strategic effects. |
| Joint ventures | CAUSAL / PROVEN | Treaty-backed ventures require real funding, split ownership and pay profit shares. |
| Infrastructure | CAUSAL / PROVEN after audit fix | Active assets change freight, production, energy, storage and technology modifiers; build/upgrade/repair now debit FinanceSystem authoritatively. |
| Technology / research | CAUSAL / PROVEN | Research and technology produce operational modifiers rather than only collection state. |
| World events | CAUSAL / PROVEN | Event modifiers feed economic conditions and downstream outcomes. |
| Ownership / shares | CAUSAL / PROVEN | Ownership entities and share state are used by ventures/corporate systems. |
| Acquisitions / mergers | IMPLEMENTED / PARTIAL | Substantial acquisition logic and targeted tests exist, but the main mobile journey lacks an explicit acquisition-stage entry point and progression presentation. |
| Bankruptcy / restructuring | IMPLEMENTED / PARTIAL | Deep failure/restructuring logic exists, but it is not currently presented as a coherent player-facing progression layer. |
| Corporations / corporate strategy | IMPLEMENTED / PARTIAL | Corporate systems and UI exist; progression relationship needs clearer presentation. |
| Global rankings / world power | IMPLEMENTED / PARTIAL | Dedicated systems exist, but the natural journey does not yet surface them as the consequence of prior expansion/strategy milestones. |
| Headquarters | IMPLEMENTED / PARTIAL | System and UI exist, but mobile progression previously did not guide the player into this late-game layer. |
| History / museum / collections | IMPLEMENTED / PARTIAL | Persistent history and collection surfaces exist; their role as a late-game legacy loop is not yet fully communicated through progression. |
| Corporate legacy / prestige / endgame | IMPLEMENTED / PARTIAL | Endgame systems and tests exist, but they need a single coherent late-game progression path and broader long-run validation. |
| Mobile navigation progression | PARTIAL | Before this audit, advanced screens were mostly exposed by day/business-open checks instead of company progression milestones. |
| Physical-device Android QA | NOT AUTOMATICALLY PROVEN | Automated layout/touch-path checks cannot certify real-device thermals, GPU performance, memory behavior or every physical touch target. |

## Defects fixed during this audit

### 1. Infrastructure finance ownership

Construction, upgrades and repairs checked available cash but depended on the UI layer to perform the actual payment. That allowed the domain operation to create value without owning its financial transaction and made non-UI callers unsafe.

**Fix:** `InfrastructureSystem` now performs authoritative finance debits for construction, upgrades and repairs. The UI only sends commands and displays the result. Regression coverage verifies exact-once debits and that rejected operations do not alter cash.

### 2. Progression had levels but no strategic meaning

The progression system previously stored XP, level and generic IDs such as `company_level_2`. It did not define which game-design layers each level represented.

**Fix:** progression now has semantic milestones with save-compatible backfill:

| Level | Strategic layer |
|---|---|
| 1 | Restoration, core operations |
| 2 | Employees, contracts, finance |
| 3 | Regions, branches, supply chain |
| 4 | Competitors, ownership, alliances |
| 5 | Diplomacy, joint ventures, trade |
| 6 | Infrastructure, technology, research |
| 7 | Acquisitions, mergers, corporate strategy |
| 8 | Rankings, world power, headquarters |
| 9 | Museum, collections, legacy |
| 10 | Prestige, endgame |

This preserves existing generic level IDs while giving UI and gameplay code a stable progression contract.

## Highest-priority remaining integration work

1. **Make mobile discovery progression-driven.** Advanced menu entries should appear as semantic milestones unlock, while underlying direct system APIs remain available for tests and save compatibility.
2. **Give acquisitions/corporate strategy an explicit late-game player entry point.** The acquisition system is mounted and tested, but there is no equally obvious dedicated acquisition panel in the main mobile navigation.
3. **Add one end-to-end strategic journey test.** It should prove a path from a restored first property through operations, contracts, regional expansion, alliances/diplomacy, infrastructure/technology, acquisition/corporate power, headquarters and legacy—not merely assert each service exists.
4. **Strengthen long-run balance by progression stage.** Existing soak tests should additionally assert that unlock pacing, cash generation, debt pressure, competitive pressure and late-game costs remain viable around each company-level band.
5. **Keep physical-device QA as a real release gate.** Do not label Android/mobile release fully proven from headless automation alone.

## Definition of “fully integrated” going forward

A feature should not be marked complete merely because its file, service or panel loads. For game-design completion, require all of the following:

- authoritative state ownership is clear;
- material actions are transactional and cannot create value for free;
- at least one upstream system changes its inputs or availability;
- at least one downstream system consumes its consequences;
- save/load preserves the relevant state;
- the player can discover it naturally at the intended progression stage;
- a behavioral test proves the causal interaction;
- long-running simulation does not make the feature economically irrelevant or dominant.

That standard should replace existence-only coverage as the final definition of feature completion.