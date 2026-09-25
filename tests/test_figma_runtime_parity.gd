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

func _near(a: float, b: float, tolerance := 0.6) -> bool:
    return absf(a - b) <= tolerance

func _rect(control: Control, pos: Vector2, size: Vector2, label: String) -> void:
    check(label + " x", _near(control.position.x, pos.x))
    check(label + " y", _near(control.position.y, pos.y))
    check(label + " width", _near(control.size.x, size.x))
    check(label + " height", _near(control.size.y, size.y))

func _child(node: Node, name: String) -> Control:
    return node.get_node_or_null(name) as Control

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
    await process_frame
    await process_frame
    await process_frame

    var hud := game.get_node_or_null("UI/MainHUD")
    check("MainHUD exists", hud != null)
    if hud == null:
        quit(1)
        return

    check("production runtime root exists", hud.get("root") != null and hud.get("root").name == "RestoraFigmaRuntime")
    check("mobile content exists", hud.get("mobile_content") != null)
    check("five production destinations", hud.get("mode_buttons") is Array and hud.get("mode_buttons").size() == 5)

    var nav := hud.get("bottom_nav") as Control
    _rect(nav, Vector2(12, 758), Vector2(366, 70), "bottom nav")
    var buttons: Array = hud.get("mode_buttons")
    var expected := ["HOME", "BUSINESS", "PROPERTY", "FINANCE", "MORE"]
    for i in range(5):
        var button := buttons[i] as Button
        check("nav %d touch target" % i, button != null and button.size.x >= 48 and button.size.y >= 48)
        var label := button.get_node_or_null("NavLabel") as Label
        check("nav %d label" % i, label != null and label.text == expected[i])

    var content := hud.get("mobile_content") as Control
    _rect(_child(content, "ExecutiveHero"), Vector2(18,82), Vector2(354,154), "LIVE hero")
    _rect(_child(content, "Stat_cash"), Vector2(18,254), Vector2(174,104), "LIVE cash")
    _rect(_child(content, "Stat_worth"), Vector2(198,254), Vector2(174,104), "LIVE worth")
    _rect(_child(content, "Stat_rep"), Vector2(18,370), Vector2(174,104), "LIVE reputation")
    _rect(_child(content, "Stat_goods"), Vector2(198,370), Vector2(174,104), "LIVE goods")
    _rect(_child(content, "Signals"), Vector2(18,494), Vector2(354,192), "LIVE signals")

    check("LIVE overview contains nine properties", content.find_children("OverviewPropertyRow*", "Panel", false, false).size() == 9)
    check("LIVE overview contains three business models", content.find_children("OverviewBusinessRow*", "Panel", false, false).size() == 3)
    check("LIVE overview contains six regions", content.find_children("OverviewRegionRow*", "Panel", false, false).size() == 6)
    check("LIVE overview links eight connected systems", content.find_children("OverviewSystemTile*", "Panel", false, false).size() == 8)

    hud.open_figma_view("operate")
    await process_frame
    content = hud.get("mobile_content") as Control
    _rect(_child(content, "ProductionControl"), Vector2(18,204), Vector2(354,150), "OPERATE production")
    _rect(_child(content, "CommercialControls"), Vector2(18,370), Vector2(354,176), "OPERATE commercial")
    _rect(_child(content, "Equipment"), Vector2(18,562), Vector2(354,112), "OPERATE equipment")
    _rect(_child(content, "DayChip"), Vector2(292,20), Vector2(80,34), "OPERATE day chip")

    hud.open_figma_view("finance")
    await process_frame
    content = hud.get("mobile_content") as Control
    _rect(_child(content, "CreditHealth"), Vector2(18,320), Vector2(354,88), "FINANCE credit")
    _rect(_child(content, "Transactions"), Vector2(18,424), Vector2(354,214), "FINANCE transactions")
    var tutorial_overlay := game.get_node_or_null("UI/TutorialOverlay")
    var guide_chip := tutorial_overlay.get("collapsed_button") as Button if tutorial_overlay != null else null
    if tutorial_overlay != null and tutorial_overlay.has_method("_layout_responsive"):
        tutorial_overlay.call("_layout_responsive")
    check("FINANCE hides compact Guide chip", guide_chip != null and not guide_chip.visible)

    hud.open_figma_view("property")
    await process_frame
    content = hud.get("mobile_content") as Control
    _rect(_child(content, "PropertyCatalog"), Vector2(18,82), Vector2(354,512), "PROPERTY catalog")
    check("PROPERTY exposes nine named buildings first", content.find_children("BuildingRow*", "Panel", false, false).size() == 9)
    _rect(_child(content, "PropertyVisual"), Vector2(18,660), Vector2(354,238), "PROPERTY visual")
    check("PROPERTY uses staged building art", _child(content, "PropertyVisual").get_node_or_null("BuildingStageArt") != null)
    _rect(_child(content, "RestorationProgress"), Vector2(18,916), Vector2(354,116), "PROPERTY progress")
    _rect(_child(content, "BuildingDetails"), Vector2(18,1050), Vector2(354,126), "PROPERTY details")
    if tutorial_overlay != null and tutorial_overlay.has_method("_layout_responsive"):
        tutorial_overlay.call("_layout_responsive")
    var guide_panel := tutorial_overlay.get("panel") as Control if tutorial_overlay != null else null
    check("PROPERTY keeps tutorial guidance available", tutorial_overlay != null and ((guide_panel != null and guide_panel.visible) or (guide_chip != null and guide_chip.visible)))
    var property_nav := hud.get("bottom_nav") as Control
    var guide_control: Control = guide_panel if guide_panel != null and guide_panel.visible else guide_chip
    check("PROPERTY guidance stays above bottom navigation", guide_control != null and property_nav != null and guide_control.get_global_rect().end.y <= property_nav.get_global_rect().position.y + 0.6)

    hud.open_figma_view("empire")
    await process_frame
    content = hud.get("mobile_content") as Control
    _rect(_child(content, "ManagementCapacity"), Vector2(18,82), Vector2(354,88), "EMPIRE capacity")
    _rect(_child(content, "ExpansionAssets"), Vector2(18,188), Vector2(354,278), "EMPIRE assets")
    _rect(_child(content, "AssetDetail"), Vector2(18,484), Vector2(354,166), "EMPIRE detail")

    hud.open_figma_view("world")
    await process_frame
    content = hud.get("mobile_content") as Control
    _rect(_child(content, "RegionalMap"), Vector2(18,82), Vector2(354,220), "WORLD map")
    check("WORLD uses authored district art", _child(content, "RegionalMap").get_node_or_null("RegionalDistrictArt") != null)
    _rect(_child(content, "RegionDetail"), Vector2(18,320), Vector2(354,142), "WORLD detail")
    _rect(_child(content, "WorldOpportunities"), Vector2(18,480), Vector2(354,176), "WORLD opportunities")

    hud.open_figma_view("more")
    await process_frame
    content = hud.get("mobile_content") as Control
    _rect(_child(content, "CompanyProfile"), Vector2(18,82), Vector2(354,94), "MORE company")
    check("MORE has ten command tiles including How to Play", content.find_children("MoreTile*", "Panel", false, false).size() == 10)

    hud.open_figma_view("settings")
    await process_frame
    content = hud.get("mobile_content") as Control
    _rect(_child(content, "Appearance"), Vector2(18,82), Vector2(354,160), "SETTINGS appearance")
    _rect(_child(content, "AudioAccessibility"), Vector2(18,258), Vector2(354,174), "SETTINGS audio")
    _rect(_child(content, "Monetization"), Vector2(18,448), Vector2(354,230), "SETTINGS monetization")
    _rect(_child(content, "SaveData"), Vector2(18,694), Vector2(354,86), "SETTINGS save")

    var theme := get_root().get_node_or_null("RestoraThemeManager")
    check("theme manager exists", theme != null)
    if theme != null:
        theme.set_mode("light")
        await process_frame
        check("light cool-stone background", theme.color("bg").to_html(false) == "e8eeea")
        theme.set_mode("dark")
        await process_frame
        check("dark graphite background", theme.color("bg").to_html(false) == "0b0d10")

    game.queue_free()
    await process_frame
    print("FIGMA RUNTIME PARITY: %d checks, %d failures" % [checks, failed])
    quit(1 if failed > 0 else 0)
