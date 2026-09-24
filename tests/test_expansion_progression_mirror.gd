extends SceneTree

var failed := 0

func check(ok: bool, label: String) -> void:
    if not ok:
        failed += 1
        push_error("FAIL: " + label)

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check(packed != null, "Main scene loads")
    if packed == null:
        quit(1)
        return

    var game = packed.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame

    var state = root.get_node_or_null("RenewGameState")
    check(state != null, "GameState resolves")
    if state == null:
        quit(1)
        return

    state.set_value("economy","cash",200000)
    state.set_value("player","reputation",100)
    game.select_expansion(0)
    game.buy_expansion()
    await process_frame

    var mirror = state.get_value("branches","expansion",{})
    var properties = mirror.get("properties",[]) if mirror is Dictionary else []
    check(properties is Array and properties.size()>0 and bool(properties[0].get("owned",false)),"Expansion purchase updates progression mirror immediately")

    game.upgrade_expansion()
    await process_frame
    mirror=state.get_value("branches","expansion",{})
    properties=mirror.get("properties",[]) if mirror is Dictionary else []
    check(properties is Array and properties.size()>0 and int(properties[0].get("level",0))>=2,"Expansion upgrade updates progression mirror immediately")

    game.queue_free()
    await process_frame
    quit(1 if failed>0 else 0)
