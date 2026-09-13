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
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check(packed != null, "Main scene loads")
    if packed == null:
        quit(1)
        return

    var game = packed.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame

    var market = game.get_node_or_null("Systems/MarketDirector")
    check(market != null, "MarketDirector resolves")
    if market == null:
        game.free()
        quit(1)
        return

    var economy = game.get("economy")
    check(economy != null, "Economy resolves")
    var finance = root.get_node_or_null("RenewFinanceSystem")
    check(finance != null, "FinanceSystem resolves")
    if economy == null or finance == null:
        game.free()
        quit(1)
        return

    economy.clear_market_modifiers()
    game.cash = 100
    var cash_before := int(game.cash)
    var before := economy.market_multipliers.duplicate(true)
    market.active_event = "INPUT SHORTAGE"
    market.event_text = "Test shortage"
    market.event_expiry = int(game.day) + 2
    market.respond_aggressively()

    check(int(game.cash) == cash_before, "Rejected aggressive response does not spend cash")
    check(economy.market_multipliers == before, "Rejected aggressive response does not leak market modifiers")
    check(str(market.active_event) == "INPUT SHORTAGE", "Rejected response leaves event available for another choice")

    game.cash = 10000
    market.respond_aggressively()
    check(str(market.active_event).is_empty(), "Funded aggressive response resolves event")
    check(str(market.effect_name) == "response", "Successful response applies temporary market effect")
    check(float(economy.market_multipliers.get("timber", 1.0)) < 1.0, "Successful shortage response changes timber modifier")

    game.free()
    await process_frame
    print("MARKET TRANSACTION RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
