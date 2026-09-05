extends "res://scripts/mobile_ui.gd"

# Production presentation layer. Inherits the tested action/state logic and
# replaces only the control surface so simulation APIs remain untouched.
var top_bar: ColorRect
var bottom_bar: ColorRect
var status_panel: Panel
var button_theme: Theme
var tab_normal_style: StyleBoxFlat
var tab_active_style: StyleBoxFlat
var tab_hover_style: StyleBoxFlat
var panel_style: StyleBoxFlat
var accent_line: ColorRect

func _build_ui() -> void:
    root = Control.new()
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)
    top_bar = ColorRect.new()
    top_bar.name = "TopBar"
    top_bar.color = Color("101820")
    top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
    top_bar.position = Vector2(0, 0)
    top_bar.size.y = 64
    top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(top_bar)
    accent_line = ColorRect.new()
    accent_line.color = Color("d5b56b")
    accent_line.position = Vector2(18, 62)
    accent_line.size = Vector2(112, 2)
    accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(accent_line)
    var brand := Label.new()
    brand.text = "RENEW"
    brand.position = Vector2(18, 7)
    brand.size = Vector2(120, 34)
    brand.add_theme_font_size_override("font_size", 22)
    brand.add_theme_color_override("font_color", Color("e6f1ef"))
    brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(brand)
    var subtitle := Label.new()
    subtitle.text = "REBUILD  /  OPERATE  /  EXPAND"
    subtitle.position = Vector2(18, 37)
    subtitle.size = Vector2(240, 20)
    subtitle.add_theme_font_size_override("font_size", 9)
    subtitle.add_theme_color_override("font_color", Color("789096"))
    subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(subtitle)
    tabs = HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 7)
    tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(tabs)
    for i in range(tab_names.size()):
        var button := Button.new()
        button.text = tab_names[i]
        button.focus_mode = Control.FOCUS_NONE
        button.mouse_filter = Control.MOUSE_FILTER_STOP
        button.pressed.connect(_set_tab.bind(i))
        tabs.add_child(button)
    status_panel = Panel.new()
    status_panel.name = "StatusPill"
    status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(status_panel)
    status_label = Label.new()
    status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 12)
    status_label.add_theme_color_override("font_color", Color("cfe0df"))
    status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    status_panel.add_child(status_label)
    action_scroll = ScrollContainer.new()
    action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    action_scroll.focus_mode = Control.FOCUS_NONE
    action_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(action_scroll)
    actions = GridContainer.new()
    actions.add_theme_constant_override("h_separation", 9)
    actions.add_theme_constant_override("v_separation", 8)
    actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
    action_scroll.add_child(actions)
    feedback_panel = Panel.new()
    feedback_panel.name = "FeedbackCard"
    feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    feedback_panel.hide()
    root.add_child(feedback_panel)
    feedback_label = Label.new()
    feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    feedback_label.add_theme_font_size_override("font_size", 14)
    feedback_label.add_theme_color_override("font_color", Color("dce8e8"))
    feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    feedback_panel.add_child(feedback_label)
    goal_label = Label.new()
    goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    goal_label.add_theme_font_size_override("font_size", 13)
    goal_label.add_theme_color_override("font_color", Color("b7cec9"))
    goal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(goal_label)
    bottom_bar = ColorRect.new()
    bottom_bar.color = Color("101820")
    bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(bottom_bar)
    button_theme = _make_button_theme()
    panel_style = _make_panel_style()
    feedback_panel.add_theme_stylebox_override("panel", panel_style)
    status_panel.add_theme_stylebox_override("panel", _make_status_style())
    _layout_responsive()
    _apply_tab_state()

func _make_button_theme() -> Theme:
    var theme := Theme.new()
    theme.default_font_size = 14
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("15252c")
    normal.border_color = Color("34515a")
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(8)
    normal.content_margin_left = 10.0
    normal.content_margin_right = 10.0
    normal.content_margin_top = 7.0
    normal.content_margin_bottom = 7.0
    normal.shadow_color = Color(0, 0, 0, 0.28)
    normal.shadow_size = 4
    var hover := normal.duplicate()
    hover.bg_color = Color("25464a")
    hover.border_color = Color("d5b56b")
    hover.shadow_color = Color(0.18, 0.55, 0.48, 0.22)
    hover.shadow_size = 6
    var pressed := hover.duplicate()
    pressed.bg_color = Color("35645f")
    pressed.border_color = Color("e4c77f")
    var disabled := normal.duplicate()
    disabled.bg_color = Color("10191d")
    disabled.border_color = Color("203137")
    theme.set_stylebox("normal", "Button", normal)
    theme.set_stylebox("hover", "Button", hover)
    theme.set_stylebox("pressed", "Button", pressed)
    theme.set_stylebox("disabled", "Button", disabled)
    theme.set_color("font_color", "Button", Color("d8e5e6"))
    theme.set_color("font_hover_color", "Button", Color("ffffff"))
    theme.set_color("font_pressed_color", "Button", Color("ffffff"))
    theme.set_color("font_disabled_color", "Button", Color("66787d"))
    return theme

func _make_panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("12232b")
    style.border_color = Color("35535b")
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    style.shadow_color = Color(0, 0, 0, 0.34)
    style.shadow_size = 8
    return style

func _make_status_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("15262b")
    style.border_color = Color("31534f")
    style.set_border_width_all(1)
    style.set_corner_radius_all(14)
    return style

