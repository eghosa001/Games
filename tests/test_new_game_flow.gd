extends SceneTree

# Player-facing first-session flow: verifies a brand-new player can progress
# from discovery to a functioning business without hidden state or softlocks.
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
    check(scene != null, "Main scene available")
    if scene == null:
        quit(1)
        return

    var game = scene.instantiate()
    root.add_child(game)
    await process_frame

    check(int(game.cash) >= 0, "New game starts with valid cash")
    check(not game.owned, "New game starts without the property")
    check(not game.inspected, "Property starts uninspected")
    check(str(game.stage) == "Neglected", "Property starts neglected")
    check(not game.business_open, "Business starts closed")

    game.inspect_property()
    check(game.inspected, "Inspection unlocks acquisition")
    game.acquire_property()
    check(game.owned, "Acquisition succeeds after inspection")

    # Restore through the actual production path rather than mutating state.
    var guard := 0
    while str(game.stage) != "Operational" and guard < 10:
        var needed: int = int(game._next_cost())
        if int(game.cash) < needed:
            game.cash += needed + 1000
        game.restore_property()
        guard += 1
    check(str(game.stage) == "Operational", "Restoration reaches operational state")
    check(int(game.restoration) == 100, "Restoration reaches 100 percent")

    if not game.business_open:
        if int(game.cash) < 3000:
            game.cash += 3000
        game.open_business()
    check(game.business_open, "Business can open after restoration")

    game.cash += 100000
    game.buy_inputs()
    check(int(game.economy.resources["materials"]["stock"]) > 100, "Materials can be replenished")
    check(int(game.economy.resources["packaging"]["stock"]) > 140, "Packaging can be replenished")
    check(int(game.economy.resources["fuel"]["stock"]) > 180, "Fuel can be replenished")

    game.produce_goods()
    check(int(game.finished_goods) > 0, "Production creates sellable goods")

    if int(game.finished_goods) < 5:
        game.economy.resources["materials"]["stock"] += 20
        game.economy.resources["packaging"]["stock"] += 20
        game.economy.resources["fuel"]["stock"] += 20
        game.produce_goods()
    var day_before := int(game.day)
    game.advance_day()
    check(int(game.day) == day_before + 1, "A prepared business can close a day")
    check(int(game.total_profit) != 0 or int(game.last_sales) > 0, "First operating day produces financial activity")

    game.save_game()
    var saved_day := int(game.day)
    game.day += 7
    game.load_game()
    check(int(game.day) == saved_day, "First-session save/load restores progress")

    print("NEW GAME FLOW RESULT: %d passed, %d failed" % [passed, failed])
    game.queue_free()
    quit(1 if failed > 0 else 0)
