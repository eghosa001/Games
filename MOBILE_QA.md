# RENEW Mobile QA Gate

This checklist separates **automated checks** from the **physical-device release gate**. The automated test cannot certify real Android touch hit-testing, thermals, GPU performance, or memory behavior on a specific handset.

## Automated test

From the repository root with Godot 4.x installed:

```text
godot --headless --path . --script res://tests/mobile_qa_test.gd
```

The test should exercise:

- 320×480, 360×640, 480×800, 720×1280 and 1024×768 responsive layouts
- every generated tab button and action button has a 44×44 minimum touch target
- controls stay inside the viewport at each target size
- RESTORE, BUSINESS, EMPIRE and WORLD navigation
- touch flow: Inspect → Acquire → Restore → Open Business → Hire → Buy Inputs → Produce → Price → Sell Goods
- finite customer demand for the current real-world trading day
- passive run-rate display and five-minute settlement
- authoritative GameState capture/restore of `analytics.real_time`
- disk save/load without resetting passive timestamps, demand usage or calendar anchor
- a short runtime FPS and memory-growth sample

## Physical Android release gate

The following must still be checked on real hardware and manually marked complete:

- [ ] 320px-wide phone
- [ ] 360px-wide phone
- [ ] 480px-wide phone
- [ ] 720px-wide phone/tablet
- [ ] 1024×768 tablet
- [ ] Inspect using touch only
- [ ] Acquire using touch only
- [ ] Restore using touch only
- [ ] Open Business using touch only
- [ ] Hire using touch only
- [ ] Buy Inputs using touch only
- [ ] Produce using touch only
- [ ] Price using touch only
- [ ] Sell Goods using touch only
- [ ] Remaining daily demand decreases correctly after a sale
- [ ] Repeated Sell cannot exceed the day's demand budget
- [ ] Contract delivery can be settled only once for the current day
- [ ] Passive revenue and operating costs accrue together
- [ ] Resource sites include risk-adjusted operating costs
- [ ] Offline passive catch-up never exceeds 24 hours
- [ ] Real date rollover applies wages, overhead, debt, rivals, wear, events and research progress
- [ ] Real date rollover does not automatically produce or sell core-business goods
- [ ] All visible interactive targets are at least 44×44 px
- [ ] Vertical action scrolling works with a finger and does not steal taps
- [ ] WORLD tab is reachable, scrollable and actionable with touch
- [ ] Sustained gameplay holds ≥30 FPS on the target low-end Android device
- [ ] 10–15 minute session shows no material memory growth, stutter, or UI degradation
- [ ] Save/load completes in <1 second on the target device
- [ ] App pause/resume preserves state and does not duplicate actions or passive settlement
- [ ] Back/gesture navigation does not corrupt or unexpectedly exit an active run

## Evidence to record

For each device, record model, Android version, screen resolution, average/lowest observed FPS, approximate memory behavior, and any touch/scroll issue. A screenshot or short screen recording is useful for failures, but is optional.

**Important:** a passing automated run is evidence that the layout and control logic are structurally sound; it does **not** turn the physical-device checklist green.
