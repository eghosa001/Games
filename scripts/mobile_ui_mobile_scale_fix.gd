extends Node

# Mobile-first presentation shell.
# The simulation remains untouched; this node replaces the dense desktop HUD on
# phones with a readable, goal-driven interface and progressively exposes depth.

const BG := Color("071317f2")
const PANEL := Color("0d2229f2")
const PANEL_SOFT := Color("102b33e8")
const BORDER := Color("36545b")
const TEXT := Color("f2f7f5")
const MUTED := Color("9cb2b3")
const ACCENT := Color("d7b86f")
const GOOD := Color("78c69a")

var game: Node
var shell: Control
var header: Panel
var cash_label: Label
var day_label: Label
var rep_label: Label
var title_label: Label
var context_label: Label
var goal_panel: Panel
var goal_title: Label
var goal_body: Label
var progress_label: Label
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
        _refresh()

func _initialize_mobile_ui() -> void:
    game = get_tree().root.get_node_or_null("Renew")
    if game == null:
        return
    _apply_legacy_visibility()
    if _is_mobile_layout():
        _build_shell()
        _layout()
        _refresh()

func _is_mobile_layout() -> bool:
    var size := get_viewport().get_visible_rect().size
    # OS mobile detection fixes high-resolution Android devices incorrectly
    # falling into the desktop layout just because they report >700 pixels.
    return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or size.x < 700.0

func _on_viewport_changed() -> void:
    call_deferred("_apply_after_resize")

func _apply_after_resize() -> void:
    _apply_legacy_visibility()
    if _is_mobile_layout():
        if shell == null:
            _build_shell()
        shell.show()
        _layout()
        _refresh()
    elif shell != null:
        shell.hide()

func _apply_legacy_visibility() -> void:
    var mobile := _is_mobile_layout()
    var hud := get_parent() as CanvasLayer
    if hud != null:
        hud.scale = Vector2.ONE
        for child in hud.get_children():
            if child is Control and child != shell:
                child.visible = not mobile

    var renew := get_tree().root.get_node_or_null("Renew")
    if renew == null:
        return

    # Keep the world itself visible, but suppress overlapping legacy HUD layers.
    var legacy_world_paths := [
        "World/EmpireController", "World/Corporate", "World/WorldMissions",
        "World/RegionController", "World/BranchController", "World/RivalSupplyController"
    ]
    for path in legacy_world_paths:
        var node := renew.get_node_or_null(path)
        if node is CanvasItem:
            node.visible = not mobile

    var hide_layers := [
        "UI/StrategyHUD", "UI/TutorialOverlay", "UI/V1Celebration",
        "UI/TechnologyPanel", "UI/HistoryPanel", "UI/NewsPanel",
        "UI/AlliancePanel", "UI/HeadquartersPanel", "UI/CollectionPanel",
        "UI/LiveOpsPanel", "UI/CustomerSegmentsUI", "UI/RenewDiplomacyUI",
        "UI/InfrastructurePanel", "UI/ContractPanel", "UI/EmployeePanel",
        "UI/DashboardPanel", "UI/FinancePanel", "UI/PortfolioPanel",
        "UI/CorporationsPanel", "UI/RegionsPanel", "UI/WorldOpportunitiesPanel",
        "UI/ProductionControlPanel", "UI/SupplyChainPanel",
        "UI/EmpireExpansionPanel", "UI/EmpireIntelligencePanel", "UI/SaveLoadPanel"
    ]
    for path in hide_layers:
        var layer := renew.get_node_or_null(path)
        if layer is CanvasItem:
            layer.visible = not mobile
        elif layer != null and layer.has_method("hide") and mobile:
            layer.hide()

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

    var dim := ColorRect.new()
    dim.color = Color("02080b4d")
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    shell.add_child(dim)

    header = Panel.new()
    header.add_theme_stylebox_override("panel", _style(BG, BORDER, 14))
    shell.add_child(header)

    title_label = _label("RENEW", 22, TEXT, true)
    context_label = _label("Restore. Operate. Grow.", 13, MUTED)
    cash_label = _label("$0", 16, TEXT, true)
    rep_label = _label("REP 0", 13, MUTED)
    day_label = _label("DAY 1", 13, MUTED)
    header.add_child(title_label)
    header.add_child(context_label)
    header.add_child(cash_label)
    header.add_child(rep_label)
    header.add_child(day_label)

    goal_panel = Panel.new()
    goal_panel.add_theme_stylebox_override("panel", _style(PANEL, ACCENT, 16, 2))
    shell.add_child(goal_panel)
    goal_title = _label("CURRENT GOAL", 13, ACCENT, true)
    goal_body = _label("Inspect the abandoned warehouse.", 19, TEXT, true)
    goal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    progress_label = _label("Your first step toward a working business.", 13, MUTED)
    progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    primary_button = Button.new()
    primary_button.text = "INSPECT PROPERTY"
    primary_button.focus_mode = Control.FOCUS_NONE
    primary_button.pressed.connect(_run_primary_action)
    goal_panel.add_child(goal_title)
    goal_panel.add_child(goal_body)
    goal_panel.add_child(progress_label)
    goal_panel.add_child(primary_button)

    content_panel = Panel.new()
    content_panel.add_theme_stylebox_override("panel", _style(PANEL_SOFT, BORDER, 14))
    shell.add_child(content_panel)
    section_title = _label("HOME", 16, TEXT, true)
    section_body = _label("Your first business starts here.", 13, MUTED)
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
    feedback_panel.add_theme_stylebox_override("panel", _style(BG, BORDER, 12))
    feedback_panel.visible = false
    shell.add_child(feedback_panel)
    feedback_label = _label("", 14, TEXT)
    feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feedback_panel.add_child(feedback_label)

    nav_panel = Panel.new()
    nav_panel.add_theme_stylebox_override("panel", _style(BG, BORDER, 14))
    shell.add_child(nav_panel)
    nav_row = HBoxContainer.new()
    nav_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    nav_panel.add_child(nav_row)

    for i in range(4):
        var b := Button.new()
        b.text = ["HOME", "BUSINESS", "WORLD", "MORE"][i]
        b.focus_mode = Control.FOCUS_NONE
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.pressed.connect(_set_tab.bind(i))
        nav_row.add_child(b)
        nav_buttons.append(b)

