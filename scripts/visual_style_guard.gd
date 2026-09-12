extends Node

## RENEW visual-style guard.
## Keeps the premium authored presentation active and prevents legacy/default
## presentation paths from resurfacing when UI nodes are created dynamically.

const PREMIUM_THEME_PATH := "res://Assets/Themes/EmpireTheme.tres"
const LEGACY_WORLD_PATH := "/root/Renew/World/WorldView"
const PREMIUM_INDUSTRIAL_PATH := "/root/Renew/World/PremiumIndustrialScene"
const PREMIUM_RESTORATION_PATH := "/root/Renew/World/PremiumRestorationScene"

var _premium_theme: Theme
var _refresh_queued := false

func _ready() -> void:
    _premium_theme = load(PREMIUM_THEME_PATH) as Theme
    if not get_tree().node_added.is_connected(_on_node_added):
        get_tree().node_added.connect(_on_node_added)
    if not get_tree().tree_changed.is_connected(_queue_refresh):
        get_tree().tree_changed.connect(_queue_refresh)
    call_deferred("_enforce_premium_presentation")

func _on_node_added(node: Node) -> void:
    if node is Control and _premium_theme != null:
        (node as Control).theme = _premium_theme
    _queue_refresh()

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
