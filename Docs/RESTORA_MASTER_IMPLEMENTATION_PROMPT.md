# RESTORA Master Implementation Prompt

## Mission
Act as the lead game designer, Godot engineer, mobile UX engineer, economy/simulation designer, QA engineer, and release engineer for RESTORA. Work directly in this repository and improve the existing game rather than rebuilding it from scratch.

RESTORA is an economic restoration and empire-building simulation built around this long-form journey:

**Discover → Inspect → Acquire → Restore → Operate → Hire → Produce → Sell → Reinvest → Secure Resources → Expand → Compete → Negotiate → Form Alliances → Trade → Build Infrastructure → Research Technology → Acquire/Merge Companies → Build World Power → Develop Headquarters → Create a Legacy → Prestige / New Dynasty.**

The player must always understand:
1. what changed,
2. why it changed,
3. what they can do next,
4. what the decision will cost or risk,
5. which system will be affected.

Never treat the UI as a second simulation. GameState and authoritative domain systems own gameplay truth.

---

## 1. Core Gameplay Loop

Preserve and polish the foundational loop:

**Property**
- Discover a neglected property.
- Inspect before acquisition.
- Show condition, value, acquisition cost and restoration needs.
- Acquire through authoritative finance.
- Restore in visible, chronological stages.
- Every restoration action changes the real property state, value and progression.
- Operational status must unlock business use rather than being cosmetic.

**Business**
- Choose a compatible business purpose for an operational property.
- Buy real inputs.
- Produce real inventory.
- Hire, train and assign employees.
- Set prices and marketing.
- Sell to demand.
- Accept and fulfil contracts.
- Make profit/loss visible.
- Feed results into reputation, progression, competitors and future opportunities.

The first 5–10 minutes should teach this loop without overwhelming the player with empire systems.

---

## 2. Progression and Discovery

Use the existing semantic company-level progression as the complexity gate:

- Level 1 — Restoration and core operations.
- Level 2 — Employees, contracts and finance.
- Level 3 — Regions, branches and supply chain.
- Level 4 — Competitors, ownership and alliances.
- Level 5 — Diplomacy, joint ventures and trade.
- Level 6 — Infrastructure, technology and research.
- Level 7 — Acquisitions, mergers and corporate strategy.
- Level 8 — Rankings, world power and headquarters.
- Level 9 — Museum, collections and legacy.
- Level 10 — Prestige and endgame.

Requirements:
- Locked systems remain visible only when useful for anticipation; clearly show their unlock level.
- Home “Next Move” must evolve with progression instead of permanently ending at “Reinvest and grow.”
- Every newly unlocked strategic layer needs a clear mobile entry point.
- Company Progress must communicate the current layer, completed layers and next meaningful unlock.
- Level-up screens must explain the real systems that were unlocked.

---

## 3. Economy and Finance

Keep RenewFinanceSystem as the authoritative money/debt ledger.

All material economic actions must:
- check affordability before mutation,
- debit/credit finance exactly once,
- roll back domain state if payment fails,
- never create value from UI-only changes,
- produce a clear player-facing result.

Cover:
- restoration spend,
- acquisitions,
- payroll,
- input procurement,
- transport,
- infrastructure,
- headquarters,
- loans and repayment,
- investment,
- contracts,
- asset sales,
- restructuring,
- expansion,
- research/technology costs where applicable.

The UI should display cash, debt, profit, revenue, equity or shortfall only from authoritative data.

---

## 4. Employees and Management

Employees must matter economically and strategically.

Ensure:
- hiring affects payroll and operating capacity,
- training affects skill/productivity,
- assignments affect real operations,
- morale/culture are not decorative metrics,
- firing and downsizing preserve transactional safety,
- executive/management capacity affects larger empires,
- headquarters and company culture provide bounded modifiers rather than replacing employee progression.

Every employee button must modify real state and refresh the visible screen immediately.

---

## 5. Production, Inventory and Supply Chain

Production must be constrained by:
- inputs,
- staff/capacity,
- business type,
- supply conditions,
- transport/logistics,
- demand and contracts.

Requirements:
- no free inventory,
- no negative stock,
- no UI-created stock,
- purchase quotes reflect the selected supplier,
- supplier reliability/cost trade-offs remain meaningful,
- transport upgrades have a real logistics effect,
- internal resource movement remains consistent with owned stock,
- contract delivery consumes actual goods.

