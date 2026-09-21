extends Control
## Presentation-only executive dashboard visual. Reads canonical state and draws
## a living company pulse without creating fake interactive controls.

const DEEP := Color("091122")
const SURFACE := Color("17264c")
const EDGE := Color("5367af")
const GOLD := Color("f2c65c")
const MINT := Color("68d4a5")
const CYAN := Color("67cbe2")
const CORAL := Color("ef7a88")
const TEXT := Color("f7f9ff")
const MUTED := Color("adbbe0")

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
    draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(DEEP.r, DEEP.g, DEEP.b, 0.72), true)
    # Layered top sheen and perspective guide lines mimic the polished Figma
    # surface while staying lightweight enough for the mobile dashboard.
    for i in range(7):
        var band_h := h * 0.055
        var alpha := 0.12 - float(i) * 0.012
        draw_rect(Rect2(0, float(i) * band_h, w, band_h + 1), Color(SURFACE.r, SURFACE.g, SURFACE.b, maxf(0.025, alpha)), true)
    for i in range(5):
        var inset := float(i) * 7.0
        draw_arc(Vector2(w * 0.50, h * 0.36), maxf(20.0, minf(w, h) * 0.48 - inset), PI * 1.08, PI * 1.92, 42, Color(CYAN.r, CYAN.g, CYAN.b, 0.032), 1.0)
    for i in range(7):
        var y := h * (0.52 + float(i) * 0.055)
        draw_line(Vector2(w * 0.08, y), Vector2(w * 0.92, y), Color(EDGE.r, EDGE.g, EDGE.b, 0.075), 1.0)
    draw_line(Vector2(w * 0.06, h * 0.77), Vector2(w * 0.94, h * 0.77), Color(EDGE.r, EDGE.g, EDGE.b, 0.52), 1.0)
    draw_line(Vector2(w * 0.06, h * 0.775), Vector2(w * 0.94, h * 0.775), Color(0, 0, 0, 0.28), 2.0)

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
    # Isometric ground wedge.
    draw_colored_polygon(PackedVector2Array([
        rect.position + Vector2(rect.size.x * 0.04, rect.size.y * 0.86),
        rect.position + Vector2(rect.size.x * 0.48, rect.size.y * 0.23),
        rect.position + Vector2(rect.size.x * 0.96, rect.size.y * 0.86),
        rect.position + Vector2(rect.size.x * 0.54, rect.size.y)
    ]), Color("12254d", 0.86))

    for i in range(10):
        var x := rect.position.x + rect.size.x * (0.07 + 0.086 * float(i))
        var bh := rect.size.y * (0.24 + float((i * 37) % 42) / 100.0)
        var bw := maxf(10.0, rect.size.x * 0.050)
        var base_y := rect.position.y + rect.size.y * 0.82
        var depth := maxf(4.0, bw * 0.28)
        var front := Color("294a78") if i % 2 == 0 else Color("354f82")
        var side := front.darkened(0.28)
        var roof := front.lightened(0.22)

        # Front face.
        draw_rect(Rect2(x, base_y - bh, bw, bh), front, true)
        # Right-side extrusion.
        draw_colored_polygon(PackedVector2Array([
            Vector2(x + bw, base_y - bh),
            Vector2(x + bw + depth, base_y - bh - depth * 0.55),
            Vector2(x + bw + depth, base_y - depth * 0.55),
            Vector2(x + bw, base_y)
        ]), side)
        # Beveled roof plane catches the specular highlight.
        draw_colored_polygon(PackedVector2Array([
            Vector2(x, base_y - bh),
            Vector2(x + depth, base_y - bh - depth * 0.55),
            Vector2(x + bw + depth, base_y - bh - depth * 0.55),
            Vector2(x + bw, base_y - bh)
        ]), roof)
        draw_line(Vector2(x + 1, base_y - bh + 2), Vector2(x + bw - 1, base_y - bh + 2), Color(1, 1, 1, 0.16), 1.0)
        draw_rect(Rect2(x + 3, base_y - bh + 8, maxf(2.0, bw - 6), 2), Color(GOLD.r, GOLD.g, GOLD.b, 0.38), true)

    var runner_x := rect.position.x + fmod(_clock * 23.0, maxf(1.0, rect.size.x * 0.82)) + rect.size.x * 0.06
    draw_circle(Vector2(runner_x, rect.position.y + rect.size.y * 0.91), 5.0, Color(MINT.r, MINT.g, MINT.b, 0.18))
    draw_circle(Vector2(runner_x, rect.position.y + rect.size.y * 0.91), 3.0, MINT)
    draw_string(ThemeDB.fallback_font, rect.position + Vector2(4, 12), "RESTORA CITY  •  DAY %d" % day, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8, 9, MUTED)

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