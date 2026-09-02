extends Node2D

# Presentation layer: turns the simulation state into a readable game-world scene.
var game: Node
var pulse := 0.0

func _ready() -> void:
    game = get_parent()
    queue_redraw()

func _process(delta: float) -> void:
    pulse += delta
    queue_redraw()

func _draw() -> void:
    if game == null:
        return
    var size := get_viewport_rect().size
    var w := size.x
    var h := size.y
    draw_rect(Rect2(0, 0, w, h), Color("081116"), true)
    _draw_grid(w, h)
    _draw_title(w)
    _draw_warehouse(w, h)
    _draw_business(w, h)
    _draw_network(w, h)

func _draw_grid(w: float, h: float) -> void:
    var top := 70.0
    var bottom := h - 150.0
    for x in range(0, int(w) + 1, 80):
        draw_line(Vector2(x, top), Vector2(x, bottom), Color("17262c"), 1.0)
    for y in range(int(top), int(bottom) + 1, 64):
        draw_line(Vector2(0, y), Vector2(w, y), Color("142229"), 1.0)
    var names := ["OLD TOWN", "MARKET", "INDUSTRIAL", "RIVERSIDE"]
    for i in range(names.size()):
        draw_string(ThemeDB.fallback_font, Vector2(28 + i * max(1.0, (w - 170.0) / 4.0), 100), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("52676e"))

func _draw_title(w: float) -> void:
    draw_string(ThemeDB.fallback_font, Vector2(28, 42), "RENEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("d8e5e6"))
    draw_string(ThemeDB.fallback_font, Vector2(125, 41), "BUILD FROM WHAT THEY LEFT BEHIND", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("789096"))
    draw_line(Vector2(28, 55), Vector2(w - 28, 55), Color("23353b"), 1.0)

func _draw_warehouse(w: float, h: float) -> void:
    var center := Vector2(w * 0.28, h * 0.42)
    var b := Rect2(center - Vector2(145, 100), Vector2(290, 200))
    var progress := clamp(float(game.restoration) / 100.0, 0.0, 1.0)
    draw_string(ThemeDB.fallback_font, b.position + Vector2(0, -28), "OLD WAREHOUSE", HORIZONTAL_ALIGNMENT_LEFT, 290, 16, Color("c9d8d9"))
    draw_rect(b, Color("152329"), true)
    draw_rect(b, Color("3a4c52"), false, 3.0)
    draw_colored_polygon(PackedVector2Array([b.position + Vector2(-12, 0), b.position + Vector2(302, 0), b.position + Vector2(255, -42), b.position + Vector2(33, -42)]), Color("203238"))
    for i in range(5):
        var wx := b.position.x + 25 + i * 53
        var window_color := Color("5a7d72") if progress >= 1.0 else Color("263b41")
        draw_rect(Rect2(wx, b.position.y + 45, 32, 38), window_color, true)
    draw_rect(Rect2(b.position.x + 112, b.position.y + 106, 66, 94), Color("0c1519"), true)
    draw_rect(Rect2(b.position.x + 122, b.position.y + 116, 46, 84), Color("25383e"), false, 2.0)
    draw_string(ThemeDB.fallback_font, b.position + Vector2(0, 225), str(game.stage).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 290, 13, Color("9fb3b6"))
    var bar := Rect2(b.position + Vector2(0, 240), Vector2(290, 10))
    draw_rect(bar, Color("17282e"), true)
    draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), Color("76a89b"), true)
    draw_string(ThemeDB.fallback_font, b.position + Vector2(0, 268), "%d%% RESTORED" % int(game.restoration), HORIZONTAL_ALIGNMENT_LEFT, 290, 11, Color("74898e"))

func _draw_business(w: float, h: float) -> void:
    var x := w * 0.57
    var y := 140.0
    var width := min(420.0, w - x - 28.0)
    var card := Rect2(x, y, width, 230.0)
    draw_rect(card, Color("111d22"), true)
    draw_rect(card, Color("30464d"), false, 2.0)
    draw_string(ThemeDB.fallback_font, Vector2(x + 20, y + 34), "RENEW GOODS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("dce8e8"))
    var state := "OPEN" if bool(game.business_open) else "CLOSED"
    draw_string(ThemeDB.fallback_font, Vector2(x + 20, y + 58), state, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("7db29f") if bool(game.business_open) else Color("7d888b"))
    _stat(x + 20, y + 92, "INVENTORY", "%d" % int(game.finished_goods))
    _stat(x + 20, y + 120, "STAFF", "%d" % int(game.employees))
    _stat(x + 20, y + 148, "PRICE", "$%d" % int(game.player_price))
    _stat(x + 20, y + 176, "LAST PROFIT", "$%d" % int(game.last_profit))
    draw_string(ThemeDB.fallback_font, Vector2(x + 210, y + 98), "CAPACITY  LVL %d" % int(game.capacity_level), HORIZONTAL_ALIGNMENT_LEFT, width - 225, 12, Color("6f858a"))
    draw_string(ThemeDB.fallback_font, Vector2(x + 210, y + 126), "MARKETING  LVL %d" % int(game.marketing_level), HORIZONTAL_ALIGNMENT_LEFT, width - 225, 12, Color("6f858a"))
    draw_string(ThemeDB.fallback_font, Vector2(x + 210, y + 154), "REPUTATION  %d" % int(game.reputation), HORIZONTAL_ALIGNMENT_LEFT, width - 225, 12, Color("6f858a"))

func _stat(x: float, y: float, label: String, value: String) -> void:
    draw_string(ThemeDB.fallback_font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, 120, 10, Color("61777d"))
    draw_string(ThemeDB.fallback_font, Vector2(x + 125, y), value, HORIZONTAL_ALIGNMENT_LEFT, 90, 12, Color("c2d1d2"))

func _draw_network(w: float, h: float) -> void:
    var y := h - 215.0
    var a := Vector2(w * 0.14, y)
    var b := Vector2(w * 0.50, y - 35)
    var c := Vector2(w * 0.83, y)
    draw_line(a, b, Color("2e5559"), 3.0)
    draw_line(b, c, Color("2e5559"), 3.0)
    draw_circle(a, 25, Color("172b31"))
    draw_circle(b, 31, Color("1d3438"))
    draw_circle(c, 25, Color("172b31"))
    draw_circle(a, 10, Color("5d8278"))
    draw_circle(b, 13, Color("789d91"))
    draw_circle(c, 10, Color("5d8278"))
    draw_circle(a.lerp(b, 0.5 + 0.5 * sin(pulse * 2.0)), 5, Color("b5cbc6"))
    draw_string(ThemeDB.fallback_font, a + Vector2(-42, 48), "RESOURCE", HORIZONTAL_ALIGNMENT_LEFT, 90, 10, Color("657b80"))
    draw_string(ThemeDB.fallback_font, b + Vector2(-48, 53), "RENEW HUB", HORIZONTAL_ALIGNMENT_LEFT, 100, 10, Color("91a6a9"))
    draw_string(ThemeDB.fallback_font, c + Vector2(-35, 48), "MARKET", HORIZONTAL_ALIGNMENT_LEFT, 80, 10, Color("657b80"))
    draw_string(ThemeDB.fallback_font, Vector2(28, h - 174), "DISTRICT %d" % (int(game.selected_district) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("657b80"))
    draw_string(ThemeDB.fallback_font, Vector2(28, h - 154), "SUPPLY NETWORK", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("a9bdbe"))
