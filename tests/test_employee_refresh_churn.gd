extends SceneTree

var failed := 0

func check(ok: bool, label: String) -> void:
    if not ok:
        failed += 1
        push_error("FAIL: " + label)

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size = Vector2i(390, 844)
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check(packed != null, "Main scene loads")
    if packed == null:
        quit(1)
        return

    var game = packed.instantiate()
    root.add_child(game)
    current_scene = game
    for _frame in range(4):
        await process_frame

    var employee = game.get_node("UI/EmployeePanel")
    employee.open_screen()
    for _frame in range(2):
        await process_frame

    var list := employee.get("employee_list") as VBoxContainer
    check(list != null and list.get_child_count() > 0, "Employee roster renders")
    if list == null or list.get_child_count() == 0:
        quit(1)
        return

    var first_id := list.get_child(0).get_instance_id()
    employee._refresh(false)
    await process_frame
    check(list.get_child(0).get_instance_id() == first_id, "Unchanged roster preserves employee nodes")

    var state = root.get_node("RenewGameState")
    var roster = state.get_value("employees", "roster", [])
    if roster is Array and not roster.is_empty() and roster[0] is Dictionary:
        roster = roster.duplicate(true)
        roster[0]["name"] = str(roster[0].get("name", "Employee")) + " QA"
        state.set_value("employees", "roster", roster)
        employee._refresh(false)
        await process_frame
        check(list.get_child(0).get_instance_id() != first_id, "Roster change rebuilds employee nodes")
    else:
        check(false, "Initial roster is available for refresh regression")

    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)
