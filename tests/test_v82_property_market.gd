extends SceneTree

## V8.2: property market. Restored property sells at improved value;
## leasing pays upfront rent and locks the building until expiry.
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
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for property market")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    var state = root.get_node_or_null("RenewGameState")
    var finance = root.get_node_or_null("RenewFinanceSystem")
    check(state != null and finance != null, "State and finance resolve")
    if state == null or finance == null:
        game.free()
        quit(1)
        return
    game.cash = 250000
    game.day = 1
    game.inspect_property()
    game.acquire_property()
    check(bool(state.get_value("properties", "owned", false)), "Property acquired")
    game.sell_property()
    check(not bool(state.get_value("properties", "owned", false)), "Property sells")
    check(int(finance.cash) > 250000 - 5000, "Sale pays above purchase price")
    check(str(state.get_value("company", "message", "")).find("Sold") >= 0, "Sale announced")

    game.inspect_property()
    game.acquire_property()
    var guard := 0
    while str(state.get_value("properties", "stage", "")) != "Operational" and guard < 20:
        game.restore_property()
        guard += 1
        await process_frame
    game.choose_business_purpose(0)
    game.open_business()
    game.sell_property()
    check(bool(state.get_value("properties", "owned", false)), "Operating business blocks the sale")

    var props: Node = game.command_system.property_system
    var before := int(finance.cash)
    game.lease_property()
    var leased: Dictionary = props.get_selected_property()
    check(int(leased.get("lease_until", 0)) == 8, "Lease locks for seven days")
    check(int(finance.cash) > before, "Lease pays upfront rent")
    game.restore_property()
    check(str(state.get_value("company", "message", "")).find("enant") >= 0, "Tenants block restoration")
    state.set_value("player", "day", 30)
    game.restore_property()
    check(str(state.get_value("company", "message", "")).find("enant") < 0, "Expiry frees the building")
    game.free()
    await process_frame
    print("V82 PROPERTY MARKET RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
