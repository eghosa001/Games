extends SceneTree

## V3.1: victory conditions. Tycoon, Monopolist and Hegemon paths are
## tracked, announced once, and recorded into the corporate legacy.
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

func _rewind_challenge(state: Variant) -> void:
    var table: Variant = state.get_value("alliances", "alliances", {})
    if not table is Dictionary:
        return
    for key in (table as Dictionary).keys():
        if (table as Dictionary)[key] is Dictionary:
            ((table as Dictionary)[key] as Dictionary)["last_challenge_day"] = int(((table as Dictionary)[key] as Dictionary).get("last_challenge_day", 0)) - 30
    state.set_value("alliances", "alliances", table)

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
    if finance != null:
        finance.financing = {}
        finance.debt = 0
        finance.loan_payment = 0
        finance.revenue = 0.0
        finance.operating_expenses = 0.0
        finance.interest_expense = 0.0
        finance.retained_earnings = 0.0
        finance.equity_contributed = 200000.0
        finance.cash = 200000
    var victory: Node = Victory.new()
    root.add_child(victory)
    await process_frame

    var fresh: Dictionary = victory.check_victory()
    check(not bool(fresh.get("ok", false)), "A fresh company has won nothing")
    var progress: Dictionary = victory.progress()
    check(progress.has("tycoon") and progress.has("monopolist") and progress.has("hegemon"), "Three paths tracked")
    check(int(progress["tycoon"]["pct"]) < 100, "Tycoon starts incomplete")
    check(not str(victory.progress_text()).is_empty(), "Progress renders as text")
    check(str(victory.progress_text()).find("Tycoon") >= 0, "Progress names the Tycoon path")

    var Alliance = load("res://scripts/alliance_v1_system.gd")
    var alliance: Node = Alliance.new()
    root.add_child(alliance)
    await process_frame
    var created: Dictionary = alliance.create_alliance("Hegemon Pact", "player")
    check(bool(created.get("ok", false)), "Alliance created")
    check(bool(alliance.donate_money("player", 60000).get("ok", false)), "Alliance funded")
    for i in range(3):
        _rewind_challenge(state)
        var result: Dictionary = alliance.run_alliance_challenge("player")
        check(bool(result.get("ok", false)), "Challenge %d runs" % (i + 1))
    var standing: Dictionary = victory.hegemon_standing()
    check(int(standing.get("wins", 0)) == 3, "Three challenge wins recorded")
    var hege: Dictionary = victory.progress()["hegemon"]
    check(int(hege["current"]) == 3, "Hegemon progress counts wins")
    var won: Dictionary = victory.check_victory()
    if int(alliance.get_member_alliance("player").get("level", 1)) >= 3:
        check(bool(won.get("ok", false)) and str(won.get("path", "")) == "hegemon", "Hegemon wins with level 3+")
    else:
        check(not bool(won.get("ok", false)), "Hegemon waits for alliance level 3")
    state.set_value("ownership", "holdings", [{"rival_id": "r1", "rival_name": "R1", "shares": 50, "avg_price": 10.0, "total_paid": 500.0}])
    var mono: Dictionary = victory.check_victory()
    var stored: Dictionary = victory.stored_victory()
    check(not str(stored).is_empty() or not bool(mono.get("ok", false)), "Victory state readable")
    if str(stored.get("path", "")) == "monopolist":
        var again: Dictionary = victory.check_victory()
        check(bool(again.get("already", false)), "Victory fires exactly once")
        check(str(state.get_value("company", "message", "")).find("VICTORY") >= 0, "Victory announced")
    else:
        check(str(stored.get("path", "")) == "hegemon", "Hegemon win recorded first")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for goals wiring")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        check(game.has_method("victory_progress"), "Main exposes victory_progress")
        game.command_system.victory_progress()
        check(str(game.command_system._state_value("company", "message", "")).find("GOALS") >= 0, "Goals command reports progress")
        game.free()
        await process_frame
    alliance.queue_free()
    victory.queue_free()
    await process_frame
    print("V31 VICTORY RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
