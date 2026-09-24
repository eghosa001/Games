extends SceneTree

# Lightweight contract test for the player-facing scene graph.
var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
    else:
        failed += 1
        push_error("FAIL: " + label)

func run() -> void:
    var scene := load("res://scenes/Main.tscn")
    check(scene != null, "Main scene resource exists")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame

    for node_name in ["World/WorldView", "UI/StrategyHUD", "UI/TutorialOverlay", "UI/MainHUD"]:
        check(game.get_node_or_null(node_name) != null, "Player-facing controller exists: " + node_name)

    check(game.get_node_or_null("World/WorldView") == null or game.get_node("World/WorldView").is_inside_tree(), "World view enters scene tree")
    check(game.get_node_or_null("UI/StrategyHUD") == null or game.get_node("UI/StrategyHUD").is_inside_tree(), "Strategy HUD enters scene tree")
    check(game.get_node_or_null("UI/MainHUD") == null or game.get_node("UI/MainHUD").is_inside_tree(), "Mobile UI enters scene tree")
    var infrastructure: Node = game.get_node_or_null("UI/InfrastructurePanel")
    check(infrastructure is CanvasLayer, "Infrastructure uses focused CanvasLayer")
    if infrastructure is CanvasLayer:
        check((infrastructure as CanvasLayer).layer > 50, "Infrastructure renders above focused-screen backdrop")
        var manager := root.get_node_or_null("RenewUIScreenManager")
        if manager != null:
            manager.show_screen("InfrastructurePanel")
            await process_frame
            var title := infrastructure.get("title_label") as Label
            var close := infrastructure.get("close_button") as Button
            var status := infrastructure.get("status_label") as Label
            var summary := infrastructure.get("summary_label") as Label
            var metrics := infrastructure.get("metrics_label") as Label
            var type_button := infrastructure.get("type_button") as Button
            check(not title.get_global_rect().intersects(close.get_global_rect()), "Infrastructure phone title clears Close")
            check(not status.visible, "Infrastructure phone hides secondary status header")
            check(summary.get_global_rect().end.y <= metrics.get_global_rect().position.y + 1.0, "Infrastructure summary clears metrics")
            check(metrics.get_global_rect().end.y <= type_button.get_global_rect().position.y + 8.0, "Infrastructure metrics clear actions")
            manager.hide_all_screens()

    print("UI SCENE CONTRACT RESULT: %d passed, %d failed" % [passed, failed])
    game.queue_free()
    quit(1 if failed > 0 else 0)
