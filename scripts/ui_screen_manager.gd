extends Node
## Central presentation guard for RESTORA's primary screens.
## Guarantees one active screen, premium close affordance, Escape/Android-back
## dismissal, tap-outside dismissal, safe cleanup and focused presentation.

const SCREEN_NAMES := ["ContractPanel", "HeadquartersPanel", "TechnologyPanel", "AlliancePanel", "EmployeePanel", "CollectionPanel", "LiveOpsPanel", "HistoryPanel", "NewsPanel", "InfrastructurePanel", "DashboardPanel", "FinancePanel", "PortfolioPanel", "CorporationsPanel", "RegionsPanel", "WorldOpportunitiesPanel", "BusinessOperationsPanel", "ProductionControlPanel", "SupplyChainPanel", "EmpireExpansionPanel", "EmpireIntelligencePanel", "EmpireProgressionPanel", "EmpireIdentityPanel", "NotificationsCenterPanel", "SaveLoadPanel"]
const ROOT_SCREEN_NAMES := ["RenewDiplomacyUI", "CustomerSegmentsUI"]
const SCREEN_ALIASES := {"MarketPanel": "CustomerSegmentsUI"}
const CLOSE_BUTTON_NAME := "UniversalCloseButton"
const MODAL_LAYER_NAME := "FocusedScreenBackdrop"
const MODAL_LAYER := 50
const SCREEN_SCAN_INTERVAL := 0.10

var _previous_visible: Dictionary = {}
var _active_screen: Node = null
var _active_screen_name := ""
var _initializing := true
var _suppress_hooks := false
var _modal_layer: CanvasLayer
var _modal_backdrop: ColorRect
var _screen_tween: Tween
var _backdrop_tween: Tween
var _scan_clock := 0.0

func _ready() -> void:
    call_deferred("_try_initialize")

func _try_initialize() -> void:
    if not _initializing: return
    if get_tree().root.get_node_or_null("Renew") == null: return
    _suppress_hooks = true
    hide_all_screens()
    _suppress_hooks = false
    _initializing = false

func _ui_root() -> Node:
    var game_root := get_tree().root.get_node_or_null("Renew")
    return game_root.get_node_or_null("UI") if game_root != null else null

func _coordinator() -> Node:
    return RenewServices.get_service("RenewUIRegionCoordinator")

func _canonical_screen_name(screen_name: String) -> String:
    return String(SCREEN_ALIASES.get(screen_name, screen_name))

func _root_screen_nodes() -> Array[Node]:
    var result: Array[Node] = []
    var ui := _ui_root()
    for screen_name in ROOT_SCREEN_NAMES:
        var node: Node = null
        if ui != null: node = ui.get_node_or_null(screen_name)
        if node == null: node = get_tree().root.get_node_or_null("Renew/" + screen_name)
        if node == null: node = get_tree().root.get_node_or_null(screen_name)
        if node != null: result.append(node)
    return result

func _screen_nodes() -> Array[Node]:
    var result: Array[Node] = []
    var ui := _ui_root()
    if ui != null:
        for screen_name in SCREEN_NAMES:
            var node := ui.get_node_or_null(screen_name)
            if node != null: result.append(node)
    result.append_array(_root_screen_nodes())
    return result

func _process(delta: float) -> void:
    if _initializing:
        _try_initialize()
        return
    # Recursive visibility inspection is unnecessary at render-frame cadence.
    # Ten checks per second keeps self-closing panels responsive without wasting CPU.
    _scan_clock += delta
    if _scan_clock >= SCREEN_SCAN_INTERVAL:
        _scan_clock = 0.0
        _enforce_single_screen()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and _active_screen != null:
        hide_all_screens()
        get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST and _active_screen != null:
        hide_all_screens()

func _is_node_visible(node: Node) -> bool:
    if node == null or not is_instance_valid(node): return false
    if node is CanvasLayer:
        for child in node.get_children():
            if child is CanvasItem and child.visible and child.is_visible_in_tree(): return true
            if _has_visible_canvas_item(child): return true
        return false
    return (node is CanvasItem and node.visible and node.is_visible_in_tree()) or _has_visible_canvas_item(node)

