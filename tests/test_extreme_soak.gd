extends SceneTree

# Extreme-duration stability pass. This intentionally exercises the live Main
# scene for 1,000 in-game days and repeatedly saves/loads the complete state.
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
    var scene := load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for extreme soak")
    if scene == null:
        quit(1)
        return

    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    game.cash = 250000
    game.reputation = 80
    game.inspected = true
    game.owned = true
    game.stage = "Operational"
    game.restoration = 100
    game.business_open = true
    game.economy.resources["materials"]["stock"] = 1000
    game.economy.resources["packaging"]["stock"] = 1000
    game.economy.resources["fuel"]["stock"] = 1000

    var start_day := int(game.day)
    var save_controller = game.get_node_or_null("GameStateBridge")
    for i in range(1000):
        if int(game.finished_goods) < 5:
            game.produce_goods()
        if int(game.finished_goods) < 5:
            game.economy.resources["materials"]["stock"] += 50
            game.economy.resources["packaging"]["stock"] += 50
            game.economy.resources["fuel"]["stock"] += 50
            game.produce_goods()
        game.advance_day()
        check(int(game.day) == start_day + i + 1, "Day progression remains exact at iteration %d" % (i + 1))
        check(int(game.cash) > -1000000000, "Cash remains bounded at day %d" % int(game.day))
        check(int(game.reputation) >= 0, "Reputation never becomes negative at day %d" % int(game.day))

        if i % 50 == 0:
            game.save_game()
        if i % 100 == 0:
            game.load_game()
        if save_controller != null and i % 125 == 0:
            save_controller._save_extended_state(false)
            save_controller._load_extended_state()

    check(int(game.day) == start_day + 1000, "Extreme soak reaches exactly 1,000 elapsed days")
    check(game.expansion.properties is Array, "Expansion state remains valid after extreme soak")
    check(game.expansion.resource_sites is Array, "Resource-site state remains valid after extreme soak")
    check(game.rivals.rivals is Array and game.rivals.rivals.size() > 0, "Rival state remains valid after extreme soak")
    check(game.economy.resources is Dictionary, "Economy state remains valid after extreme soak")

    print("EXTREME SOAK RESULT: %d passed, %d failed" % [passed, failed])
    game.queue_free()
    quit(1 if failed > 0 else 0)
