extends SceneTree

var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _init() -> void:
    call_deferred("run")

func run() -> void:
    var GameState = load("res://scripts/game_state.gd")
    var Business = load("res://scripts/business_system.gd")
    check(GameState != null, "GameState loads")
    check(Business != null, "BusinessSystem loads")
    if GameState == null or Business == null:
        quit(1)
        return

    # Reuse the canonical autoloads so the business under test reads the same
    # GameState/FinanceSystem that its DomainSystem bridge resolves via /root.
    var game_state = root.get_node_or_null("RenewGameState")
    if game_state == null:
        game_state = GameState.new()
        game_state.name = "RenewGameState"
        root.add_child(game_state)
        await process_frame
    elif game_state.has_method("clear"):
        game_state.clear()
        await process_frame
    var finance = root.get_node_or_null("RenewFinanceSystem")
    if finance != null and finance.has_method("record_equity"):
        finance.cash = 25000
        finance.debt = 0
        finance.financing = {}
        finance.revenue = 0.0
        finance.operating_expenses = 0.0
        finance.interest_expense = 0.0
        finance.retained_earnings = 0.0
        finance.equity_contributed = 25000.0
        finance.record_equity(475000, "v1 industry test capitalization")

    game_state.set_value("properties", "owned", true)
    game_state.set_value("properties", "stage", "Operational")
    game_state.set_value("properties", "catalog", [{"id":"test_property","name":"Test Property","type":"Warehouse"}])
    game_state.set_value("properties", "selected_property", 0)
    if finance != null:
        game_state.set_value("economy", "cash", int(finance.get("cash")))

    var business = Business.new()
    root.add_child(business)
    await process_frame

    # Each test uses the same authoritative business production entry point,
    # changing only the selected V1 industry. Supply inputs are procured through
    # the canonical Economy -> SupplyChain -> Warehouse path.
    var industries := [
        {"id":"furniture","purpose":"furniture_factory","product":"furniture"},
        {"id":"construction_materials","purpose":"construction_materials_factory","product":"construction_materials"},
        {"id":"consumer_electronics","purpose":"consumer_electronics_factory","product":"consumer_electronics"}
    ]

    for industry in industries:
        game_state.set_value("businesses", "business_open", true)
        game_state.set_value("businesses", "business_name", str(industry["id"]).capitalize())
        game_state.set_value("businesses", "business_purpose", str(industry["purpose"]))
        game_state.set_value("businesses", "industry_id", str(industry["id"]))
        game_state.set_value("businesses", "capacity_level", 1)
        var before: float = business.supply_chain.stock(str(industry["product"]))
        business.produce_goods()
        var after: float = business.supply_chain.stock(str(industry["product"]))
        check(after > before, "%s production succeeds" % str(industry["id"]))
        var last_run: Dictionary = {}
        if business.production != null and business.production.get("last_run") is Dictionary:
            last_run = business.production.get("last_run")
        check(str(last_run.get("industry_id", "")) == str(industry["id"]), "%s dispatches through industry_id" % str(industry["id"]))

    print("V1 INDUSTRY PRODUCTION RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
