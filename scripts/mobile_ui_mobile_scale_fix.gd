extends Node

## Mobile Web presentation hotfix.
## The primary HUD lives on a CanvasLayer, which is not governed by the same
## stretch transform as the world canvas. On narrow Web viewports the HUD must
## explicitly map its CSS-pixel layout back into the 1280x720 logical canvas.
var _layer: CanvasLayer
var _root: Control
var _last_browser := Vector2.ZERO

func _ready() -> void:
    _layer = get_parent() as CanvasLayer
    call_deferred("_apply")
    if get_viewport() != null and not get_viewport().size_changed.is_connected(_apply):
        get_viewport().size_changed.connect(_apply)

func _process(_delta: float) -> void:
    if OS.has_feature("web"):
        var browser := _browser_size()
        if browser != Vector2.ZERO and browser != _last_browser:
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
    _root = _find_root()
    if _root == null:
        return

    var logical := get_viewport().get_visible_rect().size
    var browser := _browser_size()
    if logical.x <= 1.0 or logical.y <= 1.0:
        return

    var mobile := browser.x > 0.0 and (browser.x < 700.0 or browser.y > browser.x * 1.15)
    if mobile and browser.x > 1.0:
        # Existing mobile_ui_polished.gd lays its controls out in CSS-pixel
        # coordinates. Scale that Control back into the logical canvas so a
        # 390px phone gets genuinely touch-sized controls instead of a tiny
        # 1280px desktop HUD squeezed into the phone.
        var sx := logical.x / browser.x
        var sy := logical.y / browser.y if browser.y > 1.0 else sx
        var uniform := maxf(1.0, minf(sx, sy))
        _root.scale = Vector2(uniform, uniform)
        _root.position = Vector2.ZERO
    else:
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

    # These dashboards duplicate information already provided by the responsive
    # MainHUD on phones and otherwise compete for the same limited vertical area.
    var strategy := renew.get_node_or_null("UI/StrategyHUD")
    if strategy is CanvasLayer:
        strategy.visible = not mobile

    var bankruptcy := renew.get_node_or_null("Systems/BankruptcySystem")
    if bankruptcy != null:
        var distress := bankruptcy.get_node_or_null("BankruptcyControls")
        if distress is CanvasLayer and mobile:
            distress.visible = false
