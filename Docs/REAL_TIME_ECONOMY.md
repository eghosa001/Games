# RENEW Real-Time Economy

## Core rule

RENEW uses real-world time for background progression while keeping the core business player-driven.

### Active economy

Players may buy inputs, produce, set prices, market, trade, restore assets and sell goods whenever they want. Consumer sales are manual. Demand is finite per real-world trading day, so repeatedly pressing Sell cannot create unlimited money. The daily demand budget resets on the next calendar day.

Contracts are also active: the player can deliver the current day's contract requirement manually. If that day's requirement has not been settled when the calendar rolls over, the contract closes the missed delivery with zero units and applies its shortfall penalty.

### Passive economy

Owned, active expansion properties and resource operations generate passive operating results from elapsed real time. Revenue, operating expense and management overhead accrue together. Passive settlement checkpoints occur every five minutes, and offline catch-up is capped at 24 hours per reconciliation.

Passive operations never manufacture or sell the player's core-business inventory.

### Calendar rollover

At a real-world date change the calendar controller settles the previous operating day. It advances employee condition, wages and headquarters overhead, debt and term deposits, contract deadlines, competitor/world activity, production wear, technology progress, reputation/unlock checks and other daily strategic systems.

The calendar advances at most one missed day after an offline absence. This matches the passive-income 24-hour catch-up cap and prevents long absences from skipping progression.

### Research

Research no longer advances hidden simulation days. Starting a technology deducts its cash and research-point cost and creates a pending project. Each real calendar rollover removes one remaining research day; effects apply only when the project completes.

## Anti-exploit rules

- Backwards device-clock movement never creates elapsed income.
- Passive offline accrual is capped at 24 hours.
- Fractional passive earnings are carried forward instead of repeatedly rounded up.
- Consumer demand tracks units sold during the current trading day.
- A contract can settle only once for a given game/calendar day.
- Active inventory is never sold by passive settlement.

## Legacy compatibility

The older `advance_day()` simulation path remains in the codebase for old automated tests and compatibility scenarios, but it is not exposed by the premium player UX and research no longer calls it with elapsed research days. New gameplay should use the real-time economy, active-market and world-calendar paths.
