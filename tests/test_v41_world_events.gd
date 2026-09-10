extends SceneTree

## V4.1: world events actually fire. The catalog seeds the trigger table,
## scheduled rolls create one instance per day, and expiry queues follow-ups.
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
    var World = load("res://scripts/world_event_system.gd")
    check(World != null, "World event system loads")
    if World == null:
        quit(1)
        return
    var world: Node = World.new()
    root.add_child(world)
    await process_frame
    check(not (world.get("events") as Dictionary).is_empty(), "Catalog seeds the trigger table")
    check((world.get("events") as Dictionary).has("energy_crisis"), "Energy crisis registered")
    check((world.get("events") as Dictionary).has("financial_crisis"), "Financial crisis registered")

    world.process_day(17)
    var active: Array = world.active()
    check(active.size() == 1, "Energy crisis fires on day 17")
    check(str(active[0].get("id", "")) == "energy_crisis", "Correct crisis fires")
    check(int(active[0].get("end_day", 0)) == 21, "Crisis lasts its duration")
    world.process_day(17)
    check(world.active().size() == 1, "Same-day rolls do not duplicate")
    var instance_id := str(active[0].get("instance_id", ""))
    var chosen: Dictionary = world.choose(instance_id, "ration")
    check(bool(chosen.get("ok", false)), "Crisis choice resolves")
    var decided: Dictionary = world.get_event(instance_id)
    check(str(decided.get("resolution", {}).get("choice", "")) == "ration", "Choice recorded on the crisis")
    check(abs(float((decided.get("effects", {}) as Dictionary).get("energy_price", 0.0)) - 1.10) < 0.001, "Choice effects reshape the crisis")
    check(world.active().size() == 1, "Decided crisis stays on the board")
    check(not bool(world.choose(instance_id, "subsidize").get("ok", false)), "Crises decide once")
    world.process_day(21)
    var chained: Array = []
    for e in world.active():
        chained.append(str((e as Dictionary).get("id", "")))
    check(not chained.has("energy_crisis") and chained.has("energy_price_shock"), "Expiry queues the follow-up")
    world.process_day(22)
    chained = []
    for e in world.active():
        chained.append(str((e as Dictionary).get("id", "")))
    check(chained.has("alternative_energy_demand"), "Expiry chains decided crises into follow-ups")
    check(not bool(world.choose("world_event:9999", "ration").get("ok", false)), "Unknown crises rejected")
    check(world.history_list().size() >= 2, "History records the chain")

    world.process_day(23)
    var ids: Array = []
    for e in world.active():
        ids.append(str((e as Dictionary).get("id", "")))
    check(ids.has("supply_disruption"), "Supply crisis fires on day 23")
    world.process_day(31)
    ids = []
    for e in world.active():
        ids.append(str((e as Dictionary).get("id", "")))
    check(ids.has("financial_crisis"), "Financial crisis fires on day 31")

    var snapshot: Dictionary = world.capture_state()
    var restored = World.new()
    root.add_child(restored)
    await process_frame
    restored.restore_state(snapshot)
    check((restored.get("events") as Dictionary).has("energy_crisis"), "Catalog survives save/load")
    check(restored.active().size() == world.active().size(), "Active crises persist")
    check(restored.history_list().size() == world.history_list().size(), "History persists")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads with seeded events")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        current_scene = game
        await process_frame
        await process_frame
        var live_world = RenewServices.get_service("RenewWorldEventSystem")
        check(live_world != null and not (live_world.get("events") as Dictionary).is_empty(), "Live trigger table seeded")
        game.free()
        await process_frame
    restored.queue_free()
    world.queue_free()
    await process_frame
    print("V41 WORLD EVENTS RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)