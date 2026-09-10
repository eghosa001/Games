extends SceneTree

## V8.11: Energy Valley. A late-game energy region charters like the Basin
## and unlocks geothermal and solar capacity.
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
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for valley charter")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    var state = root.get_node_or_null("RenewGameState")
    check(state != null, "GameState is available")
    if state == null:
        game.free()
        quit(1)
        return
    check(game.has_method("charter_valley"), "Main exposes charter_valley")
    var catalog = RenewServices.get_service("RenewRegionSystem")
    check(catalog != null, "Region catalog resolves")
    if catalog == null:
        game.free()
        quit(1)
        return
    game.cash = 300000
    state.set_value("player", "reputation", 20)
    var controller: Node = game.get_node_or_null("World/RegionController")
    game.charter_valley()
    check(str(controller.get("message")).find("50 reputation") >= 0, "Valley charter gated on standing")
    state.set_value("player", "reputation", 60)
    game.charter_valley()
    check(str(controller.get("message")).find("Energy Valley chartered") >= 0, "Valley charters at standing")
    var districts: Dictionary = state.get_value("regions", "districts", {})
    check(bool((districts.get("energy_valley", {}) as Dictionary).get("chartered", false)), "Charter recorded")
    var sites: Dictionary = state.get_value("supply_chain", "resource_sites", {})
    check(sites.has("geothermal_vent") and sites.has("solar_array"), "Valley sites unlock")
    check(int((sites.get("geothermal_vent", {}) as Dictionary).get("capacity", 0)) == 200, "Geothermal leads capacity")
    game.charter_valley()
    check(str(controller.get("message")).find("already chartered") >= 0, "Charter is single-use")
    check(catalog.list_regions().size() == 3, "Three regions charted in the catalog")
    check(not str(catalog.get_region_by_id("energy_valley").get("name", "")).is_empty(), "Valley resolves by id")
    game.free()
    await process_frame
    print("V811 VALLEY RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)