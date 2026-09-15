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
        _finish(); return
    var scene := packed.instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    var hud := scene.get_node_or_null("UI/MainHUD")
    if not check(hud != null, "MainHUD exists"):
        scene.free(); await process_frame; _finish(); return

    var mode_rail := hud.get("mode_rail") as Control
    var mode_buttons := hud.get("mode_buttons") as Array
    var action_dock := hud.get("action_dock") as Control
    var action_grid := hud.get("action_grid") as GridContainer
    check(mode_rail != null, "Primary navigation rail exists")
    check(action_dock != null, "Action dock exists")
    check(action_grid != null, "Action grid exists")
    check(mode_buttons.size() == 4, "Primary navigation has four sectors")
    if mode_rail == null or action_dock == null or action_grid == null or mode_buttons.size() != 4:
        scene.free(); await process_frame; _finish(); return

    hud.root.size = Vector2(390, 844)
    hud._layout_responsive()
    await process_frame

    check(mode_rail.visible, "Navigation visible on phone")
    check(action_dock.visible, "Action dock visible on phone")
    check(action_grid.columns == 1, "Narrow phone uses one readable action column")
    var expected := ["HOME", "BUSINESS", "EMPIRE", "WORLD"]
    for index in range(mode_buttons.size()):
        var button = mode_buttons[index]
        check(button is Button, "Mode button %d is a Button" % (index + 1))
        if button is Button:
            check(button.text == expected[index], "Mode button %d has authored label" % (index + 1))
            check(button.size.y >= 48.0, "Mode button %d meets 48px touch target" % (index + 1))
            check(button.focus_mode == Control.FOCUS_ALL, "Mode button %d supports focus navigation" % (index + 1))
    var action_index := 0
    for child in action_grid.get_children():
        if child is Button:
            action_index += 1
            check(child.custom_minimum_size.x > 0.0, "Action button %d has width" % action_index)
            check(child.custom_minimum_size.y >= 48.0, "Action button %d meets 48px touch target" % action_index)
            check(child.focus_mode == Control.FOCUS_ALL, "Action button %d supports focus navigation" % action_index)

    scene.free()
    await process_frame
    _finish()

func _finish() -> void:
    print("MOBILE RESPONSIVE NAVIGATION RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)