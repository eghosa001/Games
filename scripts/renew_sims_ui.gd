extends CanvasLayer

# Premium card-first presentation for RENEW.
# Presentation only: gameplay commands and simulation state remain on Renew/Main.

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
var stat_cards: Array[PanelContainer] = []
var stat_values: Array[Label] = []
var section_title: Label
var section_caption: Label
var action_scroll: ScrollContainer
var action_list: VBoxContainer
var bottom_nav: HBoxContainer
var mode_buttons: Array[Button] = []
var status_label: Label
var feedback_label: Label
var goal_label: Label
var feedback_timer := 0.0
var light_theme := true

const LIGHT_BG := Color("f6f3ef")
const LIGHT_SURFACE := Color("fffdfb")
const LIGHT_CARD := Color("ead9ce")
const LIGHT_CARD_2 := Color("f8f7f4")
const LIGHT_TEXT := Color("171513")
const LIGHT_MUTED := Color("8b817a")
const LIGHT_BORDER := Color("e5ded8")
const LIGHT_ACCENT := Color("7a543b")
const DARK_BG := Color("0b1118")
const DARK_SURFACE := Color("111a24")
const DARK_CARD := Color("172331")
const DARK_CARD_2 := Color("121c27")
const DARK_TEXT := Color("f7f2eb")
const DARK_MUTED := Color("9aa8b6")
const DARK_BORDER := Color("263443")
const DARK_ACCENT := Color("e6b978")

func _ready() -> void:
    parent = get_tree().root.get_node_or_null("Renew")
    light_theme = bool(ProjectSettings.get_setting("renew/ui/light_theme", true))
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
    page.add_theme_constant_override("separation", 14)
    shell.add_child(page)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 12)
    page.add_child(header)
    var title_stack := VBoxContainer.new()
    title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_stack.add_theme_constant_override("separation", 0)
    header.add_child(title_stack)
    brand = _label("RENEW", 28)
    location_label = _label("Restoration company", 13)
    title_stack.add_child(brand)
    title_stack.add_child(location_label)
    theme_button = Button.new()
    theme_button.text = "DARK"
    theme_button.custom_minimum_size = Vector2(84, 46)
    theme_button.focus_mode = Control.FOCUS_NONE
    theme_button.pressed.connect(_toggle_theme)
    header.add_child(theme_button)

    hero_card = PanelContainer.new()
    hero_card.custom_minimum_size = Vector2(0, 150)
    page.add_child(hero_card)
    var hero_margin := MarginContainer.new()
    hero_margin.add_theme_constant_override("margin_left", 26)
    hero_margin.add_theme_constant_override("margin_right", 26)
    hero_margin.add_theme_constant_override("margin_top", 20)
    hero_margin.add_theme_constant_override("margin_bottom", 18)
    hero_card.add_child(hero_margin)
    var hero_box := VBoxContainer.new()
    hero_box.add_theme_constant_override("separation", 3)
    hero_margin.add_child(hero_box)
    hero_value = _label("$0", 36)
    hero_caption = _label("Available cash", 15)
    hero_meta = _label("DAY 1  •  REP 0", 12)
    hero_box.add_child(hero_value)
    hero_box.add_child(hero_caption)
    hero_box.add_child(hero_meta)

    var stat_row := HBoxContainer.new()
    stat_row.add_theme_constant_override("separation", 12)
    page.add_child(stat_row)
    for i in range(2):
        var card := PanelContainer.new()
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        card.custom_minimum_size = Vector2(0, 102)
        var margin := MarginContainer.new()
        margin.add_theme_constant_override("margin_left", 18)
        margin.add_theme_constant_override("margin_right", 18)
        margin.add_theme_constant_override("margin_top", 15)
        margin.add_theme_constant_override("margin_bottom", 14)
        card.add_child(margin)
        var box := VBoxContainer.new()
        box.add_theme_constant_override("separation", 3)
        margin.add_child(box)
        var name := _label("PROPERTY" if i == 0 else "BUSINESS", 12)
        var value := _label("Available" if i == 0 else "Closed", 19)
        box.add_child(name)
        box.add_child(value)
        stat_row.add_child(card)
        stat_cards.append(card)
        stat_values.append(value)

    var section_stack := VBoxContainer.new()
    section_stack.add_theme_constant_override("separation", 0)
    page.add_child(section_stack)
    section_title = _label("Live", 25)
    section_caption = _label("Choose what to manage", 12)
    section_stack.add_child(section_title)
    section_stack.add_child(section_caption)

    action_scroll = ScrollContainer.new()
    action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    page.add_child(action_scroll)
    action_list = VBoxContainer.new()
    action_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    action_list.add_theme_constant_override("separation", 10)
    action_scroll.add_child(action_list)

    status_label = _label("", 11)
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    page.add_child(status_label)
    feedback_label = _label("", 11)
    feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    feedback_label.visible = false
    page.add_child(feedback_label)
    goal_label = _label("", 11)
    goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    page.add_child(goal_label)

    bottom_nav = HBoxContainer.new()
    bottom_nav.add_theme_constant_override("separation", 8)
    page.add_child(bottom_nav)
    var names := ["LIVE", "BUSINESS", "EMPIRE", "WORLD"]
    for i in range(names.size()):
        var button := Button.new()
        button.text = names[i]
        button.custom_minimum_size = Vector2(100, 54)
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

