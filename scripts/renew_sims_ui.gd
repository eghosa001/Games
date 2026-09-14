extends CanvasLayer

# RENEW management command deck.
# Presentation only: gameplay commands and simulation state remain on Renew/Main.
# The shell keeps high-value information persistent and exposes every major system
# through a small number of context-aware management surfaces.

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
var stat_grid: GridContainer
var stat_cards: Array[PanelContainer] = []
var stat_names: Array[Label] = []
var stat_values: Array[Label] = []
var section_title: Label
var section_caption: Label
var action_scroll: ScrollContainer
var action_list: VBoxContainer
var bottom_nav: HBoxContainer
var mode_buttons: Array[Button] = []
var status_label: Label
var feedback_label: Label
var feedback_timer := 0.0
var light_theme := false

const LIGHT_BG := Color("f4f6f4")
const LIGHT_SURFACE := Color("ffffff")
const LIGHT_CARD := Color("e5f0ed")
const LIGHT_CARD_2 := Color("fafbfa")
const LIGHT_TEXT := Color("13201d")
const LIGHT_MUTED := Color("687773")
const LIGHT_BORDER := Color("dbe3e0")
const LIGHT_ACCENT := Color("0f766e")
const LIGHT_WARN := Color("b45309")
const DARK_BG := Color("07100f")
const DARK_SURFACE := Color("0d1917")
const DARK_CARD := Color("10251f")
const DARK_CARD_2 := Color("0d1c1a")
const DARK_TEXT := Color("effbf7")
const DARK_MUTED := Color("8fa7a1")
const DARK_BORDER := Color("1e3934")
const DARK_ACCENT := Color("5eead4")
const DARK_WARN := Color("fbbf24")

func _ready() -> void:
    parent = get_tree().root.get_node_or_null("Renew")
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

func _build_ui() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    background = ColorRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(background)

    shell = MarginContainer.new()
    shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(shell)

    page = VBoxContainer.new()
    page.add_theme_constant_override("separation", 12)
    shell.add_child(page)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 12)
    page.add_child(header)

    var title_stack := VBoxContainer.new()
    title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_stack.add_theme_constant_override("separation", 0)
    header.add_child(title_stack)
    brand = _label("RENEW", 27)
    location_label = _label("RESTORATION COMMAND", 11)
    title_stack.add_child(brand)
    title_stack.add_child(location_label)

    theme_button = Button.new()
    theme_button.name = "ThemeToggle"
    theme_button.text = "LIGHT"
    theme_button.custom_minimum_size = Vector2(84, 44)
    theme_button.focus_mode = Control.FOCUS_NONE
    theme_button.pressed.connect(_toggle_theme)
    header.add_child(theme_button)

    hero_card = PanelContainer.new()
    hero_card.custom_minimum_size = Vector2(0, 152)
    page.add_child(hero_card)
    var hero_margin := MarginContainer.new()
    hero_margin.add_theme_constant_override("margin_left", 22)
    hero_margin.add_theme_constant_override("margin_right", 22)
    hero_margin.add_theme_constant_override("margin_top", 18)
    hero_margin.add_theme_constant_override("margin_bottom", 18)
    hero_card.add_child(hero_margin)

    var hero_row := HBoxContainer.new()
    hero_row.add_theme_constant_override("separation", 18)
    hero_margin.add_child(hero_row)

    var hero_stack := VBoxContainer.new()
    hero_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hero_stack.add_theme_constant_override("separation", 2)
    hero_row.add_child(hero_stack)
    hero_caption = _label("AVAILABLE CASH", 11)
    hero_value = _label("$0", 34)
    hero_meta = _label("DAY 1  •  REP 0", 12)
    hero_goal = _label("Build your restoration empire.", 13)
    hero_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hero_stack.add_child(hero_caption)
    hero_stack.add_child(hero_value)
    hero_stack.add_child(hero_meta)
    hero_stack.add_child(hero_goal)

    hero_action = Button.new()
    hero_action.name = "PrimaryNextMove"
    hero_action.text = "NEXT MOVE"
    hero_action.custom_minimum_size = Vector2(168, 54)
    hero_action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    hero_action.focus_mode = Control.FOCUS_NONE
    hero_row.add_child(hero_action)

    stat_grid = GridContainer.new()
    stat_grid.columns = 4
    stat_grid.add_theme_constant_override("h_separation", 9)
    stat_grid.add_theme_constant_override("v_separation", 9)
    page.add_child(stat_grid)
    for i in range(4):
        var card := PanelContainer.new()
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        card.custom_minimum_size = Vector2(0, 82)
        var margin := MarginContainer.new()
        margin.add_theme_constant_override("margin_left", 14)
        margin.add_theme_constant_override("margin_right", 14)
        margin.add_theme_constant_override("margin_top", 11)
        margin.add_theme_constant_override("margin_bottom", 10)
        card.add_child(margin)
        var box := VBoxContainer.new()
        box.add_theme_constant_override("separation", 2)
        margin.add_child(box)
        var name := _label("METRIC", 10)
        var value := _label("—", 17)
        box.add_child(name)
        box.add_child(value)
        stat_grid.add_child(card)
        stat_cards.append(card)
        stat_names.append(name)
        stat_values.append(value)

    var section_row := HBoxContainer.new()
    section_row.add_theme_constant_override("separation", 10)
    page.add_child(section_row)
    var section_stack := VBoxContainer.new()
    section_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    section_stack.add_theme_constant_override("separation", 0)
    section_row.add_child(section_stack)
    section_title = _label("Live", 22)
    section_caption = _label("Property, progress and essential actions", 11)
    section_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    section_stack.add_child(section_title)
    section_stack.add_child(section_caption)

    action_scroll = ScrollContainer.new()
    action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    page.add_child(action_scroll)
    action_list = VBoxContainer.new()
    action_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    action_list.add_theme_constant_override("separation", 8)
    action_scroll.add_child(action_list)

    status_label = _label("", 11)
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    page.add_child(status_label)
    feedback_label = _label("", 11)
    feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feedback_label.visible = false
    page.add_child(feedback_label)

    bottom_nav = HBoxContainer.new()
    bottom_nav.add_theme_constant_override("separation", 7)
    page.add_child(bottom_nav)
    var names := ["LIVE", "BUSINESS", "EMPIRE", "WORLD"]
    for i in range(names.size()):
        var button := Button.new()
        button.name = "Nav_" + names[i]
        button.text = names[i]
        button.custom_minimum_size = Vector2(100, 50)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.focus_mode = Control.FOCUS_NONE
        button.pressed.connect(_set_tab.bind(i))
        bottom_nav.add_child(button)
        mode_buttons.append(button)

