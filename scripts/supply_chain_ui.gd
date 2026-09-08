extends CanvasLayer
## Supply Chain Command Center. UI delegates all transactions to the canonical
## SupplyChainController / SupplyChain model.

var root: Control
var panel: PanelContainer
var scroll: ScrollContainer
var content: VBoxContainer
var status: Label
var warehouse_label: Label
var route_label: Label
var operation_label: Label
var resource_select: OptionButton
var amount_spin: SpinBox
var procure_button: Button
var process_button: Button
var transport_spin: SpinBox
var supply = null

func _ready() -> void:
    layer = 71
    _build()
    _layout()
    visible = false
    get_viewport().size_changed.connect(_layout)

func open_screen() -> void:
    visible = true
    _resolve()
    _refresh()
    _layout()

func close_screen() -> void:
    visible = false

func _process(_delta: float) -> void:
    if visible: _refresh()

func _resolve() -> void:
    var controller := get_tree().root.get_node_or_null("Renew/World/SupplyChainController")
    supply = controller.supply if controller != null and controller.get("supply") != null else controller

func _build() -> void:
    root=Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter=Control.MOUSE_FILTER_STOP; add_child(root)
    var scrim:=ColorRect.new(); scrim.color=Color(0.02,0.07,0.08,0.84); scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(scrim)
    panel=PanelContainer.new(); panel.add_theme_stylebox_override("panel",_box(Color("0b1f25"),Color("42666b"),14)); root.add_child(panel)
    scroll=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
    content=VBoxContainer.new(); content.add_theme_constant_override("separation",10); scroll.add_child(content)
    var header:=HBoxContainer.new(); content.add_child(header)
    var title:=_label("SUPPLY CHAIN COMMAND CENTER",19,Color("edf6f3")); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; header.add_child(title)
    var close:=_button("CLOSE",46); close.pressed.connect(_close); header.add_child(close)
    status=_label("",12,Color("a9c5c6")); content.add_child(status)
    content.add_child(_section("WAREHOUSE INVENTORY")); warehouse_label=_label("",12,Color("dce9e7")); warehouse_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; content.add_child(warehouse_label)
    content.add_child(_section("PROCUREMENT")); resource_select=OptionButton.new(); resource_select.custom_minimum_size=Vector2(0,46); content.add_child(resource_select)
    var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",8); content.add_child(row)
    amount_spin=SpinBox.new(); amount_spin.min_value=1; amount_spin.max_value=500; amount_spin.value=10; amount_spin.custom_minimum_size=Vector2(105,46); row.add_child(amount_spin)
    transport_spin=SpinBox.new(); transport_spin.min_value=1; transport_spin.max_value=10; transport_spin.value=1; transport_spin.custom_minimum_size=Vector2(105,46); row.add_child(transport_spin)
    procure_button=_button("PROCURE",46); procure_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; procure_button.pressed.connect(_procure); row.add_child(procure_button)
    content.add_child(_section("PROCESSING")); process_button=_button("PROCESS IRON → METAL",46); process_button.pressed.connect(_process_metal); content.add_child(process_button)
    content.add_child(_section("LOGISTICS STATUS")); route_label=_label("",12,Color("dce9e7")); route_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; content.add_child(route_label)
    content.add_child(_section("LATEST MOVEMENT")); operation_label=_label("No movement recorded.",12,Color("b8d1cf")); operation_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; content.add_child(operation_label)

