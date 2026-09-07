extends SceneTree

## V3.4: prestige / New Game+. Victories bank permanent heir bonuses into
## user://renew_prestige.json; founders can start a new dynasty after winning.
var passed := 0
var failed := 0

const PRESTIGE_PATH := "user://renew_prestige.json"

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
    if FileAccess.file_exists(PRESTIGE_PATH):
        DirAccess.remove_absolute(PRESTIGE_PATH)
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
    finance.financing = {}
    finance.debt = 0
    finance.cash = 200000
    finance.equity_contributed = 200000.0
    finance.retained_earnings = 0.0
    finance.revenue = 0.0
    finance.operating_expenses = 0.0
    finance.interest_expense = 0.0
    var victory: Node = Victory.new()
    root.add_child(victory)
    await process_frame

    check(victory.prestige_wins() == 0, "No prestige at founding")
    var early: Dictionary = victory.found_new_company()
    check(not bool(early.get("ok", false)), "Dynasties require a victory first")
    state.set_value("ownership", "holdings", [{"rival_id": "r1", "rival_name": "R1", "shares": 50, "avg_price": 10.0, "total_paid": 500.0}])
    var won: Dictionary = victory.check_victory()
    check(bool(won.get("ok", false)) and str(won.get("path", "")) == "monopolist", "Monopolist victory wins")
    check(victory.prestige_wins() == 1, "Victory banks prestige")
    check(victory.prestige_path_wins("monopolist") == 1, "Prestige tracks the path")
    check(FileAccess.file_exists(PRESTIGE_PATH), "Prestige persists to disk")
    var bonuses: Dictionary = victory.prestige_bonuses()
    check(int(bonuses.get("starting_cash", -1)) == 25000, "One win grants $25K heir capital")
    check(int(bonuses.get("starting_reputation", -1)) == 5, "Monopolist heirs start connected")
    var founded: Dictionary = victory.found_new_company()
    check(bool(founded.get("ok", false)), "A new dynasty begins")
    check(str(founded.get("prior_path", "")) == "monopolist", "Dynasty remembers its origin")
    check(int(finance.cash) == 50000, "Heir capital funds the new company")
    check(float(finance.get("equity_contributed")) == 50000.0, "Heir capital balances the books")
    check(int(state.get_value("player", "reputation", -1)) == 5, "Heir reputation applies")
    check(state.get_value("ownership", "holdings", []).is_empty(), "Old holdings do not carry over")
    check(victory.stored_victory().is_empty(), "Victory resets for the new run")
    check(str(state.get_value("company", "message", "")).find("dynasty") >= 0, "Refounding announced")

    var reloaded = Victory.new()
    root.add_child(reloaded)
    await process_frame
    check(reloaded.prestige_wins() == 1, "Prestige survives restarts")
    check(int(reloaded.prestige_bonuses().get("starting_cash", 0)) == 25000, "Reloaded bonuses match")

    var Rivals = load("res://scripts/competitors.gd")
    var model = Rivals.new()
    model._normalize()
    for r in model.rivals:
        (r as Dictionary)["cash"] = 50000
    (model.rivals[0] as Dictionary)["assets"] = 9
    (model.rivals[0] as Dictionary)["businesses"] = 4
    for i in range(1, (model.rivals as Array).size()):
        ((model.rivals as Array)[i] as Dictionary)["businesses"] = 1
        ((model.rivals as Array)[i] as Dictionary)["assets"] = 1
    var war: Dictionary = model.maybe_corporate_war(36)
    check(bool(war.get("eliminated", false)), "War eliminates before refounding")
    model.reset_to_founding()
    var living := 0
    for r in (model.rivals as Array):
        if not bool((r as Dictionary).get("eliminated", false)):
            living += 1
    check(living == 3 and (model.rivals as Array).size() == 3, "Refounding restores three living rivals")
    check(int((model.rivals[0] as Dictionary).get("businesses", 0)) > 1, "Founding businesses restored")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for dynasty wiring")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        check(game.has_method("found_new_company"), "Main exposes found_new_company")
        state.set_value("ownership", "holdings", [{"rival_id": "r1", "rival_name": "R1", "shares": 50, "avg_price": 10.0, "total_paid": 500.0}])
        var auto = root.get_node_or_null("RenewVictorySystem")
        check(bool(auto.check_victory().get("ok", false)), "Second victory wins")
        game.found_new_company()
        check(int(finance.cash) == 75000, "Second heir capital stacks")
        var scene_rivals = game.command_system.relationship_system.rivals
        var alive := 0
        for r in scene_rivals.rivals:
            if not bool((r as Dictionary).get("eliminated", false)):
                alive += 1
        check(alive == (scene_rivals.rivals as Array).size(), "Dynasty faces living rivals")
        check(root.get_node_or_null("RenewWorldEventSystem").active().is_empty(), "No crises carry over")
        check(int(root.get_node_or_null("RenewLiveOpsSystem").get("current_season")) == 1, "Seasons restart")
        var kinds := {}
        for e in root.get_node_or_null("RenewHistorySystem").get_timeline("", 100):
            kinds[str((e as Dictionary).get("type", ""))] = true
        check(not kinds.has("corporate_war") and not kinds.has("world_event"), "History restarts clean")
        game.free()
        await process_frame
    reloaded.queue_free()
    victory.queue_free()
    await process_frame
    if FileAccess.file_exists(PRESTIGE_PATH):
        DirAccess.remove_absolute(PRESTIGE_PATH)
    print("V34 PRESTIGE RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
