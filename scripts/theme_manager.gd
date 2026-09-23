extends Node
## Global RESTORA appearance service.
## Owns Dark / Light / Device theme selection, persistence, and shared premium palette.

signal theme_changed(mode: String)

const PREFS_PATH := "user://restora_ui.cfg"
const VALID_MODES := ["dark", "light", "system"]

var _mode := "dark"
var _resolved_mode := "dark"
var _theme_cache: Theme

func _ready() -> void:
    _load_preferences()
    _resolved_mode = _resolve_mode()
    ProjectSettings.set_setting("renew/ui/light_theme", _resolved_mode == "light")
    _theme_cache = _build_theme()
    if DisplayServer.is_dark_mode_supported():
        DisplayServer.set_system_theme_change_callback(Callable(self, "_on_system_theme_changed"))

func get_mode() -> String:
    return _mode

func get_resolved_mode() -> String:
    return _resolved_mode

func is_light() -> bool:
    return _resolved_mode == "light"

func set_mode(value: String) -> void:
    var normalized := value.strip_edges().to_lower()
    if not VALID_MODES.has(normalized):
        normalized = "dark"
    _mode = normalized
    _resolved_mode = _resolve_mode()
    ProjectSettings.set_setting("renew/ui/light_theme", _resolved_mode == "light")
    _theme_cache = _build_theme()
    _save_preferences()
    theme_changed.emit(_mode)

func toggle() -> void:
    set_mode("dark" if is_light() else "light")

func get_theme_resource() -> Theme:
    if _theme_cache == null:
        _theme_cache = _build_theme()
    return _theme_cache

func color(role: String) -> Color:
    var light := is_light()
    match role:
        "bg":
            return Color("e8e2d8") if light else Color("0b0d10")
        "surface":
            return Color("f6f1e8") if light else Color("151a1f")
        "surface_2":
            return Color("ddd4c6") if light else Color("20262c")
        "surface_3":
            return Color("eee8de") if light else Color("292f35")
        "selected":
            return Color("efe4ea") if light else Color("32202a")
        "border":
            return Color("b7aa98") if light else Color("3c3831")
        "text":
            return Color("292a28") if light else Color("f2efe8")
        "muted":
            return Color("71685d") if light else Color("928a80")
        "gold", "brass":
            return Color("98672a") if light else Color("c99a4b")
        "plum":
            return Color("66374f") if light else Color("7a405f")
        "success":
            return Color("557663") if light else Color("7fa88a")
        "warning":
            return Color("8b5e24") if light else Color("c28a3a")
        "danger":
            return Color("8c4337") if light else Color("b85c4a")
        "info", "world":
            return Color("4e6675") if light else Color("6b8494")
        "tech":
            return Color("516785") if light else Color("657c9d")
        "industry":
            return Color("8b573a") if light else Color("a96f45")
        "people":
            return Color("72465a") if light else Color("8f5b72")
        "scrim":
            return Color(0.22, 0.19, 0.16, 0.34) if light else Color(0.018, 0.021, 0.026, 0.72)
        _:
            return Color("292a28") if light else Color("f2efe8")

func _resolve_mode() -> String:
    if _mode != "system":
        return _mode
    if DisplayServer.is_dark_mode_supported():
        return "dark" if DisplayServer.is_dark_mode() else "light"
    return "dark"

func _on_system_theme_changed() -> void:
    if _mode != "system":
        return
    var next := _resolve_mode()
    if next == _resolved_mode:
        return
    _resolved_mode = next
    ProjectSettings.set_setting("renew/ui/light_theme", _resolved_mode == "light")
    _theme_cache = _build_theme()
    theme_changed.emit(_mode)

func _load_preferences() -> void:
    var legacy_light := bool(ProjectSettings.get_setting("renew/ui/light_theme", false))
    _mode = "light" if legacy_light else "dark"
    var file := ConfigFile.new()
    if file.load(PREFS_PATH) == OK:
        var stored := str(file.get_value("appearance", "theme_mode", _mode)).to_lower()
        if VALID_MODES.has(stored):
            _mode = stored

func _save_preferences() -> void:
    var file := ConfigFile.new()
    file.load(PREFS_PATH)
    file.set_value("appearance", "theme_mode", _mode)
    file.save(PREFS_PATH)

