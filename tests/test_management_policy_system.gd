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
    var packed = load("res://scenes/Main.tscn")
    check(packed != null, "Main scene loads")
    if packed == null:
        quit(1)
        return
    var game = packed.instantiate()
    game.name = "Renew"
    root.add_child(game)
    await process_frame
    await process_frame

    var policies = root.get_node_or_null("RenewManagementPolicySystem")
    check(policies != null, "management policy autoload exists")
    if policies == null:
        quit(1)
        return

    check(policies.get_policy("procurement") in ["manual","alert","auto"], "procurement policy has valid mode")
    check(policies.get_policy("pricing") in ["manual","alert","auto"], "pricing policy has valid mode")
    check(policies.get_policy("maintenance") in ["manual","alert","auto"], "maintenance policy has valid mode")

    var state = root.get_node_or_null("RenewGameState")
    check(state != null, "GameState exists")
    policies.set_cash_reserve(15000)
    check(int(state.get_value("management","cash_reserve",0)) == 15000, "cash reserve persists to GameState")

    var result: Dictionary = policies.cycle_policy("procurement")
    check(result.has("message"), "policy cycling returns player feedback")
    check(str(state.get_value("management","procurement_policy","")) == policies.get_policy("procurement"), "policy mode persists to GameState")

    game.cash = 500000
    game.inspect_property()
    game.acquire_property()
    for _i in range(4): game.restore_property()
    game.choose_business_purpose(0)
    game.open_business()
    policies.evaluate()
    check(policies.get_alerts() is Array, "operational alerts are exposed")
    check(not policies.policy_summary().is_empty(), "policy summary is available")
    check(not policies.alert_summary().is_empty(), "alert summary is available")

    print("MANAGEMENT POLICY RESULT: %d passed, %d failed" % [passed, failed])
    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)
