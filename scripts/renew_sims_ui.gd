extends "res://scripts/mobile_ui.gd"

# RENEW Sims-inspired presentation layer.
# This keeps the existing game/action APIs but changes the presentation to a
# world-first life-sim layout: open world canvas, compact HUD, contextual dock,
# mode rail, and touch-friendly mobile bottom sheet.

const BG := Color("071217")
const PANEL := Color("0b1b22e6")
const PANEL_SOLID := Color("0c2028")
const PANEL_SOFT := Color("102a32d9")
const BORDER := Color("31545c")
const BORDER_SOFT := Color("24434b")
const TEXT := Color("edf6f3")
const MUTED := Color("8da7aa")
const ACCENT := Color("d8b76d")
const ACCENT_SOFT := Color("b99552")
const SUCCESS := Color("8ed6b0")
const DANGER := Color("e48c83")

var hud: Control
var top_strip: Panel
var brand: Label
var location_label: Label
var cash_label: Label
var rep_label: Label
var day_label: Label
var mode_rail: Panel
var mode_buttons: Array[Button] = []
var left_rail: Panel
var left_buttons: Array[Button] = []
var selected_card: Panel
var selected_title: Label
var selected_meta: Label
var objective_card: Panel
var objective_text: Label
var action_dock: Panel
var action_title: Label
var action_subtitle: Label
var action_grid: GridContainer
var action_scroll: ScrollContainer
var network_strip: Panel
var network_row: HBoxContainer
var right_card: Panel
var right_title: Label
var right_body: Label
var bottom_mobile: Panel
var mobile_mode_row: HBoxContainer
var mobile_action_scroll: ScrollContainer
var mobile_actions: GridContainer
var mobile_objective: Label
var button_theme: Theme
var narrow := false

func _ready() -> void:
    parent = get_tree().root.get_node_or_null("Renew")
    _build_ui()
    call_deferred("_initialize")

func _build_ui() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    # Very light full-screen tint: the game world remains the hero.
    var tint := ColorRect.new()
    tint.color = Color(0.02, 0.05, 0.06, 0.08)
    tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(tint)

    button_theme = _make_theme()
    _build_top_hud()
    _build_mode_rail()
    _build_left_rail()
    _build_context_cards()
    _build_action_dock()
    _build_network_strip()
    _build_mobile_dock()
    _layout_responsive()

func _build_top_hud() -> void:
    top_strip = Panel.new()
    top_strip.add_theme_stylebox_override("panel", _style(PANEL, BORDER_SOFT, 14))
    root.add_child(top_strip)

    brand = Label.new()
    brand.text = "RENEW"
    brand.add_theme_font_size_override("font_size", 22)
    brand.add_theme_color_override("font_color", TEXT)
    top_strip.add_child(brand)

    location_label = Label.new()
    location_label.text = "RESTORATION DISTRICT  •  HEADQUARTERS"
    location_label.add_theme_font_size_override("font_size", 9)
    location_label.add_theme_color_override("font_color", MUTED)
    top_strip.add_child(location_label)

    cash_label = _hud_value("$0")
    rep_label = _hud_value("REP 0")
    day_label = _hud_value("DAY 1")
    top_strip.add_child(cash_label)
    top_strip.add_child(rep_label)
    top_strip.add_child(day_label)

func _hud_value(text: String) -> Label:
    var l := Label.new()
    l.text = text
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.add_theme_font_size_override("font_size", 12)
    l.add_theme_color_override("font_color", TEXT)
    return l

func _build_mode_rail() -> void:
    mode_rail = Panel.new()
    mode_rail.add_theme_stylebox_override("panel", _style(PANEL, BORDER_SOFT, 12))
    root.add_child(mode_rail)
    var row := HBoxContainer.new()
    row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    row.add_theme_constant_override("separation", 4)
    mode_rail.add_child(row)
    var names := ["LIVE", "BUSINESS", "EMPIRE", "WORLD"]
    for i in range(names.size()):
        var b := Button.new()
        b.text = names[i]
        b.focus_mode = Control.FOCUS_NONE
        b.mouse_filter = Control.MOUSE_FILTER_STOP
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.pressed.connect(_set_tab.bind(i))
        row.add_child(b)
        mode_buttons.append(b)

