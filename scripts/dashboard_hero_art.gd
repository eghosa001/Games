extends Control
## Presentation-only executive dashboard visual. Reads canonical state and draws
## a living company pulse without creating fake interactive controls.

const DEEP := Color("07151b")
const SURFACE := Color("0b252d")
const EDGE := Color("365c61")
const GOLD := Color("e2bb63")
const MINT := Color("67c39d")
const CYAN := Color("66bdd0")
const CORAL := Color("d77862")
const TEXT := Color("eaf4ef")
const MUTED := Color("89a5a6")

var _clock := 0.0
var _redraw_clock := 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)
    queue_redraw()

func _process(delta: float) -> void:
    _clock += delta
    _redraw_clock += delta
    if _redraw_clock >= 0.35:
        _redraw_clock = 0.0
        queue_redraw()

func _state():
    return get_node_or_null("/root/RenewGameState")

func _finance():
    return get_node_or_null("/root/RenewFinanceSystem")

func _draw() -> void:
    var w: float = maxf(size.x, 10.0)
    var h: float = maxf(size.y, 10.0)
    var state = _state()
    var finance = _finance()
    var cash := 0
    var worth := 0.0
    var reputation := 0
    var day := 1
    var goods := 0
    var research := 0
    if state != null:
        day = int(state.get_value("player", "day", 1))
        reputation = int(state.get_value("player", "reputation", 0))
        cash = int(state.get_value("economy", "cash", 0))
        goods = int(state.get_value("production", "finished_goods", 0))
        research = int(state.get_value("technology", "research_points", 0))
    if finance != null:
        cash = int(finance.get("cash"))
        if finance.has_method("valuation"):
            worth = maxf(0.0, float(finance.call("valuation")))

    _background(w, h)
    var compact := w < 320.0 or h < 250.0
    if compact:
        _compact_pulse(w, h, cash, reputation, day)
        return

    var center := Vector2(w * 0.48, h * 0.34)
    var radius := minf(w, h) * 0.18
    _pulse_ring(center, radius, reputation, cash, worth)
    _city_strip(Rect2(w * 0.08, h * 0.57, w * 0.84, h * 0.19), day)
    _metric_bar(Vector2(w * 0.08, h * 0.84), w * 0.37, "INVENTORY", goods, 180, MINT)
    _metric_bar(Vector2(w * 0.55, h * 0.84), w * 0.37, "RESEARCH", research, 160, CYAN)
    _network(Vector2(w * 0.83, h * 0.22), minf(68.0, w * 0.16))

func _background(w: float, h: float) -> void:
    draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(DEEP.r, DEEP.g, DEEP.b, 0.52), true)
    for i in range(5):
        var inset := float(i) * 7.0
        draw_arc(Vector2(w * 0.50, h * 0.36), maxf(20.0, minf(w, h) * 0.48 - inset), PI * 1.08, PI * 1.92, 42, Color(CYAN.r, CYAN.g, CYAN.b, 0.025), 1.0)
    draw_line(Vector2(w * 0.06, h * 0.77), Vector2(w * 0.94, h * 0.77), Color(EDGE.r, EDGE.g, EDGE.b, 0.45), 1.0)

func _pulse_ring(center: Vector2, radius: float, reputation: int, cash: int, worth: float) -> void:
    var pulse := 0.94 + 0.035 * sin(_clock * 1.4)
    draw_circle(center, radius * 1.17 * pulse, Color(CYAN.r, CYAN.g, CYAN.b, 0.035))
    draw_arc(center, radius, -PI * 0.5, PI * 1.5, 80, Color(EDGE.r, EDGE.g, EDGE.b, 0.70), 10.0)
    var rep_ratio := clampf(float(reputation) / 100.0, 0.06, 1.0)
    draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * rep_ratio, 80, GOLD, 10.0)
    draw_arc(center, radius * 0.77, -PI * 0.5, PI * 1.5, 70, Color(MINT.r, MINT.g, MINT.b, 0.28), 2.0)
    draw_string(ThemeDB.fallback_font, center + Vector2(-radius * 0.72, -7), "COMPANY PULSE", HORIZONTAL_ALIGNMENT_CENTER, radius * 1.44, 10, MUTED)
    draw_string(ThemeDB.fallback_font, center + Vector2(-radius * 0.72, 18), "%d REP" % reputation, HORIZONTAL_ALIGNMENT_CENTER, radius * 1.44, 18, TEXT)
    var capital := int(worth) if worth > 0.0 else cash
    draw_string(ThemeDB.fallback_font, center + Vector2(-radius * 0.72, 40), "$%s" % _compact_number(capital), HORIZONTAL_ALIGNMENT_CENTER, radius * 1.44, 10, GOLD)

