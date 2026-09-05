extends SceneTree

var passed := 0
var failed := 0

func check(condition: bool, label: String) -> void:
    if condition:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _init() -> void:
    call_deferred("run")

func run() -> void:
    var Supply = load("res://scripts/supply_chain_system.gd")
    var Production = load("res://scripts/production_system.gd")
    check(Supply != null, "SupplyChainSystem loads")
    check(Production != null, "ProductionSystem loads")
    if Supply == null or Production == null:
        quit(1)
        return

    var production = Production.new()
    production.name = "RenewProductionSystem"
    root.add_child(production)
    var supply = Supply.new()
    root.add_child(supply)
    await process_frame

    supply.warehouse["furniture"] = 500.0
    production.inventory["furniture"] = 7
    var before_warehouse := supply.warehouse_snapshot()
    var before_production := production.inventory.duplicate(true)

    var result: Dictionary = supply.receive_product("furniture", 1)
    check(not bool(result.get("ok", false)), "Receipt rejects warehouse overflow")
    check(supply.stock("furniture") == float(before_warehouse["furniture"]), "Rejected receipt leaves warehouse unchanged")
    check(int(production.inventory["furniture"]) == int(before_production["furniture"]), "Rejected receipt leaves production mirror unchanged")

    print("SUPPLY RECEIPT ATOMICITY RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
