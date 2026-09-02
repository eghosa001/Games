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
    var orders: Array = [
        {"resource":"materials","amount":12},
        {"resource":"packaging","amount":12},
        {"resource":"fuel","amount":12}
    ]

    var quote = economy.quote_bundle(orders, 0, 0.10, 250)
    check(quote["ok"], "Bundle quote succeeds")
    check(int(quote["cost"]) == int(quote["base_cost"]) - int(quote["discount"]) + 250, "Bundle quote applies adjustments")

    var cash := int(quote["cost"]) - 1
    var before: Dictionary = {}
    for key in economy.resources:
        before[key] = int(economy.resources[key]["stock"])
    var rejected = economy.buy_bundle(orders, cash, 0, 0.10, 250)
    check(not rejected["ok"], "Adjusted bundle rejects insufficient cash")
    for key in economy.resources:
        check(int(economy.resources[key]["stock"]) == int(before[key]), "Rejected bundle leaves %s unchanged" % key)

    # Supplier delivery uses probabilistic reliability. Retry the same atomic
    # order until a delivery succeeds so this test verifies transaction
    # semantics rather than depending on one random roll.
    var successful: Dictionary = {"ok":false}
    for attempt in range(20):
        successful = economy.buy_bundle(orders, 100000, 0)
        if bool(successful["ok"]):
            break
    check(successful["ok"], "Atomic bundle can commit")
    if successful["ok"]:
        for key in economy.resources:
            check(int(economy.resources[key]["stock"]) == int(before[key]) + 12, "Committed bundle adds %s exactly once" % key)

    print("ECONOMY TRANSACTION RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