func _build_left_rail() -> void:
    left_rail = Panel.new()
    left_rail.add_theme_stylebox_override("panel", _style(PANEL, BORDER_SOFT, 12))
    root.add_child(left_rail)
    var box := VBoxContainer.new()
    box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    box.add_theme_constant_override("separation", 6)
    box.add_theme_constant_override("margin_left", 7)
    box.add_theme_constant_override("margin_right", 7)
    box.add_theme_constant_override("margin_top", 7)
    box.add_theme_constant_override("margin_bottom", 7)
    left_rail.add_child(box)
    var entries := [["⌂", "HOME"], ["▣", "ASSETS"], ["◈", "BUSINESS"], ["◎", "NETWORK"], ["◇", "WORLD"]]
    for i in range(entries.size()):
        var b := Button.new()
        b.text = String(entries[i][0]) + "\n" + String(entries[i][1])
        b.custom_minimum_size = Vector2(76, 62)
        b.focus_mode = Control.FOCUS_NONE
        b.pressed.connect(_left_select.bind(i))
        box.add_child(b)
        left_buttons.append(b)

func _build_context_cards() -> void:
    selected_card = Panel.new()
    selected_card.add_theme_stylebox_override("panel", _style(PANEL_SOFT, BORDER, 14))
    root.add_child(selected_card)
    selected_title = Label.new()
    selected_title.text = "STARTING PROPERTY"
    selected_title.add_theme_font_size_override("font_size", 15)
    selected_title.add_theme_color_override("font_color", TEXT)
    selected_card.add_child(selected_title)
    selected_meta = Label.new()
    selected_meta.text = "Vacant warehouse  •  Restoration required"
    selected_meta.add_theme_font_size_override("font_size", 10)
    selected_meta.add_theme_color_override("font_color", MUTED)
    selected_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    selected_card.add_child(selected_meta)

    objective_card = Panel.new()
    objective_card.add_theme_stylebox_override("panel", _style(PANEL, BORDER_SOFT, 14))
    root.add_child(objective_card)
    var ot := Label.new()
    ot.text = "CURRENT OBJECTIVE"
    ot.add_theme_font_size_override("font_size", 9)
    ot.add_theme_color_override("font_color", ACCENT)
    objective_card.add_child(ot)
    objective_text = Label.new()
    objective_text.text = "Inspect your property and begin restoration."
    objective_text.add_theme_font_size_override("font_size", 11)
    objective_text.add_theme_color_override("font_color", TEXT)
    objective_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    objective_card.add_child(objective_text)

    right_card = Panel.new()
    right_card.add_theme_stylebox_override("panel", _style(PANEL, BORDER_SOFT, 14))
    root.add_child(right_card)
    right_title = Label.new()
    right_title.text = "CITY BRIEF"
    right_title.add_theme_font_size_override("font_size", 10)
    right_title.add_theme_color_override("font_color", ACCENT)
    right_card.add_child(right_title)
    right_body = Label.new()
    right_body.text = "Restore abandoned assets, open businesses, then grow your corporate network."
    right_body.add_theme_font_size_override("font_size", 10)
    right_body.add_theme_color_override("font_color", MUTED)
    right_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    right_card.add_child(right_body)

