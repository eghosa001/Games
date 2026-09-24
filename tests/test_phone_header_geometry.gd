extends SceneTree

var failed := 0

func check(label: String, ok: bool) -> void:
    if not ok:
        failed += 1
        push_error("FAIL: " + label)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size = Vector2i(390, 844)
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check("Main scene loads", packed != null)
    if packed == null:
        quit(1)
        return
    var game := packed.instantiate()
    root.add_child(game)
    current_scene = game
    for _frame in range(4):
        await process_frame
    var manager := root.get_node_or_null("RenewUIScreenManager")
    check("screen manager resolves", manager != null)
    if manager == null:
        quit(1)
        return

    manager.show_screen("CustomerSegmentsUI")
    await process_frame
    var market := game.get_node("UI/CustomerSegmentsUI")
    var market_title := market.get("title_label") as Label
    var market_close := market.get("close_button") as Button
    var market_status := market.get("market_status") as Label
    var market_summary := market.get("summary_label") as Label
    check("Market title clears Close", not market_title.get_global_rect().intersects(market_close.get_global_rect()))
    check("Market status starts below Close", market_status.get_global_rect().position.y >= market_close.get_global_rect().end.y)
    check("Market summary starts below status", market_summary.get_global_rect().position.y >= market_status.get_global_rect().end.y)

    manager.show_screen("EmpireIdentityPanel")
    await process_frame
    var identity := game.get_node("UI/EmpireIdentityPanel")
    var identity_title := identity.get("title_label") as Label
    var identity_close := identity.get("close_button") as Button
    var identity_summary := identity.get("summary_label") as Label
    var identity_power := identity.get("power_label") as Label
    check("Identity title clears Close", not identity_title.get_global_rect().intersects(identity_close.get_global_rect()))
    check("Identity summary starts below Close", identity_summary.get_global_rect().position.y >= identity_close.get_global_rect().end.y)
    check("Identity summary text fits one phone row", identity_summary.autowrap_mode == TextServer.AUTOWRAP_OFF and _text_fits(identity_summary))
    check("Identity power starts below summary text", identity_power.global_position.y >= identity_summary.global_position.y + _text_height(identity_summary) + 4.0)

    manager.show_screen("PortfolioPanel")
    await process_frame
    var portfolio := game.get_node("UI/PortfolioPanel")
    var portfolio_title := portfolio.get("title_label") as Label
    var portfolio_status := portfolio.get("status_label") as Label
    var portfolio_scroll := portfolio.get("scroll") as ScrollContainer
    check("Portfolio title text fits", _text_fits(portfolio_title))
    check("Portfolio restored count starts below title text", portfolio_status.global_position.y >= portfolio_title.global_position.y + _text_height(portfolio_title) + 4.0)
    check("Portfolio assets start below restored count text", portfolio_scroll.global_position.y >= portfolio_status.global_position.y + _text_height(portfolio_status) + 4.0)

    manager.hide_all_screens()
    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)


func _text_height(label: Label) -> float:
    var font := label.get_theme_font("font")
    var size := label.get_theme_font_size("font_size")
    return font.get_height(size)

func _text_fits(label: Label) -> bool:
    var font := label.get_theme_font("font")
    var size := label.get_theme_font_size("font_size")
    return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= label.size.x + 1.0
