extends CanvasLayer

## Command dashboard: overview, next objective, live operations, recent
## events. Reads authoritative systems; actions route through Main.
var dimmer: ColorRect
var panel: Panel
var title_label: Label
var status_label: Label
var overview_label: Label
var objective_label: Label
var ops_label: Label
var events_label: Label
var primary_button: Button
var notices_button: Button
var close_button: Button
var refresh_clock := 0.0
var last_signature := ""

const SURFACE := Color("0d2028")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56e")
const SCRIM := Color(0.02, 0.08, 0.10, 0.72)

func _ready() -> void:
    layer = 63
    _build_ui()
    _refresh(true)
    if not get_viewport().size_changed.is_connected(_layout):
        get_viewport().size_changed.connect(_layout)

func _process(delta: float) -> void:
    if not visible:
        return
    refresh_clock += delta
    if refresh_clock >= 1.0:
        refresh_clock = 0.0
        _refresh(false)

func _game():
    return get_tree().current_scene if get_tree() != null else null

func _state():
    return get_node_or_null("/root/RenewGameState")

func _finance():
    return get_node_or_null("/root/RenewFinanceSystem")

func _style(bg: Color, border: Color, radius := 12) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    return style

func _build_ui() -> void:
    dimmer = ColorRect.new()
    dimmer.name = "DashboardModalScrim"
    dimmer.color = SCRIM
    dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dimmer)

    panel = Panel.new()
    panel.name = "DashboardPanel"
    panel.add_theme_stylebox_override("panel", _style(SURFACE, BORDER, 14))
    add_child(panel)

    title_label = _label("DASHBOARD", 20, TEXT)
    status_label = _label("COMMAND OVERVIEW", 10, ACCENT)
    overview_label = _label("", 12, TEXT)
    objective_label = _label("", 12, ACCENT)
    ops_label = _label("", 11, MUTED)
    events_label = _label("", 11, MUTED)

    primary_button = _button("CONTINUE")
    primary_button.pressed.connect(_primary)
    notices_button = _button("NOTICES")
    notices_button.pressed.connect(_notices)
    close_button = _button("CLOSE")
    close_button.pressed.connect(_close)
    _layout()

func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    panel.add_child(label)
    return label

func _button(text: String) -> Button:
    var button := Button.new()
    button.text = text
    button.focus_mode = Control.FOCUS_NONE
    button.clip_text = true
    button.custom_minimum_size = Vector2(0, 46)
    panel.add_child(button)
    return button

func _layout() -> void:
    if get_viewport() == null or panel == null:
        return
    var viewport: Vector2 = get_viewport().size
    var margin := 12.0 if viewport.x < 390.0 else 16.0
    var width := minf(560.0, maxf(280.0, viewport.x - margin * 2.0))
    var height := minf(600.0, maxf(420.0, viewport.y - 96.0))
    dimmer.position = Vector2.ZERO
    dimmer.size = viewport
    panel.position = Vector2((viewport.x - width) / 2.0, maxf(48.0, (viewport.y - height) / 2.0))
    panel.size = Vector2(width, minf(height, viewport.y - panel.position.y - 12.0))

    var compact := width < 390.0
    var side := 14.0
    title_label.position = Vector2(side, 12)
    title_label.size = Vector2(width - 140.0, 28)
    title_label.add_theme_font_size_override("font_size", 18 if compact else 20)
    status_label.position = Vector2(width - 126.0, 14)
    status_label.size = Vector2(112.0, 20)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    status_label.add_theme_font_size_override("font_size", 9 if compact else 10)

    overview_label.position = Vector2(side, 48)
    overview_label.size = Vector2(width - side * 2.0, 46)
    overview_label.add_theme_font_size_override("font_size", 11 if compact else 12)

    objective_label.position = Vector2(side, 100)
    objective_label.size = Vector2(width - side * 2.0, 42)
    objective_label.add_theme_font_size_override("font_size", 11 if compact else 12)

    ops_label.position = Vector2(side, 146)
    ops_label.size = Vector2(width - side * 2.0, 54)
    ops_label.add_theme_font_size_override("font_size", 10 if compact else 11)

    events_label.position = Vector2(side, 208)
    events_label.size = Vector2(width - side * 2.0, maxf(52.0, panel.size.y - 394.0))
    events_label.add_theme_font_size_override("font_size", 10 if compact else 11)

    var gap := 7.0
    var action_width := maxf(72.0, (width - side * 2.0 - gap * 2.0) / 3.0)
    var y := panel.size.y - 56.0
    close_button.position = Vector2(side, y)
    close_button.size = Vector2(action_width, 46)
    notices_button.position = Vector2(side + action_width + gap, y)
    notices_button.size = Vector2(action_width, 46)
    primary_button.position = Vector2(side + (action_width + gap) * 2.0, y)
    primary_button.size = Vector2(action_width, 46)
    for button in [close_button, notices_button, primary_button]:
        button.add_theme_font_size_override("font_size", 9 if compact else 11)

