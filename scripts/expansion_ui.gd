extends CanvasLayer

## Empire expansion command center. Presentation delegates all transactions to Main/authoritative expansion systems.
var panel: Panel
var title_label: Label
var status_label: Label
var summary_label: Label
var list_scroll: ScrollContainer
var list: VBoxContainer
var detail_panel: Panel
var detail_label: Label
var action_row: GridContainer
var buy_button: Button
var upgrade_button: Button
var transport_button: Button
var close_button: Button
var selected_index := 0
var refresh_clock := 0.0
var last_signature := ""

const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const SURFACE_3 := Color("132f38")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56e")
const GREEN := Color(0.25,0.85,0.45)
const YELLOW := Color(0.95,0.75,0.20)
const RED := Color(0.95,0.30,0.30)

func _ready() -> void:
    layer = 73
    _build_ui()
    _layout()
    _refresh(true)
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)

func _process(delta: float) -> void:
    if not visible or panel == null or not panel.visible: return
    refresh_clock += delta
    if refresh_clock >= 1.0:
        refresh_clock = 0.0
        _refresh(false)

func _main(): return get_tree().current_scene

func _style(bg: Color, border: Color, radius := 10) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(1)
    s.set_corner_radius_all(radius)
    return s

func _button(text: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.focus_mode = Control.FOCUS_NONE
    b.custom_minimum_size = Vector2(0,46)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.add_theme_font_size_override("font_size",10)
    b.add_theme_color_override("font_color",TEXT)
    b.add_theme_stylebox_override("normal",_style(SURFACE_2,BORDER,8))
    b.add_theme_stylebox_override("hover",_style(Color("17343d"),ACCENT,8))
    b.add_theme_stylebox_override("pressed",_style(Color("1b3d46"),ACCENT,8))
    b.pressed.connect(callback)
    return b

func _label(text: String, size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size",size)
    l.add_theme_color_override("font_color",color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return l

func _build_ui() -> void:
    panel = Panel.new()
    panel.name = "EmpireExpansionPanel"
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.add_theme_stylebox_override("panel",_style(SURFACE,BORDER,14))
    add_child(panel)
    title_label = _label("EMPIRE EXPANSION COMMAND",20,TEXT); panel.add_child(title_label)
    status_label = _label("ASSET STRATEGY  •  LIVE",10,ACCENT); panel.add_child(status_label)
    close_button = _button("CLOSE",_close); close_button.size_flags_horizontal=Control.SIZE_SHRINK_END; panel.add_child(close_button)
    summary_label = _label("",11,MUTED); panel.add_child(summary_label)
    list_scroll = ScrollContainer.new(); list_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; list_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO; panel.add_child(list_scroll)
    list = VBoxContainer.new(); list.add_theme_constant_override("separation",7); list_scroll.add_child(list)
    detail_panel = Panel.new(); detail_panel.add_theme_stylebox_override("panel",_style(SURFACE_3,BORDER,10)); panel.add_child(detail_panel)
    detail_label = _label("",11,TEXT); detail_panel.add_child(detail_label)
    action_row = GridContainer.new(); action_row.columns = 3; action_row.add_theme_constant_override("h_separation",7); action_row.add_theme_constant_override("v_separation",7); panel.add_child(action_row)
    buy_button = _button("ACQUIRE",_buy); upgrade_button = _button("UPGRADE",_upgrade); transport_button = _button("TRANSPORT",_transport)
    action_row.add_child(buy_button); action_row.add_child(upgrade_button); action_row.add_child(transport_button)

func _expansion():
    var main = _main()
    return main.command_system.expansion_system.expansion if main != null and main.command_system != null else null

func _refresh(force := false) -> void:
    var e = _expansion()
    if e == null: return
    var rep := int(_main().reputation)
    e.unlock_from_reputation(rep)
    var props: Array = e.properties
    var owned := 0
    var unlocked := 0
    for p in props:
        if bool(p.get("owned",false)): owned += 1
        if bool(p.get("unlocked",false)): unlocked += 1
    var capacity: Dictionary = _main().command_system.expansion_system.management_capacity()
    summary_label.text = "%d ASSETS OWNED  •  %d/%d MANAGEMENT  •  REP %d  •  %d UNLOCKED" % [owned,int(capacity.get("used",0)),int(capacity.get("capacity",0)),rep,unlocked]
    var sig := "%d:%d:%d" % [owned,rep,int(e.management_level)]
    for p in props: sig += ":%s:%d:%s:%d" % [str(p.get("name","")),int(p.get("level",1)),str(p.get("owned",false)),int(p.get("condition",0))]
    if not force and sig == last_signature:
        _show_detail()
        return
    last_signature = sig
    for child in list.get_children(): child.queue_free()
    for i in range(props.size()): _add_asset_row(i,props[i])
    selected_index = clampi(selected_index,0,max(0,props.size()-1))
    _show_detail()
    _layout()

func _add_asset_row(index:int,p:Dictionary) -> void:
    var unlocked := bool(p.get("unlocked",false))
    var owned := bool(p.get("owned",false))
    var state := "OPERATING" if owned and bool(p.get("active",false)) else ("OWNED" if owned else ("AVAILABLE" if unlocked else "LOCKED"))
    var row := _button("%s  •  %s\n%s  •  L%d  •  $%d" % [str(p.get("name","Asset")),state,str(p.get("industry","General")),int(p.get("level",1)),int(p.get("cost",0))],Callable(self,"_select").bind(index))
    row.custom_minimum_size.y=62
    row.disabled=not unlocked
    row.tooltip_text="Requires %d reputation." % int(p.get("unlock_rep",0)) if not unlocked else "Inspect this expansion asset."
    list.add_child(row)

func _select(index:int) -> void:
    selected_index=index
    var main=_main()
    if main!=null and main.has_method("select_expansion"): main.select_expansion(index)
    _show_detail()

func _show_detail() -> void:
    var e=_expansion()
    if e==null or e.properties.is_empty(): detail_label.text="No expansion assets are configured."; return
    var p:Dictionary=e.get_property(selected_index)
    if p.is_empty(): return
    var owned:=bool(p.get("owned",false)); var unlocked:=bool(p.get("unlocked",false)); var active:=bool(p.get("active",false))
    var state := "OPERATING" if owned and active else ("OWNED / PAUSED" if owned else ("AVAILABLE" if unlocked else "LOCKED"))
    var capacity:Dictionary=_main().command_system.expansion_system.management_capacity()
    detail_label.text="%s  •  %s\n%s / %s  •  Condition %d%%  •  Level %d\nValue  $%d   •   Base income  $%d/day\nAcquire  $%d   •   Unlock reputation %d\nManagement  %d/%d   •   Population %d\n%s" % [str(p.get("name","Asset")),state,str(p.get("type","Asset")),str(p.get("industry","General")),int(p.get("condition",0)),int(p.get("level",1)),int(p.get("value",0)),int(p.get("income",0)),int(p.get("cost",0)),int(p.get("unlock_rep",0)),int(capacity.get("used",0)),int(capacity.get("capacity",0)),int(e.population),("Ready to acquire." if unlocked and not owned else ("Asset is contributing to the empire." if active else "Upgrade or activate from the operating surface."))]
    buy_button.disabled=owned or not unlocked or not bool(capacity.get("ok",false))
    upgrade_button.disabled=not owned

func _buy() -> void:
    var main=_main(); if main!=null and main.has_method("select_expansion"): main.select_expansion(selected_index)
    if main!=null and main.has_method("buy_expansion"): main.buy_expansion()
    last_signature=""; _refresh(true)

func _upgrade() -> void:
    var main=_main(); if main!=null and main.has_method("select_expansion"): main.select_expansion(selected_index)
    if main!=null and main.has_method("upgrade_expansion"): main.upgrade_expansion()
    last_signature=""; _refresh(true)

func _transport() -> void:
    var main=_main(); if main!=null and main.has_method("upgrade_transport"): main.upgrade_transport()
    last_signature=""; _refresh(true)

func _close() -> void:
    var manager=get_node_or_null("/root/RenewUIScreenManager")
    if manager!=null and manager.has_method("hide_all_screens"): manager.hide_all_screens()
    else: visible=false

func _layout() -> void:
    if panel==null:return
    var size:=get_viewport().get_visible_rect().size
    var narrow:=size.x<760.0
    var phone:=size.x<430.0
    var width:=maxf(304.0,size.x-16.0) if narrow else minf(560.0,size.x-36.0)
    var height:=maxf(430.0,size.y-90.0) if narrow else minf(700.0,size.y-120.0)
    panel.position=Vector2(8,70) if narrow else Vector2(maxf(18.0,size.x-width-18.0),90)
    panel.size=Vector2(width,height)
    title_label.position=Vector2(14,10); title_label.size=Vector2(width-130,30); title_label.add_theme_font_size_override("font_size",17 if phone else 20)
    status_label.position=Vector2(14,39); status_label.size=Vector2(width-28,20); status_label.add_theme_font_size_override("font_size",9 if phone else 10)
    close_button.position=Vector2(width-92,7); close_button.size=Vector2(82,46)
    summary_label.position=Vector2(14,62); summary_label.size=Vector2(width-28,40); summary_label.add_theme_font_size_override("font_size",9 if phone else 11)
    if phone:
        action_row.columns=1
        action_row.position=Vector2(12,height-164); action_row.size=Vector2(width-24,156)
    else:
        action_row.columns=3
        action_row.position=Vector2(12,height-54); action_row.size=Vector2(width-24,48)
    for b in [buy_button,upgrade_button,transport_button]:
        b.custom_minimum_size=Vector2(0,46)
        b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
        b.add_theme_font_size_override("font_size",9 if phone else 10)
    var detail_bottom:=height-(174.0 if phone else 116.0)
    detail_panel.position=Vector2(12,detail_bottom); detail_panel.size=Vector2(width-24,112 if not phone else 148)
    detail_label.position=Vector2(10,8); detail_label.size=Vector2(width-44,detail_panel.size.y-16); detail_label.add_theme_font_size_override("font_size",10 if phone else 11)
    list_scroll.position=Vector2(12,108); list_scroll.size=Vector2(width-24,maxf(90.0,detail_panel.position.y-116.0)); list.custom_minimum_size.x=width-24
