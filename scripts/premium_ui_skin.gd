extends Control

## RENEW premium presentation skin.
## Keeps gameplay callbacks/node names intact while unifying all screens into a
## restrained glass command deck that lets the illustrated world remain visible.

const THEME_PATH := "res://Assets/Themes/EmpireTheme.tres"
const DEEP := Color("071218")
const SURFACE := Color("0b2028")
const SURFACE_2 := Color("12313a")
const EDGE := Color("416a70")
const GOLD := Color("f2c65c")
const GREEN := Color("58d39b")
const CYAN := Color("55c7e8")
const BLUE := Color("6f9cff")
const PURPLE := Color("b78cff")
const ORANGE := Color("ff9d62")
const PINK := Color("ed7fbd")
const TEXT := Color("f4faf7")
const MUTED := Color("91a9ad")
const SUBTLE := Color("5d767b")
const PRIMARY_SECTORS := ["LIVE", "BUSINESS", "EMPIRE", "WORLD"]

var hud_root: Control
var _theme: Theme
var _theme_refresh_queued := false
var _pulse := 0.0
var _last_redraw := 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _theme = load(THEME_PATH) as Theme
    if not get_tree().tree_changed.is_connected(_queue_theme_refresh):
        get_tree().tree_changed.connect(_queue_theme_refresh)
    call_deferred("_install")

func _process(delta: float) -> void:
    _pulse += delta
    _last_redraw += delta
    if _last_redraw >= 0.20:
        _last_redraw = 0.0
        queue_redraw()

func _install() -> void:
    var main_hud := get_node_or_null("/root/Renew/UI/MainHUD")
    if main_hud != null:
        hud_root = main_hud.get("root") as Control
        _align_functional_navigation(main_hud)
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
    var main_hud := get_node_or_null("/root/Renew/UI/MainHUD")
    if main_hud != null:
        _align_functional_navigation(main_hud)
    _apply_theme_to_all_ui()
    if hud_root != null and is_instance_valid(hud_root):
        _style_existing_controls(hud_root)

func _align_functional_navigation(main_hud: Node) -> void:
    var left_rail := main_hud.get("left_rail") as Panel
    if left_rail == null or left_rail.get_child_count() == 0:
        return
    var stack := left_rail.get_child(0)
    if stack == null:
        return
    var index := 0
    for child in stack.get_children():
        if child is Button and index < PRIMARY_SECTORS.size():
            (child as Button).text = PRIMARY_SECTORS[index]
            index += 1

func _apply_theme_to_all_ui() -> void:
    if _theme == null:
        return
    var game_root := get_tree().root.get_node_or_null("Renew")
    if game_root == null:
        return
    var ui := game_root.get_node_or_null("UI")
    if ui != null:
        _apply_theme_recursive(ui)

func _apply_theme_recursive(node: Node) -> void:
    if node is Control and node != self:
        var c := node as Control
        c.theme = _theme
        c.add_theme_font_size_override("font_size", _theme.default_font_size)
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
        elif child is Label:
            _style_label(child as Label)
        elif child is ProgressBar:
            _style_progress(child as ProgressBar)
        elif child is LineEdit:
            _style_line_edit(child as LineEdit)
        elif child is ColorRect:
            var rect := child as ColorRect
            if rect.name != "PremiumChromeBackground":
                rect.color = Color(rect.color.r, rect.color.g, rect.color.b, minf(rect.color.a, 0.13))
        if child is Control:
            _style_existing_controls(child)

func _sector_accent(label: String) -> Color:
    var t := label.to_upper()
    if t.contains("FINANCE") or t.contains("LOAN") or t.contains("CASH") or t.contains("PORTFOLIO"):
        return GREEN
    if t.contains("EMPLOYEE") or t.contains("HIRE") or t.contains("PEOPLE"):
        return PINK
    if t.contains("PRODUCE") or t.contains("INPUT") or t.contains("OPERAT") or t.contains("INFRA") or t.contains("BUSINESS"):
        return ORANGE
    if t.contains("NETWORK") or t.contains("ALLIANCE") or t.contains("RIVAL") or t.contains("RELATION") or t.contains("EMPIRE"):
        return PURPLE
    if t.contains("WORLD") or t.contains("MARKET") or t.contains("REGION") or t.contains("EXPANSION"):
        return CYAN
    if t.contains("TECHNOLOGY") or t.contains("RESEARCH"):
        return BLUE
    if t.contains("NEWS") or t.contains("HISTORY") or t.contains("EVENT"):
        return GOLD
    if t.contains("LIVE") or t.contains("DASHBOARD") or t.contains("PROPERTY"):
        return GREEN
    return EDGE

func _style_panel(panel: Panel) -> void:
    var accent := _sector_accent(panel.name)
    var box := StyleBoxFlat.new()
    # More transparency than before: the world should visually continue behind cards.
    box.bg_color = Color(SURFACE.r, SURFACE.g, SURFACE.b, 0.84)
    box.border_color = Color(accent.r, accent.g, accent.b, 0.34)
    box.set_border_width_all(1)
    box.set_border_width(SIDE_TOP, 2)
    box.set_corner_radius_all(16)
    box.shadow_color = Color(0, 0, 0, 0.46)
    box.shadow_size = 12
    box.shadow_offset = Vector2(0, 5)
    box.content_margin_left = 14
    box.content_margin_right = 14
    box.content_margin_top = 12
    box.content_margin_bottom = 12
    panel.add_theme_stylebox_override("panel", box)

