extends SceneTree

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

func run() -> void:
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for Day-30 balance")
    if scene == null:
        quit(1)
        return

    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame

    var state = get_node_or_null("/root/RenewGameState")
    check(state != null, "GameState is available")
    if state == null:
        game.free()
        await process_frame
        quit(1)
        return

    game.cash = 100000
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

    for day in range(30):
        game.advance_day()
        await process_frame
        if day % 5 == 0:
            if int(game.cash) > 50000:
                game.upgrade_business()
            if int(game.employees) < 8:
                game.hire_employee()

    var final_cash = int(state.get_value("economy", "cash", 0))
    var final_profit = int(state.get_value("economy", "total_profit", 0))
    var final_rep = int(state.get_value("player", "reputation", 0))
    var final_employees = int(state.get_value("employees", "roster", []).size())

    check(final_cash > 20000, "Cash remains above $20,000 after 30 days (got $%d)" % final_cash)
    check(final_profit > 0, "Total profit is positive after 30 days (got $%d)" % final_profit)
    check(final_rep >= 10, "Reputation grows to at least 10 (got %d)" % final_rep)
    check(final_employees >= 4, "Employee roster grows to at least 4 (got %d)" % final_employees)
    check(final_cash < 1000000000, "Cash is bounded (no infinite money glitch)")

    print("DAY 30 BALANCE RESULT: %d passed, %d failed" % [passed, failed])
    game.free()
    await process_frame
    quit(1 if failed > 0 else 0)
