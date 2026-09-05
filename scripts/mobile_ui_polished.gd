extends "res://scripts/mobile_ui.gd"
const BG := Color("071319")
const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56b")
var top_bar: ColorRect
var sidebar: Panel
var content_scroll: ScrollContainer
var content: VBoxContainer
var title_label: Label
var status_panel: Panel
var objective_panel: Panel
var objective_label: Label
var action_panel: Panel
var action_title: Label
var network_panel: Panel
var network_summary: Label
var network_cards: HBoxContainer
var bottom_bar: Panel
var button_theme: Theme
var bottom_buttons: Array[Button] = []
var side_buttons: Array[Button] = []
var refresh_clock := 0.0

func _build_ui() -> void:
    root = Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
    var bg := ColorRect.new(); bg.color = BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(bg)
    top_bar = ColorRect.new(); top_bar.color = SURFACE; root.add_child(top_bar)
    var brand := Label.new(); brand.name = "Brand"; brand.text = "RENEW"; brand.add_theme_font_size_override("font_size", 22); brand.add_theme_color_override("font_color", TEXT); root.add_child(brand)
    var strap := Label.new(); strap.text = "RESTORE  •  OPERATE  •  COOPERATE  •  EXPAND"; strap.add_theme_font_size_override("font_size", 9); strap.add_theme_color_override("font_color", MUTED); root.add_child(strap)
    status_panel = Panel.new(); status_panel.add_theme_stylebox_override("panel", _style(SURFACE_2, BORDER, 12)); root.add_child(status_panel)
    status_label = Label.new(); status_label.add_theme_font_size_override("font_size", 11); status_label.add_theme_color_override("font_color", TEXT); status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; status_panel.add_child(status_label)
    tabs = HBoxContainer.new(); tabs.add_theme_constant_override("separation",6); root.add_child(tabs)
    for i in range(4):
        var tab := Button.new(); tab.text=["RESTORE","BUSINESS","EMPIRE","WORLD"][i]; tab.custom_minimum_size=Vector2(92,44); tab.focus_mode=Control.FOCUS_NONE; tab.pressed.connect(_set_tab.bind(i)); tabs.add_child(tab)
    sidebar = Panel.new(); sidebar.add_theme_stylebox_override("panel", _style(SURFACE, BORDER, 0)); root.add_child(sidebar)
    var side_title := Label.new(); side_title.text = "CORPORATE CONTROL"; side_title.position = Vector2(16, 16); side_title.add_theme_font_size_override("font_size", 10); side_title.add_theme_color_override("font_color", MUTED); sidebar.add_child(side_title)
    var side_box := VBoxContainer.new(); side_box.position = Vector2(10, 46); side_box.add_theme_constant_override("separation", 6); sidebar.add_child(side_box)
    for item in [["HOME",0],["ASSETS",0],["OPERATE",1],["NETWORK",2],["WORLD",3]]:
        var b := Button.new(); b.text = String(item[0]); b.custom_minimum_size = Vector2(180,44); b.focus_mode = Control.FOCUS_NONE; b.pressed.connect(_select_nav.bind(int(item[1]))); side_box.add_child(b); side_buttons.append(b)
    title_label = Label.new(); title_label.add_theme_font_size_override("font_size", 24); title_label.add_theme_color_override("font_color", TEXT); root.add_child(title_label)
    content_scroll = ScrollContainer.new(); content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; content_scroll.mouse_filter = Control.MOUSE_FILTER_STOP; root.add_child(content_scroll)
    content = VBoxContainer.new(); content.add_theme_constant_override("separation", 12); content_scroll.add_child(content)
    objective_panel = Panel.new(); objective_panel.add_theme_stylebox_override("panel", _style(SURFACE_2,BORDER,12)); objective_panel.custom_minimum_size.y = 82; content.add_child(objective_panel)
    objective_label = Label.new(); objective_label.position = Vector2(16,10); objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; objective_label.add_theme_font_size_override("font_size",13); objective_label.add_theme_color_override("font_color",TEXT); objective_panel.add_child(objective_label)
    feedback_panel = objective_panel; goal_label = objective_label
    action_panel = Panel.new(); action_panel.add_theme_stylebox_override("panel", _style(SURFACE,BORDER,12)); content.add_child(action_panel)
    action_title = Label.new(); action_title.position = Vector2(16,10); action_title.add_theme_font_size_override("font_size",11); action_title.add_theme_color_override("font_color",MUTED); action_panel.add_child(action_title)
    action_scroll = ScrollContainer.new(); action_scroll.position = Vector2(12,36); action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; action_scroll.mouse_filter = Control.MOUSE_FILTER_STOP; action_panel.add_child(action_scroll)
    actions = GridContainer.new(); actions.add_theme_constant_override("h_separation",8); actions.add_theme_constant_override("v_separation",8); action_scroll.add_child(actions)
    network_panel = Panel.new(); network_panel.add_theme_stylebox_override("panel", _style(Color("0c2229"),Color("315b60"),12)); content.add_child(network_panel)
    var nt := Label.new(); nt.text = "CORPORATE NETWORK"; nt.position = Vector2(16,10); nt.add_theme_font_size_override("font_size",11); nt.add_theme_color_override("font_color",TEXT); network_panel.add_child(nt)
    network_summary = Label.new(); network_summary.position = Vector2(16,32); network_summary.add_theme_font_size_override("font_size",9); network_summary.add_theme_color_override("font_color",MUTED); network_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; network_panel.add_child(network_summary)
    network_cards = HBoxContainer.new(); network_cards.position = Vector2(16,66); network_cards.add_theme_constant_override("separation",8); network_panel.add_child(network_cards)
    bottom_bar = Panel.new(); bottom_bar.add_theme_stylebox_override("panel", _style(SURFACE,BORDER,0)); root.add_child(bottom_bar)
    var bottom := HBoxContainer.new(); bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); bottom.add_theme_constant_override("separation",4); bottom_bar.add_child(bottom)
    for i in range(5):
        var b := Button.new(); b.text = ["HOME","ASSETS","OPERATE","NETWORK","WORLD"][i]; b.focus_mode = Control.FOCUS_NONE; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.pressed.connect(_select_bottom.bind(i)); bottom.add_child(b); bottom_buttons.append(b)
    button_theme = _make_theme(); _layout_responsive(); _refresh(); _refresh_network(); _apply_nav_state()
