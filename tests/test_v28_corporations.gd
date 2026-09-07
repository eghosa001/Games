extends SceneTree

## V2.8: advanced corporations. Development tiers change behavior as rivals
## grow, and Helios Energy enters mid-game once the player matters.
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

func _ids(rivals) -> Array:
    var ids: Array = []
    for r in rivals.rivals:
        ids.append(str(r.get("id", "")))
    return ids

func run() -> void:
    var Rivals = load("res://scripts/competitors.gd")
    check(Rivals != null, "Competitor model loads")
    if Rivals == null:
        quit(1)
        return
    var rivals = Rivals.new()
    rivals._normalize()
    check(rivals.corporate_tier(rivals.rivals[0]) == "National", "Established rivals start National")
    check(rivals.corporate_tier({"assets": 2, "businesses": 1}) == "Regional", "Small outfits read Regional")
    check(rivals.corporate_tier({"assets": 12, "businesses": 5}) == "Global", "Heavyweights read Global")
    check(not _ids(rivals).has("helios_energy"), "Helios absent at founding")
    check(rivals.maybe_spawn_entrant(10, 100) == "", "No entrant in the opening")
    check(rivals.maybe_spawn_entrant(60, 5) == "", "No entrant without standing")
    var announcement: String = rivals.maybe_spawn_entrant(60, 40)
    check(not announcement.is_empty(), "Entrant announced at day 60 with standing")
    check(_ids(rivals).has("helios_energy"), "Helios joins the market")
    check(rivals.maybe_spawn_entrant(200, 100) == "", "Entrant spawns exactly once")
    var entrant: Dictionary = {}
    for r in rivals.rivals:
        if str(r.get("id", "")) == "helios_energy":
            entrant = r
    check(str(entrant.get("strategy", "")) == "energy_leverage", "Entrant plays energy leverage")
    check(str(entrant.get("tier", "")) == "Regional", "Entrant starts Regional")
    var pressure_before := int(entrant.get("supplier_pressure", 0))
    var result: String = rivals._execute_strategy(entrant, "corner_energy_market", {}, 61)
    check(result == "corner_energy_market", "Energy corner executes")
    check(int(entrant.get("supplier_pressure", 0)) > pressure_before, "Energy corner pressures supply")
    var snapshot: Dictionary = rivals.capture_state()
    var restored = Rivals.new()
    restored.restore_state(snapshot)
    check(_ids(restored).has("helios_energy"), "Entrant persists across save/load")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for tier display")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        var status: Dictionary = game.command_system.relationship_system.rivals.ai_status(0)
        check(status.has("tier"), "Corporation status exposes tier")
        game.free()
        await process_frame
    print("V28 CORPORATIONS RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
