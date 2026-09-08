extends Node

## Small persistent entry point for the World Command surface.
var button: Button
var hud: CanvasLayer

func _ready() -> void:
    hud = get_parent() as CanvasLayer
    call_deferred("_build")

func _build() -> void:
    if hud == null: return
    button = Button.new()
    button.name = "RegionsLauncher"
    button.text = "REGIONS"
    button.custom_minimum_size = Vector2(92, 44)
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size", 10)
    button.add_theme_color_override("font_color", Color("edf6f3"))
    button.add_theme_stylebox_override("normal", _style(Color("102a31"), Color("31565d"), 9))
    button.add_theme_stylebox_override("hover", _style(Color("1b3b40"), Color("d8b76d"), 9))
    button.add_theme_stylebox_override("pressed", _style(Color("18363a"), Color("d8b76d"), 9))
    hud.add_child(button)
    button.pressed.connect(_open)
    _layout()
    get_viewport().size_changed.connect(_layout)

func _layout() -> void:
    if button == null: return
    var size := get_viewport().get_visible_rect().size
    var narrow := size.x < 700.0
    button.position = Vector2(size.x - 102.0, 64.0 if narrow else 66.0)
    button.size = Vector2(94.0, 44.0)

func _open() -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("show_screen"):
        manager.show_screen("RegionsPanel")

func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    return style
