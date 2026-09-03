extends SceneTree

# Player-facing first-session journey. This test must use the real V1 starting
# economy and must never inject cash/resources to make the journey succeed.
# Restoration mechanics with controlled/injected funds belong in
# test_restoration_mechanics.gd.
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

    var starting_cash := int(game.cash)
    check(starting_cash >= 0, "New game starts with valid V1 cash")
    check(not game.owned, "New game starts without the property")
    check(not game.inspected, "Property starts uninspected")
    check(str(game.stage) == "Neglected", "Property starts neglected")
    check(not game.business_open, "Business starts closed")

    game.inspect_property()
    check(game.inspected, "Inspection unlocks acquisition")
    game.acquire_property()
    check(game.owned, "Acquisition succeeds after inspection")

    # Genuine player journey: restoration must be affordable from the actual
    # V1 starting balance. Never top up cash here. If this fails, it exposes a
    # real onboarding/balance problem instead of hiding it.
    var guard := 0
    while str(game.stage) != "Operational" and guard < 10:
        var needed: int = int(game._next_cost())
        check(int(game.cash) >= needed, "V1 starting economy can fund restoration step %d" % [guard + 1])
        if int(game.cash) < needed:
            break
        game.restore_property()
        guard += 1
    check(int(game.cash) < starting_cash, "Restoration consumes real starting funds")
    check(str(game.stage) == "Operational", "V1 starting economy reaches operational state")
    check(int(game.restoration) == 100, "Restoration reaches 100 percent")

    var purposes: Array = game.get_business_purposes()
    check(purposes.size() == 3, "All three V1 industries are available")
    check(str(purposes[0].get("industry_id", "")) == "furniture", "Furniture industry is selectable")
    check(str(purposes[1].get("industry_id", "")) == "construction_materials", "Construction Materials industry is selectable")
    check(str(purposes[2].get("industry_id", "")) == "consumer_electronics", "Consumer Electronics industry is selectable")

    if not game.business_open:
        game.choose_business_purpose(0)
        game.open_business()
    check(game.business_open, "Business can open after restoration and industry selection")

    # Production is also part of the real first-session journey. No cash or
    # resource injection is allowed; procurement must use the live V1 economy.
    var canonical_resources := ["timber", "iron", "energy", "food", "electronics"]
    for resource in canonical_resources:
        check(game.economy.resources.has(resource), "Canonical resource available: %s" % resource)
    check(not game.economy.resources.has("materials") and not game.economy.resources.has("packaging") and not game.economy.resources.has("fuel"), "Legacy resources are not live economy resources")

    var goods_before := int(game.finished_goods)
    game.produce_goods()
    check(int(game.finished_goods) > goods_before, "Production creates sellable goods from V1 economy")

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
