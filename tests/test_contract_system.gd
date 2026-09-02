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
    var ContractSystem = load("res://scripts/contract_system.gd")
    check(ContractSystem != null, "ContractSystem loads")
    if ContractSystem == null:
        quit(1)
        return
    var contracts = ContractSystem.new()
    var created = contracts.create_customer_contract(["RENEW", "Buyer"], "steel", 10, 200, 70, {"frequency":"daily", "quantity_per_delivery":5, "duration_days":2, "start_day":1}, "Port Warehouse", 50, {"player_can_cancel":true, "fee":100}, {"eligible":true, "term_days":2}, {"on_fulfilled":3, "on_failed":-8})
    check(bool(created["ok"]), "Contract creation succeeds")
    var contract_id = str(created["contract"]["id"])
    var terms: Dictionary = created["contract"]
    check(terms.has("parties") and terms.has("resource_product") and terms.has("quantity"), "Parties, product and quantity are stored")
    check(terms.has("price") and terms.has("quality_requirement"), "Price and quality requirement are stored")
    check(terms.has("delivery_schedule") and terms.has("destination"), "Delivery schedule and destination are stored")
    check(terms.has("penalty") and terms.has("cancellation") and terms.has("renewal"), "Penalty, cancellation and renewal terms are stored")
    check(terms.has("reputation_impact") and terms.has("execution_status"), "Reputation impact and execution status are stored")

    var day1 = contracts.execute_day(contract_id, 5, 80, 1)
    check(bool(day1["ok"]) and int(day1["delivered"]) == 5, "On-time delivery fulfills daily quantity")
    check(int(day1["revenue"]) == 1000, "Revenue is based on delivered quantity and contract price")
    var day2 = contracts.execute_day(contract_id, 5, 80, 2)
    check(bool(day2["finished"]), "Contract finishes after scheduled duration")
    check(str(day2["contract"]["execution_status"]) == "fulfilled", "Fully delivered contract is fulfilled")
    check(bool(day2["contract"]["renewal_offered"]), "Fulfilled eligible contract offers renewal")

    var breach = contracts.create_customer_contract(["RENEW", "Buyer"], "lumber", 10, 100, 80, {"quantity_per_delivery":5, "duration_days":1, "start_day":3}, "Warehouse", 50, {"player_can_cancel":true, "fee":100}, {"eligible":true}, {"on_failed":-8})
    var breach_result = contracts.execute_day(str(breach["contract"]["id"]), 2, 40, 3)
    check(str(breach_result["contract"]["execution_status"]) == "breached", "Shortfall or failed quality breaches contract")
    check(int(breach_result["penalty"]) > 0, "Missed delivery incurs penalty")

    var snapshot = contracts.capture_state()
    var restored = ContractSystem.new()
    restored.restore_state(snapshot)
    check(restored.completed_contracts.size() == contracts.completed_contracts.size(), "Completed contracts persist")
    check(restored.history.size() == contracts.history.size(), "Contract execution history persists")

    print("CONTRACT SYSTEM RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
