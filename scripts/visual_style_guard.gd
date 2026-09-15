extends Node

## RESTORA visual-style guard.
## Keeps the authored presentation active and prevents legacy/default controls,
## undersized touch targets, inaccessible navigation and tiny dynamically-created
## text from resurfacing.

const PREMIUM_THEME_PATH := "res://Assets/Themes/EmpireTheme.tres"
const LEGACY_WORLD_PATH := "/root/Renew/World/WorldView"
const PREMIUM_INDUSTRIAL_PATH := "/root/Renew/World/PremiumIndustrialScene"
const PREMIUM_RESTORATION_PATH := "/root/Renew/World/PremiumRestorationScene"
const BANKRUPTCY_PATH := "/root/Renew/Systems/BankruptcySystem"
const MIN_TOUCH_TARGET := 48.0
const MIN_BUTTON_FONT := 14
const MIN_BODY_FONT := 14

var _premium_theme: Theme
var _refresh_queued := false
var _distress_refresh := 0.0

func _ready() -> void:
    _premium_theme = load(PREMIUM_THEME_PATH) as Theme
    if not get_tree().node_added.is_connected(_on_node_added):
        get_tree().node_added.connect(_on_node_added)
    if not get_tree().tree_changed.is_connected(_queue_refresh):
        get_tree().tree_changed.connect(_queue_refresh)
    call_deferred("_enforce_premium_presentation")

func _process(delta: float) -> void:
    # Some authored/premium-skin code restyles controls after creation and can
    # overwrite focus/touch defaults. Reassert the accessibility contract every
    # frame so this guard remains the final presentation authority.
    _theme_active_ui()
    _distress_refresh += delta
    if _distress_refresh >= 0.25:
        _distress_refresh = 0.0
        _sync_distress_overlay()

func _on_node_added(node: Node) -> void:
    if node is Control:
        var control := node as Control
        if _premium_theme != null:
            control.theme = _premium_theme
        _normalize_control(control)
        _normalize_mobile_shell_background(control)
        call_deferred("_normalize_if_valid", control)
    _queue_refresh()

func _normalize_if_valid(control: Control) -> void:
    if control == null or not is_instance_valid(control) or control.is_queued_for_deletion():
        return
    if _premium_theme != null:
        control.theme = _premium_theme
    _normalize_control(control)
    _normalize_mobile_shell_background(control)

func _normalize_control(control: Control) -> void:
    if control == null:
        return

    # Every interactive control is finger-safe and remains reachable by
    # keyboard/gamepad focus. This applies to late-created management screens too.
    if control is BaseButton:
        var button := control as BaseButton
        button.custom_minimum_size.x = maxf(button.custom_minimum_size.x, MIN_TOUCH_TARGET)
        button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, MIN_TOUCH_TARGET)
        if button.get_theme_font_size("font_size") < MIN_BUTTON_FONT:
            button.add_theme_font_size_override("font_size", MIN_BUTTON_FONT)
        button.focus_mode = Control.FOCUS_ALL
        if button.tooltip_text.strip_edges().is_empty() and not button.text.strip_edges().is_empty():
            button.tooltip_text = button.text.strip_edges().capitalize()

    if control is Label:
        var label := control as Label
        if label.get_theme_font_size("font_size") < MIN_BODY_FONT:
            label.add_theme_font_size_override("font_size", MIN_BODY_FONT)
    elif control is LineEdit:
        var line_edit := control as LineEdit
        line_edit.custom_minimum_size.y = maxf(line_edit.custom_minimum_size.y, MIN_TOUCH_TARGET)
        line_edit.focus_mode = Control.FOCUS_ALL
        if line_edit.get_theme_font_size("font_size") < MIN_BODY_FONT:
            line_edit.add_theme_font_size_override("font_size", MIN_BODY_FONT)
    elif control is OptionButton:
        var option := control as OptionButton
        option.custom_minimum_size.y = maxf(option.custom_minimum_size.y, MIN_TOUCH_TARGET)
        option.focus_mode = Control.FOCUS_ALL
    elif control is SpinBox:
        control.custom_minimum_size.y = maxf(control.custom_minimum_size.y, MIN_TOUCH_TARGET)
        control.focus_mode = Control.FOCUS_ALL

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
        var control := node as Control
        control.theme = _premium_theme
        _normalize_control(control)
    for child in node.get_children():
        _apply_theme_recursive(child)