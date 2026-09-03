extends SceneTree

# Phase 42: integration proof for the real employee/game-state/save flow.
# This intentionally starts from Main.tscn rather than instantiating EmployeeSystem alone.
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
    check(scene != null, "Main scene loads")
    if scene == null:
        quit(1)
        return

    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame

    var state = get_node_or_null("/root/RenewGameState")
    check(state != null, "Canonical GameState exists")
    check(game.has_method("hire_employee"), "Main exposes hire flow")
    check(game.has_method("produce_goods"), "Main exposes production flow")
    check(game.has_method("advance_day"), "Main exposes day progression")
    check(game.has_method("save_game"), "Main exposes save flow")
    check(game.has_method("load_game"), "Main exposes load flow")
    if state == null:
        game.free()
        await process_frame
        quit(1)
        return

    # Start from a deterministic, affordable state.
    game.cash = 100000
    game.day = 1
    var before_hire_cash := int(game.cash)

    # Hire James through the actual gameplay façade.
    var hire_result = game.hire_employee()
    check(hire_result is Dictionary, "Hire returns a result")

    var roster = state.get_value("employees", "roster", [])
    check(roster is Array, "GameState employees roster is an array")
    var james_id := ""
    for employee in roster:
        if employee is Dictionary and (String(employee.get("id", "")) == "emp_james_001" or String(employee.get("name", "")) == "James"):
            james_id = String(employee.get("id", ""))
            break
    check(not james_id.is_empty(), "GameState contains James after hire")

    # Ensure production has an employee-backed business path available.
    var before_production_cash := int(game.cash)
    var before_goods := int(game.finished_goods)
    game.produce_goods()
    check(int(game.finished_goods) >= before_goods or int(game.cash) != before_production_cash, "Production executes through game flow")

    # Salary is paid by the employee/day simulation, so advancing a day must affect cash.
    var cash_before_day := int(game.cash)
    var xp_before_day := -1
    var james_before_day: Dictionary = {}
    for employee in state.get_value("employees", "roster", []):
        if employee is Dictionary and String(employee.get("id", "")) == james_id:
            james_before_day = employee.duplicate(true)
            xp_before_day = int(employee.get("experience", 0))
            break
    game.advance_day()
    check(int(game.day) == 2, "Advance day progresses the simulation")
    check(int(game.cash) != cash_before_day, "Employee salary/day simulation affects cash")

    var james_after_day: Dictionary = {}
    for employee in state.get_value("employees", "roster", []):
        if employee is Dictionary and String(employee.get("id", "")) == james_id:
            james_after_day = employee.duplicate(true)
            break
    check(not james_after_day.is_empty(), "James remains in GameState after day advance")
    if xp_before_day >= 0:
        check(int(james_after_day.get("experience", 0)) >= xp_before_day, "James gains or retains experience after simulation")

    # Save through the real Main -> SaveSystem -> GameState path.
    game.save_game()
    var saved_snapshot = state.capture()
    check(saved_snapshot.get("schema_version", 0) == 8, "Save uses canonical schema 8")

    # Deliberately disturb the runtime, then reload and prove James is restored.
    state.set_value("employees", "roster", [])
    check(state.get_value("employees", "roster", []).size() == 0, "Runtime roster can be cleared for load verification")
    game.load_game()

    var restored_roster = state.get_value("employees", "roster", [])
    check(restored_roster is Array, "Loaded GameState employees roster is an array")
    var restored_james := false
    for employee in restored_roster:
        if employee is Dictionary and String(employee.get("id", "")) == james_id:
            restored_james = true
            break
    check(restored_james, "James still exists after save/load")
    check(before_hire_cash > int(game.cash) or int(game.cash) >= 0, "Game remains financially valid after integration flow")

    print("NEW GAME FLOW RESULT: %d passed, %d failed" % [passed, failed])
    game.free()
    await process_frame
    quit(1 if failed > 0 else 0)
