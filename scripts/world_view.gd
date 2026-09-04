extends Node2D

# Presentation layer: turns the simulation into a visible economic world.
var game: Node

func _ready() -> void:
    game = get_tree().root.get_node_or_null("Renew")
    queue_redraw()

func _process(_delta: float) -> void:
    # Keep the presentation synced without animating an input-obscuring marker.
    queue_redraw()

func _draw() -> void:
    if game == null:
        return
    var size: Variant = get_viewport_rect().size
    var w: Variant = size.x
    var h: Variant = size.y
    _draw_grid(w, h)
    _draw_header(w)
    _draw_warehouse(w, h)
    _draw_business(w, h)
    _draw_regions(w, h)
    _draw_network(w, h)

func _draw_grid(w: float, h: float) -> void:
    var top: Variant = 70.0
    var bottom: Variant = h - 150.0
    for x in range(0, int(w) + 1, 80):
        draw_line(Vector2(x, top), Vector2(x, bottom), Color("17262c"), 1.0)
    for y in range(int(top), int(bottom) + 1, 64):
        draw_line(Vector2(0, y), Vector2(w, y), Color("142229"), 1.0)

func _draw_header(w: float) -> void:
    draw_string(ThemeDB.fallback_font, Vector2(28, 42), "RENEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("d8e5e6"))
    draw_string(ThemeDB.fallback_font, Vector2(125, 41), "BUILD FROM WHAT THEY LEFT BEHIND", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("789096"))
    draw_line(Vector2(28, 55), Vector2(w - 28, 55), Color("23353b"), 1.0)

func _draw_warehouse(w: float, h: float) -> void:
    var center: Variant = Vector2(w * 0.24, h * 0.32)
    var b: Variant = Rect2(center - Vector2(145, 82), Vector2(290, 164))
    var progress: Variant = clamp(float(game.restoration) / 100.0, 0.0, 1.0)
    draw_string(ThemeDB.fallback_font, b.position + Vector2(0, -18), "OLD WAREHOUSE", HORIZONTAL_ALIGNMENT_LEFT, 290, 15, Color("c9d8d9"))
    draw_rect(b, Color("152329"), true)
    draw_rect(b, Color("3a4c52"), false, 3.0)
    draw_colored_polygon(PackedVector2Array([b.position + Vector2(-12, 0), b.position + Vector2(302, 0), b.position + Vector2(255, -40), b.position + Vector2(33, -40)]), Color("203238"))
    for i in range(5):
        var wx: Variant = b.position.x + 25 + i * 53
        var window_color: Variant = Color("5a7d72") if progress >= 1.0 else Color("263b41")
        draw_rect(Rect2(wx, b.position.y + 38, 32, 34), window_color, true)
    draw_rect(Rect2(b.position.x + 112, b.position.y + 92, 66, 72), Color("0c1519"), true)
    draw_string(ThemeDB.fallback_font, b.position + Vector2(0, 190), str(game.stage).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 290, 12, Color("9fb3b6"))
    var bar: Variant = Rect2(b.position + Vector2(0, 205), Vector2(290, 9))
    draw_rect(bar, Color("17282e"), true)
    draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), Color("76a89b"), true)
    draw_string(ThemeDB.fallback_font, b.position + Vector2(0, 230), "%d%% RESTORED" % int(game.restoration), HORIZONTAL_ALIGNMENT_LEFT, 290, 10, Color("74898e"))