func _has_visible_canvas_item(node: Node) -> bool:
    for child in node.get_children():
        if child is CanvasItem and child.visible and child.is_visible_in_tree(): return true
        if _has_visible_canvas_item(child): return true
    return false

func _call_screen_hook(node: Node, value: bool) -> void:
    if _suppress_hooks or node == null or not is_instance_valid(node): return
    if value and node.has_method("open_screen"): node.open_screen()
    elif not value and node.has_method("close_screen"): node.close_screen()

func _set_direct_canvas_children_visible(node: Node, value: bool) -> void:
    for child in node.get_children():
        if child is CanvasItem:
            child.visible = value
            if child is Control:
                child.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
        elif child is CanvasLayer:
            child.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED

func _set_node_visible(node: Node, value: bool) -> void:
    if node == null or not is_instance_valid(node): return

    if node.has_method("open_screen") or node.has_method("close_screen"):
        node.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
        if _suppress_hooks:
            _set_direct_canvas_children_visible(node, value)
        else:
            for child in node.get_children():
                if child is CanvasItem or child is CanvasLayer:
                    child.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
            _call_screen_hook(node, value)
            if value and not _is_node_visible(node):
                _set_direct_canvas_children_visible(node, true)
        return

    if node is CanvasLayer:
        node.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
        _set_direct_canvas_children_visible(node, value)
    elif node is CanvasItem:
        node.visible = value
        if node is Control:
            node.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
    else:
        node.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
        _set_direct_canvas_children_visible(node, value)

func _theme_scrim_color() -> Color:
    var manager := get_node_or_null("/root/RestoraThemeManager")
    if manager != null and manager.has_method("color"):
        return manager.color("scrim")
    return Color(0.018, 0.028, 0.075, 0.76)

func _ensure_modal_backdrop() -> void:
    if _modal_layer != null and is_instance_valid(_modal_layer) and _modal_backdrop != null and is_instance_valid(_modal_backdrop):
        return
    _modal_layer = CanvasLayer.new()
    _modal_layer.name = MODAL_LAYER_NAME
    _modal_layer.layer = MODAL_LAYER
    _modal_layer.follow_viewport_enabled = true
    var ui := _ui_root()
    if ui != null:
        ui.add_child(_modal_layer)
    else:
        get_tree().root.add_child(_modal_layer)
    _modal_backdrop = ColorRect.new()
    _modal_backdrop.name = "Backdrop"
    _modal_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _modal_backdrop.color = _theme_scrim_color()
    _modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    _modal_backdrop.visible = false
    _modal_backdrop.gui_input.connect(_on_backdrop_input)
    _modal_layer.add_child(_modal_backdrop)

func _on_backdrop_input(event: InputEvent) -> void:
    if _active_screen == null:
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        hide_all_screens()
        get_viewport().set_input_as_handled()
    elif event is InputEventScreenTouch and event.pressed:
        hide_all_screens()
        get_viewport().set_input_as_handled()

func _set_modal_backdrop(value: bool) -> void:
    _ensure_modal_backdrop()
    if _modal_backdrop != null:
        _modal_backdrop.color = _theme_scrim_color()
    if _modal_backdrop == null: return
    if _backdrop_tween != null and _backdrop_tween.is_valid(): _backdrop_tween.kill()
    if value:
        _modal_backdrop.visible = true
        _modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
        _modal_backdrop.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
        _modal_backdrop.modulate.a = 0.0
        _backdrop_tween = create_tween()
        _backdrop_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        _backdrop_tween.tween_property(_modal_backdrop, "modulate:a", 1.0, 0.18)
    else:
        _modal_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _modal_backdrop.process_mode = Node.PROCESS_MODE_DISABLED
        _modal_backdrop.visible = false
        _modal_backdrop.modulate.a = 1.0

