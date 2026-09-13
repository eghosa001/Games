extends Node
## Central UI region coordinator. Prevents floating CanvasLayer panels from
## overlapping each other or the primary command surface (action dock).
## Panels self-register via _on_screen_changed(open: bool).
## Stores only panel names (strings), never raw node pointers, to avoid
## use-after-free during tree teardown.

var _panel_names: Array[String] = ["StrategyHUD", "TutorialOverlay"]
var _last_screen: String = ""

func _ready() -> void:
    # Apply the initial closed state after the main UI tree has entered the scene.
    call_deferred("_resolve")

func _exit_tree() -> void:
    # Clear registries before any native cleanup runs.
    _panel_names.clear()
    _last_screen = ""

func _notification(what: int) -> void:
    if what == NOTIFICATION_PREDELETE:
        _panel_names.clear()
        _last_screen = ""

func set_active_screen(screen_name: String) -> void:
    _last_screen = screen_name
    # Skip entirely if the tree is tearing down.
    var tree := get_tree()
    if tree == null:
        return
    var root := tree.root
    if root == null or not root.is_inside_tree() or root.is_queued_for_deletion():
        return
    var open := screen_name != ""
    for name in _panel_names:
        if name.is_empty():
            continue
        # Look up by absolute path to avoid ambiguity.
        var n := root.get_node_or_null("Renew/UI/" + name)
        if n == null:
            n = root.get_node_or_null("UI/" + name)
        if n == null:
            n = root.get_node_or_null("Renew/" + name)
        if n == null or not is_instance_valid(n) or not n.is_inside_tree() or n.is_queued_for_deletion():
            continue
        if n.has_method("_on_screen_changed"):
            n.call("_on_screen_changed", open)

## Backward-compatible refresh hook for ui_screen_manager callers.
## Re-applies the last known screen state instead of silently doing nothing.
func _resolve() -> void:
    set_active_screen(_last_screen)

func is_any_floating_panel_being_managed() -> bool:
    return _last_screen != ""

func get_active_screen() -> String:
    return _last_screen

func get_all_registered() -> Array:
    return _panel_names.duplicate()

func get_panel_rect(panel_name: String) -> Rect2:
    var tree := get_tree()
    if tree == null:
        return Rect2()
    var root := tree.root
    if root == null:
        return Rect2()
    var n := root.get_node_or_null("Renew/UI/" + panel_name)
    if n == null:
        n = root.get_node_or_null("UI/" + panel_name)
    if n == null:
        n = root.get_node_or_null("Renew/" + panel_name)
    if n == null or not is_instance_valid(n) or not n.is_inside_tree():
        return Rect2()
    var panel_node := n.get("panel")
    if panel_node is Control:
        return (panel_node as Control).get_global_rect()
    return Rect2()
