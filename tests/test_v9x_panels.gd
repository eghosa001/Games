extends SceneTree

## V9 screens. Dashboard, finance, portfolio and corporation panels bind
## authoritative systems, route actions through Main, and navigate cleanly.
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

func _panel(game: Node, names: Array) -> Dictionary:
    var out := {}
    for screen_name in names:
        var node: Node = game.get_node_or_null("UI/" + str(screen_name))
        if node != null:
            out[str(screen_name)] = node
    return out

func run() -> void:
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for screen audit")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    var names := ["DashboardPanel", "FinancePanel", "PortfolioPanel", "CorporationsPanel"]
    var panels := _panel(game, names)
    check(panels.size() == 4, "Four new screens mounted")
    var manager = root.get_node_or_null("RenewUIScreenManager")
    check(manager != null, "Screen manager available")
    manager.show_screen("DashboardPanel")
    await process_frame
    check(str(manager.get_active_screen_name()) == "DashboardPanel", "Dashboard opens")
    manager.show_screen("FinancePanel")
    await process_frame
    check(str(manager.get_active_screen_name()) == "FinancePanel", "Finance takes focus")
    check(not bool(manager.is_screen_open("DashboardPanel")), "Screens stay exclusive")
    manager.hide_all_screens()
    await process_frame

    var state = root.get_node_or_null("RenewGameState")
    game.cash = 250000
    game.day = 1
    game.inspect_property()
    game.acquire_property()
    var dashboard: Node = panels["DashboardPanel"]
    dashboard._refresh(true)
    check(str(dashboard.overview_label.text).to_lower().find("day") >= 0, "Dashboard shows overview")
    check(str(dashboard.objective_label.text).find("NEXT") >= 0, "Dashboard names the objective")
    check(not str(dashboard.primary_button.text).is_empty(), "Dashboard offers a primary action")
    var ledger: Node = panels["FinancePanel"]
    ledger._refresh(true)
    check(str(ledger.overview_label.text).to_lower().find("cash") >= 0, "Finance shows the ledger")
    check(str(ledger.credit_label.text).to_lower().find("credit") >= 0, "Finance shows credit standing")
    var portfolio: Node = panels["PortfolioPanel"]
    portfolio._refresh(true)
    check(str(portfolio.list_label.text).find("Riverside") >= 0, "Portfolio lists surveyed assets")
    var before := int(state.get_value("properties", "selected_property", 0))
    portfolio._next()
    check(int(state.get_value("properties", "selected_property", 0)) != before, "Portfolio cycles selection")
    portfolio.sell_button.pressed.emit()
    await process_frame
    check(not bool(state.get_value("properties", "owned", false)), "Portfolio sells through Main")
    var network: Node = panels["CorporationsPanel"]
    network._refresh(true)
    check(str(network.list_label.text).find("Apex") >= 0, "Network lists live rivals")
    network.next_button.pressed.emit()
    await process_frame
    check(int(state.get_value("competitors", "selected_rival", 0)) == 1, "Network cycles rivals")
    network.offer_button.pressed.emit()
    await process_frame
    check(not str(state.get_value("company", "message", "")).is_empty(), "Network offers through Main")

    var hud: Node = game.get_node_or_null("UI/MainHUD")
    hud._set_tab(0)
    await process_frame
    await process_frame
    var texts := {}
    for child in (hud.get("action_grid") as Node).get_children():
        if child is Button:
            texts[str((child as Button).text)] = child
    check(texts.has("DASHBOARD") and texts.has("PROPERTY") and texts.has("OWNERSHIP"), "LIVE hub links dashboard and focused property workspaces")
    (texts["DASHBOARD"] as Button).pressed.emit()
    await process_frame
    await process_frame
    check(str(manager.get_active_screen_name()) == "DashboardPanel", "Grid opens the dashboard")
    manager.hide_all_screens()
    game.free()
    await process_frame
    print("V9 SCREENS RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