func _label(text: String, size: int) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

func _transparent(color: Color, alpha: float) -> Color:
    return Color(color.r, color.g, color.b, alpha)

func _card_style(bg: Color, border: Color, radius := 18, width := 1) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(width)
    style.set_corner_radius_all(radius)
    style.shadow_color = Color(0, 0, 0, 0.08 if light_theme else 0.30)
    style.shadow_size = 5
    style.shadow_offset = Vector2(0, 3)
    return style

func _button_style(bg: Color, border: Color, radius := 15) -> StyleBoxFlat:
    var style := _card_style(bg, border, radius, 1)
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 11
    style.content_margin_bottom = 11
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

    background.color = bg
    for label in [brand, hero_value, section_title]:
        if label != null: label.add_theme_color_override("font_color", text)
    for label in [location_label, hero_caption, hero_meta, hero_goal, section_caption, status_label, feedback_label]:
        if label != null: label.add_theme_color_override("font_color", muted)
    for value in stat_values:
        value.add_theme_color_override("font_color", text)
    for name in stat_names:
        name.add_theme_color_override("font_color", muted)

    hero_card.add_theme_stylebox_override("panel", _card_style(card, _transparent(accent, 0.34), 22, 1))
    for stat_card in stat_cards:
        stat_card.add_theme_stylebox_override("panel", _card_style(card2, border, 16, 1))

    theme_button.add_theme_stylebox_override("normal", _button_style(surface, border, 14))
    theme_button.add_theme_stylebox_override("hover", _button_style(_transparent(accent, 0.12), accent, 14))
    theme_button.add_theme_color_override("font_color", text)
    theme_button.text = "DARK" if light_theme else "LIGHT"

    hero_action.add_theme_stylebox_override("normal", _button_style(accent, accent, 15))
    hero_action.add_theme_stylebox_override("hover", _button_style(accent.lightened(0.08), accent, 15))
    hero_action.add_theme_stylebox_override("pressed", _button_style(accent.darkened(0.08), accent, 15))
    hero_action.add_theme_color_override("font_color", bg)
    hero_action.add_theme_color_override("font_hover_color", bg)

    _style_active_tab()
    _restyle_actions()

