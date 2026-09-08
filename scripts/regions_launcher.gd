extends Node

## Persistent entry points for World Command, Business Operations, Production and Supply Chain.
const BUSINESS_UI := preload("res://scripts/business_operations_ui.gd")
var button: Button
var operations_button: Button
var production_button: Button
var supply_button: Button
var hud: CanvasLayer

func _ready() -> void:
    hud = get_parent() as CanvasLayer
    call_deferred("_build")

func _build() -> void:
    if hud == null: return
    button = _make_button("REGIONS")
    operations_button = _make_button("OPS")
    production_button = _make_button("PROD")
    supply_button = _make_button("SUPPLY")
    button.name = "RegionsLauncherButton"
    operations_button.name = "BusinessOperationsLauncherButton"
    production_button.name = "ProductionControlLauncherButton"
    supply_button.name = "SupplyChainLauncherButton"
    hud.add_child(button); hud.add_child(operations_button); hud.add_child(production_button); hud.add_child(supply_button)
    button.pressed.connect(_open_regions)
    operations_button.pressed.connect(_open_operations)
    production_button.pressed.connect(_open_production)
    supply_button.pressed.connect(_open_supply)
    var ui_root := hud.get_parent()
    if ui_root != null and ui_root.get_node_or_null("BusinessOperationsPanel") == null:
        var panel := BUSINESS_UI.new(); panel.name = "BusinessOperationsPanel"; ui_root.add_child(panel)
    _layout(); get_viewport().size_changed.connect(_layout)

func _make_button(label: String) -> Button:
    var b := Button.new(); b.text = label; b.custom_minimum_size = Vector2(76,44); b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size",9); b.add_theme_color_override("font_color",Color("edf6f3"))
    b.add_theme_stylebox_override("normal",_style(Color("102a31"),Color("31565d"),9)); b.add_theme_stylebox_override("hover",_style(Color("1b3b40"),Color("d8b76d"),9)); b.add_theme_stylebox_override("pressed",_style(Color("18363a"),Color("d8b76d"),9)); return b

func _layout() -> void:
    if button == null or operations_button == null or production_button == null or supply_button == null:return
    var size:=get_viewport().get_visible_rect().size; var y:=64.0 if size.x<700.0 else 66.0
    var narrow:=size.x<520.0
    if narrow:
        button.size=Vector2(76,40); operations_button.size=Vector2(64,40); production_button.size=Vector2(70,40); supply_button.size=Vector2(72,40)
        button.position=Vector2(size.x-80,y); operations_button.position=Vector2(size.x-148,y); production_button.position=Vector2(size.x-222,y); supply_button.position=Vector2(size.x-298,y)
    else:
        button.size=Vector2(82,44); operations_button.size=Vector2(70,44); production_button.size=Vector2(80,44); supply_button.size=Vector2(84,44)
        button.position=Vector2(size.x-90,y); operations_button.position=Vector2(size.x-166,y); production_button.position=Vector2(size.x-252,y); supply_button.position=Vector2(size.x-340,y)

func _open_regions(): _show("RegionsPanel")
func _open_operations(): _show("BusinessOperationsPanel")
func _open_production(): _show("ProductionControlPanel")
func _open_supply(): _show("SupplyChainPanel")
func _show(name:String):
    var manager:=get_node_or_null("/root/RenewUIScreenManager")
    if manager!=null and manager.has_method("show_screen"):manager.show_screen(name)
func _style(bg:Color,border:Color,radius:int)->StyleBoxFlat:
    var style:=StyleBoxFlat.new();style.bg_color=bg;style.border_color=border;style.set_border_width_all(1);style.set_corner_radius_all(radius);return style
