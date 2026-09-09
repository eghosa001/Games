extends Node
## Central presentation guard for RENEW's primary screens.
## Guarantees one active screen, a visible close affordance, Escape/Android-back
## dismissal, and safe cleanup when panels close themselves.

const SCREEN_NAMES := ["ContractPanel", "HeadquartersPanel", "TechnologyPanel", "AlliancePanel", "EmployeePanel", "CollectionPanel", "LiveOpsPanel", "HistoryPanel", "NewsPanel", "InfrastructurePanel", "DashboardPanel", "FinancePanel", "PortfolioPanel", "CorporationsPanel", "RegionsPanel", "WorldOpportunitiesPanel", "BusinessOperationsPanel", "ProductionControlPanel", "SupplyChainPanel", "EmpireExpansionPanel", "EmpireIntelligencePanel", "EmpireProgressionPanel", "EmpireIdentityPanel", "NotificationsCenterPanel", "SaveLoadPanel"]
const ROOT_SCREEN_NAMES := ["RenewDiplomacyUI", "CustomerSegmentsUI"]
const SCREEN_ALIASES := {"MarketPanel": "CustomerSegmentsUI"}
const CLOSE_BUTTON_NAME := "UniversalCloseButton"

var _previous_visible: Dictionary = {}
var _active_screen: Node = null
var _active_screen_name := ""
var _initializing := true
var _suppress_hooks := false

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
    return get_tree().root.get_node_or_null("RenewUIRegionCoordinator")

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

func _process(_delta: float) -> void:
    if _initializing:
        _try_initialize()
        return
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

func _set_node_visible(node: Node, value: bool) -> void:
    if node == null or not is_instance_valid(node): return
    if node is CanvasLayer:
        node.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
        for child in node.get_children(): _set_node_visible(child, value)
    elif node is CanvasItem:
        node.visible = value
        if node is Control:
            node.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
    else:
        node.process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
        for child in node.get_children(): _set_node_visible(child, value)
    _call_screen_hook(node, value)

func hide_all_screens() -> void:
    _suppress_hooks = true
    _active_screen = null
    _active_screen_name = ""
    for node in _screen_nodes():
        _set_node_visible(node, false)
        _previous_visible[node.name] = false
    _suppress_hooks = false
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
    if newly_opened != null:
        _active_screen = newly_opened
        _active_screen_name = newly_opened.name
        _ensure_close_button(_active_screen)
    if _active_screen == null or not _is_node_visible(_active_screen):
        _active_screen = null
        _active_screen_name = ""
        var coordinator := _coordinator()
        if coordinator != null:
            coordinator.set_active_screen("")
            if coordinator.has_method("_resolve"): coordinator._resolve()
        return
    for node in nodes:
        if node != _active_screen and _is_node_visible(node):
            _set_node_visible(node, false)
            _previous_visible[node.name] = false
    var active_coordinator := _coordinator()
    if active_coordinator != null:
        active_coordinator.set_active_screen(_active_screen_name)
        if active_coordinator.has_method("_resolve"): active_coordinator._resolve()

func show_screen(screen_name: String) -> void:
    if _initializing: _try_initialize()
    var canonical_name := _canonical_screen_name(screen_name)
    var target: Node = null
    var ui := _ui_root()
    if ui != null: target = ui.get_node_or_null(canonical_name)
    if target == null: target = get_tree().root.get_node_or_null("Renew/" + canonical_name)
    if target == null: target = get_tree().root.get_node_or_null(canonical_name)
    if target == null or not (SCREEN_NAMES.has(canonical_name) or ROOT_SCREEN_NAMES.has(canonical_name)):
        push_warning("Unknown primary RENEW screen: %s" % screen_name)
        return
    _active_screen = target
    _active_screen_name = canonical_name
    for node in _screen_nodes():
        var should_show := node == target
        _set_node_visible(node, should_show)
        _previous_visible[node.name] = should_show
    _ensure_close_button(target)
    var coordinator := _coordinator()
    if coordinator != null:
        coordinator.set_active_screen(canonical_name)
        if coordinator.has_method("_resolve"): coordinator._resolve()

func get_active_screen_name() -> String:
    if _active_screen != null and is_instance_valid(_active_screen):
        return _active_screen_name if _active_screen_name != "" else String(_active_screen.name)
    return ""

func is_screen_open(screen_name: String) -> bool:
    var canonical_name := _canonical_screen_name(screen_name)
    for node in _screen_nodes():
        if node.name == canonical_name: return _is_node_visible(node)
    return false

func _ensure_close_button(screen: Node) -> void:
    if screen == null or not is_instance_valid(screen): return
    var existing := _find_close_button(screen)
    if existing != null:
        existing.name = CLOSE_BUTTON_NAME
        if not existing.pressed.is_connected(_on_close_pressed):
            existing.pressed.connect(_on_close_pressed)
        existing.tooltip_text = "Close"
        existing.focus_mode = Control.FOCUS_NONE
        return
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
    var button := Button.new()
    button.name = CLOSE_BUTTON_NAME
    button.text = "CLOSE"
    button.tooltip_text = "Close"
    button.focus_mode = Control.FOCUS_NONE
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    button.z_index = 10000
    button.custom_minimum_size = Vector2(88, 44)
    button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    button.position = Vector2(-104, 16)
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
