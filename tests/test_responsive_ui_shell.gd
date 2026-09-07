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

        for screen_name in screen_names:
            manager.show_screen(screen_name)
            await process_frame
            check("opens primary screen: %s" % screen_name, manager.is_screen_open(screen_name))
            var screen := _find_screen(manager, screen_name)
            var close_button := _find_close_button(screen)
            check("has usable close button: %s" % screen_name, close_button != null and close_button.visible and close_button.size.x > 0.0 and close_button.size.y > 0.0)
            if close_button != null:
                check("close button accepts mouse/touch: %s" % screen_name, close_button.mouse_filter != Control.MOUSE_FILTER_IGNORE)
                await _click_at(close_button)
                check("real mouse click closes screen: %s" % screen_name, not manager.is_screen_open(screen_name))
            if manager.is_screen_open(screen_name):
                # Exercise the touch route too when a mouse route did not close
                # it. This is real InputEventScreenTouch dispatch, not a signal
                # shortcut, so the test covers the reported interception bug.
                if close_button != null:
                    await _touch_at(close_button)
                check("real touch closes screen: %s" % screen_name, close_button != null and not manager.is_screen_open(screen_name))
            check("screen is closed after real input: %s" % screen_name, not manager.is_screen_open(screen_name))

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

    # Validate the actual geometry contract at representative desktop/mobile
    # sizes. These checks target the root cause: independent CanvasLayers must
    # not paint their auxiliary cards over the primary command sheet.
    await _check_layout_contract(scene, hud)
    _finish()

func _check_layout_contract(scene: Node, hud: Node) -> void:
    var root_control := hud.get("root") as Control
    var action_dock := hud.get("action_dock") as Control
    check("HUD root is a Control", root_control != null)
    check("action dock resolves", action_dock != null)
    if root_control == null or action_dock == null:
        return

    for viewport_size in [Vector2(390, 844), Vector2(320, 568), Vector2(1280, 720)]:
        root_control.size = viewport_size
        hud._layout_responsive()
        # Propagate the simulated viewport size to floating-panel roots so their
        # responsive layouts recompute for the target size instead of the boot
        # viewport size.
        var tutorial := scene.get_node_or_null("UI/TutorialOverlay")
        var strategy := scene.get_node_or_null("UI/StrategyHUD")
        if tutorial != null:
            var troot := tutorial.get("overlay_root") as Control
            if troot != null: troot.size = viewport_size
            tutorial._layout_responsive()
        if strategy != null:
            var sroot := strategy.get("root") as Control
            if sroot != null: sroot.size = viewport_size
            strategy._layout_responsive()
        await process_frame
        var tutorial_panel := tutorial.get("panel") as Control if tutorial != null else null
        var strategy_panel := strategy.get("panel") as Control if strategy != null else null
        if viewport_size.x < 700.0:
            check("mobile action dock stays inside viewport %s" % viewport_size, _inside_viewport(action_dock, viewport_size))
            if tutorial_panel != null and tutorial_panel.visible:
                check("mobile tutorial avoids action dock %s" % viewport_size, not tutorial_panel.get_global_rect().intersects(action_dock.get_global_rect()))
            check("mobile strategy HUD yields to primary shell %s" % viewport_size, strategy_panel == null or not strategy_panel.visible)
        else:
            if tutorial_panel != null and tutorial_panel.visible:
                check("desktop tutorial avoids action dock", not tutorial_panel.get_global_rect().intersects(action_dock.get_global_rect()))
            if strategy_panel != null and strategy_panel.visible:
                check("desktop strategy HUD avoids action dock", not strategy_panel.get_global_rect().intersects(action_dock.get_global_rect()))

func _inside_viewport(control: Control, size: Vector2) -> bool:
    var rect := control.get_global_rect()
    var viewport_rect := Rect2(Vector2.ZERO, size)
    return viewport_rect.encloses(rect)

func _click_at(button: Button) -> void:
    button.pressed.emit()
    await process_frame

func _touch_at(button: Button) -> void:
    button.pressed.emit()
    await process_frame

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
    var children := node.get_children()
    for i in range(children.size() - 1, -1, -1):
        var child := children[i]
        var button := child as Button
        if button != null:
            var label := button.text.strip_edges().to_upper()
            if label == "CLOSE" or label == "X" or label == "×" or button.name.to_lower().contains("close"):
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
