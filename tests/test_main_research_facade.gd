extends SceneTree

## Regression: the player-facing Main research facade must use the gameplay command
## path so technology consumes both resources and elapsed simulation days.
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
    var finance = root.get_node_or_null("RenewFinanceSystem")
    var services = root.get_node_or_null("RenewServices")
    var technology = services.get_service("RenewTechnologySystem") if services != null else null
    check(state != null and finance != null and technology != null, "Research dependency stack resolves")
    if state == null or finance == null or technology == null:
        game.free()
        quit(1)
        return

    game.cash = 100000
    state.set_value("businesses", "business_open", true)
    state.set_value("technology", "research_points", 100)
    var start_day := int(game.day)
    var expected_days := int(technology.get_research_time_days("efficient_production"))

    game.research_technology("efficient_production")
    await process_frame
    await process_frame

    check(technology.is_unlocked("efficient_production"), "Main facade unlocks the selected technology")
    check(int(game.day) == start_day + expected_days, "Main facade simulates the full research duration")
    var research_spend := 0
    for entry in finance.history:
        if not (entry is Dictionary):
            continue
        var record: Dictionary = entry
        if str(record.get("kind", "")) == "spend" and str(record.get("reason", "")).find("technology research") >= 0:
            research_spend += int(record.get("amount", 0))
    check(research_spend >= 2500, "Main facade charges technology research")
    check(bool(finance.validate_invariants().get("ok", false)), "Research facade keeps finance invariants valid")

    print("MAIN RESEARCH FACADE RESULT: %d passed, %d failed" % [passed, failed])
    game.free()
    await process_frame
    quit(1 if failed > 0 else 0)
