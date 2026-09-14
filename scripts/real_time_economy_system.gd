extends Node

# Real-world economy clock for passive empire assets.
# Active businesses remain player-driven: buying inputs, producing, pricing and
# selling are never performed by this system.

const SETTLEMENT_INTERVAL_SECONDS := 300.0
const MAX_OFFLINE_CATCHUP_SECONDS := 86400.0
const SECONDS_PER_REAL_DAY := 86400.0
const STATE_DOMAIN := "analytics"
const STATE_KEY := "simulation_system"
const CLOCK_KEY := "real_time_economy"

var _poll_accumulator := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _ensure_clock_initialized()

func _process(delta: float) -> void:
    _poll_accumulator += delta
    if _poll_accumulator < 1.0:
        return
    _poll_accumulator = 0.0
    reconcile_passive_income()

func _state():
    return get_node_or_null("/root/RenewGameState")

func _finance():
    return get_node_or_null("/root/RenewFinanceSystem")

func _commands():
    var scene := get_tree().current_scene if get_tree() != null else null
    if scene == null:
        return null
    return scene.get_node_or_null("GameplayCommandSystem")

func _expansion():
    var commands = _commands()
    if commands == null:
        return null
    var controller = commands.get("expansion_system")
    if controller == null:
        return null
    return controller.get("expansion")

func _clock_state() -> Dictionary:
    var state = _state()
    if state == null:
        return {}
    var analytics = state.get_value(STATE_DOMAIN, STATE_KEY, {})
    if not (analytics is Dictionary):
        analytics = {}
    var clock = analytics.get(CLOCK_KEY, {})
    return clock.duplicate(true) if clock is Dictionary else {}

func _save_clock(clock: Dictionary) -> void:
    var state = _state()
    if state == null:
        return
    var analytics = state.get_value(STATE_DOMAIN, STATE_KEY, {})
    if not (analytics is Dictionary):
        analytics = {}
    analytics = analytics.duplicate(true)
    analytics[CLOCK_KEY] = clock.duplicate(true)
    state.set_value(STATE_DOMAIN, STATE_KEY, analytics)

func _get_time_value(key: String, default_value):
    return _clock_state().get(key, default_value)

func _set_time_value(key: String, value) -> void:
    var clock := _clock_state()
    clock[key] = value
    _save_clock(clock)

func _ensure_clock_initialized() -> void:
    var now := Time.get_unix_time_from_system()
    var clock := _clock_state()
    var changed := false
    var last := float(clock.get("last_passive_settlement_unix", 0.0))
    if last <= 0.0 or last > now:
        clock["last_passive_settlement_unix"] = now
        changed = true
    if not clock.has("passive_fractional_carry"):
        clock["passive_fractional_carry"] = 0.0
        changed = true
    if changed:
        _save_clock(clock)

func passive_daily_run_rate() -> Dictionary:
    var expansion = _expansion()
    if expansion == null:
        return {"revenue": 0.0, "expense": 0.0, "net": 0.0, "businesses": 0, "resource_sites": 0}

    if expansion.has_method("_normalize_all"):
        expansion._normalize_all()

    var revenue := 0.0
    var expense := 0.0
    var businesses := 0
    var sites := 0

    for item in expansion.properties:
        if not (item is Dictionary):
            continue
        if bool(item.get("owned", false)) and bool(item.get("active", true)):
            businesses += 1
            var base_income := float(item.get("income", 0))
            var level := maxf(1.0, float(item.get("level", 1)))
            revenue += base_income * level
            expense += base_income / 4.0

    for item in expansion.resource_sites:
        if not (item is Dictionary):
            continue
        if bool(item.get("owned", false)):
            sites += 1
            revenue += float(item.get("output", 0)) * maxf(1.0, float(item.get("level", 1))) * 100.0

    expense += float(expansion.management_level) * 350.0
    return {
        "revenue": revenue,
        "expense": expense,
        "net": revenue - expense,
        "businesses": businesses,
        "resource_sites": sites
    }

func passive_hourly_run_rate() -> Dictionary:
    var daily := passive_daily_run_rate()
    return {
        "revenue": float(daily.get("revenue", 0.0)) / 24.0,
        "expense": float(daily.get("expense", 0.0)) / 24.0,
        "net": float(daily.get("net", 0.0)) / 24.0,
        "businesses": int(daily.get("businesses", 0)),
        "resource_sites": int(daily.get("resource_sites", 0))
    }

func reconcile_passive_income(force: bool = false) -> Dictionary:
    _ensure_clock_initialized()
    var now := Time.get_unix_time_from_system()
    var last := float(_get_time_value("last_passive_settlement_unix", now))
    var elapsed := maxf(0.0, now - last)
    if not force and elapsed < SETTLEMENT_INTERVAL_SECONDS:
        return {"ok": true, "settled": 0, "elapsed": elapsed}

    # A one-day catch-up cap keeps passive income useful without rewarding long
    # absences enough to skip the active game or making device-clock exploits huge.
    var billable_seconds := minf(elapsed, MAX_OFFLINE_CATCHUP_SECONDS)
    var rate := passive_daily_run_rate()
    var daily_net := float(rate.get("net", 0.0))
    var carry := float(_get_time_value("passive_fractional_carry", 0.0))
    var exact_amount := daily_net * (billable_seconds / SECONDS_PER_REAL_DAY) + carry
    var settled := int(floor(exact_amount)) if exact_amount >= 0.0 else int(ceil(exact_amount))
    var new_carry := exact_amount - float(settled)

    var finance = _finance()
    if settled != 0 and finance != null:
        var result: Dictionary
        if settled > 0:
            result = finance.receive(settled, "real-time passive operations")
        else:
            result = finance.spend(-settled, "real-time passive operations")
        if not bool(result.get("ok", false)):
            return {"ok": false, "settled": 0, "elapsed": elapsed, "message": str(result.get("message", "Passive settlement failed."))}

    var clock := _clock_state()
    clock["passive_fractional_carry"] = new_carry
    clock["last_passive_settlement_unix"] = now
    clock["last_passive_amount"] = settled
    clock["last_passive_elapsed_seconds"] = billable_seconds
    clock["passive_daily_net"] = daily_net
    _save_clock(clock)

    return {
        "ok": true,
        "settled": settled,
        "elapsed": billable_seconds,
        "daily_net": daily_net,
        "hourly_net": daily_net / 24.0,
        "businesses": int(rate.get("businesses", 0)),
        "resource_sites": int(rate.get("resource_sites", 0))
    }

func status() -> Dictionary:
    var rate := passive_daily_run_rate()
    var now := Time.get_unix_time_from_system()
    var last := float(_get_time_value("last_passive_settlement_unix", now))
    return {
        "daily_revenue": float(rate.get("revenue", 0.0)),
        "daily_expense": float(rate.get("expense", 0.0)),
        "daily_net": float(rate.get("net", 0.0)),
        "hourly_net": float(rate.get("net", 0.0)) / 24.0,
        "businesses": int(rate.get("businesses", 0)),
        "resource_sites": int(rate.get("resource_sites", 0)),
        "seconds_since_settlement": maxf(0.0, now - last),
        "settlement_interval_seconds": SETTLEMENT_INTERVAL_SECONDS,
        "offline_cap_seconds": MAX_OFFLINE_CATCHUP_SECONDS
    }
