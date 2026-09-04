extends Node2D

# Presentation layer: turns the simulation into a visible economic world.
var game: Node

const MAP_POINTS := [
    Vector2(145, 430),
    Vector2(300, 390),
    Vector2(455, 455),
    Vector2(610, 405),
    Vector2(735, 475),
    Vector2(600, 525)
]
const LAND_SHAPE := PackedVector2Array([
    Vector2(55, 465), Vector2(80, 405), Vector2(150, 375), Vector2(215, 392),
    Vector2(275, 360), Vector2(350, 382), Vector2(405, 420), Vector2(475, 392),
    Vector2(555, 370), Vector2(625, 392), Vector2(700, 365), Vector2(770, 405),
    Vector2(790, 470), Vector2(750, 520), Vector2(675, 532), Vector2(620, 565),
    Vector2(535, 545), Vector2(465, 575), Vector2(380, 548), Vector2(315, 570),
    Vector2(235, 540), Vector2(170, 565), Vector2(105, 530)
])

func _ready() -> void:
    game = get_tree().root.get_node_or_null("Renew")
    queue_redraw()

func _process(_delta: float) -> void:
    # Keep the presentation synced without animating an input-obscuring marker.
    queue_redraw()

func _draw() -> void:
    if game == null:
        return
    var size: Vector2 = get_viewport_rect().size
    var w: float = size.x
    var h: float = size.y
    draw_rect(Rect2(0, 0, w, h), Color("081116"), true)
    _draw_atmosphere(w, h)
    _draw_grid(w, h)
    _draw_header(w)
    _draw_warehouse(w, h)
    _draw_business(w, h)
    _draw_regions(w, h)
    _draw_network(w, h)

func _draw_atmosphere(w: float, h: float) -> void:
    draw_circle(Vector2(w * 0.78, h * 0.72), 260.0, Color("0d2024"))
    draw_circle(Vector2(w * 0.18, h * 0.78), 190.0, Color("101d22"))
    draw_rect(Rect2(0, h - 180, w, 180), Color("09151a"), true)

func _draw_grid(w: float, h: float) -> void:
    var top: float = 70.0
    var bottom: float = h - 150.0
    for x in range(0, int(w) + 1, 80):
        draw_line(Vector2(x, top), Vector2(x, bottom), Color("17262c"), 1.0)
    for y in range(int(top), int(bottom) + 1, 64):
        draw_line(Vector2(0, y), Vector2(w, y), Color("142229"), 1.0)

func _draw_header(w: float) -> void:
    # Compact brand lockup; the gold/emerald underline is the shared V1 signature.
    draw_string(ThemeDB.fallback_font, Vector2(28, 42), "RENEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("e5efee"))
    draw_line(Vector2(29, 50), Vector2(91, 50), Color("10b981"), 3.0)
    draw_line(Vector2(92, 50), Vector2(111, 50), Color("d4af37"), 3.0)
    draw_string(ThemeDB.fallback_font, Vector2(125, 41), "BUILD FROM WHAT THEY LEFT BEHIND", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("789096"))
    draw_string(ThemeDB.fallback_font, Vector2(w - 205, 41), "ECONOMIC WORLD", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("526a70"))
    draw_line(Vector2(28, 55), Vector2(w - 28, 55), Color("23353b"), 1.0)

func _draw_warehouse(w: float, h: float) -> void:
    var center: Vector2 = Vector2(w * 0.24, h * 0.32)
    var b: Rect2 = Rect2(center - Vector2(145, 82), Vector2(290, 164))
    var progress: float = clamp(float(game.restoration) / 100.0, 0.0, 1.0)
    draw_string(ThemeDB.fallback_font, b.position + Vector2(0, -18), "OLD WAREHOUSE", HORIZONTAL_ALIGNMENT_LEFT, 290, 15, Color("c9d8d9"))
    draw_rect(b, Color("152329"), true)
    draw_rect(b, Color("3a4c52"), false, 3.0)
    draw_colored_polygon(PackedVector2Array([b.position + Vector2(-12, 0), b.position + Vector2(302, 0), b.position + Vector2(255, -40), b.position + Vector2(33, -40)]), Color("203238"))
    for i in range(5):
        var wx: float = b.position.x + 25 + i * 53
        var window_color: Color = Color("5a7d72") if progress >= 1.0 else Color("263b41")
        draw_rect(Rect2(wx, b.position.y + 38, 32, 34), window_color, true)
    draw_rect(Rect2(b.position.x + 112, b.position.y + 92, 66, 72), Color("0c1519"), true)
    draw_string(ThemeDB.fallback_font, b.position + Vector2(0, 190), str(game.stage).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 290, 12, Color("9fb3b6"))
    var bar: Rect2 = Rect2(b.position + Vector2(0, 205), Vector2(290, 9))
    draw_rect(bar, Color("17282e"), true)
    draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), Color("76a89b"), true)
    draw_string(ThemeDB.fallback_font, b.position + Vector2(0, 230), "%d%% RESTORED" % int(game.restoration), HORIZONTAL_ALIGNMENT_LEFT, 290, 10, Color("74898e"))

