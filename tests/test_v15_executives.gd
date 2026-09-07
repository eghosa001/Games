extends SceneTree

## V1.5: the C-suite. Level-4 employees take CEO/COO/CFO/CTO seats with
## company-wide bonuses; management capacity gates expansion; executive
## candidates appear once the company has standing.
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

func _executive_model() -> Node:
    var EmployeeSystem = load("res://scripts/employee_system.gd")
    var model = EmployeeSystem.new()
    root.add_child(model)
    return model

func run() -> void:
    var model = _executive_model()
    await process_frame
    check(model.EXECUTIVE_SEATS == ["CEO", "COO", "CFO", "CTO"], "Four C-suite seats exist")
    check(model.get_executives().is_empty(), "No executives at founding")

    var junior: Dictionary = model.get_employee("emp_0002")
    var blocked: Dictionary = model.appoint_executive("emp_0002", "CEO", 5)
    check(not bool(blocked.get("ok", false)), "Appointment requires career level 4")
    check(junior.get("executive_seat", "") == "", "Failed appointment grants no seat")

    var bad_seat: Dictionary = model.appoint_executive("emp_james_001", "JANITOR", 5)
    check(not bool(bad_seat.get("ok", false)), "Unknown seat is rejected")

    # Promote James to level 4 through the real promotion path.
    model.get_employee("emp_james_001")["experience"] = 100
    var p2: Dictionary = model.promote_employee("emp_james_001", 6)
    check(bool(p2.get("ok", false)), "James promotes toward executive level")
    model.get_employee("emp_james_001")["experience"] = 100
    var p3: Dictionary = model.promote_employee("emp_james_001", 7)
    check(bool(p3.get("ok", false)), "James reaches level 3")
    model.get_employee("emp_james_001")["experience"] = 100
    var p4: Dictionary = model.promote_employee("emp_james_001", 8)
    check(bool(p4.get("ok", false)), "James reaches level 4")
    check(int(model.get_employee("emp_james_001").get("level", 0)) >= 4, "James holds executive-level rank")
    var ceo: Dictionary = model.appoint_executive("emp_james_001", "ceo", 8)
    check(bool(ceo.get("ok", false)), "Level-4 founder takes the CEO seat")
    check(str(ceo.get("seat", "")) == "CEO", "Seat name normalizes to uppercase")
    check(str(model.get_employee("emp_james_001").get("role", "")) == "CEO", "Appointment grants the C-suite title")
    check(model.executive_bonus_multiplier("hiring") < 1.0, "CEO discounts hiring")
    check(model.executive_bonus_multiplier("production") == 1.0, "Empty COO seat gives no production bonus")

    # A second level-4 leader takes COO, then steals the CEO chair.
    model.employees.append(model._make_employee("emp_exec_001", "Morgan", "Supervisor", "operations", {"production": 60, "logistics": 60, "management": 80}, 60, 1600, 70, 75, 0.85, 80, 4, "hq_001", 8))
    var coo: Dictionary = model.appoint_executive("emp_exec_001", "COO", 9)
    check(bool(coo.get("ok", false)), "Second leader takes the COO seat")
    check(model.executive_bonus_multiplier("production") > 1.0, "COO boosts production")
    var coup: Dictionary = model.appoint_executive("emp_exec_001", "CEO", 10)
    check(bool(coup.get("ok", false)), "CEO chair transfers to the challenger")
    check(str(model.get_employee("emp_james_001").get("executive_seat", "")) == "", "Ousted executive loses the seat")
    check(model.executive_bonus_multiplier("hiring") < 1.0, "Hiring discount follows the CEO chair")

    var cfo: Dictionary = model.appoint_executive("emp_exec_001", "CFO", 11)
    check(bool(cfo.get("ok", false)), "Challenger moves to the CFO seat")
    check(model.executive_bonus_multiplier("operating_cost") < 1.0, "CFO trims operating costs")
    var snapshot: Dictionary = model.capture_state()
    var restored_model = load("res://scripts/employee_system.gd").new()
    root.add_child(restored_model)
    restored_model.restore_state(snapshot)
    check(str(restored_model.get_employee("emp_exec_001").get("executive_seat", "")) == "CFO", "Executive seats survive save/load")

    var fired: Dictionary = model.fire_employee("emp_exec_001", 12)
    check(bool(fired.get("ok", false)), "Executive can be dismissed")
    check(str(model.get_employee("emp_exec_001").get("executive_seat", "")) == "", "Dismissal vacates the seat")

    # Executive candidates appear once the company has standing.
    var state = root.get_node_or_null("RenewGameState")
    if state != null:
        state.set_value("player", "reputation", 25)
    model._day = 30
    model.refresh_candidates()
    var exec_found := false
    for candidate in model.get_candidates():
        if int(candidate.get("level", 1)) >= 3 and str(candidate.get("assignment", "")) == "hq_001":
            exec_found = true
    check(exec_found, "Executive candidates appear at reputation 20+")

    # Management capacity gates expansion through the live command boundary.
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for capacity gate")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        var gate: Dictionary = game.command_system.expansion_system.management_capacity()
        check(int(gate.get("capacity", 0)) >= 2, "Base management capacity covers early expansion")
        check(gate.has("used") and gate.has("executives"), "Capacity report tracks use and executives")
        game.free()
        await process_frame
    print("V15 EXECUTIVES RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