func _style_button(button: Button) -> void:
    var accent := _sector_accent(button.text)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(SURFACE_2.r, SURFACE_2.g, SURFACE_2.b, 0.82)
    normal.border_color = Color(accent.r, accent.g, accent.b, 0.34)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(12)
    normal.content_margin_left = 14
    normal.content_margin_right = 14
    normal.content_margin_top = 8
    normal.content_margin_bottom = 8

    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = SURFACE_2.lerp(accent, 0.17)
    hover.border_color = Color(accent.r, accent.g, accent.b, 0.92)
    hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
    hover.shadow_size = 10
    hover.shadow_offset = Vector2(0, 2)

    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = SURFACE_2.lerp(accent, 0.26)
    pressed.border_color = accent
    pressed.shadow_color = Color(accent.r, accent.g, accent.b, 0.20)
    pressed.shadow_size = 5

    var disabled := normal.duplicate() as StyleBoxFlat
    disabled.bg_color = Color("09171d", 0.72)
    disabled.border_color = Color("253a40", 0.45)

    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("disabled", disabled)
    button.add_theme_color_override("font_color", TEXT)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_color_override("font_pressed_color", Color.WHITE)
    button.add_theme_color_override("font_disabled_color", MUTED)
    button.add_theme_font_size_override("font_size", 11)
    button.focus_mode = Control.FOCUS_NONE
    button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 44.0)

func _style_label(label: Label) -> void:
    var name_upper := label.name.to_upper()
    var text_upper := label.text.to_upper()
    if name_upper.contains("TITLE") or name_upper.contains("HEADER") or text_upper.begins_with("RENEW"):
        label.add_theme_color_override("font_color", TEXT)
        label.add_theme_font_size_override("font_size", maxi(16, label.get_theme_font_size("font_size")))
    elif name_upper.contains("VALUE") or name_upper.contains("TOTAL") or name_upper.contains("AMOUNT"):
        label.add_theme_color_override("font_color", Color("f5deb0"))
    else:
        label.add_theme_color_override("font_color", Color(TEXT.r, TEXT.g, TEXT.b, 0.91))

func _style_progress(progress: ProgressBar) -> void:
    var accent := _sector_accent(progress.name)
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color("07151a", 0.70)
    bg.set_corner_radius_all(7)
    var fill := StyleBoxFlat.new()
    fill.bg_color = Color(accent.r, accent.g, accent.b, 0.92)
    fill.set_corner_radius_all(7)
    fill.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
    fill.shadow_size = 4
    progress.add_theme_stylebox_override("background", bg)
    progress.add_theme_stylebox_override("fill", fill)
    progress.add_theme_color_override("font_color", TEXT)

func _style_line_edit(line: LineEdit) -> void:
    var box := StyleBoxFlat.new()
    box.bg_color = Color("07171d", 0.80)
    box.border_color = Color(EDGE.r, EDGE.g, EDGE.b, 0.62)
    box.set_border_width_all(1)
    box.set_corner_radius_all(10)
    box.content_margin_left = 12
    box.content_margin_right = 12
    line.add_theme_stylebox_override("normal", box)
    line.add_theme_color_override("font_color", TEXT)
    line.add_theme_color_override("font_placeholder_color", MUTED)

func _draw() -> void:
    var s := get_viewport_rect().size
    if s.x <= 0.0 or s.y <= 0.0:
        return
    var mobile := s.x < 760.0
    var top_h := 84.0 if mobile else 90.0

    # Ambient header glass instead of a solid bar.
    for i in range(6):
        var alpha := 0.62 - float(i) * 0.075
        var band_h := top_h / 6.0
        draw_rect(Rect2(0, float(i) * band_h, s.x, band_h + 1), Color(DEEP.r, DEEP.g, DEEP.b, maxf(0.10, alpha)), true)
    draw_rect(Rect2(0, 0, s.x, 2), Color(GOLD.r, GOLD.g, GOLD.b, 0.46), true)
    draw_line(Vector2(18, top_h - 1), Vector2(s.x - 18, top_h - 1), Color(EDGE.r, EDGE.g, EDGE.b, 0.52), 1.0)

    _corner(Vector2(18, top_h + 14), 28.0, GOLD)
    _corner(Vector2(s.x - 18, top_h + 14), -28.0, CYAN)

    # Soft ambient glints establish depth without creating fake controls.
    var pulse := 0.22 + 0.08 * sin(_pulse * 0.85)
    _halo(Vector2(s.x * 0.22, top_h + 54), 90.0, Color(GREEN.r,GREEN.g,GREEN.b,pulse * 0.08))
    _halo(Vector2(s.x * 0.79, top_h + 38), 108.0, Color(CYAN.r,CYAN.g,CYAN.b,pulse * 0.07))

func _corner(origin: Vector2, direction: float, tint: Color) -> void:
    draw_line(origin, origin + Vector2(direction, 0), Color(tint.r, tint.g, tint.b, 0.60), 2.0)
    draw_line(origin, origin + Vector2(0, 18), Color(tint.r, tint.g, tint.b, 0.34), 2.0)

func _halo(center: Vector2, radius: float, tint: Color) -> void:
    for i in range(4, 0, -1):
        var r := radius * float(i) / 4.0
        var a := tint.a * (1.0 - float(i) / 5.0)
        draw_circle(center, r, Color(tint.r, tint.g, tint.b, a))
