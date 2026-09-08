extends Node

## Persistent entry points for World Command, Business Operations, Production, Supply Chain, Empire Expansion, Intelligence, Progression, Identity and Notifications.
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
var hud: CanvasLayer

func _ready() -> void:
    hud = get_parent() as CanvasLayer
    call_deferred("_build")
func _build() -> void:
    if hud == null: return
    button=_make_button("REGIONS"); operations_button=_make_button("OPS"); production_button=_make_button("PROD"); supply_button=_make_button("SUPPLY"); expansion_button=_make_button("EMPIRE"); intelligence_button=_make_button("INTEL"); progression_button=_make_button("PROG"); identity_button=_make_button("IDENT"); notifications_button=_make_button("NOTICES")
    button.name="RegionsLauncherButton"; operations_button.name="BusinessOperationsLauncherButton"; production_button.name="ProductionControlLauncherButton"; supply_button.name="SupplyChainLauncherButton"; expansion_button.name="EmpireExpansionLauncherButton"; intelligence_button.name="EmpireIntelligenceLauncherButton"; progression_button.name="EmpireProgressionLauncherButton"; identity_button.name="EmpireIdentityLauncherButton"; notifications_button.name="NotificationsCenterLauncherButton"
    hud.add_child(button); hud.add_child(operations_button); hud.add_child(production_button); hud.add_child(supply_button); hud.add_child(expansion_button); hud.add_child(intelligence_button); hud.add_child(progression_button); hud.add_child(identity_button); hud.add_child(notifications_button)
    button.pressed.connect(_open_regions); operations_button.pressed.connect(_open_operations); production_button.pressed.connect(_open_production); supply_button.pressed.connect(_open_supply); expansion_button.pressed.connect(_open_expansion); intelligence_button.pressed.connect(_open_intelligence); progression_button.pressed.connect(_open_progression); identity_button.pressed.connect(_open_identity); notifications_button.pressed.connect(_open_notifications)
    var ui_root:=hud.get_parent()
    if ui_root!=null and ui_root.get_node_or_null("BusinessOperationsPanel")==null: var p:=BUSINESS_UI.new(); p.name="BusinessOperationsPanel"; ui_root.add_child(p)
    if ui_root!=null and ui_root.get_node_or_null("EmpireExpansionPanel")==null: var e:=EXPANSION_UI.new(); e.name="EmpireExpansionPanel"; ui_root.add_child(e)
    if ui_root!=null and ui_root.get_node_or_null("EmpireIntelligencePanel")==null: var i:=INTELLIGENCE_UI.new(); i.name="EmpireIntelligencePanel"; ui_root.add_child(i)
    if ui_root!=null and ui_root.get_node_or_null("EmpireProgressionPanel")==null: var p2:=PROGRESSION_UI.new(); p2.name="EmpireProgressionPanel"; ui_root.add_child(p2)
    if ui_root!=null and ui_root.get_node_or_null("EmpireIdentityPanel")==null: var idp:=IDENTITY_UI.new(); idp.name="EmpireIdentityPanel"; ui_root.add_child(idp)
    if ui_root!=null and ui_root.get_node_or_null("NotificationsCenterPanel")==null: var n:=NOTIFICATIONS_UI.new(); n.name="NotificationsCenterPanel"; ui_root.add_child(n)
    _layout(); if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)
func _make_button(label:String)->Button:
    var b:=Button.new(); b.text=label; b.custom_minimum_size=Vector2(76,44); b.focus_mode=Control.FOCUS_NONE; b.add_theme_font_size_override("font_size",9); b.add_theme_color_override("font_color",Color("edf6f3")); b.add_theme_stylebox_override("normal",_style(Color("102a31"),Color("31565d"),9)); b.add_theme_stylebox_override("hover",_style(Color("1b3b40"),Color("d8b76d"),9)); b.add_theme_stylebox_override("pressed",_style(Color("18363a"),Color("d8b76d"),9)); return b
func _layout()->void:
    if button==null or operations_button==null or production_button==null or supply_button==null or expansion_button==null or intelligence_button==null or progression_button==null or identity_button==null or notifications_button==null:return
    var size:=get_viewport().get_visible_rect().size; var y:=64.0 if size.x<700.0 else 66.0; var narrow:=size.x<700.0
    var buttons:Array[Button]=[button,operations_button,production_button,supply_button,expansion_button,intelligence_button,progression_button,identity_button,notifications_button]
    var full:Array[String]=["REGIONS","OPS","PROD","SUPPLY","EMPIRE","INTEL","PROG","IDENT","NOTICES"]
    var compact:Array[String]=["REG","OPS","PRD","SUP","EMP","INT","PROG","ID","NOT"]
    if narrow:
        var gap:=2.0; var width:=maxf(31.0,(size.x-16.0-gap*8.0)/9.0); var x:=8.0
        for i in range(buttons.size()):
            buttons[i].text=compact[i]; buttons[i].size=Vector2(width,39); buttons[i].position=Vector2(x,y); buttons[i].add_theme_font_size_override("font_size",7); x+=width+gap
    else:
        var gap:=4.0; var widths:Array[float]=[70,60,68,74,78,68,62,66,76]; var total:=0.0
        for w in widths: total+=w
        total+=gap*8.0; var start:=maxf(8.0,size.x-total-8.0); var x:=start
        for i in range(buttons.size()):
            buttons[i].text=full[i]; buttons[i].size=Vector2(widths[i],42); buttons[i].position=Vector2(x,y); buttons[i].add_theme_font_size_override("font_size",9); x+=widths[i]+gap
func _open_regions(): _show("RegionsPanel")
func _open_operations(): _show("BusinessOperationsPanel")
func _open_production(): _show("ProductionControlPanel")
func _open_supply(): _show("SupplyChainPanel")
func _open_expansion(): _show("EmpireExpansionPanel")
func _open_intelligence(): _show("EmpireIntelligencePanel")
func _open_progression(): _show("EmpireProgressionPanel")
func _open_identity(): _show("EmpireIdentityPanel")
func _open_notifications(): _show("NotificationsCenterPanel")
func _show(name:String):
    var manager:=get_node_or_null("/root/RenewUIScreenManager")
    if manager!=null and manager.has_method("show_screen"): manager.show_screen(name)
func _style(bg:Color,border:Color,radius:int)->StyleBoxFlat:
    var style:=StyleBoxFlat.new(); style.bg_color=bg; style.border_color=border; style.set_border_width_all(1); style.set_corner_radius_all(radius); return style
