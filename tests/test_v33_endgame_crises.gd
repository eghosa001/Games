extends SceneTree

## V3.3: endgame crises. Near-victory empires attract a market crash, an
## antitrust ruling, or an alliance schism. Each fires once and bites.
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

func _fund(finance: Variant) -> void:
    finance.financing = {}
    finance.debt = 0
    finance.loan_payment = 0
    finance.revenue = 0.0
    finance.operating_expenses = 0.0
    finance.interest_expense = 0.0
    finance.retained_earnings = 0.0
    finance.equity_contributed = 200000.0
    finance.cash = 10000

func run() -> void:
    var Victory = load("res://scripts/victory_system.gd")
    check(Victory != null, "Victory system loads")
    if Victory == null:
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
    if finance == null:
        push_error("FAIL: Finance is available")
        quit(1)
        return
    _fund(finance)
    var victory: Node = Victory.new()
    root.add_child(victory)
    await process_frame

    check(victory.maybe_endgame_crisis(200).is_empty(), "Small companies face no endgame crises")
    finance.revenue = 150000.0
    var pct: int = int(victory.progress()["tycoon"]["pct"])
    check(pct >= 70, "Strong earnings approach Tycoon status")
    var crash: Dictionary = victory.maybe_endgame_crisis(59)
    check(crash.is_empty(), "The crash waits for day 60")
    var before := float(finance.get("retained_earnings"))
    var cash_before := int(finance.get("cash"))
    crash = victory.maybe_endgame_crisis(60)
    check(bool(crash.get("ok", false)) and str(crash.get("id", "")) == "market_crash", "Market crash fires")
    check(float(crash.get("loss", 0.0)) == float(cash_before), "Thin reserves are wiped out")
    check(int(finance.get("cash")) == 0, "Crash drains cash reserves")
    check(float(finance.get("retained_earnings")) == before - float(cash_before), "Crash books the loss")
    check(victory.maybe_endgame_crisis(61).get("id", "") != "market_crash", "Crash fires exactly once")
    check(victory.has_fired("crisis_market_crash"), "Crash recorded")

    state.set_value("ownership", "holdings", [{"rival_id": "r1", "rival_name": "R1", "shares": 40, "avg_price": 10.0, "total_paid": 400.0}])
    var probe: Dictionary = victory.maybe_endgame_crisis(61)
    check(bool(probe.get("ok", false)) and str(probe.get("id", "")) == "antitrust", "Antitrust probe fires")
    check(int(probe.get("shares_seized", 0)) == 20, "Regulators seize 20 shares")
    var lots: Array = state.get_value("ownership", "holdings", [])
    check(lots.size() == 1 and int((lots[0] as Dictionary).get("shares", -1)) == 20, "Holdings reflect the seizure")
    check(str(state.get_value("company", "message", "")).find("ANTITRUST") >= 0, "Probe announced")

    if state.has_method("clear"):
        state.clear()
    _fund(finance)
    finance.cash = 200000
    finance.revenue = 150000.0
    var soft: Dictionary = victory.maybe_endgame_crisis(90)
    check(bool(soft.get("ok", false)) and float(soft.get("loss", 0.0)) == 75000.0, "Deep reserves cushion the crash")

    var Alliance = load("res://scripts/alliance_v1_system.gd")
    var alliance: Node = Alliance.new()
    root.add_child(alliance)
    await process_frame
    check(bool(alliance.create_alliance("Schism Pact", "player").get("ok", false)), "Alliance created")
    var table: Dictionary = state.get_value("alliances", "alliances", {})
    for key in table.keys():
        table[key]["challenge_wins"] = 2
        table[key]["trust"] = 60.0
        table[key]["treasury"] = 10000
    state.set_value("alliances", "alliances", table)
    var schism: Dictionary = victory.maybe_endgame_crisis(90)
    check(bool(schism.get("ok", false)) and str(schism.get("id", "")) == "schism", "Schism fires at two wins")
    var pact: Dictionary = alliance.get_member_alliance("player")
    check(float(pact.get("trust", -1.0)) == 45.0, "Schism burns 15 trust")
    check(int(pact.get("treasury", -1)) == 8000, "Schism drains the treasury")
    check(victory.maybe_endgame_crisis(91).is_empty(), "No crisis remains")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads after crisis changes")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        game.free()
        await process_frame
    alliance.queue_free()
    victory.queue_free()
    await process_frame
    print("V33 ENDGAME CRISES RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
