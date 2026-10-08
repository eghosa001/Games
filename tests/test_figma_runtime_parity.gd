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
    check("PROPERTY renders restoration artwork", content.find_child("PropertyVisual", true, false) is TextureRect)
    hud.open_figma_view("operate")
    await process_frame
    content = hud.get("mobile_content") as Control
    for node_name in ["ProductionControl", "CommercialControls", "BusinessToolkit"]:
        check("BUSINESS surface " + node_name, content.find_child(node_name, true, false) != null)
    for action_name in ["BusinessOverview", "BusinessTeam", "BusinessContracts", "BusinessSupply"]:
        check("BUSINESS toolkit link " + action_name, content.find_child(action_name, true, false) is Button)
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
    check("MORE groups commands into four readable sections", content.find_children("MoreSection*", "Panel", false, false).size() == 4)
    var how_to_body := content.get_node_or_null("MoreSection3/RowBody0") as Label
    check("HOW TO PLAY copy names the full loop", how_to_body != null and how_to_body.text.contains("Grow"))
    var mobile_scroll := hud.get("mobile_scroll") as ScrollContainer
    check("mobile scroll uses responsive touch deadzone", mobile_scroll != null and mobile_scroll.scroll_deadzone <= 2)
    check("MORE remains vertically scrollable", mobile_scroll != null and content.size.y > mobile_scroll.size.y)
    hud.open_figma_view("guide")
    await process_frame
    content = hud.get("mobile_content") as Control
    var next_panel := content.get_node_or_null("GuideNextMove") as Control
    var next_action := content.get_node_or_null("GuideNextMove/GoNext") as Button
    var next_detail := content.get_node_or_null("GuideNextMove/Detail") as Label
    var restore_steps := content.get_node_or_null("GuideRestore/Steps") as Label
    var restore_button := content.get_node_or_null("GuideRestore/GoRestore") as Button
    var operate_steps := content.get_node_or_null("GuideOperate/Steps") as Label
    var operate_button := content.get_node_or_null("GuideOperate/GoOperate") as Button
    var grow_panel := content.get_node_or_null("GuideGrow") as Control
    var grow_steps := content.get_node_or_null("GuideGrow/Steps") as Label
    check("guide presents simulation-driven next move first", next_panel != null and next_panel.position.y < 100.0)
    check("guide next action uses a full 48px touch target", next_action != null and next_action.size.y >= 48.0)
    check("guide next action clears its description", next_detail != null and next_action != null and next_detail.get_global_rect().end.y < next_action.get_global_rect().position.y)
    check("RESTORE explanation stays above its action", restore_steps != null and restore_button != null and restore_steps.get_global_rect().end.y < restore_button.get_global_rect().position.y)
    check("OPERATE explanation stays above its action", operate_steps != null and operate_button != null and operate_steps.get_global_rect().end.y < operate_button.get_global_rect().position.y)
    check("GROW explanation fits its card", grow_panel != null and grow_steps != null and grow_panel.get_global_rect().encloses(grow_steps.get_global_rect()))
    hud.open_figma_view("before_after")
    await process_frame
    var detail_content := hud.get("mobile_content") as Control
    var metric0 := detail_content.get_node_or_null("FlowMetric0") as Control
    var metric1 := detail_content.get_node_or_null("FlowMetric1") as Control
    var detail_label := detail_content.get_node_or_null("FlowDetails/Detail0/Text") as Label
    check("detail metric cards retain readable width", metric0 != null and metric0.size.x > 90.0)
    check("detail text uses 12px or larger", detail_label != null and detail_label.get_theme_font_size("font_size") >= 12)
    check("detail metric layout uses three columns on regular 390px phones", metric0 != null and metric1 != null and metric1.position.y == metric0.position.y)
    for target in [Vector2i(320,568), Vector2i(390,844), Vector2i(480,800)]:
        root.size = target
        await process_frame
        hud._layout_responsive()
        await process_frame
        if target.x == 320:
            var compact_content := hud.get("mobile_content") as Control
            var compact_first := compact_content.get_node_or_null("FlowMetric0") as Control
            var compact_third := compact_content.get_node_or_null("FlowMetric2") as Control
            check("320px details wrap to two metric columns", compact_first != null and compact_third != null and compact_third.position.y > compact_first.position.y)
        if hud.get("bottom_nav") != null:
            check("%s navigation contained" % target, _inside(hud.get("bottom_nav") as Control, target))
        if hud.get("mobile_scroll") != null:
            check("%s scroll host contained" % target, _inside(hud.get("mobile_scroll") as Control, target))
    var theme := root.get_node_or_null("RestoraThemeManager")
    check("theme manager exists", theme != null)
    if theme != null:
        theme.set_mode("light")
        await process_frame
        check("light background", theme.color("bg").to_html(false) == "f1ece1")
        theme.set_mode("dark")
        await process_frame
        check("dark background", theme.color("bg").to_html(false) == "171714")
    game.queue_free()
    await process_frame
    print("RUNTIME PARITY: %d checks, %d failures" % [checks, failed])
    quit(1 if failed > 0 else 0)
# Focused validation: RESTORA mobile overlap, touch scroll and navigation hierarchy.
# Focused rerun: typed mobile UX layout fix.
