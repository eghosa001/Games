extends Node

# Mobile-first presentation shell for RENEW.
# Phones receive an illustrated, premium, goal-driven interface while the
# simulation and deeper management screens remain unchanged.

const BG := Color("061014")
const BG_SOFT := Color("09191f")
const PANEL := Color("0c2028f4")
const PANEL_SOFT := Color("102a33f2")
const PANEL_HIGH := Color("173740f5")
const BORDER := Color("385a62")
const BORDER_SOFT := Color("24444c")
const TEXT := Color("f5f7f5")
const MUTED := Color("9bb0b1")
const ACCENT := Color("e5bd62")
const ACCENT_BRIGHT := Color("f5d37e")
const GREEN := Color("63c994")
const CYAN := Color("6ac7cf")
const DANGER := Color("e47b72")

const RESTORATION_ART := preload("res://Assets/Art/premium_restoration_site.svg")
const ICON := preload("res://Assets/renew_icon.svg")

var game: Node
var shell: Control
var background_art: TextureRect
var background_tint: ColorRect
var top_glow: ColorRect
var header: Panel
var logo: TextureRect
var title_label: Label
var context_label: Label
var cash_chip: Panel
var cash_label: Label
var rep_chip: Panel
var rep_label: Label
var day_chip: Panel
var day_label: Label
var goal_panel: Panel
var hero_art: TextureRect
var hero_scrim: ColorRect
var goal_title: Label
var goal_body: Label
var progress_label: Label
var restoration_bar: ProgressBar
var primary_button: Button
var content_panel: Panel
var section_title: Label
var section_body: Label
var action_scroll: ScrollContainer
var action_box: VBoxContainer
var nav_panel: Panel
var nav_row: HBoxContainer
var nav_buttons: Array[Button] = []
var feedback_panel: Panel
var feedback_label: Label
var active_tab := 0
var ui_scale := 1.0
var _last_size := Vector2.ZERO
var _refresh_accum := 0.0

func _ready() -> void:
    call_deferred("_initialize_mobile_ui")
    if get_viewport() != null and not get_viewport().size_changed.is_connected(_on_viewport_changed):
        get_viewport().size_changed.connect(_on_viewport_changed)

func _process(delta: float) -> void:
    if not _is_mobile_layout():
        if shell != null:
            shell.hide()
        return
    _refresh_accum += delta
    if _refresh_accum >= 0.25:
        _refresh_accum = 0.0
        _sync_shell_visibility()
        _refresh()

func _initialize_mobile_ui() -> void:
    game = get_tree().root.get_node_or_null("Renew")
    if game == null:
        return
    _apply_legacy_visibility()
    if _is_mobile_layout():
        _build_shell()
        _layout()
        _sync_shell_visibility()
        _refresh()

func _is_mobile_layout() -> bool:
    var size := get_viewport().get_visible_rect().size
    return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or size.x < 700.0

func _on_viewport_changed() -> void:
    call_deferred("_apply_after_resize")

func _apply_after_resize() -> void:
    _apply_legacy_visibility()
    if _is_mobile_layout():
        if shell == null:
            _build_shell()
        _layout()
        _sync_shell_visibility()
        _refresh()
    elif shell != null:
        shell.hide()

func _sync_shell_visibility() -> void:
    if shell == null:
        return
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    var focused := ""
    if manager != null and manager.has_method("get_active_screen_name"):
        focused = str(manager.get_active_screen_name())
    shell.visible = _is_mobile_layout() and focused.is_empty()

func _apply_legacy_visibility() -> void:
    var mobile := _is_mobile_layout()
    var hud := get_parent() as CanvasLayer
    if hud != null:
        hud.scale = Vector2.ONE

    var renew := get_tree().root.get_node_or_null("Renew")
    if renew == null:
        return

    # The persistent HUD command grid and the managed screens own their
    # responsive layouts and stay visible on phones; only the legacy
    # full-screen world layers yield to the mobile shell.
    var legacy_world_paths := [
        "World/EmpireController", "World/Corporate", "World/WorldMissions",
        "World/RegionController", "World/BranchController", "World/RivalSupplyController"
    ]
    for path in legacy_world_paths:
        var node := renew.get_node_or_null(path)
        if node is CanvasItem:
            node.visible = not mobile

