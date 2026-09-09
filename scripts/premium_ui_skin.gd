extends Control

## RENEW premium presentation skin.
## Applies one coherent command-deck theme to every UI screen while preserving
## gameplay callbacks, node names and screen-management behavior.

const THEME_PATH := "res://Assets/Themes/EmpireTheme.tres"
const DEEP := Color("08151b")
const SURFACE := Color("0d222b")
const SURFACE_2 := Color("12303a")
const EDGE := Color("315b63")
const GOLD := Color("f2c65c")
const GREEN := Color("58d39b")
const CYAN := Color("55c7e8")
const BLUE := Color("6f9cff")
const PURPLE := Color("b78cff")
const ORANGE := Color("ff9d62")
const PINK := Color("ed7fbd")
const TEXT := Color("eef8f5")
const MUTED := Color("8da9ae")

var hud_root: Control
var viewport_size := Vector2.ZERO
var _theme: Theme
var _theme_refresh_queued := false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _theme = load(THEME_PATH) as Theme
    if not get_tree().tree_changed.is_connected(_queue_theme_refresh):
        get_tree().tree_changed.connect(_queue_theme_refresh)
    call_deferred("_install")

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        viewport_size = size
        queue_redraw()

func _install() -> void:
    var main_hud := get_node_or_null("/root/Renew/UI/MainHUD")
    if main_hud != null:
        hud_root = main_hud.get("root") as Control
    if hud_root == null and get_parent() is Control:
        hud_root = get_parent() as Control
    _apply_theme_to_all_ui()
    if hud_root != null:
        _style_existing_controls(hud_root)
    queue_redraw()

func _queue_theme_refresh() -> void:
    if _theme_refresh_queued:
        return
    _theme_refresh_queued = true
    call_deferred("_run_theme_refresh")

func _run_theme_refresh() -> void:
    _theme_refresh_queued = false
    _apply_theme_to_all_ui()
    if hud_root != null and is_instance_valid(hud_root):
        _style_existing_controls(hud_root)

func _apply_theme_to_all_ui() -> void:
    if _theme == null:
        return
    var game_root := get_tree().root.get_node_or_null("Renew")
    if game_root == null:
        return
    var ui := game_root.get_node_or_null("UI")
    if ui == null:
        return
    _apply_theme_recursive(ui)

func _apply_theme_recursive(node: Node) -> void:
    if node is Control and node != self:
        var control := node as Control
        control.theme = _theme
        control.add_theme_font_size_override("font_size", _theme.default_font_size)
    for child in node.get_children():
        _apply_theme_recursive(child)

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
                rect.color = Color(rect.color.r, rect.color.g, rect.color.b, minf(rect.color.a, 0.20))
        if child is Control:
            _style_existing_controls(child)

func _sector_accent(label: String) -> Color:
    var t := label.to_upper()
    if t.contains("FINANCE") or t.contains("LOAN") or t.contains("CASH") or t.contains("PORTFOLIO"):
        return GREEN
    if t.contains("EMPLOYEE") or t.contains("HIRE") or t.contains("PEOPLE"):
        return PINK
    if t.contains("PRODUCE") or t.contains("INPUT") or t.contains("OPERAT") or t.contains("INFRA"):
        return ORANGE
    if t.contains("NETWORK") or t.contains("ALLIANCE") or t.contains("RIVAL") or t.contains("RELATION"):
        return PURPLE
    if t.contains("WORLD") or t.contains("MARKET") or t.contains("REGION") or t.contains("EXPANSION"):
        return CYAN
    if t.contains("TECHNOLOGY") or t.contains("RESEARCH"):
        return BLUE
    if t.contains("NEWS") or t.contains("HISTORY") or t.contains("EVENT"):
        return GOLD
    return EDGE

func _style_panel(panel: Panel) -> void:
    var accent := _sector_accent(panel.name)
    var box := StyleBoxFlat.new()
    box.bg_color = Color(SURFACE.r, SURFACE.g, SURFACE.b, 0.94)
    box.border_color = Color(accent.r, accent.g, accent.b, 0.62)
    box.set_border_width_all(1)
    box.set_border_width(SIDE_LEFT, 3)
    box.set_corner_radius_all(14)
    box.shadow_color = Color(0, 0, 0, 0.40)
    box.shadow_size = 9
    box.shadow_offset = Vector2(0, 3)
    panel.add_theme_stylebox_override("panel", box)

func _style_button(button: Button) -> void:
    var accent := _sector_accent(button.text)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(SURFACE_2.r, SURFACE_2.g, SURFACE_2.b, 0.96)
    normal.border_color = Color(accent.r, accent.g, accent.b, 0.55)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(11)
    normal.content_margin_left = 13
    normal.content_margin_right = 13
    normal.content_margin_top = 7
    normal.content_margin_bottom = 7
    var hover := normal.duplicate()
    hover.bg_color = Color(accent.r * 0.20 + SURFACE_2.r * 0.80, accent.g * 0.20 + SURFACE_2.g * 0.80, accent.b * 0.20 + SURFACE_2.b * 0.80, 1.0)
    hover.border_color = accent
    hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.22)
    hover.shadow_size = 8
    var pressed := hover.duplicate()
    pressed.bg_color = Color(accent.r * 0.30 + SURFACE_2.r * 0.70, accent.g * 0.30 + SURFACE_2.g * 0.70, accent.b * 0.30 + SURFACE_2.b * 0.70, 1.0)
    var disabled := normal.duplicate()
    disabled.bg_color = Color("0a171c")
    disabled.border_color = Color("263a40")
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("disabled", disabled)
    button.add_theme_color_override("font_color", TEXT)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", accent)
    button.add_theme_color_override("font_disabled_color", MUTED)
    button.add_theme_font_size_override("font_size", 11)
    button.focus_mode = Control.FOCUS_NONE
    button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 46.0)

