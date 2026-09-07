extends SceneTree

## V2.2: company shares. Buying rival stock builds a toehold that pays daily
## dividends and discounts future takeover bids; positions close at market.
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
    var Rivals = load("res://scripts/competitors.gd")
    check(Rivals != null, "Competitor model loads")
    if Rivals == null:
        quit(1)
        return
    var rivals = Rivals.new()
    rivals._normalize()
    check(int(rivals.share_price(0)) > 0, "Rival shares are priced")
    check(int(rivals.share_price(99)) == 0, "Unknown rival has no price")
    var ask_plain: Dictionary = rivals.negotiate_acquisition(0, 1000000, 100)
    var ask_held: Dictionary = rivals.negotiate_acquisition(0, 1000000, 100, [{"rival_id": "apex_materials", "shares": 60}])
    check(bool(ask_plain.get("ok", false)) and bool(ask_held.get("ok", false)), "Toehold quotes resolve")
    check(int(ask_held.get("cost", 0)) < int(ask_plain.get("cost", 0)), "Toehold discounts the takeover ask")
    check(float(ask_held.get("leverage", 0.0)) > 0.0, "Leverage is reported")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for share commands")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    game.cash = 300000
    game.reputation = 100
    game.select_rival(0)
    var price := int(game.command_system.relationship_system.rivals.share_price(0))
    var cash_before := int(game.cash)
    game.buy_rival_shares()
    check(int(game.cash) == cash_before - price * 10, "Share purchase charges one lot")
    var state = root.get_node_or_null("RenewGameState")
    var holdings: Array = state.get_value("ownership", "holdings", [])
    check(holdings.size() == 1 and int(holdings[0].get("shares", 0)) == 10, "Holding recorded with ten shares")
    game.buy_rival_shares()
    holdings = state.get_value("ownership", "holdings", [])
    check(int(holdings[0].get("shares", 0)) == 20, "Second lot merges into the position")
    check(float(holdings[0].get("avg_price", 0.0)) > 0.0, "Average price tracked")
    var ask_before := int(game.command_system.relationship_system.rivals.negotiate_acquisition(0, 1000000, 100).get("cost", 0))
    game.select_rival(0)
    var discounted: Dictionary = game.command_system.relationship_system.rivals.negotiate_acquisition(0, 1000000, 100, holdings)
    check(int(discounted.get("cost", ask_before)) < ask_before, "Live holdings discount the ask")
    game.sell_rival_shares()
    check(state.get_value("ownership", "holdings", []).is_empty(), "Sale closes the position")
    check(int(game.cash) > 0, "Sale proceeds land as cash")

    game.buy_rival_shares()
    game.inspect_property()
    game.acquire_property()
    for _i in range(5):
        game.restore_property()
    game.choose_business_purpose(0)
    game.open_business()
    var day_before := int(game.day)
    game.advance_day()
    check(int(game.day) == day_before + 1, "Day advances with shares held")
    game.free()
    await process_frame
    print("V22 SHARES RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
