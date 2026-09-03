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

    var game_state = GameState.new()
    game_state.name = "RenewGameState"
    root.add_child(game_state)
    await process_frame

    game_state.set_value("properties", "owned", true)
    game_state.set_value("properties", "stage", "Operational")
    game_state.set_value("properties", "catalog", [{"id":"test_property","name":"Test Property","type":"Warehouse"}])
    game_state.set_value("properties", "selected_property", 0)
    game_state.set_value("economy", "cash", 500000)

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
        check(str(business.production.last_run.get("industry_id", "")) == str(industry["id"]), "%s dispatches through industry_id" % str(industry["id"]))

    print("V1 INDUSTRY PRODUCTION RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