func _build_action_dock() -> void:
    action_dock = Panel.new()
    action_dock.add_theme_stylebox_override("panel", _style(Color("091920e8"), BORDER, 16))
    root.add_child(action_dock)

    action_title = Label.new()
    action_title.text = "LIVE COMMANDS"
    action_title.add_theme_font_size_override("font_size", 12)
    action_title.add_theme_color_override("font_color", TEXT)
    action_dock.add_child(action_title)

    action_subtitle = Label.new()
    action_subtitle.text = "Choose an action for the selected property."
    action_subtitle.add_theme_font_size_override("font_size", 9)
    action_subtitle.add_theme_color_override("font_color", MUTED)
    action_dock.add_child(action_subtitle)

    action_scroll = ScrollContainer.new()
    action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    action_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    action_dock.add_child(action_scroll)
    action_grid = GridContainer.new()
    action_grid.columns = 3
    action_grid.add_theme_constant_override("h_separation", 7)
    action_grid.add_theme_constant_override("v_separation", 7)
    action_scroll.add_child(action_grid)
    actions = action_grid

func _build_network_strip() -> void:
    network_strip = Panel.new()
    network_strip.add_theme_stylebox_override("panel", _style(PANEL, BORDER_SOFT, 14))
    root.add_child(network_strip)
    network_row = HBoxContainer.new()
    network_row.add_theme_constant_override("separation", 7)
    network_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    network_strip.add_child(network_row)

func _build_mobile_dock() -> void:
    bottom_mobile = Panel.new()
    bottom_mobile.add_theme_stylebox_override("panel", _style(Color("091920f5"), BORDER, 16))
    root.add_child(bottom_mobile)
    mobile_mode_row = HBoxContainer.new()
    mobile_mode_row.add_theme_constant_override("separation", 4)
    bottom_mobile.add_child(mobile_mode_row)
    for i in range(4):
        var b := Button.new()
        b.text = ["LIVE", "BUSINESS", "EMPIRE", "WORLD"][i]
        b.focus_mode = Control.FOCUS_NONE
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.pressed.connect(_set_tab.bind(i))
        mobile_mode_row.add_child(b)

    mobile_action_scroll = ScrollContainer.new()
    mobile_action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    mobile_action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    mobile_action_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    bottom_mobile.add_child(mobile_action_scroll)
    mobile_actions = GridContainer.new()
    mobile_actions.columns = 2
    mobile_actions.add_theme_constant_override("h_separation", 6)
    mobile_actions.add_theme_constant_override("v_separation", 6)
    mobile_action_scroll.add_child(mobile_actions)
    mobile_objective = Label.new()
    mobile_objective.add_theme_font_size_override("font_size", 10)
    mobile_objective.add_theme_color_override("font_color", TEXT)
    mobile_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    bottom_mobile.add_child(mobile_objective)

func _make_theme() -> Theme:
    var t := Theme.new()
    t.default_font_size = 11
    var normal := _style(Color("122b32"), BORDER_SOFT, 9)
    var hover := _style(Color("1c3d44"), ACCENT_SOFT, 9)
    var pressed := _style(Color("294f50"), ACCENT, 9)
    t.set_stylebox("normal", "Button", normal)
    t.set_stylebox("hover", "Button", hover)
    t.set_stylebox("pressed", "Button", pressed)
    t.set_stylebox("focus", "Button", hover)
    t.set_color("font_color", "Button", TEXT)
    t.set_color("font_hover_color", "Button", TEXT)
    t.set_color("font_pressed_color", "Button", TEXT)
    return t

func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(1)
    s.set_corner_radius_all(radius)
    s.content_margin_left = 12
    s.content_margin_right = 12
    s.content_margin_top = 8
    s.content_margin_bottom = 8
    return s

func _left_select(index: int) -> void:
    var tab := 0
    match index:
        0, 1: tab = 0
        2: tab = 1
        3: tab = 2
        4: tab = 3
    _set_tab(tab)

