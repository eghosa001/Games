extends Node2D
## RENEW living world backdrop: bright city, greenery, roads and visible
## restoration targets. This layer is visual-only and never mutates game state.

const WIDTH := 1280.0
const HEIGHT := 720.0
var _time := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    queue_redraw()

func _process(delta: float) -> void:
    _time += delta
    queue_redraw()

func _draw() -> void:
    var size := get_viewport().get_visible_rect().size
    var w := maxf(WIDTH, size.x)
    var h := maxf(HEIGHT, size.y)
    var horizon := minf(355.0, h * 0.43)
    var ground := h * 0.58
    var center := w * 0.5

    draw_rect(Rect2(0, 0, w, h), Color("173847"), true)
    draw_rect(Rect2(0, 64, w, h - 64), Color("28545c"), true)
    draw_rect(Rect2(0, 64, w, h * 0.48), Color("32606a"), true)
    draw_rect(Rect2(0, 64, w, 3), Color("f0c66a", 0.72), true)
    _glow(Vector2(w * 0.82, 120), minf(270.0, w * 0.34), Color("f0b95c"), 0.16)
    _glow(Vector2(w * 0.18, 220), minf(260.0, w * 0.32), Color("55bfa6"), 0.13)

    # Skyline.
    var heights := [46, 82, 58, 116, 72, 94, 51, 132, 68, 105, 62, 88, 124, 70, 98, 58, 110, 76, 118, 64, 92, 55]
    var facades := [Color("31576a"), Color("3b6670"), Color("49656f"), Color("385b52"), Color("5c5d55")]
    var step := maxf(44.0, w / float(heights.size()))
    for i in range(heights.size()):
        var x := float(i) * step - 20.0
        var bw := maxf(36.0, step - 12.0)
        var bh := minf(float(heights[i]), maxf(30.0, horizon - 72.0))
        var rect := Rect2(x, horizon - bh, bw, bh)
        draw_rect(rect, facades[i % facades.size()], true)
        draw_rect(Rect2(x, rect.position.y, bw, 4), Color("d9ad5f", 0.30), true)
        for wy in range(int(rect.position.y + 12), int(horizon - 8), 18):
            if i % 2 == 0:
                draw_rect(Rect2(x + 9, wy, 5, 5), Color("f6d27a", 0.46), true)
                draw_rect(Rect2(x + bw * 0.58, wy, 5, 5), Color("82d5c4", 0.34), true)

    # Park/trees.
    draw_rect(Rect2(0, ground - 12, w, 44), Color("326d55"), true)
    for i in range(14):
        var tx := 28.0 + float(i) * maxf(70.0, w / 13.0)
        var ty := ground + 8.0 + float(i % 3) * 5.0
        draw_rect(Rect2(tx - 2, ty + 13, 4, 18), Color("72543a"), true)
        draw_circle(Vector2(tx, ty), 17.0, Color("3f8d64"), true)
        draw_circle(Vector2(tx - 7, ty + 3), 10.0, Color("55a873"), true)

    # Roads.
    draw_rect(Rect2(0, ground + 26, w, h - ground - 26), Color("34464c"), true)
    var vanishing := Vector2(center, horizon + 10.0)
    for x in range(-400, int(w) + 401, 120):
        draw_line(vanishing, Vector2(float(x), h), Color("b5c3bf", 0.13), 2.0)
    for y in [410.0, 485.0, 580.0, 690.0]:
        if y <= h:
            draw_line(Vector2(0, y), Vector2(w, y), Color("d4b86c", 0.10), 2.0)

    # Three unmistakable unfinished buildings: the player's world starts here.
    _site(w * 0.12, ground + 8.0, 170.0, 112.0, Color("a8784e"), Color("d8b85f"))
    _site(w * 0.40, ground + 8.0, 205.0, 132.0, Color("8e6b55"), Color("e0a95b"))
    _site(w * 0.70, ground + 8.0, 190.0, 120.0, Color("6d7a63"), Color("e1c06a"))

    # Moving cars/work lights.
    for i in range(7):
        var p := fmod(_time * (0.028 + i * 0.004) + float(i) * 0.14, 1.0)
        var x := lerpf(center, float(80 + i * maxf(90.0, w / 7.0)), p)
        var y := lerpf(horizon + 12.0, h * 0.93, p * p)
        var tint := Color("f4c76b") if i % 2 == 0 else Color("72d5c1")
        draw_circle(Vector2(x, y), 3.0, Color(tint.r, tint.g, tint.b, 0.75))
        draw_circle(Vector2(x, y), 9.0, Color(tint.r, tint.g, tint.b, 0.08))

    draw_line(Vector2(0, h - 1), Vector2(w, h - 1), Color("d7e7df", 0.12), 1.0)

func _site(x: float, y: float, w: float, h: float, roof: Color, accent: Color) -> void:
    draw_rect(Rect2(x, y - h, w, h), Color("172d31"), true)
    draw_rect(Rect2(x + 8, y - h + 10, w - 16, h - 18), Color("765e4d", 0.76), true)
    # Missing wall section + exposed frame = visibly incomplete property.
    draw_rect(Rect2(x + w * 0.62, y - h + 20, w * 0.28, h * 0.42), Color("21373a"), true)
    draw_rect(Rect2(x + 12, y - h - 8, w - 24, 9), roof, true)
    draw_line(Vector2(x + w * 0.62, y - h - 2), Vector2(x + w * 0.62, y - 12), accent, 3.0)
    draw_line(Vector2(x + w * 0.78, y - h + 2), Vector2(x + w * 0.78, y - 4), accent, 2.0)
    draw_line(Vector2(x + w * 0.58, y - h * 0.72), Vector2(x + w * 0.88, y - h * 0.72), accent, 2.0)
    draw_line(Vector2(x + w * 0.63, y - h * 0.72), Vector2(x + w * 0.72, y - h * 0.34), accent, 1.5)
    for wx in [0.12, 0.30, 0.48]:
        draw_rect(Rect2(x + w * wx, y - h * 0.60, 22, 30), Color("d8b15d", 0.32), true)
    draw_rect(Rect2(x + w * 0.43, y - 45, 42, 45), Color("263d40"), true)
    draw_circle(Vector2(x + 20, y + 4), 7.0, Color("18252a"), true)
    draw_circle(Vector2(x + w - 20, y + 4), 7.0, Color("18252a"), true)

func _glow(center: Vector2, radius: float, tint: Color, strength: float) -> void:
    for i in range(8, 0, -1):
        var r := radius * float(i) / 8.0
        var a := strength * (1.0 - float(i) / 9.0)
        draw_circle(center, r, Color(tint.r, tint.g, tint.b, a))
