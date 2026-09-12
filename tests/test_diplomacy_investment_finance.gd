extends SceneTree

## Regression: investment treaties must fund principal before any return is paid.
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

    var services = root.get_node_or_null("RenewServices")
    var finance = root.get_node_or_null("RenewFinanceSystem")
    var diplomacy = services.get_service("RenewDiplomacySystem") if services != null else null
    var effects = services.get_service("RenewDiplomacyEffects") if services != null else null
    check(finance != null and diplomacy != null and effects != null, "Investment treaty stack resolves")
    if finance == null or diplomacy == null or effects == null:
        game.free()
        quit(1)
        return

    var proposed: Dictionary = diplomacy.propose_treaty("player", "northstar_logistics", "investment", {"capital_commitment":5000}, 30)
    check(bool(proposed.get("ok", false)), "Investment treaty proposes")
    var treaty_id := str(proposed.get("treaty", {}).get("id", ""))
    check(bool(diplomacy.accept_treaty(treaty_id, "northstar_logistics").get("ok", false)), "Investment treaty activates")
    var treaty: Dictionary = diplomacy.get_treaty(treaty_id)

    game.cash = 100
    var blocked_cash := int(finance.cash)
    effects._apply(treaty, int(game.day))
    var blocked_state: Dictionary = effects.applied.get(treaty_id, {})
    check(bool(blocked_state.get("funding_blocked", false)), "Unaffordable investment is marked blocked")
    check(not bool(blocked_state.get("funded", false)), "Unaffordable investment is not funded")
    check(int(finance.cash) == blocked_cash, "Blocked investment pays no free return")

    game.cash = 10000
    var before_funding := int(finance.cash)
    effects._apply(treaty, int(game.day) + 1)
    var funded_state: Dictionary = effects.applied.get(treaty_id, {})
    check(bool(funded_state.get("funded", false)), "Investment funds after cash becomes available")
    check(int(funded_state.get("funded_capital", 0)) == 5000, "Investment records committed principal")
    check(int(finance.cash) < before_funding, "Funding debits principal before return")
    var after_first_return := int(finance.cash)
    effects._apply(treaty, int(game.day) + 1)
    check(int(finance.cash) == after_first_return, "Investment return cannot be paid twice on the same day")
    check(bool(finance.validate_invariants().get("ok", false)), "Investment treaty keeps finance invariants valid")

    print("DIPLOMACY INVESTMENT FINANCE RESULT: %d passed, %d failed" % [passed, failed])
    game.free()
    await process_frame
    quit(1 if failed > 0 else 0)
