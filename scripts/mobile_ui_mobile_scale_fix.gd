extends Node

## Responsive Web presentation guard.
## Godot's stretch pipeline already maps the CanvasLayer to the browser
## viewport. A second browser-to-design scale makes the phone HUD tiny.
var _last_mobile := false

func _ready() -> void:
    call_deferred("_apply")
    if get_viewport() != null and not get_viewport().size_changed.is_connected(_apply):
        get_viewport().size_changed.connect(_apply)

func _process(_delta: float) -> void:
    if not OS.has_feature("web"):
        return
    var mobile := _is_mobile()
    if mobile != _last_mobile:
        _apply()

func _is_mobile() -> bool:
    var size := get_viewport().get_visible_rect().size
    return size.x < 760.0 or size.y > size.x * 1.15

func _apply() -> void:
    var mobile := _is_mobile()
    var layer := get_parent() as CanvasLayer
    if layer != null:
        layer.scale = Vector2.ONE
    var root := _find_root(layer)
    if root != null:
        root.scale = Vector2.ONE
        root.position = Vector2.ZERO
    _hide_legacy_mobile_layers(mobile)
    _last_mobile = mobile

func _find_root(layer: CanvasLayer) -> Control:
    if layer == null:
        return null
    for child in layer.get_children():
        if child is Control:
            return child as Control
    return null

func _hide_legacy_mobile_layers(mobile: bool) -> void:
    var renew := get_tree().root.get_node_or_null("Renew")
    if renew == null:
        return
    var legacy_paths := [
        "World/MainRenderer", "World/PropertyVisual", "World/WorldView",
        "World/EmpireController", "World/Corporate", "World/WorldMissions",
        "World/RegionController", "World/BranchController", "World/RivalSupplyController"
    ]
    for path in legacy_paths:
        var node := renew.get_node_or_null(path)
        if node is CanvasItem:
            node.visible = not mobile
    var strategy := renew.get_node_or_null("UI/StrategyHUD")
    if strategy is CanvasLayer:
        strategy.visible = not mobile
