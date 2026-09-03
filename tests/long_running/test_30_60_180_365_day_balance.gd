extends SceneTree

# Phase 45: long-run V1 balance verification.
# Runs the real Main scene to days 30, 60, 180 and 365 and checks that
# economy, employees, resources, competition, contracts, technology,
# progression, history and persistence remain sane.
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _init() -> void:
    call_deferred("run")

func _state():
    return get_node_or_null("/root/RenewGameState")

func _roster() -> Array:
    var state = _state()
    if state == null:
        return []
    var roster = state.get_value("employees", "roster", [])
    return roster if roster is Array else []

func _resource_stock() -> Dictionary:
    var state = _state()
    if state == null:
        return {}
    var stock = state.get_value("supply_chain", "warehouse", {})
    if stock is Dictionary:
        return stock
    stock = state.get_value("resources", "stock", {})
    return stock if stock is Dictionary else {}

func _history() -> Array:
    var history = get_node_or_null("/root/RenHistorySystem")
    if history == null:
        return []
    var timeline = history.get("timeline")
    return timeline if timeline is Array else []

func _unique_history() -> bool:
    var seen := {}
    for event in _history():
        if not event is Dictionary:
            continue
        var signature := str(event.get("signature", ""))
        if signature.is_empty():
            signature = "%s|%s|%s" % [event.get("type", ""), event.get("day", 0), event.get("title", "")]
        if seen.has(signature):
            return false
        seen[signature] = true
    return true

func _issue() -> Dictionary:
    var news = get_node_or_null("/root/RenewNewsSystem")
    if news == null or not news.has_method("get_current_issue"):
        return {}
    var issue = news.get_current_issue()
    return issue if issue is Dictionary else {}

func _finite(value) -> bool:
    return is_finite(float(value))

func _prepare_new_game(game, state) -> void:
    # Keep this a gameplay-level setup: restore the property and open a
    # Furniture business so the simulation can run continuously.
    game.cash = 250000
    game.day = 1
    game.inspect_property()
    game.acquire_property()
    var guard := 0
    while str(state.get_value("properties", "stage", "")) != "Operational" and guard < 20:
        game.restore_property()
        guard += 1
        await process_frame
    game.choose_business_purpose(0)
    game.hire_employee()
    game.buy_inputs()
    game.produce_goods()

func _assert_baseline(state) -> void:
    check(int(state.get_value("player", "day", 0)) >= 1, "Long-run day is valid")
    check(_roster().size() >= 3, "Long-run employee roster remains populated")
    check(_finite(state.get_value("economy", "cash", 0)), "Cash remains finite")
    check(_finite(state.get_value("economy", "last_profit", 0)), "Profit remains finite")
    check(int(state.get_value("player", "reputation", 0)) >= 0, "Reputation never becomes impossible negative")
    for key in _resource_stock():
        check(float(_resource_stock()[key]) >= -0.0001, "Resource stock is non-negative: " + str(key))

func _check_day_30(state) -> void:
    check(int(state.get_value("player", "day", 0)) >= 30, "Day 30 reached")
    check(_finite(state.get_value("economy", "cash", 0)), "Day 30 cash is finite")
    check(_finite(state.get_value("economy", "last_profit", 0)), "Day 30 profit is finite")
    check(_roster().size() >= 3, "Day 30 employees remain active roster data")
    check(_resource_stock().size() > 0, "Day 30 resources remain represented")
    check(_finite(state.get_value("competitors", "relationship", 0)), "Day 30 market/competition state is valid")
    check(int(state.get_value("player", "reputation", 0)) >= 0, "Day 30 reputation is valid")

func _check_day_60(state) -> void:
    check(int(state.get_value("player", "day", 0)) >= 60, "Day 60 reached")
    check(int(state.get_value("economy", "cash", 0)) > -1000000000, "Day 60 growth remains bounded")
    check(_roster().size() >= 3, "Day 60 employee growth state remains valid")
    check(int(state.get_value("contracts", "contract_days", 0)) >= 0, "Day 60 contract state is valid")
    var technology = get_node_or_null("/root/RenewTechnologySystem")
    check(technology != null, "Day 60 technology system remains available")
    if technology != null:
        check(technology.has_method("get_unlocked"), "Day 60 technology progression API remains available")
    check(_finite(state.get_value("competitors", "relationship", 0)), "Day 60 competition remains valid")