func _make_tab_style(active: bool) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("244b4b") if active else Color("12232b")
    style.border_color = Color("d5b56b") if active else Color("2f4b53")
    style.set_border_width_all(1)
    style.set_corner_radius_all(9)
    style.content_margin_top = 5.0
    style.content_margin_bottom = 5.0
    return style

func _apply_tab_state() -> void:
    if tabs == null:
        return
    tab_normal_style = _make_tab_style(false)
    tab_active_style = _make_tab_style(true)
    tab_hover_style = _make_tab_style(false)
    tab_hover_style.bg_color = Color("20383f")
    tab_hover_style.border_color = Color("557d78")
    for i in range(tabs.get_child_count()):
        var child := tabs.get_child(i)
        if child is Button:
            child.theme = button_theme
            child.add_theme_stylebox_override("normal", tab_active_style if i == active_tab else tab_normal_style)
            child.add_theme_stylebox_override("hover", tab_hover_style)
            child.add_theme_stylebox_override("pressed", tab_active_style)
            child.add_theme_color_override("font_color", Color("f1f8f6") if i == active_tab else Color("9bb0b1"))
            child.add_theme_color_override("font_hover_color", Color("ffffff"))

func _set_tab(index: int) -> void:
    super._set_tab(index)
    _apply_tab_state()
    _layout_responsive()

func _refresh() -> void:
    super._refresh()
    call_deferred("_layout_responsive")

func _button(text: String, callback: Callable) -> void:
    var b := Button.new()
    b.text = text
    b.tooltip_text = "Tap to " + text.to_lower()
    b.focus_mode = Control.FOCUS_NONE
    b.mouse_filter = Control.MOUSE_FILTER_STOP
    b.theme = button_theme
    b.pressed.connect(_run_action.bind(text, callback))
    actions.add_child(b)

func _layout_responsive() -> void:
    if root == null or tabs == null or action_scroll == null or actions == null:
        return
    var size: Vector2 = get_viewport().get_visible_rect().size
    var w: float = size.x
    var h: float = size.y
    if w <= 1.0 or h <= 1.0:
        return
    var narrow: bool = w < 700.0
    top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
    top_bar.position = Vector2.ZERO
    top_bar.size.y = 64.0
    bottom_bar.position = Vector2(0, maxf(0.0, h - 150.0))
    bottom_bar.size = Vector2(w, 150.0)
    accent_line.position = Vector2(18, 62)
    if narrow:
        tabs.position = Vector2(8, 8)
        tabs.size = Vector2(w - 16.0, 42.0)
        var tab_width := maxf(44.0, (w - 16.0 - 21.0) / 4.0)
        for child in tabs.get_children():
            if child is Button:
                child.custom_minimum_size = Vector2(tab_width, 40.0)
                child.add_theme_font_size_override("font_size", 10)
        status_panel.position = Vector2(8, 54)
        status_panel.size = Vector2(w - 16.0, 28.0)
        status_label.position = Vector2(8, 2)
        status_label.size = Vector2(w - 32.0, 24.0)
        status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        action_scroll.position = Vector2(8, 88)
        action_scroll.size = Vector2(w - 16.0, minf(190.0, maxf(120.0, h * 0.24)))
        actions.columns = 2
        actions.custom_minimum_size = Vector2(w - 16.0, 0)
        var button_width := maxf(120.0, (w - 16.0 - 9.0) / 2.0)
        for child in actions.get_children():
            if child is Button:
                child.custom_minimum_size = Vector2(button_width, 44.0)
                child.add_theme_font_size_override("font_size", 11)
        feedback_panel.position = Vector2(8, 286)
        feedback_panel.size = Vector2(w - 16.0, 72.0)
        feedback_label.position = Vector2(12, 6)
        feedback_label.size = Vector2(w - 40.0, 60.0)
        goal_label.position = Vector2(8, 366)
        goal_label.size = Vector2(w - 16.0, 52.0)
    else:
        tabs.position = Vector2(270, 10)
        tabs.size = Vector2(minf(700.0, w - 570.0), 44.0)
        var tab_width := maxf(110.0, (tabs.size.x - 21.0) / 4.0)
        for child in tabs.get_children():
            if child is Button:
                child.custom_minimum_size = Vector2(tab_width, 42.0)
        status_panel.position = Vector2(maxf(730.0, w - 420.0), 14)
        status_panel.size = Vector2(minf(270.0, w - status_panel.position.x - 12.0), 30.0)
        status_label.position = Vector2(10, 3)
        status_label.size = Vector2(status_panel.size.x - 20.0, 24.0)
        status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        action_scroll.position = Vector2(18, 76)
        action_scroll.size = Vector2(w - 36.0, 150.0)
        actions.columns = 3
        actions.custom_minimum_size = Vector2(w - 36.0, 0)
        for child in actions.get_children():
            if child is Button:
                child.custom_minimum_size = Vector2(225.0, 48.0)
        feedback_panel.position = Vector2(18, 238)
        feedback_panel.size = Vector2(minf(760.0, w - 36.0), 92.0)
        feedback_label.position = Vector2(18, 10)
        feedback_label.size = Vector2(feedback_panel.size.x - 36.0, 72.0)
        goal_label.position = Vector2(18, 344)
        goal_label.size = Vector2(minf(920.0, w - 36.0), 48.0)
    _apply_tab_state()
