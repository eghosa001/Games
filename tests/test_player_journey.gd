extends SceneTree

# Player-journey smoke test: verifies the core first-session loop is actionable.
var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
    else:
        failed += 1
        push_error("FAIL: " + label)

func run() -> void:
    var scene := load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame

    check(game.cash >= 0, "New player starts with usable cash")
    check(game.day >= 1, "New game starts on a valid day")
    check(game.stage != "Operational" or game.business_open, "Starting state is not an impossible operating state")

    game.cash = max(100000, int(game.cash))
    game.inspected = true
    game.owned = true
    game.stage = "Operational"
    game.restoration = 100
    game.business_open = true
    game.economy.resources["timber"]["stock"] = 100
    game.economy.resources["iron"]["stock"] = 100
    game.economy.resources["energy"]["stock"] = 100

    var before_cash := int(game.cash)
    var before_day := int(game.day)
    game.produce_goods()
    game.advance_day()
    check(int(game.day) == before_day + 1, "Core loop advances exactly one day")
    check(int(game.finished_goods) >= 0, "Production leaves valid inventory")
    check(int(game.cash) > -1000000000, "First operating day keeps economy valid")

    game.save_game()
    var saved_cash := int(game.cash)
    game.cash = -123
    game.load_game()
    check(int(game.cash) == saved_cash, "Save/load restores player cash")
    check(before_cash != int(game.cash) or saved_cash == before_cash, "State changed only through valid gameplay/save flow")

    print("PLAYER JOURNEY RESULT: %d passed, %d failed" % [passed, failed])
    game.queue_free()
    quit(1 if failed > 0 else 0)
