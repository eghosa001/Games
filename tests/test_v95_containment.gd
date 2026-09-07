extends SceneTree

## Pass 5: new screens stay inside small viewports with touch-sized
## controls, and re-layout when the viewport changes.
var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _inside(parent: Control, child: Control) -> bool:
    var bounds := Rect2(Vector2.ZERO, parent.size)
    return bounds.encloses(Rect2(child.position, child.size))

func run() -> void:
    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for containment audit")
    if scene == null:
        quit(1)
        return
    var game = scene.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    root.size = Vector2i(320, 568)
    await process_frame
    await process_frame
    var manager = root.get_node_or_null("RenewUIScreenManager")
    for screen_name in ["DashboardPanel", "FinancePanel", "PortfolioPanel", "CorporationsPanel"]:
        manager.show_screen(screen_name)
        await process_frame
        await process_frame
        var panel: Node = game.get_node_or_null("UI/" + screen_name)
        check(panel != null, screen_name + " mounted")
        if panel == null:
            continue
        var box: Control = null
        for child in panel.get_children():
            if child is Panel:
                box = child
        check(box != null, screen_name + " has a panel box")
        if box == null:
            continue
        check(box.position.x >= 0.0 and box.position.y >= 0.0, screen_name + " positioned on screen")
        check(box.position.x + box.size.x <= 321.0, screen_name + " fits 320px width")
        var small := 0
        var outside := 0
        for child in box.get_children():
            if child is Button:
                if (child as Button).custom_minimum_size.y < 44.0:
                    small += 1
                if not _inside(box, child):
                    outside += 1
        check(small == 0, screen_name + " buttons meet touch sizing")
        check(outside == 0, screen_name + " controls stay inside")
    manager.hide_all_screens()
    root.size = Vector2i(1280, 720)
    await process_frame
    game.free()
    await process_frame
    print("V95 CONTAINMENT RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
