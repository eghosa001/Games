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
    for _frame in range(3):
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
    for _frame in range(3):
        await process_frame
    var identity := game.get_node("UI/EmpireIdentityPanel")
    var identity_title := identity.get("title_label") as Label
    var identity_close := identity.get("close_button") as Button
    var identity_summary := identity.get("summary_label") as Label
    var identity_power := identity.get("power_label") as Label
    check("Identity title clears Close", not identity_title.get_global_rect().intersects(identity_close.get_global_rect()))
    check("Identity summary starts below Close", identity_summary.get_global_rect().position.y >= identity_close.get_global_rect().end.y)
    check("Identity power starts below visible summary text", identity_power.get_global_rect().position.y >= _visible_text_bottom(identity_summary))

    manager.show_screen("PortfolioPanel")
    for _frame in range(3):
        await process_frame
    var portfolio := game.get_node("UI/PortfolioPanel")
    var portfolio_title := portfolio.get("title_label") as Label
    var portfolio_status := portfolio.get("status_label") as Label
    var portfolio_scroll := portfolio.get("scroll") as ScrollContainer
    check("Portfolio title clears visible restored count", portfolio_status.get_global_rect().position.y >= _visible_text_bottom(portfolio_title))
    check("Portfolio assets start below visible restored count", portfolio_scroll.get_global_rect().position.y >= _visible_text_bottom(portfolio_status))

    manager.hide_all_screens()
    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)


func _visible_text_bottom(label: Label) -> float:
    var font := label.get_theme_font("font")
    var font_size := label.get_theme_font_size("font_size")
    var height := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).y
    return label.get_global_rect().position.y + height
