extends SceneTree

# Phase 43: employee integration proof across hiring, wages, assignment,
# production impact, simulation, and canonical save/load persistence.
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
    if state == null:
        game.free()
        await process_frame
        quit(1)
        return

    # Start from the real founding roster: James, David, and Sarah.
    game.cash = 100000
    game.day = 1
    state.set_value("businesses", "business_open", true)

    var employee_command = game.command_system.employee_system
    var starting_count := int(employee_command.get_active_employee_count())
    check(starting_count == 3, "Employee count starts at 3")

    var wages_before_hire := int(employee_command.get_daily_wage_total())
    game.hire_employee()
    var count_after_hire := int(employee_command.get_active_employee_count())
    check(count_after_hire == 4, "Hiring increases employee count to 4")

    var wages_after_hire := int(employee_command.get_daily_wage_total())
    check(wages_after_hire > wages_before_hire, "Daily wages increase after hiring")

    var roster = state.get_value("employees", "roster", [])
    check(roster is Array and roster.size() == 4, "GameState roster contains four employees")

    # Identify the newly hired employee through the real roster rather than a
    # UI-only fixture. Keep the employee ID for the final persistence check.
    var hired_id := ""
    for employee in roster:
        if employee is Dictionary and String(employee.get("id", "")) != "emp_james_001" and String(employee.get("id", "")) != "emp_0002" and String(employee.get("id", "")) != "emp_0003":
            if String(employee.get("status", "active")) == "active":
                hired_id = String(employee.get("id", ""))
                break
    check(not hired_id.is_empty(), "Newly hired employee has a persistent ID")

    # Put the hired employee on the bench first, then assign to the factory.
    # This gives the integration test a real before/after production signal.
    employee_command.assign_employee(hired_id, "bench_001", game.day)
    employee_command.sync_roster()
    var productivity_before_factory := float(employee_command.get_productivity_multiplier("factory_001"))

    employee_command.assign_employee(hired_id, "factory_001", game.day)
    employee_command.sync_roster()
    var productivity_after_factory := float(employee_command.get_productivity_multiplier("factory_001"))
    check(productivity_after_factory > productivity_before_factory, "Assigning employee to factory increases production productivity")

    # Advance the real simulation. daily_update() increments experience for
    # active employees and the simulation charges the current daily wages.
    var experience_before_day := -1
    for employee in state.get_value("employees", "roster", []):
        if employee is Dictionary and String(employee.get("id", "")) == hired_id:
            experience_before_day = int(employee.get("experience", 0))
            break
    var cash_before_day := int(game.cash)
    game.advance_day()
    check(int(game.day) == 2, "Advance day progresses the simulation")

    var experience_after_day := -1
    for employee in state.get_value("employees", "roster", []):
        if employee is Dictionary and String(employee.get("id", "")) == hired_id:
            experience_after_day = int(employee.get("experience", 0))
            break
    check(experience_before_day >= 0 and experience_after_day == experience_before_day + 1, "Assigned employee gains one experience on day advance")
    check(int(game.cash) != cash_before_day, "Daily simulation changes cash including employee wages")

    # Save through the actual Main -> SaveSystem -> GameState path.
    game.save_game()
    var saved_snapshot = state.capture()
    check(int(saved_snapshot.get("schema_version", 0)) == 8, "Employee integration save uses schema 8")

    # Disturb the live roster, then reload and prove the exact employee ID is
    # restored from persistent GameState data.
    state.set_value("employees", "roster", [])
    check(state.get_value("employees", "roster", []).size() == 0, "Runtime employee roster can be cleared before load")
    game.load_game()

    var restored_roster = state.get_value("employees", "roster", [])
    var restored_same_id := false
    for employee in restored_roster:
        if employee is Dictionary and String(employee.get("id", "")) == hired_id:
            restored_same_id = true
            break
    check(restored_same_id, "Same employee ID exists after save/load")

    print("EMPLOYEE INTEGRATION RESULT: %d passed, %d failed" % [passed, failed])
    game.free()
    await process_frame
    quit(1 if failed > 0 else 0)
