extends SceneTree

## V2.5: contract variety. Exclusive, construction and government agreements
## carry distinct pricing, penalties, durations and reputation weight while
## flowing through the same delivery, renewal and persistence machinery.
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
    var Contracts = load("res://scripts/contract_system.gd")
    check(Contracts != null, "Contract system loads")
    if Contracts == null:
        quit(1)
        return
    var contracts = Contracts.new()
    root.add_child(contracts)
    await process_frame

    var standard: Dictionary = contracts.create_default_customer_contract(1, 40, "furniture")
    check(bool(standard.get("ok", false)), "Standard contract still signs")
    check(str(standard.get("contract", {}).get("kind", "")) != "exclusive", "Standard contract is not exclusive")
    var exclusive: Dictionary = contracts.create_exclusive_contract(1, 40, "furniture")
    check(bool(exclusive.get("ok", false)), "Exclusive contract signs")
    check(str(exclusive.get("contract", {}).get("kind", "")) == "exclusive", "Exclusive kind recorded")
    check(int(exclusive.get("contract", {}).get("price", 0)) > int(standard.get("contract", {}).get("price", 0)), "Exclusivity commands a premium")
    check(int(exclusive.get("contract", {}).get("penalty", 0)) > int(standard.get("contract", {}).get("penalty", 0)), "Exclusivity carries heavier penalties")
    var construction: Dictionary = contracts.create_construction_contract(1, 40, "construction_materials")
    check(bool(construction.get("ok", false)), "Construction contract signs")
    check(str(construction.get("contract", {}).get("kind", "")) == "construction", "Construction kind recorded")
    check(int(construction.get("contract", {}).get("quantity", 0)) == 50, "Construction fixes a project lot")
    var weak_govt: Dictionary = contracts.create_government_contract(1, 10, "furniture")
    check(not bool(weak_govt.get("ok", false)), "Government work requires standing")
    var government: Dictionary = contracts.create_government_contract(1, 60, "furniture")
    check(bool(government.get("ok", false)), "Government contract signs at standing")
    check(str(government.get("contract", {}).get("kind", "")) == "government", "Government kind recorded")
    check(int(government.get("contract", {}).get("quantity", 0)) == 100, "Government fixes a civic lot")
    check(int(government.get("contract", {}).get("delivery_schedule", {}).get("duration_days", 0)) == 10, "Government runs a long schedule")

    var exec_id := str(exclusive.get("contract", {}).get("id", ""))
    var first_day: Dictionary = contracts.execute_day(exec_id, 50, 90, 1)
    check(bool(first_day.get("ok", false)), "Exclusive delivery executes")
    check(int(first_day.get("delivered", 0)) > 0, "Exclusive delivery moves goods")
    check(int(first_day.get("revenue", 0)) == int(first_day.get("delivered", 0)) * int(exclusive.get("contract", {}).get("price", 0)), "Exclusive revenue uses premium price")
    var snapshot: Dictionary = contracts.capture_state()
    var restored = Contracts.new()
    root.add_child(restored)
    restored.restore_state(snapshot)
    var restored_kind := ""
    for item in restored.list_active_contracts():
        if str(item.get("id", "")) == exec_id:
            restored_kind = str(item.get("kind", ""))
    check(not restored.list_active_contracts().is_empty(), "Active kinded contract persists")
    check(restored_kind == "exclusive", "Kind persists across save/load")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for contract commands")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        game.cash = 200000
        game.reputation = 60
        game.inspect_property()
        game.acquire_property()
        for _i in range(5):
            game.restore_property()
        game.choose_business_purpose(0)
        game.open_business()
        for method in ["sign_exclusive_contract", "sign_construction_contract", "sign_government_contract"]:
            check(game.has_method(method), "Main exposes %s" % method)
        game.sign_government_contract()
        check(not root.get_node_or_null("RenewContractSystem").active_contract().is_empty(), "Government contract signs through Main")
        check(str(root.get_node_or_null("RenewContractSystem").active_contract().get("resource_product", "")) == "furniture", "Command routes the active industry product")
        game.free()
        await process_frame
    print("V25 CONTRACTS RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
