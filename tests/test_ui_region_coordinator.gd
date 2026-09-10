extends SceneTree

## Verifies that the UIRegionCoordinator correctly suppresses overlapping
## floating panels (StrategyHUD, TutorialOverlay) and hides them when any
## primary screen is open.
var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("run")

func check(label: String, ok: bool) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func run() -> void:
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check("Main scene loads", packed != null)
    if packed == null:
        quit(1)
        return
    var game := packed.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    await process_frame

    var hud := game.get_node_or_null("UI/MainHUD")
    var strategy := game.get_node_or_null("UI/StrategyHUD")
    var tutorial := game.get_node_or_null("UI/TutorialOverlay")
    var coordinator: Node = RenewServices.get_service("RenewUIRegionCoordinator")
    check("coordinator service resolves", coordinator != null)
    if coordinator == null:
        game.free()
        quit(1)
        return

    var registered: Array = coordinator.get_all_registered()
    check("StrategyHUD is registered", registered.has("StrategyHUD"))
    check("TutorialOverlay is registered", registered.has("TutorialOverlay"))

    var strat_panel := strategy.get("panel") as Control
    var tut_panel := tutorial.get("panel") as Control
    var strat_root := strategy.get("root") as Control
    var tut_root := tutorial.get("overlay_root") as Control

    if strat_root != null: strat_root.size = Vector2(1280, 720)
    if tut_root != null: tut_root.size = Vector2(1280, 720)
    strategy._layout_responsive()
    tutorial._layout_responsive()
    coordinator.set_active_screen("")
    await process_frame
    check("desktop strategy panel has position", strat_panel.position.x >= 0.0)
    check("desktop tutorial panel has position", tut_panel.position.x >= 0.0)

    if strat_root != null: strat_root.size = Vector2(390, 844)
    if tut_root != null: tut_root.size = Vector2(390, 844)
    strategy._layout_responsive()
    tutorial._layout_responsive()
    coordinator.set_active_screen("")
    await process_frame
    check("mobile strategy HUD hides", not strat_panel.visible)

    if strat_root != null: strat_root.size = Vector2(1280, 720)
    strategy._layout_responsive()
    tutorial._layout_responsive()
    var smgr := get_root().get_node_or_null("RenewUIScreenManager")
    if smgr != null:
        smgr.show_screen("FinancePanel")
        coordinator.set_active_screen("FinancePanel")
    await process_frame
    check("floating strategy hidden when screen open", not strat_panel.visible)
    check("floating tutorial hidden when screen open", not tut_panel.visible)

    if smgr != null:
        smgr.hide_all_screens()
    coordinator.set_active_screen("")
    await process_frame
    check("floating strategy visible after screen closes", strat_panel.visible)

    var action_dock := hud.get("action_dock") as Control
    if action_dock != null:
        var dock_rect := action_dock.get_global_rect()
        var strat_rect := strat_panel.get_global_rect()
        var overlaps := dock_rect != Rect2() and strat_rect != Rect2() and dock_rect.intersects(strat_rect)
        if overlaps:
            check("coordinator hides floater overlapping dock", not strat_panel.visible)
        else:
            check("strategy does not overlap dock at desktop size", strat_panel.visible)

    game.free()
    await process_frame
    print("COORDINATOR TEST RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)