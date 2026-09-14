extends Node

const MAX_OFFLINE_CALENDAR_DAYS := 1

var _poll := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _ensure_initialized()
    reconcile_calendar()

func _process(delta: float) -> void:
    _poll += delta
    if _poll < 30.0:
        return
    _poll = 0.0
    reconcile_calendar()

func _state(): return get_node_or_null("/root/RenewGameState")
func _finance(): return get_node_or_null("/root/RenewFinanceSystem")
func _production(): return get_node_or_null("/root/RenewProductionSystem")
func _technology(): return get_node_or_null("/root/RenewTechnologySystem")
func _commands():
    var scene = get_tree().current_scene if get_tree() != null else null
    return scene.get_node_or_null("GameplayCommandSystem") if scene != null else null
func _analytics() -> Dictionary:
    var state = _state()
    if state == null: return {}
    var root = state.get_value("analytics", "simulation_system", {})
    return root.duplicate(true) if root is Dictionary else {}
func _calendar_state() -> Dictionary:
    var root = _analytics(); var value = root.get("world_calendar", {})
    return value.duplicate(true) if value is Dictionary else {}
func _save_calendar(value: Dictionary) -> void:
    var state = _state()
    if state == null: return
    var root = _analytics(); root["world_calendar"] = value.duplicate(true); state.set_value("analytics", "simulation_system", root)
func _date_key() -> String:
    var d = Time.get_date_dict_from_system()
    return "%04d-%02d-%02d" % [int(d.get("year", 1970)), int(d.get("month", 1)), int(d.get("day", 1))]
func _date_ordinal() -> int:
    var d = Time.get_date_dict_from_system()
    var unix = Time.get_unix_time_from_datetime_dict({"year": int(d.get("year", 1970)), "month": int(d.get("month", 1)), "day": int(d.get("day", 1)), "hour": 12, "minute": 0, "second": 0})
    return int(floor(float(unix) / 86400.0))
func _ensure_initialized() -> void:
    var calendar = _calendar_state()
    if not calendar.has("last_date_ordinal"):
        calendar["last_date_ordinal"] = _date_ordinal()
        calendar["last_date_key"] = _date_key()
        _save_calendar(calendar)
func _log(text: String) -> void:
    var state = _state()
    if state == null or text.is_empty(): return
    var logs = state.get_value("company", "log_lines", [])
    if not (logs is Array): logs = []
    logs = logs.duplicate(true); logs.append(text)
    if logs.size() > 100: logs.pop_front()
    state.set_value("company", "log_lines", logs)
func _sync_finance() -> void:
    var state = _state(); var finance = _finance()
    if state == null or finance == null: return
    state.set_value("economy", "cash", int(finance.cash)); state.set_value("finance", "debt", int(finance.debt)); state.set_value("finance", "loan_payment", int(finance.loan_payment))

func reconcile_calendar(force_one_day: bool = false) -> Dictionary:
    _ensure_initialized()
    var calendar = _calendar_state(); var now_ordinal = _date_ordinal(); var last_ordinal = int(calendar.get("last_date_ordinal", now_ordinal))
    if now_ordinal < last_ordinal:
        calendar["last_date_ordinal"] = now_ordinal; calendar["last_date_key"] = _date_key(); _save_calendar(calendar)
        return {"ok": true, "days": 0, "clock_rewound": true}
    var elapsed_days = maxi(0, now_ordinal - last_ordinal)
    if force_one_day and elapsed_days == 0: elapsed_days = 1
    var days_to_process = mini(elapsed_days, MAX_OFFLINE_CALENDAR_DAYS)
    var processed = 0
    for _i in range(days_to_process):
        var result = _close_one_day()
        if not bool(result.get("ok", false)): return {"ok": false, "days": processed, "message": str(result.get("message", "Calendar rollover failed."))}
        processed += 1
    if processed > 0 or elapsed_days > MAX_OFFLINE_CALENDAR_DAYS:
        calendar = _calendar_state(); calendar["last_date_ordinal"] = now_ordinal; calendar["last_date_key"] = _date_key(); calendar["last_rollover_unix"] = Time.get_unix_time_from_system(); calendar["last_processed_days"] = processed; _save_calendar(calendar)
    return {"ok": true, "days": processed}

