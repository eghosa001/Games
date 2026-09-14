extends Node

## RESTORA production presentation layer.
## This is intentionally global: legacy and newly-created screens are brought into
## the same authored visual language instead of falling back to stock Godot UI.
## Gameplay state is never owned here.

const DEEP := Color("071116")
const SURFACE := Color("0b1c22")
const SURFACE_RAISED := Color("102b31")
const SURFACE_HOVER := Color("173840")
const EDGE := Color("2b5158")
const EDGE_SOFT := Color("1d363c")
const GOLD := Color("f2c65c")
const GOLD_SOFT := Color("d9ad49")
const TEAL := Color("50d1ae")
const CYAN := Color("58c9e8")
const ORANGE := Color("ff9d62")
const RED := Color("ff6f78")
const PURPLE := Color("b58cff")
const TEXT := Color("f2f8f6")
const MUTED := Color("90a8ac")
const SUBTLE := Color("627b80")
const THEME_PATH := "res://Assets/Themes/EmpireTheme.tres"
const MIN_TOUCH := 44.0

var _theme: Theme
var _refresh_queued := false
var _last_viewport := Vector2.ZERO

func _ready() -> void:
    _theme = load(THEME_PATH) as Theme
    get_tree().node_added.connect(_on_node_added)
    get_viewport().size_changed.connect(_on_viewport_changed)
    call_deferred("_refresh_all")

func _on_node_added(node: Node) -> void:
    if not node is Control:
        return
    if _refresh_queued:
        return
    _refresh_queued = true
    call_deferred("_refresh_all")

func _on_viewport_changed() -> void:
    call_deferred("_refresh_all")

func _refresh_all() -> void:
    _refresh_queued = false
    _last_viewport = get_viewport().get_visible_rect().size
    var ui := get_tree().root.get_node_or_null("Renew/UI")
    if ui == null:
        return
    _walk(ui)

func _walk(node: Node) -> void:
    if node is Control:
        _polish(node as Control)
    for child in node.get_children():
        _walk(child)

func _polish(control: Control) -> void:
    if _theme != null and control.theme == null:
        control.theme = _theme

    if control is Button:
        _button(control as Button)
    elif control is LineEdit:
        _line_edit(control as LineEdit)
    elif control is TextEdit:
        _text_edit(control as TextEdit)
    elif control is OptionButton:
        _option_button(control as OptionButton)
    elif control is SpinBox:
        _spin_box(control as SpinBox)
    elif control is CheckButton:
        _check_button(control as CheckButton)
    elif control is CheckBox:
        _check_box(control as CheckBox)
    elif control is TabBar:
        _tab_bar(control as TabBar)
    elif control is ItemList:
        _item_list(control as ItemList)
    elif control is Tree:
        _tree(control as Tree)
    elif control is ScrollContainer:
        _scroll_container(control as ScrollContainer)
    elif control is PanelContainer:
        _panel_container(control as PanelContainer)
    elif control is PopupPanel:
        _popup_panel(control as PopupPanel)
    elif control is Label:
        _label(control as Label)

func _surface(bg: Color, border: Color, radius: int = 12, shadow: bool = false) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = bg
    box.border_color = border
    box.set_border_width_all(1)
    box.set_corner_radius_all(radius)
    if shadow:
        box.shadow_color = Color(0, 0, 0, 0.38)
        box.shadow_size = 12
        box.shadow_offset = Vector2(0, 4)
    return box

func _button(button: Button) -> void:
    button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, MIN_TOUCH)
    button.clip_text = true
    button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    button.add_theme_font_size_override("font_size", 12)
    button.add_theme_color_override("font_color", TEXT)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", DEEP)
    button.add_theme_color_override("font_disabled_color", SUBTLE)

    var normal := _surface(Color(SURFACE_RAISED, 0.96), Color(EDGE, 0.82), 12)
    normal.content_margin_left = 14
    normal.content_margin_right = 14
    normal.content_margin_top = 8
    normal.content_margin_bottom = 8
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = SURFACE_HOVER
    hover.border_color = Color(GOLD, 0.82)
    hover.shadow_color = Color(GOLD, 0.13)
    hover.shadow_size = 8
    hover.shadow_offset = Vector2(0, 2)
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = GOLD
    pressed.border_color = Color("ffe09a")
    var disabled := normal.duplicate() as StyleBoxFlat
    disabled.bg_color = Color("0a171b")
    disabled.border_color = Color(EDGE_SOFT, 0.5)
    var focus := StyleBoxFlat.new()
    focus.bg_color = Color(0, 0, 0, 0)
    focus.border_color = Color(CYAN, 0.85)
    focus.set_border_width_all(2)
    focus.set_corner_radius_all(13)

    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("disabled", disabled)
    button.add_theme_stylebox_override("focus", focus)
    _wire_button_motion(button)

