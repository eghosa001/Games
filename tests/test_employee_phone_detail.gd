extends SceneTree

var failed := 0

func check(label: String, ok: bool) -> void:
    if not ok:
        failed += 1
        push_error("FAIL: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size = Vector2i(390, 844)
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check("Main scene loads", packed != null)
    if packed == null:
        quit(1)
        return
    var game := packed.instantiate()
    root.add_child(game)
    current_scene = game
    for _frame in range(4):
        await process_frame
    var manager := root.get_node_or_null("RenewUIScreenManager")
    check("screen manager resolves", manager != null)
    if manager == null:
        quit(1)
        return
    manager.show_screen("EmployeePanel")
    await process_frame
    var employee := game.get_node("UI/EmployeePanel")
    var detail := employee.get("_detail_scroll") as ScrollContainer
    var actions := employee.get("_actions") as GridContainer
    check("Employee phone detail gets readable height", detail != null and detail.size.y >= 124.0)
    check("Employee actions start after detail viewport", detail != null and actions != null and actions.get_global_rect().position.y >= detail.get_global_rect().end.y)
    manager.hide_all_screens()
    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)
