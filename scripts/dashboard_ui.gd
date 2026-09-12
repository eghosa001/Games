extends CanvasLayer

## Executive command dashboard. The world remains visible behind a light glass
## surface while a presentation-only hero visual summarizes company momentum.
const DashboardHeroArt := preload("res://scripts/dashboard_hero_art.gd")

var dimmer: ColorRect
var panel: Panel
var hero: Control
var content_surface: Panel
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

const SURFACE := Color("0b1c23", 0.93)
const CONTENT := Color("0a171d", 0.76)
const BORDER := Color("36575e", 0.68)
const TEXT := Color("edf6f2")
const MUTED := Color("89a3a7")
const ACCENT := Color("e2bb63")
const MINT := Color("65c69c")
const SCRIM := Color(0.01, 0.055, 0.07, 0.52)

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

func _style(bg: Color, border: Color, radius := 16) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    style.shadow_color = Color(0, 0, 0, 0.34)
    style.shadow_size = 14
    style.shadow_offset = Vector2(0, 5)
    return style

func _build_ui() -> void:
    dimmer = ColorRect.new()
    dimmer.name = "DashboardModalScrim"
    dimmer.color = SCRIM
    dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dimmer)

    panel = Panel.new()
    panel.name = "DashboardPanel"
    panel.add_theme_stylebox_override("panel", _style(SURFACE, BORDER, 20))
    add_child(panel)

    hero = DashboardHeroArt.new()
    hero.name = "ExecutiveHero"
    panel.add_child(hero)

    content_surface = Panel.new()
    content_surface.name = "ExecutiveBriefSurface"
    content_surface.add_theme_stylebox_override("panel", _style(CONTENT, Color(BORDER.r, BORDER.g, BORDER.b, 0.48), 16))
    panel.add_child(content_surface)

    title_label = _label("EXECUTIVE COMMAND", 22, TEXT)
    status_label = _label("LIVE ENTERPRISE", 10, ACCENT)
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

