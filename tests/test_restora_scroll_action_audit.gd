extends SceneTree
# Focused usability gate: every authored Figma route is scrollable and its
# enabled visible actions are wired, without firing on touch-down while swiping.
const BASE := ["live", "operate", "property", "finance", "empire", "world", "portfolio", "intelligence", "more", "settings", "guide", "rewards"]
const DETAILS := [
    "new_game", "continue_game", "onboarding",
    "property_overview", "restoration_plan", "restoration_confirm", "before_after",
    "business_list", "business_overview", "production", "employee_list",
    "employee_detail", "hiring", "assign_employee", "contract_market",
    "contract_detail", "active_contracts", "supply_chain", "supplier_compare",
    "inventory", "budget", "funding", "financial_health", "region_overview",
    "property_acquisition", "infrastructure_roadmap", "company_progress",
    "milestones", "alliances", "corporate_strategy", "acquisitions",
    "world_power", "headquarters", "legacy", "endgame", "reports",
    "notifications", "accessibility", "pause", "day_summary", "level_up",
    "restoration_complete", "insufficient_funds", "offline_error",
    "loading", "empty_states"
]
var failed := 0
var checks := 0

func _initialize() -> void:
    call_deferred("_run")

func check(label: String, condition: bool) -> void:
    checks += 1
    if not condition:
        failed += 1
        push_error("FAIL: " + label)

func _buttons(node: Node, found: Array[Button]) -> void:
    if node is Button:
        var button := node as Button
        if button.is_visible_in_tree() and not button.disabled:
            found.append(button)
    for child in node.get_children():
        _buttons(child, found)

func _run() -> void:
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
    root.size = Vector2i(390, 844)
    var scene := load("res://scenes/Main.tscn") as PackedScene
    check("Main scene loads", scene != null)
    if scene == null:
        quit(1)
        return
    var game := scene.instantiate()
    root.add_child(game)
    current_scene = game
    for i in range(3):
        await process_frame
    var hud := game.get_node_or_null("UI/MainHUD")
    check("Main HUD available", hud != null)
    if hud == null:
        quit(1)
        return

    for viewport in [Vector2i(320, 568), Vector2i(390, 844)]:
        root.size = viewport
        hud._layout_responsive()
        await process_frame
        for route in BASE + DETAILS:
            hud.open_figma_view(route)
            await process_frame
            await process_frame
            var scroll := hud.get("mobile_scroll") as ScrollContainer
            var content := hud.get("mobile_content") as Control
            var label := "%s %s" % [viewport, route]
            check(label + " scroll host", scroll != null and content != null)
            if scroll == null or content == null:
                continue
            check(label + " uses visible vertical scrollbar", scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO)
            check(label + " enables keyboard focus following", scroll.follow_focus)
            check(label + " disables sideways scroll", scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED)
            var buttons: Array[Button] = []
            _buttons(content, buttons)
            for button in buttons:
                check(label + " %s is wired" % button.name, not button.pressed.get_connections().is_empty())
                if String(button.name).begins_with("FlowAction") or String(button.name).begins_with("Open"):
                    check(label + " %s waits for touch release" % button.name, button.action_mode == BaseButton.ACTION_MODE_BUTTON_RELEASE)
            var vbar := scroll.get_v_scroll_bar()
            var end_scroll := int(maxf(0.0, vbar.max_value - vbar.page)) if vbar != null else 0
            if end_scroll > 10:
                scroll.scroll_vertical = end_scroll
                await process_frame
                check(label + " can reach lower content", scroll.scroll_vertical >= end_scroll - 4)
                scroll.scroll_vertical = 0

    hud.open_figma_view("more")
    await process_frame
    var sc := hud.get("mobile_scroll") as ScrollContainer
    var more := hud.get("mobile_content") as Control
    var last := more.get_node_or_null("MoreSection3/Opensettings") as Button
    check("More final Settings action exists", last != null)
    if sc != null and last != null:
        sc.scroll_vertical = 0
        last.grab_focus()
        await process_frame
        await process_frame
        check("keyboard focus scrolls to final Settings action", sc.scroll_vertical > 0)
        last.pressed.emit()
        await process_frame
        check("More Settings action opens real Settings page", str(hud.get("active_view")) == "settings")

    hud.open_figma_view("more")
    await process_frame
    var guide := (hud.get("mobile_content") as Control).get_node_or_null("MoreSection3/Openguide") as Button
    check("More How to Play action exists", guide != null)
    if guide != null:
        guide.pressed.emit()
        await process_frame
        check("More How to Play action opens Guide", str(hud.get("active_view")) == "guide")

    # ScreenManager owns 27 other pop-up and dashboard surfaces. These do not
    # share ProductionScroll, so check their close/actions are reachable too.
    var manager := root.get_node_or_null("RenewUIScreenManager")
    check("managed screen coordinator available", manager != null)
    if manager != null:
        var managed := [
            "ContractPanel", "HeadquartersPanel", "TechnologyPanel", "AlliancePanel",
            "EmployeePanel", "CollectionPanel", "LiveOpsPanel", "HistoryPanel",
            "NewsPanel", "InfrastructurePanel", "DashboardPanel", "FinancePanel",
            "PortfolioPanel", "CorporationsPanel", "RegionsPanel",
            "WorldOpportunitiesPanel", "BusinessOperationsPanel",
            "ProductionControlPanel", "SupplyChainPanel", "EmpireExpansionPanel",
            "EmpireIntelligencePanel", "EmpireProgressionPanel", "EmpireIdentityPanel",
            "NotificationsCenterPanel", "SaveLoadPanel", "RenewDiplomacyUI",
            "CustomerSegmentsUI"
        ]
        for viewport in [Vector2i(320, 568), Vector2i(390, 844)]:
            root.size = viewport
            hud._layout_responsive()
            await process_frame
            for name in managed:
                manager.show_screen(name)
                await process_frame
                var modal := game.get_node_or_null("UI/" + name)
                check("%s %s is reachable" % [viewport, name], modal != null and manager.get_active_screen_name() == name)
                if modal != null:
                    var modal_buttons: Array[Button] = []
                    _buttons(modal, modal_buttons)
                    for btn in modal_buttons:
                        var bound := Rect2(Vector2.ZERO, Vector2(viewport))
                        var rect := btn.get_global_rect()
                        var clipped := rect.intersection(bound)
                        var visible_ratio := clipped.get_area() / maxf(1.0, rect.get_area())
                        var container: Node = btn.get_parent()
                        var in_scroll := false
                        while container != null:
                            if container is ScrollContainer:
                                in_scroll = true
                                break
                            container = container.get_parent()
                        check("%s %s %s wired" % [viewport, name, btn.name], not btn.pressed.get_connections().is_empty())
                        if not in_scroll:
                            check("%s %s %s on-screen" % [viewport, name, btn.name], visible_ratio >= 0.98)
                manager.hide_all_screens()
                await process_frame

    game.queue_free()
    await process_frame
    print("SCROLL AND BUTTON AUDIT: %d checks, %d failures" % [checks, failed])
    quit(1 if failed > 0 else 0)
