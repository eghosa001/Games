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

    var portfolio := game.get_node_or_null("UI/PortfolioPanel")
    var state := root.get_node_or_null("RenewGameState")
    var manager := root.get_node_or_null("RenewUIScreenManager")
    check(portfolio != null, "Portfolio panel available")
    check(state != null, "GameState available")
    check(manager != null, "Screen manager available")
    if portfolio == null or state == null:
        game.queue_free()
        await process_frame
        quit(1)
        return

    if manager != null:
        manager.show_screen("PortfolioPanel")
        await process_frame

    portfolio.set("last_signature", "")
    portfolio.set("applied_refreshes", 0)
    portfolio._refresh(true)
    var applied_after_force := int(portfolio.get("applied_refreshes"))
    var signature_after_force := str(portfolio.get("last_signature"))
    check(applied_after_force == 1, "Forced portfolio refresh applies once")
    check(not signature_after_force.is_empty(), "Portfolio refresh records a state signature")

    portfolio._refresh(false)
    check(int(portfolio.get("applied_refreshes")) == applied_after_force, "Unchanged portfolio poll skips list rebuild")
    check(str(portfolio.get("last_signature")) == signature_after_force, "Unchanged portfolio poll preserves signature")

    var original_catalog: Array = (state.get_value("properties", "catalog", []) as Array).duplicate(true)
    var original_selected := int(state.get_value("properties", "selected_property", 0))
    var original_day := int(state.get_value("player", "day", 1))
    check(not original_catalog.is_empty(), "Portfolio fixture contains property catalog")

    var applied_after_selection := applied_after_force
    var signature_after_selection := signature_after_force
    if original_catalog.size() > 1:
        var selected_after := (original_selected + 1) % original_catalog.size()
        state.set_value("properties", "selected_property", selected_after)
        portfolio._refresh(false)
        applied_after_selection = int(portfolio.get("applied_refreshes"))
        signature_after_selection = str(portfolio.get("last_signature"))
        check(applied_after_selection == applied_after_force + 1, "Selected property change triggers one portfolio refresh")
        check(signature_after_selection != signature_after_force, "Selected property change updates portfolio signature")
    else:
        var single_catalog := original_catalog.duplicate(true)
        var single_entry: Dictionary = single_catalog[0]
        single_entry["condition"] = int(single_entry.get("condition", 0)) + 1
        single_catalog[0] = single_entry
        state.set_value("properties", "catalog", single_catalog)
        portfolio._refresh(false)
        applied_after_selection = int(portfolio.get("applied_refreshes"))
        signature_after_selection = str(portfolio.get("last_signature"))
        check(applied_after_selection == applied_after_force + 1, "Single-property content change triggers one portfolio refresh")
        check(signature_after_selection != signature_after_force, "Single-property content change updates portfolio signature")

    var changed_catalog: Array = (state.get_value("properties", "catalog", []) as Array).duplicate(true)
    if not changed_catalog.is_empty():
        var selected_now := clampi(int(state.get_value("properties", "selected_property", 0)), 0, changed_catalog.size() - 1)
        var entry: Dictionary = changed_catalog[selected_now]
        entry["condition"] = int(entry.get("condition", 0)) + 3
        changed_catalog[selected_now] = entry
        state.set_value("properties", "catalog", changed_catalog)
        portfolio._refresh(false)
        check(int(portfolio.get("applied_refreshes")) == applied_after_selection + 1, "Property content change triggers one portfolio refresh")
        check(str(portfolio.get("last_signature")) != signature_after_selection, "Property content change updates portfolio signature")

    var applied_before_day := int(portfolio.get("applied_refreshes"))
    var signature_before_day := str(portfolio.get("last_signature"))
    state.set_value("player", "day", original_day + 1)
    portfolio._refresh(false)
    check(int(portfolio.get("applied_refreshes")) == applied_before_day + 1, "Day change refreshes lease-sensitive portfolio state")
    check(str(portfolio.get("last_signature")) != signature_before_day, "Day change updates portfolio signature")

    state.set_value("properties", "catalog", original_catalog)
    state.set_value("properties", "selected_property", original_selected)
    state.set_value("player", "day", original_day)

    if manager != null:
        manager.hide_all_screens()
    game.queue_free()
    await process_frame

    print("PORTFOLIO REFRESH RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