func _refresh() -> void:
    if parent == null or actions == null: return
    _clear_action_grids()
    var titles := ["RESTORE & PROPERTY", "BUSINESS OPERATIONS", "CORPORATE NETWORK", "WORLD & EMPIRE"]
    action_title.text = titles[active_tab]
    action_subtitle.text = [
        "Inspect, acquire and restore the property in front of you.",
        "Run production, customers, employees and contracts.",
        "Build alliances, finance growth and challenge rivals.",
        "Move across regions, events, history and the wider market."
    ][active_tab]

    match active_tab:
        0:
            _action("INSPECT PROPERTY", parent.inspect_property)
            _action("ACQUIRE PROPERTY", parent.acquire_property)
            _action("RESTORE PROPERTY", parent.restore_property)
            _action("OPEN BUSINESS", parent.open_business)
            _action("HEADQUARTERS", Callable(self, "_open_screen").bind("HeadquartersPanel"))
            _action("RESTORATION", Callable(self, "_open_screen").bind("CollectionPanel"))
        1:
            _action("BUY INPUTS", parent.buy_inputs)
            _action("PRODUCE GOODS", parent.produce_goods)
            _action("HIRE EMPLOYEE", parent.hire_employee)
            _action("UPGRADE BUSINESS", parent.upgrade_business)
            _action("MARKETING", parent.marketing_campaign)
            _action("CHANGE PRICE", parent.change_price)
            _action("CUSTOMERS", Callable(self, "_open_screen").bind("CustomerSegmentsUI"))
            _action("CONTRACTS", Callable(self, "_open_screen").bind("ContractPanel"))
            _action("EMPLOYEES", Callable(self, "_open_screen").bind("EmployeePanel"))
        2:
            _action("NEXT RIVAL", _next_rival)
            _action("ALLIANCE OFFER", parent.make_alliance_offer)
            _action("IMPROVE RELATION", parent.improve_alliance)
            _action("SUPPLY DEAL", parent.propose_supply_deal)
            _action("CUSTOMER PARTNERSHIP", parent.propose_customer_partnership)
            _action("ACQUIRE TARGET", parent.negotiate_selected_acquisition)
            _action("TAKE LOAN", parent.take_loan)
            _action("REPAY LOAN", parent.repay_loan)
            _action("ALLIANCE COUNCIL", Callable(self, "_open_screen").bind("AlliancePanel"))
            _action("DIPLOMACY", Callable(self, "_open_screen").bind("RenewDiplomacyUI"))
            _action("TECHNOLOGY", Callable(self, "_open_screen").bind("TechnologyPanel"))
        3:
            _action("MARKET", Callable(self, "_open_screen").bind("MarketPanel"))
            _action("INFRASTRUCTURE", Callable(self, "_open_screen").bind("HeadquartersPanel"))
            _action("TECHNOLOGY", Callable(self, "_open_screen").bind("TechnologyPanel"))
            _action("NEWS", Callable(self, "_open_screen").bind("NewsPanel"))
            _action("HISTORY", Callable(self, "_open_screen").bind("HistoryPanel"))
            _action("LIVE OPS", Callable(self, "_open_screen").bind("LiveOpsPanel"))
            _action("SAVE GAME", parent.save_game)
            _action("LOAD GAME", parent.load_game)
    _action("END DAY", parent.advance_day)
    _apply_state()
    _sync_mobile_actions()
    call_deferred("_layout_responsive")

func _action(text: String, callback: Callable) -> void:
    if not callback.is_valid(): return
    var b := Button.new()
    b.text = text
    b.theme = button_theme
    b.focus_mode = Control.FOCUS_NONE
    b.mouse_filter = Control.MOUSE_FILTER_STOP
    b.custom_minimum_size = Vector2(150, 42)
    b.pressed.connect(_run_action.bind(text, callback))
    action_grid.add_child(b)

