extends SceneTree

# Exhaustive release gate for player-facing UI behavior.
# Validates the real Main scene and UIScreenManager across representative
# phones, tablets and desktop sizes, including every persistent command page.

const VIEWPORTS := [
    Vector2i(320, 568),
    Vector2i(360, 640),
    Vector2i(390, 844),
    Vector2i(412, 915),
    Vector2i(768, 1024),
    Vector2i(1280, 720),
    Vector2i(1920, 1080),
]

const MANAGED_SCREENS := [
    "ContractPanel", "HeadquartersPanel", "TechnologyPanel", "AlliancePanel",
    "EmployeePanel", "CollectionPanel", "LiveOpsPanel", "HistoryPanel",
    "NewsPanel", "InfrastructurePanel", "DashboardPanel", "FinancePanel",
    "PortfolioPanel", "CorporationsPanel", "RegionsPanel", "WorldOpportunitiesPanel",
    "BusinessOperationsPanel", "ProductionControlPanel", "SupplyChainPanel",
    "EmpireExpansionPanel", "EmpireIntelligencePanel", "EmpireProgressionPanel",
    "EmpireIdentityPanel", "NotificationsCenterPanel", "SaveLoadPanel",
    "RenewDiplomacyUI", "CustomerSegmentsUI",
]

const PAGE_COUNTS := [4, 9, 10, 5]

const TRANSITION_SEQUENCE := [
    "DashboardPanel", "FinancePanel", "BusinessOperationsPanel", "EmployeePanel",
    "ContractPanel", "HeadquartersPanel", "TechnologyPanel", "InfrastructurePanel",
    "ProductionControlPanel", "SupplyChainPanel", "RegionsPanel",
    "WorldOpportunitiesPanel", "CorporationsPanel", "PortfolioPanel",
    "CollectionPanel", "LiveOpsPanel", "NewsPanel", "HistoryPanel",
    "EmpireExpansionPanel", "EmpireIntelligencePanel", "EmpireProgressionPanel",
    "EmpireIdentityPanel", "NotificationsCenterPanel", "SaveLoadPanel",
    "AlliancePanel", "RenewDiplomacyUI", "CustomerSegmentsUI",
]

var checks := 0
var failures: Array[String] = []
var game: Node
var manager: Node

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load("res://scenes/Main.tscn") as PackedScene
    _check(packed != null, "Main scene loads for exhaustive UI matrix")
    if packed == null:
        _finish()
        return

    game = packed.instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    await process_frame
    await process_frame

    manager = root.get_node_or_null("RenewUIScreenManager")
    _check(manager != null, "UIScreenManager resolves")
    if manager == null:
        _finish()
        return

    _check(MANAGED_SCREENS.size() == 27, "matrix contains 27 managed primary screens")
    _check(_manager_screen_names().size() == MANAGED_SCREENS.size(), "matrix count matches screen manager")
    for screen_name in MANAGED_SCREENS:
        _check(_manager_screen_names().has(screen_name), "matrix includes manager screen %s" % screen_name)

    for viewport_size in VIEWPORTS:
        await _set_viewport(viewport_size)
        await _audit_persistent_shell(viewport_size)
        await _audit_viewport(viewport_size)

    await _set_viewport(Vector2i(390, 844))
    for cycle in range(3):
        for screen_name in TRANSITION_SEQUENCE:
            manager.show_screen(screen_name)
            await process_frame
            _check(manager.get_active_screen_name() == screen_name, "stress %d active screen %s" % [cycle + 1, screen_name])
            _check(_visible_screen_count() == 1, "stress %d single visible screen after %s" % [cycle + 1, screen_name])
        manager.hide_all_screens()
        await process_frame
        _check(_visible_screen_count() == 0, "stress %d closes all screens" % [cycle + 1])

    manager.show_screen("MarketPanel")
    await process_frame
    _check(manager.get_active_screen_name() == "CustomerSegmentsUI", "MarketPanel alias resolves")
    manager.hide_all_screens()
    await process_frame

    _finish()

func _manager_screen_names() -> Array[String]:
    var names: Array[String] = []
    for node in manager._screen_nodes():
        if node != null:
            names.append(String(node.name))
    return names

func _set_viewport(size: Vector2i) -> void:
    root.size = size
    root.size_changed.emit()
    await process_frame
    await process_frame

