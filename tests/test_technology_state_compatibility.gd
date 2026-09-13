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
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check(packed != null, "Main scene loads")
    if packed == null:
        quit(1)
        return

    var game = packed.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame

    var state = root.get_node_or_null("RenewGameState")
    var tech = root.get_node_or_null("RenewTechnologySystem")
    if tech == null:
        tech = game.get_node_or_null("Systems/TechnologySystem")
    check(state != null, "GameState resolves")
    check(tech != null, "TechnologySystem resolves")
    if state == null or tech == null:
        game.free()
        quit(1)
        return

    state.set_value("technology", "technology", {
        "efficient_production": {"researched": true},
        "better_logistics": {"researched": false},
    })
    check(tech.is_unlocked("efficient_production"), "Legacy researched dictionary is unlocked")
    check(not tech.is_unlocked("better_logistics"), "Legacy unresearched dictionary stays locked")
    check(tech.production_multiplier() > 1.0, "Legacy researched technology contributes effects")
    check(is_equal_approx(tech.transport_capacity_multiplier(), 1.0), "Legacy unresearched technology contributes no effect")

    state.set_value("technology", "technology", {
        "efficient_production": true,
        "better_logistics": false,
    })
    check(tech.is_unlocked("efficient_production"), "Boolean researched state remains supported")
    check(not tech.is_unlocked("better_logistics"), "Boolean locked state remains supported")

    game.free()
    await process_frame
    print("TECHNOLOGY COMPATIBILITY RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
