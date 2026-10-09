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

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size = Vector2i(390, 844)
    var state = root.get_node_or_null("RenewGameState")
    if state != null and state.has_method("clear"):
        state.clear()

    var packed := load("res://scenes/Main.tscn") as PackedScene
    var game := packed.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame

    var hud = game.get_node("UI/MainHUD")
    var nav := hud.get("bottom_nav") as Control
    check(nav != null, "bottom navigation exists")
    check(nav.position == Vector2(12, 758), "bottom navigation matches phone position")
    check(nav.size == Vector2(366, 70), "bottom navigation matches phone size")
    var scroll := hud.get("mobile_scroll") as ScrollContainer
    var mobile_content := hud.get("mobile_content") as Control
    check(scroll != null and scroll.scroll_deadzone <= 2, "touch scrolling uses a low deadzone")
    check(scroll != null and mobile_content != null and is_equal_approx(scroll.size.x, mobile_content.size.x), "scroll content keeps full phone width")

    var buttons: Array = hud.get("mode_buttons")
    var expected := ["HOME", "BUSINESS", "PROPERTY", "FINANCE", "MORE"]
    check(buttons.size() == 5, "five navigation items")
    for i in range(5):
        var button := buttons[i] as Button
        var label := button.get_node("NavLabel") as Label
        check(label.text == expected[i], "nav label " + expected[i])
        check(button.size.y >= 48.0, "48px touch target " + expected[i])
        if not button.disabled:
            check(button.focus_mode == Control.FOCUS_ALL, "keyboard focus " + expected[i])
        else:
            check(not button.tooltip_text.is_empty(), "locked navigation explains unlock " + expected[i])
            check(button.has_theme_stylebox_override("disabled"), "locked navigation has authored disabled style " + expected[i])
            check(button.get_node_or_null("UnlockLevel") != null, "locked navigation shows unlock level " + expected[i])

    check(not (buttons[0] as Button).disabled and not (buttons[1] as Button).disabled and not (buttons[2] as Button).disabled and not (buttons[4] as Button).disabled, "home, business, property and more are available from Level 1")
    check(not (buttons[3] as Button).disabled, "Finance is available from company Level 1")

    var progression = game.get_node("Systems/StrategicProgression")
    state.set_value("progression", "xp", 100)
    state.set_value("progression", "level", 2)
    state.set_value("progression", "unlocks", [])
    progression._backfill_semantic_unlocks()
    hud._rebuild_current()
    await process_frame

    buttons = hud.get("mode_buttons")
    check(not (buttons[3] as Button).disabled, "Level 2 unlocks Finance navigation")
    (buttons[2] as Button).pressed.emit()
    await process_frame
    check(int(hud.get("active_tab")) == 2 and str(hud.get("active_view")) == "property", "Property navigation opens the building restoration screen")
    (buttons[3] as Button).pressed.emit()
    await process_frame
    check(int(hud.get("active_tab")) == 3 and str(hud.get("active_view")) == "finance", "Finance navigation opens the ledger")

    hud.open_figma_view("operate")
    await process_frame
    var business_content := hud.get("mobile_content") as Control
    for action_name in ["BusinessOverview", "BusinessTeam", "BusinessContracts", "BusinessSupply"]:
        check(business_content.find_child(action_name, true, false) is Button, "Business hub exposes " + action_name)

    hud.open_figma_view("more")
    await process_frame
    var more_content := hud.get("mobile_content") as Control
    check(more_content.find_children("MoreSection*", "Panel", false, false).size() == 4, "More uses four grouped command sections")
    check(more_content.size.y > (hud.get("mobile_scroll") as ScrollContainer).size.y, "More has a real vertical scroll range")
    var how_to_play := more_content.find_child("Openguide", true, false) as Button
    check(how_to_play != null, "More exposes permanent How to Play guidance")
    if how_to_play != null:
        how_to_play.pressed.emit()
        await process_frame
        check(str(hud.get("active_view")) == "guide", "How to Play opens the Restore → Operate → Grow guide")

    game.queue_free()
    await process_frame
    print("BOTTOM NAV: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
# Focused validation: RESTORA mobile overlap, touch scroll and navigation hierarchy.
# Focused rerun: typed mobile UX layout fix.
