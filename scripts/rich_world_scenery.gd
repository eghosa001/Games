extends Node2D
## Premium presentation-only world for RENEW.
## Drawn procedurally so Web, desktop and mobile share the same art direction
## without shipping a heavy scene graph. This node never mutates simulation state.

const SKY_TOP := Color("08151d")
const SKY_BOTTOM := Color("17343c")
const GROUND := Color("d8d0bb")
const ROAD := Color("243940")
const ROAD_EDGE := Color("668084")
const PAPER := Color("eee5d3")
const WALL := Color("c9b99c")
const WALL_DARK := Color("847966")
const GLASS := Color("6fb4b8")
const GLASS_DARK := Color("315e66")
const GOLD := Color("e1b95f")
const GREEN := Color("5c9870")
const GREEN_LIGHT := Color("82b987")
const ORANGE := Color("b9684f")
const INK := Color("173039")
const WHITE := Color("fffdf7")

var _time: float = 0.0
var _redraw_clock: float = 0.0

func _ready() -> void:
    z_index = -24
    mouse_filter = Control.MOUSE_FILTER_IGNORE if self is Control else 0
    queue_redraw()

func _process(delta: float) -> void:
    _time += delta
    _redraw_clock += delta
    if _redraw_clock >= 0.25:
        _redraw_clock = 0.0
        queue_redraw()

func _draw() -> void:
    var viewport: Vector2 = get_viewport_rect().size
    var w: float = maxf(viewport.x, 360.0)
    var h: float = maxf(viewport.y, 568.0)
    var compact: bool = w < 720.0
    _draw_sky(w, h)
    _draw_city_base(w, h, compact)
    _draw_hq(w, h, compact)
    _draw_industry(w, h, compact)
    _draw_public_space(w, h)
    _draw_city_life(w, h)
    _draw_badges(w, h, compact)

func _draw_sky(w: float, h: float) -> void:
    var horizon: float = h * 0.31
    for i in range(8):
        var t: float = float(i) / 7.0
        var c: Color = SKY_TOP.lerp(SKY_BOTTOM, t)
        draw_rect(Rect2(0.0, t * horizon, w, horizon / 7.0 + 2.0), c, true)
    _glow(Vector2(w * 0.79, horizon * 0.35), minf(250.0, w * 0.28), GOLD, 0.08)
    _glow(Vector2(w * 0.20, horizon * 0.58), minf(200.0, w * 0.23), GLASS, 0.07)

    var step: float = maxf(40.0, w / 22.0)
    for i in range(25):
        var x: float = float(i) * step - 20.0
        var bh: float = 34.0 + float((i * 43) % 122)
        var bw: float = step - 7.0
        var tone: Color = Color("203c45") if i % 3 != 0 else Color("294b50")
        draw_rect(Rect2(x, horizon - bh, bw, bh), tone, true)
        draw_rect(Rect2(x, horizon - bh, bw, 2.0), Color(GOLD.r, GOLD.g, GOLD.b, 0.22), true)
        for wy in range(int(horizon - bh + 13.0), int(horizon - 8.0), 18):
            if (wy / 18 + i) as int % 3 != 0:
                draw_rect(Rect2(x + 8.0, float(wy), 4.0, 4.0), Color(0.95, 0.82, 0.48, 0.28), true)
    draw_line(Vector2(0.0, horizon), Vector2(w, horizon), Color(0.62, 0.82, 0.79, 0.14), 3.0)