func _layout() -> void:
    if shell == null:
        return
    var size := get_viewport().get_visible_rect().size
    if size.x <= 1.0 or size.y <= 1.0:
        return
    _last_size = size
    var portrait := size.y >= size.x
    var ref_size := Vector2(390.0, 780.0) if portrait else Vector2(780.0, 390.0)
    ui_scale = clampf(minf(size.x / ref_size.x, size.y / ref_size.y), 1.0, 3.2)

    var m := 10.0 * ui_scale
    var gap := 8.0 * ui_scale
    var header_h := 70.0 * ui_scale
    var nav_h := 66.0 * ui_scale
    var available_h := size.y - header_h - nav_h - m * 4.0
    var goal_h := clampf((170.0 if portrait else 142.0) * ui_scale, 130.0 * ui_scale, available_h * 0.48)

    header.position = Vector2(m, m)
    header.size = Vector2(size.x - m * 2.0, header_h)
    title_label.position = Vector2(14, 8) * ui_scale
    title_label.size = Vector2(header.size.x * 0.38, 28 * ui_scale)
    context_label.position = Vector2(14, 36) * ui_scale
    context_label.size = Vector2(header.size.x * 0.45, 22 * ui_scale)
    cash_label.position = Vector2(header.size.x - 165 * ui_scale, 8 * ui_scale)
    cash_label.size = Vector2(150 * ui_scale, 26 * ui_scale)
    cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    rep_label.position = Vector2(header.size.x - 165 * ui_scale, 36 * ui_scale)
    rep_label.size = Vector2(75 * ui_scale, 20 * ui_scale)
    rep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    day_label.position = Vector2(header.size.x - 84 * ui_scale, 36 * ui_scale)
    day_label.size = Vector2(69 * ui_scale, 20 * ui_scale)
    day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

    var goal_y := header.position.y + header.size.y + gap
    goal_panel.position = Vector2(m, goal_y)
    goal_panel.size = Vector2(size.x - m * 2.0, goal_h)
    goal_title.position = Vector2(14, 10) * ui_scale
    goal_title.size = Vector2(goal_panel.size.x - 28 * ui_scale, 22 * ui_scale)
    goal_body.position = Vector2(14, 36) * ui_scale
    goal_body.size = Vector2(goal_panel.size.x - 28 * ui_scale, 50 * ui_scale)
    progress_label.position = Vector2(14, 87) * ui_scale
    progress_label.size = Vector2(goal_panel.size.x - 28 * ui_scale, 36 * ui_scale)
    primary_button.position = Vector2(14 * ui_scale, goal_panel.size.y - 54 * ui_scale)
    primary_button.size = Vector2(goal_panel.size.x - 28 * ui_scale, 44 * ui_scale)

    nav_panel.position = Vector2(m, size.y - nav_h - m)
    nav_panel.size = Vector2(size.x - m * 2.0, nav_h)
    nav_row.add_theme_constant_override("separation", int(4 * ui_scale))

    var content_y := goal_panel.position.y + goal_panel.size.y + gap
    content_panel.position = Vector2(m, content_y)
    content_panel.size = Vector2(size.x - m * 2.0, maxf(70 * ui_scale, nav_panel.position.y - content_y - gap))
    section_title.position = Vector2(14, 10) * ui_scale
    section_title.size = Vector2(content_panel.size.x - 28 * ui_scale, 26 * ui_scale)
    section_body.position = Vector2(14, 38) * ui_scale
    section_body.size = Vector2(content_panel.size.x - 28 * ui_scale, 42 * ui_scale)
    action_scroll.position = Vector2(12 * ui_scale, 82 * ui_scale)
    action_scroll.size = Vector2(content_panel.size.x - 24 * ui_scale, maxf(0.0, content_panel.size.y - 92 * ui_scale))
    action_box.custom_minimum_size.x = maxf(0.0, action_scroll.size.x - 10 * ui_scale)
    action_box.add_theme_constant_override("separation", int(8 * ui_scale))

    feedback_panel.position = Vector2(m * 2.0, maxf(m, nav_panel.position.y - 72 * ui_scale))
    feedback_panel.size = Vector2(size.x - m * 4.0, 60 * ui_scale)
    feedback_label.position = Vector2(12, 8) * ui_scale
    feedback_label.size = feedback_panel.size - Vector2(24, 16) * ui_scale

    _apply_scaled_typography()