func _draw_business(w: float, h: float) -> void:
    var x: Variant = w * 0.52
    var y: Variant = 112.0
    var width: Variant = min(450.0, w - x - 28.0)
    var card: Variant = Rect2(x, y, width, 220.0)
    draw_rect(card, Color("111d22"), true)
    draw_rect(card, Color("30464d"), false, 2.0)
    draw_string(ThemeDB.fallback_font, Vector2(x + 20, y + 34), "RENEW GOODS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("dce8e8"))
    var state: Variant = "OPEN" if bool(game.business_open) else "CLOSED"
    draw_string(ThemeDB.fallback_font, Vector2(x + 20, y + 58), state, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("7db29f") if bool(game.business_open) else Color("7d888b"))
    _stat(x + 20, y + 90, "INVENTORY", "%d" % int(game.finished_goods))
    _stat(x + 20, y + 116, "STAFF", "%d" % int(game.employees))
    _stat(x + 20, y + 142, "PRICE", "$%d" % int(game.player_price))
    _stat(x + 20, y + 168, "LAST PROFIT", "$%d" % int(game.last_profit))
    draw_string(ThemeDB.fallback_font, Vector2(x + 215, y + 94), "CAPACITY  LVL %d" % int(game.capacity_level), HORIZONTAL_ALIGNMENT_LEFT, width - 230, 12, Color("6f858a"))
    draw_string(ThemeDB.fallback_font, Vector2(x + 215, y + 120), "MARKETING  LVL %d" % int(game.marketing_level), HORIZONTAL_ALIGNMENT_LEFT, width - 230, 12, Color("6f858a"))
    draw_string(ThemeDB.fallback_font, Vector2(x + 215, y + 146), "REPUTATION  %d" % int(game.reputation), HORIZONTAL_ALIGNMENT_LEFT, width - 230, 12, Color("6f858a"))
    draw_string(ThemeDB.fallback_font, Vector2(x + 215, y + 174), "TOTAL PROFIT  $%d" % int(game.total_profit), HORIZONTAL_ALIGNMENT_LEFT, width - 230, 12, Color("7f9b99"))

func _stat(x: float, y: float, label: String, value: String) -> void:
    draw_string(ThemeDB.fallback_font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, 120, 10, Color("61777d"))
    draw_string(ThemeDB.fallback_font, Vector2(x + 125, y), value, HORIZONTAL_ALIGNMENT_LEFT, 90, 12, Color("c2d1d2"))

func _draw_regions(w: float, h: float) -> void:
    # RegionController is a world-owned system, not a direct child of Renew.
    var controller = game.get_node_or_null("World/RegionController")
    if controller == null:
        return
    var regions = controller.regions
    var count: int = int(regions.regions.size())
    var card_w: Variant = (w - 72.0) / 3.0
    var card_h: Variant = 78.0
    var start_y: Variant = 350.0
    draw_string(ThemeDB.fallback_font, Vector2(28, 340), "REGIONAL EMPIRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("a9bdbe"))
    for i in range(count):
        var col: Variant = i % 3
        var row: Variant = i / 3
        var x: Variant = 18.0 + col * (card_w + 18.0)
        var y: Variant = start_y + row * (card_h + 12.0)
        var selected: Variant = i == int(regions.selected)
        var unlocked: Variant = bool(regions.regions[i].get("unlocked", false))
        var presence: Variant = int(regions.player_presence[i])
        var rivals: Variant = int(regions.rival_presence[i])
        draw_rect(Rect2(x, y, card_w, card_h), Color("17262d") if not selected else Color("1d3438"), true)
        draw_rect(Rect2(x, y, card_w, card_h), Color("587d78") if selected else Color("2b4148"), false, 2.0)
        draw_string(ThemeDB.fallback_font, Vector2(x + 10, y + 20), str(regions.regions[i]["name"]), HORIZONTAL_ALIGNMENT_LEFT, card_w - 20, 12, Color("d7e3e4"))
        var status: Variant = "LOCKED" if not unlocked else ("OWNED" if presence > 0 else "OPEN")
        draw_string(ThemeDB.fallback_font, Vector2(x + 10, y + 39), "T%d  %s" % [regions.regions[i]["tier"], status], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ffad8f") if not unlocked else Color("7db29f"))
        draw_string(ThemeDB.fallback_font, Vector2(x + 10, y + 57), "MARKET %.2fx  RIVALS %d  INFRA %d" % [regions.market_levels[i], rivals, regions.infrastructure[i]], HORIZONTAL_ALIGNMENT_LEFT, card_w - 20, 10, Color("8ca1a6"))
        draw_string(ThemeDB.fallback_font, Vector2(x + 10, y + 72), str(regions.regions[i]["special"]), HORIZONTAL_ALIGNMENT_LEFT, card_w - 20, 9, Color("6e858b"))

func _draw_network(w: float, h: float) -> void:
    var y: Variant = h - 150.0
    var a: Variant = Vector2(w * 0.14, y)
    var b: Variant = Vector2(w * 0.50, y - 28)
    var c: Variant = Vector2(w * 0.84, y)
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
