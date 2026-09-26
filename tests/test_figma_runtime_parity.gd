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
    var how_to_body := content.get_node_or_null("MoreTile0/Body") as Label
    check("HOW TO PLAY copy names the full loop", how_to_body != null and how_to_body.text.contains("Grow") and how_to_body.get_line_count() >= 2)

    hud.open_figma_view("guide")
    await process_frame
    content = hud.get("mobile_content") as Control
    var intro_body := content.get_node_or_null("GuideIntro/Body") as Label
    var restore_steps := content.get_node_or_null("GuideRestore/Steps") as Label
    var restore_why := content.get_node_or_null("GuideRestore/Why") as Control
    var restore_button := content.get_node_or_null("GuideRestore/GoRestore") as Control
    var operate_why := content.get_node_or_null("GuideOperate/Why") as Control
    var operate_button := content.get_node_or_null("GuideOperate/GoOperate") as Control
    var grow_panel := content.get_node_or_null("GuideGrow") as Control
    var grow_why := content.get_node_or_null("GuideGrow/Why") as Label
    check("guide body wraps instead of clipping", intro_body != null and intro_body.get_line_count() >= 2 and restore_steps != null and restore_steps.get_line_count() >= 2)
    check("RESTORE explanation clears its action", restore_why != null and restore_button != null and restore_why.get_global_rect().end.y <= restore_button.get_global_rect().position.y)
    check("OPERATE explanation clears its action", operate_why != null and operate_button != null and operate_why.get_global_rect().end.y <= operate_button.get_global_rect().position.y)
    check("GROW explanation fits its card", grow_panel != null and grow_why != null and grow_why.get_line_count() >= 2 and grow_panel.get_global_rect().encloses(grow_why.get_global_rect()))

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
