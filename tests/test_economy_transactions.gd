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
    var economy = load("res://scripts/economy.gd").new()
    check(economy != null, "Economy system instantiates")
    if economy == null:
        quit(1)
        return
    var orders: Array = [
        {"resource":"timber","amount":12},
        {"resource":"iron","amount":12},
        {"resource":"energy","amount":12}
    ]
    var quote = economy.quote_bundle(orders, 0, 0.10, 250)
    check(bool(quote.get("ok", false)), "Bundle quote succeeds")
    check(int(quote.get("cost", 0)) == int(quote.get("base_cost", 0)) - int(quote.get("discount", 0)) + 250, "Bundle quote applies adjustments")
    var cash := int(quote.get("cost", 0)) - 1
    var before: Dictionary = {}
    for order in orders:
        var resource := String(order["resource"])
        before[resource] = int(economy.resources[resource]["stock"])
    var rejected = economy.buy_bundle(orders, cash, 0, 0.10, 250)
    check(not bool(rejected.get("ok", false)), "Adjusted bundle rejects insufficient cash")
    for order in orders:
        var resource := String(order["resource"])
        check(int(economy.resources[resource]["stock"]) == int(before[resource]), "Rejected bundle leaves %s unchanged" % resource)

    # buy_bundle is an atomic bundle path and does not use the probabilistic
    # supplier reliability roll used by buy_resource. A retry loop here would
    # mask a regression, so one call is intentionally required to succeed.
    var successful: Dictionary = economy.buy_bundle(orders, 100000, 0)
    check(bool(successful.get("ok", false)), "Atomic bundle commits deterministically")
    if bool(successful.get("ok", false)):
        check(successful.get("delivered", []).size() == orders.size(), "Atomic bundle reports every delivery")
        for order in orders:
            var resource := String(order["resource"])
            var amount := int(order["amount"])
            check(int(economy.resources[resource]["stock"]) == int(before[resource]) + amount, "Committed bundle adds %s exactly once" % resource)
    print("ECONOMY TRANSACTION RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
