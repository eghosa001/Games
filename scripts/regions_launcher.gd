extends Node

## Persistent entry points for World Command, Business Operations, Production, Supply Chain, Empire, Intelligence, Progression, Identity, Notifications, Headquarters and Company Control.
const BUSINESS_UI := preload("res://scripts/business_operations_ui.gd")
const EXPANSION_UI := preload("res://scripts/expansion_ui.gd")
const INTELLIGENCE_UI := preload("res://scripts/empire_intelligence_ui.gd")
const PROGRESSION_UI := preload("res://scripts/empire_progression_ui.gd")
const IDENTITY_UI := preload("res://scripts/empire_identity_ui.gd")
const NOTIFICATIONS_UI := preload("res://scripts/notifications_center_ui.gd")
var button: Button
var operations_button: Button
var production_button: Button
var supply_button: Button
var expansion_button: Button
var intelligence_button: Button
var progression_button: Button
var identity_button: Button
var notifications_button: Button
var headquarters_button: Button
var system_button: Button
var hud: CanvasLayer

func _ready() -> void:
    hud = get_parent() as CanvasLayer
    call_deferred("_build")

func _build() -> void:
    # RESTORA now uses the layered MainHUD. Keep the dynamically-created depth
    # screens, but do not render the old persistent launcher strip.
    if hud == null: return
    var ui_root := hud.get_parent()
    if ui_root == null: return
    if ui_root.get_node_or_null("BusinessOperationsPanel") == null:
        var p := BUSINESS_UI.new(); p.name = "BusinessOperationsPanel"; ui_root.add_child(p)
    if ui_root.get_node_or_null("EmpireExpansionPanel") == null:
        var e := EXPANSION_UI.new(); e.name = "EmpireExpansionPanel"; ui_root.add_child(e)
    if ui_root.get_node_or_null("EmpireIntelligencePanel") == null:
        var i := INTELLIGENCE_UI.new(); i.name = "EmpireIntelligencePanel"; ui_root.add_child(i)
    if ui_root.get_node_or_null("EmpireProgressionPanel") == null:
        var p2 := PROGRESSION_UI.new(); p2.name = "EmpireProgressionPanel"; ui_root.add_child(p2)
    if ui_root.get_node_or_null("EmpireIdentityPanel") == null:
        var idp := IDENTITY_UI.new(); idp.name = "EmpireIdentityPanel"; ui_root.add_child(idp)
    if ui_root.get_node_or_null("NotificationsCenterPanel") == null:
        var n := NOTIFICATIONS_UI.new(); n.name = "NotificationsCenterPanel"; ui_root.add_child(n)

func _make_button(label:String)->Button:
    var b:=Button.new(); b.text=label; b.custom_minimum_size=Vector2(76,44); b.focus_mode=Control.FOCUS_NONE; b.add_theme_font_size_override("font_size",9); b.add_theme_color_override("font_color",Color("edf6f3")); b.add_theme_stylebox_override("normal",_style(Color("102a31"),Color("31565d"),9)); b.add_theme_stylebox_override("hover",_style(Color("1b3b40"),Color("d8b76d"),9)); b.add_theme_stylebox_override("pressed",_style(Color("18363a"),Color("d8b76d"),9)); return b

func _layout()->void:
    return

func _open_regions(): _show("RegionsPanel")
func _open_operations(): _show("BusinessOperationsPanel")
func _open_production(): _show("ProductionControlPanel")
func _open_supply(): _show("SupplyChainPanel")
func _open_expansion(): _show("EmpireExpansionPanel")
func _open_intelligence(): _show("EmpireIntelligencePanel")
func _open_progression(): _show("EmpireProgressionPanel")
func _open_identity(): _show("EmpireIdentityPanel")
func _open_notifications(): _show("NotificationsCenterPanel")
func _open_headquarters(): _show("HeadquartersPanel")
func _open_system(): _show("SaveLoadPanel")

func _show(name:String):
    var manager:=get_node_or_null("/root/RenewUIScreenManager")
    if manager!=null and manager.has_method("show_screen"):
        manager.show_screen(name)
        return
    var ui_root:=hud.get_parent() if hud!=null else null
    var target:=ui_root.get_node_or_null(name) if ui_root!=null else null
    if target==null: target=get_tree().root.get_node_or_null("Renew/"+name)
    if target==null: return
    if ui_root!=null:
        for child in ui_root.get_children():
            if child is CanvasItem and child.name.ends_with("Panel"): child.visible=false
    if target is CanvasItem: target.visible=true

func _style(bg:Color,border:Color,radius:int)->StyleBoxFlat:
    var style:=StyleBoxFlat.new(); style.bg_color=bg; style.border_color=border; style.set_border_width_all(1); style.set_corner_radius_all(radius); return style