func _apply_scaled_typography() -> void:
    if shell == null:
        return
    title_label.add_theme_font_size_override("font_size", int(22 * ui_scale))
    context_label.add_theme_font_size_override("font_size", int(13 * ui_scale))
    cash_label.add_theme_font_size_override("font_size", int(16 * ui_scale))
    rep_label.add_theme_font_size_override("font_size", int(13 * ui_scale))
    day_label.add_theme_font_size_override("font_size", int(13 * ui_scale))
    goal_title.add_theme_font_size_override("font_size", int(13 * ui_scale))
    goal_body.add_theme_font_size_override("font_size", int(19 * ui_scale))
    progress_label.add_theme_font_size_override("font_size", int(13 * ui_scale))
    primary_button.add_theme_font_size_override("font_size", int(17 * ui_scale))
    section_title.add_theme_font_size_override("font_size", int(16 * ui_scale))
    section_body.add_theme_font_size_override("font_size", int(13 * ui_scale))
    feedback_label.add_theme_font_size_override("font_size", int(14 * ui_scale))
    for button in nav_buttons:
        button.add_theme_font_size_override("font_size", int(13 * ui_scale))
        button.custom_minimum_size.y = 48 * ui_scale

func _style(bg: Color, border: Color, radius: int, width: int = 1) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(width)
    s.set_corner_radius_all(radius)
    s.content_margin_left = 10
    s.content_margin_right = 10
    s.content_margin_top = 8
    s.content_margin_bottom = 8
    return s

