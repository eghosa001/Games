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
    manager.show_screen("HistoryPanel")
    await process_frame
    var history := game.get_node("UI/HistoryPanel")
    var panel := history.get("panel") as Control
    var title := history.get("title_label") as Label
    var close := history.get("close_button") as Button
    var tabs_scroll := history.get("tabs_scroll") as ScrollContainer
    var viewport := Rect2(Vector2.ZERO, Vector2(root.size))
    check("History panel stays in phone viewport", viewport.encloses(panel.get_global_rect()))
    check("History Close stays in phone viewport", viewport.encloses(close.get_global_rect()))
    check("History title clears Close", not title.get_global_rect().intersects(close.get_global_rect()))
    check("History tabs stay inside panel width", panel.get_global_rect().encloses(tabs_scroll.get_global_rect()))
    manager.hide_all_screens()
    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)
