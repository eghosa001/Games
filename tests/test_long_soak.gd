extends SceneTree

var passed := 0
var failed := 0

func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    if ok: passed += 1
    else: failed += 1; push_error("FAIL: " + label)

func run() -> void:
    await soak_days(365)
    await soak_save_load(60)
    print("LONG SOAK RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

func soak_days(days: int) -> void:
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "V1 long soak main scene loads")
    if scene == null: return
    var game = scene.instantiate(); root.add_child(game); await process_frame
    var state = get_node_or_null("/root/RenewGameState")
    check(state != null, "Canonical GameState is available")
    var start_day := int(state.get_value("player", "day", 1)) if state != null else 1
    # advance_day is intentionally gated until a business is operating.
    # Bootstrap the smallest valid V1 business fixture instead of testing an
    # impossible closed-business day transition.
    game.cash = 500000
    game.inspect_property()
    game.acquire_property()
    for _i in range(5):
        game.restore_property()
    game.choose_business_purpose(0)
    game.open_business()
    check(bool(game.business_open), "V1 soak fixture opens a business")
    for i in range(days):
        game.advance_day()
        var current_day := int(state.get_value("player", "day", 0)) if state != null else 0
        check(current_day == start_day + i + 1, "V1 day progression %d" % (i + 1))
        check(current_day >= 1, "V1 day remains valid %d" % (i + 1))
        if i % 30 == 0: game.save_game()
    check(int(state.get_value("player", "day", 0)) == start_day + days, "V1 soak final day")
    game.free(); await process_frame

func soak_save_load(rounds: int) -> void:
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "V1 save/load soak scene loads")
    if scene == null: return
    var game = scene.instantiate(); root.add_child(game); await process_frame
    var state = get_node_or_null("/root/RenewGameState")
    for i in range(rounds):
        state.set_value("player", "day", 20 + i)
        state.set_value("economy", "cash", 50000 + i)
        game.save_game()
        state.set_value("player", "day", 1)
        state.set_value("economy", "cash", 1)
        game.load_game()
        check(int(state.get_value("player", "day", 0)) == 20 + i, "V1 save/load day round %d" % (i + 1))
        check(int(state.get_value("economy", "cash", 0)) == 50000 + i, "V1 save/load cash round %d" % (i + 1))
    game.free(); await process_frame
