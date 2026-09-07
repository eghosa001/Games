extends SceneTree

var passed := 0
var failed := 0

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> bool:
    if ok:
        passed += 1
        print("PASS: " + label)
        return true
    failed += 1
    push_error("FAIL: " + label)
    return false

func _run() -> void:
    var packed := load("res://scenes/Main.tscn") as PackedScene
    if not check(packed != null, "Main scene loads for responsive navigation"):
        _finish()
        return
    var scene := packed.instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    var hud := scene.get_node_or_null("UI/MainHUD")
    if not check(hud != null, "MainHUD exists"):
        scene.free()
        await process_frame
        _finish()
        return

    # MainHUD's final responsive layer intentionally uses the action dock and
    # top mode rail on phones; the legacy bottom_mobile grid is hidden.
    var mode_rail := hud.get("mode_rail") as Control
    var mode_buttons := hud.get("mode_buttons") as Array
    var action_dock := hud.get("action_dock") as Control
    var action_grid := hud.get("action_grid") as GridContainer
    check(mode_rail != null, "Mobile mode rail exists")
    check(action_dock != null, "Mobile action dock exists")
    check(action_grid != null, "Mobile action grid exists")
    check(mode_buttons.size() == 4, "Mobile mode rail has four modes")
    if mode_rail == null or action_dock == null or action_grid == null or mode_buttons.size() != 4:
        scene.free()
        await process_frame
        _finish()
        return

    hud.root.size = Vector2(390, 844)
    hud._layout_responsive()
    await process_frame

    check(mode_rail.visible, "Mode rail visible on phone")
    check(action_dock.visible, "Action dock visible on phone")
    check(action_grid.columns == 2, "Action grid uses two phone columns")
    for index in range(mode_buttons.size()):
        var button = mode_buttons[index]
        if button is Button:
            check(button.size.y >= 44.0, "Mode button %d meets 44px touch target" % (index + 1))
        else:
            check(false, "Mode button %d is a Button" % (index + 1))
    var action_index := 0
    for child in action_grid.get_children():
        if child is Button:
            action_index += 1
            check(child.custom_minimum_size.x > 0.0, "Action button %d has width" % action_index)
            check(child.custom_minimum_size.y >= 44.0, "Action button %d meets 44px touch target" % action_index)

    scene.free()
    await process_frame
    _finish()

func _finish() -> void:
    print("MOBILE RESPONSIVE NAVIGATION RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