func _style_active_tab() -> void:
    if mode_buttons.is_empty(): return
    var card := LIGHT_CARD_2 if light_theme else DARK_CARD_2
    var text := LIGHT_TEXT if light_theme else DARK_TEXT
    var muted := LIGHT_MUTED if light_theme else DARK_MUTED
    var border := LIGHT_BORDER if light_theme else DARK_BORDER
    var accent := LIGHT_ACCENT if light_theme else DARK_ACCENT
    for i in range(mode_buttons.size()):
        var button := mode_buttons[i]
        button.add_theme_color_override("font_hover_color", text)
        if i == active_tab:
            button.add_theme_stylebox_override("normal", _button_style(_transparent(accent, 0.15), accent, 14))
            button.add_theme_color_override("font_color", accent)
        else:
            button.add_theme_stylebox_override("normal", _button_style(card, border, 14))
            button.add_theme_color_override("font_color", muted)

func _toggle_theme() -> void:
    light_theme = not light_theme
    ProjectSettings.set_setting("renew/ui/light_theme", light_theme)
    _apply_theme()

func _layout_responsive() -> void:
    if shell == null: return
    var width := get_viewport().get_visible_rect().size.x
    var mobile := width < 700.0
    var compact := width < 980.0
    shell.add_theme_constant_override("margin_left", 12 if mobile else 24)
    shell.add_theme_constant_override("margin_right", 12 if mobile else 24)
    shell.add_theme_constant_override("margin_top", 12 if mobile else 18)
    shell.add_theme_constant_override("margin_bottom", 10 if mobile else 16)
    brand.add_theme_font_size_override("font_size", 22 if mobile else 27)
    hero_value.add_theme_font_size_override("font_size", 28 if mobile else 34)
    section_title.add_theme_font_size_override("font_size", 20 if mobile else 22)
    stat_grid.columns = 2 if compact else 4
    hero_action.custom_minimum_size = Vector2(126 if mobile else 168, 52)
    hero_action.add_theme_font_size_override("font_size", 11 if mobile else 13)
    for button in mode_buttons:
        button.add_theme_font_size_override("font_size", 10 if mobile else 12)
    _restyle_actions()

func _set_tab(index: int) -> void:
    active_tab = clampi(index, 0, 3)
    _refresh()
    _style_active_tab()

func _clear_actions() -> void:
    for child in action_list.get_children(): child.queue_free()

func _group(title: String, caption := "") -> void:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 0)
    box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var title_label := _label(title.to_upper(), 10)
    var muted := LIGHT_MUTED if light_theme else DARK_MUTED
    title_label.add_theme_color_override("font_color", muted)
    box.add_child(title_label)
    if caption != "":
        var caption_label := _label(caption, 11)
        caption_label.add_theme_color_override("font_color", muted)
        caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        box.add_child(caption_label)
    action_list.add_child(box)

func _action(text: String, callback: Callable, subtitle := "", emphasis := false) -> void:
    if not callback.is_valid(): return
    var button := Button.new()
    button.name = "Action_" + text.to_snake_case()
    button.text = text + ("\n" + subtitle if subtitle != "" else "")
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.custom_minimum_size = Vector2(0, 64)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.focus_mode = Control.FOCUS_NONE
    button.set_meta("renew_emphasis", emphasis)
    button.pressed.connect(_run_action.bind(callback))
    action_list.add_child(button)
    _style_action_button(button)

func _style_action_button(button: Button) -> void:
    var surface := LIGHT_SURFACE if light_theme else DARK_SURFACE
    var text := LIGHT_TEXT if light_theme else DARK_TEXT
    var border := LIGHT_BORDER if light_theme else DARK_BORDER
    var accent := LIGHT_ACCENT if light_theme else DARK_ACCENT
    var emphasis := bool(button.get_meta("renew_emphasis", false))
    var normal_bg := _transparent(accent, 0.11) if emphasis else surface
    var normal_border := accent if emphasis else border
    button.add_theme_stylebox_override("normal", _button_style(normal_bg, normal_border, 15))
    button.add_theme_stylebox_override("hover", _button_style(_transparent(accent, 0.16), accent, 15))
    button.add_theme_stylebox_override("pressed", _button_style(_transparent(accent, 0.23), accent, 15))
    button.add_theme_color_override("font_color", accent if emphasis else text)
    button.add_theme_color_override("font_hover_color", text)
    button.add_theme_font_size_override("font_size", 14)

func _restyle_actions() -> void:
    if action_list == null: return
    for child in action_list.get_children():
        if child is Button: _style_action_button(child)

func _run_action(callback: Callable) -> void:
    if parent == null or not callback.is_valid(): return
    var result = callback.call()
    if result is Dictionary and result.has("message"): parent.message = str(result["message"])
    if str(parent.message) != "": show_feedback(str(parent.message))
    _refresh()