func _audit_persistent_shell(viewport_size: Vector2i) -> void:
    manager.hide_all_screens()
    await process_frame
    var hud := game.get_node_or_null("UI/MainHUD")
    _check(hud != null, "%s MainHUD resolves" % viewport_size)
    if hud == null:
        return
    if hud.has_method("_layout_responsive"):
        hud._layout_responsive()
        await process_frame

    var tabs := hud.get("tabs") as HBoxContainer
    var actions := hud.get("actions") as GridContainer
    var action_dock := hud.get("action_dock") as Control
    _check(tabs != null, "%s primary tabs resolve" % viewport_size)
    _check(actions != null, "%s action grid resolves" % viewport_size)
    _check(action_dock != null, "%s action dock resolves" % viewport_size)
    if tabs != null:
        _check(tabs.get_child_count() == 4, "%s exactly four primary tabs" % viewport_size)
        for child in tabs.get_children():
            var button := child as Button
            if button == null: continue
            _check(button.size.x >= 44.0 and button.size.y >= 44.0, "%s primary tab >=44px: %s" % [viewport_size, button.text])
            _check(button.pressed.get_connections().size() > 0, "%s primary tab wired: %s" % [viewport_size, button.text])

    if action_dock != null and action_dock.visible:
        _check(_rect_mostly_inside(action_dock.get_global_rect(), Rect2(Vector2.ZERO, Vector2(viewport_size))), "%s action dock inside viewport" % viewport_size)

    # Exercise every command page without invoking business mutations. This
    # verifies the navigation structure, button creation and responsive sizing
    # for all 28 HUD pages.
    if hud.has_method("_set_tab") and hud.has_method("_set_page"):
        for tab_index in range(PAGE_COUNTS.size()):
            hud._set_tab(tab_index)
            await process_frame
            for page_index in range(PAGE_COUNTS[tab_index]):
                hud._set_page(page_index)
                await process_frame
                var page_buttons: Array[Button] = []
                if actions != null:
                    _collect_enabled_visible_buttons(actions, page_buttons)
                _check(not page_buttons.is_empty(), "%s HUD tab %d page %d has actions" % [viewport_size, tab_index, page_index])
                _check(page_buttons.size() <= 6, "%s HUD tab %d page %d keeps action count <=6" % [viewport_size, tab_index, page_index])
                for button in page_buttons:
                    var label := button.text.strip_edges().replace("\n", " ")
                    _check(button.size.x >= 44.0 and button.size.y >= 44.0, "%s HUD action >=44px: %s" % [viewport_size, label])
                    _check(button.pressed.get_connections().size() > 0, "%s HUD action wired: %s" % [viewport_size, label])
                    if not _has_scroll_ancestor(button):
                        _check(_rect_mostly_inside(button.get_global_rect(), Rect2(Vector2.ZERO, Vector2(viewport_size))), "%s HUD action inside viewport: %s" % [viewport_size, label])

    # Restore the default landing page so later screen tests start consistently.
    if hud.has_method("_set_tab"):
        hud._set_tab(0)
        await process_frame

func _audit_viewport(viewport_size: Vector2i) -> void:
    var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
    manager.hide_all_screens()
    await process_frame
    _check(_visible_screen_count() == 0, "%s starts with no modal screen" % viewport_size)

    for screen_name in MANAGED_SCREENS:
        manager.show_screen(screen_name)
        await process_frame
        await process_frame

        var screen := _find_screen(screen_name)
        _check(screen != null, "%s %s resolves" % [viewport_size, screen_name])
        if screen == null:
            continue

        _check(manager.get_active_screen_name() == screen_name, "%s %s becomes active" % [viewport_size, screen_name])
        _check(manager.is_screen_open(screen_name), "%s %s reports open" % [viewport_size, screen_name])
        _check(_visible_screen_count() == 1, "%s %s is the only managed screen" % [viewport_size, screen_name])

        var visible_controls: Array[Control] = []
        _collect_visible_controls(screen, visible_controls)
        _check(not visible_controls.is_empty(), "%s %s paints visible controls" % [viewport_size, screen_name])

        var close_button := _find_close_button(screen)
        _check(close_button != null, "%s %s has close affordance" % [viewport_size, screen_name])
        if close_button != null:
            _check(close_button.visible and close_button.is_visible_in_tree(), "%s %s close button visible" % [viewport_size, screen_name])
            _check(close_button.size.x >= 44.0 and close_button.size.y >= 44.0, "%s %s close target >=44px" % [viewport_size, screen_name])
            _check(close_button.pressed.get_connections().size() > 0, "%s %s close button wired" % [viewport_size, screen_name])

        var enabled_buttons: Array[Button] = []
        _collect_enabled_visible_buttons(screen, enabled_buttons)
        for button in enabled_buttons:
            var label := button.text.strip_edges().replace("\n", " ")
            if label.is_empty(): label = String(button.name)
            _check(button.size.x > 0.0 and button.size.y > 0.0, "%s %s button has size: %s" % [viewport_size, screen_name, label])
            _check(button.size.x >= 44.0 and button.size.y >= 44.0, "%s %s touch target >=44px: %s" % [viewport_size, screen_name, label])
            _check(button.pressed.get_connections().size() > 0, "%s %s button wired: %s" % [viewport_size, screen_name, label])
            if not _has_scroll_ancestor(button):
                var rect := button.get_global_rect()
                _check(_rect_mostly_inside(rect, viewport_rect), "%s %s button inside viewport: %s rect=%s" % [viewport_size, screen_name, label, rect])

        for control in visible_controls:
            if control == null or not is_instance_valid(control): continue
            if _has_scroll_ancestor(control): continue
            var rect := control.get_global_rect()
            if rect.size.x <= 0.0 or rect.size.y <= 0.0: continue
            _check(rect.intersects(viewport_rect), "%s %s visible control intersects viewport: %s" % [viewport_size, screen_name, control.name])

        _check_button_overlap(screen_name, viewport_size, enabled_buttons)

        manager.hide_all_screens()
        await process_frame
        _check(not manager.is_screen_open(screen_name), "%s %s closes cleanly" % [viewport_size, screen_name])
        _check(_visible_screen_count() == 0, "%s no stale screen after closing %s" % [viewport_size, screen_name])

