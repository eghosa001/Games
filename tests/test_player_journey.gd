extends SceneTree

# Player-journey integration test.
# Unlike the old smoke test, this does not inject inspected/owned/restored/open
# state directly. The designed early-game journey must be reached through real
# player commands and survive persistence.
var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _state():
    return root.get_node_or_null("RenewGameState")

func _service(name: String):
    var services := root.get_node_or_null("RenewServices")
    if services != null and services.has_method("get_service"):
        return services.get_service(name)
    return root.get_node_or_null(name)

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

func run() -> void:
    var scene := load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads")
    if scene == null:
        quit(1)
        return

    var game = scene.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame

    var state = _state()
    check(state != null, "Canonical GameState is available")
    if state == null:
        game.free()
        quit(1)
        return

    check(int(game.day) == 1, "New game starts on day 1")
    check(not bool(state.get_value("properties", "owned", false)), "Starting property is not already owned")
    check(not bool(state.get_value("businesses", "business_open", false)), "Starting business is not already open")

    # Give the integration fixture enough capital to exercise mechanics without
    # bypassing any mechanic. Finance remains authoritative after this setup.
    game.cash = 1000000

    game.inspect_property()
    check(bool(state.get_value("properties", "inspected", false)), "Player can inspect the starting property")

    game.acquire_property()
    check(bool(state.get_value("properties", "owned", false)), "Player can acquire the starting property")

    var guard := 0
    while str(state.get_value("properties", "stage", "")) != "Operational" and guard < 24:
        game.restore_property()
        guard += 1
        await process_frame
    check(str(state.get_value("properties", "stage", "")) == "Operational", "Real restoration commands make the property operational")
    check(int(state.get_value("properties", "restoration", 0)) >= 100, "Restoration reaches 100 percent")
    var property := _selected_property(game)
    check(not property.is_empty(), "Operational property remains an authoritative property record")

    game.choose_business_purpose(0)
    if not bool(state.get_value("businesses", "business_open", false)):
        game.open_business()
    check(bool(state.get_value("businesses", "business_open", false)), "Restored property becomes an operating business")
    check(str(state.get_value("businesses", "industry_id", "")) == "furniture", "Industry choice reaches BusinessSystem")

    var employees_before := _roster().size()
    game.hire_employee()
    check(_roster().size() == employees_before + 1, "Hiring creates a persistent employee record")

    var goods_before := int(state.get_value("production", "finished_goods", 0))
    game.buy_inputs()
    game.produce_goods()
    var goods_after := int(state.get_value("production", "finished_goods", 0))
    check(goods_after > goods_before, "Procurement feeds production and creates inventory")

    game.sign_contract()
    var contract_days := int(state.get_value("contracts", "contract_days", 0))
    var contract_message := str(state.get_value("company", "message", "")).to_lower()
    check(contract_days > 0 or contract_message.find("contract") >= 0, "Contract system is reachable from the operating company")

    var day_before := int(game.day)
    var cash_before_day := int(state.get_value("economy", "cash", game.cash))
    game.advance_day()
    await process_frame
    await process_frame
    check(int(game.day) == day_before + 1, "Simulation closes exactly one operating day")
    check(int(state.get_value("economy", "last_sales", 0)) > 0, "Produced inventory reaches real customer/contract sales")
    check(int(state.get_value("economy", "cash", game.cash)) != cash_before_day or int(state.get_value("economy", "last_profit", 0)) != 0, "Trading day has an authoritative financial consequence")

    var progression = _service("RenewProgressionSystem")
    check(progression != null, "Progression system is live")
    if progression != null and progression.has_method("get_xp"):
        check(int(progression.get_xp()) > 0, "Core gameplay feeds long-term progression")

    var history = _service("RenewHistorySystem")
    check(history != null, "History system is live")
    if history != null:
        var timeline = history.get("timeline")
        check(timeline is Array and timeline.size() > 0, "Core gameplay creates permanent history")

    var news = _service("RenewNewsSystem")
    check(news != null, "News system is live")
    if news != null and news.has_method("generate_daily"):
        news.generate_daily(int(game.day))
        var issue = news.get_current_issue() if news.has_method("get_current_issue") else {}
        check(issue is Dictionary and not issue.is_empty(), "Core gameplay can produce a daily news edition")

    game.save_game()
    var saved_day := int(game.day)
    var saved_cash := int(state.get_value("economy", "cash", game.cash))
    var saved_employee_count := _roster().size()
    state.set_value("player", "day", 1)
    state.set_value("economy", "cash", 1)
    state.set_value("employees", "roster", [])
    state.set_value("properties", "owned", false)
    state.set_value("businesses", "business_open", false)
    game.load_game()
    await process_frame

    check(int(game.day) == saved_day, "Save/load restores journey day")
    check(int(state.get_value("economy", "cash", game.cash)) == saved_cash, "Save/load restores authoritative cash")
    check(_roster().size() == saved_employee_count, "Save/load restores employee roster")
    check(bool(state.get_value("properties", "owned", false)), "Save/load restores property ownership")
    check(bool(state.get_value("businesses", "business_open", false)), "Save/load restores operating business")

    print("PLAYER JOURNEY RESULT: %d passed, %d failed" % [passed, failed])
    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)
