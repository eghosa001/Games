extends SceneTree

# Exhaustive release gate for player-facing UI behavior.
# This test intentionally validates the real Main scene and real UIScreenManager
# instead of unit-testing individual presentation scripts in isolation.

const VIEWPORTS := [
    Vector2i(320, 568),
    Vector2i(360, 640),
    Vector2i(390, 844),
    Vector2i(412, 915),
    Vector2i(768, 1024),
    Vector2i(1280, 720),
    Vector2i(1920, 1080),
]

const TRANSITION_SEQUENCE := [
    "DashboardPanel",
    "FinancePanel",
    "BusinessOperationsPanel",
    "EmployeePanel",
    "ContractPanel",
    "HeadquartersPanel",
    "TechnologyPanel",
    "InfrastructurePanel",
    "ProductionControlPanel",
    "SupplyChainPanel",
    "RegionsPanel",
    "WorldOpportunitiesPanel",
    "CorporationsPanel",
    "PortfolioPanel",
    "CollectionPanel",
    "LiveOpsPanel",
    "NewsPanel",
    "HistoryPanel",
    "EmpireExpansionPanel",
    "EmpireIntelligencePanel",
    "EmpireProgressionPanel",
    "EmpireIdentityPanel",
    "NotificationsCenterPanel",
    "SaveLoadPanel",
    "AlliancePanel",
    "RenewDiplomacyUI",
    "CustomerSegmentsUI",
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

    # Keep the test list coupled to the manager itself so newly managed screens
    # cannot be added without automatically entering this gate.
    var managed_names: Array[String] = []
    for name in manager.SCREEN_NAMES:
        managed_names.append(String(name))
    for name in manager.ROOT_SCREEN_NAMES:
        managed_names.append(String(name))
    _check(managed_names.size() == 27, "expected 27 managed primary screens")

    for viewport_size in VIEWPORTS:
        await _set_viewport(viewport_size)
        await _audit_viewport(managed_names, viewport_size)

    # Stress the lifecycle at a representative phone size. Repeated open/close
    # catches stale visibility flags, duplicated dynamic controls and manager
    # re-entry bugs that a single pass misses.
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

    # Legacy navigation alias is part of the public UI contract.
    manager.show_screen("MarketPanel")
    await process_frame
    _check(manager.get_active_screen_name() == "CustomerSegmentsUI", "MarketPanel alias resolves")
    manager.hide_all_screens()
    await process_frame

    _finish()

func _set_viewport(size: Vector2i) -> void:
    root.size = size
    # Some screens listen to Window.size_changed while others recompute during
    # open_screen/process. Give both paths time to settle.
    root.size_changed.emit()
    await process_frame
    await process_frame

func _audit_viewport(screen_names: Array[String], viewport_size: Vector2i) -> void:
    var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
    manager.hide_all_screens()
    await process_frame
    _check(_visible_screen_count() == 0, "%s starts with no modal screen" % viewport_size)

    for screen_name in screen_names:
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
            var rect := button.get_global_rect()
            _check(_rect_mostly_inside(rect, viewport_rect), "%s %s button inside viewport: %s rect=%s" % [viewport_size, screen_name, label, rect])

        # Detect controls that are completely unreachable/off-screen. Partial
        # clipping is permitted for scroll content, but a visible control must
        # intersect the viewport at all.
        for control in visible_controls:
            if control == null or not is_instance_valid(control): continue
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
    # Allow a tiny rounding/layout tolerance, but reject genuinely clipped
    # interactive controls because inaccessible buttons are release blockers.
    var visible_area := clipped.size.x * clipped.size.y
    var area := rect.size.x * rect.size.y
    return visible_area / maxf(area, 1.0) >= 0.98

func _check_button_overlap(screen_name: String, viewport_size: Vector2i, buttons: Array[Button]) -> void:
    for i in range(buttons.size()):
        var a := buttons[i]
        if not is_instance_valid(a): continue
        var a_rect := a.get_global_rect()
        for j in range(i + 1, buttons.size()):
            var b := buttons[j]
            if not is_instance_valid(b): continue
            # Parent/child button nesting is not a valid interactive pattern,
            # but avoid double-reporting it as geometry overlap here.
            if a.is_ancestor_of(b) or b.is_ancestor_of(a): continue
            var intersection := a_rect.intersection(b.get_global_rect())
            if intersection.size.x <= 1.0 or intersection.size.y <= 1.0: continue
            var overlap_area := intersection.size.x * intersection.size.y
            var smaller_area := minf(a_rect.size.x * a_rect.size.y, b.size.x * b.size.y)
            _check(overlap_area / maxf(smaller_area, 1.0) < 0.10, "%s %s buttons do not overlap: %s / %s" % [viewport_size, screen_name, a.text, b.text])

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
        var node := ui.get_node_or_null(screen_name)
        if node != null: return node
    var node := root.get_node_or_null("Renew/" + screen_name)
    if node != null: return node
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
