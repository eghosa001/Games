extends SceneTree

## V8.3: player identities. Eight paths with three reward tiers track how
## the player actually plays; claims fire once and persist.
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
    var Identity = load("res://scripts/identity_system.gd")
    check(Identity != null, "Identity system loads")
    if Identity == null:
        quit(1)
        return
    var state = root.get_node_or_null("RenewGameState")
    check(state != null, "GameState is available")
    if state == null:
        quit(1)
        return
    if state.has_method("clear"):
        state.clear()
    var finance = root.get_node_or_null("RenewFinanceSystem")
    if finance != null:
        finance.financing = {}
        finance.debt = 0
        finance.cash = 20000
        finance.equity_contributed = 20000.0
        finance.retained_earnings = 0.0
        finance.revenue = 0.0
        finance.operating_expenses = 0.0
        finance.interest_expense = 0.0
    var identity: Node = Identity.new()
    root.add_child(identity)
    await process_frame

    check(identity.progress().size() == 8, "Eight identities tracked")
    check(str(identity.status_text()).find("IDENTITIES") >= 0, "Status renders")
    check(identity.evaluate().is_empty(), "Fresh company earns nothing")
    var table: Dictionary = state.get_value("progression", "claimed_goals", {})
    state.set_value("ownership", "holdings", [{"rival_id": "r1", "rival_name": "R1", "shares": 50, "avg_price": 10.0, "total_paid": 500.0}])
    state.set_value("ownership", "acquisition_count", 2)
    var cash_before := int(finance.cash)
    var rep_before := int(state.get_value("player", "reputation", 0))
    var awarded: Array = identity.evaluate()
    check(awarded.size() >= 2, "Takeovers advance the Competitor path twice")
    check(int(finance.cash) > cash_before, "Identity tiers pay cash")
    check(int(state.get_value("player", "reputation", 0)) > rep_before, "Identity tiers grant reputation")
    check(str(state.get_value("company", "message", "")).find("IDENTITY") >= 0, "Tier-ups announced")
    check(identity.evaluate().is_empty(), "Claims fire exactly once")

    finance.revenue = 200000.0
    var rich: Array = identity.evaluate()
    var tycoon := false
    for entry in rich:
        if str((entry as Dictionary).get("id", "")) == "tycoon":
            tycoon = true
    check(tycoon, "Earnings advance the Tycoon path")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for identity wiring")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        check(game.has_method("identity_status"), "Main exposes identity_status")
        game.command_system.identity_status()
        check(str(game.command_system._state_value("company", "message", "")).find("IDENTITIES") >= 0, "Identity command reports")
        game.free()
        await process_frame
    identity.queue_free()
    await process_frame
    print("V83 IDENTITIES RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