func _check_day_180(state) -> void:
    check(int(state.get_value("player", "day", 0)) >= 180, "Day 180 reached")
    check(_finite(state.get_value("economy", "cash", 0)), "Day 180 economy remains finite")
    check(_finite(state.get_value("economy", "total_profit", 0)), "Day 180 cumulative profit remains finite")
    var roster = _roster()
    var progression_seen := false
    for employee in roster:
        if employee is Dictionary and int(employee.get("experience", 0)) > 0:
            progression_seen = true
            break
    check(progression_seen, "Day 180 employee progression exists")
    check(_resource_stock().size() > 0, "Day 180 resource system remains active")
    check(int(state.get_value("branches", "capacity_level", 1)) >= 1, "Day 180 expansion state remains valid")
    check(_finite(state.get_value("supply_chain", "transport_capacity", 40)), "Day 180 supply capacity remains valid")

func _check_day_365(state) -> void:
    check(int(state.get_value("player", "day", 0)) >= 365, "Day 365 reached")
    var cash := float(state.get_value("economy", "cash", 0))
    check(_finite(cash), "Day 365 has no runaway non-finite money")
    check(abs(cash) < 100000000000.0, "Day 365 money remains bounded")
    check(_finite(state.get_value("economy", "total_profit", 0)), "Day 365 cumulative profit is finite")
    var stock = _resource_stock()
    for key in stock:
        check(float(stock[key]) >= -0.0001, "Day 365 resource is never impossible negative: " + str(key))
    check(_roster().size() >= 1, "Day 365 employee data remains intact")
    check(_unique_history(), "Day 365 history contains no duplicate signatures")
    var rivals = get_node_or_null("/root/RenewCompetitorReactionSystem")
    check(rivals != null, "Day 365 competitor AI remains available")
    var news = get_node_or_null("/root/RenewNewsSystem")
    check(news != null, "Day 365 NewsSystem remains available")
    var issue := _issue()
    check(issue.is_empty() or bool(issue.get("verified_only", false)), "Day 365 news remains verified-event-only")

func _save_and_reload(game, state) -> void:
    var saved_day := int(state.get_value("player", "day", 0))
    var saved_cash := int(state.get_value("economy", "cash", 0))
    var saved_ids: Array[String] = []
    for employee in _roster():
        if employee is Dictionary:
            saved_ids.append(str(employee.get("id", "")))
    game.save_game()
    var snapshot = state.capture()
    check(int(snapshot.get("schema_version", 0)) == 8, "Day 365 save uses schema 8")
    state.set_value("player", "day", 1)
    state.set_value("economy", "cash", 1)
    state.set_value("employees", "roster", [])
    game.load_game()
    await process_frame
    check(int(state.get_value("player", "day", 0)) == saved_day, "Day 365 load restores day")
    check(int(state.get_value("economy", "cash", 0)) == saved_cash, "Day 365 load restores cash")
    var loaded_ids := {}
    for employee in _roster():
        if employee is Dictionary:
            loaded_ids[str(employee.get("id", ""))] = true
    var all_restored := true
    for employee_id in saved_ids:
        if not loaded_ids.has(employee_id):
            all_restored = false
            break
    check(all_restored, "Day 365 save/load preserves employee IDs")

func run() -> void:
    var packed = load("res://scenes/Main.tscn")
    check(packed != null, "Long-run test loads the real Main scene")
    if packed == null:
        quit(1)
        return
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var state = _state()
    check(state != null, "Long-run test has canonical GameState")
    if state == null:
        game.free()
        await process_frame
        quit(1)
        return

    await _prepare_new_game(game, state)
    _assert_baseline(state)

    # Advance the real simulation one day at a time. This deliberately does
    # not bypass SimulationSystem, competitor reactions, events, employees,
    # contracts, history or news.
    while int(state.get_value("player", "day", 0)) < 365:
        game.advance_day()
        await process_frame
        if int(state.get_value("player", "day", 0)) % 10 == 0:
            await process_frame

        var day := int(state.get_value("player", "day", 0))
        if day == 30:
            _check_day_30(state)
        elif day == 60:
            _check_day_60(state)
        elif day == 180:
            _check_day_180(state)
        elif day == 365:
            _check_day_365(state)

    await _save_and_reload(game, state)

    print("30/60/180/365 DAY BALANCE RESULT: %d passed, %d failed" % [passed, failed])
    game.free()
    await process_frame
    quit(1 if failed > 0 else 0)
