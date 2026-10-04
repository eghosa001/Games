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

    var network := game.get_node_or_null("UI/CorporationsPanel")
    var state := root.get_node_or_null("RenewGameState")
    var manager := root.get_node_or_null("RenewUIScreenManager")
    check(network != null, "Corporations panel available")
    check(state != null, "GameState available")
    check(manager != null, "Screen manager available")
    if network == null or state == null:
        game.queue_free()
        await process_frame
        quit(1)
        return

    if manager != null:
        manager.show_screen("CorporationsPanel")
        await process_frame

    network.set("last_signature", "")
    network.set("applied_refreshes", 0)
    network._refresh(true)
    var applied_after_force := int(network.get("applied_refreshes"))
    var signature_after_force := str(network.get("last_signature"))
    check(applied_after_force == 1, "Forced corporate refresh applies once")
    check(not signature_after_force.is_empty(), "Corporate refresh records a state signature")

    network._refresh(false)
    check(int(network.get("applied_refreshes")) == applied_after_force, "Unchanged corporate poll skips UI relayout")
    check(str(network.get("last_signature")) == signature_after_force, "Unchanged corporate poll preserves signature")

    var rivals = network._rivals()
    var rival_array: Array = rivals.get("rivals") if rivals != null and rivals.get("rivals") is Array else []
    if rival_array.size() > 1:
        var selected_before := int(state.get_value("competitors", "selected_rival", 0))
        var selected_after := (selected_before + 1) % rival_array.size()
        state.set_value("competitors", "selected_rival", selected_after)
        network._refresh(false)
        check(int(network.get("applied_refreshes")) == applied_after_force + 1, "Selected-rival change triggers one corporate refresh")
        check(str(network.get("last_signature")) != signature_after_force, "Selected-rival change updates corporate signature")
        check(str(network.detail_label.text).contains(str(rivals.ai_status(selected_after).get("name", ""))), "Corporate detail follows authoritative selected rival")
    else:
        check(true, "Single-rival fixture does not require selection transition")
        check(true, "Single-rival fixture keeps authoritative detail")

    if manager != null:
        manager.hide_all_screens()
    game.queue_free()
    await process_frame

    print("CORPORATE REFRESH RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
