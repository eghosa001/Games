extends CanvasLayer

# RESTORA layered management shell.
# The simulation stays in domain systems; this HUD exposes only the player's
# current decision layer and routes deeper management into focused screens.

var parent: Node
var active_tab := 0
var root: Control
var background: ColorRect
var shell: MarginContainer
var page: VBoxContainer
var brand: Label
var location_label: Label
var theme_button: Button
var hero_card: PanelContainer
var hero_value: Label
var hero_caption: Label
var hero_meta: Label
var hero_goal: Label
var hero_action: Button
var hero_art: TextureRect
var alerts_button: Button
var hero_progress: ProgressBar
var hero_progress_label: Label
var stat_grid: GridContainer
var stat_cards: Array[PanelContainer] = []
var stat_names: Array[Label] = []
var stat_values: Array[Label] = []
var section_title: Label
var section_caption: Label
var action_scroll: ScrollContainer
var action_list: VBoxContainer
var action_dock: PanelContainer
var action_grid: GridContainer
var actions: GridContainer
var bottom_nav: HBoxContainer
var mode_rail: HBoxContainer
var mode_buttons: Array[Button] = []
var status_label: Label
var feedback_label: Label
var feedback_timer := 0.0
var light_theme := false
var _refresh_accumulator := 0.0
var _transition_serial := 0

const LIGHT_BG := Color("e8e2d8")
const LIGHT_SURFACE := Color("f6f1e8")
const LIGHT_CARD := Color("ddd4c6")
const LIGHT_CARD_2 := Color("eee8de")
const LIGHT_TEXT := Color("292a28")
const LIGHT_MUTED := Color("71685d")
const LIGHT_BORDER := Color("b7aa98")
const LIGHT_ACCENT := Color("66374f")
const LIGHT_GOLD := Color("98672a")
const DARK_BG := Color("0b0d10")
const DARK_SURFACE := Color("151a1f")
const DARK_CARD := Color("20262c")
const DARK_CARD_2 := Color("292f35")
const DARK_TEXT := Color("f2efe8")
const DARK_MUTED := Color("928a80")
const DARK_BORDER := Color("3c3831")
const DARK_ACCENT := Color("7a405f")
const DARK_GOLD := Color("c99a4b")
const WARN := Color("c28a3a")
const ICON_ROOT := "res://Assets/Art/Icons/"
const ACTION_ICON_MAP := {
    "HOME": "home",
    "BUSINESS": "business",
    "EMPIRE": "empire",
    "WORLD": "world",
    "COMPANY OVERVIEW": "business",
    "PROPERTIES": "property",
    "ACTIVE COMPANY": "business",
    "SAVE & SETTINGS": "settings",
    "OPERATIONS": "business",
    "PRODUCTION & EQUIPMENT": "production",
    "PEOPLE & DEMAND": "people",
    "MARKET & CUSTOMERS": "market",
    "FINANCE & CONTRACTS": "finance",
    "PORTFOLIO & PROJECTS": "property",
    "EXPANSION": "empire",
    "HQ & TECHNOLOGY": "empire",
    "COMPETITION": "intelligence",
    "REGIONS": "world",
    "SUPPLY NETWORK": "supply",
    "OPPORTUNITIES": "opportunities",
    "INTELLIGENCE": "intelligence",
    "MARKET INTELLIGENCE": "market",
    "DECISIONS": "decisions",
    "ALERTS": "decisions",
}

func _theme_manager():
    return get_node_or_null("/root/RestoraThemeManager")

func _on_global_theme_changed(_mode: String) -> void:
    var manager = _theme_manager()
    if manager != null:
        light_theme = bool(manager.is_light())
    _apply_theme()

func _ready() -> void:
    parent = get_tree().root.get_node_or_null("Renew")
    var manager = _theme_manager()
    if manager != null:
        light_theme = bool(manager.is_light())
        if not manager.theme_changed.is_connected(_on_global_theme_changed):
            manager.theme_changed.connect(_on_global_theme_changed)
    else:
        light_theme = bool(ProjectSettings.get_setting("renew/ui/light_theme", false))
    _build_ui()
    call_deferred("_initialize")

func _initialize() -> void:
    parent = get_tree().root.get_node_or_null("Renew")
    _apply_theme()
    _refresh()
    if not get_viewport().size_changed.is_connected(_layout_responsive):
        get_viewport().size_changed.connect(_layout_responsive)
    _layout_responsive()
    _animate_entry()

