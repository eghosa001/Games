extends SceneTree

## Verifies that the UIRegionCoordinator keeps the retired StrategyHUD
## registered but non-rendering, while the TutorialOverlay remains responsive
## and is hidden when a primary screen is open.
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
    var services = root.get_node_or_null("RenewServices")
    var coordinator: Node = services.get_service("RenewUIRegionCoordinator") if services != null else null
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
    var tut_chip := tutorial.get("collapsed_button") as Control
    var strat_root := strategy.get("root") as Control
    var tut_root := tutorial.get("overlay_root") as Control

    if strat_root != null: strat_root.size = Vector2(1700, 900)
    if tut_root != null: tut_root.size = Vector2(1700, 900)
    strategy._layout_responsive()
    tutorial._layout_responsive()
    coordinator.set_active_screen("")
    await process_frame
    check("wide desktop strategy overlay stays retired", not strat_panel.visible and strategy._get_rect() == Rect2())
    check("desktop tutorial defaults to compact guide", not tut_panel.visible and tut_chip != null and tut_chip.visible)
    check("compact guide remains inside the viewport", tut_chip != null and tut_chip.position.x >= 0.0 and tut_chip.position.y >= 0.0)

    if strat_root != null: strat_root.size = Vector2(390, 844)
    if tut_root != null: tut_root.size = Vector2(390, 844)
    strategy._layout_responsive()
    tutorial._layout_responsive()
    coordinator.set_active_screen("")
    await process_frame
    check("mobile strategy HUD hides", not strat_panel.visible)

    if strat_root != null: strat_root.size = Vector2(1700, 900)
    if tut_root != null: tut_root.size = Vector2(1700, 900)
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
    check("retired strategy remains hidden after screen closes", not strat_panel.visible)

    var action_dock := hud.get("action_dock") as Control
    if action_dock != null:
        check("retired strategy cannot overlap the command dock", not strat_panel.visible and strategy._get_rect() == Rect2())

    game.free()
    await process_frame
    print("COORDINATOR TEST RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