func _refresh(_force: bool) -> void:
    var state = _state()
    var finance = _finance()
    if state == null:
        return
    var cash := int(finance.get("cash")) if finance != null else int(state.get_value("economy", "cash", 0))
    var worth := 0.0
    if finance != null and finance.has_method("valuation"):
        worth = maxf(0.0, float(finance.call("valuation")))
    overview_label.text = "Day %d  •  Cash $%s  •  Worth $%s  •  Rep %d" % [int(state.get_value("player", "day", 1)), _money(cash), _money(int(worth)), int(state.get_value("player", "reputation", 0))]
    var goal := _next_goal(state)
    objective_label.text = "NEXT OBJECTIVE\n" + goal["text"]
    primary_button.text = goal["action"]
    var contracts: int = 0
    var world = get_node_or_null("/root/RenewContractSystem")
    if world != null and world.has_method("list_active_contracts"):
        contracts = (world.list_active_contracts() as Array).size()
    ops_label.text = "LIVE OPERATIONS\nContracts %d  •  Research %d pts  •  Finished goods %d" % [contracts, int(state.get_value("technology", "research_points", 0)), int(state.get_value("production", "finished_goods", 0))]
    var logs: Array = state.get_value("company", "log_lines", [])
    var recent: Array = (logs as Array).slice(maxi(0, logs.size() - 5), logs.size()) if logs is Array else []
    if recent.is_empty():
        events_label.text = "RECENT ACTIVITY\nNo recent activity recorded."
    else:
        events_label.text = "RECENT ACTIVITY\n" + "\n".join(recent)
    status_label.text = "COMMAND OVERVIEW"

func _next_goal(state: Variant) -> Dictionary:
    if not bool(state.get_value("properties", "owned", false)):
        return {"text": "Acquire the abandoned property.", "action": "ACQUIRE", "method": "acquire_property"}
    if str(state.get_value("properties", "stage", "")) != "Operational":
        return {"text": "Restore the property to Operational.", "action": "RESTORE", "method": "restore_property"}
    if not bool(state.get_value("businesses", "business_open", false)):
        return {"text": "Open your first business.", "action": "OPEN BUSINESS", "method": "open_business"}
    if int(state.get_value("economy", "total_profit", 0)) <= 0:
        return {"text": "Produce and sell for your first profit.", "action": "PRODUCE", "method": "produce_goods"}
    return {"text": "Expand the empire: branches, regions, alliances.", "action": "ADVANCE DAY", "method": "advance_day"}

func _primary() -> void:
    var game = _game()
    var state = _state()
    if game == null or state == null:
        return
    var method := str(_next_goal(state).get("method", "advance_day"))
    if game.has_method(method):
        game.call(method)

func _notices() -> void:
    var game = _game()
    if game != null and game.has_method("check_notifications"):
        game.check_notifications()

func _close() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"):
        manager.hide_all_screens()

func _money(amount: int) -> String:
    if amount >= 1000000:
        return "%.2fM" % (float(amount) / 1000000.0)
    if amount >= 1000:
        return "%.1fK" % (float(amount) / 1000.0)
    return str(amount)
