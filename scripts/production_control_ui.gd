extends CanvasLayer
## Dedicated production command center. Presentation only: all simulation
## decisions are delegated to RenewProductionSystem / production facade.

var root: Control
var scrim: ColorRect
var panel: PanelContainer
var scroll: ScrollContainer
var content: VBoxContainer
var status_label: Label
var inventory_label: Label
var machine_label: Label
var recipe_label: Label
var result_label: Label
var recipe_select: OptionButton
var cycles_spin: SpinBox
var run_button: Button
var maintenance_button: Button
var automation_minus: Button
var automation_plus: Button
var selected_recipe := ""
var selected_machine := ""
var production = null

func _ready() -> void:
    layer = 72
    _build_ui()
    _layout()
    _refresh()
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)
    visible = false

func open_screen() -> void:
    visible = true
    _refresh()
    _layout()

func close_screen() -> void:
    visible = false

func _process(_delta: float) -> void:
    if visible: _refresh_live()

func _production():
    var node := get_tree().root.get_node_or_null("Renew/ProductionSystem")
    if node != null: return node
    node = get_tree().root.get_node_or_null("Renew/Systems/ProductionSystem")
    if node != null: return node
    var facade := get_tree().root.get_node_or_null("Renew/Production")
    return facade

func _build_ui() -> void:
    root = Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(root)
    scrim = ColorRect.new(); scrim.color = Color(0.02,0.07,0.08,0.82); scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); scrim.mouse_filter = Control.MOUSE_FILTER_STOP; root.add_child(scrim)
    panel = PanelContainer.new(); panel.add_theme_stylebox_override("panel", _box(Color("0b1f25"),Color("42666b"),14,1)); root.add_child(panel)
    scroll = ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.add_theme_constant_override("scroll_bar_width",8); panel.add_child(scroll)
    content = VBoxContainer.new(); content.add_theme_constant_override("separation",10); scroll.add_child(content)

    var header := HBoxContainer.new(); header.add_theme_constant_override("separation",10); content.add_child(header)
    var title := _label("PRODUCTION CONTROL CENTER",20,Color("edf6f3")); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; header.add_child(title)
    var close := _button("CLOSE",46); close.pressed.connect(func(): get_node_or_null("/root/RenewUIScreenManager").hide_all_screens() if get_node_or_null("/root/RenewUIScreenManager") != null else close_screen()); header.add_child(close)

    status_label = _label("",13,Color("a9c5c6")); content.add_child(status_label)
    content.add_child(_section("PRODUCTION LINE"))
    recipe_select = OptionButton.new(); recipe_select.custom_minimum_size=Vector2(0,46); recipe_select.item_selected.connect(_recipe_changed); content.add_child(recipe_select)
    recipe_label = _label("",12,Color("dce9e7")); recipe_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; content.add_child(recipe_label)
    var controls:=HBoxContainer.new(); controls.add_theme_constant_override("separation",8); content.add_child(controls)
    var cycle_text:=_label("CYCLES",11,Color("8faeb0")); controls.add_child(cycle_text)
    cycles_spin=SpinBox.new(); cycles_spin.min_value=1; cycles_spin.max_value=99; cycles_spin.value=1; cycles_spin.custom_minimum_size=Vector2(110,46); controls.add_child(cycles_spin)
    run_button=_button("RUN PRODUCTION",46); run_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; run_button.pressed.connect(_run); controls.add_child(run_button)

    content.add_child(_section("INVENTORY")); inventory_label=_label("",12,Color("dce9e7")); inventory_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; content.add_child(inventory_label)
    content.add_child(_section("EQUIPMENT")); machine_label=_label("",12,Color("dce9e7")); machine_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; content.add_child(machine_label)
    var machine_actions:=HBoxContainer.new(); machine_actions.add_theme_constant_override("separation",8); content.add_child(machine_actions)
    maintenance_button=_button("MAINTAIN",46); maintenance_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; maintenance_button.pressed.connect(_maintain); machine_actions.add_child(maintenance_button)
    automation_minus=_button("−",46); automation_minus.custom_minimum_size=Vector2(52,46); automation_minus.pressed.connect(func(): _automation(-1)); machine_actions.add_child(automation_minus)
    automation_plus=_button("+",46); automation_plus.custom_minimum_size=Vector2(52,46); automation_plus.pressed.connect(func(): _automation(1)); machine_actions.add_child(automation_plus)
    content.add_child(_section("LATEST RUN")); result_label=_label("No production run recorded.",12,Color("b8d1cf")); result_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; content.add_child(result_label)

func _refresh() -> void:
    production = _production()
    if production == null: status_label.text="PRODUCTION SYSTEM OFFLINE"; run_button.disabled=true; return
    run_button.disabled=false; _populate_recipes(); _refresh_live()

func _populate_recipes() -> void:
    recipe_select.clear()
    var ids:Array=[]
    if production.has_method("recipe_ids"): ids=production.recipe_ids()
    elif production.has_method("product_ids"): ids=production.product_ids()
    for id in ids:
        var recipe:Dictionary=production.get_recipe(id) if production.has_method("get_recipe") else production.get_product_config(id)
        var label:=String(recipe.get("name",id)).replace("_"," ").capitalize()
        recipe_select.add_item(label); recipe_select.set_item_metadata(recipe_select.item_count-1,String(id))
    if recipe_select.item_count>0:
        recipe_select.select(0); selected_recipe=String(recipe_select.get_item_metadata(0)); _update_recipe_detail()