func _build_ui() -> void:
    root = Control.new()
    root.name = "RestoraLayeredShell"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(root)

    background = ColorRect.new()
    background.name = "Backdrop"
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(background)

    shell = MarginContainer.new()
    shell.name = "SafeArea"
    shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(shell)

    page = VBoxContainer.new()
    page.name = "LayerStack"
    page.add_theme_constant_override("separation", 10)
    shell.add_child(page)

    var header := HBoxContainer.new()
    header.name = "Header"
    header.add_theme_constant_override("separation", 12)
    page.add_child(header)

    var title_stack := VBoxContainer.new()
    title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_stack.add_theme_constant_override("separation", 0)
    header.add_child(title_stack)
    brand = _label("RESTORA", 26)
    location_label = _label("ACQUIRE • RESTORE • OPERATE • EXPAND", 10)
    title_stack.add_child(brand)
    title_stack.add_child(location_label)

    alerts_button = Button.new()
    alerts_button.name = "DecisionCenter"
    alerts_button.text = "DECISIONS"
    _apply_button_icon(alerts_button, "DECISIONS", 20)
    alerts_button.custom_minimum_size = Vector2(92, 44)
    alerts_button.focus_mode = Control.FOCUS_NONE
    alerts_button.pressed.connect(_open_decision_center)
    _wire_button_motion(alerts_button)
    header.add_child(alerts_button)

    theme_button = Button.new()
    theme_button.name = "ThemeToggle"
    theme_button.text = "LIGHT"
    var settings_icon := _icon_texture("settings")
    if settings_icon != null:
        theme_button.icon = settings_icon
        theme_button.add_theme_constant_override("icon_max_width", 20)
        theme_button.expand_icon = true
    theme_button.custom_minimum_size = Vector2(78, 44)
    theme_button.focus_mode = Control.FOCUS_NONE
    theme_button.pressed.connect(_toggle_theme)
    _wire_button_motion(theme_button)
    header.add_child(theme_button)

    # Home pulse: one strong hero instead of many competing modules.
    hero_card = PanelContainer.new()
    hero_card.name = "CompanyPulse"
    hero_card.custom_minimum_size = Vector2(0, 174)
    page.add_child(hero_card)
    hero_art = TextureRect.new()
    hero_art.name = "PropertyProjectArt"
    hero_art.texture = load("res://Assets/Art/premium_restoration_site.svg")
    hero_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    hero_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    hero_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hero_art.modulate = Color(1, 1, 1, 0.22)
    hero_card.add_child(hero_art)
    var hero_margin := MarginContainer.new()
    for key in ["left", "right"]:
        hero_margin.add_theme_constant_override("margin_" + key, 20)
    hero_margin.add_theme_constant_override("margin_top", 16)
    hero_margin.add_theme_constant_override("margin_bottom", 14)
    hero_card.add_child(hero_margin)
    var hero_stack := VBoxContainer.new()
    hero_stack.add_theme_constant_override("separation", 6)
    hero_margin.add_child(hero_stack)

    var hero_top := HBoxContainer.new()
    hero_top.add_theme_constant_override("separation", 14)
    hero_stack.add_child(hero_top)
    var hero_copy := VBoxContainer.new()
    hero_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hero_copy.add_theme_constant_override("separation", 1)
    hero_top.add_child(hero_copy)
    hero_caption = _label("COMPANY CASH", 10)
    hero_value = _label("$0", 32)
    hero_meta = _label("DAY 1 • STARTING OUT", 11)
    hero_goal = _label("Turn a neglected property into your first profitable company.", 13)
    hero_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hero_copy.add_child(hero_caption)
    hero_copy.add_child(hero_value)
    hero_copy.add_child(hero_meta)
    hero_copy.add_child(hero_goal)

    hero_action = Button.new()
    hero_action.name = "PrimaryNextMove"
    hero_action.text = "NEXT MOVE"
    hero_action.custom_minimum_size = Vector2(160, 54)
    hero_action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    hero_action.focus_mode = Control.FOCUS_NONE
    _wire_button_motion(hero_action)
    hero_top.add_child(hero_action)

    var progress_row := HBoxContainer.new()
    progress_row.add_theme_constant_override("separation", 10)
    hero_stack.add_child(progress_row)
    hero_progress = ProgressBar.new()
    hero_progress.name = "RestorationProgress"
    hero_progress.min_value = 0
    hero_progress.max_value = 100
    hero_progress.show_percentage = false
    hero_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hero_progress.custom_minimum_size.y = 8
    progress_row.add_child(hero_progress)
    hero_progress_label = _label("0% restored", 10)
    progress_row.add_child(hero_progress_label)

    # Four summary signals only. Detailed ledgers live one layer deeper.
    stat_grid = GridContainer.new()
    stat_grid.name = "CompanyPulseMetrics"
    stat_grid.columns = 4
    stat_grid.add_theme_constant_override("h_separation", 8)
    stat_grid.add_theme_constant_override("v_separation", 8)
    page.add_child(stat_grid)
    for i in range(4):
        var card := PanelContainer.new()
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        card.custom_minimum_size = Vector2(0, 68)
        var margin := MarginContainer.new()
        margin.add_theme_constant_override("margin_left", 12)
        margin.add_theme_constant_override("margin_right", 12)
        margin.add_theme_constant_override("margin_top", 8)
        margin.add_theme_constant_override("margin_bottom", 8)
        card.add_child(margin)
        var box := VBoxContainer.new()
        box.add_theme_constant_override("separation", 1)
        margin.add_child(box)
        var name := _label("METRIC", 9)
        var value := _label("—", 16)
        box.add_child(name)
        box.add_child(value)
        stat_grid.add_child(card)
        stat_cards.append(card)
        stat_names.append(name)
        stat_values.append(value)

    var section_row := HBoxContainer.new()
    page.add_child(section_row)
    var section_stack := VBoxContainer.new()
    section_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    section_stack.add_theme_constant_override("separation", 0)
    section_row.add_child(section_stack)
    section_title = _label("Home", 20)
    section_caption = _label("Current objective and the few decisions that matter now.", 11)
    section_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    section_stack.add_child(section_title)
    section_stack.add_child(section_caption)

    action_scroll = ScrollContainer.new()
    action_scroll.name = "DepthScroll"
    action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    page.add_child(action_scroll)

    action_dock = PanelContainer.new()
    action_dock.name = "ActionDock"
    action_dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    action_scroll.add_child(action_dock)
    var action_margin := MarginContainer.new()
    action_margin.add_theme_constant_override("margin_left", 10)
    action_margin.add_theme_constant_override("margin_right", 10)
    action_margin.add_theme_constant_override("margin_top", 10)
    action_margin.add_theme_constant_override("margin_bottom", 10)
    action_dock.add_child(action_margin)
    action_list = VBoxContainer.new()
    action_list.name = "DepthContent"
    action_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    action_list.add_theme_constant_override("separation", 8)
    action_margin.add_child(action_list)
    action_grid = GridContainer.new()
    actions = action_grid
    action_grid.name = "ActionGrid"
    action_grid.columns = 2
    action_grid.add_theme_constant_override("h_separation", 8)
    action_grid.add_theme_constant_override("v_separation", 8)
    action_list.add_child(action_grid)

    status_label = _label("", 10)
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    page.add_child(status_label)
    feedback_label = _label("", 11)
    feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feedback_label.visible = false
    page.add_child(feedback_label)

    bottom_nav = HBoxContainer.new()
    bottom_nav.name = "PrimaryNavigation"
    bottom_nav.add_theme_constant_override("separation", 6)
    page.add_child(bottom_nav)
    mode_rail = bottom_nav
    var names := ["HOME", "BUSINESS", "EMPIRE", "WORLD"]
    var legacy_names := ["LIVE", "BUSINESS", "EMPIRE", "WORLD"]
    for i in range(names.size()):
        var button := Button.new()
        button.name = "Nav_" + legacy_names[i]
        button.text = names[i]
        _apply_button_icon(button, names[i], 20)
        button.custom_minimum_size = Vector2(100, 48)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.focus_mode = Control.FOCUS_NONE
        button.pressed.connect(_set_tab.bind(i))
        _wire_button_motion(button)
        bottom_nav.add_child(button)
        mode_buttons.append(button)