func _wire_button_motion(button: Button) -> void:
    if button.has_meta("restora_premium_motion"):
        return
    button.set_meta("restora_premium_motion", true)
    button.pivot_offset = button.size * 0.5
    button.mouse_entered.connect(func() -> void:
        if not is_instance_valid(button) or button.disabled:
            return
        button.pivot_offset = button.size * 0.5
        var tween := button.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(button, "scale", Vector2(1.018, 1.018), 0.10)
    )
    button.mouse_exited.connect(func() -> void:
        if not is_instance_valid(button):
            return
        var tween := button.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(button, "scale", Vector2.ONE, 0.12)
    )
    button.button_down.connect(func() -> void:
        if not is_instance_valid(button):
            return
        button.pivot_offset = button.size * 0.5
        var tween := button.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        tween.tween_property(button, "scale", Vector2(0.982, 0.982), 0.06)
    )
    button.button_up.connect(func() -> void:
        if not is_instance_valid(button):
            return
        var tween := button.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tween.tween_property(button, "scale", Vector2.ONE, 0.12)
    )

func _input_box(focused: bool = false) -> StyleBoxFlat:
    var box := _surface(Color("07171d", 0.98), Color(GOLD if focused else EDGE, 0.84), 10)
    box.content_margin_left = 12
    box.content_margin_right = 12
    box.content_margin_top = 9
    box.content_margin_bottom = 9
    if focused:
        box.shadow_color = Color(GOLD, 0.10)
        box.shadow_size = 6
    return box

func _line_edit(line: LineEdit) -> void:
    line.custom_minimum_size.y = maxf(line.custom_minimum_size.y, MIN_TOUCH)
    line.add_theme_stylebox_override("normal", _input_box(false))
    line.add_theme_stylebox_override("focus", _input_box(true))
    line.add_theme_color_override("font_color", TEXT)
    line.add_theme_color_override("font_placeholder_color", MUTED)
    line.add_theme_color_override("caret_color", GOLD)
    line.add_theme_color_override("selection_color", Color(GOLD, 0.24))

func _text_edit(edit: TextEdit) -> void:
    edit.add_theme_stylebox_override("normal", _input_box(false))
    edit.add_theme_stylebox_override("focus", _input_box(true))
    edit.add_theme_color_override("font_color", TEXT)
    edit.add_theme_color_override("caret_color", GOLD)
    edit.add_theme_color_override("selection_color", Color(GOLD, 0.24))

func _option_button(option: OptionButton) -> void:
    option.custom_minimum_size.y = maxf(option.custom_minimum_size.y, MIN_TOUCH)
    _button(option)

func _spin_box(spin: SpinBox) -> void:
    spin.custom_minimum_size.y = maxf(spin.custom_minimum_size.y, MIN_TOUCH)
    var line := spin.get_line_edit()
    if line != null:
        _line_edit(line)

func _check_button(check: CheckButton) -> void:
    check.custom_minimum_size.y = maxf(check.custom_minimum_size.y, MIN_TOUCH)
    check.add_theme_color_override("font_color", TEXT)
    check.add_theme_color_override("font_hover_color", Color.WHITE)

func _check_box(check: CheckBox) -> void:
    check.custom_minimum_size.y = maxf(check.custom_minimum_size.y, MIN_TOUCH)
    check.add_theme_color_override("font_color", TEXT)
    check.add_theme_color_override("font_hover_color", Color.WHITE)

