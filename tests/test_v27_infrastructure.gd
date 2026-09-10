extends SceneTree

## V2.7: regional infrastructure with teeth. Power, logistics, storage,
## research and factory bonuses flow from founder-owned active assets into
## freight, operating costs, warehouse limits, research and production.
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
    var Infra = load("res://scripts/infrastructure_system.gd")
    check(Infra != null, "Infrastructure system loads")
    if Infra == null:
        quit(1)
        return
    var infra = Infra.new()
    root.add_child(infra)
    await process_frame
    var neutral: Dictionary = infra.founder_modifiers()
    check(float(neutral.get("logistics", 0.0)) == 1.0, "No assets means neutral logistics")
    check(float(neutral.get("energy", 0.0)) == 1.0, "No assets means neutral energy")
    var road: Dictionary = infra.build("road", 0, "founder", 1000000, 1)
    check(bool(road.get("ok", false)), "Road construction starts")
    var power: Dictionary = infra.build("power_plant", 0, "founder", 1000000, 1)
    check(bool(power.get("ok", false)), "Power plant construction starts")
    var bad: Dictionary = infra.build("moon_base", 0, "founder", 1000000, 1)
    check(not bool(bad.get("ok", false)), "Unknown type rejected")
    for day in range(1, 12):
        infra.process_day(day)
    var mods: Dictionary = infra.founder_modifiers()
    check(float(mods.get("logistics", 1.0)) < 1.0, "Roads cut freight")
    check(float(mods.get("energy", 1.0)) > 1.0, "Power plants add energy")
    var store: Dictionary = infra.capture_state()
    var restored = Infra.new()
    root.add_child(restored)
    restored.restore_state(store)
    check(restored.founder_modifiers().get("logistics", 1.0) == mods.get("logistics", 1.0), "Modifiers persist across save/load")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for infrastructure commands")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        current_scene = game
        await process_frame
        await process_frame
        check(game.get_node_or_null("UI/InfrastructurePanel") != null, "Infrastructure panel is mounted")
        for method in ["infra_build", "infra_type", "infra_repair"]:
            check(game.has_method(method), "Main exposes %s" % method)
        game.cash = 300000
        game.infra_type()
        game.infra_build()
        var services = root.get_node_or_null("RenewServices")
        var live_infra = services.get_service("RenewInfrastructureSystem") if services != null else null
        check(live_infra != null and live_infra.list_assets().size() > 0, "Touch command builds infrastructure")
        game.free()
        await process_frame
    infra.queue_free()
    restored.queue_free()
    await process_frame
    print("V27 INFRASTRUCTURE RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
