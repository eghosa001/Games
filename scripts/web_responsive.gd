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

func _ready() -> void:
    if not OS.has_feature("web"):
        return
    call_deferred("_apply")
    var root := get_tree().root
    if not root.size_changed.is_connected(_on_window_size_changed):
        root.size_changed.connect(_on_window_size_changed)

func _on_window_size_changed() -> void:
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
