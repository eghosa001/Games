extends SceneTree

var failed := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check("Main scene loads", packed != null)
    if packed == null:
        quit(1)
        return

    var game := packed.instantiate()
    root.add_child(game)
    current_scene = game
    for _frame in range(4):
        await process_frame

    var hud := game.get_node_or_null("UI/MainHUD")
    check("Main HUD exists", hud != null)
    var property_visual := game.get_node_or_null("World/PropertyVisual")
    check("PropertyVisual exists", property_visual != null)
    check("3D mode suppresses duplicate restoration overlay", property_visual != null and property_visual.has_method("should_draw_site_overlay") and not bool(property_visual.call("should_draw_site_overlay")))
    if hud == null:
        game.queue_free()
        await process_frame
        quit(1)
        return

    root.size = Vector2i(390, 844)
    await process_frame
    hud._layout_responsive()
    await process_frame
    var actions := hud.get("action_grid") as GridContainer
    check("mobile action grid exists", actions != null)
    if actions != null:
        for child in actions.get_children():
            if child is Button and child.visible:
                var button := child as Button
                check("mobile action wraps: %s" % button.text.split("\n")[0], button.autowrap_mode != TextServer.AUTOWRAP_OFF)
                check("mobile action does not ellipsize: %s" % button.text.split("\n")[0], button.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING)
                check("mobile action has premium subtitle height: %s" % button.text.split("\n")[0], button.custom_minimum_size.y >= 72.0)

    root.size = Vector2i(320, 568)
    await process_frame
    hud._layout_responsive()
    await process_frame
    if actions != null:
        for child in actions.get_children():
            if child is Button and child.visible:
                var button := child as Button
                check("short phone uses primary-only action copy: %s" % button.text.split("\n")[0], not button.text.contains("\n"))
                check("short phone keeps touch height: %s" % button.text, button.custom_minimum_size.y >= 52.0)
                check("short phone avoids ellipsis: %s" % button.text, button.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING)

    root.size = Vector2i(360, 640)
    await process_frame
    hud._layout_responsive()
    await process_frame
    var stat_grid := hud.get("stat_grid") as GridContainer
    var action_dock := hud.get("action_dock") as Control
    check("compact 360x640 hides summary metrics", stat_grid != null and not stat_grid.visible)
    check("compact 360x640 keeps action dock inside viewport", action_dock != null and action_dock.get_global_rect().end.y <= 640.0)
    if actions != null:
        for child in actions.get_children():
            if child is Button and child.visible:
                check("compact 360x640 uses primary-only action copy: %s" % child.text.split("\n")[0], not child.text.contains("\n"))

    root.size = Vector2i(390, 844)
    await process_frame
    hud._layout_responsive()
    await process_frame
    if actions != null:
        for child in actions.get_children():
            if child is Button and child.visible and str(button_meta(child, "renew_subtitle")) != "":
                check("larger phone restores subtitle: %s" % child.text.split("\n")[0], child.text.contains("\n"))

    root.size = Vector2i(1280, 720)
    await process_frame
    hud._layout_responsive()
    await process_frame
    var status_label := hud.get("status_label") as Label
    check("3D desktop hides duplicate persistent status line", status_label != null and not status_label.visible)
    var tutorial := game.get_node_or_null("UI/TutorialOverlay")
    var collapsed := tutorial.get("collapsed_button") as Button if tutorial != null else null
    var primary_nav := hud.get("bottom_nav") as Control
    check("desktop tutorial launcher avoids primary navigation", collapsed != null and primary_nav != null and not collapsed.get_global_rect().intersects(primary_nav.get_global_rect()))

    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)

func button_meta(button: Button, key: String):
    return button.get_meta(key, "")

func check(label: String, condition: bool) -> void:
    if condition:
        print("PASS: %s" % label)
    else:
        failed += 1
        push_error("FAIL: %s" % label)