func show_feedback(text: String) -> void:
    feedback_label.text = text
    feedback_label.visible = true
    feedback_timer = 6.0

func _open_screen(screen_name: String) -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("show_screen"): manager.show_screen(screen_name)

func _screen(text: String, screen_name: String, subtitle := "", emphasis := false) -> void:
    _action(text, Callable(self, "_open_screen").bind(screen_name), subtitle, emphasis)

func _next_rival() -> void:
    if parent != null and parent.rivals != null and not parent.rivals.rivals.is_empty():
        parent.select_rival((int(parent.selected_rival) + 1) % parent.rivals.rivals.size())

func _goal_text() -> String:
    if parent == null: return "Build your restoration empire."
    if not bool(parent.inspected): return "Survey the abandoned property and uncover its potential."
    if not bool(parent.owned): return "Secure the property before another buyer moves in."
    if str(parent.stage) != "Operational": return "Restore the site, stage by stage, until it can operate."
    if not bool(parent.business_open): return "Choose a purpose and launch the restored business."
    if int(parent.finished_goods) <= 0: return "Build inventory, then convert it into cash through demand and contracts."
    if int(parent.debt) > int(parent.cash): return "Protect liquidity: monitor debt while keeping production moving."
    return "Scale the company: improve margins, secure supply and expand into stronger markets."

func _primary_move() -> Dictionary:
    if parent == null: return {"label": "NEXT MOVE", "call": Callable()}
    if not bool(parent.inspected): return {"label": "INSPECT", "call": parent.inspect_property}
    if not bool(parent.owned): return {"label": "ACQUIRE", "call": parent.acquire_property}
    if str(parent.stage) != "Operational": return {"label": "RESTORE", "call": parent.restore_property}
    if not bool(parent.business_open): return {"label": "OPEN BUSINESS", "call": parent.open_business}
    if int(parent.finished_goods) <= 0: return {"label": "PRODUCE", "call": parent.produce_goods}
    return {"label": "END DAY", "call": parent.advance_day}

func _bind_primary_move() -> void:
    for connection in hero_action.pressed.get_connections():
        var callable: Callable = connection.get("callable", Callable())
        if callable.is_valid(): hero_action.pressed.disconnect(callable)
    var move := _primary_move()
    hero_action.text = str(move.get("label", "NEXT MOVE"))
    var callable: Callable = move.get("call", Callable())
    if callable.is_valid(): hero_action.pressed.connect(_run_action.bind(callable))

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
            _set_metric(0, "RESTORATION", "%d%%" % int(parent.restoration))
            _set_metric(1, "SITE", str(parent.stage).to_upper())
            _set_metric(2, "LAST PROFIT", _money(int(parent.last_profit)))
            _set_metric(3, "REPUTATION", str(int(parent.reputation)))
        1:
            _set_metric(0, "INVENTORY", str(int(parent.finished_goods)))
            _set_metric(1, "STAFF", str(int(parent.employees)))
            _set_metric(2, "PRICE", _money(int(parent.player_price)))
            _set_metric(3, "DEBT", _money(int(parent.debt)))
        2:
            _set_metric(0, "ACQUISITIONS", str(int(parent.acquisition_count)))
            _set_metric(1, "TRANSPORT", "LV %d" % int(parent.transport_level))
            _set_metric(2, "CAPACITY", str(int(parent.transport_capacity)))
            _set_metric(3, "TOTAL PROFIT", _money(int(parent.total_profit)))
        3:
            _set_metric(0, "DISTRICT", str(int(parent.selected_district) + 1))
            _set_metric(1, "TRANSPORT", "LV %d" % int(parent.transport_level))
            _set_metric(2, "CONTRACT", "%dd" % int(parent.contract_days))
            _set_metric(3, "REPUTATION", str(int(parent.reputation)))

