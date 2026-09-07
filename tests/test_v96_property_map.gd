extends SceneTree

## World map milestone: every catalog property is drawn from authoritative
## state with stage/owned/lease visuals, and clicks select through the
## property system.
var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func run() -> void:
    var Map = load("res://scripts/property_map.gd")
    check(Map != null, "Property map loads")
    if Map == null:
        quit(1)
        return
    var state = root.get_node_or_null("RenewGameState")
    check(state != null, "GameState is available")
    if state == null:
        quit(1)
        return
    if state.has_method("clear"):
        state.clear()
    var probe: Node = Map.new()
    check(probe.stage_of({"cleaning": 0}, false) == 0, "Unowned reads abandoned")
    check(probe.stage_of({"cleaning": 100, "repair": 0}, true) == 1, "Cleaned stage maps")
    check(probe.stage_of({"cleaning": 100, "repair": 100, "painting": 100, "furnishing": 100}, true) == 5, "Finished reads restored")
    check(probe.stage_of({"cleaning": 100, "repair": 100, "painting": 100, "furnishing": 60}, true) == 4, "Furnishing stage maps")
    probe.free()

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads with the map")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    var map: Node = game.get_node_or_null("World/PropertyMap")
    check(map != null, "Map mounted in the world")
    if map == null:
        game.free()
        quit(1)
        return
    var slots: Array = map.map_rects()
    check(slots.size() == 9, "Nine properties on the map")
    var inside_viewport := true
    for slot in slots:
        var rect: Rect2 = slot["rect"]
        if rect.position.x < 0.0 or rect.position.y < 0.0:
            inside_viewport = false
    check(inside_viewport, "Map stays on screen")
    var overlap := false
    for i in range(slots.size()):
        for j in range(i + 1, slots.size()):
            if (slots[i]["rect"] as Rect2).intersects(slots[j]["rect"] as Rect2):
                overlap = true
    check(not overlap, "Buildings never overlap")
    var hud: Node = game.get_node_or_null("UI/MainHUD")
    if hud != null:
        var dock: Variant = hud.get("action_dock")
        if dock is Control and (dock as Control).visible:
            var clear := true
            for slot in slots:
                if ((slot as Dictionary)["rect"] as Rect2).end.y > (dock as Control).position.y:
                    clear = false
            check(clear, "Map stays clear of the command dock")
    var sig_before: String = str(map._signature())
    game.inspect_property()
    game.acquire_property()
    await process_frame
    check(map._signature() != sig_before, "Ownership changes the map")
    var target: Rect2 = (slots[2] as Dictionary)["rect"]
    var click := InputEventMouseButton.new()
    click.pressed = true
    click.button_index = MOUSE_BUTTON_LEFT
    click.position = target.get_center()
    map._unhandled_input(click)
    await process_frame
    check(int(state.get_value("properties", "selected_property", -1)) == 2, "Map click selects property")
    game.free()
    await process_frame
    print("V96 PROPERTY MAP RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
