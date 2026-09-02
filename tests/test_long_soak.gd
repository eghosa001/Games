extends SceneTree

var passed := 0
var failed := 0
var failures: Array[String] = []

func _init() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
    else:
        failed += 1
        failures.append(label)
        push_error("FAIL: " + label)

func run() -> void:
    randomize()
    await soak_full_game(365)
    await soak_save_load(120)
    print("LONG SOAK RESULT: %d passed, %d failed" % [passed, failed])
    for failure in failures:
        print("FAILED: " + failure)
    quit(1 if failed > 0 else 0)

func soak_full_game(days: int) -> void:
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "long soak main scene loads")
    if scene == null:
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    game.cash = 10000000
    game.reputation = 100
    game.expansion.unlock_from_reputation(100)

    game.inspect_property()
    game.acquire_property()
    for i in range(5):
        game.restore_property()
    game.open_business()
    game.buy_inputs()
    game.produce_goods()
    game.hire_employee()
    game.upgrade_business()
    game.marketing_campaign()
    game.sign_contract()
    game.select_expansion(0)
    game.expansion.buy(0, game.cash)
    game.expansion.buy_resource_site(0, game.cash)
    game.expansion.generate_resource(0)
    game.select_rival(0)
    game.improve_alliance()
    game.make_alliance_offer()
    game.propose_supply_deal()
    game.propose_customer_partnership()
    game.upgrade_transport()

    for day in range(days):
        while game.finished_goods < 5:
            game.produce_goods()
        var cash_before := int(game.cash)
        var day_before := int(game.day)
        game.advance_day()
        check(int(game.day) == day_before + 1, "soak day progression %d" % (day + 1))
        check(int(game.cash) >= 0 or int(game.debt) > 0, "soak financial state %d" % (day + 1))
        check(int(game.total_profit) == int(game.total_profit), "soak profit finite %d" % (day + 1))
        check(int(game.cash) != -2147483648 and int(game.cash) != 2147483647, "soak cash bounds %d" % (day + 1))
        if day % 30 == 0:
            game.save_game()
        if day % 60 == 0:
            game.load_game()
        if day % 90 == 0:
            game.expansion.generate_resource(0)
            game.improve_alliance()
            game.select_rival(day % 3)
        if day % 120 == 0:
            game.upgrade_transport()
        check(int(game.day) > 0 and int(game.day) == day_before + 1, "soak stable day after actions %d" % (day + 1))
        check(int(game.cash) != cash_before or int(game.total_profit) != 0 or int(game.day) > day_before, "soak state changes %d" % (day + 1))

    check(int(game.day) == days, "soak final day")
    check(game.expansion.properties.size() == 3, "soak expansion count")
    check(game.expansion.resource_sites.size() == 3, "soak resource site count")
    game.free()
    await process_frame

func soak_save_load(rounds: int) -> void:
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "save-load soak scene loads")
    if scene == null:
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    game.cash = 765432
    game.reputation = 88
    game.day = 17
    game.total_profit = 234567
    game.expansion.unlock_from_reputation(100)
    game.expansion.buy(0, 1000000)
    game.expansion.buy_resource_site(0, 1000000)
    game.expansion.generate_resource(0)

    for i in range(rounds):
        game.cash = 765432 + i
        game.total_profit = 234567 + i
        game.day = 17 + i
        game.save_game()
        game.cash = 1
        game.total_profit = 0
        game.day = 0
        game.load_game()
        check(int(game.cash) == 765432 + i, "save-load cash round %d" % (i + 1))
        check(int(game.total_profit) == 234567 + i, "save-load profit round %d" % (i + 1))
        check(int(game.day) == 17 + i, "save-load day round %d" % (i + 1))
        check(game.expansion.properties.size() == 3, "save-load expansion state round %d" % (i + 1))
        check(game.expansion.resource_sites.size() == 3, "save-load resource state round %d" % (i + 1))

    game.free()
    await process_frame
