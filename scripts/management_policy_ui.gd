extends CanvasLayer

const BG := Color("07100f")
const SURFACE := Color("0d1917")
const CARD := Color("10251f")
const BORDER := Color("1e3934")
const TEXT := Color("effbf7")
const MUTED := Color("8fa7a1")
const ACCENT := Color("5eead4")
const WARN := Color("fbbf24")

var root: Control
var launcher: Button
var scrim: ColorRect
var panel: PanelContainer
var summary: Label
var alert_text: Label
var procurement: Button
var pricing: Button
var maintenance: Button
var reserve: Button
var close_button: Button
var open := false
var refresh_clock := 0.0

func _ready() -> void:
    layer = 88
    _build()
    _layout()
    _refresh()
    if not get_viewport().size_changed.is_connected(_layout):
        get_viewport().size_changed.connect(_layout)

func _policy(): return get_node_or_null("/root/RenewManagementPolicySystem")

func _build() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    launcher = _button("EXEC")
    launcher.name = "ExecutiveDeskLauncher"
    launcher.tooltip_text = "Executive policies and operating exceptions"
    launcher.pressed.connect(_toggle)
    root.add_child(launcher)

    scrim = ColorRect.new()
    scrim.color = Color(0.01,0.03,0.03,0.72)
    scrim.mouse_filter = Control.MOUSE_FILTER_STOP
    scrim.visible = false
    root.add_child(scrim)

    panel = PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _style(SURFACE, BORDER, 18))
    panel.visible = false
    root.add_child(panel)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left",16)
    margin.add_theme_constant_override("margin_right",16)
    margin.add_theme_constant_override("margin_top",14)
    margin.add_theme_constant_override("margin_bottom",14)
    panel.add_child(margin)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation",9)
    margin.add_child(box)

    var header := HBoxContainer.new()
    box.add_child(header)
    var title := _label("EXECUTIVE DESK",20,TEXT)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    close_button = _button("CLOSE")
    close_button.custom_minimum_size = Vector2(82,44)
    close_button.pressed.connect(_toggle)
    header.add_child(close_button)
    box.add_child(_label("DELEGATION & EXCEPTIONS",10,ACCENT))
    summary = _label("",11,MUTED)
    box.add_child(summary)

    var grid := GridContainer.new()
    grid.columns = 1
    grid.add_theme_constant_override("v_separation",7)
    box.add_child(grid)
    procurement = _button("PROCUREMENT")
    pricing = _button("PRICING")
    maintenance = _button("MAINTENANCE")
    reserve = _button("CASH RESERVE")
    procurement.pressed.connect(_cycle.bind("procurement"))
    pricing.pressed.connect(_cycle.bind("pricing"))
    maintenance.pressed.connect(_cycle.bind("maintenance"))
    reserve.pressed.connect(_cycle_reserve)
    grid.add_child(procurement)
    grid.add_child(pricing)
    grid.add_child(maintenance)
    grid.add_child(reserve)

    box.add_child(_label("OPERATING EXCEPTIONS",10,WARN))
    alert_text = _label("",11,TEXT)
    alert_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(alert_text)

func _style(bg:Color,border:Color,radius:int=12) -> StyleBoxFlat:
    var s:=StyleBoxFlat.new()
    s.bg_color=bg; s.border_color=border; s.set_border_width_all(1); s.set_corner_radius_all(radius)
    s.content_margin_left=12; s.content_margin_right=12; s.content_margin_top=9; s.content_margin_bottom=9
    return s

func _button(text:String) -> Button:
    var b:=Button.new()
    b.text=text; b.focus_mode=Control.FOCUS_NONE; b.custom_minimum_size=Vector2(0,48)
    b.add_theme_stylebox_override("normal",_style(CARD,BORDER,12))
    b.add_theme_stylebox_override("hover",_style(Color("16342d"),ACCENT,12))
    b.add_theme_stylebox_override("pressed",_style(Color("183b32"),ACCENT,12))
    b.add_theme_color_override("font_color",TEXT); b.add_theme_color_override("font_hover_color",TEXT)
    return b

func _label(text:String,size:int,color:Color) -> Label:
    var l:=Label.new(); l.text=text; l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_size_override("font_size",size); l.add_theme_color_override("font_color",color)
    return l

func _toggle() -> void:
    open = not open
    panel.visible=open; scrim.visible=open
    launcher.visible=not open
    _refresh()

func _cycle(kind:String) -> void:
    var policy=_policy()
    if policy==null:return
    var result:Dictionary=policy.cycle_policy(kind)
    var game=get_tree().current_scene
    if game!=null and game.get("message")!=null: game.set("message",str(result.get("message","Policy updated.")))
    _refresh()

func _cycle_reserve() -> void:
    var policy=_policy(); if policy==null:return
    var values:=[5000,7500,10000,15000,25000,50000]
    var current:=int(policy.cash_reserve); var index:=values.find(current)
    policy.set_cash_reserve(values[(maxi(0,index)+1)%values.size()]); _refresh()

func _refresh() -> void:
    var policy=_policy(); if policy==null:return
    policy.evaluate()
    summary.text="Policies reduce repetitive clicks but retain the same finance and operating rules.\n"+policy.policy_summary()
    procurement.text="PROCUREMENT   •   "+str(policy.get_policy("procurement")).to_upper()
    pricing.text="PRICING   •   "+str(policy.get_policy("pricing")).to_upper()
    maintenance.text="MAINTENANCE   •   "+str(policy.get_policy("maintenance")).to_upper()
    reserve.text="CASH RESERVE   •   $"+_money(int(policy.cash_reserve))
    alert_text.text=policy.alert_summary(6)

func _process(delta:float) -> void:
    if not open:return
    refresh_clock+=delta
    if refresh_clock>=0.75:
        refresh_clock=0.0; _refresh()

func _layout() -> void:
    if root==null:return
    var size:=get_viewport().get_visible_rect().size
    var mobile:=size.x<700.0
    launcher.position=Vector2(size.x-(84 if mobile else 98),14)
    launcher.size=Vector2(70 if mobile else 82,44)
    scrim.position=Vector2.ZERO; scrim.size=size
    var width:=minf(520.0,size.x-24.0); var height:=minf(620.0,size.y-36.0)
    panel.position=Vector2((size.x-width)/2.0,(size.y-height)/2.0)
    panel.size=Vector2(width,height)

func _money(value:int)->String:
    var digits:=str(absi(value)); var out:=""
    while digits.length()>3:
        out=","+digits.substr(digits.length()-3,3)+out; digits=digits.substr(0,digits.length()-3)
    return ("-" if value<0 else "")+digits+out
