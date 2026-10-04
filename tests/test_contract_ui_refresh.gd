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

func _ids(grid: GridContainer) -> Array[int]:
    var result: Array[int] = []
    for child in grid.get_children():
        result.append(child.get_instance_id())
    return result

func _all_disabled(grid: GridContainer, expected: bool) -> bool:
    for child in grid.get_children():
        if child is BaseButton and bool((child as BaseButton).disabled) != expected:
            return false
    return true

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

    var panel := game.get_node_or_null("UI/ContractPanel")
    check(panel != null, "Contract panel available")
    if panel == null:
        game.queue_free()
        await process_frame
        quit(1)
        return

    var grid := panel.get("offer_grid") as GridContainer
    check(grid != null, "Contract offer grid available")
    if grid == null:
        game.queue_free()
        await process_frame
        quit(1)
        return

    check(grid.get_child_count() == 5, "Five commercial offer controls are created once")
    var first_ids := _ids(grid)

    panel.call("_refresh", false)
    await process_frame
    var second_ids := _ids(grid)
    check(second_ids == first_ids, "Timed contract refresh preserves offer button instances")

    panel.call("_refresh", false)
    await process_frame
    check(_ids(grid) == first_ids, "Repeated unchanged refresh does not rebuild offer controls")

    panel.call("_sync_offer_actions", {"eligible": false})
    check(_ids(grid) == first_ids and _all_disabled(grid, true), "Eligibility lock updates existing offer controls")

    panel.call("_sync_offer_actions", {"eligible": true})
    check(_ids(grid) == first_ids and _all_disabled(grid, false), "Eligibility unlock updates existing offer controls")

    game.queue_free()
    await process_frame
    print("CONTRACT UI REFRESH RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