func _label(text: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    panel.add_child(label)
    return label

func _button(text: String) -> Button:
    var button := Button.new()
    button.text = text
    button.focus_mode = Control.FOCUS_NONE
    button.clip_text = true
    button.custom_minimum_size = Vector2(44, 46)
    panel.add_child(button)
    return button

func _layout() -> void:
    if get_viewport() == null or panel == null:
        return
    var viewport: Vector2 = get_viewport().size
    var mobile := viewport.x < 720.0
    var margin := 12.0 if viewport.x < 390.0 else 18.0
    var width := minf(940.0, maxf(280.0, viewport.x - margin * 2.0))
    var height := minf(650.0, maxf(430.0, viewport.y - 88.0))
    dimmer.position = Vector2.ZERO
    dimmer.size = viewport
    panel.position = Vector2((viewport.x - width) * 0.5, maxf(42.0, (viewport.y - height) * 0.5))
    panel.size = Vector2(width, minf(height, viewport.y - panel.position.y - 12.0))

    var pad := 16.0 if mobile else 22.0
    title_label.position = Vector2(pad, 15)
    title_label.size = Vector2(width * 0.58, 30)
    title_label.add_theme_font_size_override("font_size", 18 if mobile else 22)
    status_label.position = Vector2(width - 160.0 - pad, 19)
    status_label.size = Vector2(160.0, 20)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    status_label.add_theme_font_size_override("font_size", 9 if mobile else 10)

    if mobile:
        _layout_mobile(width, pad)
    else:
        _layout_desktop(width, pad)

func _layout_desktop(width: float, pad: float) -> void:
    var top := 56.0
    var bottom_actions := 68.0
    var available_h := panel.size.y - top - bottom_actions - pad
    var hero_w := width * 0.46
    hero.position = Vector2(pad, top)
    hero.size = Vector2(hero_w - pad * 0.5, available_h)

    var right_x := hero_w + pad * 0.55
    var right_w := width - right_x - pad
    content_surface.position = Vector2(right_x, top)
    content_surface.size = Vector2(right_w, available_h)

    var inner := 17.0
    overview_label.position = Vector2(right_x + inner, top + 18)
    overview_label.size = Vector2(right_w - inner * 2, 44)
    objective_label.position = Vector2(right_x + inner, top + 72)
    objective_label.size = Vector2(right_w - inner * 2, 58)
    ops_label.position = Vector2(right_x + inner, top + 142)
    ops_label.size = Vector2(right_w - inner * 2, 56)
    events_label.position = Vector2(right_x + inner, top + 214)
    events_label.size = Vector2(right_w - inner * 2, maxf(72.0, available_h - 230.0))

    var gap := 9.0
    var action_w := (right_w - gap * 2.0) / 3.0
    var y := panel.size.y - 56.0
    close_button.position = Vector2(right_x, y)
    close_button.size = Vector2(action_w, 44)
    notices_button.position = Vector2(right_x + action_w + gap, y)
    notices_button.size = Vector2(action_w, 44)
    primary_button.position = Vector2(right_x + (action_w + gap) * 2.0, y)
    primary_button.size = Vector2(action_w, 44)
    for button in [close_button, notices_button, primary_button]:
        button.add_theme_font_size_override("font_size", 10)

func _layout_mobile(width: float, pad: float) -> void:
    var top := 54.0
    var hero_h := clampf(panel.size.y * 0.25, 116.0, 160.0)
    hero.position = Vector2(pad, top)
    hero.size = Vector2(width - pad * 2.0, hero_h)

    var content_y := top + hero_h + 9.0
    var actions_h := 104.0
    var content_h := maxf(174.0, panel.size.y - content_y - actions_h - 11.0)
    content_surface.position = Vector2(pad, content_y)
    content_surface.size = Vector2(width - pad * 2.0, content_h)
    var inner := 13.0
    var text_w := width - pad * 2.0 - inner * 2.0
    overview_label.position = Vector2(pad + inner, content_y + 10)
    overview_label.size = Vector2(text_w, 34)
    overview_label.add_theme_font_size_override("font_size", 10)
    objective_label.position = Vector2(pad + inner, content_y + 49)
    objective_label.size = Vector2(text_w, 45)
    objective_label.add_theme_font_size_override("font_size", 10)
    ops_label.position = Vector2(pad + inner, content_y + 99)
    ops_label.size = Vector2(text_w, 40)
    ops_label.add_theme_font_size_override("font_size", 9)
    events_label.position = Vector2(pad + inner, content_y + 143)
    events_label.size = Vector2(text_w, maxf(26.0, content_h - 151.0))
    events_label.add_theme_font_size_override("font_size", 9)

    var gap := 7.0
    var half := (width - pad * 2.0 - gap) * 0.5
    var row_one_y := panel.size.y - 101.0
    var row_two_y := panel.size.y - 52.0
    close_button.position = Vector2(pad, row_one_y)
    close_button.size = Vector2(half, 43)
    notices_button.position = Vector2(pad + half + gap, row_one_y)
    notices_button.size = Vector2(half, 43)
    primary_button.position = Vector2(pad, row_two_y)
    primary_button.size = Vector2(width - pad * 2.0, 43)
    for button in [close_button, notices_button, primary_button]:
        button.add_theme_font_size_override("font_size", 9)

func _refresh(_force: bool) -> void:
    var state = _state()
    var finance = _finance()
    if state == null:
        return
    var cash := int(finance.get("cash")) if finance != null else int(state.get_value("economy", "cash", 0))
    var worth := 0.0
    if finance != null and finance.has_method("valuation"):
        worth = maxf(0.0, float(finance.call("valuation")))
    overview_label.text = "Day %d  •  Cash $%s\nWorth $%s  •  Reputation %d" % [int(state.get_value("player", "day", 1)), _money(cash), _money(int(worth)), int(state.get_value("player", "reputation", 0))]
    var goal := _next_goal(state)
    objective_label.text = "NEXT MOVE\n" + str(goal["text"])
    primary_button.text = str(goal["action"])
    var contracts := 0
    var world = get_node_or_null("/root/RenewContractSystem")
    if world != null and world.has_method("list_active_contracts"):
        contracts = (world.list_active_contracts() as Array).size()
    ops_label.text = "OPERATIONS\n%d contracts  •  %d research  •  %d goods" % [contracts, int(state.get_value("technology", "research_points", 0)), int(state.get_value("production", "finished_goods", 0))]
    var logs: Array = state.get_value("company", "log_lines", [])
    var recent: Array = logs.slice(maxi(0, logs.size() - 4), logs.size())
    events_label.text = "SIGNALS\n" + ("No recent activity recorded." if recent.is_empty() else "\n".join(recent))
    status_label.text = "LIVE ENTERPRISE"
    if hero != null:
        hero.queue_redraw()

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