func _label(text: String, size: int, color: Color, bold: bool = false) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    if bold:
        l.add_theme_color_override("font_shadow_color", Color("00000066"))
        l.add_theme_constant_override("shadow_offset_x", 1)
        l.add_theme_constant_override("shadow_offset_y", 1)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

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
    context_label.text = _context_text()
    _refresh_goal()
    _refresh_nav()
    _refresh_tab_content()

func _refresh_goal() -> void:
    var inspected := bool(_value("inspected", false))
    var owned := bool(_value("owned", false))
    var restoration := int(_value("restoration", 0))
    var business_open := bool(_value("business_open", false))
    var finished := int(_value("finished_goods", 0))

    if not inspected:
        goal_body.text = "Inspect the abandoned warehouse"
        progress_label.text = "Learn what it will take to bring this property back to life."
        primary_button.text = "INSPECT PROPERTY"
    elif not owned:
        goal_body.text = "Acquire your first property"
        progress_label.text = "The opportunity is understood. Take ownership to begin restoration."
        primary_button.text = "BUY PROPERTY"
    elif restoration < 100 and str(_value("stage", "")) != "Operational":
        goal_body.text = "Restore the warehouse"
        progress_label.text = "%d%% restored • Keep investing until the site is operational." % restoration
        primary_button.text = "RESTORE • %d%%" % restoration
    elif not business_open:
        goal_body.text = "Open RENEW Goods"
        progress_label.text = "The property is ready. Turn it into a working business."
        primary_button.text = "OPEN BUSINESS"
    elif finished <= 0:
        goal_body.text = "Produce your first goods"
        progress_label.text = "Buy inputs if needed, then turn them into inventory you can sell."
        primary_button.text = "PRODUCE GOODS"
    elif int(_value("day", 1)) <= 1:
        goal_body.text = "Complete your first trading day"
        progress_label.text = "%d finished goods ready • End the day to generate sales and results." % finished
        primary_button.text = "END DAY"
    else:
        goal_body.text = "Grow profitably"
        progress_label.text = "Operate, improve the business, then expand when your cash flow is strong."
        primary_button.text = "END DAY"

func _run_primary_action() -> void:
    if game == null:
        return
    var inspected := bool(_value("inspected", false))
    var owned := bool(_value("owned", false))
    var restoration := int(_value("restoration", 0))
    var business_open := bool(_value("business_open", false))
    var finished := int(_value("finished_goods", 0))

    if not inspected:
        _run_method("inspect_property")
    elif not owned:
        _run_method("acquire_property")
    elif restoration < 100 and str(_value("stage", "")) != "Operational":
        _run_method("restore_property")
    elif not business_open:
        _run_method("open_business")
    elif finished <= 0:
        # Production may require inputs; make the failure actionable rather than
        # forcing the player to hunt through another screen.
        _run_method("produce_goods")
    else:
        _run_method("advance_day")

func _refresh_nav() -> void:
    for i in range(nav_buttons.size()):
        var button := nav_buttons[i]
        var active := i == active_tab
        button.add_theme_color_override("font_color", ACCENT if active else TEXT)
        button.add_theme_color_override("font_hover_color", ACCENT)

