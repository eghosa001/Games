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

    var market = game.get_node("UI/CustomerSegmentsUI")
    market.open_screen()
    for _frame in range(2):
        await process_frame

    var list := market.get("segment_list") as VBoxContainer
    check(list != null and list.get_child_count() > 0, "Customer segments render")
    if list == null or list.get_child_count() == 0:
        quit(1)
        return

    var first_id := list.get_child(0).get_instance_id()
    market._refresh(false)
    await process_frame
    check(list.get_child(0).get_instance_id() == first_id, "Unchanged market state preserves segment nodes")

    var state = root.get_node("RenewGameState")
    var marketing := int(state.get_value("businesses", "marketing_level", 0))
    state.set_value("businesses", "marketing_level", marketing + 1)
    market._refresh(false)
    await process_frame
    check(list.get_child(0).get_instance_id() != first_id, "Market input change rebuilds segment nodes")

    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)