func _draw() -> void:
    var s := get_viewport_rect().size
    if s.x <= 0.0 or s.y <= 0.0:
        return
    var mobile := s.x < 760.0
    var dock_h := 78.0 if mobile else 0.0
    var top_h := 86.0 if mobile else 92.0
    draw_rect(Rect2(0, 0, s.x, 2), Color(GOLD.r, GOLD.g, GOLD.b, 0.34), true)
    draw_rect(Rect2(0, 0, s.x, top_h), Color(DEEP.r, DEEP.g, DEEP.b, 0.76), true)
    draw_line(Vector2(18, top_h - 1), Vector2(s.x - 18, top_h - 1), Color(EDGE.r, EDGE.g, EDGE.b, 0.72), 1.0)
    _corner(Vector2(18, top_h + 14), 26.0, GOLD)
    _corner(Vector2(s.x - 18, top_h + 14), -26.0, CYAN)

    # Secondary screens are deliberately presented as focused workspaces.
    # Hide the persistent navigation chrome while one is open so the player
    # sees the active task rather than multiple competing command surfaces.
    var screen_manager := get_tree().root.get_node_or_null("RenewUIScreenManager")
    var secondary_screen_open := screen_manager != null and screen_manager.get_active_screen_name() != ""
    if secondary_screen_open:
        return

    if mobile:
        _draw_mobile_command_dock(s, dock_h)
    else:
        _draw_desktop_command_rail(s)

func _corner(origin: Vector2, direction: float, tint: Color) -> void:
    draw_line(origin, origin + Vector2(direction, 0), Color(tint.r, tint.g, tint.b, 0.60), 2.0)
    draw_line(origin, origin + Vector2(0, 18), Color(tint.r, tint.g, tint.b, 0.38), 2.0)

func _draw_mobile_command_dock(s: Vector2, dock_h: float) -> void:
    var y := s.y - dock_h
    var dock := Rect2(10, y + 7, s.x - 20, dock_h - 14)
    draw_style_box(_chrome_box(Color(DEEP.r, DEEP.g, DEEP.b, 0.96), EDGE, 20), dock)
    draw_line(Vector2(dock.position.x + 26, y + 7), Vector2(dock.end.x - 26, y + 7), Color(GOLD.r, GOLD.g, GOLD.b, 0.58), 1.0)
    var labels := ["⌂", "◇", "▣", "◈", "◎"]
    var names := ["HOME", "ASSETS", "OPS", "NETWORK", "WORLD"]
    var tints := [GREEN, CYAN, ORANGE, PURPLE, BLUE]
    var slot := (s.x - 40.0) / 5.0
    for i in range(5):
        var cx := 20.0 + slot * float(i) + slot * 0.5
        draw_circle(Vector2(cx, y + 31), 20.0, Color(SURFACE_2.r, SURFACE_2.g, SURFACE_2.b, 0.92))
        draw_arc(Vector2(cx, y + 31), 20.0, -2.7, -0.45, 18, Color(tints[i].r, tints[i].g, tints[i].b, 0.72), 2.0)
        draw_string(ThemeDB.fallback_font, Vector2(cx - 9, y + 37), labels[i], HORIZONTAL_ALIGNMENT_CENTER, 18, 16, tints[i])
        draw_string(ThemeDB.fallback_font, Vector2(cx - 35, y + 61), names[i], HORIZONTAL_ALIGNMENT_CENTER, 70, 8, MUTED)

func _draw_desktop_command_rail(s: Vector2) -> void:
    var rail := Rect2(16, 104, 190, minf(s.y - 128, 470.0))
    draw_style_box(_chrome_box(Color(DEEP.r, DEEP.g, DEEP.b, 0.82), EDGE, 18), rail)
    draw_string(ThemeDB.fallback_font, rail.position + Vector2(16, 28), "COMMAND DECK", HORIZONTAL_ALIGNMENT_LEFT, 150, 10, MUTED)
    draw_line(rail.position + Vector2(16, 38), rail.position + Vector2(174, 38), Color(GOLD.r, GOLD.g, GOLD.b, 0.42), 1.0)
    var legend := [["FINANCE", GREEN], ["PEOPLE", PINK], ["OPS", ORANGE], ["WORLD", CYAN], ["NETWORK", PURPLE]]
    for i in range(legend.size()):
        var tint: Color = legend[i][1]
        draw_circle(rail.position + Vector2(20, 60 + i * 22), 4.0, tint)
        draw_string(ThemeDB.fallback_font, rail.position + Vector2(31, 64 + i * 22), legend[i][0], HORIZONTAL_ALIGNMENT_LEFT, 120, 9, MUTED)

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
