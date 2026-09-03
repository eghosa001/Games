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
    var State = load("res://scripts/game_state.gd")
    var Business = load("res://scripts/business_system.gd")
    check(State != null, "GameState script loads")
    check(Business != null, "BusinessSystem script loads")
    if State == null or Business == null:
        quit(1)
        return

    var state = State.new()
    state.name = "RenewGameState"
    root.add_child(state)
    await process_frame

    var catalog := [{"id":"warehouse_001","name":"Riverside Warehouse","type":"Warehouse","condition":100,"cleaning":100,"repair":100,"painting":100,"furnishing":100,"value":65000,"capacity":80,"industry_compatibility":["Logistics","Manufacturing","Wholesale"]}]
    state.set_value("properties", "catalog", catalog)
    state.set_value("properties", "selected_property", 0)
    state.set_value("properties", "owned", true)
    state.set_value("properties", "stage", "Operational")
    state.set_value("properties", "restoration", 100)
    state.set_value("economy", "cash", 25000)

    var business = Business.new()
    root.add_child(business)
    await process_frame

    check(business.get_industries().size() == 3, "Exactly three V1 industries exist")
    check(business.get_industry("furniture").get("name", "") == "Furniture", "Furniture industry exists")
    check(business.get_industry("construction_materials").get("name", "") == "Construction Materials", "Construction Materials industry exists")
    check(business.get_industry("consumer_electronics").get("name", "") == "Consumer Electronics", "Consumer Electronics industry exists")
    for industry_id in ["furniture", "construction_materials", "consumer_electronics"]:
        var industry := business.get_industry(industry_id)
        check(industry.get("inputs", {}) is Dictionary and not industry.get("inputs", {}).is_empty(), "%s has inputs" % industry.get("name", industry_id))
        check(industry.get("output", {}) is Dictionary and not industry.get("output", {}).is_empty(), "%s has output" % industry.get("name", industry_id))
        check(int(industry.get("workers", 0)) > 0, "%s has workers" % industry.get("name", industry_id))
        check(int(industry.get("capacity", 0)) > 0, "%s has capacity" % industry.get("name", industry_id))
        check(int(industry.get("operating_cost", -1)) >= 0, "%s has operating cost" % industry.get("name", industry_id))
        check(int(industry.get("base_price", 0)) > 0, "%s has base price" % industry.get("name", industry_id))
        check(int(industry.get("market_demand", 0)) > 0, "%s has market demand" % industry.get("name", industry_id))

    check(business.get_business_purposes().size() == 3, "Warehouse exposes three industry purposes")
    check(business.get_business_purpose(0).get("name", "") == "Furniture Factory", "Warehouse can become Furniture Factory")

    business.choose_business_purpose(0)
    check(state.get_value("businesses", "business_open", false) == true, "Choosing purpose creates business")
    check(state.get_value("businesses", "business_name", "") == "Furniture Factory", "Business name is Furniture Factory")
    check(state.get_value("businesses", "business_purpose", "") == "furniture_factory", "Business purpose is canonical")
    check(state.get_value("businesses", "industry_id", "") == "furniture", "Business stores canonical industry")
    check(state.get_value("businesses", "origin_property_id", "") == "warehouse_001", "Business stores origin property ID")
    check(state.get_value("businesses", "origin_property_name", "") == "Riverside Warehouse", "Business stores origin property name")
    check(state.get_value("businesses", "origin_property_type", "") == "Warehouse", "Business stores origin property type")
    check(state.get_value("economy", "cash", 0) == 22000, "Business launch consumes working capital")
    check(state.get_value("player", "reputation", 0) == 2, "Business creation grants launch reputation")

    business.open_business()
    check(state.get_value("businesses", "business_open", false) == true, "Opening an existing business is idempotent")

    print("PHASE 20 RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
