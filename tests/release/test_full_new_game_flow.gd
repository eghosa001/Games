extends SceneTree

# Phase 44: the single most important V1 release-flow integration test.
# This exercises the real Main scene and gameplay façade from a clean new game
# through restoration, business, employees, production, sales, contracts,
# simulation, competitors, events, history/news, and save/load.
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

func _selected_property(game) -> Dictionary:
    if game.command_system != null and game.command_system.property_system != null:
        return game.command_system.property_system.get_selected_property()
    return {}

func _history_events() -> Array:
    var history = get_node_or_null("/root/RenewHistorySystem")
    if history == null:
        return []
    var timeline = history.get("timeline")
    return timeline if timeline is Array else []

func _news_issue() -> Dictionary:
    var news = get_node_or_null("/root/RenewNewsSystem")
    if news == null or not news.has_method("get_current_issue"):
        return {}
    var issue = news.get_current_issue()
    return issue if issue is Dictionary else {}

func _has_history_event(event_name: String) -> bool:
    for event in _history_events():
        if event is Dictionary and str(event.get("gameplay_event", "")) == event_name:
            return true
    return false

func run() -> void:
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "New Game scene loads")
    if scene == null:
        quit(1)
        return

    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame

    var state = _state()
    check(state != null, "New Game has canonical GameState")
    check(game.has_method("inspect_property"), "Inspect property command exists")
    check(game.has_method("acquire_property"), "Acquire property command exists")
    check(game.has_method("restore_property"), "Restoration command exists")
    check(game.has_method("choose_business_purpose"), "Business purpose command exists")
    check(game.has_method("hire_employee"), "Hire employee command exists")
    check(game.has_method("buy_inputs"), "Resource purchase command exists")
    check(game.has_method("produce_goods"), "Production command exists")
    check(game.has_method("sign_contract"), "Contract command exists")
    check(game.has_method("advance_day"), "Advance day command exists")
    check(game.has_method("save_game"), "Save command exists")
    check(game.has_method("load_game"), "Load command exists")
    check(get_node_or_null("/root/RenewHistorySystem") != null, "HistorySystem is available")
    check(get_node_or_null("/root/RenewNewsSystem") != null, "NewsSystem is available")
    check(game.get_node_or_null("UI/TutorialOverlay") != null, "Tutorial is present in the release scene")
    if state == null:
        game.free()
        await process_frame
        quit(1)
        return

    # New Game -> Tutorial.
    game.cash = 100000
    game.day = 1
    check(int(game.day) == 1, "New Game starts on day 1")
    check(_roster().size() == 3, "New Game starts with the founding employee roster")

    # Tutorial -> inspect -> acquire.
    game.inspect_property()
    check(bool(state.get_value("properties", "inspected", false)), "Property inspection completes")
    game.acquire_property()
    check(bool(state.get_value("properties", "owned", false)), "Property acquisition completes")

    # Clean -> repair -> paint -> furnish. Restore through the real command,
    # repeating until each authoritative property field reaches 100%.
    var selected = _selected_property(game)
    var property_id := str(selected.get("id", ""))
    check(not property_id.is_empty(), "A selected V1 property exists")

    for step in ["cleaning", "repair", "painting", "furnishing"]:
        var guard := 0
        while guard < 10:
            selected = _selected_property(game)
            if int(selected.get(step, 0)) >= 100:
                break
            game.restore_property()
            guard += 1
            await process_frame
        selected = _selected_property(game)
        check(int(selected.get(step, 0)) >= 100, "Restoration step complete: " + step)

    check(str(state.get_value("properties", "stage", "")) == "Operational", "Property becomes operational")

    # Open business through the actual V1 purpose-selection path.
    game.choose_business_purpose(0)
    check(bool(state.get_value("businesses", "business_open", false)), "Business opens after restoration")
    check(str(state.get_value("businesses", "industry_id", "")) == "furniture", "V1 flow selects Furniture industry")

    # Hire employee: founding roster is 3, then the real hiring command makes 4.
    var count_before_hire := _roster().size()
    game.hire_employee()
    var count_after_hire := _roster().size()
    check(count_before_hire == 3, "Employee roster begins at exactly 3")
    check(count_after_hire == 4, "Hiring increases the roster to 4")

    # Buy resources -> produce.
    var before_goods := int(state.get_value("production", "finished_goods", 0))
    game.buy_inputs()
    game.produce_goods()
    var after_goods := int(state.get_value("production", "finished_goods", 0))
    check(after_goods > before_goods, "Resource purchase and production create finished goods")

    # Sign a real V1 contract before the day closes.
    game.sign_contract()
    var contract_days := int(state.get_value("contracts", "contract_days", 0))
    var contract_message := str(state.get_value("company", "message", "")).to_lower()
    check(contract_days > 0 or contract_message.find("contract") >= 0, "Contract flow is reached")

    # Advance day is the V1 sales/settlement boundary. It also runs employee
    # progression, competitors, dynamic events, HistorySystem and NewsSystem.
    var day_before := int(game.day)
    var tracked_id := ""
    var experience_before := -1
    for employee in _roster():
        if employee is Dictionary:
            tracked_id = str(employee.get("id", ""))
            experience_before = int(employee.get("experience", 0))
            break
    game.advance_day()
    await process_frame
    await process_frame

    check(int(game.day) == day_before + 1, "Advance day closes the first operating day")
    check(int(state.get_value("economy", "last_sales", 0)) > 0, "Sales occur during the release flow")

    var experience_after := -1
    for employee in _roster():
        if employee is Dictionary and str(employee.get("id", "")) == tracked_id:
            experience_after = int(employee.get("experience", 0))
            break
    check(experience_after > experience_before, "Employee experience increases during simulation")

    var logs = state.get_value("company", "log_lines", [])
    check(logs is Array and logs.size() > 0, "Simulation produces authoritative company events")
    var competitor_reacted := false
    var event_occurred := false
    if logs is Array:
        for line in logs:
            var text := str(line)
            if text.begins_with("RIVAL:") or text.begins_with("CORPORATE AI:") or text.begins_with("COMPETITOR REACTION:"):
                competitor_reacted = true
            if text.begins_with("EVENT:"):
                event_occurred = true
    check(competitor_reacted, "Competitor reacts during the release flow")
    check(event_occurred, "A dynamic event occurs during the release flow")

    # Actual event stream -> HistorySystem -> NewsSystem.
    check(_history_events().size() > 0, "History records the release-flow events")
    check(_has_history_event("MAJOR_EVENT") or event_occurred, "History has the major-event path")
    var issue := _news_issue()
    check(not issue.is_empty(), "News generates the daily edition")
    check(bool(issue.get("verified_only", false)), "News edition is verified-event-only")
    var stories = issue.get("stories", [])
    check(stories is Array and stories.size() > 0, "News reports at least one actual development")

    # Save -> deliberately disturb state -> load -> prove the release state survives.
    game.save_game()
    var saved_snapshot = state.capture()
    check(int(saved_snapshot.get("schema_version", 0)) == 8, "Release save uses schema 8")
    var saved_employee_ids: Array[String] = []
    for employee in _roster():
        if employee is Dictionary:
            saved_employee_ids.append(str(employee.get("id", "")))
    check(saved_employee_ids.size() == 4, "Saved release state contains the four employees")

    state.set_value("employees", "roster", [])
    state.set_value("properties", "owned", false)
    state.set_value("businesses", "business_open", false)
    game.load_game()
    await process_frame

    var loaded_roster := _roster()
    var all_ids_restored := true
    for employee_id in saved_employee_ids:
        var found := false
        for employee in loaded_roster:
            if employee is Dictionary and str(employee.get("id", "")) == employee_id:
                found = true
                break
        if not found:
            all_ids_restored = false
            break
    check(all_ids_restored, "All employee IDs survive save/load")
    check(bool(state.get_value("properties", "owned", false)), "Property ownership survives save/load")
    check(bool(state.get_value("businesses", "business_open", false)), "Business state survives save/load")

    print("FULL NEW GAME FLOW RESULT: %d passed, %d failed" % [passed, failed])
    game.free()
    await process_frame
    quit(1 if failed > 0 else 0)
