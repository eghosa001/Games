extends CanvasLayer

# Canonical responsive presentation base for renew_sims_ui_final.gd.
# This layer owns presentation only; all gameplay state and commands remain on Main.

var parent: Node
var active_tab: int = 0
var root: Control
var top_strip: Panel
var brand: Label
var location_label: Label
var cash_label: Label
var rep_label: Label
var day_label: Label
var mode_rail: Panel
var tabs: HBoxContainer
var mode_buttons: Array = []
var left_rail: Panel
var selected_card: Panel
var selected_title: Label
var selected_meta: Label
var objective_card: Panel
var right_card: Panel
var objective_text: Label
var action_dock: Panel
var action_title: Label
var action_subtitle: Label
var action_grid: GridContainer
var actions: GridContainer
var action_scroll: ScrollContainer
var network_strip: Panel
var status_surface: Panel
var bottom_mobile: Panel
var mobile_actions: GridContainer
var mobile_objective: Label
var status_label: Label
var goal_label: Label
var feedback_panel: Panel
var feedback_label: Label
var feedback_timer: float = 0.0
var narrow: bool = false

const PANEL := Color("0b1b22e6")
const BORDER := Color("31545c")
const BORDER_SOFT := Color("24434b")
const TEXT := Color("edf6f3")
const MUTED := Color("8da7aa")
const ACCENT := Color("d8b76d")

func _ready() -> void:
    parent = get_tree().root.get_node_or_null("Renew")
    _build_ui()
    call_deferred("_initialize")

func _initialize() -> void:
    parent = get_tree().root.get_node_or_null("Renew")
    if parent == null: return
    _layout_responsive()
    _refresh()
    if not get_viewport().size_changed.is_connected(_layout_responsive):
        get_viewport().size_changed.connect(_layout_responsive)

func _build_ui() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    top_strip = Panel.new()
    top_strip.add_theme_stylebox_override("panel", _style(PANEL, BORDER_SOFT, 12))
    root.add_child(top_strip)
    brand = _label("RENEW", 19, TEXT)
    location_label = _label("RESTORATION DISTRICT  •  HEADQUARTERS", 9, MUTED)
    cash_label = _label("$0", 11, TEXT)
    rep_label = _label("REP 0", 11, TEXT)
    day_label = _label("DAY 1", 11, TEXT)
    top_strip.add_child(brand); top_strip.add_child(location_label); top_strip.add_child(cash_label); top_strip.add_child(rep_label); top_strip.add_child(day_label)

    mode_rail = Panel.new()
    mode_rail.add_theme_stylebox_override("panel", _style(PANEL, BORDER_SOFT, 10))
    root.add_child(mode_rail)
    var mode_row := HBoxContainer.new()
    mode_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mode_rail.add_child(mode_row)
    tabs = mode_row
    mode_buttons.clear()
    for i in range(4):
        var b := Button.new()
        b.text = ["LIVE", "BUSINESS", "EMPIRE", "WORLD"][i]
        b.focus_mode = Control.FOCUS_NONE
        b.custom_minimum_size = Vector2(44, 44)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.pressed.connect(_set_tab.bind(i))
        mode_row.add_child(b)
        mode_buttons.append(b)

    left_rail = Panel.new()
    left_rail.add_theme_stylebox_override("panel", _style(PANEL, BORDER_SOFT, 10))
    root.add_child(left_rail)
    var left_box := VBoxContainer.new()
    left_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    left_rail.add_child(left_box)
    for i in range(4):
        var b := Button.new()
        b.text = ["HOME", "BUSINESS", "EMPIRE", "WORLD"][i]
        b.custom_minimum_size = Vector2(76, 52)
        b.focus_mode = Control.FOCUS_NONE
        b.pressed.connect(_set_tab.bind(i))
        left_box.add_child(b)

    selected_card = Panel.new(); selected_card.add_theme_stylebox_override("panel", _style(PANEL, BORDER_SOFT, 12)); root.add_child(selected_card)
    selected_title = _label("STARTING PROPERTY", 14, TEXT); selected_meta = _label("Restoration required", 10, MUTED); selected_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    selected_card.add_child(selected_title); selected_card.add_child(selected_meta)

    objective_card = Panel.new(); objective_card.add_theme_stylebox_override("panel", _style(PANEL, BORDER_SOFT, 12)); root.add_child(objective_card)
    objective_text = _label("Inspect your property and begin restoration.", 10, TEXT); objective_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; objective_card.add_child(objective_text)

    action_dock = Panel.new(); action_dock.add_theme_stylebox_override("panel", _style(Color("091920f2"), BORDER, 14)); root.add_child(action_dock)
    action_title = _label("LIVE COMMANDS", 12, TEXT); action_subtitle = _label("Choose an action.", 9, MUTED); action_dock.add_child(action_title); action_dock.add_child(action_subtitle)
    action_scroll = ScrollContainer.new(); action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; action_dock.add_child(action_scroll)
    action_grid = GridContainer.new(); action_grid.columns = 3; action_grid.add_theme_constant_override("h_separation", 7); action_grid.add_theme_constant_override("v_separation", 7); action_scroll.add_child(action_grid)
    actions = action_grid

    network_strip = Panel.new(); network_strip.add_theme_stylebox_override("panel", _style(PANEL, BORDER_SOFT, 12)); root.add_child(network_strip)

    # Desktop status/feedback live outside the command dock. Ground this area so
    # the world renderer cannot visually bleed through the executive status rail.
    status_surface = Panel.new()
    status_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
    status_surface.add_theme_stylebox_override("panel", _style(Color("091920f2"), BORDER_SOFT, 10))
    root.add_child(status_surface)

    bottom_mobile = Panel.new(); bottom_mobile.visible = false; root.add_child(bottom_mobile)
    status_label = _label("", 10, TEXT); status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(status_label)
    feedback_panel = Panel.new(); feedback_panel.add_theme_stylebox_override("panel", _style(PANEL, BORDER, 10)); feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; feedback_panel.visible = false; root.add_child(feedback_panel)
    feedback_label = _label("", 10, TEXT); feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; feedback_panel.add_child(feedback_label)
    goal_label = _label("", 10, MUTED); goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; goal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(goal_label)
    mobile_actions = GridContainer.new(); mobile_objective = _label("", 10, TEXT); bottom_mobile.add_child(mobile_actions); bottom_mobile.add_child(mobile_objective)

