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
    var SupplyChain = load("res://scripts/supply_chain.gd")
    check(SupplyChain != null, "Supply chain loads")
    if SupplyChain == null:
        quit(1)
        return
    var chain = SupplyChain.new()
    check(chain.STAGES.size() == 8, "All physical chain stages exist")
    for stage in ["source", "extraction", "transport", "processing", "manufacturing", "warehouse", "distribution", "retail"]:
        check(chain.stage_state.has(stage), "Stage has operational state: " + stage)
        check(chain.stage_state[stage].has("capacity"), "Stage capacity exists: " + stage)
        check(chain.stage_state[stage].has("reliability"), "Stage reliability exists: " + stage)
        check(chain.stage_state[stage].has("risk"), "Stage disruption risk exists: " + stage)
    check(chain.routes.size() >= 6, "End-to-end routes exist")
    var route = chain.route_metrics("extraction", "processing", 20)
    check(route["capacity"] == 20, "Route capacity limits shipment")
    check(route["cost"] > 0, "Transport route has cost")
    check(route["delay"] > 0, "Transport route has delay")
    check(route["reliability"] > 0.0, "Transport route has reliability")
    check(route["risk"] > 0.0, "Transport route has disruption risk")
    check(route["controlled"], "Route has ownership/control")

    var expansion = load("res://scripts/expansion.gd").new()
    expansion.resource_sites[0]["owned"] = true
    expansion.resource_sites[0]["stock"] = 0
    expansion.resource_sites[0]["output"] = 10
    var day_result = chain.daily_network_update(expansion, 50)
    check(int(day_result["generated"]) > 0, "Owned extraction generates physical stock")
    check(int(day_result["moved"]) > 0, "Generated stock enters the network")

    chain.begin_day(2)
    var physical = chain.process_physical_chain("materials", 10)
    check(physical.has("capacity"), "Physical chain reports capacity")
    check(physical.has("chain_factor"), "Physical chain reports reliability factor")
    check(physical["results"].size() > 0, "Physical chain executes linked routes")
    check(int(physical["cost"]) > 0, "Physical chain accumulates transport cost")
    check(int(physical["delay"]) > 0, "Physical chain accumulates delay")

    var snapshot = chain.snapshot()
    var restored = SupplyChain.new()
    restored.load_snapshot(snapshot)
    check(restored.routes.size() == chain.routes.size(), "Routes survive save/restore")
    check(restored.stage_state["warehouse"]["capacity"] == chain.stage_state["warehouse"]["capacity"], "Stage state survives save/restore")
    check(restored.shipments.size() == chain.shipments.size(), "Shipment history survives save/restore")

    chain.set_route_control("resource_haul", "rival_001", false)
    var controlled_factor = chain.chain_factor()
    check(controlled_factor < 1.0, "Loss of route control reduces chain efficiency")
    chain.set_route_active("distribution_route", false)
    var blocked = chain.process_physical_chain("materials", 10)
    check(blocked["results"].size() < chain.STAGES.size() - 1, "Closed route creates a physical bottleneck")

    print("SUPPLY CHAIN SYSTEM RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
