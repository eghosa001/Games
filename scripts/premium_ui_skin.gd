extends Control

## Presentation-only visual skin for the command HUD.
## It deliberately leaves gameplay callbacks, node names and screen management untouched.
## The goal is to move the interface away from generic dashboard rectangles toward a
## compact, game-first command deck inspired by polished city/tycoon simulators.

const BG := Color("071319")
const DEEP := Color("09171d")
const SURFACE := Color("0c2028")
const SURFACE_2 := Color("102a32")
const EDGE := Color("2d535b")
const GOLD := Color("d7b86f")
const GREEN := Color("67d39a")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")

var hud_root: Control
var viewport_size := Vector2.ZERO
var pulse := 0.0
var accent_points := [Vector2(0, 0), Vector2(0, 0), Vector2(0, 0)]

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    call_deferred("_install")

func _process(delta: float) -> void:
    pulse += delta
    if size != viewport_size:
        viewport_size = size
        queue_redraw()

func _install() -> void:
    var main_hud := get_node_or_null("/root/Ren/UI/MainHUD")
    if main_hud != null:
        hud_root = main_hud.get("root") as Control
    if hud_root == null and get_parent() is Control:
        hud_root = get_parent() as Control
    if hud_root == null:
        return
    _style_existing_controls(hud_root)
    queue_redraw()

func _style_existing_controls(node: Node) -> void:
    for child in node.get_children():
        if child == self:
            continue
        if child is Button:
            _style_button(child as Button)
        elif child is Panel:
            _style_panel(child as Panel)
        elif child is ColorRect:
            var rect := child as ColorRect
            if rect.name != "PremiumChromeBackground":
                rect.color = Color(rect.color.r, rect.color.g, rect.color.b, minf(rect.color.a, 0.18))
        if child is Control:
            _style_existing_controls(child)

func _style_panel(panel: Panel) -> void:
    var box := StyleBoxFlat.new()
    box.bg_color = Color(SURFACE.r, SURFACE.g, SURFACE.b, 0.90)
    box.border_color = EDGE
    box.set_border_width_all(1)
    box.set_corner_radius_all(14)
    box.shadow_color = Color(0, 0, 0, 0.38)
    box.shadow_size = 8
    box.shadow_offset = Vector2(0, 3)
    panel.add_theme_stylebox_override("panel", box)

func _style_button(button: Button) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(SURFACE_2.r, SURFACE_2.g, SURFACE_2.b, 0.94)
    normal.border_color = Color(EDGE.r, EDGE.g, EDGE.b, 0.90)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(11)
    normal.content_margin_left = 13
    normal.content_margin_right = 13
    normal.content_margin_top = 7
    normal.content_margin_bottom = 7
    var hover := normal.duplicate()
    hover.bg_color = Color("183b43")
    hover.border_color = GOLD
    hover.shadow_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.16)
    hover.shadow_size = 7
    var pressed := hover.duplicate()
    pressed.bg_color = Color("244f50")
    var disabled := normal.duplicate()
    disabled.bg_color = Color("0b181d")
    disabled.border_color = Color("1b3036")
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("disabled", disabled)
    button.add_theme_color_override("font_color", TEXT)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", GOLD)
    button.add_theme_color_override("font_disabled_color", MUTED)
    button.add_theme_font_size_override("font_size", 11)
    button.focus_mode = Control.FOCUS_NONE
    button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 46.0)
    button.text = _decorate_button_text(button.text)

func _decorate_button_text(value: String) -> String:
    var t := value.strip_edges()
    var icon := "◆"
    if t.contains("HOME"):
        icon = "⌂"
    elif t.contains("ASSET") or t.contains("PROPERTY") or t.contains("RESTOR"):
        icon = "◇"
    elif t.contains("OPERAT") or t.contains("PRODUCE") or t.contains("INPUT"):
        icon = "▣"
    elif t.contains("NETWORK") or t.contains("ALLIANCE") or t.contains("RIVAL") or t.contains("RELATION"):
        icon = "◈"
    elif t.contains("WORLD") or t.contains("MARKET") or t.contains("INFRA"):
        icon = "◎"
    elif t.contains("FINANCE") or t.contains("LOAN"):
        icon = "₿"
    elif t.contains("EMPLOYEE") or t.contains("HIRE"):
        icon = "●"
    elif t.contains("TECHNOLOGY"):
        icon = "✦"
    elif t.contains("NEWS") or t.contains("HISTORY"):
        icon = "▤"
    elif t.contains("SAVE") or t.contains("LOAD"):
        icon = "⬢"
    elif t.contains("END DAY"):
        icon = "▶"
    return icon + "  " + t

