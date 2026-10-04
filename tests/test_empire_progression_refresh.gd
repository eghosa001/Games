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

    var panel := game.get_node_or_null("UI/EmpireProgressionPanel")
    var state := root.get_node_or_null("RenewGameState")
    var manager := root.get_node_or_null("RenewUIScreenManager")
    check(panel != null, "Empire Progression panel available")
    check(state != null, "GameState available")
    check(manager != null, "Screen manager available")
    if panel == null or state == null:
        game.queue_free()
        await process_frame
        quit(1)
        return

    if manager != null:
        manager.show_screen("EmpireProgressionPanel")
        await process_frame

    panel.set("last_signature", "")
    panel.set("applied_refreshes", 0)
    panel._refresh(true)
    var applied_after_force := int(panel.get("applied_refreshes"))
    var signature_after_force := str(panel.get("last_signature"))
    check(applied_after_force == 1, "Forced progression refresh applies once")
    check(not signature_after_force.is_empty(), "Progression refresh records a state signature")

    panel._refresh(false)
    check(int(panel.get("applied_refreshes")) == applied_after_force, "Unchanged progression poll skips card rebuild")
    check(str(panel.get("last_signature")) == signature_after_force, "Unchanged progression poll preserves signature")

    var original_level := int(state.get_value("progression", "level", 1))
    var original_xp := int(state.get_value("progression", "xp", 0))
    var next_level := mini(10, maxi(2, original_level + 1))
    state.set_value("progression", "level", next_level)
    state.set_value("progression", "xp", original_xp + 137)
    panel._refresh(false)
    var applied_after_progress := int(panel.get("applied_refreshes"))
    var signature_after_progress := str(panel.get("last_signature"))
    check(applied_after_progress == applied_after_force + 1, "Level or XP change triggers one progression refresh")
    check(signature_after_progress != signature_after_force, "Level or XP change updates progression signature")
    check(str(panel.status_label.text).contains("LEVEL %d" % next_level), "Visible progression status follows authoritative company level")

    var original_message := str(game.get("message"))
    game.set("message", "Focused executive notice refresh")
    panel._refresh(false)
    check(int(panel.get("applied_refreshes")) == applied_after_progress + 1, "Executive notice change triggers one progression refresh")
    check(str(panel.get("last_signature")) != signature_after_progress, "Executive notice change updates progression signature")

    state.set_value("progression", "level", original_level)
    state.set_value("progression", "xp", original_xp)
    game.set("message", original_message)

    if manager != null:
        manager.hide_all_screens()
    game.queue_free()
    await process_frame

    print("EMPIRE PROGRESSION REFRESH RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
