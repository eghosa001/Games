extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("_run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _run() -> void:
    root.size = Vector2i(390, 844)
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check(packed != null, "Main scene loads")
    if packed == null:
        quit(1)
        return

    var game := packed.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    await process_frame

    var state := root.get_node_or_null("RenewGameState")
    var victory := root.get_node_or_null("RenewVictorySystem")
    var panel := game.get_node_or_null("UI/SaveLoadPanel")
    check(state != null, "GameState available")
    check(victory != null, "Victory system available")
    check(panel != null, "Save / Load panel available")
    if state == null or victory == null or panel == null:
        game.queue_free()
        await process_frame
        quit(1)
        return

    state.set_value("player", "day", 77)
    state.set_value("progression", "milestones", {
        "victory_monopolist": {"path": "monopolist", "day": 77}
    })
    victory.prestige = {
        "wins_total": 2,
        "paths": {"monopolist": 1, "hegemon": 1}
    }

    panel.open_screen()
    await process_frame

    check(not bool(panel.new_button.disabled), "New dynasty unlocks after stored victory")
    check(panel.status.text.contains("Monopolist"), "Dynasty preview names the banked victory path")
    check(panel.status.text.contains("+$50.0K cash"), "Dynasty preview shows permanent cash bonus")
    check(panel.status.text.contains("+5 reputation"), "Dynasty preview shows permanent reputation bonus")
    check(panel.status.text.contains("+10 research"), "Dynasty preview shows permanent research bonus")
    check(panel.status.text.contains("$75.0K cash"), "Dynasty preview shows resulting starting cash")
    check(panel.status.text.contains("30 research points"), "Dynasty preview shows resulting starting research")

    panel._request_new()
    await process_frame

    check(int(state.get_value("player", "day", -1)) == 77, "Opening reset confirmation does not mutate the current campaign")
    check(bool(panel.confirm_new), "Destructive reset requires explicit confirmation")
    check(panel.warning.visible, "Reset warning becomes visible")
    check(panel.warning.text.contains("CURRENT CAMPAIGN WILL RESET ONLY AFTER CONFIRMATION"), "Warning states exactly when reset happens")
    check(panel.warning.text.contains("$75.0K cash"), "Confirmation repeats resulting starting cash")
    check(panel.warning.text.contains("5 reputation"), "Confirmation repeats resulting starting reputation")
    check(panel.warning.text.contains("30 research points"), "Confirmation repeats resulting research")
    check(panel.confirm_button.text.contains("RESET"), "Confirmation button names destructive reset")

    panel._cancel_new()
    await process_frame
    check(int(state.get_value("player", "day", -1)) == 77, "Cancelling preserves the current campaign")
    check(not bool(panel.confirm_new), "Cancel exits reset confirmation")
    check(not panel.warning.visible, "Cancel hides destructive warning")

    game.queue_free()
    await process_frame
    print("SAVE/LOAD DYNASTY UI RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
