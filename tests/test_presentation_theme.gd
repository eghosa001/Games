extends SceneTree

## Presentation QA gate: the premium command skin must be active and touch-safe.
func _init() -> void:
    var failures := 0
    var main := load("res://scenes/Main.tscn")
    if main == null:
        push_error("Unable to load Main.tscn")
        quit(1)
        return
    var scene := main.instantiate()
    root.add_child(scene)
    await process_frame
    var skin := scene.get_node_or_null("UI/MainHUD/PremiumUISkin") as Control
    if skin == null:
        push_error("PremiumUISkin node missing")
        failures += 1
    elif not skin.visible:
        push_error("PremiumUISkin must be visible in the release presentation")
        failures += 1
    if skin != null and skin.mouse_filter != Control.MOUSE_FILTER_IGNORE:
        push_error("PremiumUISkin must not block gameplay input")
        failures += 1
    var employee := scene.get_node_or_null("UI/EmployeePanel")
    if employee != null:
        var panel := employee.get("panel") as Control
        if panel != null and panel.visible:
            for child in panel.get_children():
                if child is Button and child.custom_minimum_size.y < 44.0:
                    failures += 1
                    push_error("Employee action target below 44px")
    scene.queue_free()
    print("PRESENTATION_THEME: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    quit(failures)