func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
    var s := StyleBoxFlat.new(); s.bg_color=bg; s.border_color=border; s.set_border_width_all(1); s.set_corner_radius_all(radius); return s
func _make_theme() -> Theme:
    var t:=Theme.new(); t.default_font_size=12; var n:=_style(Color("132b33"),Color("31535b"),8); var h:=n.duplicate(); h.bg_color=Color("1d4148"); h.border_color=ACCENT; var p:=h.duplicate(); p.bg_color=Color("2a5658"); t.set_stylebox("normal","Button",n); t.set_stylebox("hover","Button",h); t.set_stylebox("pressed","Button",p); t.set_color("font_color","Button",TEXT); t.set_color("font_hover_color","Button",Color.WHITE); return t
func _select_nav(tab: int) -> void: _set_tab(tab); _apply_nav_state()
func _select_bottom(index: int) -> void: _select_nav(index if index == 0 else (0 if index == 1 else index-1))
func _apply_nav_state() -> void:
    var selected := 0 if active_tab == 0 else (2 if active_tab == 1 else (3 if active_tab == 2 else 4))
    for i in range(side_buttons.size()): _nav_style(side_buttons[i],i==selected)
    for i in range(bottom_buttons.size()): _nav_style(bottom_buttons[i],i==selected)
func _nav_style(b: Button, active: bool) -> void:
    b.theme=button_theme; b.add_theme_stylebox_override("normal",_style(Color("23494c") if active else Color("10252c"),ACCENT if active else BORDER,8)); b.add_theme_color_override("font_color",TEXT if active else MUTED)