func _build_shell() -> void:
    if shell != null:
        return
    var hud := get_parent() as CanvasLayer
    if hud == null:
        return

    shell = Control.new()
    shell.name = "MobileGameShell"
    shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shell.mouse_filter = Control.MOUSE_FILTER_PASS
    hud.add_child(shell)

    background_art = TextureRect.new()
    background_art.texture = RESTORATION_ART
    background_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background_art.modulate = Color(0.72, 0.82, 0.80, 0.34)
    background_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shell.add_child(background_art)

    background_tint = ColorRect.new()
    background_tint.color = Color("031014c9")
    background_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shell.add_child(background_tint)

    top_glow = ColorRect.new()
    top_glow.color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.045)
    top_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shell.add_child(top_glow)

    header = Panel.new()
    header.add_theme_stylebox_override("panel", _panel_style(Color("081a20ed"), BORDER_SOFT, 18, 1, 10))
    shell.add_child(header)

    logo = TextureRect.new()
    logo.texture = ICON
    logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    header.add_child(logo)

    title_label = _label("RENEW", 22, TEXT, true)
    context_label = _label("RESTORE  •  BUILD  •  EXPAND", 11, MUTED)
    header.add_child(title_label)
    header.add_child(context_label)

    cash_chip = _metric_chip(header)
    cash_label = _label("$0", 15, ACCENT_BRIGHT, true)
    cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cash_chip.add_child(cash_label)

    rep_chip = _metric_chip(header)
    rep_label = _label("REP 0", 12, TEXT, true)
    rep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    rep_chip.add_child(rep_label)

    day_chip = _metric_chip(header)
    day_label = _label("DAY 1", 12, TEXT, true)
    day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    day_chip.add_child(day_label)

    goal_panel = Panel.new()
    goal_panel.clip_contents = true
    goal_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, ACCENT, 20, 2, 14))
    shell.add_child(goal_panel)

    hero_art = TextureRect.new()
    hero_art.texture = RESTORATION_ART
    hero_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    hero_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    hero_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hero_art.modulate = Color(1, 1, 1, 0.88)
    goal_panel.add_child(hero_art)

    hero_scrim = ColorRect.new()
    hero_scrim.color = Color("061317a8")
    hero_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    goal_panel.add_child(hero_scrim)

    goal_title = _label("CURRENT OBJECTIVE", 11, ACCENT_BRIGHT, true)
    goal_body = _label("Inspect the abandoned warehouse", 21, TEXT, true)
    goal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    progress_label = _label("Turn a neglected asset into your first operating company.", 13, Color("d1dddd"))
    progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    goal_panel.add_child(goal_title)
    goal_panel.add_child(goal_body)
    goal_panel.add_child(progress_label)

    restoration_bar = ProgressBar.new()
    restoration_bar.min_value = 0
    restoration_bar.max_value = 100
    restoration_bar.show_percentage = false
    restoration_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    restoration_bar.add_theme_stylebox_override("background", _progress_bg())
    restoration_bar.add_theme_stylebox_override("fill", _progress_fill())
    goal_panel.add_child(restoration_bar)

    primary_button = Button.new()
    primary_button.text = "INSPECT PROPERTY"
    primary_button.focus_mode = Control.FOCUS_NONE
    primary_button.pressed.connect(_run_primary_action)
    _apply_primary_style(primary_button)
    goal_panel.add_child(primary_button)

    content_panel = Panel.new()
    content_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_SOFT, BORDER_SOFT, 18, 1, 8))
    shell.add_child(content_panel)
    section_title = _label("YOUR BUSINESS", 17, TEXT, true)
    section_body = _label("Your first restoration starts here.", 13, MUTED)
    section_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content_panel.add_child(section_title)
    content_panel.add_child(section_body)

    action_scroll = ScrollContainer.new()
    action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    content_panel.add_child(action_scroll)
    action_box = VBoxContainer.new()
    action_scroll.add_child(action_box)

    feedback_panel = Panel.new()
    feedback_panel.add_theme_stylebox_override("panel", _panel_style(Color("0a1b21f8"), ACCENT, 14, 1, 10))
    feedback_panel.visible = false
    feedback_panel.z_index = 50
    shell.add_child(feedback_panel)
    feedback_label = _label("", 14, TEXT, true)
    feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feedback_panel.add_child(feedback_label)

    nav_panel = Panel.new()
    nav_panel.add_theme_stylebox_override("panel", _panel_style(Color("07171df5"), BORDER_SOFT, 18, 1, 9))
    shell.add_child(nav_panel)
    nav_row = HBoxContainer.new()
    nav_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    nav_panel.add_child(nav_row)
    for i in range(4):
        var button := Button.new()
        button.text = ["HOME", "BUSINESS", "WORLD", "MORE"][i]
        button.focus_mode = Control.FOCUS_NONE
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.pressed.connect(_set_tab.bind(i))
        nav_row.add_child(button)
        nav_buttons.append(button)