func _card_style(bg: Color, border: Color, radius := 22, width := 1) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(width)
    style.set_corner_radius_all(radius)
    style.shadow_color = Color(0, 0, 0, 0.10 if light_theme else 0.24)
    style.shadow_size = 5
    style.shadow_offset = Vector2(0, 3)
    return style

func _button_style(bg: Color, border: Color, radius := 18) -> StyleBoxFlat:
    var style := _card_style(bg, border, radius, 1)
    style.content_margin_left = 18
    style.content_margin_right = 18
    style.content_margin_top = 13
    style.content_margin_bottom = 13
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
    for label in [brand, hero_value, hero_caption, section_title]:
        if label != null: label.add_theme_color_override("font_color", text)
    for label in [location_label, hero_meta, section_caption, status_label, feedback_label, goal_label]:
        if label != null: label.add_theme_color_override("font_color", muted)
    for value in stat_values:
        value.add_theme_color_override("font_color", text)
        var box := value.get_parent()
        if box != null and box.get_child_count() > 0 and box.get_child(0) is Label:
            (box.get_child(0) as Label).add_theme_color_override("font_color", muted)
    hero_card.add_theme_stylebox_override("panel", _card_style(card, _transparent(card, 0.0), 28, 0))
    for stat_card in stat_cards:
        stat_card.add_theme_stylebox_override("panel", _card_style(card2, border, 22, 1))
    theme_button.add_theme_stylebox_override("normal", _button_style(accent, accent, 18))
    theme_button.add_theme_stylebox_override("hover", _button_style(accent.lightened(0.08), accent, 18))
    theme_button.add_theme_color_override("font_color", bg)
    theme_button.text = "DARK" if light_theme else "LIGHT"
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
            button.add_theme_stylebox_override("normal", _button_style(_transparent(accent, 0.14 if light_theme else 0.20), accent, 18))
            button.add_theme_color_override("font_color", accent)
        else:
            button.add_theme_stylebox_override("normal", _button_style(card, border, 18))
            button.add_theme_color_override("font_color", muted)

func _toggle_theme() -> void:
    light_theme = not light_theme
    ProjectSettings.set_setting("renew/ui/light_theme", light_theme)
    _apply_theme()

func _layout_responsive() -> void:
    if shell == null: return
    var mobile := get_viewport().get_visible_rect().size.x < 700.0
    shell.add_theme_constant_override("margin_left", 14 if mobile else 28)
    shell.add_theme_constant_override("margin_right", 14 if mobile else 28)
    shell.add_theme_constant_override("margin_top", 14 if mobile else 20)
    shell.add_theme_constant_override("margin_bottom", 12 if mobile else 18)
    brand.add_theme_font_size_override("font_size", 23 if mobile else 28)
    hero_value.add_theme_font_size_override("font_size", 28 if mobile else 36)
    section_title.add_theme_font_size_override("font_size", 21 if mobile else 25)
    for button in mode_buttons:
        button.add_theme_font_size_override("font_size", 10 if mobile else 12)
    _restyle_actions()

func _set_tab(index: int) -> void:
    active_tab = clampi(index, 0, 3)
    _refresh()
    _style_active_tab()

func _clear_actions() -> void:
    for child in action_list.get_children(): child.queue_free()

func _action(text: String, callback: Callable, subtitle := "") -> void:
    if not callback.is_valid(): return
    var button := Button.new()
    button.name = "Action_" + text.to_snake_case()
    button.text = text + ("\n" + subtitle if subtitle != "" else "")
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.custom_minimum_size = Vector2(0, 70)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.focus_mode = Control.FOCUS_NONE
    button.pressed.connect(_run_action.bind(callback))
    action_list.add_child(button)
    _style_action_button(button)