func _icon_texture(icon_key: String) -> Texture2D:
    var normalized := icon_key.strip_edges().to_lower()
    if normalized.is_empty():
        return null
    var path := ICON_ROOT + normalized + ".svg"
    if not ResourceLoader.exists(path):
        return null
    return load(path) as Texture2D

func _icon_for_action(label: String) -> Texture2D:
    var key := str(ACTION_ICON_MAP.get(label.strip_edges().to_upper(), ""))
    return _icon_texture(key)

func _apply_button_icon(button: Button, label: String, max_width: int = 22) -> void:
    if button == null:
        return
    var texture := _icon_for_action(label)
    if texture == null:
        return
    button.icon = texture
    button.add_theme_constant_override("icon_max_width", max_width)
    button.expand_icon = true

func _wire_button_motion(button: Button) -> void:
    if button == null:
        return
    if not button.button_down.is_connected(_button_motion.bind(button, true)):
        button.button_down.connect(_button_motion.bind(button, true))
    if not button.button_up.is_connected(_button_motion.bind(button, false)):
        button.button_up.connect(_button_motion.bind(button, false))

func _button_motion(button: Button, pressed: bool) -> void:
    if button == null or not is_instance_valid(button):
        return
    if bool(ProjectSettings.get_setting("renew/ui/reduce_motion", false)):
        button.scale = Vector2.ONE
        return
    button.pivot_offset = button.size * 0.5
    var target := Vector2(0.972, 0.972) if pressed else Vector2.ONE
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(button, "scale", target, 0.075 if pressed else 0.12)