func _draw_city_base(w: float, h: float, compact: bool) -> void:
    var top: float = h * 0.30
    var bottom: float = h * 0.98
    var cx: float = w * 0.5
    var top_half: float = w * (0.47 if compact else 0.43)
    var bottom_half: float = w * (0.64 if compact else 0.55)
    var island := PackedVector2Array([
        Vector2(cx - top_half, top), Vector2(cx + top_half, top),
        Vector2(cx + bottom_half, bottom), Vector2(cx - bottom_half, bottom)
    ])
    draw_colored_polygon(island, GROUND)
    draw_polyline(PackedVector2Array([island[0], island[1], island[2], island[3], island[0]]), Color(1.0, 0.96, 0.84, 0.28), 2.0)

    var road_y: float = lerpf(top, bottom, 0.61)
    var cross_road := PackedVector2Array([
        Vector2(cx - top_half, road_y - 30.0), Vector2(cx + top_half, road_y - 30.0),
        Vector2(cx + bottom_half, road_y + 38.0), Vector2(cx - bottom_half, road_y + 38.0)
    ])
    draw_colored_polygon(cross_road, ROAD)
    draw_line(Vector2(cx - top_half, road_y - 30.0), Vector2(cx + top_half, road_y - 30.0), ROAD_EDGE, 2.0)
    draw_line(Vector2(cx - bottom_half, road_y + 38.0), Vector2(cx + bottom_half, road_y + 38.0), ROAD_EDGE, 2.0)
    for x in range(int(cx - top_half + 28.0), int(cx + top_half - 20.0), 78):
        draw_line(Vector2(float(x), road_y + 3.0), Vector2(float(x + 34), road_y + 3.0), Color(GOLD.r, GOLD.g, GOLD.b, 0.68), 2.0)

    var avenue := PackedVector2Array([
        Vector2(cx - 38.0, top + 4.0), Vector2(cx + 38.0, top + 4.0),
        Vector2(cx + 108.0, bottom), Vector2(cx - 108.0, bottom)
    ])
    draw_colored_polygon(avenue, Color("30464d"))
    for i in range(7):
        var t: float = float(i + 1) / 8.0
        var y: float = lerpf(top, bottom, t * t)
        var stripe: float = lerpf(20.0, 68.0, t)
        draw_line(Vector2(cx - stripe * 0.18, y), Vector2(cx + stripe * 0.18, y), Color(GOLD.r, GOLD.g, GOLD.b, 0.46), 2.0)

func _draw_hq(w: float, h: float, compact: bool) -> void:
    var s: float = clampf(w / 1280.0, 0.62, 1.08)
    if compact:
        s *= 0.90
    var c := Vector2(w * 0.50, h * 0.49)
    _iso_plate(c + Vector2(0.0, 44.0 * s), 438.0 * s, 214.0 * s, 16.0 * s, Color("e8dfca"), WALL)

    _iso_building(c + Vector2(-158.0, -4.0) * s, Vector2(108.0, 68.0) * s, 48.0 * s, Color("e7e1d4"), GLASS, "FINANCE", s)
    _iso_building(c + Vector2(158.0, -4.0) * s, Vector2(108.0, 68.0) * s, 48.0 * s, Color("e7e1d4"), Color("8fbbb0"), "PRODUCT", s)
    _iso_building(c + Vector2(0.0, -67.0) * s, Vector2(134.0, 70.0) * s, 50.0 * s, Color("efe6d5"), Color("d39c66"), "STRATEGY", s)

    for row in range(2):
        for col in range(4):
            var p := c + Vector2(-122.0 + float(col) * 80.0, 48.0 + float(row) * 57.0) * s
            _desk(p, s, row * 4 + col)

    _lounge(c + Vector2(-150.0, 112.0) * s, s)
    _meeting(c + Vector2(146.0, 110.0) * s, s)
    _brand_mark(c + Vector2(0.0, -145.0) * s, s)
    _tower(c + Vector2(0.0, -184.0) * s, s)

func _draw_industry(w: float, h: float, compact: bool) -> void:
    var s: float = clampf(w / 1280.0, 0.60, 1.0)
    var y: float = h * (0.80 if not compact else 0.79)
    _factory(Vector2(w * 0.18, y), s, "MANUFACTURING")
    _warehouse(Vector2(w * 0.38, y + 14.0 * s), s, "LOGISTICS")
    _research(Vector2(w * 0.69, y), s, "RESEARCH")
    _store(Vector2(w * 0.85, y + 18.0 * s), s, "RETAIL")

