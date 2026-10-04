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

    var manager := root.get_node_or_null("RenewUIScreenManager")
    var legacy := root.get_node_or_null("RenewCorporateLegacy")
    var collection_system := root.get_node_or_null("RenewCollectionSystem")
    var history := game.get_node_or_null("UI/HistoryPanel")
    var collection := game.get_node_or_null("UI/CollectionPanel")

    check(manager != null, "Screen manager available")
    check(legacy != null, "Corporate legacy system available")
    check(collection_system != null, "Collection system available")
    check(history != null, "History panel available")
    check(collection != null, "Collection panel available")
    if manager == null or legacy == null or collection_system == null or history == null or collection == null:
        game.queue_free()
        await process_frame
        quit(1)
        return

    manager.show_screen("HistoryPanel")
    await process_frame
    var history_refreshes := int(history.get("applied_refreshes"))
    var history_total_before := int(legacy.summary().get("total", 0))
    var history_sig := "focused_history_refresh_%d" % history_total_before
    legacy.record("awards", "Focused history refresh A", {"source":"test"}, int(game.get("day")), history_sig + "_a")
    legacy.record("awards", "Focused history refresh B", {"source":"test"}, int(game.get("day")), history_sig + "_b")
    await process_frame
    await process_frame
    var history_total_after := int(legacy.summary().get("total", 0))
    check(history_total_after == history_total_before + 2, "Two legacy mutations are recorded")
    check(int(history.get("applied_refreshes")) == history_refreshes + 1, "Visible History coalesces burst mutations into one refresh")
    var summary_label := history.get("summary_label") as Label
    check(summary_label != null and summary_label.text.contains("%d preserved artifacts" % history_total_after), "History summary reflects newly recorded artifacts")

    manager.hide_all_screens()
    await process_frame
    var hidden_history_refreshes := int(history.get("applied_refreshes"))
    legacy.record("awards", "Focused hidden history refresh", {"source":"test"}, int(game.get("day")), history_sig + "_hidden")
    await process_frame
    await process_frame
    check(int(history.get("applied_refreshes")) == hidden_history_refreshes, "Hidden History does not rebuild in background")

    manager.show_screen("CollectionPanel")
    await process_frame
    var collection_refreshes := int(collection.get("applied_refreshes"))
    var collection_total_before := int(collection_system.get_status().get("total", 0))
    var collection_sig := "focused_collection_refresh_%d" % collection_total_before
    collection_system.collect("world_event_artifacts", "Focused collection A", {"source":"test"}, {"value":1111}, int(game.get("day")), collection_sig + "_a")
    collection_system.collect("world_event_artifacts", "Focused collection B", {"source":"test"}, {"value":2222}, int(game.get("day")), collection_sig + "_b")
    await process_frame
    await process_frame
    var collection_total_after := int(collection_system.get_status().get("total", 0))
    check(collection_total_after == collection_total_before + 2, "Two collection mutations are recorded")
    check(int(collection.get("applied_refreshes")) == collection_refreshes + 1, "Visible Collection coalesces burst mutations into one refresh")
    var count_label := collection.get("count_label") as Label
    check(count_label != null and count_label.text == "%d ITEMS" % collection_total_after, "Collection count reflects newly recovered assets")

    manager.hide_all_screens()
    await process_frame
    var hidden_collection_refreshes := int(collection.get("applied_refreshes"))
    collection_system.collect("world_event_artifacts", "Focused hidden collection", {"source":"test"}, {"value":3333}, int(game.get("day")), collection_sig + "_hidden")
    await process_frame
    await process_frame
    check(int(collection.get("applied_refreshes")) == hidden_collection_refreshes, "Hidden Collection does not rebuild in background")

    game.queue_free()
    await process_frame

    print("ARCHIVE LIVE REFRESH RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
