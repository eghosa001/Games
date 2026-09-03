extends SceneTree

# Controlled restoration-mechanics test. Unlike test_new_game_flow.gd, this
# suite may inject cash so restoration behavior can be tested independently of
# V1 onboarding balance.
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
    seed(123456)
    var scene := load("res://scenes/Main.tscn")
    check(scene != null, "Main scene available")
    if scene == null:
        quit(1)
        return

    var game = scene.instantiate()
    root.add_child(game)
    await process_frame

    game.inspect_property()
    check(game.inspected, "Inspection unlocks acquisition")
    game.acquire_property()
    check(game.owned, "Acquisition succeeds after inspection")

    # Controlled fixture: restoration behavior is the subject of this test,
    # so provide enough cash rather than coupling it to V1 starting balance.
    game.cash = max(int(game.cash), 100000)
    var starting_restoration := int(game.restoration)
    var starting_cash := int(game.cash)
    var steps := 0
    while str(game.stage) != "Operational" and steps < 10:
        var needed: int = int(game._next_cost())
        check(int(game.cash) >= needed, "Injected restoration fixture can fund step %d" % [steps + 1])
        if int(game.cash) < needed:
            break
        game.restore_property()
        steps += 1

    check(int(game.restoration) > starting_restoration, "Restoration increases property restoration")
    check(int(game.cash) < starting_cash, "Restoration charges cash")
    check(str(game.stage) == "Operational", "Restoration mechanics reach operational state")
    check(int(game.restoration) == 100, "Restoration mechanics reach 100 percent")

    game.queue_free()
    print("RESTORATION MECHANICS RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
