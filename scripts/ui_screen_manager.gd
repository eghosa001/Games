extends Node
class_name RenewUIScreenManager

# Central UI presentation guard for RENEW.
# Primary/modal screens must never render on top of one another. Existing UI
# scripts remain responsible for their own content and buttons; this manager
# only enforces visibility boundaries between screens.

const SCREEN_NAMES := [
    "ContractPanel",
    "HeadquartersPanel",
    "TechnologyPanel",
    "AlliancePanel",
    "MarketPanel",
    "EmployeePanel",
    "CollectionPanel",
    "LiveOpsPanel",
    "HistoryPanel",
    "NewsPanel",
]

const ROOT_SCREEN_NAMES := [
    "RenewDiplomacyUI",
    "CustomerSegmentsUI",
]

var _previous_visible: Dictionary = {}
var _active_screen: Node = null
var _initializing := true

func _ready() -> void:
    call_deferred("_initialize")

func _ui_root() -> Node:
    var game_root := get_tree().root.get_node_or_null("Renew")
    if game_root == null:
        return null
    return game_root.get_node_or_null("UI")

func _root_screen_nodes() -> Array[Node]:
    var result: Array[Node] = []
    for screen_name in ROOT_SCREEN_NAMES:
        var node := get_tree().root.get_node_or_null("Renew/" + screen_name)
        if node == null:
            node = get_tree().root.get_node_or_null(screen_name)
        if node != null:
            result.append(node)
    return result

func _initialize() -> void:
    if get_tree().root.get_node_or_null("Renew") == null:
        call_deferred("_initialize")
        return
    for node in _screen_nodes():
        _previous_visible[node.name] = _is_node_visible(node)
    _initializing = false
    _enforce_single_screen()

func _process(_delta: float) -> void:
    if _initializing:
        return
    _enforce_single_screen()

func _screen_nodes() -> Array[Node]:
    var result: Array[Node] = []
    var ui := _ui_root()
    if ui != null:
        for screen_name in SCREEN_NAMES:
            var node := ui.get_node_or_null(screen_name)
            if node != null:
                result.append(node)
    result.append_array(_root_screen_nodes())
    return result

func _is_node_visible(node: Node) -> bool:
    # CanvasLayer is a host, so inspect its rendered descendants. This avoids
    # disabling the host scripts while still detecting their actual panels.
    if node is CanvasLayer:
        for child in node.get_children():
            if _has_visible_canvas_item(child):
                return true
        return false

    # Node2D/Control panels can render directly from _draw(), so their own
    # visible flag must be checked as well as their descendants.
    if node is CanvasItem and node.visible and node.is_visible_in_tree():
        return true
    return _has_visible_canvas_item(node)

func _has_visible_canvas_item(node: Node) -> bool:
    for child in node.get_children():
        if child is CanvasItem and child.visible and child.is_visible_in_tree():
            return true
        if _has_visible_canvas_item(child):
            return true
    return false

func _set_node_visible(node: Node, value: bool) -> void:
    if node is CanvasLayer:
        # Do not hide the CanvasLayer host; existing scripts may need it to
        # receive input. Hide only the rendered UI descendants.
        for child in node.get_children():
            _set_canvas_descendants_visible(child, value)
    elif node is CanvasItem:
        node.visible = value
    else:
        _set_canvas_descendants_visible(node, value)

func _set_canvas_descendants_visible(node: Node, value: bool) -> void:
    for child in node.get_children():
        if child is CanvasItem:
            child.visible = value
        else:
            _set_canvas_descendants_visible(child, value)

func _enforce_single_screen() -> void:
    var nodes := _screen_nodes()
    if nodes.is_empty():
        return

    var newly_opened: Node = null
    for node in nodes:
        var now := _is_node_visible(node)
        var was: bool = _previous_visible.get(node.name, false)
        if now and not was:
            newly_opened = node
        _previous_visible[node.name] = now

    if newly_opened != null:
        _active_screen = newly_opened

    if _active_screen == null:
        for node in nodes:
            if _is_node_visible(node):
                _active_screen = node
                break

    if _active_screen == null:
        return

    if not _is_node_visible(_active_screen):
        _active_screen = null
        for node in nodes:
            if _is_node_visible(node):
                _active_screen = node
                break

    if _active_screen == null:
        return

    for node in nodes:
        if node != _active_screen and _is_node_visible(node):
            _set_node_visible(node, false)
            _previous_visible[node.name] = false

func show_screen(screen_name: String) -> void:
    var target: Node = null
    var ui := _ui_root()
    if ui != null:
        target = ui.get_node_or_null(screen_name)
    if target == null:
        target = get_tree().root.get_node_or_null("Renew/" + screen_name)
    if target == null:
        target = get_tree().root.get_node_or_null(screen_name)
    if target == null or not (SCREEN_NAMES.has(screen_name) or ROOT_SCREEN_NAMES.has(screen_name)):
        push_warning("Unknown primary RENEW screen: %s" % screen_name)
        return

    _active_screen = target
    for node in _screen_nodes():
        _set_node_visible(node, node == target)
        _previous_visible[node.name] = node == target