func _tab_bar(tabs: TabBar) -> void:
    tabs.custom_minimum_size.y = maxf(tabs.custom_minimum_size.y, MIN_TOUCH)
    tabs.add_theme_color_override("font_unselected_color", MUTED)
    tabs.add_theme_color_override("font_hovered_color", TEXT)
    tabs.add_theme_color_override("font_selected_color", GOLD)
    tabs.add_theme_stylebox_override("tab_unselected", _surface(Color(SURFACE, 0.72), Color(EDGE_SOFT, 0.65), 9))
    tabs.add_theme_stylebox_override("tab_hovered", _surface(Color(SURFACE_HOVER, 0.90), Color(EDGE, 0.86), 9))
    var selected := _surface(Color(GOLD, 0.10), Color(GOLD, 0.76), 9)
    selected.set_border_width(SIDE_BOTTOM, 2)
    tabs.add_theme_stylebox_override("tab_selected", selected)

func _item_list(items: ItemList) -> void:
    items.add_theme_stylebox_override("panel", _surface(Color(SURFACE, 0.88), Color(EDGE_SOFT, 0.75), 12))
    items.add_theme_stylebox_override("selected", _surface(Color(TEAL, 0.12), Color(TEAL, 0.70), 8))
    items.add_theme_stylebox_override("selected_focus", _surface(Color(TEAL, 0.16), Color(GOLD, 0.70), 8))
    items.add_theme_color_override("font_color", TEXT)
    items.add_theme_color_override("font_selected_color", Color.WHITE)

func _tree(tree: Tree) -> void:
    tree.add_theme_stylebox_override("panel", _surface(Color(SURFACE, 0.88), Color(EDGE_SOFT, 0.75), 12))
    tree.add_theme_stylebox_override("selected", _surface(Color(CYAN, 0.10), Color(CYAN, 0.60), 7))
    tree.add_theme_stylebox_override("selected_focus", _surface(Color(CYAN, 0.15), Color(GOLD, 0.65), 7))
    tree.add_theme_color_override("font_color", TEXT)
    tree.add_theme_color_override("font_selected_color", Color.WHITE)
    tree.add_theme_color_override("guide_color", Color(EDGE, 0.34))

func _scroll_container(scroll: ScrollContainer) -> void:
    var vbar := scroll.get_v_scroll_bar()
    var hbar := scroll.get_h_scroll_bar()
    if vbar != null:
        _scrollbar(vbar)
    if hbar != null:
        _scrollbar(hbar)

func _scrollbar(bar: ScrollBar) -> void:
    var track := StyleBoxFlat.new()
    track.bg_color = Color(DEEP, 0.52)
    track.set_corner_radius_all(5)
    var grabber := StyleBoxFlat.new()
    grabber.bg_color = Color(EDGE, 0.90)
    grabber.set_corner_radius_all(5)
    var hover := grabber.duplicate() as StyleBoxFlat
    hover.bg_color = Color(GOLD_SOFT, 0.84)
    bar.add_theme_stylebox_override("scroll", track)
    bar.add_theme_stylebox_override("grabber", grabber)
    bar.add_theme_stylebox_override("grabber_highlight", hover)
    bar.add_theme_stylebox_override("grabber_pressed", hover)

func _panel_container(panel: PanelContainer) -> void:
    if panel.has_theme_stylebox_override("panel"):
        return
    panel.add_theme_stylebox_override("panel", _surface(Color(SURFACE, 0.93), Color(EDGE, 0.56), 14, true))

func _popup_panel(popup: PopupPanel) -> void:
    popup.add_theme_stylebox_override("panel", _surface(Color(DEEP, 0.985), Color(GOLD, 0.48), 14, true))

func _label(label: Label) -> void:
    var key := (label.name + " " + label.text).to_lower()
    label.add_theme_color_override("font_color", TEXT)
    if key.contains("caption") or key.contains("subtitle") or key.contains("hint") or key.contains("meta"):
        label.add_theme_color_override("font_color", MUTED)
    if key.contains("title") or key.contains("header"):
        label.add_theme_font_size_override("font_size", maxi(18, label.get_theme_font_size("font_size")))
    elif key.contains("value") or key.contains("metric") or key.contains("amount") or key.contains("total"):
        label.add_theme_color_override("font_color", Color("f5deb0"))
        label.add_theme_font_size_override("font_size", maxi(15, label.get_theme_font_size("font_size")))

    # Remove accidental development-facing language from visual presentation.
    # Do not rewrite legitimate gameplay copy; only obvious implementation labels.
    if OS.is_debug_build():
        return
    var dev_words := ["placeholder", "todo", "debug only", "test button", "dev menu"]
    var lower := label.text.to_lower()
    for word in dev_words:
        if lower.contains(word):
            label.visible = false
            break
