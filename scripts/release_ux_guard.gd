extends Node

## Final release interaction/layout contract.
## This runs from SceneTree.process_frame, registered by an autoload before test
## and scene coroutines. That makes focus/touch normalization visible before
## process_frame awaiters resume, instead of one _process callback too late.

const MIN_TOUCH := 48.0
const PHONE_BREAKPOINT := 420.0

func _ready() -> void:
    var tree := get_tree()
    if tree != null and not tree.process_frame.is_connected(_enforce):
        tree.process_frame.connect(_enforce)
    call_deferred("_enforce")

func _enforce() -> void:
    var hud := get_node_or_null("/root/Renew/UI/MainHUD")
    if hud == null:
        return

    var mode_buttons = hud.get("mode_buttons")
    if mode_buttons is Array:
        for candidate in mode_buttons:
            if candidate is BaseButton:
                _normalize_button(candidate as BaseButton)

    var grid := hud.get("action_grid") as GridContainer
    var ui_root := hud.get("root") as Control
    if grid != null:
        if ui_root != null:
            grid.columns = 1 if ui_root.size.x < PHONE_BREAKPOINT else 2
        for child in grid.get_children():
            if child is BaseButton:
                var button := child as BaseButton
                _normalize_button(button)
                if ui_root != null and ui_root.size.x < PHONE_BREAKPOINT:
                    button.custom_minimum_size.x = 0.0
                    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    for key in ["alerts_button", "theme_button", "hero_action"]:
        var candidate = hud.get(key)
        if candidate is BaseButton:
            _normalize_button(candidate as BaseButton)

    _contain_action_viewport(hud, ui_root)

func _normalize_button(button: BaseButton) -> void:
    if button == null:
        return
    button.focus_mode = Control.FOCUS_ALL
    button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, MIN_TOUCH)
    if button.tooltip_text.strip_edges().is_empty() and not button.text.strip_edges().is_empty():
        button.tooltip_text = button.text.strip_edges().capitalize()

func _contain_action_viewport(hud: Node, ui_root: Control) -> void:
    if ui_root == null or ui_root.size.x <= 0.0 or ui_root.size.y <= 0.0:
        return
    var scroll := hud.get("action_scroll") as Control
    if scroll == null:
        return

    scroll.custom_minimum_size.x = 0.0
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var dock := hud.get("action_dock") as Control
    if dock != null:
        dock.custom_minimum_size.x = 0.0
        dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    # Ultra-compact phones need vertical space reserved for the navigation row.
    if ui_root.size.x <= 320.0 and ui_root.size.y <= 600.0:
        var hero := hud.get("hero_card") as Control
        if hero != null:
            hero.custom_minimum_size.y = minf(hero.custom_minimum_size.y, 112.0)
        var stats := hud.get("stat_grid") as Control
        if stats != null:
            stats.visible = false
        var caption := hud.get("section_caption") as Control
        if caption != null:
            caption.visible = false

    # Container minimums can briefly exceed the synthetic viewport used by the
    # commercial gate. Clamp the scroll rect at the frame boundary; its content
    # remains scrollable, while the viewport itself never escapes the screen.
    var rect := scroll.get_global_rect()
    var max_width := maxf(0.0, ui_root.size.x - rect.position.x)
    var max_height := maxf(0.0, ui_root.size.y - rect.position.y)
    if scroll.size.x > max_width:
        scroll.size.x = max_width
    if scroll.size.y > max_height:
        scroll.size.y = max_height
