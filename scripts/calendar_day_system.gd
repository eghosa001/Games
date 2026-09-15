extends Node

## Real calendar progression for RESTORA.
## Passive economy may catch up hours, but simulation-bearing daily systems are
## deliberately capped to one missed calendar day per launch/resume. This avoids
## surprising multi-day debt, staffing, wear or research jumps after an absence.

const MAX_OFFLINE_CALENDAR_DAYS := 1
const CALENDAR_KEY := "calendar_day_anchor"
const CHECK_INTERVAL_SECONDS := 30.0

var _check_clock := 0.0

func _ready() -> void:
    call_deferred("sync_calendar")

func _process(delta: float) -> void:
    _check_clock += delta
    if _check_clock < CHECK_INTERVAL_SECONDS:
        return
    _check_clock = 0.0
    sync_calendar()

func _state():
    return get_node_or_null("/root/RenewGameState")

func _today_ordinal() -> int:
    var now := Time.get_datetime_dict_from_system()
    var year := int(now.get("year", 1970))
    var month := int(now.get("month", 1))
    var day := int(now.get("day", 1))
    # Gregorian ordinal; exact epoch is irrelevant because only differences matter.
    var y := year - (1 if month <= 2 else 0)
    var era := floori(float(y) / 400.0)
    var yoe := y - era * 400
    var mp := month + (-3 if month > 2 else 9)
    var doy := floori((153.0 * mp + 2.0) / 5.0) + day - 1
    var doe := yoe * 365 + floori(float(yoe) / 4.0) - floori(float(yoe) / 100.0) + doy
    return era * 146097 + doe

func _real_time_state() -> Dictionary:
    var state = _state()
    if state == null:
        return {}
    var stored = state.get_value("analytics", "real_time", {})
    return stored.duplicate(true) if stored is Dictionary else {}

func _save_anchor(ordinal: int) -> void:
    var state = _state()
    if state == null:
        return
    var rt := _real_time_state()
    rt[CALENDAR_KEY] = ordinal
    state.set_value("analytics", "real_time", rt)

func sync_calendar() -> Dictionary:
    var state = _state()
    if state == null:
        return {"ok": false, "processed_days": 0}
    var today := _today_ordinal()
    var rt := _real_time_state()
    var previous := int(rt.get(CALENDAR_KEY, today))
    if not rt.has(CALENDAR_KEY):
        _save_anchor(today)
        return {"ok": true, "processed_days": 0}
    if today <= previous:
        if today < previous:
            _save_anchor(today)
        return {"ok": true, "processed_days": 0}
    var elapsed := mini(MAX_OFFLINE_CALENDAR_DAYS, today - previous)
    for _i in range(elapsed):
        advance_calendar_day()
    # Anchor to today even when more than one real day elapsed; the cap is an
    # intentional safety rule, not a backlog that should repeatedly drain.
    _save_anchor(today)
    return {"ok": true, "processed_days": elapsed}

func advance_calendar_day() -> Dictionary:
    var finance = get_node_or_null("/root/RenewFinanceSystem")
    if finance != null and finance.has_method("settle_debt_day"):
        finance.settle_debt_day()

    var game := get_tree().current_scene if get_tree() != null else null
    var commands = game.get("command_system") if game != null else null
    var employee_system = commands.employee_system if commands != null else null
    if employee_system != null and employee_system.has_method("daily_update"):
        employee_system.daily_update()

    var production = get_node_or_null("/root/RenewProductionSystem")
    if production != null and production.has_method("advance_day"):
        production.advance_day()

    var services = get_node_or_null("/root/RenewServices")
    var technology = services.get_service("RenewTechnologySystem") if services != null and services.has_method("get_service") else null
    if technology != null and technology.has_method("advance_calendar_day"):
        technology.advance_calendar_day()

    return {"ok": true}
