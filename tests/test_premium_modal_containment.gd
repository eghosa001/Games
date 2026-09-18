extends SceneTree

var failed := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
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
    root.size = Vector2i(1280, 720)
    root.size_changed.emit()
    for _frame in range(3):
        await process_frame

    var manager := root.get_node_or_null("RenewUIScreenManager")
    var skin := game.get_node_or_null("UI/MainHUD/PremiumUISkin")
    check("screen manager exists", manager != null)
    check("premium skin exists", skin != null)
    if manager == null or skin == null:
        game.queue_free()
        await process_frame
        quit(1)
        return

    for screen_name in ["EmployeePanel", "WorldOpportunitiesPanel"]:
        manager.show_screen(screen_name)
        await process_frame
        if skin.has_method("_refresh_active_screen"):
            skin.call("_refresh_active_screen")
        await process_frame
        var screen := game.get_node_or_null("UI/" + screen_name)
        check("%s opens" % screen_name, screen != null and manager.is_screen_open(screen_name))
        if screen != null:
            var buttons: Array[Button] = []
            collect_buttons(screen, buttons)
            for button in buttons:
                if not button.is_visible_in_tree():
                    continue
                var rect := button.get_global_rect()
                check("%s button inside desktop viewport: %s" % [screen_name, button.text], Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(rect))
        manager.hide_all_screens()
        await process_frame

    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)

func collect_buttons(node: Node, out: Array[Button]) -> void:
    if node is Button:
        out.append(node as Button)
    for child in node.get_children():
        collect_buttons(child, out)

func check(label: String, condition: bool) -> void:
    if condition:
        print("PASS: %s" % label)
    else:
        failed += 1
        push_error("FAIL: %s" % label)
