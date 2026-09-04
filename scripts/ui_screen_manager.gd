extends Node
class_name RenewUIScreenManager

# Keeps mutually-exclusive game panels from stacking over the world.
# Individual panels can continue to own their own input/build logic; this manager
# only enforces the presentation rule that at most one primary screen is visible.

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

func _initialize() -> void:
    var ui := _ui_root()
    if ui == null:
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
    if ui == null:
        return result
    for screen_name in PRIMARY_SCREEN_NAMES:
        var node := ui.get_node_or_null(screen_name)
        if node != null:
            result.append(node)
    return result

func _is_node_visible(node: Node) -> bool:
    if node is CanvasLayer:
        return node.visible
    if node is CanvasItem:
        return node.visible
    return false

func _set_node_visible(node: Node, value: bool) -> void:
    if node is CanvasLayer:
        node.visible = value
    elif node is CanvasItem:
        node.visible = value

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
    var ui := _ui_root()
    if ui == null or not PRIMARY_SCREEN_NAMES.has(screen_name):
        push_warning("Unknown primary RENEW screen: %s" % screen_name)
        return
    var target := ui.get_node_or_null(screen_name)
    if target == null:
        push_warning("Missing primary RENEW screen: %s" % screen_name)
        return

    _active_screen = target
    for node in _screen_nodes():
        _set_node_visible(node, node == target)
        _previous_visible[node.name] = node == target
