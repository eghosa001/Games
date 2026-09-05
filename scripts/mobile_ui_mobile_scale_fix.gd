extends Node

## Mobile Web presentation hotfix.
## CanvasLayer HUDs are rendered outside the world stretch transform. The
## responsive HUD is authored in browser/CSS pixels, so its CanvasLayer itself
## must be scaled back to the Godot desktop design width on narrow screens.
var _layer: CanvasLayer
var _root: Control
var _last_browser := Vector2.ZERO

func _ready() -> void:
    _layer = get_parent() as CanvasLayer
    call_deferred("_apply")
    if get_viewport() != null and not get_viewport().size_changed.is_connected(_apply):
        get_viewport().size_changed.connect(_apply)

func _process(_delta: float) -> void:
    if not OS.has_feature("web"):
        return
    # Re-apply continuously because mobile_ui_polished.gd also manages the
    # CanvasLayer scale during its responsive layout pass.
    _apply()

func _browser_size() -> Vector2:
    if not OS.has_feature("web"):
        return Vector2.ZERO
    var result = JavaScriptBridge.eval("[Math.round(window.innerWidth), Math.round(window.innerHeight)]")
    if result is Array and result.size() >= 2:
        return Vector2(maxf(1.0, float(result[0])), maxf(1.0, float(result[1])))
    return Vector2.ZERO

func _find_root() -> Control:
    if _layer == null:
        return null
    for child in _layer.get_children():
        if child is Control:
            return child as Control
    return null

func _apply() -> void:
    if _layer == null:
        return
    _root = _find_root()
    var browser := _browser_size()
    if browser.x <= 1.0 or browser.y <= 1.0:
        return

    var mobile := browser.x < 700.0 or browser.y > browser.x * 1.15
    if mobile:
        # The project canvas is 1280px wide. The compact HUD is laid out using
        # browser pixels (for example 390px on a phone), so restore that scale
        # at the CanvasLayer boundary rather than relying on viewport stretch.
        var uniform := maxf(1.0, 1280.0 / browser.x)
        _layer.scale = uniform
        if _root != null:
            _root.scale = Vector2.ONE
            _root.position = Vector2.ZERO
    else:
        _layer.scale = 1.0
        if _root != null:
            _root.scale = Vector2.ONE
            _root.position = Vector2.ZERO

    _hide_legacy_mobile_layers(mobile)
    _last_browser = browser

func _hide_legacy_mobile_layers(mobile: bool) -> void:
    var renew := get_tree().root.get_node_or_null("Renew")
    if renew == null:
        return

    var legacy_paths := [
        "World/MainRenderer",
        "World/PropertyVisual",
        "World/WorldView",
        "World/EmpireController",
        "World/Corporate",
        "World/WorldMissions",
        "World/RegionController",
        "World/BranchController",
        "World/RivalSupplyController"
    ]
    for path in legacy_paths:
        var node := renew.get_node_or_null(path)
        if node is CanvasItem:
            node.visible = not mobile

    var strategy := renew.get_node_or_null("UI/StrategyHUD")
    if strategy is CanvasLayer:
        strategy.visible = not mobile

    var bankruptcy := renew.get_node_or_null("Systems/BankruptcySystem")
    if bankruptcy != null:
        var distress := bankruptcy.get_node_or_null("BankruptcyControls")
        if distress is CanvasLayer and mobile:
            distress.visible = false
