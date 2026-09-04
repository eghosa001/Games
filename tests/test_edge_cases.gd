extends SceneTree

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
    test_economy_edges()
    test_production_edges()
    test_save_edges()
    await test_scene_edges()
    print("EDGE RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

func test_economy_edges() -> void:
    var economy = load("res://scripts/economy.gd").new()
    check(economy.supplier_for("unknown").is_empty(), "Economy unknown supplier")
    check(not bool(economy.quote("unknown", 1).get("ok", true)), "Economy unknown quote")
    check(not bool(economy.buy_resource("timber", 100000, 1).get("ok", true)), "Economy insufficient cash")
    economy.set_market_modifier("timber", 99.0)
    check(float(economy.market_multipliers["timber"]) == 1.6, "Economy modifier upper clamp")
    economy.set_market_modifier("timber", 0.1)
    check(float(economy.market_multipliers["timber"]) == 0.65, "Economy modifier lower clamp")
    economy.clear_market_modifiers()

func test_production_edges() -> void:
    var production = load("res://scripts/production_system.gd").new()
    var economy = load("res://scripts/economy.gd").new()
    check(not bool(production.produce(economy, 0, "furniture").get("ok", true)), "Production rejects zero cycles")
    economy.resources["timber"]["stock"] = 20
    economy.resources["iron"]["stock"] = 20
    economy.resources["energy"]["stock"] = 20
    var result = production.produce(economy, 3, "furniture")
    check(bool(result.get("ok", false)), "Production accepts canonical furniture inputs")
    check(int(result.get("output", 0)) > 0, "Production creates output")
    check(not bool(production.produce(economy, 1, "not_a_product").get("ok", true)), "Production rejects unknown product")

func test_save_edges() -> void:
    var save = load("res://scripts/save_system.gd")
    check(save != null, "Save system loads")
    check(save.save_game({"edge":true,"nested":{"ok":true}}), "Save system writes")
    var data = save.load_game()
    check(bool(data.get("edge", false)), "Save system reads boolean")
    check(bool(data.get("nested", {}).get("ok", false)), "Save system reads nested state")

func test_scene_edges() -> void:
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene available for edge fixture")
    if scene == null:
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    game.cash = 500000
    game.inspect_property()
    check(game.inspected, "Property inspection edge path")
    game.acquire_property()
    check(game.owned, "Property acquisition edge path")
    for _i in range(5):
        game.restore_property()
    check(game.stage == "Operational", "Property restoration edge path")
    game.choose_business_purpose(0)
    check(str(game.command_system.business_system.get_business_purpose(0).get("industry_id", "")) == "furniture", "Furniture purpose remains canonical")
    game.open_business()
    check(game.business_open, "Business opening edge path")
    game.queue_free()
    await process_frame