func _draw_public_space(w: float, h: float) -> void:
    var s: float = clampf(w / 1280.0, 0.60, 1.0)
    for i in range(9):
        var x: float = w * (0.08 + 0.105 * float(i))
        var y: float = h * 0.66 + float(i % 2) * 17.0 * s
        _tree(Vector2(x, y), s * (0.84 + 0.06 * float(i % 3)))
    for i in range(6):
        _lamp(Vector2(w * (0.14 + 0.145 * float(i)), h * 0.705), s)
    _fountain(Vector2(w * 0.50, h * 0.69), s)

func _draw_city_life(w: float, h: float) -> void:
    var s: float = clampf(w / 1280.0, 0.62, 1.0)
    var starts: Array[Vector2] = [Vector2(w * 0.16, h * 0.62), Vector2(w * 0.64, h * 0.62), Vector2(w * 0.28, h * 0.86), Vector2(w * 0.72, h * 0.84)]
    var ends: Array[Vector2] = [Vector2(w * 0.39, h * 0.58), Vector2(w * 0.84, h * 0.58), Vector2(w * 0.46, h * 0.76), Vector2(w * 0.56, h * 0.74)]
    for i in range(starts.size()):
        var t: float = fmod(_time * (0.045 + 0.007 * float(i)) + float(i) * 0.21, 1.0)
        _person(starts[i].lerp(ends[i], t), s * (0.86 + 0.05 * float(i)), i)
    for i in range(3):
        var t: float = fmod(_time * (0.055 + 0.006 * float(i)) + float(i) * 0.31, 1.0)
        var travel: float = t if i % 2 == 0 else 1.0 - t
        _vehicle(Vector2(lerpf(w * 0.10, w * 0.90, travel), h * 0.625 + float(i) * 7.0), s * 0.82, i)

func _draw_badges(w: float, h: float, compact: bool) -> void:
    if compact:
        return
    var day: int = 1
    var cash: int = 0
    var state := get_tree().root.get_node_or_null("RenewGameState")
    if state != null and state.has_method("get_value"):
        day = int(state.call("get_value", "player", "day", 1))
        cash = int(state.call("get_value", "economy", "cash", 0))
    _badge(Vector2(24.0, h - 76.0), "RENEW CITY", "DAY %d" % day)
    _badge(Vector2(w - 220.0, h - 76.0), "ENTERPRISE VALUE", "$%s" % _compact_number(cash))

func _iso_plate(center: Vector2, width: float, depth: float, height: float, top: Color, side: Color) -> void:
    var hw: float = width * 0.5
    var hd: float = depth * 0.5
    var poly := PackedVector2Array([center + Vector2(0.0, -hd), center + Vector2(hw, 0.0), center + Vector2(0.0, hd), center + Vector2(-hw, 0.0)])
    draw_colored_polygon(PackedVector2Array([poly[3], poly[2], poly[2] + Vector2(0.0, height), poly[3] + Vector2(0.0, height)]), side.darkened(0.12))
    draw_colored_polygon(PackedVector2Array([poly[1], poly[2], poly[2] + Vector2(0.0, height), poly[1] + Vector2(0.0, height)]), side.darkened(0.27))
    draw_colored_polygon(poly, top)
    draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]), Color(1.0, 0.98, 0.90, 0.42), 1.4)

func _iso_building(c: Vector2, footprint: Vector2, height: float, wall: Color, accent: Color, label: String, s: float) -> void:
    _iso_plate(c, footprint.x, footprint.y, 5.0 * s, wall.lightened(0.04), WALL)
    var hw: float = footprint.x * 0.5
    var hd: float = footprint.y * 0.5
    var left := c + Vector2(-hw, 0.0)
    var top := c + Vector2(0.0, -hd)
    var right := c + Vector2(hw, 0.0)
    draw_colored_polygon(PackedVector2Array([left, top, top + Vector2(0.0, -height), left + Vector2(0.0, -height)]), wall.darkened(0.08))
    draw_colored_polygon(PackedVector2Array([top, right, right + Vector2(0.0, -height), top + Vector2(0.0, -height)]), wall.darkened(0.18))
    draw_line(left + Vector2(0.0, -height), top + Vector2(0.0, -height), accent, 2.0 * s)
    draw_line(top + Vector2(0.0, -height), right + Vector2(0.0, -height), accent, 2.0 * s)
    draw_line(left.lerp(top, 0.22) + Vector2(0.0, -height * 0.55), left.lerp(top, 0.82) + Vector2(0.0, -height * 0.55), Color(accent.r, accent.g, accent.b, 0.50), 5.0 * s)
    draw_line(top.lerp(right, 0.18) + Vector2(0.0, -height * 0.55), top.lerp(right, 0.78) + Vector2(0.0, -height * 0.55), Color(accent.r, accent.g, accent.b, 0.42), 5.0 * s)
    draw_string(ThemeDB.fallback_font, c + Vector2(-footprint.x * 0.27, footprint.y * 0.18), label, HORIZONTAL_ALIGNMENT_LEFT, footprint.x * 0.66, maxi(7, int(9.0 * s)), Color(INK.r, INK.g, INK.b, 0.72))