func _close_one_day() -> Dictionary:
    var state = _state(); var finance = _finance(); var commands = _commands()
    if state == null or finance == null or commands == null: return {"ok": false, "message": "World calendar dependencies unavailable."}
    var current_day = int(state.get_value("player", "day", 1)); var last_profit = int(state.get_value("economy", "last_profit", 0))

    var employee_result = commands.employee_system.daily_update(last_profit)
    for warning in employee_result.get("warnings", []): _log("STAFF: " + str(warning))
    if commands.supply_system != null and commands.supply_system.economy != null: commands.supply_system.economy.end_market_day()

    var contract_penalty = _settle_contract_deadline(commands, current_day)
    var wages = int(commands.employee_system.get_daily_wage_total())
    var capacity = int(state.get_value("businesses", "capacity_level", 1))
    var overhead = int(round(float(650 + capacity * 100) / 30.0))
    var operating = finance.settle_sales(0, wages, overhead + contract_penalty, 0)
    if bool(operating.get("ok", false)):
        var day_profit = int(operating.get("profit", 0)); state.set_value("economy", "last_profit", day_profit); state.set_value("economy", "total_profit", int(state.get_value("economy", "total_profit", 0)) + day_profit)
    else:
        _log("FINANCE: daily operating costs could not be fully settled: %s" % str(operating.get("message", "unknown")))
    _sync_finance()

    var debt = finance.settle_debt_day(); _sync_finance()
    if bool(debt.get("missed", false)):
        state.set_value("player", "reputation", maxi(0, int(state.get_value("player", "reputation", 0)) - 2)); _log("BANK: missed loan payment; reputation damaged.")
    elif int(debt.get("interest", 0)) > 0: _log("BANK: $%d interest charged." % int(debt.get("interest", 0)))
    for matured in debt.get("matured_investments", []):
        if matured is Dictionary: _log("BANK: term deposit matured +$%d." % int(matured.get("total", 0)))

    var new_day = current_day + 1; state.set_value("player", "day", new_day)
    var rivals = commands.relationship_system.rivals
    if rivals != null:
        for news in rivals.daily_update(new_day): _log("RIVAL: " + str(news))
        var player_state = commands._simulation_state(); player_state["day"] = new_day
        for news in rivals.strategic_ai_update(new_day, player_state): _log("CORPORATE AI: " + str(news))

    if new_day % 2 == 0:
        var events = commands._events()
        if events != null:
            var event = events.roll(); var event_cash = int(event.get("cash", 0))
            if event_cash > 0: finance.receive(event_cash, "calendar event")
            elif event_cash < 0: finance.spend(-event_cash, "calendar event")
            _sync_finance(); state.set_value("player", "reputation", maxi(0, int(state.get_value("player", "reputation", 0)) + int(event.get("rep", 0))))
            if not event.is_empty(): _log("EVENT: %s — %s" % [str(event.get("title", "World event")), str(event.get("text", ""))])

    commands.expansion_system.expansion.unlock_from_reputation(int(state.get_value("player", "reputation", 0)))
    commands.expansion_system.districts.update_unlocks(int(state.get_value("player", "reputation", 0)))
    var production = _production()
    if production != null and production.has_method("advance_day"): production.advance_day()
    var technology = _technology()
    if technology != null:
        if technology.has_method("add_daily_research_points"): technology.add_daily_research_points(3)
        if technology.has_method("advance_calendar_day"): technology.advance_calendar_day()
    if commands.competitor_reactions != null and commands.competitor_reactions.has_method("daily_decay"): commands.competitor_reactions.daily_decay()

    var victory = get_node_or_null("/root/RenewVictorySystem")
    if victory != null and victory.has_method("check_victory"): victory.check_victory()
    if victory != null and victory.has_method("maybe_endgame_crisis"): victory.maybe_endgame_crisis()
    var identity = commands._service("RenewIdentitySystem")
    if identity != null and identity.has_method("evaluate"): identity.evaluate()

    state.set_value("company", "message", "A new real-world trading day has begun. Passive operations continued; active production and sales remain under your control.")
    _log("CALENDAR: day %d opened. Wages, overhead, debt, rivals and world systems settled." % new_day)
    return {"ok": true, "day": new_day, "wages": wages, "overhead": overhead, "contract_penalty": contract_penalty}

func _settle_contract_deadline(commands, current_day: int) -> int:
    var state = _state(); var contracts = get_node_or_null("/root/RenewContractSystem")
    if state == null or contracts == null: return 0
    var active = contracts.active_contract()
    if active.is_empty(): state.set_value("contracts", "contract_days", 0); return 0
    var last = active.get("last_execution", {})
    if last is Dictionary and int(last.get("day", -1)) == current_day: return 0
    var result = contracts.execute_day(str(active.get("id", "")), 0, 100, current_day)
    if not bool(result.get("ok", false)): return 0
    var updated = result.get("contract", {}); var duration = int((updated.get("delivery_schedule", {}) as Dictionary).get("duration_days", 0)) if updated is Dictionary else 0
    var remaining = maxi(0, duration - int(updated.get("days_elapsed", 0))) if updated is Dictionary else 0
    state.set_value("contracts", "contract_days", remaining)
    if bool(result.get("finished", false)): state.set_value("contracts", "contract_bonus", 0)
    var penalty = int(result.get("penalty", 0))
    if penalty > 0: _log("CONTRACT: missed daily delivery; $%d penalty due." % penalty)
    return penalty

func status() -> Dictionary:
    var calendar = _calendar_state()
    return {"date": _date_key(), "day": int(_state().get_value("player", "day", 1)) if _state() != null else 1, "last_date": str(calendar.get("last_date_key", _date_key())), "offline_calendar_cap_days": MAX_OFFLINE_CALENDAR_DAYS}