func _screen_control(node: Node) -> Control:
    if node is Control: return node
    if node is CanvasLayer:
        for child in node.get_children():
            if child is Control and child.visible: return child
    return _first_control_child(node)

func _animate_screen_in(node: Node) -> void:
    var control := _screen_control(node)
    if control == null: return
    if _screen_tween != null and _screen_tween.is_valid(): _screen_tween.kill()
    control.pivot_offset = control.size * 0.5
    if bool(ProjectSettings.get_setting("renew/ui/reduce_motion", false)):
        control.modulate.a = 1.0
        control.scale = Vector2.ONE
        return
    control.modulate.a = 0.0
    control.scale = Vector2(0.976, 0.976)
    control.position.y += 16.0
    var target_y := control.position.y - 16.0
    _screen_tween = create_tween().set_parallel(true)
    _screen_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    _screen_tween.tween_property(control, "modulate:a", 1.0, 0.22)
    _screen_tween.tween_property(control, "scale", Vector2.ONE, 0.26)
    _screen_tween.tween_property(control, "position:y", target_y, 0.25)

func hide_all_screens() -> void:
    _suppress_hooks = true
    _active_screen = null
    _active_screen_name = ""
    for node in _screen_nodes():
        _set_node_visible(node, false)
        _previous_visible[node.name] = false
    _suppress_hooks = false
    _set_modal_backdrop(false)
    var coordinator := _coordinator()
    if coordinator != null:
        coordinator.set_active_screen("")
        if coordinator.has_method("_resolve"): coordinator._resolve()

func _enforce_single_screen() -> void:
    var nodes := _screen_nodes()
    var newly_opened: Node = null
    for node in nodes:
        var now := _is_node_visible(node)
        var was: bool = _previous_visible.get(node.name, false)
        if now and not was: newly_opened = node
        _previous_visible[node.name] = now
    # An explicit show_screen() selection is authoritative. A late-visible
    # legacy panel may be discovered by the periodic scan, but it must not steal
    # focus from a valid active screen simply because a frame crossed the scan
    # interval. Only adopt an externally-opened screen when there is no valid
    # active screen left.
    if newly_opened != null and (_active_screen == null or not _is_node_visible(_active_screen)):
        _active_screen = newly_opened
        _active_screen_name = newly_opened.name
        _ensure_close_button(_active_screen)
    if _active_screen == null or not _is_node_visible(_active_screen):
        _active_screen = null
        _active_screen_name = ""
        _set_modal_backdrop(false)
        var coordinator := _coordinator()
        if coordinator != null:
            coordinator.set_active_screen("")
            if coordinator.has_method("_resolve"): coordinator._resolve()
        return
    for node in nodes:
        if node != _active_screen and _is_node_visible(node):
            _set_node_visible(node, false)
            _previous_visible[node.name] = false
    _set_modal_backdrop(true)
    var active_coordinator := _coordinator()
    if active_coordinator != null:
        active_coordinator.set_active_screen(_active_screen_name)
        if active_coordinator.has_method("_resolve"): active_coordinator._resolve()

func show_screen(screen_name: String) -> bool:
    if _initializing: _try_initialize()
    var canonical_name := _canonical_screen_name(screen_name)
    var target: Node = null
    var ui := _ui_root()
    if ui != null: target = ui.get_node_or_null(canonical_name)
    if target == null: target = get_tree().root.get_node_or_null("Renew/" + canonical_name)
    if target == null: target = get_tree().root.get_node_or_null(canonical_name)
    if target == null or not (SCREEN_NAMES.has(canonical_name) or ROOT_SCREEN_NAMES.has(canonical_name)):
        push_warning("Unknown primary RESTORA screen: %s" % screen_name)
        return false
    _active_screen = target
    _active_screen_name = canonical_name
    for node in _screen_nodes():
        var should_show := node == target
        _set_node_visible(node, should_show)
        _previous_visible[node.name] = should_show
    _ensure_close_button(target)
    _set_modal_backdrop(true)
    _animate_screen_in(target)
    var coordinator := _coordinator()
    if coordinator != null:
        coordinator.set_active_screen(canonical_name)
        if coordinator.has_method("_resolve"): coordinator._resolve()
    return true

