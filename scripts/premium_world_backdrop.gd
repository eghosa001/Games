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
    draw_rect(Rect2(0, 0, WIDTH, HEIGHT), Color("081017"), true)
    draw_rect(Rect2(0, 64, WIDTH, HEIGHT - 64), Color("0b151d"), true)

    _glow(Vector2(1120, 120), 240.0, Color("183a46"), 0.11)
    _glow(Vector2(160, 560), 280.0, Color("123d35"), 0.08)
    _glow(Vector2(690, 690), 360.0, Color("172b3c"), 0.07)

    for x in range(0, 1281, 40):
        draw_line(Vector2(x, 64), Vector2(x, HEIGHT), Color("9bb7c5", 0.035), 1.0)
    for y in range(80, 721, 40):
        draw_line(Vector2(0, y), Vector2(WIDTH, y), Color("9bb7c5", 0.028), 1.0)

    var horizon := 355.0
    draw_line(Vector2(0, horizon), Vector2(WIDTH, horizon), Color("7fa6ad", 0.09), 1.0)
    var buildings := [46, 82, 58, 116, 72, 94, 51, 132, 68, 105, 62, 88, 124, 70, 98, 58, 110, 76, 118, 64, 92, 55]
    for i in range(buildings.size()):
        var x := float(i * 60 - 20)
        var h := float(buildings[i])
        var rect := Rect2(x, horizon - h, 48, h)
        draw_rect(rect, Color("0e2029", 0.78), true)
        if i % 3 != 0:
            for wy in range(int(rect.position.y + 12), int(horizon - 8), 18):
                draw_rect(Rect2(x + 9, wy, 3, 2), Color("d4af63", 0.12), true)
                if i % 4 == 1:
                    draw_rect(Rect2(x + 27, wy, 3, 2), Color("8bd3c7", 0.09), true)

    var vanishing := Vector2(640, 348)
    for x in range(-400, 1681, 120):
        draw_line(vanishing, Vector2(x, HEIGHT), Color("8da9b4", 0.045), 1.0)
    for y in [410.0, 485.0, 580.0, 690.0]:
        draw_line(Vector2(0, y), Vector2(WIDTH, y), Color("8da9b4", 0.035), 1.0)

    for i in range(6):
        var lane := float(i) * 1.13
        var p := fmod(_time * (0.035 + i * 0.004) + lane, 1.0)
        var x := lerp(640.0, float(80 + i * 220), p)
        var y := lerp(355.0, 670.0, p * p)
        var alpha := 0.10 * (1.0 - p)
        draw_circle(Vector2(x, y), 2.0, Color("8ee6a8", alpha))
        draw_circle(Vector2(x, y), 7.0, Color("8ee6a8", alpha * 0.12))

    draw_line(Vector2(0, 64), Vector2(WIDTH, 64), Color("a6c6d2", 0.10), 1.0)
    draw_line(Vector2(0, HEIGHT - 1), Vector2(WIDTH, HEIGHT - 1), Color("a6c6d2", 0.06), 1.0)

func _glow(center: Vector2, radius: float, tint: Color, strength: float) -> void:
    for i in range(8, 0, -1):
        var r := radius * float(i) / 8.0
        var a := strength * (1.0 - float(i) / 9.0)
        draw_circle(center, r, Color(tint.r, tint.g, tint.b, a))
