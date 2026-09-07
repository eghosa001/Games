extends SceneTree

## V8.9: economic cycles. 45-day phases rotate expansion to recovery with
## per-industry demand sensitivity, announced into the verified pipeline.
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

func _set_cycle(state: Variant, phase: String, start_day: int) -> void:
    var table: Dictionary = (state.get_value("events", "seasonal", {}) as Dictionary).duplicate(true)
    table["economy_cycle"] = {"phase": phase, "start_day": start_day}
    state.set_value("events", "seasonal", table)

func run() -> void:
    var World = load("res://scripts/world_event_system.gd")
    check(World != null, "World event system loads")
    if World == null:
        quit(1)
        return
    var state = root.get_node_or_null("RenewGameState")
    check(state != null, "GameState is available")
    if state == null:
        quit(1)
        return
    if state.has_method("clear"):
        state.clear()
    var world: Node = World.new()
    root.add_child(world)
    await process_frame

    world.process_day(1)
    check(str(world.cycle_phase().get("phase", "")) == "expansion", "Cycle starts in expansion")
    check(abs(float(state.get_world_modifier("cycle_furniture", 0.0)) - 1.0) < 0.001, "Expansion demand neutral")
    _set_cycle(state, "expansion", 1)
    world.process_day(46)
    check(str(world.cycle_phase().get("phase", "")) == "boom", "Cycle advances to boom")
    check(abs(float(state.get_world_modifier("cycle_furniture", 0.0)) - 1.20) < 0.001, "Boom lifts furniture demand")
    check(abs(float(state.get_world_modifier("cycle_construction_materials", 0.0)) - 1.30) < 0.001, "Boom lifts construction most")
    var announced := false
    for line in (state.get_value("company", "log_lines", []) as Array):
        if str(line).find("Economic Boom") >= 0:
            announced = true
    check(announced, "Phase change announced")
    _set_cycle(state, "overheating", 46)
    world.process_day(91)
    check(str(world.cycle_phase().get("phase", "")) == "recession", "Cycle reaches recession")
    check(abs(float(state.get_world_modifier("cycle_construction_materials", 0.0)) - 0.60) < 0.01, "Recession hits construction hardest")
    check(abs(float(state.get_world_modifier("cycle_consumer_electronics", 0.0)) - 0.75) < 0.01, "Recession hits electronics softer")
    _set_cycle(state, "recovery", 91)
    world.process_day(136)
    check(str(world.cycle_phase().get("phase", "")) == "expansion", "Cycle wraps to expansion")
    var snapshot: Dictionary = world.capture_state()
    var restored = World.new()
    root.add_child(restored)
    await process_frame
    restored.restore_state(snapshot)
    check(str(restored.cycle_phase().get("phase", "")) == "expansion", "Cycle persists across save/load")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads with cycle pricing")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        game.free()
        await process_frame
    restored.queue_free()
    world.queue_free()
    await process_frame
    print("V89 CYCLES RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