func _sync_mobile_actions() -> void:
    for child in mobile_actions.get_children(): child.queue_free()
    for child in action_grid.get_children():
        var src := child as Button
        if src == null: continue
        var b := Button.new()
        b.text = src.text
        b.theme = button_theme
        b.focus_mode = Control.FOCUS_NONE
        b.custom_minimum_size = Vector2(0, 44)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.pressed.connect(_run_action.bind(src.text, _find_action_callback(src.text)))
        mobile_actions.add_child(b)
    mobile_objective.text = "OBJECTIVE  •  " + objective_text.text

func _find_action_callback(label: String) -> Callable:
    for child in action_grid.get_children():
        if child is Button and child.text == label:
            var signal_list := child.pressed.get_connections()
            if not signal_list.is_empty():
                return signal_list[0].callable.get_unbound(0) if false else Callable(self, "_run_action")
    return Callable()

func _clear_action_grids() -> void:
    for child in action_grid.get_children(): child.queue_free()
    for child in mobile_actions.get_children(): child.queue_free()

func _open_screen(screen_name: String) -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("show_screen"):
        manager.show_screen(screen_name)
        _show_feedback("OPENED: %s" % screen_name.replace("Panel", "").replace("UI", ""))
    else:
        _show_feedback("Screen manager is unavailable.")

func _run_action(label: String, callback: Callable) -> void:
    if parent == null or not callback.is_valid():
        _show_feedback(label + "\nAction is unavailable.")
        return
    var before_cash := int(parent.cash)
    var before_rep := int(parent.reputation)
    var before_day := int(parent.day)
    var before_message := String(parent.message)
    var result: Variant = callback.call()
    var message := ""
    if result is Dictionary and result.has("message"): message = String(result["message"])
    if message.is_empty() and String(parent.message) != before_message: message = String(parent.message)
    if message.is_empty(): message = label + " completed."
    var changes: Array[String] = []
    var dc := int(parent.cash) - before_cash
    var dr := int(parent.reputation) - before_rep
    if dc != 0: changes.append("Cash %s$%s" % [("+" if dc > 0 else "-"), _money(abs(dc))])
    if dr != 0: changes.append("REP %s%d" % [("+" if dr > 0 else ""), dr])
    if int(parent.day) != before_day: changes.append("Day %d" % int(parent.day))
    if not changes.is_empty(): message += "\n" + "  •  ".join(changes)
    _show_feedback(message)
    _refresh()
    _detect_milestones()

func _apply_state() -> void:
    for i in range(mode_buttons.size()):
        _button_state(mode_buttons[i], i == active_tab)
    for i in range(left_buttons.size()):
        var selected := (i <= 1 and active_tab == 0) or (i == 2 and active_tab == 1) or (i == 3 and active_tab == 2) or (i == 4 and active_tab == 3)
        _button_state(left_buttons[i], selected)

func _button_state(b: Button, active: bool) -> void:
    b.theme = button_theme
    b.add_theme_stylebox_override("normal", _style(Color("27494d") if active else Color("10262d"), ACCENT if active else BORDER_SOFT, 9))
    b.add_theme_color_override("font_color", TEXT if active else MUTED)

func _process(delta: float) -> void:
    if parent == null: return
    cash_label.text = "$" + _money(int(parent.cash))
    rep_label.text = "REP " + str(int(parent.reputation))
    day_label.text = "DAY " + str(int(parent.day))
    location_label.text = _location_text()
    selected_title.text = _selected_title()
    selected_meta.text = _selected_meta()
    objective_text.text = _objective_text()
    mobile_objective.text = "OBJECTIVE  •  " + objective_text.text
    _apply_state()
    if feedback_timer > 0.0:
        feedback_timer -= delta
        if feedback_timer <= 0.0 and feedback_panel != null: feedback_panel.hide()

func _location_text() -> String:
    match active_tab:
        0: return "RESTORATION DISTRICT  •  PROPERTY VIEW"
        1: return "RESTORATION DISTRICT  •  BUSINESS VIEW"
        2: return "CITY REGION  •  CORPORATE NETWORK"
        3: return "WORLD MAP  •  REGIONAL OVERVIEW"
    return "RENEW"

