extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("run")

func check(condition: bool, label: String) -> void:
    if condition:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _find_named(node: Node, wanted: String) -> Node:
    if node.name == wanted:
        return node
    for child in node.get_children():
        var found := _find_named(child, wanted)
        if found != null:
            return found
    return null

func run() -> void:
    var packed = load("res://scenes/Main.tscn")
    check(packed != null, "command deck Main scene parses")
    if packed == null:
        quit(1)
        return

    var game = packed.instantiate()
    game.name = "Renew"
    root.add_child(game)
    await process_frame
    await process_frame

    var hud = game.get_node_or_null("UI/MainHUD")
    check(hud != null, "command deck HUD exists")
    if hud == null:
        quit(1)
        return

    for nav_name in ["Nav_LIVE", "Nav_BUSINESS", "Nav_EMPIRE", "Nav_WORLD"]:
        check(_find_named(hud, nav_name) != null, "command deck exposes %s" % nav_name)

    var manager = root.get_node_or_null("RenewUIScreenManager")
    check(manager != null, "command deck screen manager exists")

    var linked_screens := [
        "DashboardPanel", "PortfolioPanel", "SaveLoadPanel",
        "ProductionControlPanel", "CustomerSegmentsUI", "ContractPanel", "EmployeePanel", "FinancePanel",
        "EmpireExpansionPanel", "HeadquartersPanel", "TechnologyPanel", "CorporationsPanel", "AlliancePanel", "SupplyChainPanel",
        "RegionsPanel", "WorldOpportunitiesPanel", "InfrastructurePanel", "LiveOpsPanel", "NewsPanel"
    ]
    for screen_name in linked_screens:
        var screen = game.get_node_or_null("UI/" + screen_name)
        if screen == null:
            screen = game.get_node_or_null(screen_name)
        check(screen != null, "command deck target exists: %s" % screen_name)

    if manager != null:
        for screen_name in ["DashboardPanel", "ProductionControlPanel", "EmpireExpansionPanel", "RegionsPanel"]:
            manager.show_screen(screen_name)
            await process_frame
            check(manager.get_active_screen_name() == screen_name, "command deck opens %s" % screen_name)
            manager.hide_all_screens()
            await process_frame

    game.queue_free()
    await process_frame
    print("\nCOMMAND DECK UI TEST: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
