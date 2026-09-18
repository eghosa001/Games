extends SceneTree

var failed := 0

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
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

    var state = root.get_node_or_null("RenewGameState")
    var finance = root.get_node_or_null("RenewFinanceSystem")
    check(state != null and finance != null, "Canonical state and finance resolve")
    if state == null or finance == null:
        game.free()
        quit(1)
        return

    var finance_cash := int(finance.get("cash"))
    var game_cash := int(game.cash)
    var mirror_cash := int(state.get_value("economy", "cash", 0))
    check(game_cash == 35000, "Real new game starts with $35,000 (game=$%d finance=$%d mirror=$%d)" % [game_cash, finance_cash, mirror_cash])
    check(mirror_cash == game_cash, "Cash mirror matches FinanceSystem (game=$%d finance=$%d mirror=$%d)" % [game_cash, finance_cash, mirror_cash])
    var balance_source := FileAccess.get_file_as_string("res://scripts/game_balance.gd")
    check(not balance_source.contains("record_equity("), "Startup balance helper does not add extra equity")
    check(not balance_source.contains("game.stages ="), "Startup balance helper leaves restoration stages authoritative")

    game.inspect_property()
    game.acquire_property()
    for _i in range(4):
        game.restore_property()
        await process_frame
    check(str(state.get_value("properties", "stage", "")) == "Operational", "Starting bankroll completes restoration")

    game.choose_business_purpose(0)
    check(bool(state.get_value("businesses", "business_open", false)), "Starting bankroll launches first business")

    var cash_before_inputs := int(game.cash)
    game.buy_inputs()
    game.produce_goods()
    check(int(state.get_value("production", "finished_goods", 0)) > 0, "Starting bankroll funds first production run")
    check(int(game.cash) >= 0 and int(game.cash) < cash_before_inputs, "Opening production spends cash without bankruptcy")

    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)

func check(condition: bool, label: String) -> void:
    if condition:
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)
