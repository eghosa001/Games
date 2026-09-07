extends Node
## Central UI region coordinator. Prevents floating CanvasLayer panels from
## overlapping each other or the primary command surface (action dock).
## Each floater registers its rectangle; the coordinator suppresses any that
## would intersect reserved regions or other higher-priority floaters.
var _panel_names: Array[String] = []   # ordered list of registered panel names
var _panel_priorities: Dictionary = {}  # name -> priority (int)
var _last_screen: String = ""

func _ready() -> void:
    pass

func register_panel(name: String, priority: int) -> void:
    if not _panel_names.has(name):
        _panel_names.append(name)
    _panel_priorities[name] = priority

func unregister_panel(name: String) -> void:
    if _panel_names.has(name):
        _panel_names.erase(name)
    _panel_priorities.erase(name)

func _find_panel(name: String) -> Node:
    if name == "" or name == null: return null
    # Try common locations where panels might live.
    var candidates := [
        get_node_or_null("Renew/UI/" + name),
        get_node_or_null("UI/" + name),
        get_node_or_null("Renew/" + name),
        get_tree().root.get_node_or_null("Renew/UI/" + name),
        get_tree().root.get_node_or_null("UI/" + name),
        get_tree().root.get_node_or_null("Renew/" + name),
    ]
    for c in candidates:
        if c != null and is_instance_valid(c): return c
    return null

func set_active_screen(screen_name: String) -> void:
    _last_screen = screen_name
    _resolve()

func is_any_floating_panel_being_managed() -> bool:
    return _last_screen != ""

func get_active_screen() -> String:
    return _last_screen

func get_all_registered() -> Array[String]:
    return _panel_names.duplicate()

func get_panel_rect(panel_name: String) -> Rect2:
    var node := _find_panel(panel_name)
    if node == null: return Rect2()
    if node.has_method("_get_rect"):
        var r := node.call("_get_rect")
        if r is Rect2: return r
    return Rect2()

func rect_intersects_dock(rect: Rect2, dock_rect: Rect2) -> bool:
    return rect.intersects(dock_rect)

func is_any_floating_panel_visible() -> bool:
    for name in _panel_names:
        var node := _find_panel(name)
        if node != null and node.visible and node.is_visible_in_tree():
            return true
    return false

func _resolve() -> void:
    if _panel_names.is_empty(): return
    # Lock panels so their _process() does not fight our visibility decisions.
    for name in _panel_names:
        var node := _find_panel(name)
        if node == null: continue
        if node.has_method("_set_coordinator_active"):
            node.call("_set_coordinator_active", true)
    var dock_rect := _get_dock_rect()
    var screen_open := _last_screen != ""
    var sorted_keys: Array = _panel_names.duplicate()
    sorted_keys.sort_custom(func(a: String, b: String) -> int:
        var pa := _panel_priorities.get(a, 999) as int
        var pb := _panel_priorities.get(b, 999) as int
        return pa - pb
    )
    var occupied: Array[Rect2] = []
    for name in sorted_keys:
        var panel_node := _find_panel(name)
        if panel_node == null: continue
        # Ensure layout is current before checking overlap.
        if panel_node.has_method("_layout_responsive"):
            panel_node.call("_layout_responsive")
        var r: Variant = panel_node.call("_get_rect")
        var rect: Rect2 = Rect2() if r == null else (r as Rect2)
        if rect == Rect2(): continue
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
    for name in _panel_names:
        var node := _find_panel(name)
        if node == null: continue
        if node.has_method("_set_coordinator_active"):
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
