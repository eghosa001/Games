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

    manager.show_screen("AlliancePanel")
    await process_frame
    var alliance := game.get_node("UI/AlliancePanel")
    var alliance_title := alliance.get("title") as Label
    var alliance_close := alliance.get("close_button") as Button
    var alliance_subtitle := (alliance.get("panel") as Panel).get_node("Subtitle") as Label
    check("Alliance title clears Close", not alliance_title.get_global_rect().intersects(alliance_close.get_global_rect()))
    check("Alliance subtitle clears Close", not alliance_subtitle.get_global_rect().intersects(alliance_close.get_global_rect()))
    check("Alliance subtitle text fits", _text_fits(alliance_subtitle))

    manager.show_screen("RenewDiplomacyUI")
    await process_frame
    var diplomacy := game.get_node("UI/RenewDiplomacyUI")
    var diplomacy_panel := diplomacy.get("panel") as Panel
    var diplomacy_close := diplomacy_panel.find_child("UniversalCloseButton", true, false) as Button
    check("Diplomacy close resolves after manager normalization", diplomacy_close != null)
    if diplomacy_close != null:
        check("Diplomacy title clears Close", not (diplomacy_panel.get_node("Title") as Label).get_global_rect().intersects(diplomacy_close.get_global_rect()))
        var diplomacy_subtitle := diplomacy_panel.get_node("Subtitle") as Label
        check("Diplomacy subtitle clears Close", not diplomacy_subtitle.get_global_rect().intersects(diplomacy_close.get_global_rect()))
        check("Diplomacy subtitle text fits", _text_fits(diplomacy_subtitle))
    for name in ["AcceptIncoming", "SendGift", "CancelTreaty", "RefreshTreatyLedger"]:
        var action := diplomacy_panel.get_node(name) as Button
        check("Diplomacy action text fits: %s" % name, _button_text_fits(action))

    manager.show_screen("TechnologyPanel")
    await process_frame
    var technology := game.get_node("UI/TechnologyPanel")
    check("Technology title clears Close", not (technology.get("title_label") as Label).get_global_rect().intersects((technology.get("close_button") as Button).get_global_rect()))
    check("Technology hides secondary header status on phone", not (technology.get("status_label") as Label).visible)

    manager.show_screen("RegionsPanel")
    await process_frame
    var regions := game.get_node("UI/RegionsPanel")
    var regions_summary := regions.get("summary_label") as Label
    check("Regions summary clears Close", not regions_summary.get_global_rect().intersects((regions.get("close_button") as Button).get_global_rect()))
    check("Regions summary wraps instead of clipping", regions_summary.autowrap_mode != TextServer.AUTOWRAP_OFF and not regions_summary.clip_text)

    manager.show_screen("CollectionPanel")
    await process_frame
    var collection := game.get_node("UI/CollectionPanel")
    var filter_scroll := collection.get("filter_scroll") as ScrollContainer
    var filters := filter_scroll.get_node("Filters") as HBoxContainer
    for child in filters.get_children():
        if child is Button:
            check("Collection filter text fits: %s" % child.text, _button_text_fits(child as Button))

    manager.hide_all_screens()
    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)


func _text_fits(label: Label) -> bool:
    var font := label.get_theme_font("font")
    var size := label.get_theme_font_size("font_size")
    return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= label.size.x + 1.0

func _button_text_fits(button: Button) -> bool:
    var font := button.get_theme_font("font")
    var size := button.get_theme_font_size("font_size")
    return font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= button.size.x - 20.0
