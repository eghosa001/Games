extends Node

# Web-only display adapter. Godot's Adaptive canvas makes the canvas fill the
# browser, but the game's 1280x720 design space can still become too small on
# portrait phones. This switches the content design size to the actual browser
# viewport on portrait/tight screens so the UI remains touch-sized and readable.
const DESKTOP_SIZE := Vector2i(1280, 720)
const MIN_MOBILE_WIDTH := 320
const MAX_MOBILE_WIDTH := 900
const MIN_MOBILE_HEIGHT := 568
const MAX_MOBILE_HEIGHT := 1200

var _last_browser_size := Vector2i.ZERO
var _scene_adjusted := false
var _adjust_clock := 0.0

func _ready() -> void:
    if not OS.has_feature("web"):
        return
    call_deferred("_apply")
    var root := get_tree().root
    if not root.size_changed.is_connected(_on_window_size_changed):
        root.size_changed.connect(_on_window_size_changed)

func _process(delta: float) -> void:
    if not OS.has_feature("web"):
        return
    _adjust_clock -= delta
    if _adjust_clock <= 0.0:
        _adjust_clock = 0.25
        _apply_scene_visibility()

func _on_window_size_changed() -> void:
    _scene_adjusted = false
    call_deferred("_apply")

func _browser_size() -> Vector2i:
    if not OS.has_feature("web"):
        return Vector2i.ZERO
    var result = JavaScriptBridge.eval("[Math.round(window.innerWidth), Math.round(window.innerHeight)]")
    if result is Array and result.size() >= 2:
        return Vector2i(maxi(1, int(result[0])), maxi(1, int(result[1])))
    return Vector2i.ZERO

func _apply() -> void:
    var browser := _browser_size()
    if browser == Vector2i.ZERO or browser == _last_browser_size:
        _apply_scene_visibility()
        return
    _last_browser_size = browser

    var root := get_tree().root
    root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL

    var portrait := browser.y > browser.x * 1.15
    var tight_landscape := browser.x < 700
    if portrait or tight_landscape:
        var mobile_size := Vector2i(
            clampi(browser.x, MIN_MOBILE_WIDTH, MAX_MOBILE_WIDTH),
            clampi(browser.y, MIN_MOBILE_HEIGHT, MAX_MOBILE_HEIGHT)
        )
        root.content_scale_size = mobile_size
        root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
    else:
        root.content_scale_size = DESKTOP_SIZE
        root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
    _scene_adjusted = false
    call_deferred("_apply_scene_visibility")

func _apply_scene_visibility() -> void:
    var renew := get_node_or_null("/root/Renew")
    if renew == null:
        return
    var browser := _last_browser_size
    if browser == Vector2i.ZERO:
        browser = _browser_size()
    var mobile := browser.y > browser.x * 1.15 or browser.x < 700

    var infrastructure_ui := get_node_or_null("/root/RenewInfrastructureUI")
    if infrastructure_ui is CanvasItem:
        var hud := renew.get_node_or_null("UI/MainHUD")
        var tab := int(hud.get("active_tab")) if hud != null else 0
        infrastructure_ui.visible = tab == 3

    var region_controller := renew.get_node_or_null("World/RegionController")
    if region_controller is CanvasItem:
        var hud := renew.get_node_or_null("UI/MainHUD")
        var tab := int(hud.get("active_tab")) if hud != null else 0
        region_controller.visible = tab == 3

    if mobile and not _scene_adjusted:
        var warehouse := renew.get_node_or_null("World/WarehouseArt")
        if warehouse is Node2D:
            warehouse.position = Vector2(browser.x * 0.5, minf(520.0, browser.y * 0.58))
            warehouse.scale = Vector2(0.62, 0.62)
        var skyline := renew.get_node_or_null("World/SkylineArt")
        if skyline is Node2D:
            skyline.position = Vector2(browser.x * 0.5, 145.0)
            skyline.scale = Vector2(0.58, 0.58)
        var resource_hub := renew.get_node_or_null("World/ResourceHubArt")
        if resource_hub is CanvasItem:
            resource_hub.visible = false
        _scene_adjusted = true