func _style(bg: Color, border: Color, radius := 14, shadow_alpha := 0.0) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = bg
    box.border_color = border
    box.set_border_width_all(1)
    box.set_corner_radius_all(radius)
    if shadow_alpha > 0.0:
        box.shadow_color = Color(0, 0, 0, shadow_alpha)
        box.shadow_size = 12
        box.shadow_offset = Vector2(0, 5)
    return box

func _button_style(bg: Color, border: Color, radius := 13) -> StyleBoxFlat:
    var box := _style(bg, border, radius, 0.18 if not is_light() else 0.07)
    box.content_margin_left = 14
    box.content_margin_right = 14
    box.content_margin_top = 10
    box.content_margin_bottom = 10
    return box

func _build_theme() -> Theme:
    var theme := Theme.new()
    var body_font := SystemFont.new()
    body_font.font_names = PackedStringArray(["Inter", "Roboto", "Noto Sans", "Arial"])
    body_font.font_weight = 400
    theme.default_font = body_font
    theme.default_font_size = 14
    var text := color("text")
    var muted := color("muted")
    var border := color("border")
    var surface := color("surface")
    var surface_2 := color("surface_2")
    var gold := color("gold")
    var plum := color("plum")

    theme.set_stylebox("panel", "Panel", _style(surface, border, 18, 0.24 if not is_light() else 0.08))
    theme.set_stylebox("panel", "PanelContainer", _style(surface, border, 18, 0.22 if not is_light() else 0.07))

    theme.set_stylebox("normal", "Button", _button_style(surface_2, border))
    theme.set_stylebox("hover", "Button", _button_style(surface_2.lerp(plum, 0.13), plum))
    theme.set_stylebox("pressed", "Button", _button_style(surface_2.lerp(plum, 0.22), plum))
    theme.set_stylebox("disabled", "Button", _button_style(surface_2.lerp(color("bg"), 0.25), border))
    theme.set_color("font_color", "Button", text)
    theme.set_color("font_hover_color", "Button", text)
    theme.set_color("font_pressed_color", "Button", text)
    theme.set_color("font_disabled_color", "Button", muted)
    theme.set_font_size("font_size", "Button", 13)

    theme.set_color("font_color", "Label", text)
    theme.set_color("font_color", "CheckButton", text)
    theme.set_color("font_hover_color", "CheckButton", text)
    theme.set_color("font_pressed_color", "CheckButton", text)
    theme.set_color("font_color", "CheckBox", text)
    theme.set_color("font_color", "OptionButton", text)
    theme.set_color("font_color", "SpinBox", text)

    var input := _style(surface, border, 13)
    input.content_margin_left = 12
    input.content_margin_right = 12
    input.content_margin_top = 9
    input.content_margin_bottom = 9
    var input_focus := input.duplicate() as StyleBoxFlat
    input_focus.border_color = plum
    theme.set_stylebox("normal", "LineEdit", input)
    theme.set_stylebox("focus", "LineEdit", input_focus)
    theme.set_color("font_color", "LineEdit", text)
    theme.set_color("caret_color", "LineEdit", gold)
    theme.set_color("selection_color", "LineEdit", Color(plum.r, plum.g, plum.b, 0.26))

    var progress_bg := _style(color("surface_2"), border, 7)
    var progress_fill := _style(gold, gold, 7)
    theme.set_stylebox("background", "ProgressBar", progress_bg)
    theme.set_stylebox("fill", "ProgressBar", progress_fill)
    theme.set_color("font_color", "ProgressBar", text)

    # Premium scroll treatment keeps every long management screen inside the
    # same Figma material system instead of falling back to Godot defaults.
    var scroll_track := StyleBoxFlat.new()
    scroll_track.bg_color = Color(surface_2.r, surface_2.g, surface_2.b, 0.34)
    scroll_track.set_corner_radius_all(5)
    var scroll_grabber := StyleBoxFlat.new()
    scroll_grabber.bg_color = Color(gold.r, gold.g, gold.b, 0.72)
    scroll_grabber.set_corner_radius_all(5)
    var scroll_hover := scroll_grabber.duplicate() as StyleBoxFlat
    scroll_hover.bg_color = gold
    for scrollbar_type in ["VScrollBar", "HScrollBar"]:
        theme.set_stylebox("scroll", scrollbar_type, scroll_track)
        theme.set_stylebox("grabber", scrollbar_type, scroll_grabber)
        theme.set_stylebox("grabber_highlight", scrollbar_type, scroll_hover)
        theme.set_stylebox("grabber_pressed", scrollbar_type, scroll_hover)

    return theme
