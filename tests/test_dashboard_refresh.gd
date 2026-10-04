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

    var dashboard := game.get_node_or_null("UI/DashboardPanel")
    var finance := root.get_node_or_null("RenewFinanceSystem")
    var manager := root.get_node_or_null("RenewUIScreenManager")
    check(dashboard != null, "Dashboard panel available")
    check(finance != null, "Finance system available")
    check(manager != null, "Screen manager available")
    if dashboard == null or finance == null:
        game.queue_free()
        await process_frame
        quit(1)
        return

    if manager != null:
        manager.show_screen("DashboardPanel")
        await process_frame

    dashboard.set("last_signature", "")
    dashboard.set("applied_refreshes", 0)
    dashboard._refresh(true)
    var applied_after_force := int(dashboard.get("applied_refreshes"))
    var signature_after_force := str(dashboard.get("last_signature"))
    check(applied_after_force == 1, "Forced dashboard refresh applies once")
    check(not signature_after_force.is_empty(), "Dashboard records a state signature")

    dashboard._refresh(false)
    check(int(dashboard.get("applied_refreshes")) == applied_after_force, "Unchanged dashboard poll skips redraw work")
    check(str(dashboard.get("last_signature")) == signature_after_force, "Unchanged dashboard poll preserves signature")

    var original_cash := int(finance.get("cash"))
    finance.set("cash", original_cash + 137)
    dashboard._refresh(false)
    check(int(dashboard.get("applied_refreshes")) == applied_after_force + 1, "Finance change triggers one dashboard refresh")
    check(str(dashboard.get("last_signature")) != signature_after_force, "Finance change updates dashboard signature")
    check(str(dashboard.overview_label.text).contains("$"), "Dashboard still renders financial overview")
    finance.set("cash", original_cash)

    if manager != null:
        manager.hide_all_screens()
    game.queue_free()
    await process_frame

    print("DASHBOARD REFRESH RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