func _tower(p: Vector2, s: float) -> void:
    var width: float = 126.0 * s
    var depth: float = 72.0 * s
    var height: float = 136.0 * s
    var hw: float = width * 0.5
    var hd: float = depth * 0.5
    var roof := PackedVector2Array([p + Vector2(0.0, -hd - height), p + Vector2(hw, -height), p + Vector2(0.0, hd - height), p + Vector2(-hw, -height)])
    draw_colored_polygon(PackedVector2Array([p + Vector2(-hw, 0.0), p + Vector2(0.0, hd), roof[2], roof[3]]), Color("27474d"))
    draw_colored_polygon(PackedVector2Array([p + Vector2(hw, 0.0), p + Vector2(0.0, hd), roof[2], roof[1]]), Color("17363e"))
    draw_colored_polygon(roof, Color("4d7378"))
    for i in range(5):
        var yy: float = -18.0 * s - float(i) * 21.0 * s
        draw_line(p + Vector2(-hw * 0.82, yy), p + Vector2(-4.0 * s, hd * 0.72 + yy), Color(0.55, 0.82, 0.80, 0.36), 3.0 * s)
        draw_line(p + Vector2(hw * 0.82, yy), p + Vector2(4.0 * s, hd * 0.72 + yy), Color(0.36, 0.66, 0.69, 0.30), 3.0 * s)
    draw_line(roof[3], roof[0], GOLD, 2.0 * s)
    draw_line(roof[0], roof[1], GOLD, 2.0 * s)
    draw_string(ThemeDB.fallback_font, p + Vector2(-29.0 * s, -height * 0.52), "RENEW", HORIZONTAL_ALIGNMENT_CENTER, 58.0 * s, maxi(9, int(12.0 * s)), Color("f6e7b0"))

func _desk(p: Vector2, s: float, variant: int) -> void:
    var woods: Array[Color] = [Color("b9865c"), Color("a67658"), Color("c39b69"), Color("93735c")]
    var wood: Color = woods[variant % woods.size()]
    _iso_plate(p, 52.0 * s, 26.0 * s, 4.0 * s, wood, wood.darkened(0.22))
    draw_rect(Rect2(p + Vector2(-9.0, -19.0) * s, Vector2(18.0, 10.0) * s), Color("19343b"), true)
    draw_circle(p + Vector2(-14.0, 19.0) * s, 7.0 * s, Color("31464a"))
    _person(p + Vector2(14.0, 15.0) * s, s * 0.72, variant)

func _lounge(p: Vector2, s: float) -> void:
    _iso_plate(p, 116.0 * s, 64.0 * s, 4.0 * s, Color("d6c7aa"), Color("9c8d75"))
    _iso_plate(p + Vector2(-26.0, 4.0) * s, 44.0 * s, 24.0 * s, 8.0 * s, Color("5f8079"), Color("3f5d58"))
    _iso_plate(p + Vector2(30.0, 4.0) * s, 44.0 * s, 24.0 * s, 8.0 * s, Color("7e6d66"), Color("574b47"))
    _tree(p + Vector2(0.0, -20.0) * s, s * 0.55)

