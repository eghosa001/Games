extends Node2D
## RENEW premium environmental backdrop.
## Subtle depth, skyline silhouettes, grid perspective and animated light give the
## management screen a living-world feel without texture dependencies.

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
    var viewport_size := get_viewport().get_visible_rect().size
    var draw_width := maxf(WIDTH, viewport_size.x)
    var draw_height := maxf(HEIGHT, viewport_size.y)

    # Always paint the complete expanded viewport. On portrait Web builds the
    # engine exposes extra vertical space; leaving this area transparent makes
    # the browser's page background show through as a large gray block.
    draw_rect(Rect2(0, 0, draw_width, draw_height), Color("081017"), true)
    draw_rect(Rect2(0, 64, draw_width, draw_height - 64), Color("0b151d"), true)
    draw_rect(Rect2(0, 64, draw_width, 2), Color("d5b56b", 0.30), true)

    var center_x := draw_width * 0.5
    var center_y := draw_height * 0.72
    _glow(Vector2(draw_width * 0.88, draw_height * 0.17), minf(240.0, draw_width * 0.30), Color("183a46"), 0.11)
    _glow(Vector2(draw_width * 0.12, center_y), minf(280.0, draw_width * 0.35), Color("123d35"), 0.08)
    _glow(Vector2(center_x, draw_height * 0.90), minf(360.0, draw_width * 0.45), Color("172b3c"), 0.07)

    var grid_step := 40.0
    for x in range(0, int(draw_width) + 1, int(grid_step)):
        draw_line(Vector2(float(x), 64), Vector2(float(x), draw_height), Color("9bb7c5", 0.035), 1.0)
    for y in range(80, int(draw_height) + 1, int(grid_step)):
        draw_line(Vector2(0, float(y)), Vector2(draw_width, float(y)), Color("9bb7c5", 0.028), 1.0)

    var horizon := minf(355.0, draw_height * 0.43)
    draw_line(Vector2(0, horizon), Vector2(draw_width, horizon), Color("7fa6ad", 0.09), 1.0)
    var buildings := [46, 82, 58, 116, 72, 94, 51, 132, 68, 105, 62, 88, 124, 70, 98, 58, 110, 76, 118, 64, 92, 55]
    var building_step := maxf(44.0, draw_width / float(buildings.size()))
    var building_width := maxf(36.0, building_step - 12.0)
    for i in range(buildings.size()):
        var x := float(i) * building_step - 20.0
        var h := minf(float(buildings[i]), maxf(30.0, horizon - 72.0))
        var rect := Rect2(x, horizon - h, building_width, h)
        draw_rect(rect, Color("0e2029", 0.78), true)
        if i % 3 != 0:
            for wy in range(int(rect.position.y + 12), int(horizon - 8), 18):
                draw_rect(Rect2(x + 9, wy, 3, 2), Color("d4af63", 0.12), true)
                if i % 4 == 1:
                    draw_rect(Rect2(x + building_width * 0.56, wy, 3, 2), Color("8bd3c7", 0.09), true)

    var vanishing := Vector2(center_x, horizon - 7.0)
    for x in range(-400, int(draw_width) + 401, 120):
        draw_line(vanishing, Vector2(float(x), draw_height), Color("8da9b4", 0.045), 1.0)
    for y in [410.0, 485.0, 580.0, 690.0]:
        if y <= draw_height:
            draw_line(Vector2(0, y), Vector2(draw_width, y), Color("8da9b4", 0.035), 1.0)

    for i in range(6):
        var lane := float(i) * 1.13
        var p := fmod(_time * (0.035 + i * 0.004) + lane, 1.0)
        var x := lerp(center_x, float(80 + i * maxf(90.0, draw_width / 7.0)), p)
        var y := lerp(horizon, draw_height * 0.93, p * p)
        var alpha := 0.10 * (1.0 - p)
        draw_circle(Vector2(x, y), 2.0, Color("8ee6a8", alpha))
        draw_circle(Vector2(x, y), 7.0, Color("8ee6a8", alpha * 0.12))

    draw_line(Vector2(0, 64), Vector2(draw_width, 64), Color("a6c6d2", 0.10), 1.0)
    draw_line(Vector2(0, draw_height - 1), Vector2(draw_width, draw_height - 1), Color("a6c6d2", 0.06), 1.0)
    draw_circle(Vector2(minf(110.0, draw_width * 0.12), 116), 2.0, Color("d5b56b", 0.55))
    draw_circle(Vector2(minf(110.0, draw_width * 0.12), 116), 7.0, Color("d5b56b", 0.08))
    draw_line(Vector2(minf(122.0, draw_width * 0.13), 116), Vector2(minf(182.0, draw_width * 0.20), 116), Color("d5b56b", 0.24), 1.0)

func _glow(center: Vector2, radius: float, tint: Color, strength: float) -> void:
    for i in range(8, 0, -1):
        var r := radius * float(i) / 8.0
        var a := strength * (1.0 - float(i) / 9.0)
        draw_circle(center, r, Color(tint.r, tint.g, tint.b, a))