func _refresh() -> void:
    if parent == null or actions == null: return
    _clear_actions(); action_title.text = ["ASSET & RESTORATION COMMAND","OPERATIONS COMMAND","CORPORATE NETWORK","WORLD COMMAND"][active_tab]
    match active_tab:
        0:
            _button("INSPECT PROPERTY",parent.inspect_property); _button("ACQUIRE PROPERTY",parent.acquire_property); _button("RESTORE PROPERTY",parent.restore_property); _button("OPEN BUSINESS",parent.open_business); _screen("HEADQUARTERS","HeadquartersPanel"); _screen("RESTORATION","CollectionPanel")
        1:
            _button("BUY INPUTS",parent.buy_inputs); _button("PRODUCE GOODS",parent.produce_goods); _button("HIRE EMPLOYEE",parent.hire_employee); _button("UPGRADE BUSINESS",parent.upgrade_business); _button("MARKETING",parent.marketing_campaign); _button("CHANGE PRICE",parent.change_price); _screen("EMPLOYEES","EmployeePanel"); _screen("CONTRACTS","ContractPanel"); _screen("CUSTOMERS","CustomerSegmentsUI")
        2:
            _button("NEXT RIVAL",_next_rival); _button("MAKE ALLIANCE OFFER",parent.make_alliance_offer); _button("IMPROVE RELATION",parent.improve_alliance); _button("SUPPLY DEAL",parent.propose_supply_deal); _button("CUSTOMER PARTNERSHIP",parent.propose_customer_partnership); _button("ACQUIRE TARGET",parent.negotiate_selected_acquisition); _button("TAKE LOAN",parent.take_loan); _screen("ALLIANCE COUNCIL","AlliancePanel"); _screen("DIPLOMACY","RenewDiplomacyUI"); _screen("TECHNOLOGY","TechnologyPanel")
        3:
            _screen("MARKET","CustomerSegmentsUI"); _screen("INFRASTRUCTURE","HeadquartersPanel"); _screen("TECHNOLOGY","TechnologyPanel"); _screen("NEWS","NewsPanel"); _screen("HISTORY","HistoryPanel"); _screen("LIVE OPS","LiveOpsPanel"); _button("SAVE GAME",parent.save_game); _button("LOAD GAME",parent.load_game)
    _button("END DAY",parent.advance_day); _update_text(); call_deferred("_layout_responsive")
func _button(text: String, callback: Callable) -> void:
    if not callback.is_valid(): return
    var b:=Button.new(); b.text=text; b.theme=button_theme; b.focus_mode=Control.FOCUS_NONE; b.mouse_filter=Control.MOUSE_FILTER_STOP; b.pressed.connect(_run_action.bind(text,callback)); actions.add_child(b)
func _screen(text: String, screen_name: String) -> void: _button(text,Callable(self,"_open_screen").bind(screen_name))
func _open_screen(screen_name:String)->void:
    var manager:=get_node_or_null("/root/RenewUIScreenManager")
    if manager!=null and manager.has_method("show_screen"): manager.show_screen(screen_name)
func _run_action(label:String,callback:Callable)->void:
    if parent==null or not callback.is_valid(): return
    var before_cash:=int(parent.cash); var before_rep:=int(parent.reputation); var before_day:=int(parent.day); var before_message:=String(parent.message); var result=callback.call(); var message:=""
    if result is Dictionary and result.has("message"): message=String(result["message"])
    if message.is_empty() and String(parent.message)!=before_message: message=String(parent.message)
    if message.is_empty(): message=label+" completed."
    var changes:Array[String]=[]; var dc:=int(parent.cash)-before_cash; var dr:=int(parent.reputation)-before_rep
    if dc!=0: changes.append("Cash "+("+" if dc>0 else "-")+_money(abs(dc)))
    if dr!=0: changes.append("REP "+("+" if dr>0 else "")+str(dr))
    if int(parent.day)!=before_day: changes.append("Day "+str(int(parent.day)))
    if not changes.is_empty(): message += "\n"+"  •  ".join(changes)
    objective_label.text="LATEST DECISION\n"+message; _refresh()
func _update_text()->void:
    if parent==null:return
    var objective:="Inspect → acquire → restore your first property."
    if bool(parent.owned) and bool(parent.inspected) and String(parent.stage)!="Operational": objective="Restore the property through its next phase."
    elif String(parent.stage)=="Operational" and not bool(parent.business_open): objective="Open the business and establish cash flow."
    elif int(parent.total_profit)>0: objective="Reinvest profits to expand your corporate network."
    objective_label.text="NEXT OBJECTIVE\n"+objective; title_label.text=["ASSET COMMAND","OPERATIONS","CORPORATE NETWORK","WORLD COMMAND"][active_tab]; status_label.text="$"+_money(int(parent.cash))+"  •  REP "+str(int(parent.reputation))+"  •  DAY "+str(int(parent.day))