func _label(text: String, size: int, color: Color) -> Label:
    var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", color); l.mouse_filter = Control.MOUSE_FILTER_IGNORE; return l

func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
    var s := StyleBoxFlat.new(); s.bg_color = bg; s.border_color = border; s.set_border_width_all(1); s.set_corner_radius_all(radius); s.content_margin_left = 10; s.content_margin_right = 10; s.content_margin_top = 7; s.content_margin_bottom = 7; return s

func _layout_responsive() -> void:
    if root == null: return
    var size := root.size
    var w := maxf(size.x, 320.0)
    var h := maxf(size.y, 480.0)
    narrow = w < 700.0
    top_strip.position = Vector2(8, 8); top_strip.size = Vector2(w - 16, 50)
    brand.position = Vector2(10, 5); brand.size = Vector2(80, 32)
    location_label.position = Vector2(92, 12); location_label.size = Vector2(maxf(80.0, w - 330.0), 24); location_label.visible = not narrow
    cash_label.position = Vector2(w - 235, 8); cash_label.size = Vector2(72, 28)
    rep_label.position = Vector2(w - 155, 8); rep_label.size = Vector2(65, 28)
    day_label.position = Vector2(w - 78, 8); day_label.size = Vector2(65, 28)
    mode_rail.position = Vector2(8, 64); mode_rail.size = Vector2(w - 16, 42)
    left_rail.visible = not narrow
    left_rail.position = Vector2(8, 116); left_rail.size = Vector2(88, 220)
    selected_card.visible = not narrow
    selected_card.position = Vector2(108, 116); selected_card.size = Vector2(minf(330.0, w * 0.30), 92)
    selected_title.position = Vector2(10, 8); selected_title.size = Vector2(selected_card.size.x - 20, 28)
    selected_meta.position = Vector2(10, 40); selected_meta.size = Vector2(selected_card.size.x - 20, 44)
    objective_card.visible = not narrow
    objective_card.position = Vector2(450, 116); objective_card.size = Vector2(minf(330.0, w * 0.30), 92)
    objective_text.position = Vector2(10, 10); objective_text.size = objective_card.size - Vector2(20, 20)
    network_strip.visible = not narrow
    network_strip.position = Vector2(w - 250, 216); network_strip.size = Vector2(242, 82)
    action_dock.position = Vector2(108 if not narrow else 8, 220 if not narrow else h - clampf(h * 0.40, 218.0, 250.0) - 8)
    action_dock.size = Vector2(w - (116 if not narrow else 16), (h - 228) if not narrow else clampf(h * 0.40, 218.0, 250.0))
    action_title.position = Vector2(10, 7); action_title.size = Vector2(action_dock.size.x - 20, 20)
    action_subtitle.position = Vector2(10, 28); action_subtitle.size = Vector2(action_dock.size.x - 20, 20)
    action_scroll.position = Vector2(8, 50); action_scroll.size = Vector2(action_dock.size.x - 16, action_dock.size.y - 58)
    action_grid.columns = 2 if narrow else 3
    if narrow:
        status_surface.visible = false
        status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        status_label.position = Vector2(8, 108); status_label.size = Vector2(w - 16, 36)
        feedback_panel.position = Vector2(8, 148); feedback_panel.size = Vector2(w - 16, 56)
        feedback_label.position = Vector2(10, 8); feedback_label.size = Vector2(maxf(40.0, w - 52.0), 40)
        goal_label.position = Vector2(8, 208); goal_label.size = Vector2(w - 16, 40)
    else:
        status_surface.visible = true
        status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
        var dock_bottom := action_dock.position.y + action_dock.size.y
        var max_y := maxf(0.0, h - 4.0)
        status_surface.position = Vector2(4, h * 0.76)
        status_surface.size = Vector2(minf(460.0, maxf(320.0, w * 0.36)), maxf(80.0, h * 0.24))
        status_label.position = Vector2(8, minf(dock_bottom + 4.0, max_y - 24.0))
        status_label.size = Vector2(minf(360.0, w - 16.0), 24)
        feedback_panel.position = Vector2(8, minf(status_label.position.y + 32.0, max_y - 80.0))
        feedback_panel.size = Vector2(300, 80)
        feedback_label.position = Vector2(10, 8)
        feedback_label.size = Vector2(280, 64)
        goal_label.position = Vector2(8, minf(feedback_panel.position.y + 88.0, max_y - 44.0))
        goal_label.size = Vector2(300, 44)