---

## 6. Regions, Branches and Expansion

Make growth feel like entering a larger economy, not unlocking menus.

Regions and branches should visibly connect to:
- reputation requirements,
- demand,
- infrastructure,
- logistics,
- competition,
- resource access,
- property opportunities,
- trade routes.

The World surface should answer:
- Where am I?
- What is unlocked?
- What can I acquire?
- What is the commercial opportunity?
- What risk or competitor pressure exists?
- What action should I take next?

---

## 7. Competitors, Ownership, Alliances and Corporate Strategy

The player should encounter competitors naturally after building a functioning company.

Expose and connect:
- rival relationships,
- alliances,
- shares/ownership,
- supply/customer partnerships,
- acquisition negotiation,
- acquisition battles,
- bid escalation,
- mergers/control,
- competitor reactions.

At Level 7, provide an explicit **Corporate Strategy** entry point. It must lead to the real corporation/ownership/acquisition systems, never a fake summary-only mechanic.

Acquisition results should influence history, collections, company value and later world-power/legacy layers.

---

## 8. Infrastructure, Technology and Research

Infrastructure must affect operational outcomes such as:
- freight/logistics,
- production,
- energy,
- storage,
- security/risk,
- technology/research capacity.

Technology/research must create bounded, understandable operational modifiers.

At Level 6, both systems should be easy to discover from mobile navigation and from the progression journey.

---

## 9. World Power, Rankings and Headquarters

At Level 8, introduce a coherent “power” phase.

World Power should summarize live dimensions such as:
- economic power,
- resource control,
- industrial capacity,
- technology,
- logistics,
- diplomacy,
- alliance influence,
- cultural/reputation strength.

Never use invented percentages; derive values from the ranking/power system.

Headquarters must:
- use the real HeadquartersSystem,
- show current stage,
- show built functional areas,
- show real next-stage cost,
- expose management/research/training effects,
- use authoritative finance for upgrades.

World Power → Headquarters → Legacy should feel like a deliberate strategic chain.

---

## 10. Bankruptcy and Corporate Recovery

Financial distress is gameplay, not a dead-end error state.

Preserve the existing lifecycle:

**Stable → Cash Crisis → Covenant Pressure → Restructuring → Recovery**

and severe outcomes:

**Insolvent → Administration → Liquidation / Distressed Acquisition**

Requirements:
- distress state comes from real financial conditions,
- recovery controls remain reachable when needed,
- no distress overlay while healthy,
- actions such as restructuring, rescue investment, downsizing, refinancing, liquidation and distressed acquisition must use authoritative systems,
- save/load must preserve recovery state,
- successful recovery should feed company history/legacy.

---

## 11. Legacy, Collections, Victory and Prestige

At Level 9+, make late-game history understandable.

Legacy should connect:
- restored landmarks,
- notable employees,
- contracts,
- acquisitions,
- technologies,
- alliances,
- rankings,
- crisis recoveries,
- collections.

At Level 10:
- surface victory paths and prestige clearly,
- explain permanent bonuses before a new dynasty,
- never reset the current campaign accidentally,
- preserve earned prestige according to the existing victory/save rules.

---

## 12. UI / UX and Figma Runtime

The current Figma-driven mobile direction is authoritative.

Design principles:
- premium, clean, warm industrial/business aesthetic,
- clear hierarchy,
- flat or lightly dimensional presentation; avoid heavy 3D UI,
- generous spacing,
- no overlapping panels or text,
- no truncated important labels,
- no debug/internal terminology,
- no fake data,
- no duplicate navigation controls,
- no screen should obscure another active screen.

Mobile shell:
- Home
- Business
- Property
- Finance
- More

Use “More” as the progression-aware enterprise command center.

Minimum touch target: 44×44 px; prefer 48 px where practical.

Scrolling:
- vertical touch scrolling must respond quickly,
- no horizontal drift,
- content must remain inside viewport bounds,
- persistent bottom navigation must not cover content,
- re-tapping the active main tab should return to the top without a heavy rebuild.

