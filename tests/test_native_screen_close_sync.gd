extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _run() -> void:
    root.size = Vector2i(390, 844)
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check(packed != null, "Main scene loads")
    if packed == null:
        quit(1)
        return

    var game := packed.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame

    var manager := root.get_node_or_null("RenewUIScreenManager")
    var hud := game.get_node_or_null("UI/MainHUD")
    var history := game.get_node_or_null("UI/HistoryPanel")
    var collection := game.get_node_or_null("UI/CollectionPanel")
    check(manager != null, "Screen manager available")
    check(hud != null, "Command HUD available")
    check(history != null, "History panel available")
    check(collection != null, "Collection panel available")
    if manager == null or hud == null or history == null or collection == null:
        game.queue_free()
        await process_frame
        quit(1)
        return

    manager.show_screen("HistoryPanel")
    await process_frame
    check(manager.get_active_screen_name() == "HistoryPanel", "History is manager-owned while open")
    check(not bool(hud.visible), "Command HUD hides behind History")
    history.close_screen()
    check(not bool(manager._is_node_visible(history)), "Hidden History child panel makes CanvasLayer logically closed")
    manager._process(0.11)
    check(manager.get_active_screen_name().is_empty(), "Manager releases self-closed History within active scan interval")
    check(bool(hud.visible), "Command HUD returns after native History close")

    manager.show_screen("CollectionPanel")
    await process_frame
    check(manager.get_active_screen_name() == "CollectionPanel", "Collection is manager-owned while open")
    check(not bool(hud.visible), "Command HUD hides behind Collection")
    collection.close_screen()
    check(not bool(manager._is_node_visible(collection)), "Hidden Collection child panel makes CanvasLayer logically closed")
    manager._process(0.11)
    check(manager.get_active_screen_name().is_empty(), "Manager releases self-closed Collection within active scan interval")
    check(bool(hud.visible), "Command HUD returns after native Collection close")

    game.queue_free()
    await process_frame

    print("NATIVE SCREEN CLOSE SYNC RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
