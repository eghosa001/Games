extends Control

## Responsive vector headquarters illustration used by HeadquartersUI.
## The visual is generated at runtime so it stays crisp on mobile, web and desktop.

const SKY := Color("07141a")
const GROUND := Color("10242b")
const BUILDING := Color("18343d")
const BUILDING_LIGHT := Color("214a55")
const GLASS := Color("4f8290")
const GLASS_LIT := Color("8cc2bf")
const GOLD := Color("d5b56e")
const MUTED := Color("78949a")
const TEXT := Color("e7f2ef")

var stage_index: int = 0
var stage_name: String = "Small Office"
var invested_value: int = 0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    custom_minimum_size = Vector2(0, 150)
    resized.connect(queue_redraw)

func set_headquarters_state(index: int, name: String, value: int) -> void:
    stage_index = clampi(index, 0, 4)
    stage_name = name
    invested_value = maxi(0, value)
    queue_redraw()

func _draw() -> void:
    var w := size.x
    var h := size.y
    if w < 40.0 or h < 80.0:
        return
    draw_rect(Rect2(Vector2.ZERO, size), SKY, true)
    draw_rect(Rect2(0, h * 0.78, w, h * 0.22), GROUND, true)
    for i in range(9):
        var sw := maxf(12.0, w * 0.035)
        var sx := float(i) * (w / 8.0) - sw * 0.5
        var sh := h * (0.10 + float((i * 7) % 5) * 0.025)
        draw_rect(Rect2(sx, h * 0.78 - sh, sw, sh), Color(0.08, 0.16, 0.19, 0.65), true)
    var center := Vector2(w * 0.5, h * 0.78)
    match stage_index:
        0: _draw_small_office(center, w, h)
        1: _draw_headquarters(center, w, h)
        2: _draw_corporate_center(center, w, h)
        3: _draw_regional_hq(center, w, h)
        _: _draw_global_hq(center, w, h)
    draw_string(ThemeDB.fallback_font, Vector2(12, 20), stage_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w - 24, 12, TEXT)
    draw_string(ThemeDB.fallback_font, Vector2(12, 38), "HEADQUARTERS EVOLUTION  %d/5" % (stage_index + 1), HORIZONTAL_ALIGNMENT_LEFT, w - 24, 9, MUTED)
    draw_string(ThemeDB.fallback_font, Vector2(12, h - 9), "CORPORATE CAMPUS • $%s INVESTED" % _money(invested_value), HORIZONTAL_ALIGNMENT_LEFT, w - 24, 9, MUTED)

func _draw_small_office(center: Vector2, w: float, h: float) -> void:
    var bw := minf(150.0, w * 0.38)
    var bh := h * 0.34
    var rect := Rect2(center.x - bw * 0.5, center.y - bh, bw, bh)
    _building(rect, 3, 2)
    draw_rect(Rect2(center.x - 15, center.y - 31, 30, 31), Color("0b171c"), true)
    _sign(Vector2(center.x, rect.position.y - 9), "RENEW")

func _draw_headquarters(center: Vector2, w: float, h: float) -> void:
    var main_w := minf(176.0, w * 0.42)
    var main_h := h * 0.47
    var main := Rect2(center.x - main_w * 0.5, center.y - main_h, main_w, main_h)
    _building(main, 4, 4)
    var wing_w := main_w * 0.35
    _building(Rect2(main.position.x - wing_w + 2, center.y - main_h * 0.62, wing_w, main_h * 0.62), 2, 2)
    _building(Rect2(main.end.x - 2, center.y - main_h * 0.62, wing_w, main_h * 0.62), 2, 2)
    _sign(Vector2(center.x, main.position.y - 9), "RENEW HQ")

func _draw_corporate_center(center: Vector2, w: float, h: float) -> void:
    var tower_w := minf(142.0, w * 0.32)
    var tower_h := h * 0.60
    var tower := Rect2(center.x - tower_w * 0.5, center.y - tower_h, tower_w, tower_h)
    _building(tower, 4, 6)
    var podium_h := h * 0.17
    var podium_w := minf(260.0, w * 0.62)
    _building(Rect2(center.x - podium_w * 0.5, center.y - podium_h, podium_w, podium_h), 6, 1)
    draw_line(Vector2(center.x, tower.position.y - 18), Vector2(center.x, tower.position.y), GOLD, 2.0)
    draw_circle(Vector2(center.x, tower.position.y - 20), 3.5, GOLD)
    _sign(Vector2(center.x, tower.position.y - 28), "CORPORATE CENTER")

