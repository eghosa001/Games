extends SceneTree

## V2.9: alliance competitions. Industrial challenges score the player's
## alliance against synthetic rivals with a 30-day cooldown and prizes.
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
    var Alliance = load("res://scripts/alliance_v1_system.gd")
    check(Alliance != null, "Alliance system loads")
    if Alliance == null:
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
    var system: Node = Alliance.new()
    root.add_child(system)
    await process_frame

    var lonely: Dictionary = system.run_alliance_challenge("player")
    check(not bool(lonely.get("ok", false)), "Outsiders cannot enter challenges")
    var created: Dictionary = system.create_alliance("Challenge Pact", "player")
    check(bool(created.get("ok", false)), "Alliance created")
    var id := str(created.get("alliance", {}).get("id", ""))
    check(bool(system.invite_member(id, "player", "builder_a").get("ok", false)), "Founder invites")
    check(bool(system.join_alliance(id, "builder_a").get("ok", false)), "Member joins")
    check(bool(system.donate_money("player", 60000).get("ok", false)), "Major donation lands")
    var pact: Dictionary = system.get_alliance(id)
    var score: int = system.challenge_score(pact)
    check(score > 100, "A funded two-member alliance scores over 100")
    var expected: int = 2 * 10 + int(int(pact.get("treasury", 0)) / 1000) + int(pact.get("level", 1)) * 15 + int(float(pact.get("trust", 50.0)) / 2.0)
    check(score == expected, "Challenge score follows the public formula")
    var treasury_before := int(pact.get("treasury", 0))
    var result: Dictionary = system.run_alliance_challenge("player")
    check(bool(result.get("ok", false)), "Challenge runs")
    check(int(result.get("rank", 0)) == 1, "A powerhouse alliance wins")
    check(int(result.get("prize", 0)) == 3000, "Winners take the $3,000 purse")
    check(result.get("standings", []).size() == 3, "Three alliances contest each challenge")
    check(not str(result.get("message", "")).is_empty(), "Challenge reports a result")
    check(int(system.get_alliance(id).get("treasury", 0)) == treasury_before + 3000, "Prize lands in the treasury")
    var encore: Dictionary = system.run_alliance_challenge("player")
    check(not bool(encore.get("ok", false)), "Challenges cool down for 30 days")
    check(str(encore.get("message", "")).find("opens in") >= 0, "Cooldown names the wait")
    check(system.get_alliance(id).has("last_challenge_day"), "Challenge day persists")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for challenge wiring")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        check(game.has_method("compete_alliance"), "Main exposes compete_alliance")
        game.command_system.compete_alliance()
        check(not str(game.command_system._state_value("company", "message", "")).is_empty(), "Compete command reports a result")
        game.free()
        await process_frame
    system.queue_free()
    await process_frame
    print("V29 ALLIANCE COMPETITIONS RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
