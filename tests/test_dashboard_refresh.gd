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
    dashboard._refresh(true)

    var hud := game.get_node_or_null("UI/MainHUD")
    var state := root.get_node_or_null("RenewGameState")
    check(hud != null, "Command HUD available for shared objective routing")
    check(state != null, "GameState available for navigation-only assertion")
    if hud != null and state != null:
        var goal: Dictionary = dashboard._next_goal(state)
        var expected_title := str(hud.call("_objective_title"))
        var expected_detail := str(hud.call("_objective_detail"))
        var expected_target := str(hud.call("_objective_view"))
        check(str(goal.get("text", "")) == expected_title, "Dashboard Next Move mirrors Home objective title")
        check(str(goal.get("detail", "")) == expected_detail, "Dashboard Next Move mirrors Home objective detail")
        check(str(goal.get("target", "")) == expected_target, "Dashboard Next Move mirrors Home objective destination")
        check(str(dashboard.objective_label.text).contains(expected_detail), "Dashboard visibly explains why the next move matters")

        var day_before := int(state.get_value("player", "day", 1))
        var cash_before := int(finance.get("cash"))
        var owned_before := bool(state.get_value("properties", "owned", false))
        var stage_before := str(state.get_value("properties", "stage", ""))
        dashboard._primary()
        await process_frame
        await process_frame
        check(manager != null and str(manager.get_active_screen_name()).is_empty(), "Dashboard Next Move exits deep-screen focus")
        check(bool(hud.visible), "Dashboard Next Move restores command HUD")
        check(str(hud.get("active_view")) == expected_target, "Dashboard Next Move navigates to Home's authoritative destination")
        check(int(state.get_value("player", "day", 1)) == day_before, "Dashboard Next Move does not advance time")
        check(int(finance.get("cash")) == cash_before, "Dashboard Next Move does not spend or create cash")
        check(bool(state.get_value("properties", "owned", false)) == owned_before, "Dashboard Next Move does not acquire property")
        check(str(state.get_value("properties", "stage", "")) == stage_before, "Dashboard Next Move does not mutate restoration state")

    if manager != null:
        manager.hide_all_screens()
    game.queue_free()
    await process_frame

    print("DASHBOARD REFRESH RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
