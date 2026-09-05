extends Node
class_name RenewUIScreenManager

## Central presentation guard. Primary screens are mutually exclusive; screen
## scripts remain responsible for their own content and gameplay integration.
const SCREEN_NAMES := ["ContractPanel", "HeadquartersPanel", "TechnologyPanel", "AlliancePanel", "MarketPanel", "EmployeePanel", "CollectionPanel", "LiveOpsPanel", "HistoryPanel", "NewsPanel"]
const ROOT_SCREEN_NAMES := ["RenewDiplomacyUI", "CustomerSegmentsUI"]
var _previous_visible: Dictionary = {}
var _active_screen: Node = null
var _initializing := true
var _suppress_hooks := false

func _ready() -> void:
    call_deferred("_initialize")

func _ui_root() -> Node:
    var game_root := get_tree().root.get_node_or_null("Renew")
    return game_root.get_node_or_null("UI") if game_root != null else null

func _root_screen_nodes() -> Array[Node]:
    var result: Array[Node] = []
    for screen_name in ROOT_SCREEN_NAMES:
        var node := get_tree().root.get_node_or_null("Renew/" + screen_name)
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

func _initialize() -> void:
    if get_tree().root.get_node_or_null("Renew") == null:
        call_deferred("_initialize"); return
    _suppress_hooks = true; hide_all_screens(); _suppress_hooks = false; _initializing = false

func _process(_delta: float) -> void:
    if not _initializing: _enforce_single_screen()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and _active_screen != null:
        hide_all_screens(); get_viewport().set_input_as_handled()

func _is_node_visible(node: Node) -> bool:
    if node == null or not is_instance_valid(node): return false
    if node is CanvasLayer:
        for child in node.get_children():
            if _has_visible_canvas_item(child): return true
        return false
    return node is CanvasItem and node.visible and node.is_visible_in_tree() or _has_visible_canvas_item(node)

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
        for child in node.get_children(): _set_node_visible(child, value)
    elif node is CanvasItem:
        node.visible = value
    else:
        for child in node.get_children(): _set_node_visible(child, value)
    _call_screen_hook(node, value)

func hide_all_screens() -> void:
    _active_screen = null
    for node in _screen_nodes(): _set_node_visible(node, false); _previous_visible[node.name] = false

func _enforce_single_screen() -> void:
    var nodes := _screen_nodes(); var newly_opened: Node = null
    for node in nodes:
        var now := _is_node_visible(node); var was: bool = _previous_visible.get(node.name, false)
        if now and not was: newly_opened = node
        _previous_visible[node.name] = now
    if newly_opened != null: _active_screen = newly_opened
    if _active_screen == null or not _is_node_visible(_active_screen):
        if _active_screen != null: _active_screen = null
        return
    for node in nodes:
        if node != _active_screen and _is_node_visible(node): _set_node_visible(node, false); _previous_visible[node.name] = false

func show_screen(screen_name: String) -> void:
    var target: Node = null; var ui := _ui_root()
    if ui != null: target = ui.get_node_or_null(screen_name)
    if target == null: target = get_tree().root.get_node_or_null("Renew/" + screen_name)
    if target == null: target = get_tree().root.get_node_or_null(screen_name)
    if target == null or not (SCREEN_NAMES.has(screen_name) or ROOT_SCREEN_NAMES.has(screen_name)):
        push_warning("Unknown primary RENEW screen: %s" % screen_name); return
    _active_screen = target
    for node in _screen_nodes():
        var should_show := node == target; _set_node_visible(node, should_show); _previous_visible[node.name] = should_show

func get_active_screen_name() -> String:
    return String(_active_screen.name) if _active_screen != null and is_instance_valid(_active_screen) else ""

func is_screen_open(screen_name: String) -> bool:
    for node in _screen_nodes():
        if node.name == screen_name: return _is_node_visible(node)
    return false
