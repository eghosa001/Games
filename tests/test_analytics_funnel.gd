extends SceneTree

class FakeGame:
    extends Node
    var day := 2
    var restoration := true
    var stage := "Operational"
    var business_open := true
    var total_profit := 100
    var acquisition_count := 0
    var employees := 1
    var capacity_level := 2
    var finished_goods := 0
    var last_sales := 0
    var contract_days := 0
    var debt := 0
    var strategic_decisions := 1

var failed := 0

func check(ok: bool, label: String) -> void:
    if not ok:
        failed += 1
        push_error("FAIL: " + label)

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var game := FakeGame.new()
    game.name = "Renew"
    root.add_child(game)
    current_scene = game

    var Analytics = load("res://scripts/analytics_system.gd")
    var analytics = Analytics.new()
    root.add_child(analytics)
    await process_frame

    analytics._scan_game_state(2)
    var funnel: Dictionary = analytics.get_funnel()
    for step in ["new_game", "first_restoration", "first_business", "first_profit", "first_expansion", "first_major_strategic_decision"]:
        check(bool((funnel.get(step, {}) as Dictionary).get("reached", false)), "Funnel reaches " + step)

    check(analytics.get_event_count("business_opening") == 1, "Legacy business counter remains available")
    check(analytics.get_event_count("expansion") == 1, "Legacy expansion counter remains available")

    game.queue_free()
    analytics.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)
