extends SceneTree

var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _init() -> void:
    call_deferred("_run")

func _find_button(node: Node, label: String, by_name := false) -> Button:
    if node == null:
        return null
    if node is Button:
        var button := node as Button
        if (by_name and button.name == label) or (not by_name and button.text.begins_with(label)):
            return button
    for child in node.get_children():
        var found := _find_button(child, label, by_name)
        if found != null:
            return found
    return null

func _wait(frames := 3) -> void:
    for _i in range(frames):
        await process_frame

func _step(overlay: Node) -> int:
    return int((overlay.tutorial_status() as Dictionary).get("step", -1))

func _run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.size = Vector2i(390, 844)

    var packed := load("res://scenes/Main.tscn") as PackedScene
    check(packed != null, "Main scene loads")
    if packed == null:
        quit(1)
        return

    var state = root.get_node_or_null("RenewGameState")
    if state != null:
        state.clear()

    var game = packed.instantiate()
    root.add_child(game)
    current_scene = game
    await _wait(5)

    var hud = game.get_node_or_null("UI/MainHUD")
    var overlay = game.get_node_or_null("UI/TutorialOverlay")
    check(hud != null, "Figma HUD is available")
    check(overlay != null, "Tutorial overlay is mounted")
    check(state != null, "Canonical GameState is available")
    var tutorial_overlay_source := FileAccess.get_file_as_string("res://scripts/tutorial_overlay.gd")
    check(tutorial_overlay_source.contains("const UPDATE_INTERVAL: float = 0.10"), "Tutorial refresh work is throttled")
    if hud == null or overlay == null or state == null:
        game.queue_free()
        await process_frame
        quit(1)
        return

    var status: Dictionary = overlay.tutorial_status()
    check(not bool(status.get("dismissed", true)), "Fresh game starts with tutorial visible")
    check(_step(overlay) == 0, "Tutorial begins at Inspect")
    check(overlay.panel.visible, "Tutorial card is visible on phone")

    overlay.hide_tutorial()
    await _wait(2)
    check(bool((overlay.tutorial_status() as Dictionary).get("dismissed", false)), "Tutorial can be dismissed")
    check(overlay.collapsed_button.visible, "Dismissed mobile tutorial exposes GUIDE chip")
    overlay.open_tutorial()
    await _wait(2)
    check(not bool((overlay.tutorial_status() as Dictionary).get("dismissed", true)), "GUIDE can reopen tutorial")

    hud.open_figma_view("property")
    await _wait(2)
    var property_cta := _find_button(hud.get("mobile_content"), "INSPECT PROPERTY")
    check(property_cta != null, "Inspect action is reachable")
    if property_cta != null:
        property_cta.pressed.emit()
    await _wait(4)
    check(_step(overlay) == 1, "Inspect advances tutorial to Acquire")

    property_cta = _find_button(hud.get("mobile_content"), "ACQUIRE PROPERTY")
    check(property_cta != null, "Acquire action is reachable")
    if property_cta != null:
        property_cta.pressed.emit()
    await _wait(4)
    check(_step(overlay) == 2, "Acquire advances tutorial to Restore")

    var restore_guard := 0
    while str(state.get_value("properties", "stage", "")) != "Operational" and restore_guard < 8:
        property_cta = _find_button(hud.get("mobile_content"), "RESTORE NEXT STAGE")
        check(property_cta != null, "Restore action remains reachable")
        if property_cta == null:
            break
        property_cta.pressed.emit()
        await _wait(4)
        restore_guard += 1
    check(str(state.get_value("properties", "stage", "")) == "Operational", "Restoration can reach Operational")
    check(_step(overlay) == 3, "Operational property advances tutorial to Open Business")

    var open_ops := _find_button(hud.get("mobile_content"), "OPEN OPERATIONS")
    check(open_ops != null, "Open Operations action is reachable")
    if open_ops != null:
        open_ops.pressed.emit()
    await _wait(3)
    check(str(hud.get("active_view")) == "operate", "Operations view opens")

    var choose := _find_button(hud.get("mobile_content"), "CHOOSE BUSINESS")
    check(choose != null, "Choose Business action is reachable")
    if choose != null:
        choose.pressed.emit()
    await _wait(2)
    var purpose := _find_button(hud.get("mobile_content"), "Purpose0", true)
    check(purpose != null, "First business purpose is reachable")
    if purpose != null:
        purpose.pressed.emit()
    await _wait(5)
    check(bool(state.get_value("businesses", "business_open", false)), "Business opens")
    check(_step(overlay) == 4, "Open Business advances tutorial to Buy Inputs")

    var buy := _find_button(hud.get("mobile_content"), "BUY INPUTS")
    check(buy != null, "Buy Inputs action is reachable")
    if buy != null:
        buy.pressed.emit()
    await _wait(5)
    check(_step(overlay) == 5, "Buying inputs advances tutorial to Produce")

    var produce := _find_button(hud.get("mobile_content"), "PRODUCE BATCH")
    check(produce != null, "Produce action is reachable")
    if produce != null:
        produce.pressed.emit()
    await _wait(5)
    check(int(state.get_value("production", "finished_goods", 0)) > 0, "Production creates finished goods")
    check(_step(overlay) == 6, "Producing advances tutorial to Sell Goods")

    var commercial := _find_button(hud.get("mobile_content"), "OpenCommercial", true)
    check(commercial != null, "Commercial Controls is reachable")
    if commercial != null:
        commercial.pressed.emit()
    await _wait(3)
    var sell := _find_button(hud.get("mobile_content"), "SELL GOODS")
    check(sell != null, "Sell Goods action is reachable")
    if sell != null:
        sell.pressed.emit()
    await _wait(6)

    status = overlay.tutorial_status()
    check(int(state.get_value("economy", "last_sales", 0)) > 0, "First sale succeeds")
    check(bool(status.get("completed", false)), "All seven tutorial steps complete")
    check(int(status.get("step", 0)) == 7, "Tutorial reaches step 7 of 7")
    check(bool(state.get_value("progression", "tutorial_completed", false)), "Tutorial completion is persisted")
    check(int(state.get_value("progression", "tutorial_step", -1)) == 7, "Tutorial step is persisted")

    var snapshot: Dictionary = state.capture()
    state.clear()
    check(int(state.get_value("progression", "tutorial_step", -1)) == 0, "New game state resets tutorial")
    check(state.restore(snapshot), "Saved state restores after tutorial completion")
    check(bool(state.get_value("progression", "tutorial_completed", false)), "Save/load preserves tutorial completion")

    print("TUTORIAL COMPLETION RESULT: %d passed, %d failed" % [passed, failed])
    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)
