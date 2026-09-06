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
    var bottom := hud.get("bottom_mobile") as Control
    var tabs := hud.get("mobile_mode_row") as HBoxContainer
    if bottom == null or tabs == null or tabs.get_child_count() != 4:
        quit(1); return
    hud.root.size = Vector2(390, 844)
    hud._layout_responsive()
    await process_frame
    if not bottom.visible or bottom.size.x <= 0.0 or bottom.size.y < 44.0:
        quit(1); return
    for child in tabs.get_children():
        if child is Button and (child.custom_minimum_size.x < 44.0 or child.custom_minimum_size.y < 44.0):
            quit(1); return
    print("BOTTOM NAVIGATION RESPONSIVE TEST: PASS")
    quit(0)