func _label(text: String, size: int) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

func _transparent(color: Color, alpha: float) -> Color:
    return Color(color.r, color.g, color.b, alpha)

func _card_style(bg: Color, border: Color, radius := 16, width := 1) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(width)
    style.set_corner_radius_all(radius)
    style.shadow_color = Color(0, 0, 0, 0.07 if light_theme else 0.24)
    style.shadow_size = 5
    style.shadow_offset = Vector2(0, 3)
    return style

func _button_style(bg: Color, border: Color, radius := 13) -> StyleBoxFlat:
    var style := _card_style(bg, border, radius, 1)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 10
    style.content_margin_bottom = 10
    return style

func _apply_theme() -> void:
    if root == null: return
    var bg := LIGHT_BG if light_theme else DARK_BG
    var surface := LIGHT_SURFACE if light_theme else DARK_SURFACE
    var card := LIGHT_CARD if light_theme else DARK_CARD
    var card2 := LIGHT_CARD_2 if light_theme else DARK_CARD_2
    var text := LIGHT_TEXT if light_theme else DARK_TEXT
    var muted := LIGHT_MUTED if light_theme else DARK_MUTED
    var border := LIGHT_BORDER if light_theme else DARK_BORDER
    var accent := LIGHT_ACCENT if light_theme else DARK_ACCENT
    var gold := LIGHT_GOLD if light_theme else DARK_GOLD
    background.color = bg
    for label in [brand, hero_value, section_title]: label.add_theme_color_override("font_color", text)
    brand.add_theme_color_override("font_color", gold)
    for label in [location_label, hero_caption, hero_meta, hero_goal, section_caption, status_label, feedback_label, hero_progress_label]:
        label.add_theme_color_override("font_color", muted)
    for value in stat_values: value.add_theme_color_override("font_color", text)
    for name in stat_names: name.add_theme_color_override("font_color", muted)
    hero_card.add_theme_stylebox_override("panel", _card_style(card, _transparent(gold, 0.48), 20, 1))
    action_dock.add_theme_stylebox_override("panel", _card_style(card2, border, 16, 1))
    for stat_card in stat_cards: stat_card.add_theme_stylebox_override("panel", _card_style(card2, border, 13, 1))
    var progress_bg := StyleBoxFlat.new(); progress_bg.bg_color = _transparent(muted, 0.18); progress_bg.set_corner_radius_all(6)
    var progress_fill := StyleBoxFlat.new(); progress_fill.bg_color = accent; progress_fill.set_corner_radius_all(6)
    hero_progress.add_theme_stylebox_override("background", progress_bg)
    hero_progress.add_theme_stylebox_override("fill", progress_fill)
    alerts_button.add_theme_stylebox_override("normal", _button_style(_transparent(gold, 0.10), gold, 12))
    alerts_button.add_theme_stylebox_override("hover", _button_style(_transparent(gold, 0.18), gold, 12))
    alerts_button.add_theme_color_override("font_color", gold)
    theme_button.add_theme_stylebox_override("normal", _button_style(surface, border, 12))
    theme_button.add_theme_stylebox_override("hover", _button_style(_transparent(accent, 0.12), accent, 12))
    theme_button.add_theme_color_override("font_color", text)
    theme_button.text = "DARK" if light_theme else "LIGHT"
    hero_action.add_theme_stylebox_override("normal", _button_style(gold, gold, 13))
    hero_action.add_theme_stylebox_override("hover", _button_style(gold.lightened(0.08), gold, 13))
    hero_action.add_theme_stylebox_override("pressed", _button_style(gold.darkened(0.08), gold, 13))
    hero_action.add_theme_color_override("font_color", bg)
    hero_action.add_theme_color_override("font_hover_color", bg)
    _style_active_tab()
    _restyle_actions()

