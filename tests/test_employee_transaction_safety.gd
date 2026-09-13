extends SceneTree

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

func run() -> void:
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check(packed != null, "Main scene loads")
    if packed == null:
        quit(1)
        return
    var game = packed.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame

    var command = game.get_node_or_null("GameplayCommandSystem")
    var finance = root.get_node_or_null("RenewFinanceSystem")
    check(command != null, "GameplayCommandSystem resolves")
    check(finance != null, "FinanceSystem resolves")
    if command == null or finance == null:
        game.free()
        quit(1)
        return
    var employee_commands = command.get("employee_system")
    check(employee_commands != null, "Employee command layer resolves")
    if employee_commands == null:
        game.free()
        quit(1)
        return

    finance.receive(5000, "employee transaction test funding")
    var cash_before := int(finance.available_cash())
    var employee_before: Dictionary = employee_commands.employee_system.capture_state()
    employee_commands.train_employee("missing_employee_id")
    check(int(finance.available_cash()) == cash_before, "Failed training restores exact cash balance")
    check(employee_commands.employee_system.capture_state() == employee_before, "Failed training restores employee state")

    game.free()
    await process_frame
    print("EMPLOYEE TRANSACTION RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
