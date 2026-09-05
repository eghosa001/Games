extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check("Main scene loads", packed != null)
    if packed == null:
        _finish(); return
    var scene := packed.instantiate()
    root.add_child(scene)
    current_scene = scene
    await process_frame
    await process_frame
    var hud := scene.get_node_or_null("UI/MainHUD")
    check("MainHUD resolves", hud != null)
    if hud == null:
        _finish(); return
    var tabs := hud.get("tabs") as HBoxContainer
    var actions := hud.get("actions") as GridContainer
    check("four primary tabs exist", tabs != null and tabs.get_child_count() == 4)
    check("action grid exists", actions != null)
    if tabs != null:
        for child in tabs.get_children():
            var button := child as Button
            check("tab touch target >= 44", button != null and button.size.x >= 44.0 and button.size.y >= 44.0)
    var manager := get_root().get_node_or_null("RenewUIScreenManager")
    check("screen manager resolves", manager != null)
    if manager != null:
        manager.show_screen("NewsPanel")
        await process_frame
        check("screen manager exposes active screen", manager.has_method("get_active_screen_name") and manager.get_active_screen_name() == "NewsPanel")
        manager.hide_all_screens()
    _finish()

func check(label: String, condition: bool) -> void:
    checks += 1
    if condition:
        print("PASS: %s" % label)
    else:
        failures.append(label)
        print("FAIL: %s" % label)

func _finish() -> void:
    print("--- RESPONSIVE UI SHELL SUMMARY ---")
    print("Checks: %d | Failures: %d" % [checks, failures.size()])
    if not failures.is_empty():
        for failure in failures: print("FAILED: %s" % failure)
        quit(1)
    print("RESPONSIVE UI SHELL TEST: PASS")
    quit(0)