func get_active_screen_name() -> String:
    if _active_screen != null and is_instance_valid(_active_screen):
        return _active_screen_name if _active_screen_name != "" else String(_active_screen.name)
    return ""

func is_screen_open(screen_name: String) -> bool:
    var canonical_name := _canonical_screen_name(screen_name)
    for node in _screen_nodes():
        if node.name == canonical_name: return _is_node_visible(node)
    return false

func _premium_close_style(bg: Color, border: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(12)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 9
    style.content_margin_bottom = 9
    style.shadow_color = Color(0, 0, 0, 0.28)
    style.shadow_size = 4
    style.shadow_offset = Vector2(0, 2)
    return style

func _style_close_button(button: Button) -> void:
    if button == null: return
    var surface := Color("10241f")
    var border := Color("37564f")
    var accent := Color("e5b95f")
    var text := Color("eef9f5")
    button.add_theme_stylebox_override("normal", _premium_close_style(surface, border))
    button.add_theme_stylebox_override("hover", _premium_close_style(Color("19332c"), accent))
    button.add_theme_stylebox_override("pressed", _premium_close_style(Color("0b1816"), accent))
    button.add_theme_stylebox_override("focus", _premium_close_style(Color("19332c"), accent))
    button.add_theme_color_override("font_color", text)
    button.add_theme_color_override("font_hover_color", accent)
    button.add_theme_color_override("font_pressed_color", accent)
    button.add_theme_font_size_override("font_size", 12)

func _ensure_close_button(screen: Node) -> void:
    if screen == null or not is_instance_valid(screen): return
    var host: Control = null
    if screen is CanvasLayer:
        for child in screen.get_children():
            if child is Control:
                host = child
                break
    elif screen is Control:
        host = screen
    else:
        host = _first_control_child(screen)
    if host == null: return

    var existing := _find_close_button(screen)
    if existing != null:
        existing.name = CLOSE_BUTTON_NAME
        existing.tooltip_text = "Close"
        existing.focus_mode = Control.FOCUS_ALL
        existing.mouse_filter = Control.MOUSE_FILTER_STOP
        existing.z_index = 4096
        existing.custom_minimum_size = Vector2(
            maxf(existing.custom_minimum_size.x, 48.0),
            maxf(existing.custom_minimum_size.y, 48.0)
        )
        _style_close_button(existing)
        if not existing.pressed.is_connected(_on_close_pressed):
            existing.pressed.connect(_on_close_pressed)
        return

    var button := Button.new()
    button.name = CLOSE_BUTTON_NAME
    button.text = "CLOSE"
    button.tooltip_text = "Close"
    button.focus_mode = Control.FOCUS_ALL
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    button.z_index = 4096
    button.custom_minimum_size = Vector2(96, 48)
    button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    button.offset_left = -112.0
    button.offset_top = 14.0
    button.offset_right = -16.0
    button.offset_bottom = 62.0
    _style_close_button(button)
    button.pressed.connect(_on_close_pressed)
    host.add_child(button)

func _on_close_pressed() -> void:
    hide_all_screens()

func _first_control_child(node: Node) -> Control:
    for child in node.get_children():
        if child is Control: return child
        var nested := _first_control_child(child)
        if nested != null: return nested
    return null

func _find_close_button(node: Node) -> Button:
    if node is Button:
        var self_button := node as Button
        if self_button.name == CLOSE_BUTTON_NAME or self_button.text.strip_edges().to_upper() in ["CLOSE", "X", "×"]:
            return self_button
    var children := node.get_children()
    for i in range(children.size() - 1, -1, -1):
        var found := _find_close_button(children[i])
        if found != null: return found
    return null