func _metric_chip(parent: Control) -> Panel:
    var chip := Panel.new()
    chip.add_theme_stylebox_override("panel", _panel_style(Color("10252bd9"), Color("2f4d53"), 11, 1, 0))
    parent.add_child(chip)
    return chip

func _layout() -> void:
    if shell == null:
        return
    var size := get_viewport().get_visible_rect().size
    if size.x <= 1.0 or size.y <= 1.0:
        return
    _last_size = size
    var portrait := size.y >= size.x
    var reference := Vector2(390.0, 780.0) if portrait else Vector2(780.0, 390.0)
    ui_scale = clampf(minf(size.x / reference.x, size.y / reference.y), 1.0, 3.0)

    background_art.size = size
    background_tint.size = size
    top_glow.position = Vector2.ZERO
    top_glow.size = Vector2(size.x, 180.0 * ui_scale)

    var margin := 10.0 * ui_scale
    var gap := 9.0 * ui_scale
    var header_h := 82.0 * ui_scale
    var nav_h := 68.0 * ui_scale
    var available_h := size.y - header_h - nav_h - margin * 4.0
    var goal_h := clampf((224.0 if portrait else 168.0) * ui_scale, 164.0 * ui_scale, available_h * 0.55)

    header.position = Vector2(margin, margin)
    header.size = Vector2(size.x - margin * 2.0, header_h)
    logo.position = Vector2(11, 12) * ui_scale
    logo.size = Vector2(44, 44) * ui_scale
    title_label.position = Vector2(61, 11) * ui_scale
    title_label.size = Vector2(145, 30) * ui_scale
    context_label.position = Vector2(61, 42) * ui_scale
    context_label.size = Vector2(190, 22) * ui_scale

    var chip_y := 9.0 * ui_scale
    var chip_h := 29.0 * ui_scale
    var chip_gap := 5.0 * ui_scale
    var right := header.size.x - 10.0 * ui_scale
    var day_w := 64.0 * ui_scale
    var rep_w := 64.0 * ui_scale
    var cash_w := 86.0 * ui_scale
    day_chip.position = Vector2(right - day_w, chip_y)
    day_chip.size = Vector2(day_w, chip_h)
    rep_chip.position = Vector2(right - day_w - chip_gap - rep_w, chip_y)
    rep_chip.size = Vector2(rep_w, chip_h)
    cash_chip.position = Vector2(right - day_w - rep_w - chip_gap * 2.0 - cash_w, chip_y + chip_h + 5.0 * ui_scale)
    cash_chip.size = Vector2(cash_w + rep_w + day_w + chip_gap * 2.0, 27.0 * ui_scale)
    cash_label.position = Vector2.ZERO
    cash_label.size = cash_chip.size
    rep_label.position = Vector2.ZERO
    rep_label.size = rep_chip.size
    day_label.position = Vector2.ZERO
    day_label.size = day_chip.size

    goal_panel.position = Vector2(margin, header.position.y + header.size.y + gap)
    goal_panel.size = Vector2(size.x - margin * 2.0, goal_h)
    hero_art.position = Vector2.ZERO
    hero_art.size = goal_panel.size
    hero_scrim.position = Vector2.ZERO
    hero_scrim.size = goal_panel.size
    goal_title.position = Vector2(16, 14) * ui_scale
    goal_title.size = Vector2(goal_panel.size.x - 32 * ui_scale, 20 * ui_scale)
    goal_body.position = Vector2(16, 38) * ui_scale
    goal_body.size = Vector2(goal_panel.size.x - 32 * ui_scale, 58 * ui_scale)
    progress_label.position = Vector2(16, 99) * ui_scale
    progress_label.size = Vector2(goal_panel.size.x - 32 * ui_scale, 42 * ui_scale)
    restoration_bar.position = Vector2(16 * ui_scale, goal_panel.size.y - 79 * ui_scale)
    restoration_bar.size = Vector2(goal_panel.size.x - 32 * ui_scale, 8 * ui_scale)
    primary_button.position = Vector2(16 * ui_scale, goal_panel.size.y - 61 * ui_scale)
    primary_button.size = Vector2(goal_panel.size.x - 32 * ui_scale, 48 * ui_scale)

    nav_panel.position = Vector2(margin, size.y - nav_h - margin)
    nav_panel.size = Vector2(size.x - margin * 2.0, nav_h)
    nav_row.add_theme_constant_override("separation", int(5 * ui_scale))

    var content_y := goal_panel.position.y + goal_panel.size.y + gap
    content_panel.position = Vector2(margin, content_y)
    content_panel.size = Vector2(size.x - margin * 2.0, maxf(74 * ui_scale, nav_panel.position.y - content_y - gap))
    section_title.position = Vector2(16, 12) * ui_scale
    section_title.size = Vector2(content_panel.size.x - 32 * ui_scale, 28 * ui_scale)
    section_body.position = Vector2(16, 42) * ui_scale
    section_body.size = Vector2(content_panel.size.x - 32 * ui_scale, 42 * ui_scale)
    action_scroll.position = Vector2(13 * ui_scale, 86 * ui_scale)
    action_scroll.size = Vector2(content_panel.size.x - 26 * ui_scale, maxf(0.0, content_panel.size.y - 98 * ui_scale))
    action_box.custom_minimum_size.x = maxf(0.0, action_scroll.size.x - 10 * ui_scale)
    action_box.add_theme_constant_override("separation", int(9 * ui_scale))

    feedback_panel.position = Vector2(margin * 1.8, maxf(margin, nav_panel.position.y - 78 * ui_scale))
    feedback_panel.size = Vector2(size.x - margin * 3.6, 64 * ui_scale)
    feedback_label.position = Vector2(12, 8) * ui_scale
    feedback_label.size = feedback_panel.size - Vector2(24, 16) * ui_scale
    _apply_scaled_typography()

