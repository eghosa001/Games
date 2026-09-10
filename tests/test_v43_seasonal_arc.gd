extends SceneTree

## V4.3: seasonal liveops arc. Season rotation triggers themed world events
## whose sales/production/research effects scale the real formulas.
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
    check(scene != null, "Main scene loads with seasonal effects")
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
    if state.has_method("clear"):
        state.clear()
    var services = root.get_node_or_null("RenewServices")
    var liveops = services.get_service("RenewLiveOpsSystem") if services != null else null
    var world = services.get_service("RenewWorldEventSystem") if services != null else null
    var tech = services.get_service("RenewTechnologySystem") if services != null else null
    check(liveops != null and world != null and tech != null, "LiveOps, world and tech systems available")
    if liveops == null or world == null or tech == null:
        game.free()
        quit(1)
        return

    var before: Dictionary = liveops.get_state()
    check(int(before.get("season", 0)) >= 1, "Season calendar running")
    state.set_value("player", "day", 31)
    liveops.season_start_day = 1
    liveops.process_day(31)
    var after: Dictionary = liveops.get_state()
    check(int(after.get("season", 0)) == int(before.get("season", 0)) + 1, "Season advances every 30 days")
    check((after.get("offers", {}) as Dictionary).has("seasonal"), "New season posts an offer")
    check((after.get("challenges", {}) as Dictionary).size() > 0, "New season posts a challenge")
    var names: Array = []
    for e in world.active():
        names.append(str((e as Dictionary).get("id", "")))
    check(names.has("season_2_global_trade_week"), "Trade Week event fires in season 2")
    check(abs(float(state.get_world_modifier("sales", 0.0)) - 1.15) < 0.001, "Trade Week lifts sales")
    check(abs(float(state.get_world_modifier("logistics", 0.0)) - 0.90) < 0.001, "Trade Week eases logistics")

    state.set_value("technology", "research_points", 20)
    tech.add_daily_research_points(3)
    var calm := int(state.get_value("technology", "research_points", 0))
    check(calm == 23, "Calm research credits 3 points")
    state.set_world_modifier("research", 1.25)
    tech.add_daily_research_points(3)
    var boosted := int(state.get_value("technology", "research_points", 0))
    check(boosted == calm + 4, "Innovation seasons credit 25 percent more")
    state.clear_world_modifiers()
    tech.add_daily_research_points(3)
    check(int(state.get_value("technology", "research_points", 0)) == boosted + 3, "Cleared modifiers restore baseline")

    var done: Dictionary = liveops.complete_challenge("challenge_2", 5)
    check(bool(done.get("ok", false)), "Seasonal challenge completes")
    check(bool((done.get("challenge", {}) as Dictionary).get("completed", false)), "Completion recorded")

    game.free()
    await process_frame
    print("V43 SEASONAL ARC RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
