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

    manager.show_screen("RenewDiplomacyUI")
    await process_frame
    var diplomacy := game.get_node("UI/RenewDiplomacyUI")
    var diplomacy_panel := diplomacy.get("panel") as Panel
    var diplomacy_close := diplomacy_panel.get_node("CloseButton") as Button
    check("Diplomacy title clears Close", not (diplomacy_panel.get_node("Title") as Label).get_global_rect().intersects(diplomacy_close.get_global_rect()))
    check("Diplomacy subtitle clears Close", not (diplomacy_panel.get_node("Subtitle") as Label).get_global_rect().intersects(diplomacy_close.get_global_rect()))

    manager.show_screen("TechnologyPanel")
    await process_frame
    var technology := game.get_node("UI/TechnologyPanel")
    check("Technology title clears Close", not (technology.get("title_label") as Label).get_global_rect().intersects((technology.get("close_button") as Button).get_global_rect()))
    check("Technology hides secondary header status on phone", not (technology.get("status_label") as Label).visible)

    manager.show_screen("RegionsPanel")
    await process_frame
    var regions := game.get_node("UI/RegionsPanel")
    check("Regions summary clears Close", not (regions.get("summary_label") as Label).get_global_rect().intersects((regions.get("close_button") as Button).get_global_rect()))

    manager.show_screen("CollectionPanel")
    await process_frame
    var collection := game.get_node("UI/CollectionPanel")
    var filter_scroll := collection.get("filter_scroll") as ScrollContainer
    var filters := filter_scroll.get_node("Filters") as HBoxContainer
    var first_three_width := 0.0
    for i in range(mini(3, filters.get_child_count())):
        first_three_width += (filters.get_child(i) as Button).custom_minimum_size.x
    first_three_width += 12.0
    check("Collection first three filters fit phone strip", first_three_width <= filter_scroll.size.x + 1.0)

    manager.hide_all_screens()
    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)