func _apply_scaled_typography() -> void:
    title_label.add_theme_font_size_override("font_size", int(23 * ui_scale))
    context_label.add_theme_font_size_override("font_size", int(10 * ui_scale))
    cash_label.add_theme_font_size_override("font_size", int(15 * ui_scale))
    rep_label.add_theme_font_size_override("font_size", int(11 * ui_scale))
    day_label.add_theme_font_size_override("font_size", int(11 * ui_scale))
    goal_title.add_theme_font_size_override("font_size", int(11 * ui_scale))
    goal_body.add_theme_font_size_override("font_size", int(21 * ui_scale))
    progress_label.add_theme_font_size_override("font_size", int(13 * ui_scale))
    primary_button.add_theme_font_size_override("font_size", int(16 * ui_scale))
    section_title.add_theme_font_size_override("font_size", int(17 * ui_scale))
    section_body.add_theme_font_size_override("font_size", int(13 * ui_scale))
    feedback_label.add_theme_font_size_override("font_size", int(14 * ui_scale))
    for button in nav_buttons:
        button.add_theme_font_size_override("font_size", int(12 * ui_scale))
        button.custom_minimum_size.y = 48 * ui_scale

func _panel_style(bg: Color, border: Color, radius: int, width: int = 1, shadow: int = 6) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(width)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 10
    style.content_margin_right = 10
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    if shadow > 0:
        style.shadow_color = Color(0, 0, 0, 0.42)
        style.shadow_size = shadow
        style.shadow_offset = Vector2(0, 3)
    return style

func _progress_bg() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color("071216dd")
    style.border_color = Color("456169aa")
    style.set_border_width_all(1)
    style.set_corner_radius_all(5)
    return style

func _progress_fill() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = GREEN
    style.set_corner_radius_all(5)
    return style

func _apply_primary_style(button: Button) -> void:
    var normal := _panel_style(ACCENT, ACCENT_BRIGHT, 13, 1, 8)
    normal.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.20)
    var hover := normal.duplicate()
    hover.bg_color = ACCENT_BRIGHT
    var pressed := normal.duplicate()
    pressed.bg_color = Color("cda64e")
    pressed.shadow_size = 2
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    button.add_theme_color_override("font_color", Color("102027"))
    button.add_theme_color_override("font_hover_color", Color("081014"))
    button.add_theme_color_override("font_pressed_color", Color("081014"))