func _selected_title() -> String:
    if parent == null: return "STARTING PROPERTY"
    if active_tab == 2 and parent.rivals != null and not parent.rivals.rivals.is_empty():
        var r: Dictionary = parent.rivals.rivals[int(parent.selected_rival) % parent.rivals.rivals.size()]
        return str(r.get("name", "CORPORATE RIVAL"))
    if active_tab == 1 and bool(parent.business_open): return "OPERATING BUSINESS"
    return "STARTING PROPERTY"

func _selected_meta() -> String:
    if parent == null: return ""
    if active_tab == 0: return "%s  •  Cash $%s  •  Restoration stage" % [str(parent.stage), _money(int(parent.cash))]
    if active_tab == 1: return "Production, employees and customer demand  •  Business %s" % ["OPEN" if bool(parent.business_open) else "CLOSED"]
    if active_tab == 2: return "Relationship network  •  Rival %d  •  REP %d" % [int(parent.selected_rival) + 1, int(parent.reputation)]
    return "Regions, market events and expansion  •  Day %d" % int(parent.day)

func _objective_text() -> String:
    if parent == null: return "Inspect your property and begin restoration."
    if not bool(parent.owned): return "Inspect → acquire the abandoned property."
    if String(parent.stage) != "Operational": return "Restore the property through its next phase."
    if not bool(parent.business_open): return "Open the business and establish cash flow."
    if int(parent.total_profit) <= 0: return "Operate efficiently and reach your first profit."
    return "Reinvest profits, strengthen alliances and expand."

