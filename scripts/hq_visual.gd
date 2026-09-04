extends Control
class_name RenewHQVisual

var stage_index: int = 0

func set_stage(value: int) -> void:
    stage_index = clampi(value, 0, 4)
    queue_redraw()

func _ready() -> void:
    custom_minimum_size = Vector2(330, 145)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _draw() -> void:
    var box := Rect2(0, 0, size.x, size.y)
    draw_style_box(V1VisualTheme.panel_style(Color("101B2D"), 10, Color("31445F"), 1), box)
    var ground_y: float = size.y - 25.0
    draw_rect(Rect2(15, ground_y, size.x - 30, 2), V1VisualTheme.GREEN.darkened(0.35))
    var heights := [42.0, 62.0, 82.0, 106.0, 128.0]
    var widths := [105.0, 125.0, 150.0, 108.0, 86.0]
    var h: float = heights[stage_index]
    var w: float = widths[stage_index]
    var x: float = (size.x - w) * 0.5
    var y: float = ground_y - h
    var body := Color("30435F")
    var glass := Color("6A86A9")
    draw_rect(Rect2(x, y, w, h), body)
    if stage_index >= 1:
        draw_rect(Rect2(x + 8, y + 10, w - 16, 3), V1VisualTheme.GOLD)
    var floors: int = max(1, int(h / 18.0))
    for floor in range(floors):
        var fy: float = y + 10 + floor * 18
        var cols: int = max(2, int(w / 22.0))
        for col in range(cols):
            var wx: float = x + 8 + col * ((w - 16) / cols)
            draw_rect(Rect2(wx, fy, 8, 6), glass if floor <= stage_index + 1 else Color("26364F"))
    if stage_index >= 2:
        draw_rect(Rect2(x - 12, y + 18, 7, h - 18), Color("405575"))
        draw_rect(Rect2(x + w + 5, y + 18, 7, h - 18), Color("405575"))
    if stage_index >= 3:
        draw_line(Vector2(size.x * 0.5, y), Vector2(size.x * 0.5, y - 14), V1VisualTheme.GOLD, 2)
        draw_circle(Vector2(size.x * 0.5, y - 16), 3, V1VisualTheme.GOLD)
    if stage_index >= 4:
        draw_rect(Rect2(x + w * 0.5 - 4, y - 25, 8, 25), V1VisualTheme.GOLD)
        draw_circle(Vector2(x + w * 0.5, y - 28), 4, V1VisualTheme.GREEN)
