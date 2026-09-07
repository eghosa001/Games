extends SceneTree

## Performance budgets. Grid rebuilds, panel refreshes and day advances
## must stay far inside generous headless budgets on every run.
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
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for profiling")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    var hud: Node = game.get_node_or_null("UI/MainHUD")
    var start := Time.get_ticks_msec()
    for i in range(20):
        hud._set_tab(i % 4)
    var grid_ms := float(Time.get_ticks_msec() - start) / 20.0
    check(grid_ms < 1000.0, "Grid rebuild averages under budget")
    var manager = root.get_node_or_null("RenewUIScreenManager")
    var panels := ["DashboardPanel", "FinancePanel", "PortfolioPanel", "CorporationsPanel"]
    start = Time.get_ticks_msec()
    for screen_name in panels:
        var panel: Node = game.get_node_or_null("UI/" + screen_name)
        for i in range(10):
            panel._refresh(true)
    var panel_ms := float(Time.get_ticks_msec() - start) / 40.0
    check(panel_ms < 1000.0, "Panel refresh averages under budget")
    var state = root.get_node_or_null("RenewGameState")
    game.cash = 250000
    game.day = 1
    game.inspect_property()
    game.acquire_property()
    var guard := 0
    while str(state.get_value("properties", "stage", "")) != "Operational" and guard < 20:
        game.restore_property()
        guard += 1
        await process_frame
    game.choose_business_purpose(0)
    game.open_business()
    start = Time.get_ticks_msec()
    for i in range(10):
        game.advance_day()
        await process_frame
    var day_ms := float(Time.get_ticks_msec() - start) / 10.0
    check(day_ms < 30000.0, "Day advance averages under budget")
    print("PERF grid=%.1fms panel=%.1fms day=%.1fms" % [grid_ms, panel_ms, day_ms])
    game.free()
    await process_frame
    print("V98 PERFORMANCE RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