func _refresh() -> void:
    if parent == null or action_list == null: return
    _clear_actions()
    hero_value.text = _money(int(parent.cash))
    hero_meta.text = "DAY %d  •  REP %d  •  %s" % [int(parent.day), int(parent.reputation), "OPEN" if bool(parent.business_open) else "CLOSED"]
    hero_goal.text = _goal_text()
    status_label.text = str(parent.status)
    _bind_primary_move()
    _refresh_metrics()

    section_title.text = ["Live Command", "Business Operations", "Empire Control", "World Network"][active_tab]
    section_caption.text = [
        "Restore assets, read the company pulse and move the day forward.",
        "Coordinate production, people, customers, contracts and capital.",
        "Build a portfolio, compete with corporations and invest in scale.",
        "Connect regions, logistics, infrastructure, opportunities and market news."
    ][active_tab]

    match active_tab:
        0:
            _group("Command center", "The shortest path from abandoned asset to operating company.")
            _screen("Company dashboard", "DashboardPanel", "KPIs, alerts and company health", true)
            if not bool(parent.inspected):
                _action("Inspect property", parent.inspect_property, "Reveal condition, risk and restoration needs", true)
            elif not bool(parent.owned):
                _action("Acquire property", parent.acquire_property, "Secure the asset and begin the turnaround", true)
            elif str(parent.stage) != "Operational":
                _action("Restore next stage", parent.restore_property, "Invest in the next visible restoration milestone", true)
            elif not bool(parent.business_open):
                _action("Open business", parent.open_business, "Convert the restored asset into an operating company", true)
            else:
                _action("End day", parent.advance_day, "Resolve demand, costs, rivals and the wider economy", true)
            _group("Control")
            _screen("Portfolio", "PortfolioPanel", "Owned assets, leases and property decisions")
            _screen("Save / load", "SaveLoadPanel", "Protect or restore the current company state")
        1:
            _group("Operations", "Turn supply and labor into profitable output.")
            _screen("Production control", "ProductionControlPanel", "Inventory, throughput and production decisions", true)
            _action("Buy inputs", parent.buy_inputs, "Replenish production materials")
            _action("Produce goods", parent.produce_goods, "Convert inputs into saleable inventory")
            _action("Change price", parent.change_price, "Respond to demand and competitive pressure")
            _action("Upgrade business", parent.upgrade_business, "Increase capacity and operating efficiency")
            _group("Demand and people")
            _screen("Customers & market", "CustomerSegmentsUI", "Segments, demand and pricing intelligence")
            _screen("Contracts", "ContractPanel", "Customer commitments, haggling and special deals")
            _screen("Employees", "EmployeePanel", "Hiring, assignments, development and leadership")
            _action("Marketing campaign", parent.marketing_campaign, "Build visibility and stimulate demand")
            _group("Capital")
            _screen("Finance", "FinancePanel", "Cash flow, debt, investment and financial health")
        2:
            _group("Portfolio and scale", "Expansion should create new operational choices, not just bigger numbers.")
            _screen("Empire expansion", "EmpireExpansionPanel", "Acquire and upgrade expansion businesses", true)
            _screen("Portfolio", "PortfolioPanel", "Property ownership, leases and asset allocation")
            _screen("Headquarters", "HeadquartersPanel", "Management capacity and empire-wide capabilities")
            _screen("Technology", "TechnologyPanel", "Research efficiency, logistics and strategic advantages")
            _group("Competition and alliances")
            _screen("Corporations", "CorporationsPanel", "Rivals, ownership moves and corporate intelligence")
            _action("Next rival", _next_rival, "Cycle the active competing corporation")
            _action("Alliance offer", parent.make_alliance_offer, "Open a strategic route instead of a price war")
            _screen("Alliance network", "AlliancePanel", "Relationships, members and alliance competitions")
            _group("Infrastructure")
            _screen("Supply chain", "SupplyChainPanel", "Internal logistics, suppliers and transport pressure")
            _action("Upgrade transport", parent.upgrade_transport, "Raise network capacity and expansion resilience")
        3:
            _group("Regional strategy", "Expansion works best when market access, supply and infrastructure move together.")
            _screen("Regions", "RegionsPanel", "Presence, branches and regional economics", true)
            _screen("World opportunities", "WorldOpportunitiesPanel", "Missions and expansion opportunities")
            _screen("Infrastructure", "InfrastructurePanel", "Build and repair strategic infrastructure")
            _group("Flows and intelligence")
            _screen("Supply chain", "SupplyChainPanel", "Transport, suppliers and network bottlenecks")
            _action("Upgrade transport", parent.upgrade_transport, "Increase resilience across the wider network")
            _screen("Live events", "LiveOpsPanel", "Seasonal shocks and market-wide modifiers")
            _screen("News", "NewsPanel", "Read economic and competitive signals before acting")

    _style_active_tab()
    _restyle_actions()

func _process(delta: float) -> void:
    if feedback_timer > 0.0:
        feedback_timer = maxf(0.0, feedback_timer - delta)
        if feedback_timer <= 0.0: feedback_label.visible = false
    if parent != null:
        hero_value.text = _money(int(parent.cash))
        hero_meta.text = "DAY %d  •  REP %d  •  %s" % [int(parent.day), int(parent.reputation), "OPEN" if bool(parent.business_open) else "CLOSED"]
