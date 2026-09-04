extends RefCounted
class_name V1VisualTheme

const NAVY := Color("14213D")
const NAVY_2 := Color("0B132B")
const SLATE := Color("26364F")
const PANEL := Color("17243A")
const PANEL_2 := Color("1D2D47")
const TEXT := Color("F5F7FA")
const MUTED := Color("A9B6C8")
const GREEN := Color("10B981")
const GOLD := Color("D4AF37")
const RED := Color("E05252")
const BLUE := Color("4F8CFF")

static func panel_style(fill: Color = PANEL, radius: int = 10, border: Color = Color("31445F"), border_width: int = 1) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(border_width)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    return style

static func button_style(fill: Color, hover: Color, pressed: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = Color("405575")
    style.set_border_width_all(1)
    style.set_corner_radius_all(7)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    return style

static func apply_button(button: Button, accent: Color = GREEN) -> void:
    button.add_theme_font_size_override("font_size", 13)
    button.add_theme_color_override("font_color", TEXT)
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_stylebox_override("normal", button_style(SLATE, PANEL_2, NAVY_2))
    button.add_theme_stylebox_override("hover", button_style(accent.darkened(0.35), accent.darkened(0.15), NAVY_2))
    button.add_theme_stylebox_override("pressed", button_style(accent.darkened(0.5), accent.darkened(0.3), NAVY_2))
    button.add_theme_stylebox_override("disabled", button_style(Color("202C40"), Color("202C40"), Color("202C40")))

static func apply_panel(panel: Control) -> void:
    if panel is Panel:
        panel.add_theme_stylebox_override("panel", panel_style())
    elif panel is PanelContainer:
        panel.add_theme_stylebox_override("panel", panel_style())

static func apply_label(label: Label, size: int = 14, muted: bool = false) -> void:
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", MUTED if muted else TEXT)