func _style_active_tab() -> void:
    if mode_buttons.is_empty(): return
    var surface := LIGHT_SURFACE if light_theme else DARK_CARD_2
    var text := LIGHT_TEXT if light_theme else DARK_TEXT
    var muted := LIGHT_MUTED if light_theme else DARK_MUTED
    var border := LIGHT_BORDER if light_theme else DARK_BORDER
    var gold := LIGHT_GOLD if light_theme else DARK_GOLD
    for i in range(mode_buttons.size()):
        var button := mode_buttons[i]
        button.add_theme_color_override("font_hover_color", text)
        if i == active_tab:
            button.add_theme_stylebox_override("normal", _button_style(_transparent(gold, 0.13), gold, 12))
            button.add_theme_color_override("font_color", gold)
        else:
            button.add_theme_stylebox_override("normal", _button_style(surface, border, 12))
            button.add_theme_color_override("font_color", muted)

func _toggle_theme() -> void:
    var manager = _theme_manager()
    if manager != null:
        manager.toggle()
        return
    light_theme = not light_theme
    ProjectSettings.set_setting("renew/ui/light_theme", light_theme)
    _apply_theme()

func _layout_responsive() -> void:
    if shell == null: return
    var size := root.size if root != null and root.size.x > 0.0 else get_viewport().get_visible_rect().size
    var mobile := size.x < 700.0
    var compact := size.x < 980.0
    shell.add_theme_constant_override("margin_left", 10 if mobile else 24)
    shell.add_theme_constant_override("margin_right", 10 if mobile else 24)
    shell.add_theme_constant_override("margin_top", 10 if mobile else 16)
    shell.add_theme_constant_override("margin_bottom", 8 if mobile else 12)
    page.add_theme_constant_override("separation", 7 if mobile else 10)
    brand.add_theme_font_size_override("font_size", 21 if mobile else 26)
    hero_value.add_theme_font_size_override("font_size", 27 if mobile else 32)
    hero_card.custom_minimum_size.y = 132 if size.x < 340.0 else (158 if mobile else 174)
    hero_action.custom_minimum_size = Vector2(112 if mobile else 160, 50)
    hero_action.add_theme_font_size_override("font_size", 10 if mobile else 12)
    stat_grid.columns = 2 if compact else 4
    stat_grid.visible = size.y >= 620.0
    action_grid.columns = 2
    hero_goal.visible = size.x >= 340.0 and size.y >= 600.0
    hero_art.visible = size.x >= 360.0
    location_label.visible = size.x >= 340.0
    theme_button.visible = size.x >= 420.0
    alerts_button.text = "ALERTS" if size.x < 420.0 else "DECISIONS"
    _apply_button_icon(alerts_button, alerts_button.text, 19)
    alerts_button.custom_minimum_size.x = 72 if size.x < 420.0 else 92
    section_caption.visible = size.y >= 640.0
    status_label.visible = not mobile and size.y >= 720.0
    for child in action_grid.get_children():
        if child is Button:
            child.custom_minimum_size = Vector2(118 if size.x < 340.0 else 148, 52 if size.y < 600.0 else 62)
    for button in mode_buttons:
        button.custom_minimum_size = Vector2(0, 46 if mobile else 48)
        button.add_theme_font_size_override("font_size", 9 if mobile else 11)
    _restyle_actions()

func _set_tab(index: int) -> void:
    var next := clampi(index, 0, 3)
    if next == active_tab:
        return
    active_tab = next
    _transition_serial += 1
    _refresh()
    _style_active_tab()
    _animate_layer_change(_transition_serial)

func _clear_actions() -> void:
    if action_grid == null: return
    for child in action_grid.get_children(): child.queue_free()
    # Legacy/final overlays may add group captions directly to action_list.
    for child in action_list.get_children():
        if child != action_grid: child.queue_free()

func _group(title: String, caption := "") -> void:
    # Group labels are deliberately subtle: depth comes from screens, not more cards.
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 0)
    var title_label := _label(title.to_upper(), 9)
    var muted := LIGHT_MUTED if light_theme else DARK_MUTED
    title_label.add_theme_color_override("font_color", muted)
    box.add_child(title_label)
    if caption != "":
        var caption_label := _label(caption, 10)
        caption_label.add_theme_color_override("font_color", muted)
        caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        box.add_child(caption_label)
    action_list.add_child(box)
    action_list.move_child(box, max(0, action_list.get_child_count() - 2))

