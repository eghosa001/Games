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
var left_rail: Panel
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
var bottom_mobile: Panel
var mobile_actions: GridContainer
var mobile_objective: Label
var narrow: bool = false

const BG := Color("071217")
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
    for i in range(4):
        var b := Button.new()
        b.text = ["LIVE", "BUSINESS", "EMPIRE", "WORLD"][i]
        b.focus_mode = Control.FOCUS_NONE
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.pressed.connect(_set_tab.bind(i))
        mode_row.add_child(b)

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

    network_strip = Panel.new(); network_strip.add_theme_stylebox_override("panel", _style(PANEL, BORDER_SOFT, 12)); root.add_child(network_strip)

    bottom_mobile = Panel.new(); bottom_mobile.visible = false; root.add_child(bottom_mobile)
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

func _set_tab(index: int) -> void:
    active_tab = clampi(index, 0, 3); _refresh()

func _clear_action_grids() -> void:
    if action_grid == null: return
    for child in action_grid.get_children(): child.queue_free()

func _action(text: String, callback: Callable) -> void:
    if action_grid == null or not callback.is_valid(): return
    var b := Button.new(); b.text = text; b.focus_mode = Control.FOCUS_NONE; b.custom_minimum_size = Vector2(140, 44); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.pressed.connect(_run_action.bind(text, callback)); action_grid.add_child(b)

func _run_action(label: String, callback: Callable) -> void:
    if parent == null or not callback.is_valid(): return
    var result = callback.call()
    if result is Dictionary and result.has("message"): parent.message = str(result["message"])
    _refresh()

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
            _action("INSPECT", parent.inspect_property); _action("ACQUIRE", parent.acquire_property); _action("RESTORE", parent.restore_property); _action("OPEN BUSINESS", parent.open_business); _action("END DAY", parent.advance_day)
        1:
            _action("BUY INPUTS", parent.buy_inputs); _action("PRODUCE", parent.produce_goods); _action("HIRE", parent.hire_employee); _action("UPGRADE", parent.upgrade_business); _action("MARKETING", parent.marketing_campaign); _action("PRICE", parent.change_price); _action("CONTRACT", parent.sign_contract); _action("END DAY", parent.advance_day)
        2:
            _action("NEXT RIVAL", _next_rival); _action("ALLIANCE", parent.make_alliance_offer); _action("RELATION", parent.improve_alliance); _action("SUPPLY DEAL", parent.propose_supply_deal); _action("ACQUIRE", parent.negotiate_selected_acquisition); _action("LOAN", parent.take_loan); _action("REPAY", parent.repay_loan); _action("END DAY", parent.advance_day)
        3:
            _action("EXPANSION", parent.buy_expansion); _action("UPGRADE", parent.upgrade_expansion); _action("TRANSPORT", parent.upgrade_transport); _action("SAVE", parent.save_game); _action("LOAD", parent.load_game); _action("END DAY", parent.advance_day)

func _process(_delta: float) -> void:
    if parent == null: return
    cash_label.text = "$%s" % _money(int(parent.cash))
    rep_label.text = "REP %d" % int(parent.reputation)
    day_label.text = "DAY %d" % int(parent.day)

func _money(value: int) -> String:
    return String.num_int64(value)