func _draw() -> void:
    var s := get_viewport_rect().size
    if s.x <= 0.0 or s.y <= 0.0:
        return
    var mobile := s.x < 760.0
    var dock_h := 78.0 if mobile else 0.0
    var top_h := 86.0 if mobile else 92.0
    draw_rect(Rect2(0, 0, s.x, 2), Color(GOLD.r, GOLD.g, GOLD.b, 0.28), true)
    draw_rect(Rect2(0, 0, s.x, top_h), Color(DEEP.r, DEEP.g, DEEP.b, 0.72), true)
    draw_line(Vector2(18, top_h - 1), Vector2(s.x - 18, top_h - 1), Color(EDGE.r, EDGE.g, EDGE.b, 0.72), 1.0)
    _corner(Vector2(18, top_h + 14), 26.0, GOLD)
    _corner(Vector2(s.x - 18, top_h + 14), -26.0, Color(GREEN.r, GREEN.g, GREEN.b, 0.72))
    if mobile:
        _draw_mobile_command_dock(s, dock_h)
    else:
        _draw_desktop_command_rail(s)
    var base := Vector2(s.x - (78 if mobile else 118), 28)
    for i in range(3):
        var alpha := 0.42 + 0.28 * sin(pulse * 1.7 + i * 1.8)
        draw_circle(base + Vector2(i * 15, 0), 3.0, Color(GREEN.r, GREEN.g, GREEN.b, alpha))

func _corner(origin: Vector2, direction: float, tint: Color) -> void:
    draw_line(origin, origin + Vector2(direction, 0), Color(tint.r, tint.g, tint.b, 0.55), 2.0)
    draw_line(origin, origin + Vector2(0, 18), Color(tint.r, tint.g, tint.b, 0.35), 2.0)

func _draw_mobile_command_dock(s: Vector2, dock_h: float) -> void:
    var y := s.y - dock_h
    var dock := Rect2(10, y + 7, s.x - 20, dock_h - 14)
    draw_style_box(_chrome_box(Color(DEEP.r, DEEP.g, DEEP.b, 0.94), EDGE, 20), dock)
    draw_line(Vector2(dock.position.x + 26, y + 7), Vector2(dock.end.x - 26, y + 7), Color(GOLD.r, GOLD.g, GOLD.b, 0.52), 1.0)
    var labels := ["⌂", "◇", "▣", "◈", "◎"]
    var names := ["HOME", "ASSETS", "OPS", "NETWORK", "WORLD"]
    var slot := (s.x - 40.0) / 5.0
    for i in range(5):
        var cx := 20.0 + slot * float(i) + slot * 0.5
        draw_circle(Vector2(cx, y + 31), 20.0, Color(SURFACE_2.r, SURFACE_2.g, SURFACE_2.b, 0.90))
        draw_arc(Vector2(cx, y + 31), 20.0, -2.7, -0.45, 18, Color(EDGE.r, EDGE.g, EDGE.b, 0.72), 1.0)
        draw_string(ThemeDB.fallback_font, Vector2(cx - 9, y + 37), labels[i], HORIZONTAL_ALIGNMENT_CENTER, 18, 16, TEXT)
        draw_string(ThemeDB.fallback_font, Vector2(cx - 35, y + 61), names[i], HORIZONTAL_ALIGNMENT_CENTER, 70, 8, MUTED)

func _draw_desktop_command_rail(s: Vector2) -> void:
    var rail := Rect2(16, 104, 190, minf(s.y - 128, 470.0))
    draw_style_box(_chrome_box(Color(DEEP.r, DEEP.g, DEEP.b, 0.78), EDGE, 18), rail)
    draw_string(ThemeDB.fallback_font, rail.position + Vector2(16, 28), "COMMAND DECK", HORIZONTAL_ALIGNMENT_LEFT, 150, 10, MUTED)
    draw_line(rail.position + Vector2(16, 38), rail.position + Vector2(174, 38), Color(GOLD.r, GOLD.g, GOLD.b, 0.38), 1.0)

func _chrome_box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = bg
    box.border_color = border
    box.set_border_width_all(1)
    box.set_corner_radius_all(radius)
    box.shadow_color = Color(0, 0, 0, 0.35)
    box.shadow_size = 10
    box.shadow_offset = Vector2(0, 4)
    return box