func _set_tab(index: int) -> void:
    active_tab = clampi(index, 0, 3); _refresh()

func _clear_action_grids() -> void:
    if action_grid == null: return
    for child in action_grid.get_children(): child.queue_free()

func _action(text: String, callback: Callable) -> void:
    if action_grid == null or not callback.is_valid(): return
    var b := Button.new(); b.text = text; b.focus_mode = Control.FOCUS_NONE; b.custom_minimum_size = Vector2(140, 44); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.pressed.connect(_run_action.bind(callback)); action_grid.add_child(b)

func _run_action(callback: Callable) -> void:
    if parent == null or not callback.is_valid(): return
    var result = callback.call()
    if result is Dictionary and result.has("message"): parent.message = str(result["message"])
    if str(parent.message) != "": show_feedback(str(parent.message))
    _refresh()

func show_feedback(text: String) -> void:
    if feedback_label == null or feedback_panel == null: return
    feedback_label.text = text
    feedback_panel.show()
    feedback_timer = 7.0

func _goal_text() -> String:
    if parent == null: return "GOAL: Build your restoration empire."
    if not bool(parent.owned): return "GOAL: Inspect and acquire the abandoned property."
    if str(parent.stage) != "Operational": return "GOAL: Restore the property (%d%% complete)." % int(parent.restoration)
    if not bool(parent.business_open): return "GOAL: Choose a purpose and open your first business."
    return "GOAL: Produce, sell and expand your empire."

func _open_screen(screen_name: String) -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("show_screen"):
        manager.show_screen(screen_name)
    else:
        var scene := get_tree().current_scene if get_tree() != null else null
        if scene != null:
            var node := scene.get_node_or_null("UI/" + screen_name)
            if node != null: node.show()

func _selected_title() -> String:
    if parent == null: return "RENEW"
    return "%s" % str(parent.stage).to_upper()

func _selected_meta() -> String:
    if parent == null: return ""
    return "Property %s  •  Restoration %d%%  •  Business %s" % ["OWNED" if parent.owned else "AVAILABLE", int(parent.restoration), "OPEN" if parent.business_open else "CLOSED"]

func _next_rival() -> void:
    if parent != null and parent.rivals != null and not parent.rivals.rivals.is_empty(): parent.select_rival((int(parent.selected_rival) + 1) % parent.rivals.rivals.size())