func _layout_responsive() -> void:
    if root == null: return
    var s := root.size
    var w := maxf(s.x, 320.0)
    var h := maxf(s.y, 480.0)
    narrow = w < 760.0

    # Desktop: Sims-like world-first composition.
    top_strip.position = Vector2(16, 14)
    top_strip.size = Vector2(w - 32, 58)
    brand.position = Vector2(14, 7)
    brand.size = Vector2(100, 30)
    location_label.position = Vector2(116, 11)
    location_label.size = Vector2(maxf(180, w - 500), 28)
    cash_label.position = Vector2(w - 360, 7)
    cash_label.size = Vector2(105, 30)
    rep_label.position = Vector2(w - 250, 7)
    rep_label.size = Vector2(90, 30)
    day_label.position = Vector2(w - 150, 7)
    day_label.size = Vector2(120, 30)

    if narrow:
        top_strip.position = Vector2(8, 8)
        top_strip.size = Vector2(w - 16, 50)
        brand.position = Vector2(9, 3)
        brand.size = Vector2(90, 30)
        brand.add_theme_font_size_override("font_size", 18)
        location_label.visible = false
        cash_label.position = Vector2(w - 230, 5)
        cash_label.size = Vector2(80, 28)
        rep_label.position = Vector2(w - 150, 5)
        rep_label.size = Vector2(70, 28)
        day_label.visible = false
        mode_rail.visible = false
        left_rail.visible = false
        selected_card.visible = false
        objective_card.visible = false
        right_card.visible = false
        network_strip.visible = false
        action_dock.visible = false
        bottom_mobile.visible = true
        bottom_mobile.position = Vector2(8, h - minf(260.0, h * 0.43))
        bottom_mobile.size = Vector2(w - 16, minf(252.0, h * 0.42))
        mobile_mode_row.position = Vector2(7, 7)
        mobile_mode_row.size = Vector2(w - 30, 42)
        mobile_action_scroll.position = Vector2(7, 54)
        mobile_action_scroll.size = Vector2(w - 30, bottom_mobile.size.y - 102)
        mobile_objective.position = Vector2(10, bottom_mobile.size.y - 42)
        mobile_objective.size = Vector2(w - 36, 35)
        for child in mobile_mode_row.get_children():
            child.custom_minimum_size.y = 38
    else:
        brand.add_theme_font_size_override("font_size", 22)
        location_label.visible = true
        day_label.visible = true
        mode_rail.visible = true
        left_rail.visible = true
        selected_card.visible = true
        objective_card.visible = true
        right_card.visible = true
        network_strip.visible = true
        action_dock.visible = true
        bottom_mobile.visible = false

        mode_rail.position = Vector2(16, 82)
        mode_rail.size = Vector2(400, 44)
        left_rail.position = Vector2(16, 136)
        left_rail.size = Vector2(90, 340)

        selected_card.position = Vector2(124, h - 182)
        selected_card.size = Vector2(minf(285, w * 0.25), 78)
        selected_title.position = Vector2(12, 8)
        selected_title.size = Vector2(selected_card.size.x - 24, 25)
        selected_meta.position = Vector2(12, 36)
        selected_meta.size = Vector2(selected_card.size.x - 24, 34)

        objective_card.position = Vector2(124, 82)
        objective_card.size = Vector2(minf(350, w * 0.30), 62)
        var ot := objective_card.get_child(0) as Label
        ot.position = Vector2(12, 7)
        ot.size = Vector2(objective_card.size.x - 24, 18)
        objective_text.position = Vector2(12, 25)
        objective_text.size = Vector2(objective_card.size.x - 24, 30)

        right_card.position = Vector2(w - 246, 82)
        right_card.size = Vector2(230, 104)
        right_title.position = Vector2(12, 8)
        right_title.size = Vector2(206, 20)
        right_body.position = Vector2(12, 30)
        right_body.size = Vector2(206, 62)

        action_dock.position = Vector2(124, h - 96)
        action_dock.size = Vector2(w - 390, 80)
        action_title.position = Vector2(12, 7)
        action_title.size = Vector2(180, 20)
        action_subtitle.position = Vector2(12, 28)
        action_subtitle.size = Vector2(205, 42)
        action_scroll.position = Vector2(225, 7)
        action_scroll.size = Vector2(maxf(160, action_dock.size.x - 235), 66)
        action_grid.columns = 3
        for child in action_grid.get_children():
            if child is Button: child.custom_minimum_size = Vector2(142, 44)

        network_strip.position = Vector2(w - 246, 194)
        network_strip.size = Vector2(230, 128)
        network_row.position = Vector2(8, 8)
        network_row.size = Vector2(214, 112)

func _clear_actions() -> void:
    _clear_action_grids()

func _next_rival() -> void:
    if parent != null and parent.rivals != null and not parent.rivals.rivals.is_empty():
        parent.select_rival((int(parent.selected_rival) + 1) % parent.rivals.rivals.size())

func _update_panel_visibility() -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"):
        manager.hide_all_screens()

    var renew := get_tree().root.get_node_or_null("Renew")
    if renew == null: return
    var world := renew.get_node_or_null("World")
    if world == null: return
    _set_world_visible(world.get_node_or_null("WorldView"), active_tab == 3)
    _set_world_visible(world.get_node_or_null("PropertyVisual"), active_tab == 0)
    _set_world_visible(world.get_node_or_null("RegionController"), active_tab == 3)
    _set_world_visible(world.get_node_or_null("EmpireController"), active_tab == 2)
    _set_world_visible(world.get_node_or_null("Corporate"), active_tab == 2)
    _set_world_visible(world.get_node_or_null("WorldMissions"), active_tab == 3)
    _set_world_visible(world.get_node_or_null("RivalSupplyController"), active_tab == 3)
    _set_world_visible(world.get_node_or_null("BranchController"), active_tab in [1, 3])
    _set_world_visible(world.get_node_or_null("MainRenderer"), false)

func _set_world_visible(node: Node, value: bool) -> void:
    if node == null: return
    if node is CanvasItem:
        node.visible = value
    else:
        for child in node.get_children(): _set_world_visible(child, value)
