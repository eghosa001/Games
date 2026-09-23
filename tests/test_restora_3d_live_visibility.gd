extends SceneTree

var failed := 0

const LEGACY_RENDERERS := [
    "World/EmpireController",
    "World/Corporate",
    "World/WorldMissions",
    "World/RegionController",
    "World/BranchController",
    "World/RivalSupplyController",
]

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check("Main scene loads", packed != null)
    if packed == null:
        quit(1)
        return

    var game := packed.instantiate()
    root.add_child(game)
    current_scene = game
    for _frame in range(12):
        await process_frame

    var world_3d := game.get_node_or_null("World3D")
    check("3D world exists", world_3d != null)
    if world_3d == null:
        game.queue_free()
        await process_frame
        quit(1)
        return

    for path in LEGACY_RENDERERS:
        var renderer := game.get_node_or_null(path) as CanvasItem
        check("legacy renderer exists: %s" % path, renderer != null)
        if renderer != null:
            check("3D mode hides live renderer: %s" % path, not renderer.visible)

    root.size = Vector2i(1280, 720)
    await process_frame
    var mobile_fix := game.get_node_or_null("UI/MainHUD/MobileScaleFix")
    check("obsolete mobile compatibility node is removed", mobile_fix == null)

    var web_adapter := root.get_node_or_null("RenewWebResponsive")
    check("web responsive adapter exists", web_adapter != null)
    var main_hud := game.get_node_or_null("UI/MainHUD")
    if web_adapter != null and main_hud != null and web_adapter.has_method("_apply_scene_visibility"):
        web_adapter.set("_last_browser_size", Vector2i(1280, 720))
        main_hud.set("active_tab", 2)
        web_adapter.call("_apply_scene_visibility")
        await process_frame
        for path in LEGACY_RENDERERS:
            var renderer := game.get_node_or_null(path) as CanvasItem
            if renderer != null:
                check("Empire responsive pass keeps 3D renderer hidden: %s" % path, not renderer.visible)
        main_hud.set("active_tab", 3)
        web_adapter.call("_apply_scene_visibility")
        await process_frame
        for path in LEGACY_RENDERERS:
            var renderer := game.get_node_or_null(path) as CanvasItem
            if renderer != null:
                check("World responsive pass keeps 3D renderer hidden: %s" % path, not renderer.visible)

    world_3d.set_presentation_enabled(false)
    await process_frame
    for path in LEGACY_RENDERERS:
        var renderer := game.get_node_or_null(path) as CanvasItem
        if renderer != null:
            check("2D fallback restores renderer: %s" % path, renderer.visible)

    game.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)

func check(label: String, condition: bool) -> void:
    if condition:
        print("PASS: %s" % label)
    else:
        failed += 1
        push_error("FAIL: %s" % label)