func _recipe_changed(index:int)->void:
    selected_recipe=String(recipe_select.get_item_metadata(index)); _update_recipe_detail()

func _update_recipe_detail()->void:
    if production==null or selected_recipe.is_empty(): return
    var r:Dictionary=production.get_recipe(selected_recipe) if production.has_method("get_recipe") else production.get_product_config(selected_recipe)
    var inputs:Dictionary=r.get("inputs",{}); var outputs:Dictionary=r.get("outputs",{})
    recipe_label.text="%s  •  %s\nINPUTS  %s\nOUTPUTS  %s\nMachine: %s  •  Technology: %s" % [String(r.get("stage","" )).to_upper(),String(selected_recipe).replace("_"," ").capitalize(),_dict_text(inputs),_dict_text(outputs),String(r.get("machine","—")),String(r.get("technology","—"))]
    selected_machine=String(r.get("machine","")); _refresh_live()

func _refresh_live()->void:
    if production==null: return
    var q=int(production.quality); var goods=int(production.finished_goods)
    status_label.text="LINE STATUS  •  QUALITY %d%%  •  FINISHED GOODS %d" % [q,goods]
    var inv:Dictionary=production.inventory
    var items:=[]
    for key in inv.keys():
        var amount=int(inv[key]); if amount>0: items.append("%s %d" % [String(key).replace("_"," ").to_upper(),amount])
    inventory_label.text="  •  ".join(items) if not items.is_empty() else "Inventory is currently empty."
    if production.machines.has(selected_machine):
        var m:Dictionary=production.machines[selected_machine]
        var owned:=bool(m.get("owned",false)); var condition:=float(m.get("condition",0.0)); var auto:=int(m.get("automation",0)); var cap:=int(m.get("capacity",1)); var util:=float(production.utilization.get(selected_machine,0.0))
        machine_label.text="%s  •  %s\nCondition %d%%  •  Capacity %d  •  Automation %d/5  •  Utilization %d%%\nMaintenance due: %d cycles" % [selected_machine.to_upper(),"OWNED" if owned else "LOCKED",int(condition),cap,auto,int(util),int(m.get("maintenance_due",0))]
        maintenance_button.disabled=not owned
        automation_minus.disabled=not owned or auto<=0; automation_plus.disabled=not owned or auto>=5
    if not production.last_run.is_empty(): result_label.text=_dict_text(production.last_run)

func _run()->void:
    if production==null: return
    var result:Dictionary={}
    if production.has_method("run_recipe"): result=production.run_recipe(selected_recipe,int(cycles_spin.value))
    elif production.has_method("produce"): result=production.produce(null,int(cycles_spin.value),selected_recipe)
    result_label.text=_dict_text(result)
    _refresh_live()

func _maintain()->void:
    if production==null or selected_machine.is_empty(): return
    var finance=get_tree().root.get_node_or_null("Renew/FinanceSystem")
    if production.has_method("maintain_machine"): result_label.text=_dict_text(production.maintain_machine(selected_machine,finance))
    _refresh_live()

func _automation(delta:int)->void:
    if production==null or selected_machine.is_empty() or not production.machines.has(selected_machine): return
    var level=int(production.machines[selected_machine].get("automation",0))+delta
    if production.has_method("set_automation") and production.set_automation(selected_machine,level): result_label.text="Automation set to level %d." % level
    _refresh_live()

func _dict_text(data:Dictionary)->String:
    var parts:=[]
    for key in data.keys(): parts.append("%s=%s" % [String(key).replace("_"," "),str(data[key])])
    return ", ".join(parts) if not parts.is_empty() else "—"

func _layout()->void:
    if root==null:return
    var size:=get_viewport().get_visible_rect().size; var narrow:=size.x<700.0
    var w:=min(size.x-20.0,920.0); var h:=min(size.y-24.0,760.0)
    panel.position=Vector2((size.x-w)/2.0,(size.y-h)/2.0); panel.size=Vector2(w,h)
    scroll.size=Vector2(w,h); content.custom_minimum_size.x=max(0.0,w-26.0)
    if narrow:
        panel.position=Vector2(8,8); panel.size=Vector2(size.x-16,size.y-16); scroll.size=panel.size; content.custom_minimum_size.x=max(0.0,size.x-34.0)

func _section(text:String)->Label: return _label(text,11,Color("d8b76d"))
func _label(text:String,size:int,color:Color)->Label:
    var l:=Label.new(); l.text=text; l.add_theme_font_size_override("font_size",size); l.add_theme_color_override("font_color",color); return l
func _button(text:String,height:int)->Button:
    var b:=Button.new(); b.text=text; b.custom_minimum_size=Vector2(0,height); b.focus_mode=Control.FOCUS_NONE; b.add_theme_font_size_override("font_size",11); b.add_theme_stylebox_override("normal",_box(Color("102a31"),Color("31565d"),9,1)); b.add_theme_stylebox_override("hover",_box(Color("18363a"),Color("d8b76d"),9,1)); b.add_theme_stylebox_override("pressed",_box(Color("18363a"),Color("d8b76d"),9,1)); return b
func _box(bg:Color,border:Color,radius:int,width:int)->StyleBoxFlat:
    var s:=StyleBoxFlat.new(); s.bg_color=bg; s.border_color=border; s.set_border_width_all(width); s.set_corner_radius_all(radius); s.content_margin_left=12; s.content_margin_right=12; s.content_margin_top=8; s.content_margin_bottom=8; return s