func _city_strip(rect: Rect2, day: int) -> void:
    draw_colored_polygon(PackedVector2Array([
        rect.position + Vector2(rect.size.x * 0.06, rect.size.y * 0.88),
        rect.position + Vector2(rect.size.x * 0.48, rect.size.y * 0.30),
        rect.position + Vector2(rect.size.x * 0.94, rect.size.y * 0.88),
        rect.position + Vector2(rect.size.x * 0.52, rect.size.y)
    ]), Color("142d33", 0.78))
    for i in range(10):
        var x := rect.position.x + rect.size.x * (0.08 + 0.085 * float(i))
        var bh := rect.size.y * (0.22 + float((i * 37) % 40) / 100.0)
        var bw := maxf(10.0, rect.size.x * 0.052)
        var base_y := rect.position.y + rect.size.y * 0.82
        draw_rect(Rect2(x, base_y - bh, bw, bh), Color("24444a") if i % 2 == 0 else Color("315057"), true)
        draw_rect(Rect2(x + 3, base_y - bh + 5, maxf(2.0, bw - 6), 2), Color(GOLD.r, GOLD.g, GOLD.b, 0.25), true)
    var runner_x := rect.position.x + fmod(_clock * 23.0, maxf(1.0, rect.size.x * 0.82)) + rect.size.x * 0.06
    draw_circle(Vector2(runner_x, rect.position.y + rect.size.y * 0.91), 3.0, MINT)
    draw_string(ThemeDB.fallback_font, rect.position + Vector2(4, 12), "RENEW CITY  •  DAY %d" % day, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8, 9, MUTED)

func _metric_bar(pos: Vector2, width: float, label: String, value: int, soft_cap: int, tint: Color) -> void:
    var ratio := clampf(float(maxi(0, value)) / float(maxi(1, soft_cap)), 0.0, 1.0)
    draw_string(ThemeDB.fallback_font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, width * 0.70, 8, MUTED)
    draw_string(ThemeDB.fallback_font, pos + Vector2(width * 0.70, 0), str(value), HORIZONTAL_ALIGNMENT_RIGHT, width * 0.30, 9, TEXT)
    draw_rect(Rect2(pos + Vector2(0, 8), Vector2(width, 5)), Color(EDGE.r, EDGE.g, EDGE.b, 0.42), true)
    draw_rect(Rect2(pos + Vector2(0, 8), Vector2(width * ratio, 5)), tint, true)

func _network(center: Vector2, radius: float) -> void:
    draw_string(ThemeDB.fallback_font, center + Vector2(-radius, -radius - 8), "NETWORK", HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 8, MUTED)
    for i in range(6):
        var angle := float(i) * TAU / 6.0 + _clock * 0.045
        var p := center + Vector2(cos(angle), sin(angle)) * radius
        draw_line(center, p, Color(CYAN.r, CYAN.g, CYAN.b, 0.22), 1.0)
        draw_circle(p, 3.5, GOLD if i == 0 else CYAN)
    draw_circle(center, 6.0, MINT)

func _compact_pulse(w: float, h: float, cash: int, reputation: int, day: int) -> void:
    var center := Vector2(w * 0.25, h * 0.50)
    var radius := minf(h * 0.28, w * 0.16)
    draw_arc(center, radius, -PI * 0.5, PI * 1.5, 60, Color(EDGE.r, EDGE.g, EDGE.b, 0.75), 7.0)
    draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * clampf(float(reputation) / 100.0, 0.05, 1.0), 60, GOLD, 7.0)
    draw_string(ThemeDB.fallback_font, Vector2(w * 0.46, h * 0.39), "DAY %d" % day, HORIZONTAL_ALIGNMENT_LEFT, w * 0.45, 10, MUTED)
    draw_string(ThemeDB.fallback_font, Vector2(w * 0.46, h * 0.58), "$%s" % _compact_number(cash), HORIZONTAL_ALIGNMENT_LEFT, w * 0.45, 16, TEXT)

func _compact_number(value: int) -> String:
    var n := abs(value)
    if n >= 1000000000:
        return "%.1fB" % (float(value) / 1000000000.0)
    if n >= 1000000:
        return "%.1fM" % (float(value) / 1000000.0)
    if n >= 1000:
        return "%.1fK" % (float(value) / 1000.0)
    return str(value)