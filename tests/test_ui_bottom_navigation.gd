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
    var bottom := hud.get("bottom_bar") as Control
    var tabs := hud.get("tabs") as HBoxContainer
    if bottom == null or tabs == null or tabs.get_child_count() != 4:
        quit(1); return
    hud.root.size = Vector2(390, 844)
    hud._layout_responsive()
    await process_frame
    if not bottom.visible or bottom.size.x < 389.0 or bottom.size.y < 57.0:
        quit(1); return
    for child in bottom.get_children():
        for button in child.get_children():
            if button is Button and (button.size.x < 44.0 or button.size.y < 44.0):
                quit(1); return
    print("BOTTOM NAVIGATION RESPONSIVE TEST: PASS")
    quit(0)
