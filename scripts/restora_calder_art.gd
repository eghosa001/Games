extends Control

## Native lightweight Calder Works illustration.
## Drawn with Godot canvas primitives so Android/web do not depend on SVG feature support.

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if not resized.is_connected(queue_redraw):
        resized.connect(queue_redraw)
    queue_redraw()

func _draw() -> void:
    var w := maxf(1.0, size.x)
    var h := maxf(1.0, size.y)

    var sky := Color("eadfc9")
    var ground := Color("7b765d")
    var road := Color("8b765d")
    var old_wall := Color("5c5548")
    var old_edge := Color("3d3831")
    var frame := Color("b6a58b")
    var dark_glass := Color("202827")
    var brick := Color("87503d")
    var brick_dark := Color("54332c")
    var glass := Color("6f918b")
    var brass := Color("d2a85a")
    var cream := Color("efe2c5")

    draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), sky)
    draw_circle(Vector2(w * 0.86, h * 0.18), maxf(5.0, h * 0.10), Color("dfb55f"))

    var hills := PackedVector2Array([
        Vector2(0, h * 0.66), Vector2(w * 0.18, h * 0.56),
        Vector2(w * 0.36, h * 0.64), Vector2(w * 0.56, h * 0.55),
        Vector2(w * 0.78, h * 0.62), Vector2(w, h * 0.52),
        Vector2(w, h), Vector2(0, h)
    ])
    draw_colored_polygon(hills, ground)
    draw_rect(Rect2(0, h * 0.87, w, h * 0.13), road)
    draw_line(Vector2(0, h * 0.90), Vector2(w, h * 0.90), brass, maxf(1.0, h * 0.012))

    # Original mill shell.
    var old_body := Rect2(w * 0.08, h * 0.36, w * 0.50, h * 0.46)
    draw_rect(old_body, old_wall)
    var old_roof := PackedVector2Array([
        Vector2(w * 0.06, h * 0.37),
        Vector2(w * 0.33, h * 0.20),
        Vector2(w * 0.60, h * 0.37)
    ])
    draw_polyline(old_roof, old_edge, maxf(3.0, h * 0.035))
    draw_line(Vector2(w * 0.06, h * 0.37), Vector2(w * 0.06, h * 0.82), old_edge, maxf(2.0, h * 0.018))
    draw_line(Vector2(w * 0.60, h * 0.37), Vector2(w * 0.60, h * 0.82), old_edge, maxf(2.0, h * 0.018))
    draw_line(Vector2(w * 0.06, h * 0.82), Vector2(w * 0.60, h * 0.82), old_edge, maxf(2.0, h * 0.018))

    for col in range(4):
        for row in range(2):
            var wx := w * (0.11 + float(col) * 0.115)
            var wy := h * (0.43 + float(row) * 0.18)
            var wr := Rect2(wx, wy, w * 0.075, h * 0.105)
            draw_rect(wr, dark_glass)
            draw_rect(wr, frame, false, maxf(1.0, h * 0.012))

    # Restored heritage wing.
    var restored := Rect2(w * 0.55, h * 0.31, w * 0.37, h * 0.51)
    draw_rect(restored, brick)
    draw_rect(restored, brick_dark, false, maxf(2.0, h * 0.018))
    var restored_roof := PackedVector2Array([
        Vector2(w * 0.53, h * 0.31),
        Vector2(w * 0.735, h * 0.15),
        Vector2(w * 0.94, h * 0.31)
    ])
    draw_colored_polygon(restored_roof, Color("494035"))
    draw_polyline(restored_roof, old_edge, maxf(3.0, h * 0.025))

    # Clock tower.
    draw_rect(Rect2(w * 0.685, h * 0.105, w * 0.10, h * 0.205), brick)
    var clock_center := Vector2(w * 0.735, h * 0.19)
    draw_circle(clock_center, maxf(7.0, h * 0.075), cream)
    draw_circle(clock_center, maxf(7.0, h * 0.075), old_edge, false, maxf(1.0, h * 0.012))
    draw_line(clock_center, clock_center + Vector2(0, -h * 0.045), old_edge, maxf(1.0, h * 0.012))
    draw_line(clock_center, clock_center + Vector2(w * 0.025, h * 0.025), old_edge, maxf(1.0, h * 0.012))

    for col in range(3):
        for row in range(2):
            var wx2 := w * (0.59 + float(col) * 0.105)
            var wy2 := h * (0.40 + float(row) * 0.18)
            var wr2 := Rect2(wx2, wy2, w * 0.07, h * 0.105)
            draw_rect(wr2, glass)
            draw_rect(wr2, cream, false, maxf(1.0, h * 0.012))

    # Restoration progress accent and site equipment.
    draw_rect(Rect2(w * 0.60, h * 0.76, w * 0.26, h * 0.035), brass)
    draw_rect(Rect2(w * 0.14, h * 0.82, w * 0.12, h * 0.035), brass)
    draw_rect(Rect2(w * 0.30, h * 0.82, w * 0.08, h * 0.035), brass)
    draw_circle(Vector2(w * 0.17, h * 0.87), maxf(2.0, h * 0.018), old_edge)
    draw_circle(Vector2(w * 0.23, h * 0.87), maxf(2.0, h * 0.018), old_edge)
