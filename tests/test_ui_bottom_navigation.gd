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

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size = Vector2i(390, 844)
    var state = root.get_node_or_null("RenewGameState")
    if state != null and state.has_method("clear"):
        state.clear()

    var packed := load("res://scenes/Main.tscn") as PackedScene
    var game := packed.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame

    var hud = game.get_node("UI/MainHUD")
    var nav := hud.get("bottom_nav") as Control
    check(nav != null, "bottom navigation exists")
    check(nav.position == Vector2(12, 758), "bottom navigation matches phone position")
    check(nav.size == Vector2(366, 70), "bottom navigation matches phone size")

    var buttons: Array = hud.get("mode_buttons")
    var expected := ["HOME", "BUSINESS", "PROPERTY", "FINANCE", "MORE"]
    check(buttons.size() == 5, "five navigation items")
    for i in range(5):
        var button := buttons[i] as Button
        var label := button.get_node("NavLabel") as Label
        check(label.text == expected[i], "nav label " + expected[i])
        check(button.size.y >= 48.0, "48px touch target " + expected[i])
        if not button.disabled:
            check(button.focus_mode == Control.FOCUS_ALL, "keyboard focus " + expected[i])
        else:
            check(not button.tooltip_text.is_empty(), "locked navigation explains unlock " + expected[i])

    check(not (buttons[0] as Button).disabled and not (buttons[1] as Button).disabled and not (buttons[2] as Button).disabled and not (buttons[4] as Button).disabled, "home, business, property and more are available from Level 1")
    check((buttons[3] as Button).disabled, "Finance waits for Company Level 2")

    var progression = game.get_node("Systems/StrategicProgression")
    state.set_value("progression", "xp", 100)
    state.set_value("progression", "level", 2)
    state.set_value("progression", "unlocks", [])
    progression._backfill_semantic_unlocks()
    hud._rebuild_current()
    await process_frame

    buttons = hud.get("mode_buttons")
    check(not (buttons[3] as Button).disabled, "Level 2 unlocks Finance navigation")
    (buttons[2] as Button).pressed.emit()
    await process_frame
    check(int(hud.get("active_tab")) == 2 and str(hud.get("active_view")) == "property", "Property navigation opens the building restoration screen")
    (buttons[3] as Button).pressed.emit()
    await process_frame
    check(int(hud.get("active_tab")) == 3 and str(hud.get("active_view")) == "finance", "Finance navigation opens the ledger")

    game.queue_free()
    await process_frame
    print("BOTTOM NAV: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