func _action(text: String, callback: Callable, subtitle := "", emphasis := false) -> void:
    if not callback.is_valid(): return
    var button := Button.new()
    button.name = "Action_" + text.to_snake_case()
    button.text = text + ("\n" + subtitle if subtitle != "" else "")
    _apply_button_icon(button, text, 24)
    button.set_meta("renew_primary_text", text)
    button.set_meta("renew_subtitle", subtitle)
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.custom_minimum_size = Vector2(148, 62)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.focus_mode = Control.FOCUS_NONE
    button.clip_text = true
    button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    button.set_meta("renew_emphasis", emphasis)
    button.pressed.connect(_run_action.bind(callback))
    _wire_button_motion(button)
    action_grid.add_child(button)
    _style_action_button(button)

func _style_action_button(button: Button) -> void:
    var surface := LIGHT_SURFACE if light_theme else DARK_SURFACE
    var text := LIGHT_TEXT if light_theme else DARK_TEXT
    var border := LIGHT_BORDER if light_theme else DARK_BORDER
    var accent := LIGHT_ACCENT if light_theme else DARK_ACCENT
    var gold := LIGHT_GOLD if light_theme else DARK_GOLD
    var emphasis := bool(button.get_meta("renew_emphasis", false))
    var tint := gold if emphasis else accent
    button.add_theme_stylebox_override("normal", _button_style(_transparent(tint, 0.10) if emphasis else surface, tint if emphasis else border, 13))
    button.add_theme_stylebox_override("hover", _button_style(_transparent(tint, 0.15), tint, 13))
    button.add_theme_stylebox_override("pressed", _button_style(_transparent(tint, 0.24), tint, 13))
    button.add_theme_color_override("font_color", gold if emphasis else text)
    button.add_theme_color_override("font_hover_color", text)
    button.add_theme_font_size_override("font_size", 12)

func _restyle_actions() -> void:
    if action_grid == null: return
    for child in action_grid.get_children():
        if child is Button: _style_action_button(child)

func _run_action(callback: Callable) -> void:
    if parent == null or not callback.is_valid(): return
    var result = callback.call()
    if result is Dictionary and result.has("message"): parent.message = str(result["message"])
    if str(parent.message) != "": show_feedback(str(parent.message))
    _refresh()
    _pulse_primary()

func show_feedback(text: String) -> void:
    feedback_label.text = text
    feedback_label.visible = true
    feedback_timer = 4.5
    feedback_label.modulate.a = 0.0
    feedback_label.position.y += 4.0
    var target_y := feedback_label.position.y - 4.0
    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(feedback_label, "modulate:a", 1.0, 0.18)
    tween.tween_property(feedback_label, "position:y", target_y, 0.20)

func _open_decision_center() -> void:
    var desk := get_node_or_null("/root/RenewManagementPolicyUI")
    if desk != null and desk.has_method("_toggle"):
        desk._toggle()

func _open_screen(screen_name: String) -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("show_screen"):
        manager.show_screen(screen_name)

func _screen(text: String, screen_name: String, subtitle := "", emphasis := false) -> void:
    _action(text, Callable(self, "_open_screen").bind(screen_name), subtitle, emphasis)

func _next_rival() -> void:
    if parent != null and parent.rivals != null and not parent.rivals.rivals.is_empty():
        parent.select_rival((int(parent.selected_rival) + 1) % parent.rivals.rivals.size())

func _goal_text() -> String:
    if parent == null: return "Build your restoration empire."
    if not bool(parent.inspected): return "Inspect the abandoned property and reveal its commercial potential."
    if not bool(parent.owned): return "Acquire the property before committing restoration capital."
    if str(parent.stage) != "Operational": return "Complete the next restoration milestone and increase asset value."
    if not bool(parent.business_open): return "Choose what the restored property becomes, then launch the company."
    if int(parent.finished_goods) <= 0: return "Build inventory and establish reliable supply before chasing growth."
    if int(parent.debt) > int(parent.cash): return "Protect liquidity while keeping the operating engine moving."
    return "Grow deliberately: improve margins, people, supply and market reach."

func _primary_move() -> Dictionary:
    if parent == null: return {"label": "NEXT MOVE", "call": Callable()}
    if not bool(parent.inspected): return {"label": "INSPECT", "call": parent.inspect_property}
    if not bool(parent.owned): return {"label": "ACQUIRE", "call": parent.acquire_property}
    if str(parent.stage) != "Operational": return {"label": "RESTORE", "call": parent.restore_property}
    if not bool(parent.business_open): return {"label": "CHOOSE BUSINESS", "call": Callable(self, "_open_business_choices")}
    if int(parent.finished_goods) <= 0: return {"label": "PRODUCE", "call": parent.produce_goods}
    return {"label": "BUSINESS", "call": Callable(self, "_set_tab").bind(1)}