func _apply_secondary_style(button: Button, selected: bool = false) -> void:
    var accent := ACCENT if selected else BORDER
    var bg := Color("2a2519") if selected else Color("112831e8")
    var normal := _panel_style(bg, accent, 12, 1, 3)
    var hover := normal.duplicate()
    hover.bg_color = Color("183740")
    hover.border_color = ACCENT
    var pressed := hover.duplicate()
    pressed.bg_color = Color("203f46")
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    button.add_theme_color_override("font_color", ACCENT_BRIGHT if selected else TEXT)
    button.add_theme_color_override("font_hover_color", ACCENT_BRIGHT)

func _label(text: String, size: int, color: Color, emphasized: bool = false) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    if emphasized:
        label.add_theme_color_override("font_shadow_color", Color("00000088"))
        label.add_theme_constant_override("shadow_offset_x", 1)
        label.add_theme_constant_override("shadow_offset_y", 2)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

func _set_tab(index: int) -> void:
    active_tab = clampi(index, 0, 3)
    _refresh()

func _refresh() -> void:
    if game == null or shell == null or not _is_mobile_layout():
        return
    if _last_size != get_viewport().get_visible_rect().size:
        _layout()
    cash_label.text = _money(_value("cash", 0))
    rep_label.text = "REP %d" % int(_value("reputation", 0))
    day_label.text = "DAY %d" % int(_value("day", 1))
    context_label.text = _context_text().to_upper()
    restoration_bar.value = clampf(float(_value("restoration", 0)), 0.0, 100.0)
    _refresh_goal()
    _refresh_nav()
    _refresh_tab_content()

func _refresh_goal() -> void:
    var inspected := bool(_value("inspected", false))
    var owned := bool(_value("owned", false))
    var restoration := int(_value("restoration", 0))
    var operational := str(_value("stage", "")) == "Operational" or restoration >= 100
    var business_open := bool(_value("business_open", false))
    var finished := int(_value("finished_goods", 0))
    var purpose := str(_state_value("businesses", "business_purpose", ""))

    if not inspected:
        goal_body.text = "Inspect the abandoned warehouse"
        progress_label.text = "Your first opportunity is waiting. Learn what it needs before spending capital."
        primary_button.text = "INSPECT PROPERTY"
    elif not owned:
        goal_body.text = "Acquire your first property"
        progress_label.text = "Take ownership of the site and turn neglected space into productive capital."
        primary_button.text = "BUY PROPERTY"
    elif not operational:
        goal_body.text = "Restore the warehouse"
        progress_label.text = "%d%% restored  •  Keep rebuilding until the site is operational." % restoration
        primary_button.text = "CONTINUE RESTORATION"
    elif not business_open and purpose.is_empty():
        goal_body.text = "Choose your first business"
        progress_label.text = "The property is ready. Decide what company will begin your empire."
        primary_button.text = "CHOOSE BUSINESS"
    elif not business_open:
        goal_body.text = "Launch your first company"
        progress_label.text = "Your business plan is ready. Put the restored property back to work."
        primary_button.text = "OPEN BUSINESS"
    elif not _has_inputs():
        goal_body.text = "Stock your production floor"
        progress_label.text = "Buy the materials your new operation needs to make its first inventory."
        primary_button.text = "BUY INPUTS"
    elif finished <= 0:
        goal_body.text = "Produce your first goods"
        progress_label.text = "Turn stocked resources into sellable inventory and create real economic value."
        primary_button.text = "PRODUCE GOODS"
    elif int(_value("day", 1)) <= 1:
        goal_body.text = "Complete your first trading day"
        progress_label.text = "%d finished goods ready  •  Close the day to see sales and profit." % finished
        primary_button.text = "END DAY"
    else:
        goal_body.text = "Build a stronger company"
        progress_label.text = "Protect cash flow, improve operations and expand when the business can support it."
        primary_button.text = "END DAY"

