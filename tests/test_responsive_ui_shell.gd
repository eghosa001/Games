extends SceneTree

var failures: Array[String] = []
var failed := 0
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
        var screen_names: Array[String] = [
            "ContractPanel", "HeadquartersPanel", "TechnologyPanel", "AlliancePanel",
            "EmployeePanel", "CollectionPanel", "LiveOpsPanel", "HistoryPanel",
            "NewsPanel", "InfrastructurePanel", "DashboardPanel", "FinancePanel",
            "PortfolioPanel", "CorporationsPanel", "RenewDiplomacyUI", "CustomerSegmentsUI"
        ]

        # The first playable frame must not contain an accidental modal/window.
        for screen_name in screen_names:
            check("startup screen hidden: %s" % screen_name, not manager.is_screen_open(screen_name))

        # Every primary screen must be openable, have a real close action, and
        # release the UI back to the primary page after that action.
        for screen_name in screen_names:
            manager.show_screen(screen_name)
            await process_frame
            check("opens primary screen: %s" % screen_name, manager.is_screen_open(screen_name))
            var screen := _find_screen(manager, screen_name)
            var close_button := _find_close_button(screen)
            check("has usable close button: %s" % screen_name, close_button != null and close_button.visible and close_button.size.x > 0.0 and close_button.size.y > 0.0)
            if close_button != null:
                check("close button accepts mouse/touch: %s" % screen_name, close_button.mouse_filter != Control.MOUSE_FILTER_IGNORE)
                close_button.emit_signal("pressed")
                await process_frame
            check("closes screen: %s" % screen_name, not manager.is_screen_open(screen_name))

        # ESC must close the currently active primary screen as a second,
        # independent escape path.
        manager.show_screen("NewsPanel")
        await process_frame
        check("ESC test opens NewsPanel", manager.is_screen_open("NewsPanel"))
        var escape := InputEventKey.new()
        escape.keycode = KEY_ESCAPE
        escape.pressed = true
        Input.parse_input_event(escape)
        await process_frame
        check("ESC closes active screen", not manager.is_screen_open("NewsPanel"))

    _finish()

func _find_screen(manager: Node, screen_name: String) -> Node:
    var ui := get_root().get_node_or_null("Renew/UI")
    if ui != null:
        var node := ui.get_node_or_null(screen_name)
        if node != null:
            return node
    return manager.get_tree().root.get_node_or_null("Renew/" + screen_name)

func _find_close_button(node: Node) -> Button:
    if node == null:
        return null
    for child in node.get_children():
        var button := child as Button
        if button != null and (button.text.to_upper() == "CLOSE" or button.name.to_lower().contains("close")):
            return button
        var nested := _find_close_button(child)
        if nested != null:
            return nested
    return null

func check(label: String, condition: bool) -> void:
    checks += 1
    if condition:
        print("PASS: %s" % label)
    else:
        failures.append(label)
        failed += 1
        print("FAIL: %s" % label)

func _finish() -> void:
    print("--- RESPONSIVE UI SHELL SUMMARY ---")
    print("Checks: %d | Failures: %d" % [checks, failures.size()])
    if not failures.is_empty():
        for failure in failures: print("FAILED: %s" % failure)
    else:
        print("RESPONSIVE UI SHELL TEST: PASS")
    quit(1 if failed > 0 else 0)