func _bind_primary_move() -> void:
    for connection in hero_action.pressed.get_connections():
        var callable: Callable = connection.get("callable", Callable())
        if callable.is_valid(): hero_action.pressed.disconnect(callable)
    var move := _primary_move()
    hero_action.text = str(move.get("label", "NEXT MOVE"))
    var primary_icon_key := "property"
    match hero_action.text:
        "PRODUCE": primary_icon_key = "production"
        "BUSINESS": primary_icon_key = "business"
        "CHOOSE BUSINESS": primary_icon_key = "market"
        "ACQUIRE": primary_icon_key = "finance"
        "INSPECT": primary_icon_key = "intelligence"
        "RESTORE": primary_icon_key = "property"
    var primary_icon := _icon_texture(primary_icon_key)
    if primary_icon != null:
        hero_action.icon = primary_icon
        hero_action.add_theme_constant_override("icon_max_width", 24)
        hero_action.expand_icon = true
    var callable: Callable = move.get("call", Callable())
    if callable.is_valid(): hero_action.pressed.connect(_run_action.bind(callable))

func _open_business_choices() -> void:
    active_tab = 1
    _refresh()
    _style_active_tab()
    _animate_layer_change(_transition_serial + 1)

func _choose_business(index: int) -> void:
    if parent != null and parent.has_method("choose_business_purpose"):
        parent.choose_business_purpose(index)
        show_feedback(str(parent.message))
        _refresh()

func _set_metric(index: int, title: String, value: String) -> void:
    if index < 0 or index >= stat_values.size(): return
    stat_names[index].text = title
    stat_values[index].text = value

func _money(value: int) -> String:
    var sign := "-" if value < 0 else ""
    return "%s$%s" % [sign, String.num_int64(abs(value))]

func _refresh_metrics() -> void:
    if parent == null: return
    match active_tab:
        0:
            _set_metric(0, "RESTORED", "%d%%" % int(parent.restoration))
            _set_metric(1, "LAST PROFIT", _money(int(parent.last_profit)))
            _set_metric(2, "REPUTATION", str(int(parent.reputation)))
            _set_metric(3, "BUSINESS", "OPEN" if bool(parent.business_open) else str(parent.stage).to_upper())
        1:
            _set_metric(0, "INVENTORY", str(int(parent.finished_goods)))
            _set_metric(1, "STAFF", str(int(parent.employees)))
            _set_metric(2, "PRICE", _money(int(parent.player_price)))
            _set_metric(3, "DEBT", _money(int(parent.debt)))
        2:
            _set_metric(0, "ACQUISITIONS", str(int(parent.acquisition_count)))
            _set_metric(1, "TOTAL PROFIT", _money(int(parent.total_profit)))
            _set_metric(2, "TRANSPORT", "LV %d" % int(parent.transport_level))
            _set_metric(3, "CAPACITY", str(int(parent.transport_capacity)))
        3:
            _set_metric(0, "DISTRICT", str(int(parent.selected_district) + 1))
            _set_metric(1, "CONTRACT", "%dd" % int(parent.contract_days))
            _set_metric(2, "TRANSPORT", "LV %d" % int(parent.transport_level))
            _set_metric(3, "REPUTATION", str(int(parent.reputation)))

