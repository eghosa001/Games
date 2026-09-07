extends SceneTree

## V2.6: international trade. Overseas procurement pays tariffs and risks
## customs spoilage; export contracts pay premium prices for freight-capable
## exporters with standing.
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
    var weak: Dictionary = contracts.create_export_contract(1, 5, "furniture")
    check(not bool(weak.get("ok", false)), "Export needs standing")
    var deal: Dictionary = contracts.create_export_contract(1, 40, "furniture")
    check(bool(deal.get("ok", false)), "Export contract signs")
    check(str(deal.get("contract", {}).get("kind", "")) == "export", "Export kind recorded")
    check(str(deal.get("contract", {}).get("customer_id", "")) == "Meridian Overseas", "Foreign buyer recorded")
    check(int(deal.get("contract", {}).get("quantity", 0)) == 60, "Export fixes an overseas lot")
    var standard: Dictionary = contracts.create_default_customer_contract(1, 40, "furniture")
    check(int(deal.get("contract", {}).get("price", 0)) > int(standard.get("contract", {}).get("price", 0)), "Export commands a premium")
    var first: Dictionary = contracts.execute_day(str(deal.get("contract", {}).get("id", "")), 60, 90, 1)
    check(bool(first.get("ok", false)) and int(first.get("delivered", 0)) > 0, "Export delivery executes")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for trade commands")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        game.cash = 200000
        game.reputation = 10
        game.buy_international()
        check(game.message == "Overseas suppliers need 15 reputation before clearing customs for you.", "Customs gate needs standing")
        game.reputation = 25
        game.inspect_property()
        game.acquire_property()
        for _i in range(5):
            game.restore_property()
        game.choose_business_purpose(0)
        game.open_business()
        seed(7)
        var cash_before := int(game.cash)
        game.buy_international()
        check(int(game.cash) < cash_before, "Tariff import spends cash")
        check(game.message != "", "Import reports through commands")
        for method in ["buy_international", "sign_export_contract"]:
            check(game.has_method(method), "Main exposes %s" % method)
        game.upgrade_transport()
        game.sign_export_contract()
        var active: Dictionary = root.get_node_or_null("RenewContractSystem").active_contract()
        check(str(active.get("kind", "")) == "export", "Export signs through Main")
        game.free()
        await process_frame
    print("V26 TRADE RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
