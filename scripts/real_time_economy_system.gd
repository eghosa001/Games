extends Node

# Real-world economy clock for passive empire assets.
# Active businesses remain player-driven: buying inputs, producing, pricing and
# selling are never performed by passive settlement.

const ActiveMarketSystem = preload("res://scripts/active_market_system.gd")
const WorldCalendarSystem = preload("res://scripts/world_calendar_system.gd")
const SETTLEMENT_INTERVAL_SECONDS := 300.0
const MAX_OFFLINE_CATCHUP_SECONDS := 86400.0
const SECONDS_PER_REAL_DAY := 86400.0
const STATE_DOMAIN := "analytics"
const STATE_KEY := "real_time"
const CLOCK_KEY := "real_time_economy"

var _poll_accumulator := 0.0
var active_market: Node
var world_calendar: Node

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    active_market = ActiveMarketSystem.new(); active_market.name = "ActiveMarketSystem"; add_child(active_market)
    world_calendar = WorldCalendarSystem.new(); world_calendar.name = "WorldCalendarSystem"; add_child(world_calendar)
    _ensure_clock_initialized()

func _process(delta: float) -> void:
    _poll_accumulator += delta
    if _poll_accumulator < 1.0:
        return
    _poll_accumulator = 0.0
    reconcile_passive_income()

func _state(): return get_node_or_null("/root/RenewGameState")
func _finance(): return get_node_or_null("/root/RenewFinanceSystem")
func _sync_finance() -> void:
    var state = _state(); var finance = _finance()
    if state == null or finance == null: return
    state.set_value("economy", "cash", int(finance.cash))
    state.set_value("finance", "debt", int(finance.debt))
    state.set_value("finance", "loan_payment", int(finance.loan_payment))
func _commands():
    var scene := get_tree().current_scene if get_tree() != null else null
    if scene == null: return null
    return scene.get_node_or_null("GameplayCommandSystem")
func _expansion():
    var commands = _commands()
    if commands == null: return null
    var controller = commands.get("expansion_system")
    if controller == null: return null
    return controller.get("expansion")
func _clock_state() -> Dictionary:
    var state = _state()
    if state == null: return {}
    var analytics = state.get_value(STATE_DOMAIN, STATE_KEY, {})
    if not (analytics is Dictionary): analytics = {}
    var clock = analytics.get(CLOCK_KEY, {})
    return clock.duplicate(true) if clock is Dictionary else {}
func _save_clock(clock: Dictionary) -> void:
    var state = _state()
    if state == null: return
    var analytics = state.get_value(STATE_DOMAIN, STATE_KEY, {})
    if not (analytics is Dictionary): analytics = {}
    analytics = analytics.duplicate(true); analytics[CLOCK_KEY] = clock.duplicate(true); state.set_value(STATE_DOMAIN, STATE_KEY, analytics)
func _get_time_value(key: String, default_value): return _clock_state().get(key, default_value)
func _ensure_clock_initialized() -> void:
    var now := Time.get_unix_time_from_system(); var clock := _clock_state(); var changed := false
    var last := float(clock.get("last_passive_settlement_unix", 0.0))
    if last <= 0.0 or last > now: clock["last_passive_settlement_unix"] = now; changed = true
    if not clock.has("passive_fractional_carry"): clock["passive_fractional_carry"] = 0.0; changed = true
    if changed: _save_clock(clock)

func passive_daily_run_rate() -> Dictionary:
    var expansion = _expansion()
    if expansion == null: return {"revenue": 0.0, "expense": 0.0, "net": 0.0, "businesses": 0, "resource_sites": 0}
    if expansion.has_method("_normalize_all"): expansion._normalize_all()
    var revenue := 0.0; var expense := 0.0; var businesses := 0; var sites := 0
    for item in expansion.properties:
        if item is Dictionary and bool(item.get("owned", false)) and bool(item.get("active", true)):
            businesses += 1
            var base_income := float(item.get("income", 0)); var level := maxf(1.0, float(item.get("level", 1)))
            var property_revenue := base_income * level
            revenue += property_revenue
            expense += property_revenue * 0.25
    for item in expansion.resource_sites:
        if item is Dictionary and bool(item.get("owned", false)):
            sites += 1
            var site_revenue := float(item.get("output", 0)) * maxf(1.0, float(item.get("level", 1))) * 100.0
            var risk := clampf(float(item.get("risk", 0)), 0.0, 100.0)
            # Extraction/logistics costs start at 25% and rise with site risk.
            var site_cost_ratio := clampf(0.25 + risk * 0.005, 0.25, 0.75)
            revenue += site_revenue
            expense += site_revenue * site_cost_ratio
    expense += float(expansion.management_level) * 350.0
    return {"revenue": revenue, "expense": expense, "net": revenue - expense, "businesses": businesses, "resource_sites": sites}