Navigation:
- all visible buttons must have a real destination or real action,
- back paths must return to the logical parent,
- Figma detail screens should not overlap notification controls,
- native legacy/deep screens opened from Figma must use the central screen manager,
- only one focused deep screen may be visible at a time.

State-changing same-view actions must refresh the visible screen immediately.

---

## 13. Theme and Accessibility

Support:
- light mode,
- dark mode,
- system theme,
- scalable text,
- reduced motion,
- high contrast,
- text labels alongside color meaning.

Accessibility changes must persist and apply consistently to both Figma and native management screens.

Do not solve text overflow by making text unreadably small.

---

## 14. Audio and Feedback

Preserve adaptive music, UI feedback, success/failure sounds and day-end/restoration cues.

Requirements:
- no crackling or repeated rapid-fire sounds,
- volume controls persist,
- audio feedback should confirm actions without slowing navigation,
- visual feedback must still work when sound is disabled.

---

## 15. Save, Load and Reliability

GameState remains the single persistent source of truth.

Save/load must preserve:
- properties and restoration,
- business state,
- employees,
- production/inventory,
- contracts,
- finance/debt,
- supply chain,
- expansion,
- regions,
- competitors/ownership,
- acquisitions,
- infrastructure,
- technology,
- headquarters,
- bankruptcy/recovery,
- history/collections,
- progression and prestige where designed.

Autosave must protect mobile sessions and lifecycle interruptions.

Never silently replace a valid save with a partially initialized state.

---

## 16. Performance

Prioritize responsiveness on Android.

Requirements:
- avoid rebuilding the entire UI tree when only a focused section must change,
- do not poll expensive services every frame when event/state-driven updates work,
- keep transitions short,
- reuse persistent navigation,
- avoid unnecessary 3D rendering,
- prevent duplicate hidden screens from processing,
- preserve GL compatibility for broad Android support unless deliberately changed.

Target real-device minimum: stable ≥30 FPS on low-end supported Android hardware, with no progressive memory growth during a normal play session.

---

## 17. Monetization

Monetization must remain optional and separate from core economic balance.

Rules:
- no paywall for the restoration/business core,
- rewarded benefits must be provider-verified and capped,
- premium entitlements must be provider-verified,
- the game remains playable when ad/purchase providers are unavailable,
- no local flag may be trusted as proof of a purchase,
- privacy/consent behavior must match the actual enabled providers.

Do not enable production monetization configuration without valid account-side credentials.

---

## 18. Android and Release Engineering

Maintain:
- Godot 4.x compatibility,
- correct package/application metadata,
- portrait mobile behavior,
- Android-compatible renderer/assets,
- safe permission set,
- reproducible debug build,
- release signing through secrets rather than committed keys.

Do not claim store-ready until:
- signed release artifact is generated,
- installation is tested,
- restart save/load is tested,
- low/mid/high-end devices are checked,
- permissions are reviewed,
- store privacy/terms assets exist,
- required Play testing/account steps are completed.

---

## 19. Testing Policy

Repository owner policy is mandatory:
- run only tests directly relevant to changed files/behavior,
- keep tests short and behavior-specific,
- do not run broad/full suites automatically,
- do not run exhaustive visual matrices, soak tests, Android release builds or unrelated CI unless explicitly requested,
- stop once the smallest relevant validation proves the change.

For UI-flow work, prefer a focused runtime test proving:
- screen builds,
- route is reachable,
- button is at least 44 px,
- authoritative state/action wiring works,
- back route is correct,
- mobile content remains contained.

---

## 20. Completion Standard

A feature is complete only when:
- authoritative state ownership is clear,
- action logic is real,
- finance/state mutations are safe,
- save/load preserves it,
- mobile UI exposes it at the right progression stage,
- the player understands its consequence,
- the relevant focused test passes.

Do not mark physical-device, signing, Play Console or store-account work complete unless it was actually performed.

## Immediate implementation priority
1. Preserve the polished opening restoration/business flow.
2. Make the entire strategic progression discoverable from mobile.
3. Add explicit Corporate Strategy, World Power, Headquarters and Legacy Figma journey screens.
4. Connect each summary screen to the existing authoritative native/system implementation.
5. Make Home Next Move progression-aware through Level 10.
6. Keep all existing saves and gameplay systems compatible.
7. Validate only the changed flow with focused tests.