func _refresh() -> void:
    if parent == null or action_grid == null: return
    _clear_actions()
    hero_value.text = _money(int(parent.cash))
    hero_goal.text = _goal_text()
    hero_progress.value = clampi(int(parent.restoration), 0, 100)
    hero_progress_label.text = "%d%% restored" % int(parent.restoration)
    hero_meta.text = "DAY %d  •  %s" % [int(parent.day), "OPERATING" if bool(parent.business_open) else str(parent.stage).to_upper()]
    _bind_primary_move()
    _refresh_metrics()

    section_title.text = ["Home", "Business", "Empire", "World"][active_tab]
    section_caption.text = [
        "Current objective, company pulse and the next meaningful move.",
        "Operate the active company. Open a layer only when you need its detail.",
        "Manage assets, strategy and competition at portfolio scale.",
        "Read regions, logistics and external signals before expanding."
    ][active_tab]
    status_label.text = str(parent.message)

    match active_tab:
        0:
            _screen("Company overview", "DashboardPanel", "Health, alerts and performance", true)
            _screen("Properties", "PortfolioPanel", "See owned sites and restoration projects")
            if bool(parent.business_open):
                _screen("Active company", "BusinessOperationsPanel", "Open the touch-first operating company workspace")
            else:
                _action(hero_action.text, _primary_move().get("call", Callable()), "Continue the current objective", true)
            _screen("Save & settings", "SettingsPanel", "Theme, audio, premium, privacy and company controls")
        1:
            if str(parent.stage) == "Operational" and not bool(parent.business_open):
                _group("Choose the company", "One restored site can support different business models. Pick deliberately.")
                var choices: Array = parent.get_business_purposes() if parent.has_method("get_business_purposes") else []
                for i in range(choices.size()):
                    var choice: Dictionary = choices[i]
                    var name := str(choice.get("name", "Business"))
                    var industry_id := str(choice.get("industry_id", ""))
                    var detail := "Tap to launch this business model"
                    if parent.command_system != null and parent.command_system.business_system != null:
                        var industry: Dictionary = parent.command_system.business_system.get_industry(industry_id)
                        if not industry.is_empty():
                            detail = "%d staff • cap %d • cost %s • demand %d" % [int(industry.get("workers", 0)), int(industry.get("capacity", 0)), _money(int(industry.get("operating_cost", 0))), int(industry.get("market_demand", 0))]
                    _action(name, Callable(self, "_choose_business").bind(i), detail, i == 0)
                _screen("Market intelligence", "CustomerSegmentsUI", "Compare demand before you commit")
            else:
                _screen("Operations", "BusinessOperationsPanel", "Buy inputs, produce, price and manage the operating company", true)
                _screen("Production & equipment", "ProductionControlPanel", "Recipes, equipment condition, maintenance and automation")
                _screen("People & demand", "EmployeePanel", "Staffing, assignments and development")
                _screen("Market & customers", "CustomerSegmentsUI", "Demand, segments, pricing and marketing")
                _screen("Finance & contracts", "FinancePanel", "Cash flow, debt and commercial commitments")
        2:
            _screen("Portfolio & projects", "PortfolioPanel", "Properties, projects and asset allocation", true)
            _screen("Expansion", "EmpireExpansionPanel", "Acquire and build the next operating asset")
            _screen("HQ & technology", "HeadquartersPanel", "Management capacity, research and automation")
            _screen("Competition", "CorporationsPanel", "Rivals, ownership moves and alliances")
        3:
            _screen("Regions", "RegionsPanel", "Districts, reputation and expansion conditions", true)
            _screen("Supply network", "SupplyChainPanel", "Suppliers, transport and bottlenecks")
            _screen("Opportunities", "WorldOpportunitiesPanel", "Time-sensitive projects and market openings")
            _screen("Intelligence", "EmpireIntelligencePanel", "Events, rivals and external signals")
    _style_active_tab()
    _restyle_actions()
    _layout_responsive()

func _animate_entry() -> void:
    page.modulate.a = 0.0
    page.position.y += 12.0
    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(page, "modulate:a", 1.0, 0.28)
    tween.tween_property(page, "position:y", page.position.y - 12.0, 0.28)

func _animate_layer_change(serial: int) -> void:
    if action_dock == null: return
    action_dock.modulate.a = 0.0
    action_dock.position.x = 18.0
    action_dock.scale = Vector2(0.992, 0.992)
    action_dock.pivot_offset = action_dock.size * 0.5
    var tween := create_tween().set_parallel(true)
    tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(action_dock, "modulate:a", 1.0, 0.24)
    tween.tween_property(action_dock, "position:x", 0.0, 0.24)
    tween.tween_property(action_dock, "scale", Vector2.ONE, 0.26)

func _pulse_primary() -> void:
    if hero_action == null: return
    hero_action.scale = Vector2.ONE
    hero_action.pivot_offset = hero_action.size * 0.5
    var tween := create_tween()
    tween.tween_property(hero_action, "scale", Vector2(1.035, 1.035), 0.08)
    tween.tween_property(hero_action, "scale", Vector2.ONE, 0.13)

func _process(delta: float) -> void:
    if feedback_timer > 0.0:
        feedback_timer = maxf(0.0, feedback_timer - delta)
        if feedback_timer <= 0.0:
            var tween := create_tween()
            tween.tween_property(feedback_label, "modulate:a", 0.0, 0.15)
            tween.tween_callback(func(): feedback_label.visible = false)
    _refresh_accumulator += delta
    if hero_art != null and hero_art.visible:
        hero_art.modulate.a = 0.20 + 0.025 * sin(Time.get_ticks_msec() / 1100.0)
    if _refresh_accumulator >= 0.5 and parent != null:
        _refresh_accumulator = 0.0
        hero_value.text = _money(int(parent.cash))
        hero_progress.value = clampi(int(parent.restoration), 0, 100)
        hero_progress_label.text = "%d%% restored" % int(parent.restoration)
