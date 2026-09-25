extends SceneTree

var failed := 0
var checks := 0

func _init() -> void:
    call_deferred("_run")

func check(label: String, ok: bool) -> void:
    checks += 1
    if ok:
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func _inside(control: Control, viewport: Vector2i) -> bool:
    return control != null and Rect2(Vector2.ZERO, Vector2(viewport)).encloses(control.get_global_rect())

func _run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.size = Vector2i(390, 844)
    var packed := load("res://scenes/Main.tscn") as PackedScene
    check("Main scene loads", packed != null)
    if packed == null:
        quit(1)
        return

    var game := packed.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    await process_frame

    var hud := game.get_node_or_null("UI/MainHUD")
    check("MainHUD exists", hud != null)
    if hud == null:
        quit(1)
        return

    check("management runtime root exists", hud.get("root") != null and hud.get("root").name == "RestoraFigmaRuntime")
    check("five primary destinations", hud.get("mode_buttons") is Array and hud.get("mode_buttons").size() == 5)

    var expected := ["HOME", "BUSINESS", "PROPERTY", "FINANCE", "MORE"]
    var buttons: Array = hud.get("mode_buttons")
    for i in range(mini(5, buttons.size())):
        var b := buttons[i] as Button
        var label := b.get_node_or_null("NavLabel") as Label
        check("nav label " + expected[i], label != null and label.text == expected[i])
        check("nav touch target " + expected[i], b != null and b.size.y >= 48.0)

    var content := hud.get("mobile_content") as Control
    for node_name in ["ExecutiveHero", "Stat_cash", "Stat_worth", "Stat_rep", "Stat_goods", "CoreLoop", "CommandOverview"]:
        check("HOME surface " + node_name, content.find_child(node_name, true, false) != null)
    for action_name in ["OpenHomeProperties", "OpenHomeBusiness", "OpenHomeGrowth"]:
        check("HOME linked overview " + action_name, content.find_child(action_name, true, false) is Button)

    hud.open_figma_view("property")
    await process_frame
    content = hud.get("mobile_content") as Control
    check("PROPERTY selected summary exists", content.find_child("SelectedProperty", true, false) != null)
    check("PROPERTY exposes nine property rows", content.find_children("BuildingRow*", "Panel", true, false).size() == 9)
    check("PROPERTY does not render building artwork", content.find_child("BuildingStageArt", true, false) == null and content.find_child("PropertyVisual", true, false) == null)

    hud.open_figma_view("operate")
    await process_frame
    content = hud.get("mobile_content") as Control
    for node_name in ["ProductionControl", "CommercialControls", "Equipment"]:
        check("BUSINESS surface " + node_name, content.find_child(node_name, true, false) != null)

    hud.open_figma_view("finance")
    await process_frame
    content = hud.get("mobile_content") as Control
    check("FINANCE credit health exists", content.find_child("CreditHealth", true, false) != null)
    check("FINANCE real ledger exists", content.find_child("Transactions", true, false) != null)

    hud.open_figma_view("world")
    await process_frame
    content = hud.get("mobile_content") as Control
    check("WORLD regional catalog exists", content.find_child("RegionalCatalog", true, false) != null)
    check("WORLD exposes region rows", content.find_children("RegionRow*", "Panel", true, false).size() >= 3)
    check("WORLD network signals exist", content.find_child("WorldOpportunities", true, false) != null)

    hud.open_figma_view("more")
    await process_frame
    content = hud.get("mobile_content") as Control
    check("MORE has ten command tiles", content.find_children("MoreTile*", "Panel", false, false).size() == 10)

    for target in [Vector2i(320,568), Vector2i(390,844), Vector2i(480,800)]:
        root.size = target
        await process_frame
        hud._layout_responsive()
        await process_frame
        if hud.get("bottom_nav") != null:
            check("%s navigation contained" % target, _inside(hud.get("bottom_nav") as Control, target))
        if hud.get("mobile_scroll") != null:
            check("%s scroll host contained" % target, _inside(hud.get("mobile_scroll") as Control, target))

    var theme := root.get_node_or_null("RestoraThemeManager")
    check("theme manager exists", theme != null)
    if theme != null:
        theme.set_mode("light")
        await process_frame
        check("light background", theme.color("bg").to_html(false) == "e8eeea")
        theme.set_mode("dark")
        await process_frame
        check("dark background", theme.color("bg").to_html(false) == "0b0d10")

    game.queue_free()
    await process_frame
    print("RUNTIME PARITY: %d checks, %d failures" % [checks, failed])
    quit(1 if failed > 0 else 0)
