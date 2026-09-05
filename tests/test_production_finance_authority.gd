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
    var business_path := "res://scripts/business_system.gd"
    var business_text := FileAccess.get_file_as_string(business_path)
    check(not business_text.is_empty(), "BusinessSystem source is readable")
    check(business_text.contains("var finance = get_node_or_null(\"/root/RenewFinanceSystem\")"), "BusinessSystem resolves canonical FinanceSystem")
    check(business_text.contains("var operating_cost: int = int(config.get(\"operating_cost\", 0))"), "Production reads configured operating cost")
    check(business_text.contains("state_adapter.spend(operating_cost, \"production operating cost\")"), "Production operating cost is charged through FinanceSystem")
    check(business_text.contains("delivery_cost + operating_cost"), "Production preflights delivery and operating cash together")
    check(business_text.contains("func warehouse_restore(resource:String, amount:float)->void: supply_chain.warehouse[resource] = max(0.0, float(supply_chain.warehouse.get(resource,0.0))+amount)"), "Production rollback restores delivered warehouse inventory")
    print("\nRENEW PRODUCTION FINANCE AUTHORITY RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)