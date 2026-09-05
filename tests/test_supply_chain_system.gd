extends SceneTree

# Unit test boundary: instantiate the authoritative SupplyChainSystem directly.
# Main/composed-game behavior is covered by integration and E2E suites.

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
    seed(123456)
    var Economy = load("res://scripts/economy.gd")
    var SupplyChain = load("res://scripts/supply_chain_system.gd")
    check(Economy != null, "Economy loads")
    check(SupplyChain != null, "Authoritative supply chain system loads")
    if Economy == null or SupplyChain == null:
        quit(1)
        return

    var economy = Economy.new()
    var chain = SupplyChain.new()
    chain.set_economy(economy)

    check(chain.SYSTEM_VERSION == 4, "Supply chain system version is current")
    check(chain.RESOURCE_IDS.size() == 5, "Supply chain uses canonical V1 resources")
    for resource in ["timber", "iron", "energy", "food", "electronics"]:
        check(economy.resources.has(resource), "Economy exposes canonical resource: " + resource)
        check(chain.warehouse.has(resource), "Warehouse supports canonical resource: " + resource)

    var timber_before = int(economy.resources["timber"]["stock"])
    var procurement = chain.procure("timber", 10.0, 100000, 1)
    check(bool(procurement.get("ok", false)), "Market timber procurement succeeds")
    check(chain.stock("timber") > 0.0, "Procured timber enters warehouse")
    check(int(economy.resources["timber"]["stock"]) < timber_before, "Procurement removes stock from market")
    check(int(procurement.get("freight", 0)) > 0, "Procurement records freight cost")

    var bundle = chain.procure_bundle([
        {"resource": "iron", "amount": 4.0},
        {"resource": "energy", "amount": 2.0}
    ], 100000, 1)
    check(bool(bundle.get("ok", false)), "Canonical input bundle procurement succeeds")
    check(chain.stock("iron") > 0.0 and chain.stock("energy") > 0.0, "Bundle inputs enter warehouse")

    var metal = chain.process_iron_to_metal(2)
    check(bool(metal.get("ok", false)), "Iron to metal processing succeeds")
    check(float(metal.get("output", 0.0)) > 0.0 and chain.stock("metal") > 0.0, "Metal output enters warehouse")

    var furniture_inputs = {"timber": 1.0, "metal": 0.5, "energy": 0.5}
    var can_make = chain.can_make_inputs(furniture_inputs, 1)
    check(bool(can_make.get("ok", false)), "Industry input availability is reported")
    var consumed = chain.consume_inputs(furniture_inputs, 1)
    check(bool(consumed.get("ok", false)), "Industry inputs are consumed")
    check(consumed.has("consumed"), "Input consumption reports consumed quantities")

    chain.receive_product("furniture", 3)
    check(chain.stock("furniture") == 3.0, "Finished furniture enters warehouse")
    var sale = chain.sell_furniture(2, 220)
    check(bool(sale.get("ok", false)) and int(sale.get("sold", 0)) == 2, "Warehouse furniture can be sold")
    check(chain.stock("furniture") == 1.0, "Furniture sale reduces warehouse stock")

    var snapshot = chain.capture_state()
    var restored = SupplyChain.new()
    restored.set_economy(economy)
    restored.restore_state(snapshot)
    check(restored.stock("furniture") == chain.stock("furniture"), "Warehouse state survives save/restore")
    check(restored.total_freight_cost == chain.total_freight_cost, "Freight state survives save/restore")
    check(restored.last_operation.get("type", "") == chain.last_operation.get("type", ""), "Last operation survives save/restore")

    var over_capacity = chain.procure("timber", 1000.0, 100000, 1)
    check(not bool(over_capacity.get("ok", false)) and over_capacity.get("reason", "") == "transport_capacity", "Transport capacity rejects oversized shipment")

    var resources_before_invalid_bundle := economy.resources.duplicate(true)
    var warehouse_before_invalid_bundle := chain.warehouse_snapshot()
    var freight_before_invalid_bundle := chain.total_freight_cost
    var invalid_bundle := chain.procure_bundle([
        {"resource": "timber", "amount": 1.0},
        {"resource": "not_a_real_resource", "amount": 1.0}
    ], 100000, 1)
    check(not bool(invalid_bundle.get("ok", false)), "Invalid bundle is rejected")
    check(economy.resources == resources_before_invalid_bundle, "Rejected bundle leaves market stock unchanged")
    check(chain.warehouse == warehouse_before_invalid_bundle, "Rejected bundle leaves warehouse unchanged")
    check(chain.total_freight_cost == freight_before_invalid_bundle, "Rejected bundle leaves freight totals unchanged")

    print("SUPPLY CHAIN SYSTEM RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