func _refresh() -> void:
    if supply==null: _resolve()
    if supply==null: status.text="SUPPLY CHAIN OFFLINE"; procure_button.disabled=true; process_button.disabled=true; return
    procure_button.disabled=false; process_button.disabled=false
    var warehouse:Dictionary=supply.warehouse_snapshot() if supply.has_method("warehouse_snapshot") else supply.warehouse
    var parts:=[]; var total:=0.0
    for key in warehouse.keys():
        var value:=float(warehouse[key]); total+=value
        if value>0.0: parts.append("%s %d" % [String(key).replace("_"," ").to_upper(),int(value)])
    var limit:=500.0
    if supply.has_method("_effective_warehouse_limit"): limit=float(supply._effective_warehouse_limit())
    status.text="NETWORK STATUS  •  WAREHOUSE %d / %d  •  FREIGHT SPEND %d" % [int(total),int(limit),int(supply.total_freight_cost)]
    warehouse_label.text="  •  ".join(parts) if not parts.is_empty() else "Warehouse is empty."
    route_label.text="TRANSPORT LEVEL %d  •  COMPETITOR PRESSURE %d/20\nFreight and delivery efficiency are affected by infrastructure, technology and world modifiers." % [int(transport_spin.value),int(supply.competitor_pressure)]
    if not supply.last_operation.is_empty(): operation_label.text=_dict_text(supply.last_operation)
    _populate_resources(warehouse)

func _populate_resources(_warehouse:Dictionary)->void:
    if resource_select.item_count>0:return
    var ids=["timber","iron","energy","food","electronics"]
    for id in ids: resource_select.add_item(id.replace("_"," ").capitalize()); resource_select.set_item_metadata(resource_select.item_count-1,id)

func _procure()->void:
    if supply==null:return
    var id:=String(resource_select.get_item_metadata(resource_select.selected))
    var amount:=float(amount_spin.value); var cash:=_cash(); var result:Dictionary=supply.procure(id,amount,cash,int(transport_spin.value)); operation_label.text=_dict_text(result); _refresh()

func _process_metal()->void:
    if supply==null:return
    var result:Dictionary=supply.process_iron_to_metal(int(amount_spin.value)); operation_label.text=_dict_text(result); _refresh()

func _cash()->int:
    var game=get_tree().root.get_node_or_null("Renew")
    return int(game.get("cash")) if game!=null else 0

func _close()->void:
    var manager=get_node_or_null("/root/RenewUIScreenManager")
    if manager!=null: manager.hide_all_screens()
    else: close_screen()

func _dict_text(data:Dictionary)->String:
    var parts:=[]
    for key in data.keys():parts.append("%s=%s"%[String(key).replace("_"," "),str(data[key])])
    return ", ".join(parts) if not parts.is_empty() else "—"
func _layout()->void:
    if panel==null:return
    var size:=get_viewport().get_visible_rect().size; var w:=min(size.x-20.0,860.0); var h:=min(size.y-24.0,720.0)
    panel.position=Vector2((size.x-w)/2.0,(size.y-h)/2.0); panel.size=Vector2(w,h)
    if size.x<700.0: panel.position=Vector2(8,8); panel.size=Vector2(size.x-16,size.y-16)
    scroll.size=panel.size; content.custom_minimum_size.x=max(0.0,panel.size.x-26.0)
func _section(text:String)->Label:return _label(text,11,Color("d8b76d"))
func _label(text:String,size:int,color:Color)->Label:
    var l:=Label.new(); l.text=text;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);return l
func _button(text:String,height:int)->Button:
    var b:=Button.new();b.text=text;b.custom_minimum_size=Vector2(0,height);b.focus_mode=Control.FOCUS_NONE;b.add_theme_font_size_override("font_size",11);b.add_theme_stylebox_override("normal",_box(Color("102a31"),Color("31565d"),9));b.add_theme_stylebox_override("hover",_box(Color("18363a"),Color("d8b76d"),9));b.add_theme_stylebox_override("pressed",_box(Color("18363a"),Color("d8b76d"),9));return b
func _box(bg:Color,border:Color,radius:int)->StyleBoxFlat:
    var s:=StyleBoxFlat.new();s.bg_color=bg;s.border_color=border;s.set_border_width_all(1);s.set_corner_radius_all(radius);s.content_margin_left=12;s.content_margin_right=12;s.content_margin_top=8;s.content_margin_bottom=8;return s