func _draw_regional_hq(center: Vector2, w: float, h: float) -> void:
    var tower_h := h * 0.67
    var tower_w := minf(124.0, w * 0.27)
    var gap := tower_w * 0.82
    for offset in [-gap, 0.0, gap]:
        var scale := 0.82 if offset != 0.0 else 1.0
        var th := tower_h * scale
        var rect := Rect2(center.x + offset - tower_w * 0.5, center.y - th, tower_w, th)
        _glass_tower(rect, 4, 7 if offset == 0.0 else 5)
    draw_line(Vector2(center.x - gap, center.y - tower_h * 0.44), Vector2(center.x + gap, center.y - tower_h * 0.44), GOLD, 3.0)
    _sign(Vector2(center.x, center.y - tower_h - 13), "REGIONAL HQ")

func _draw_global_hq(center: Vector2, w: float, h: float) -> void:
    var tower_h := h * 0.72
    var tower_w := minf(150.0, w * 0.30)
    var tower := Rect2(center.x - tower_w * 0.5, center.y - tower_h, tower_w, tower_h)
    _glass_tower(tower, 5, 8)
    var crown := PackedVector2Array([Vector2(tower.position.x, tower.position.y + 12), Vector2(center.x, tower.position.y - 19), Vector2(tower.end.x, tower.position.y + 12)])
    draw_colored_polygon(crown, Color("2a5962"))
    draw_polyline(PackedVector2Array([crown[0], crown[1], crown[2]]), GOLD, 2.0)
    draw_line(Vector2(center.x, tower.position.y - 19), Vector2(center.x, tower.position.y - 33), GOLD, 2.0)
    draw_circle(Vector2(center.x, tower.position.y - 35), 4.0, GOLD)
    var podium_w := minf(320.0, w * 0.70)
    var podium_h := h * 0.16
    _building(Rect2(center.x - podium_w * 0.5, center.y - podium_h, podium_w, podium_h), 7, 1)
    _sign(Vector2(center.x, tower.position.y - 43), "RENEW GLOBAL")

func _building(rect: Rect2, columns: int, rows: int) -> void:
    draw_rect(rect, BUILDING, true)
    draw_rect(rect, Color("315b63"), false, 1.5)
    _windows(rect, columns, rows, false)

func _glass_tower(rect: Rect2, columns: int, rows: int) -> void:
    draw_rect(rect, BUILDING_LIGHT, true)
    draw_rect(rect, GLASS, false, 2.0)
    _windows(rect, columns, rows, true)

func _windows(rect: Rect2, columns: int, rows: int, glass: bool) -> void:
    var margin_x := maxf(8.0, rect.size.x * 0.10)
    var margin_y := maxf(9.0, rect.size.y * 0.10)
    var usable_w := maxf(1.0, rect.size.x - margin_x * 2.0)
    var usable_h := maxf(1.0, rect.size.y - margin_y * 2.0)
    var cell_w := usable_w / float(maxi(columns, 1))
    var cell_h := usable_h / float(maxi(rows, 1))
    for row in range(rows):
        for col in range(columns):
            var inset := 3.0
            var wr := Rect2(rect.position.x + margin_x + col * cell_w + inset, rect.position.y + margin_y + row * cell_h + inset, maxf(3.0, cell_w - inset * 2.0), maxf(3.0, cell_h - inset * 2.0))
            var lit := ((row + col + stage_index) % 3) != 0
            draw_rect(wr, GLASS_LIT if lit else (GLASS if glass else Color("29464d")), true)

func _sign(pos: Vector2, text: String) -> void:
    var width := minf(size.x - 24.0, maxf(80.0, float(text.length()) * 7.5))
    draw_string(ThemeDB.fallback_font, Vector2(pos.x - width * 0.5, pos.y), text, HORIZONTAL_ALIGNMENT_CENTER, width, 10, GOLD)

func _money(value: int) -> String:
    var digits := str(absi(value))
    var out := ""
    while digits.length() > 3:
        out = "," + digits.substr(digits.length() - 3, 3) + out
        digits = digits.substr(0, digits.length() - 3)
    return ("-" if value < 0 else "") + digits + out
