extends SceneTree

## Modal/input/focus audit. Screens stay exclusive, ESC closes, grids
## rebuild stably, and unknown screens never crash.
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

func _esc(manager: Node) -> void:
    var ev := InputEventKey.new()
    ev.keycode = KEY_ESCAPE
    ev.pressed = true
    manager._unhandled_input(ev)

func run() -> void:
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for modal audit")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    var manager = root.get_node_or_null("RenewUIScreenManager")
    check(manager != null, "Screen manager available")
    if manager == null:
        game.free()
        quit(1)
        return
    var names := ["DashboardPanel", "FinancePanel", "PortfolioPanel", "CorporationsPanel", "AlliancePanel", "ContractPanel", "NewsPanel", "HistoryPanel"]
    for screen_name in names:
        manager.show_screen(screen_name)
        await process_frame
        check(str(manager.get_active_screen_name()) == screen_name, screen_name + " takes focus")
    manager.show_screen("NoSuchScreen")
    await process_frame
    check(str(manager.get_active_screen_name()) == "HistoryPanel", "Unknown screens ignored safely")
    _esc(manager)
    await process_frame
    var any_open := false
    for screen_name in names:
        if bool(manager.is_screen_open(screen_name)):
            any_open = true
    check(not any_open, "ESC clears every screen")
    var hud: Node = game.get_node_or_null("UI/MainHUD")
    check(hud != null, "Action grid found")
    hud._set_tab(2)
    await process_frame
    await process_frame
    var grid: Node = hud.get("action_grid")
    var first_count := (grid as Node).get_child_count()
    var stable := true
    for i in range(30):
        hud._refresh()
        await process_frame
        if (grid as Node).get_child_count() != first_count:
            stable = false
    check(stable, "Grid rebuilds stably")
    var valid := true
    for child in (grid as Node).get_children():
        if child is Button:
            var found := false
            for connection in (child as Button).pressed.get_connections():
                if (connection.get("callable", Callable()) as Callable).is_valid():
                    found = true
            if not found:
                valid = false
    check(valid, "Rebuilt buttons stay connected")
    game.free()
    await process_frame
    print("V97 MODAL FOCUS RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