func _meeting(p: Vector2, s: float) -> void:
    _iso_plate(p, 120.0 * s, 70.0 * s, 4.0 * s, Color("e1d5bb"), Color("a89b81"))
    draw_circle(p, 24.0 * s, Color("c7995d"))
    draw_circle(p, 15.0 * s, Color("eadfca"))
    for i in range(5):
        var a: float = TAU * float(i) / 5.0
        draw_circle(p + Vector2(cos(a), sin(a)) * 34.0 * s, 7.0 * s, Color("39565b"))

func _brand_mark(p: Vector2, s: float) -> void:
    draw_circle(p, 28.0 * s, Color("14333b"))
    draw_circle(p, 20.0 * s, Color("275960"))
    draw_arc(p, 14.0 * s, -PI * 0.8, PI * 0.8, 22, GOLD, 4.0 * s)
    draw_line(p + Vector2(-8.0, 6.0) * s, p + Vector2(8.0, -6.0) * s, Color("f4e1a0"), 3.0 * s)

func _factory(p: Vector2, s: float, label: String) -> void:
    _iso_plate(p, 164.0 * s, 80.0 * s, 11.0 * s, Color("c8b997"), Color("81765f"))
    _iso_building(p + Vector2(-15.0, -17.0) * s, Vector2(124.0, 56.0) * s, 44.0 * s, Color("c2aa86"), ORANGE, label, s)
    for i in range(3):
        var stack := p + Vector2(42.0 + float(i) * 18.0, -55.0 - float(i) * 4.0) * s
        draw_rect(Rect2(stack - Vector2(5.0, 34.0) * s, Vector2(10.0, 34.0) * s), Color("6e665b"), true)
        draw_circle(stack - Vector2(0.0, 39.0) * s, 5.0 * s, Color(0.82, 0.84, 0.80, 0.14))

func _warehouse(p: Vector2, s: float, label: String) -> void:
    _iso_plate(p, 154.0 * s, 74.0 * s, 9.0 * s, Color("d4c8ae"), Color("8f836d"))
    _iso_building(p + Vector2(0.0, -12.0) * s, Vector2(128.0, 56.0) * s, 35.0 * s, Color("d0c1a6"), Color("6e9d9d"), label, s)

func _research(p: Vector2, s: float, label: String) -> void:
    _iso_plate(p, 148.0 * s, 78.0 * s, 9.0 * s, Color("d9d7c8"), Color("9a9686"))
    _iso_building(p + Vector2(0.0, -18.0) * s, Vector2(120.0, 58.0) * s, 50.0 * s, Color("dbe4df"), GLASS, label, s)
    draw_circle(p + Vector2(42.0, -66.0) * s, 10.0 * s, Color(GLASS.r, GLASS.g, GLASS.b, 0.38))

func _store(p: Vector2, s: float, label: String) -> void:
    _iso_plate(p, 140.0 * s, 70.0 * s, 8.0 * s, Color("d9c8aa"), Color("96846b"))
    _iso_building(p + Vector2(0.0, -13.0) * s, Vector2(114.0, 54.0) * s, 37.0 * s, Color("d9c3a6"), ORANGE, label, s)
    draw_rect(Rect2(p + Vector2(-24.0, -28.0) * s, Vector2(48.0, 20.0) * s), Color("2d5960"), true)

func _tree(p: Vector2, s: float) -> void:
    draw_rect(Rect2(p + Vector2(-2.0, 0.0) * s, Vector2(4.0, 18.0) * s), Color("76543c"), true)
    draw_circle(p + Vector2(0.0, -6.0) * s, 15.0 * s, GREEN)
    draw_circle(p + Vector2(-9.0, -2.0) * s, 9.0 * s, GREEN_LIGHT)
    draw_circle(p + Vector2(8.0, -3.0) * s, 10.0 * s, Color("4f8c63"))

func _lamp(p: Vector2, s: float) -> void:
    draw_line(p, p + Vector2(0.0, -32.0) * s, Color("546164"), 2.0 * s)
    draw_circle(p + Vector2(0.0, -34.0) * s, 4.0 * s, Color("ffe6a5"))
    _glow(p + Vector2(0.0, -34.0) * s, 14.0 * s, Color("ffd67a"), 0.11)

