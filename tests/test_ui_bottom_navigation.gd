extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load("res://scenes/Main.tscn") as PackedScene
    if packed == null:
        quit(1); return
    var scene := packed.instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    var hud := scene.get_node_or_null("UI/MainHUD")
    if hud == null:
        quit(1); return

    # MainHUD's final responsive layer intentionally uses the action dock and
    # top mode rail on phones; the legacy bottom_mobile grid is hidden.
    var mode_rail := hud.get("mode_rail") as Control
    var mode_buttons := hud.get("mode_buttons") as Array
    var action_dock := hud.get("action_dock") as Control
    var action_grid := hud.get("action_grid") as GridContainer
    if mode_rail == null or action_dock == null or action_grid == null or mode_buttons.size() != 4:
        quit(1); return

    hud.root.size = Vector2(390, 844)
    hud._layout_responsive()
    await process_frame

    if not mode_rail.visible or not action_dock.visible or action_grid.columns != 2:
        quit(1); return
    for button in mode_buttons:
        if button is Button and button.size.y < 44.0:
            quit(1); return
    for child in action_grid.get_children():
        if child is Button and (child.custom_minimum_size.x <= 0.0 or child.custom_minimum_size.y < 44.0):
            quit(1); return

    print("MOBILE RESPONSIVE NAVIGATION TEST: PASS")
    quit(0)
