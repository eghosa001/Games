extends Node
## Central UI region coordinator. Prevents floating CanvasLayer panels from
## overlapping each other or the primary command surface (action dock).
## Each floater registers its rectangle; the coordinator suppresses any that
## would intersect reserved regions or other higher-priority floaters.
var _panels: Dictionary = {}   # name -> {panel, priority, rect_fn}
var _last_screen: String = ""

func _ready() -> void:
    pass

func register_panel(name: String, panel: Node, priority: int, rect_fn: Callable) -> void:
    _panels[name] = {"panel": panel, "priority": priority, "rect_fn": rect_fn}

func unregister_panel(name: String) -> void:
    if _panels.has(name):
        _panels.erase(name)

func set_active_screen(screen_name: String) -> void:
    _last_screen = screen_name
    _resolve()

func is_any_floating_panel_being_managed() -> bool:
    return _last_screen != ""

func get_active_screen() -> String:
    return _last_screen

func get_all_registered() -> Array[String]:
    return _panels.keys()

func get_panel_rect(panel_name: String) -> Rect2:
    if not _panels.has(panel_name): return Rect2()
    var panel_info := _panels[panel_name] as Dictionary
    if panel_info["rect_fn"].is_valid():
        return panel_info["rect_fn"].call() as Rect2
    return Rect2()

func rect_intersects_dock(rect: Rect2, dock_rect: Rect2) -> bool:
    return rect.intersects(dock_rect)

func is_any_floating_panel_visible() -> bool:
    for _panel_info in _panels.values():
        var pi := _panel_info as Dictionary
        if pi["panel"] != null and pi["panel"].visible and pi["panel"].is_visible_in_tree():
            return true
    return false

func _resolve() -> void:
    if _panels.is_empty(): return
    # Lock panels so their _process() does not fight our visibility decisions.
    for info in _panels.values():
        var node := info["panel"] as Node
        if node != null and is_instance_valid(node) and node.has_method("_set_coordinator_active"):
            node.call("_set_coordinator_active", true)
    var dock_rect := _get_dock_rect()
    var screen_open := _last_screen != ""
    var sorted_keys: Array = _panels.keys()
    sorted_keys.sort_custom(func(a: String, b: String) -> int:
        var pa := _panels[a] as Dictionary
        var pb := _panels[b] as Dictionary
        return pa["priority"] as int - pb["priority"] as int
    )
    var occupied: Array[Rect2] = []
    for name in sorted_keys:
        var panel_info := _panels[name] as Dictionary
        var panel_node := panel_info["panel"] as Node
        if panel_node == null or not is_instance_valid(panel_node): continue
        # Ensure layout is current before checking overlap.
        if panel_node.has_method("_layout_responsive"):
            panel_node.call("_layout_responsive")
        var r: Rect2 = panel_info["rect_fn"].call() as Rect2
        if r == Rect2(): continue
        var should_show: bool = false
        if panel_node.has_method("_should_show"):
            var result = panel_node.call("_should_show")
            should_show = result is bool and result as bool
        var would_overlap: bool = false
        if screen_open:
            would_overlap = true
        elif dock_rect != Rect2() and rect_intersects_dock(r, dock_rect):
            would_overlap = true
        else:
            for other_r in occupied:
                if r.intersects(other_r):
                    would_overlap = true
                    break
        if not should_show:
            would_overlap = true
        var show := not would_overlap
        panel_node.visible = show
        # Propagate to all descendant Controls so nested-panel visibility checks
        # (e.g. strategy.get("panel").visible) remain consistent.
        _propagate_visibility(panel_node, show)
        if not would_overlap:
            occupied.append(r)
    # Release coordinator lock so panels resume independent layout after the
    # current resolve tick finishes.
    for info in _panels.values():
        var node := info["panel"] as Node
        if node != null and is_instance_valid(node) and node.has_method("_set_coordinator_active"):
            node.call("_set_coordinator_active", false)

func _propagate_visibility(node: Node, value: bool) -> void:
    if node == null or not is_instance_valid(node): return
    if node is Control:
        node.visible = value
    for child in node.get_children():
        _propagate_visibility(child, value)

func _get_dock_rect() -> Rect2:
    var hud := get_node_or_null("/root/Renew/UI/MainHUD") as CanvasLayer
    if hud == null:
        hud = get_tree().root.get_node_or_null("Renew/UI/MainHUD")
    if hud == null: return Rect2()
    var root_ctrl := hud.get("root") as Control
    if root_ctrl == null: return Rect2()
    var dock := hud.get("action_dock") as Control
    if dock == null: return Rect2()
    var global_rect: Rect2 = dock.get_global_rect()
    if global_rect == Rect2(): return Rect2()
    var vp: Rect2 = get_viewport().get_visible_rect()
    if vp.size.x <= 0.0 or vp.size.y <= 0.0: return Rect2()
    # Clamp dock rect to viewport bounds manually (Godot 4 has no Rect2.clip).
    var clamped := global_rect
    if clamped.position.x < vp.position.x:
        clamped.position.x = vp.position.x
    if clamped.position.y < vp.position.y:
        clamped.position.y = vp.position.y
    var vp_right := vp.position.x + vp.size.x
    var vp_bottom := vp.position.y + vp.size.y
    if clamped.position.x + clamped.size.x > vp_right:
        clamped.size.x = vp_right - clamped.position.x
    if clamped.position.y + clamped.size.y > vp_bottom:
        clamped.size.y = vp_bottom - clamped.position.y
    return clamped
