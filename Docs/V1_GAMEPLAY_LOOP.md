# RENEW — V1 Gameplay Loop

## Player fantasy
Start with an abandoned property, restore it, turn it into a profitable business, then use the cash and reputation it creates to build a larger company that can challenge established rivals.

## Core loop
1. **Restore** — inspect, acquire and choose a restoration strategy.
2. **Open** — complete restoration and open the first business.
3. **Operate** — buy inputs, produce, set price, market and sell.
4. **Earn** — end the day, read profit/loss feedback and build reputation.
5. **Expand** — acquire properties, resource sites and better transport.
6. **Compete** — manage rivals, supply contracts, regional markets and alliances.
7. **Scale** — raise capital, acquire competitors and pursue corporate control.

## V1 implementation priorities
### 1. First-business experience
- Make opening the first business feel like a major milestone.
- Show a clear before/after state for the restored property.
- Explain the first profitable action rather than dumping the player into menus.

### 2. Daily operating feedback
Every meaningful operating day should communicate:
- cash before/after
- revenue
- operating costs
- profit/loss
- reputation change
- important resource/supplier effects

Avoid requiring the player to infer whether an action was good from raw numbers alone.

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
- first profitable day
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
- The first 5–10 minutes have a clear restore → open → operate → earn progression.
- Daily results are understandable without inspecting debug information.
- Major progression events are visibly acknowledged.
- No new system should block the existing economy/expansion/corporate systems.

## Next coding target
Implement the first-business milestone and daily operating feedback in the mobile HUD, then add/adjust automated tests around those player-facing outcomes.