func _draw_business(w: float, h: float) -> void:
    var x: float = w * 0.52
    var y: float = 112.0
    var width: float = min(450.0, w - x - 28.0)
    var card: Rect2 = Rect2(x, y, width, 220.0)
    draw_rect(card, Color("111d22"), true)
    draw_rect(card, Color("30464d"), false, 2.0)
    draw_string(ThemeDB.fallback_font, Vector2(x + 20, y + 34), "RENEW GOODS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("dce8e8"))
    var state: String = "OPEN" if bool(game.business_open) else "CLOSED"
    draw_string(ThemeDB.fallback_font, Vector2(x + 20, y + 58), state, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("7db29f") if bool(game.business_open) else Color("7d888b"))
    _stat(x + 20, y + 90, "INVENTORY", "%d" % int(game.finished_goods))
    _stat(x + 20, y + 116, "STAFF", "%d" % int(game.employees))
    _stat(x + 20, y + 142, "PRICE", "$%d" % int(game.player_price))
    _stat(x + 20, y + 168, "LAST PROFIT", "$%d" % int(game.last_profit))
    draw_string(ThemeDB.fallback_font, Vector2(x + 215, y + 94), "CAPACITY  LVL %d" % int(game.capacity_level), HORIZONTAL_ALIGNMENT_LEFT, width - 230, 12, Color("6f858a"))
    draw_string(ThemeDB.fallback_font, Vector2(x + 215, y + 120), "MARKETING  LVL %d" % int(game.marketing_level), HORIZONTAL_ALIGNMENT_LEFT, width - 230, 12, Color("6f858a"))
    draw_string(ThemeDB.fallback_font, Vector2(x + 215, y + 146), "REPUTATION  %d" % int(game.reputation), HORIZONTAL_ALIGNMENT_LEFT, width - 230, 12, Color("7f9b99"))
    draw_string(ThemeDB.fallback_font, Vector2(x + 215, y + 174), "TOTAL PROFIT  $%d" % int(game.total_profit), HORIZONTAL_ALIGNMENT_LEFT, width - 230, 12, Color("7f9b99"))

func _stat(x: float, y: float, label: String, value: String) -> void:
    draw_string(ThemeDB.fallback_font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, 120, 10, Color("61777d"))
    draw_string(ThemeDB.fallback_font, Vector2(x + 125, y), value, HORIZONTAL_ALIGNMENT_LEFT, 90, 12, Color("c2d1d2"))

func _draw_regions(w: float, h: float) -> void:
    var controller = game.get_node_or_null("RegionController")
    if controller == null:
        return
    var regions = controller.regions
    var count: int = int(regions.regions.size())
    var panel := Rect2(18, 350, min(810.0, w * 0.64), 205)
    draw_rect(panel, Color("0f1c21"), true)
    draw_rect(panel, Color("2a4147"), false, 2.0)
    draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 14, panel.position.y + 23), "REGIONAL EMPIRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("b5c8c9"))
    draw_string(ThemeDB.fallback_font, Vector2(panel.end.x - 250, panel.position.y + 23), "TRADE / INFRASTRUCTURE / PRESENCE", HORIZONTAL_ALIGNMENT_LEFT, 240, 9, Color("5e777c"))

    # Stylized landmass: deliberately abstract so the map reads as strategy geography,
    # not a literal real-world map. Region nodes remain anchored to simulation indices.
    draw_colored_polygon(LAND_SHAPE, Color("142a2d"))
    draw_polyline(LAND_SHAPE, Color("35545a"), 2.0, true)
    draw_line(Vector2(95, 500), Vector2(745, 425), Color("1f4143"), 1.0)
    draw_line(Vector2(175, 390), Vector2(640, 550), Color("1f4143"), 1.0)
    draw_string(ThemeDB.fallback_font, Vector2(75, 520), "WESTERN RESOURCE ROUTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("45666a"))
    draw_string(ThemeDB.fallback_font, Vector2(575, 392), "NORTHERN GROWTH ARC", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("45666a"))

    # Existing trade corridors are drawn first so active routes visually connect nodes.
    for key in regions.trade_routes:
        var route: Dictionary = regions.trade_routes[key]
        var origin: int = int(route["origin"])
        var destination: int = int(route["destination"])
        if origin < count and destination < count:
            draw_line(MAP_POINTS[origin], MAP_POINTS[destination], Color("6fa99b"), 3.0, true)
            var midpoint: Vector2 = (MAP_POINTS[origin] + MAP_POINTS[destination]) * 0.5
            draw_circle(midpoint, 3.0, Color("d4af37"))

    for i in range(min(count, MAP_POINTS.size())):
        var p: Vector2 = MAP_POINTS[i]
        var unlocked: bool = bool(regions.regions[i].get("unlocked", false))
        var selected: bool = i == int(regions.selected)
        var owned: bool = int(regions.player_presence[i]) > 0
        var radius: float = 15.0 if selected else 11.0
        var outer: Color = Color("d4af37") if selected else (Color("10b981") if owned else Color("47656b"))
        if not unlocked:
            outer = Color("394b50")
        draw_circle(p, radius + 4.0, Color("091519"))
        draw_circle(p, radius, outer)
        draw_circle(p, radius - 4.0, Color("152a2e") if unlocked else Color("182328"))
        if owned:
            draw_circle(p, 4.0, Color("b9d5cf"))
        draw_string(ThemeDB.fallback_font, p + Vector2(18, 4), str(regions.regions[i]["name"]), HORIZONTAL_ALIGNMENT_LEFT, 145, 9, Color("c7d5d5") if unlocked else Color("637477"))
        draw_string(ThemeDB.fallback_font, p + Vector2(18, 17), "T%d  M%.2fx  I%d" % [regions.regions[i]["tier"], regions.market_levels[i], regions.infrastructure[i]], HORIZONTAL_ALIGNMENT_LEFT, 120, 8, Color("71898d"))

    draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 14, panel.end.y - 13), "● OWNED    ◉ SELECTED    ○ AVAILABLE    · LOCKED", HORIZONTAL_ALIGNMENT_LEFT, 390, 9, Color("62797d"))

