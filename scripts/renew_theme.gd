extends RefCounted

## RENEW central theme (UI 2.0 foundation).
## Single source of truth for the premium command-deck identity.
## Replaces the per-panel duplicated `_style()` helpers and color constants:
## screens should call these factories instead of hardcoding StyleBoxFlat,
## font sizes and colors. Pure functions only: safe to call anywhere,
## including headless tests.
const DEEP := Color("08151b")
const SURFACE := Color("0d222b")
const SURFACE_2 := Color("12303a")
const SURFACE_3 := Color("17343d")
const EDGE := Color("315b63")
const EDGE_SOFT := Color("24434b")
const GOLD := Color("f2c65c")
const GOLD_DIM := Color("d5b56e")
const GREEN := Color("58d39b")
const RED := Color("f26d6d")
const YELLOW := Color("f2c65c")
const CYAN := Color("55c7e8")
const BLUE := Color("6f9cff")
const TEXT := Color("eef8f5")
const MUTED := Color("8da9ae")

const RADIUS_CARD := 14
const RADIUS_PANEL := 10
const RADIUS_CHIP := 8

const FONT_HERO := 22
const FONT_TITLE := 20
const FONT_SECTION := 16
const FONT_BODY := 12
const FONT_SMALL := 10
const FONT_TINY := 9

const TOUCH_MIN := Vector2(44, 44)
const BUTTON_MIN := Vector2(96, 46)

static func get_palette() -> Dictionary:
    return {
        "deep": DEEP, "surface": SURFACE, "surface_2": SURFACE_2,
        "surface_3": SURFACE_3, "edge": EDGE, "edge_soft": EDGE_SOFT,
        "gold": GOLD, "gold_dim": GOLD_DIM, "green": GREEN, "red": RED,
        "yellow": YELLOW, "cyan": CYAN, "blue": BLUE,
        "text": TEXT, "muted": MUTED,
    }

static func panel_style(bg: Color, border: Color, radius: int = RADIUS_PANEL) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    return style

static func card_style() -> StyleBoxFlat:
    return panel_style(SURFACE, EDGE, RADIUS_CARD)

static func button_style(bg: Color) -> StyleBoxFlat:
    var style := panel_style(bg, EDGE, RADIUS_CHIP)
    style.content_margin_left = 10.0
    style.content_margin_right = 10.0
    style.content_margin_top = 6.0
    style.content_margin_bottom = 6.0
    return style

static func make_label(text: String, size: int = FONT_BODY, color: Color = TEXT) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

static func make_button(text: String, callback: Callable = Callable()) -> Button:
    var button := Button.new()
    button.text = text
    button.focus_mode = Control.FOCUS_NONE
    button.clip_text = true
    button.custom_minimum_size = BUTTON_MIN
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_stylebox_override("normal", button_style(SURFACE_2))
    button.add_theme_stylebox_override("hover", button_style(SURFACE_3))
    button.add_theme_stylebox_override("pressed", button_style(Color("1b3d46")))
    button.add_theme_color_override("font_color", TEXT)
    if callback.is_valid():
        button.pressed.connect(callback)
    return button

static func make_close_button(callback: Callable = Callable()) -> Button:
    var button := make_button("CLOSE", callback)
    button.name = "UniversalCloseButton"
    button.tooltip_text = "Close"
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    return button

static func money(value: int) -> String:
    return String.num_int64(value)

static func percent(value: float) -> String:
    return "%d%%" % int(round(value * 100.0))