func _run_primary_action() -> void:
    var inspected := bool(_value("inspected", false))
    var owned := bool(_value("owned", false))
    var restoration := int(_value("restoration", 0))
    var operational := str(_value("stage", "")) == "Operational" or restoration >= 100
    var business_open := bool(_value("business_open", false))
    var purpose := str(_state_value("businesses", "business_purpose", ""))
    var finished := int(_value("finished_goods", 0))

    if not inspected:
        _run_method("inspect_property")
    elif not owned:
        _run_method("acquire_property")
    elif not operational:
        _run_method("restore_property")
    elif not business_open and purpose.is_empty():
        active_tab = 1
        _refresh()
        _show_feedback("Choose one business type. This decision launches your restored property.")
    elif not business_open:
        _run_method("open_business")
    elif not _has_inputs():
        _run_method("buy_inputs")
    elif finished <= 0:
        _run_method("produce_goods")
    else:
        _run_method("advance_day")

func _refresh_nav() -> void:
    for i in range(nav_buttons.size()):
        _apply_secondary_style(nav_buttons[i], i == active_tab)

func _refresh_tab_content() -> void:
    _clear_actions()
    match active_tab:
        0:
            section_title.text = "YOUR BUSINESS"
            section_body.text = _home_summary()
            if not bool(_value("inspected", false)):
                _add_action("INSPECT PROPERTY", "inspect_property")
            elif not bool(_value("owned", false)):
                _add_action("BUY PROPERTY", "acquire_property")
            elif str(_value("stage", "")) != "Operational":
                _add_action("CONTINUE RESTORATION", "restore_property")
            elif bool(_value("business_open", false)):
                _add_action("END DAY", "advance_day")
        1:
            section_title.text = "BUSINESS OPERATIONS"
            var operational := str(_value("stage", "")) == "Operational" or int(_value("restoration", 0)) >= 100
            if not operational:
                section_body.text = "Business tools unlock after your first property is fully restored."
                _add_info("Complete the restoration objective to unlock your operating company.")
            elif not bool(_value("business_open", false)):
                section_body.text = "Choose the industry that will occupy your restored warehouse."
                _add_purpose_action("FURNITURE FACTORY", 0)
                _add_purpose_action("CONSTRUCTION MATERIALS", 1)
                _add_purpose_action("CONSUMER ELECTRONICS", 2)
            else:
                section_body.text = "Control the operation without losing sight of cash flow."
                _add_action("BUY INPUTS", "buy_inputs")
                _add_action("PRODUCE GOODS", "produce_goods")
                _add_action("HIRE STAFF", "hire_employee")
                _add_action("MARKETING", "marketing_campaign")
                _add_action("CHANGE PRICE", "change_price")
                _add_screen("FINANCE & PORTFOLIO", "FinancePanel")
        2:
            section_title.text = "WORLD & EXPANSION"
            if int(_value("day", 1)) <= 1 or not bool(_value("business_open", false)):
                section_body.text = "Expansion unlocks after your first company survives a trading day."
                _add_info("Build one healthy operation before spreading your attention across the world.")
            else:
                section_body.text = "Grow the empire only when the core company can carry the risk."
                _add_screen("REGIONS", "RegionsPanel")
                _add_screen("SUPPLY CHAIN", "SupplyChainPanel")
                _add_screen("EXPANSION", "EmpireExpansionPanel")
                _add_screen("RIVALS & INTELLIGENCE", "EmpireIntelligencePanel")
        3:
            section_title.text = "COMPANY MENU"
            section_body.text = "Records, saves and optional management systems."
            _add_action("SAVE GAME", "save_game")
            _add_action("LOAD GAME", "load_game")
            _add_screen("DASHBOARD", "DashboardPanel")
            if int(_value("day", 1)) > 1:
                _add_screen("NEWS", "NewsPanel")
                _add_screen("HISTORY", "HistoryPanel")
                _add_screen("TECHNOLOGY", "TechnologyPanel")
                _add_screen("ALLIANCES", "AlliancePanel")

func _home_summary() -> String:
    var owned_text := "OWNED" if bool(_value("owned", false)) else "AVAILABLE"
    var open_text := "OPERATING" if bool(_value("business_open", false)) else "NOT OPEN"
    return "Warehouse  •  %s  •  %d%% restored  •  %s" % [owned_text, int(_value("restoration", 0)), open_text]

func _context_text() -> String:
    if not bool(_value("owned", false)):
        return "First opportunity"
    if str(_value("stage", "")) != "Operational":
        return "Restoration district"
    if not bool(_value("business_open", false)):
        return "Property restored"
    return str(_state_value("businesses", "business_name", "RENEW Goods"))

func _clear_actions() -> void:
    if action_box == null:
        return
    for child in action_box.get_children():
        child.queue_free()