func _refresh_network()->void:
    if network_cards==null:return
    for c in network_cards.get_children():c.queue_free()
    network_summary.text="Live relationships from the authoritative competitor state."
    if parent==null or parent.rivals==null:return
    for i in range(min(3,parent.rivals.rivals.size())):
        var r:Dictionary=parent.rivals.rivals[i]; var p:=Panel.new(); p.custom_minimum_size=Vector2(200,62); p.add_theme_stylebox_override("panel",_style(Color("122c33"),BORDER,8)); var n:=Label.new(); n.text=str(r.get("name","Corporate Partner")); n.position=Vector2(9,7); n.add_theme_color_override("font_color",TEXT); p.add_child(n); var rel:=Label.new(); rel.text="Relationship  "+str(int(r.get("relationship",0))); rel.position=Vector2(9,31); rel.add_theme_font_size_override("font_size",9); rel.add_theme_color_override("font_color",MUTED); p.add_child(rel); network_cards.add_child(p)
func _clear_actions()->void:
    for c in actions.get_children():c.queue_free()
func _next_rival()->void:
    if parent.rivals!=null and not parent.rivals.rivals.is_empty(): parent.select_rival((int(parent.selected_rival)+1)%parent.rivals.rivals.size())
func _layout_responsive()->void:
    if root==null:return
    var s:=root.size
    if s.x < 1.0 or s.y < 1.0: s=get_viewport().get_visible_rect().size
    var w:=maxf(320,s.x); var h:=maxf(480,s.y); var mobile:=w<760
    top_bar.size=Vector2(w,72 if mobile else 64); sidebar.visible=not mobile; bottom_bar.visible=mobile; tabs.visible=not mobile
    tabs.position=Vector2(260,10) if not mobile else Vector2(8,76); tabs.size=Vector2(minf(500,w-16),44)
    for tab in tabs.get_children(): tab.custom_minimum_size=Vector2(maxf(70,(tabs.size.x-18)/4),44)
    var brand:=root.get_node_or_null("Brand") as Label; if brand: brand.position=Vector2(16,7); brand.size=Vector2(150,30)
    var strap:=root.get_child(3) as Label; if strap: strap.position=Vector2(16,38); strap.size=Vector2(minf(330,w-32),18)
    status_panel.position=Vector2(maxf(150,w-230),10); status_panel.size=Vector2(minf(220,w-166),38); status_label.position=Vector2(8,3); status_label.size=Vector2(status_panel.size.x-16,30); status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    if mobile:
        title_label.position=Vector2(12,82); title_label.size=Vector2(w-24,30); content_scroll.position=Vector2(10,116); content_scroll.size=Vector2(w-20,maxf(260,h-184)); content.custom_minimum_size.x=w-20; objective_panel.custom_minimum_size.y=76; action_panel.custom_minimum_size.y=maxf(190,minf(330,h*.36)); action_scroll.size=Vector2(w-44,action_panel.custom_minimum_size.y-48); actions.columns=2; network_panel.custom_minimum_size.y=138
        for c in actions.get_children(): c.custom_minimum_size=Vector2(maxf(120,(w-40)/2),46)
        bottom_bar.position=Vector2(0,h-58); bottom_bar.size=Vector2(w,58)
    else:
        sidebar.position=Vector2(0,64); sidebar.size=Vector2(202,h-64); title_label.position=Vector2(224,78); title_label.size=Vector2(w-246,34); content_scroll.position=Vector2(224,122); content_scroll.size=Vector2(w-246,h-184); content.custom_minimum_size.x=w-246; objective_panel.custom_minimum_size.y=76; action_panel.custom_minimum_size.y=230; action_scroll.size=Vector2(w-270,190); actions.columns=3; network_panel.custom_minimum_size.y=136
        for c in actions.get_children(): c.custom_minimum_size=Vector2(maxf(160,(w-300)/3),46)
    _apply_nav_state()
func _set_tab(index:int)->void:
    active_tab=clampi(index,0,3); if action_scroll: action_scroll.scroll_vertical=0; _refresh(); _apply_nav_state(); _refresh_network()
func _process(delta:float)->void:
    if parent==null:return
    status_label.text="$"+_money(int(parent.cash))+"  •  REP "+str(int(parent.reputation))+"  •  DAY "+str(int(parent.day))
    refresh_clock+=delta
    if refresh_clock>=1.0: refresh_clock=0.0; _refresh_network()
