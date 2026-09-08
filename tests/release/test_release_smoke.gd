extends SceneTree

## Release-gate smoke inside tests/release: boot, first operating day,
## save/load round-trip and schema contract. All assertions execute real
## gameplay through Main; any failure exits non-zero.
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
    check(packed != null, "Release loads the main scene")
    if packed == null:
        quit(1)
        return
    var game := packed.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    var state = root.get_node_or_null("RenewGameState")
    check(state != null, "Release boots canonical state")
    if state == null:
        game.free()
        quit(1)
        return
    check(int(state.get_value("player", "day", 0)) >= 1, "Release starts on day one")
    game.cash = 250000
    game.day = 1
    game.inspect_property()
    game.acquire_property()
    check(bool(state.get_value("properties", "owned", false)), "Release acquires property")
    var guard := 0
    while str(state.get_value("properties", "stage", "")) != "Operational" and guard < 20:
        game.restore_property()
        guard += 1
        await process_frame
    check(str(state.get_value("properties", "stage", "")) == "Operational", "Release restores property")
    game.choose_business_purpose(0)
    game.open_business()
    check(bool(state.get_value("businesses", "business_open", false)), "Release opens business")
    game.hire_employee()
    game.buy_inputs()
    game.produce_goods()
    check(int(state.get_value("production", "finished_goods", 0)) > 0, "Release produces goods")
    var day_before := int(state.get_value("player", "day", 1))
    game.advance_day()
    await process_frame
    check(int(state.get_value("player", "day", 0)) == day_before + 1, "Release advances days")
    game.save_game()
    var cash_saved := int(state.get_value("economy", "cash", 0))
    state.set_value("economy", "cash", 1)
    game.load_game()
    await process_frame
    check(int(state.get_value("economy", "cash", 0)) == cash_saved, "Release save/load round-trips")
    var snapshot: Dictionary = state.capture()
    check(int(snapshot.get("schema_version", 0)) == 8, "Release save uses schema 8")
    game.free()
    current_scene = null
    # Wait for deferred tree teardown to complete.
    for _i in range(8):
        await process_frame
    print("RELEASE SMOKE RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
