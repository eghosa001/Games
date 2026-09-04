extends Node
class_name RenewUIScreenManager

# Keeps mutually-exclusive game panels from stacking over the world.
# Individual panels continue to own their own input/build logic; this manager
# enforces the presentation rule that at most one primary screen is open.

const PRIMARY_SCREEN_NAMES := [
    "ContractPanel",
    "HeadquartersPanel",
    "TechnologyPanel",
    "AlliancePanel",
    "MarketPanel",
    "EmployeePanel",
    "CollectionPanel",
    "LiveOpsPanel",
]
const ROOT_SCREEN_NAMES := ["RenewDiplomacyUI"]

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
        var node := get_tree().root.get_node_or_null(screen_name)
        if node != null:
            result.append(node)
    return result

func _initialize() -> void:
    if _ui_root() == null:
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
        for screen_name in PRIMARY_SCREEN_NAMES:
            var node := ui.get_node_or_null(screen_name)
            if node != null:
                result.append(node)
    result.append_array(_root_screen_nodes())
    return result

# Screen scripts intentionally hide their inner Panel/PanelContainer rather than
# their CanvasLayer/Node2D host. We therefore inspect the rendered descendants.
func _is_node_visible(node: Node) -> bool:
    for child in node.get_children():
        if child is CanvasItem and child.is_visible_in_tree():
            return true
        if _has_visible_canvas_item(child):
            return true
    return false

func _has_visible_canvas_item(node: Node) -> bool:
    for child in node.get_children():
        if child is CanvasItem and child.is_visible_in_tree():
            return true
        if _has_visible_canvas_item(child):
            return true
    return false

func _set_node_visible(node: Node, value: bool) -> void:
    # Keep CanvasLayer hosts enabled so existing scripts can still open their
    # panels by changing panel.visible. Only the actual rendered UI descendants
    # are toggled.
    for child in node.get_children():
        if child is CanvasItem:
            child.visible = value
        else:
            _set_canvas_descendants_visible(child, value)

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

    # Recover gracefully if a panel was opened before this manager initialized.
    if _active_screen == null:
        for node in nodes:
            if _is_node_visible(node):
                _active_screen = node
                break

    if _active_screen == null:
        return

    # If the active screen was closed, allow another visible screen to become active.
    if not _is_node_visible(_active_screen):
        _active_screen = null
        for node in nodes:
            if _is_node_visible(node):
                _active_screen = node
                break

    if _active_screen == null:
        return

    # One and only one primary screen may be visible.
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
        target = get_tree().root.get_node_or_null(screen_name)
    if target == null or not (PRIMARY_SCREEN_NAMES.has(screen_name) or ROOT_SCREEN_NAMES.has(screen_name)):
        push_warning("Unknown primary RENEW screen: %s" % screen_name)
        return

    _active_screen = target
    for node in _screen_nodes():
        _set_node_visible(node, node == target)
        _previous_visible[node.name] = node == target