func passive_hourly_run_rate() -> Dictionary:
    var daily := passive_daily_run_rate()
    return {"revenue": float(daily.get("revenue", 0.0)) / 24.0, "expense": float(daily.get("expense", 0.0)) / 24.0, "net": float(daily.get("net", 0.0)) / 24.0, "businesses": int(daily.get("businesses", 0)), "resource_sites": int(daily.get("resource_sites", 0))}

func reconcile_passive_income(force: bool = false) -> Dictionary:
    _ensure_clock_initialized()
    var now := Time.get_unix_time_from_system(); var last := float(_get_time_value("last_passive_settlement_unix", now)); var elapsed := maxf(0.0, now - last)
    if not force and elapsed < SETTLEMENT_INTERVAL_SECONDS: return {"ok": true, "settled": 0, "elapsed": elapsed}
    var billable_seconds := minf(elapsed, MAX_OFFLINE_CATCHUP_SECONDS); var rate := passive_daily_run_rate(); var daily_net := float(rate.get("net", 0.0)); var carry := float(_get_time_value("passive_fractional_carry", 0.0))
    var exact_amount := daily_net * (billable_seconds / SECONDS_PER_REAL_DAY) + carry
    var settled := int(floor(exact_amount)) if exact_amount >= 0.0 else int(ceil(exact_amount)); var new_carry := exact_amount - float(settled)
    var finance = _finance()
    if settled != 0 and finance != null:
        var result: Dictionary = finance.receive(settled, "real-time passive operations") if settled > 0 else finance.spend(-settled, "real-time passive operations")
        if not bool(result.get("ok", false)):
            # Advance the clock even when an operating deficit cannot be paid so
            # the same elapsed period cannot be charged repeatedly every frame.
            var failed_clock := _clock_state(); failed_clock["last_passive_settlement_unix"] = now; failed_clock["last_passive_amount"] = 0; failed_clock["last_passive_elapsed_seconds"] = billable_seconds; failed_clock["passive_daily_net"] = daily_net; _save_clock(failed_clock)
            _sync_finance()
            return {"ok": false, "settled": 0, "elapsed": billable_seconds, "message": str(result.get("message", "Passive operating deficit could not be paid."))}
        _sync_finance()
    var clock := _clock_state(); clock["passive_fractional_carry"] = new_carry; clock["last_passive_settlement_unix"] = now; clock["last_passive_amount"] = settled; clock["last_passive_elapsed_seconds"] = billable_seconds; clock["passive_daily_net"] = daily_net; _save_clock(clock)
    return {"ok": true, "settled": settled, "elapsed": billable_seconds, "daily_net": daily_net, "hourly_net": daily_net / 24.0, "businesses": int(rate.get("businesses", 0)), "resource_sites": int(rate.get("resource_sites", 0))}

func sell_goods() -> Dictionary:
    return active_market.sell_goods() if active_market != null else {"ok": false, "message": "Active market unavailable."}
func deliver_contract() -> Dictionary:
    return active_market.deliver_contract() if active_market != null else {"ok": false, "message": "Active market unavailable."}
func demand_snapshot() -> Dictionary:
    return active_market.demand_snapshot() if active_market != null else {"ok": false, "remaining": 0}
func reconcile_calendar(force_one_day: bool = false) -> Dictionary:
    return world_calendar.reconcile_calendar(force_one_day) if world_calendar != null else {"ok": false, "message": "World calendar unavailable."}

func status() -> Dictionary:
    var rate: Dictionary = passive_daily_run_rate()
    var now := Time.get_unix_time_from_system()
    var last := float(_get_time_value("last_passive_settlement_unix", now))
    var demand: Dictionary = demand_snapshot()
    var calendar_state: Dictionary = {}
    if world_calendar != null:
        calendar_state = world_calendar.status()
    return {"daily_revenue": float(rate.get("revenue", 0.0)), "daily_expense": float(rate.get("expense", 0.0)), "daily_net": float(rate.get("net", 0.0)), "hourly_net": float(rate.get("net", 0.0)) / 24.0, "businesses": int(rate.get("businesses", 0)), "resource_sites": int(rate.get("resource_sites", 0)), "seconds_since_settlement": maxf(0.0, now - last), "settlement_interval_seconds": SETTLEMENT_INTERVAL_SECONDS, "offline_cap_seconds": MAX_OFFLINE_CATCHUP_SECONDS, "consumer_demand_remaining": int(demand.get("remaining", 0)), "calendar": calendar_state}