func _draw_network(w: float, h: float) -> void:
    var y: float = h - 150.0
    var a: Vector2 = Vector2(w * 0.14, y)
    var b: Vector2 = Vector2(w * 0.50, y - 28)
    var c: Vector2 = Vector2(w * 0.84, y)
    draw_line(a, b, Color("2e5559"), 3.0)
    draw_line(b, c, Color("2e5559"), 3.0)
    draw_circle(a, 23, Color("172b31"))
    draw_circle(b, 29, Color("1d3438"))
    draw_circle(c, 23, Color("172b31"))
    draw_circle(a, 9, Color("5d8278"))
    draw_circle(b, 12, Color("789d91"))
    draw_circle(c, 9, Color("5d8278"))
    draw_circle(b, 5, Color("b5cbc6"))
    draw_string(ThemeDB.fallback_font, a + Vector2(-42, 42), "RESOURCE", HORIZONTAL_ALIGNMENT_LEFT, 90, 10, Color("657b80"))
    draw_string(ThemeDB.fallback_font, b + Vector2(-48, 48), "RENEW HUB", HORIZONTAL_ALIGNMENT_LEFT, 100, 10, Color("91a6a9"))
    draw_string(ThemeDB.fallback_font, c + Vector2(-35, 42), "MARKET", HORIZONTAL_ALIGNMENT_LEFT, 80, 10, Color("657b80"))