func _refresh_tab_content() -> void:
    _clear_actions()
    match active_tab:
        0:
            section_title.text = "YOUR BUSINESS"
            section_body.text = _home_summary()
            _add_action("INSPECT PROPERTY", "inspect_property", not bool(_value("inspected", false)))
            _add_action("RESTORE PROPERTY", "restore_property", bool(_value("owned", false)) and str(_value("stage", "")) != "Operational")
            _add_action("OPEN BUSINESS", "open_business", str(_value("stage", "")) == "Operational" and not bool(_value("business_open", false)))
            _add_action("END DAY", "advance_day", bool(_value("business_open", false)))
        1:
            section_title.text = "BUSINESS"
            if not bool(_value("business_open", false)):
                section_body.text = "Business tools unlock after you restore and open your first property."
                _add_info("Finish the current goal first.")
            else:
                section_body.text = "Produce, sell and improve the operation. Advanced management stays optional."
                _add_action("BUY INPUTS", "buy_inputs")
                _add_action("PRODUCE GOODS", "produce_goods")
                _add_action("HIRE STAFF", "hire_employee")
                _add_action("MARKETING", "marketing_campaign")
                _add_action("CHANGE PRICE", "change_price")
                _add_screen("FINANCE & PORTFOLIO", "FinancePanel")
        2:
            section_title.text = "WORLD"
            if int(_value("day", 1)) <= 1 or not bool(_value("business_open", false)):
                section_body.text = "Expansion unlocks after your first business is operating."
                _add_info("Build a working company before spreading your attention.")
            else:
                section_body.text = "Expand only when the core business is ready."
                _add_screen("PROPERTY MAP", "RegionsPanel")
                _add_screen("REGIONS", "RegionsPanel")
                _add_screen("SUPPLY CHAIN", "SupplyChainPanel")
                _add_screen("EXPANSION", "EmpireExpansionPanel")
                _add_screen("RIVALS & INTELLIGENCE", "EmpireIntelligencePanel")
        3:
            section_title.text = "MORE"
            section_body.text = "Optional management, records and advanced systems."
            _add_screen("DASHBOARD", "DashboardPanel")
            _add_screen("SAVE / LOAD", "SaveLoadPanel")
            _add_screen("NEWS", "NewsPanel")
            _add_screen("HISTORY", "HistoryPanel")
            if int(_value("day", 1)) > 1:
                _add_screen("TECHNOLOGY", "TechnologyPanel")
                _add_screen("ALLIANCES", "AlliancePanel")
                _add_screen("HEADQUARTERS", "HeadquartersPanel")

func _home_summary() -> String:
    var owned_text := "OWNED" if bool(_value("owned", false)) else "AVAILABLE"
    var open_text := "OPEN" if bool(_value("business_open", false)) else "CLOSED"
    return "Warehouse: %s • Restoration: %d%% • Business: %s" % [owned_text, int(_value("restoration", 0)), open_text]

func _context_text() -> String:
    if not bool(_value("owned", false)):
        return "Your first opportunity"
    if str(_value("stage", "")) != "Operational":
        return "Restoring the first property"
    if not bool(_value("business_open", false)):
        return "Ready to open"
    return "RENEW Goods • Operating"

func _clear_actions() -> void:
    if action_box == null:
        return
    for child in action_box.get_children():
        child.queue_free()

func _add_action(text: String, method_name: String, show: bool = true) -> void:
    if not show:
        return
    var button := Button.new()
    button.text = text
    button.focus_mode = Control.FOCUS_NONE
    button.custom_minimum_size = Vector2(0, 50 * ui_scale)
    button.add_theme_font_size_override("font_size", int(16 * ui_scale))
    button.pressed.connect(_run_method.bind(method_name))
    action_box.add_child(button)

func _add_screen(text: String, screen_name: String) -> void:
    var button := Button.new()
    button.text = text
    button.focus_mode = Control.FOCUS_NONE
    button.custom_minimum_size = Vector2(0, 50 * ui_scale)
    button.add_theme_font_size_override("font_size", int(16 * ui_scale))
    button.pressed.connect(_open_screen.bind(screen_name))
    action_box.add_child(button)

func _add_info(text: String) -> void:
    var label := _label(text, int(14 * ui_scale), MUTED)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.custom_minimum_size = Vector2(0, 52 * ui_scale)
    action_box.add_child(label)

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
        _show_feedback("Opened %s." % screen_name.replace("Panel", "").replace("UI", ""))
    else:
        _show_feedback("That screen is not available right now.")

func _show_feedback(text: String) -> void:
    if feedback_panel == null:
        return
    feedback_label.text = text
    feedback_panel.show()
    var tween := create_tween()
    tween.tween_interval(2.8)
    tween.tween_callback(func():
        if is_instance_valid(feedback_panel):
            feedback_panel.hide()
    )

func _value(property_name: String, fallback: Variant) -> Variant:
    if game == null:
        return fallback
    for info in game.get_property_list():
        if str(info.get("name", "")) == property_name:
            return game.get(property_name)
    return fallback

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
