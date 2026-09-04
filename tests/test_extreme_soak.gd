extends SceneTree

var passed := 0
var failed := 0

func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    if ok: passed += 1
    else: failed += 1; push_error("FAIL: " + label)

func run() -> void:
    var scene := load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for extreme V1 soak")
    if scene == null: quit(1); return
    var game = scene.instantiate(); root.add_child(game); await process_frame
    var state = get_node_or_null("/root/RenewGameState")
    check(state != null, "Canonical GameState is available")
    var start_day := int(state.get_value("player", "day", 1))
    # advance_day requires an operating business; use a deterministic funded
    # fixture so this stress test exercises the real day-transition path.
    game.cash = 500000
    game.inspect_property()
    game.acquire_property()
    for _i in range(5):
        game.restore_property()
    game.choose_business_purpose(0)
    game.open_business()
    check(bool(game.business_open), "Extreme soak fixture opens a business")
    for i in range(1000):
        game.advance_day()
        var day := int(state.get_value("player", "day", 0))
        check(day == start_day + i + 1, "Exact V1 day progression at iteration %d" % (i + 1))
        check(day >= 1, "Day remains valid at iteration %d" % (i + 1))
        if i % 50 == 0: game.save_game()
        if i % 100 == 0: game.load_game()
    check(int(state.get_value("player", "day", 0)) == start_day + 1000, "Extreme soak reaches exactly 1,000 V1 days")
    check(state.get_domain("economy") is Dictionary, "Economy domain remains valid")
    check(state.get_domain("properties") is Dictionary, "Properties domain remains valid")
    check(state.get_domain("employees") is Dictionary, "Employees domain remains valid")
    game.queue_free(); await process_frame
    print("EXTREME SOAK RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
