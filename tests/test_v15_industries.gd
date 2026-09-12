extends SceneTree

## V1.5: Construction Materials and Consumer Electronics are fully playable
## industries across demand, segments, production config, upstream economy,
## contracts and balance data — not just business-system entries.
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
    var DemandModel = load("res://scripts/demand_model.gd")
    var Segments = load("res://scripts/customer_segment_system.gd")
    var Production = load("res://scripts/production_system.gd")
    var Economy = load("res://scripts/economy.gd")
    check(DemandModel != null, "Demand model loads")
    check(Segments != null, "Customer segments load")
    check(Production != null, "Production system loads")
    check(Economy != null, "Economy loads")
    if DemandModel == null or Segments == null or Production == null or Economy == null:
        quit(1)
        return

    # DemandModel, customer segments, and Economy are RefCounted helpers. They
    # must not be attached to the SceneTree or queue_free()'d like Nodes.
    var demand = DemandModel.new()
    var segments = Segments.new()
    var production = Production.new()
    root.add_child(production)
    await process_frame
    var economy = Economy.new()

    for product in ["construction_materials", "consumer_electronics"]:
        var config: Dictionary = demand.get_product_config(product)
        check(not config.is_empty(), "%s has a demand configuration" % product)
        var calc: Dictionary = demand.calculate(product, 150.0, 160.0, 20, 78, 1, 0, 1.0, 1.0, 0.0, 0.0, 0.0)
        check(bool(calc.get("ok", false)), "%s demand calculates" % product)
        check(int(calc.get("demand", 0)) > 0, "%s has nonzero customer demand" % product)
        check(calc.get("modifiers", {}).has("culture_quality"), "%s demand exposes culture modifier" % product)
        var seg: Dictionary = segments.calculate(product, 150.0, 160.0, 78, 20, 1, 1.0)
        check(bool(seg.get("ok", false)), "%s segment demand calculates" % product)
        check(int(seg.get("demand", 0)) > 0, "%s has nonzero segment demand" % product)
        var prod_config: Dictionary = production.get_product_config(product)
        check(not prod_config.is_empty(), "%s has a production configuration" % product)
        check(not bool(production.produce(economy, 0, "not_a_product").get("ok", true)), "Unknown product rejected")
        var upstream: Dictionary = economy.register_customer_demand(product, 5.0)
        check(bool(upstream.get("ok", false)), "%s sale creates upstream resource demand" % product)
        check(not (upstream.get("resource_demand", {}) as Dictionary).is_empty(), "%s upstream demand is nonempty" % product)

    var contracts = root.get_node_or_null("RenewContractSystem")
    check(contracts != null, "Contract system autoload is available")
    if contracts != null:
        var furniture_contract: Dictionary = contracts.create_default_customer_contract(1, 40, "furniture")
        check(bool(furniture_contract.get("ok", false)), "Furniture contract can be created")
        var materials_contract: Dictionary = contracts.create_default_customer_contract(1, 40, "construction_materials")
        check(bool(materials_contract.get("ok", false)), "Construction materials contract can be created")
        check(str(materials_contract.get("contract", {}).get("resource_product", "")) == "construction_materials", "Contract stores the industry product")
        var electronics_contract: Dictionary = contracts.create_default_customer_contract(1, 40, "consumer_electronics")
        check(bool(electronics_contract.get("ok", false)), "Consumer electronics contract can be created")

    var data_text := FileAccess.get_file_as_string("res://data/industries.json")
    var data: Dictionary = JSON.parse_string(data_text)
    check(not data.is_empty(), "Industries balance data parses")
    var data_industries: Dictionary = data.get("industries", {})
    for industry_id in ["furniture", "construction_materials", "consumer_electronics"]:
        check(data_industries.has(industry_id), "Balance data defines %s" % industry_id)
        var entry: Dictionary = data_industries.get(industry_id, {})
        check(float(entry.get("inputs", {}).get("energy", 0.0)) > 0.0, "%s balance entry has energy inputs" % industry_id)
        check(int(entry.get("base_price", 0)) > 0, "%s balance entry has a base price" % industry_id)

    print("V15 INDUSTRIES RESULT: %d passed, %d failed" % [passed, failed])
    demand = null
    segments = null
    economy = null
    production.queue_free()
    await process_frame
    production = null
    quit(1 if failed > 0 else 0)