func _rect_mostly_inside(rect: Rect2, viewport_rect: Rect2) -> bool:
    if rect.size.x <= 0.0 or rect.size.y <= 0.0:
        return false
    var clipped := rect.intersection(viewport_rect)
    if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
        return false
    var visible_area := clipped.size.x * clipped.size.y
    var area := rect.size.x * rect.size.y
    return visible_area / maxf(area, 1.0) >= 0.98

func _check_button_overlap(screen_name: String, viewport_size: Vector2i, buttons: Array[Button]) -> void:
    for i in range(buttons.size()):
        var a := buttons[i]
        if not is_instance_valid(a) or _is_fully_clipped_by_scroll(a): continue
        var a_rect := a.get_global_rect()
        for j in range(i + 1, buttons.size()):
            var b := buttons[j]
            if not is_instance_valid(b) or _is_fully_clipped_by_scroll(b): continue
            if a.is_ancestor_of(b) or b.is_ancestor_of(a): continue
            var b_rect := b.get_global_rect()
            var intersection := a_rect.intersection(b_rect)
            if intersection.size.x <= 1.0 or intersection.size.y <= 1.0: continue
            var overlap_area := intersection.size.x * intersection.size.y
            var smaller_area := minf(a_rect.size.x * a_rect.size.y, b_rect.size.x * b_rect.size.y)
            _check(overlap_area / maxf(smaller_area, 1.0) < 0.10, "%s %s buttons do not overlap: %s / %s" % [viewport_size, screen_name, a.text, b.text])

func _has_scroll_ancestor(control: Control) -> bool:
    var node := control.get_parent()
    while node != null:
        if node is ScrollContainer:
            return true
        node = node.get_parent()
    return false

func _is_fully_clipped_by_scroll(control: Control) -> bool:
    var rect := control.get_global_rect()
    var node := control.get_parent()
    while node != null:
        if node is ScrollContainer:
            if not rect.intersects((node as Control).get_global_rect()):
                return true
        node = node.get_parent()
    return false

func _collect_visible_controls(node: Node, out: Array[Control]) -> void:
    if node is Control:
        var control := node as Control
        if control.visible and control.is_visible_in_tree():
            out.append(control)
    for child in node.get_children():
        _collect_visible_controls(child, out)

func _collect_enabled_visible_buttons(node: Node, out: Array[Button]) -> void:
    if node is Button:
        var button := node as Button
        if button.visible and button.is_visible_in_tree() and not button.disabled:
            out.append(button)
    for child in node.get_children():
        _collect_enabled_visible_buttons(child, out)

func _find_screen(screen_name: String) -> Node:
    var ui := game.get_node_or_null("UI")
    if ui != null:
        var ui_node := ui.get_node_or_null(screen_name)
        if ui_node != null: return ui_node
    var scene_node := root.get_node_or_null("Renew/" + screen_name)
    if scene_node != null: return scene_node
    return root.get_node_or_null(screen_name)

func _find_close_button(node: Node) -> Button:
    if node == null: return null
    if node is Button:
        var button := node as Button
        var text := button.text.strip_edges().to_upper()
        if text in ["CLOSE", "X", "×"] or String(button.name).to_lower().contains("close"):
            return button
    var children := node.get_children()
    for i in range(children.size() - 1, -1, -1):
        var found := _find_close_button(children[i])
        if found != null: return found
    return null

func _visible_screen_count() -> int:
    var count := 0
    for node in manager._screen_nodes():
        if manager._is_node_visible(node): count += 1
    return count

func _check(ok: bool, label: String) -> void:
    checks += 1
    if ok:
        print("PASS: " + label)
    else:
        failures.append(label)
        push_error("FAIL: " + label)

func _finish() -> void:
    print("--- EXHAUSTIVE UI MATRIX SUMMARY ---")
    print("Checks: %d | Failures: %d" % [checks, failures.size()])
    if not failures.is_empty():
        for failure in failures:
            print("FAILED: " + failure)
    else:
        print("EXHAUSTIVE UI MATRIX: PASS")
    if game != null and is_instance_valid(game): game.queue_free()
    quit(1 if not failures.is_empty() else 0)