func _fountain(p: Vector2, s: float) -> void:
    _flat_ellipse(p, 34.0 * s, 15.0 * s, Color("8caeaa"), Color("507a78"))
    draw_circle(p, 8.0 * s, Color("d9e4db"))
    draw_line(p, p + Vector2(0.0, -18.0) * s, Color(0.64, 0.84, 0.82, 0.65), 2.0 * s)
    draw_circle(p + Vector2(0.0, -18.0) * s, 3.0 * s, Color(0.84, 0.96, 0.94, 0.85))

func _flat_ellipse(center: Vector2, rx: float, ry: float, fill: Color, edge: Color) -> void:
    var points := PackedVector2Array()
    for i in range(25):
        var a: float = TAU * float(i) / 24.0
        points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
    draw_colored_polygon(points, fill)
    draw_polyline(points, edge, 1.5)

func _person(p: Vector2, s: float, variant: int) -> void:
    var shirts: Array[Color] = [Color("d36d55"), Color("527aa3"), Color("d7a846"), Color("5a9d82"), Color("8b6f9e")]
    var skins: Array[Color] = [Color("6d402c"), Color("9a6448"), Color("c48b68"), Color("5d3829")]
    var skin: Color = skins[variant % skins.size()]
    var shirt: Color = shirts[variant % shirts.size()]
    draw_circle(p + Vector2(0.0, -12.0) * s, 4.2 * s, skin)
    draw_line(p + Vector2(0.0, -7.0) * s, p + Vector2(0.0, 5.0) * s, shirt, 5.0 * s)
    draw_line(p + Vector2(0.0, 4.0) * s, p + Vector2(-5.0, 12.0) * s, Color("26373c"), 2.0 * s)
    draw_line(p + Vector2(0.0, 4.0) * s, p + Vector2(5.0, 12.0) * s, Color("26373c"), 2.0 * s)

func _vehicle(p: Vector2, s: float, variant: int) -> void:
    var colors: Array[Color] = [Color("d8b65d"), Color("6da7a0"), Color("c76d59")]
    var c: Color = colors[variant % colors.size()]
    _iso_plate(p, 44.0 * s, 22.0 * s, 6.0 * s, c, c.darkened(0.25))
    draw_rect(Rect2(p + Vector2(-10.0, -11.0) * s, Vector2(20.0, 7.0) * s), GLASS_DARK, true)
    draw_circle(p + Vector2(-13.0, 9.0) * s, 4.0 * s, Color("142126"))
    draw_circle(p + Vector2(13.0, 9.0) * s, 4.0 * s, Color("142126"))

func _badge(pos: Vector2, title: String, value: String) -> void:
    var rect := Rect2(pos, Vector2(196.0, 52.0))
    draw_rect(rect, Color(0.04, 0.10, 0.12, 0.82), true)
    draw_rect(rect, Color(0.44, 0.57, 0.56, 0.38), false, 1.0)
    draw_string(ThemeDB.fallback_font, pos + Vector2(12.0, 18.0), title, HORIZONTAL_ALIGNMENT_LEFT, 170.0, 9, Color("a9bcba"))
    draw_string(ThemeDB.fallback_font, pos + Vector2(12.0, 39.0), value, HORIZONTAL_ALIGNMENT_LEFT, 170.0, 13, Color("f2d98b"))

func _glow(center: Vector2, radius: float, tint: Color, strength: float) -> void:
    for i in range(5, 0, -1):
        var r: float = radius * float(i) / 5.0
        var alpha: float = strength * (1.0 - float(i) / 6.0)
        draw_circle(center, r, Color(tint.r, tint.g, tint.b, alpha))

func _compact_number(value: int) -> String:
    var n: int = absi(value)
    if n >= 1000000000:
        return "%.1fB" % (float(value) / 1000000000.0)
    if n >= 1000000:
        return "%.1fM" % (float(value) / 1000000.0)
    if n >= 1000:
        return "%.1fK" % (float(value) / 1000.0)
    return str(value)
