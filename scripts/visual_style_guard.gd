extends Node

## RENEW visual-style guard.
## Keeps the premium authored presentation active and prevents legacy/default
## presentation paths from resurfacing when UI nodes are created dynamically.

const PREMIUM_THEME_PATH := "res://Assets/Themes/EmpireTheme.tres"
const LEGACY_WORLD_PATH := "/root/Renew/World/WorldView"
const PREMIUM_INDUSTRIAL_PATH := "/root/Renew/World/PremiumIndustrialScene"
const PREMIUM_RESTORATION_PATH := "/root/Renew/World/PremiumRestorationScene"
const BANKRUPTCY_PATH := "/root/Renew/Systems/BankruptcySystem"

var _premium_theme: Theme
var _refresh_queued := false

func _ready() -> void:
    _premium_theme = load(PREMIUM_THEME_PATH) as Theme
    if not get_tree().node_added.is_connected(_on_node_added):
        get_tree().node_added.connect(_on_node_added)
    if not get_tree().tree_changed.is_connected(_queue_refresh):
        get_tree().tree_changed.connect(_queue_refresh)
    call_deferred("_enforce_premium_presentation")

func _process(_delta: float) -> void:
    _sync_distress_overlay()

func _on_node_added(node: Node) -> void:
    if node is Control:
        var control := node as Control
        if _premium_theme != null:
            control.theme = _premium_theme
        _normalize_mobile_shell_background(control)
    _queue_refresh()

func _normalize_mobile_shell_background(control: Control) -> void:
    var parent := control.get_parent()
    if parent == null or parent.name != "MobileGameShell":
        return
    if not (control is TextureRect or control is ColorRect):
        return
    var uses_stretch_anchors := not is_equal_approx(control.anchor_left, control.anchor_right) or not is_equal_approx(control.anchor_top, control.anchor_bottom)
    if not uses_stretch_anchors:
        return
    control.set_anchor(SIDE_LEFT, 0.0, true)
    control.set_anchor(SIDE_TOP, 0.0, true)
    control.set_anchor(SIDE_RIGHT, 0.0, true)
    control.set_anchor(SIDE_BOTTOM, 0.0, true)

func _queue_refresh() -> void:
    if _refresh_queued:
        return
    _refresh_queued = true
    call_deferred("_run_refresh")

func _run_refresh() -> void:
    _refresh_queued = false
    _enforce_premium_presentation()

func _enforce_premium_presentation() -> void:
    _disable_legacy_world_renderer()
    _enable_premium_art()
    _sync_distress_overlay()
    _theme_active_ui()

func _disable_legacy_world_renderer() -> void:
    var legacy := get_node_or_null(LEGACY_WORLD_PATH) as Node2D
    if legacy == null:
        return
    legacy.visible = false
    legacy.process_mode = Node.PROCESS_MODE_DISABLED
    legacy.set_process(false)
    legacy.set_physics_process(false)

func _enable_premium_art() -> void:
    var industrial := get_node_or_null(PREMIUM_INDUSTRIAL_PATH) as Sprite2D
    if industrial != null:
        industrial.visible = true
        industrial.z_index = -28
    var restoration := get_node_or_null(PREMIUM_RESTORATION_PATH) as Sprite2D
    if restoration != null:
        restoration.visible = true
        restoration.z_index = -27

func _sync_distress_overlay() -> void:
    var bankruptcy := get_node_or_null(BANKRUPTCY_PATH)
    if bankruptcy == null:
        return
    var controls := bankruptcy.get_node_or_null("BankruptcyControls") as CanvasLayer
    if controls == null:
        return
    var distress_state := str(bankruptcy.get("state"))
    controls.visible = distress_state != "stable"

func _theme_active_ui() -> void:
    if _premium_theme == null:
        return
    var ui := get_node_or_null("/root/Renew/UI")
    if ui == null:
        return
    _apply_theme_recursive(ui)

func _apply_theme_recursive(node: Node) -> void:
    if node is Control:
        (node as Control).theme = _premium_theme
    for child in node.get_children():
        _apply_theme_recursive(child)