func _style_action_button(button: Button) -> void:
    var surface := LIGHT_SURFACE if light_theme else DARK_SURFACE
    var text := LIGHT_TEXT if light_theme else DARK_TEXT
    var border := LIGHT_BORDER if light_theme else DARK_BORDER
    var accent := LIGHT_ACCENT if light_theme else DARK_ACCENT
    button.add_theme_stylebox_override("normal", _button_style(surface, border, 20))
    button.add_theme_stylebox_override("hover", _button_style(_transparent(accent, 0.10 if light_theme else 0.14), accent, 20))
    button.add_theme_stylebox_override("pressed", _button_style(_transparent(accent, 0.16 if light_theme else 0.20), accent, 20))
    button.add_theme_color_override("font_color", text)
    button.add_theme_color_override("font_hover_color", text)
    button.add_theme_font_size_override("font_size", 15)

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
    feedback_timer = 7.0

func _open_screen(screen_name: String) -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("show_screen"): manager.show_screen(screen_name)

func _screen(text: String, screen_name: String, subtitle := "Open management screen") -> void:
    _action(text, Callable(self, "_open_screen").bind(screen_name), subtitle)

func _next_rival() -> void:
    if parent != null and parent.rivals != null and not parent.rivals.rivals.is_empty():
        parent.select_rival((int(parent.selected_rival) + 1) % parent.rivals.rivals.size())

func _goal_text() -> String:
    if parent == null: return "Build your restoration empire."
    if not bool(parent.owned): return "Inspect and acquire your first property."
    if str(parent.stage) != "Operational": return "Restore the property to 100%."
    if not bool(parent.business_open): return "Choose a purpose and open your first business."
    return "Produce, sell, expand and control the market."

func _refresh() -> void:
    if parent == null or action_list == null: return
    _clear_actions()
    hero_value.text = "$%s" % str(int(parent.cash))
    hero_meta.text = "DAY %d  •  REP %d" % [int(parent.day), int(parent.reputation)]
    stat_values[0].text = "%d%% restored" % int(parent.restoration)
    stat_values[1].text = "Open" if bool(parent.business_open) else "Closed"
    goal_label.text = _goal_text()
    status_label.text = str(parent.status)
    section_title.text = ["Live", "Business", "Empire", "World"][active_tab]
    section_caption.text = ["Property, progress and essential actions", "Operate production, people and finance", "Expand holdings and compete with rivals", "Regions, logistics and global opportunities"][active_tab]
    match active_tab:
        0:
            _screen("Dashboard", "DashboardPanel", "Company overview and key indicators")
            _action("Inspect property", parent.inspect_property, "Review condition and restoration needs")
            _action("Acquire property", parent.acquire_property, "Take ownership of the selected site")
            _action("Restore property", parent.restore_property, "Invest in the next restoration stage")
            _action("Open business", parent.open_business, "Start operating from this property")
            _action("End day", parent.advance_day, "Advance the economy by one day")
            _action("Save", parent.save_game, "Save the current company state")
        1:
            _action("Buy inputs", parent.buy_inputs, "Purchase production materials")
            _action("Produce", parent.produce_goods, "Run the current production cycle")
            _action("Change price", parent.change_price, "Adjust selling price to market conditions")
            _action("Upgrade business", parent.upgrade_business, "Increase business capacity and efficiency")
            _action("Marketing", parent.marketing_campaign, "Increase demand and brand visibility")
            _screen("People", "EmployeePanel", "Manage employees and staffing")
            _screen("Customers", "CustomerSegmentsUI", "Review customers and demand")
            _screen("Finance", "FinancePanel", "Loans, collections and company finances")
        2:
            _screen("Corporate network", "CorporateNetworkPanel", "Review controlled businesses and assets")
            _action("Next rival", _next_rival, "Select another competing corporation")
            _action("Alliance offer", parent.alliance_offer, "Propose a strategic alliance")
            _screen("Expansion", "ExpansionUI", "Acquire and upgrade expansion businesses")
            _screen("Regions", "RegionPanel", "Review regional presence")
            _screen("Technology", "TechnologyPanel", "Invest in progression and technology")
        3:
            _screen("Regional management", "RegionPanel", "Manage presence across regions")
            _screen("Logistics", "SupplyChainPanel", "Review transport and supply network")
            _action("Upgrade transport", parent.upgrade_transport, "Improve logistics capacity")
            _screen("Missions", "MissionPanel", "Review current world opportunities")
            _screen("Live events", "LiveOpsPanel", "Seasonal and market-wide events")
            _screen("News", "NewsPanel", "Read current world and market news")
    _style_active_tab()
    _restyle_actions()

func _process(delta: float) -> void:
    if feedback_timer > 0.0:
        feedback_timer = maxf(0.0, feedback_timer - delta)
        if feedback_timer <= 0.0: feedback_label.visible = false
    if parent != null:
        hero_value.text = "$%s" % str(int(parent.cash))
        hero_meta.text = "DAY %d  •  REP %d" % [int(parent.day), int(parent.reputation)]