func _add_action(text: String, method_name: String) -> void:
    var button := _action_button(text)
    button.pressed.connect(_run_method.bind(method_name))
    action_box.add_child(button)

func _add_purpose_action(text: String, index: int) -> void:
    var button := _action_button(text)
    button.pressed.connect(_choose_business.bind(index))
    action_box.add_child(button)

func _add_screen(text: String, screen_name: String) -> void:
    var button := _action_button(text)
    button.pressed.connect(_open_screen.bind(screen_name))
    action_box.add_child(button)

func _action_button(text: String) -> Button:
    var button := Button.new()
    button.text = text
    button.focus_mode = Control.FOCUS_NONE
    button.custom_minimum_size = Vector2(0, 54 * ui_scale)
    button.add_theme_font_size_override("font_size", int(15 * ui_scale))
    _apply_secondary_style(button)
    return button

func _add_info(text: String) -> void:
    var panel := Panel.new()
    panel.custom_minimum_size = Vector2(0, 58 * ui_scale)
    panel.add_theme_stylebox_override("panel", _panel_style(Color("0b1d23c8"), BORDER_SOFT, 11, 1, 0))
    var label := _label(text, int(13 * ui_scale), MUTED)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    label.offset_left = 12 * ui_scale
    label.offset_right = -12 * ui_scale
    label.offset_top = 7 * ui_scale
    label.offset_bottom = -7 * ui_scale
    panel.add_child(label)
    action_box.add_child(panel)

func _choose_business(index: int) -> void:
    if game == null or not game.has_method("choose_business_purpose"):
        _show_feedback("Business selection is unavailable.")
        return
    game.choose_business_purpose(index)
    _show_feedback(str(_value("message", "Business selected.")))
    active_tab = 0
    _refresh()

func _run_method(method_name: String) -> void:
    if game == null or not game.has_method(method_name):
        _show_feedback("That action is not available yet.")
        return
    var result = game.call(method_name)
    var message := str(_value("message", ""))
    if result is Dictionary and result.has("message"):
        message = str(result["message"])
    if message.is_empty():
        message = "%s complete." % method_name.replace("_", " ").capitalize()
    _show_feedback(message)
    _refresh()

func _open_screen(screen_name: String) -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("show_screen"):
        manager.show_screen(screen_name)
        _sync_shell_visibility()
    else:
        _show_feedback("That screen is not available right now.")

func _show_feedback(text: String) -> void:
    if feedback_panel == null:
        return
    feedback_label.text = text
    feedback_panel.show()
    feedback_panel.modulate = Color(1, 1, 1, 0)
    var tween := create_tween()
    tween.tween_property(feedback_panel, "modulate", Color.WHITE, 0.16)
    tween.tween_interval(2.7)
    tween.tween_property(feedback_panel, "modulate", Color(1, 1, 1, 0), 0.22)
    tween.tween_callback(func():
        if is_instance_valid(feedback_panel):
            feedback_panel.hide()
            feedback_panel.modulate = Color.WHITE
    )

func _value(property_name: String, fallback: Variant) -> Variant:
    if game == null:
        return fallback
    for info in game.get_property_list():
        if str(info.get("name", "")) == property_name:
            return game.get(property_name)
    return fallback

func _state_value(domain: String, key: String, fallback: Variant) -> Variant:
    var state := get_node_or_null("/root/RenewGameState")
    if state != null and state.has_method("get_value"):
        return state.get_value(domain, key, fallback)
    return fallback

func _has_inputs() -> bool:
    if game == null:
        return false
    var commands = game.get("command_system")
    if commands == null or commands.get("supply_system") == null:
        return false
    var chain = commands.supply_system.get("chain")
    if chain == null or not chain.has_method("stock"):
        return false
    return float(chain.stock("timber")) > 0.0 or float(chain.stock("iron")) > 0.0 or float(chain.stock("energy")) > 0.0

func _money(value: Variant) -> String:
    var amount := int(value)
    var sign := "-" if amount < 0 else ""
    amount = abs(amount)
    if amount >= 1000000000:
        return "%s$%.1fB" % [sign, amount / 1000000000.0]
    if amount >= 1000000:
        return "%s$%.1fM" % [sign, amount / 1000000.0]
    if amount >= 1000:
        return "%s$%.1fK" % [sign, amount / 1000.0]
    return "%s$%d" % [sign, amount]