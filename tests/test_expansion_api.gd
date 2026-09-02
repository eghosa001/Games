extends SceneTree

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
    var x = load("res://scripts/expansion.gd").new()
    x.unlock_from_reputation(100)
    check(x.buy(1, 100000)["ok"], "Expansion business purchase")
    check(x.get_property(1).get("industry", "") == "Consumer Goods", "Expansion industry metadata")
    check(x.change_price(1, 15)["ok"], "Expansion price control")
    check(x.toggle_active(1)["ok"], "Expansion pause control")
    check(x.toggle_active(1)["ok"], "Expansion reopen control")
    check(x.hire(1, 100000)["ok"], "Expansion hiring")

    var p = x.get_property(1)
    p["inputs"]["materials"] = 10
    p["inputs"]["packaging"] = 10
    check(x.produce(1)["ok"], "Expansion production")
    check(int(x.get_property(1).get("stock", 0)) > 0, "Expansion production stock")
    check(x.sell(1)["ok"], "Expansion sales")

    check(x.buy_resource_site(0, 100000)["ok"], "Expansion resource ownership")
    check(x.harvest_resource(0)["ok"], "Expansion harvest compatibility API")
    check(x.supply_business(1, "materials", 3)["ok"], "Expansion owned-source supply")
    check(x.management_upgrade(100000)["ok"], "Expansion HQ management upgrade")
    check(x.transfer_core_goods(1, 2, 2)["ok"], "Expansion core goods transfer")

    var cash_before := int(x.cash)
    x.operate_day()
    check(int(x.cash) == cash_before, "Expansion operate day does not double-apply global cash")

    print("EXPANSION API RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
