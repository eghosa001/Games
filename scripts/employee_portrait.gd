extends Control
class_name RenewEmployeePortrait

@export var seed: int = 0
@export var accent: Color = Color("10B981")

func _ready() -> void:
    custom_minimum_size = Vector2(92, 112)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func set_employee(employee_id: String, role: String = "") -> void:
    seed = abs(employee_id.hash())
    accent = Color("10B981") if role.to_lower().contains("manager") or role.to_lower().contains("executive") else Color("4F8CFF")
    queue_redraw()

func _draw() -> void:
    var w: float = size.x
    var h: float = size.y
    var skin_options: Array[Color] = [Color("C98F6B"), Color("B97858"), Color("E0A27B"), Color("8E5A43")]
    var hair_options: Array[Color] = [Color("171717"), Color("3A2922"), Color("5B4438"), Color("2B3542")]
    var skin: Color = skin_options[seed % skin_options.size()]
    var hair: Color = hair_options[(seed / 7) % hair_options.size()]
    var jacket: Color = accent.darkened(0.48)
    draw_style_box(V1VisualTheme.panel_style(Color("101B2D"), 10, Color("31445F"), 1), Rect2(0, 0, w, h))
    draw_circle(Vector2(w * 0.5, 42), 22, skin)
    draw_circle(Vector2(w * 0.5, 31), 23, hair)
    draw_rect(Rect2(w * 0.5 - 23, 29, 46, 17), hair)
    draw_circle(Vector2(w * 0.42, 42), 2.2, Color("18202C")); draw_circle(Vector2(w * 0.58, 42), 2.2, Color("18202C"))
    draw_line(Vector2(w * 0.45, 53), Vector2(w * 0.55, 53), Color("7D4438"), 2)
    draw_colored_polygon(PackedVector2Array([Vector2(14, h - 4), Vector2(24, 70), Vector2(w - 24, 70), Vector2(w - 14, h - 4)]), jacket)
    draw_colored_polygon(PackedVector2Array([Vector2(w * 0.5, 70), Vector2(w * 0.42, h - 4), Vector2(w * 0.58, h - 4)]), Color("E8EEF5"))
    draw_circle(Vector2(w * 0.5, 79), 3.5, accent)
    draw_line(Vector2(7, h - 14), Vector2(w - 7, h - 14), Color("405575"), 1)
