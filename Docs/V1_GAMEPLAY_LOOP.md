# RENEW — V1 Gameplay Loop

## Player fantasy
Start with an abandoned property, restore it, turn it into a profitable business, then use the cash and reputation it creates to build a larger company that can challenge established rivals.

## Core loop
1. **Restore** — inspect, acquire and choose a restoration strategy.
2. **Open** — complete restoration and open the first business.
3. **Operate** — buy inputs, produce, set price, market and sell whenever you choose.
4. **Earn** — sell into finite daily customer demand while passive assets accrue net operating income in real time.
5. **Settle** — real-world calendar rollover handles wages, overhead, debt, contract deadlines, rivals, events, wear and research progress.
6. **Expand** — acquire properties, resource sites and better transport.
7. **Compete** — manage rivals, supply contracts, regional markets and alliances.
8. **Scale** — raise capital, acquire competitors and pursue corporate control.

## V1 implementation priorities
### 1. First-business experience
- Make opening the first business feel like a major milestone.
- Show a clear before/after state for the restored property.
- Explain the first profitable action rather than dumping the player into menus.

### 2. Live operating feedback
Every meaningful operating period should communicate:
- current cash
- active sales revenue
- passive revenue and operating costs
- net passive run rate
- today's remaining customer demand
- reputation and important resource/supplier effects

The player should never need to press an End Day button to make the economy move.

### 3. Strategic choices
The player should repeatedly choose between trade-offs such as:
- cheaper restoration vs faster reputation growth
- low price/volume vs high price/margin
- reliable supplier vs cheaper risky supplier
- reinvestment vs cash reserves
- local expansion vs resource ownership
- cooperation with rivals vs aggressive competition

### 4. Milestones
Important milestones should produce a clear reward/feedback moment:
- first property restored
- first business opened
- first live sale
- first profitable operating day
- first passive asset
- first expansion
- first resource site
- first alliance/deal
- first rival acquisition
- first capital raise
- hostile takeover unlocked
- first hostile takeover victory

### 5. Player motivation
Every major screen should answer one question: **"Why should I do this next?"**
Use short contextual feedback and visible next-step goals rather than long tutorials.

## Definition of done for this phase
- Existing regression, extended and edge tests remain green.
- The first 5–10 minutes have a clear restore → open → operate → sell progression.
- Active sales, passive run rate and calendar costs are understandable without debug information.
- Save/load preserves passive timestamps, daily demand usage and calendar anchors.
- Major progression events are visibly acknowledged.
- No new system should block the existing economy/expansion/corporate systems.

See `Docs/REAL_TIME_ECONOMY.md` for the authoritative timing and income rules.