func _refresh() -> void:
    if parent == null or action_grid == null: return
    _clear_action_grids()
    var titles := ["PROPERTY & RESTORATION", "BUSINESS OPERATIONS", "CORPORATE NETWORK", "WORLD & EMPIRE"]
    action_title.text = titles[active_tab]
    match active_tab:
        0:
            _action("INSPECT", parent.inspect_property); _action("ACQUIRE", parent.acquire_property); _action("RESTORE", parent.restore_property); _action("SELL", parent.sell_property); _action("LEASE", parent.lease_property); _action("OPEN BUSINESS", parent.open_business); _action("DASHBOARD", Callable(self, "_open_screen").bind("DashboardPanel")); _action("ASSETS", Callable(self, "_open_screen").bind("PortfolioPanel")); _action("END DAY", parent.advance_day)
        1:
            _action("BUY INPUTS", parent.buy_inputs); _action("IMPORT", parent.buy_international); _action("PRODUCE", parent.produce_goods); _action("HIRE", parent.hire_employee); _action("UPGRADE", parent.upgrade_business); _action("MARKETING", parent.marketing_campaign); _action("PRICE", parent.change_price); _action("CONTRACT", parent.sign_contract); _action("HAGGLE", parent.haggle_contract); _action("EXCLUSIVE", parent.sign_exclusive_contract); _action("GOVT DEAL", parent.sign_government_contract); _action("BUILD DEAL", parent.sign_construction_contract); _action("EXPORT DEAL", parent.sign_export_contract); _action("FINANCE", Callable(self, "_open_screen").bind("FinancePanel")); _action("DEALS", Callable(self, "_open_screen").bind("ContractPanel")); _action("STAFF", Callable(self, "_open_screen").bind("EmployeePanel")); _action("END DAY", parent.advance_day)
        2:
            _action("NEXT RIVAL", _next_rival); _action("ALLIANCE", parent.make_alliance_offer); _action("RELATION", parent.improve_alliance); _action("COMPETE", parent.compete_alliance); _action("GOALS", parent.victory_progress); _action("REPUTE", parent.reputation_status); _action("SUPPLY DEAL", parent.propose_supply_deal); _action("ACQUIRE", parent.negotiate_selected_acquisition); _action("BID BATTLE", parent.start_acquisition_battle); _action("RAISE BID", parent.raise_acquisition_bid); _action("WALK AWAY", parent.walk_away_acquisition); _action("BUY SHARES", parent.buy_rival_shares); _action("SELL SHARES", parent.sell_rival_shares); _action("LOAN", parent.take_loan); _action("REPAY", parent.repay_loan); _action("INVESTOR", parent.request_investment); _action("ACCEPT DEAL", parent.accept_investment); _action("DECLINE DEAL", parent.decline_investment); _action("INVEST BILL", parent.invest_term); _action("DIVIDEND", parent.pay_dividend); _action("GO PUBLIC", parent.go_public); _action("CAP TABLE", parent.cap_table); _action("POWER", parent.world_power); _action("NETWORK", Callable(self, "_open_screen").bind("CorporationsPanel")); _action("PACT", Callable(self, "_open_screen").bind("AlliancePanel")); _action("END DAY", parent.advance_day)
        3:
            _action("EXPANSION", parent.buy_expansion); _action("UPGRADE", parent.upgrade_expansion); _action("TRANSPORT", parent.upgrade_transport); _action("NEXT REGION", parent.next_region); _action("ESTABLISH", parent.establish_region); _action("CHARTER BASIN", parent.charter_basin); _action("CHARTER VALLEY", parent.charter_valley); _action("TRADE ROUTE", parent.establish_trade_route); _action("DISPATCH", parent.dispatch_goods); _action("INFRA BUILD", parent.infra_build); _action("INFRA TYPE", parent.infra_type); _action("INFRA REPAIR", parent.infra_repair); _action("SAVE", parent.save_game); _action("LOAD", parent.load_game); _action("NEW COMPANY", parent.found_new_company); _action("IDENTITY", parent.identity_status); _action("NOTICES", parent.check_notifications); _action("TECH", Callable(self, "_open_screen").bind("TechnologyPanel")); _action("NEWS", Callable(self, "_open_screen").bind("NewsPanel")); _action("PAST", Callable(self, "_open_screen").bind("HistoryPanel")); _action("END DAY", parent.advance_day)

func _process(delta: float) -> void:
    if parent == null: return
    cash_label.text = "$%s" % _money(int(parent.cash))
    rep_label.text = "REP %d" % int(parent.reputation)
    day_label.text = "DAY %d" % int(parent.day)
    if status_label != null:
        status_label.text = "CASH $%s   |   REP %d   |   DAY %d" % [_money(int(parent.cash)), int(parent.reputation), int(parent.day)]
    if goal_label != null:
        goal_label.text = _goal_text()
    if feedback_timer > 0.0:
        feedback_timer -= delta
        if feedback_timer <= 0.0 and feedback_panel != null:
            feedback_panel.hide()

func _money(value: int) -> String:
    return String.num_int64(value)