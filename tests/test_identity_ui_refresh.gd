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

func _ids(container: VBoxContainer) -> Array[int]:
    var out: Array[int] = []
    for child in container.get_children():
        out.append(child.get_instance_id())
    return out

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

    var screen := game.get_node_or_null("UI/EmpireIdentityPanel")
    check(screen != null, "Empire Identity panel available")
    if screen == null:
        game.queue_free()
        await process_frame
        quit(1)
        return

    screen.open_screen()
    await process_frame
    var content := screen.get("content") as VBoxContainer
    check(content != null and content.get_child_count() > 0, "Empire Identity renders cards")
    if content == null:
        game.queue_free()
        await process_frame
        quit(1)
        return

    var first_ids := _ids(content)
    screen.call("_refresh", false)
    await process_frame
    check(_ids(content) == first_ids, "Unchanged identity refresh preserves card instances")

    screen.call("_refresh", false)
    await process_frame
    check(_ids(content) == first_ids, "Repeated timed identity refresh stays allocation-free")

    game.message = "Identity refresh regression notice"
    screen.call("_refresh", false)
    await process_frame
    var changed_ids := _ids(content)
    check(changed_ids != first_ids, "Changed company state rebuilds identity cards")
    var rendered_notice := false
    for child in content.get_children():
        var labels: Array[Node] = child.find_children("*", "Label", true, false)
        for label in labels:
            if label is Label and (label as Label).text.contains("Identity refresh regression notice"):
                rendered_notice = true
                break
        if rendered_notice:
            break
    check(rendered_notice, "Changed company notice is reflected after rebuild")

    game.queue_free()
    await process_frame
    print("IDENTITY UI REFRESH RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
