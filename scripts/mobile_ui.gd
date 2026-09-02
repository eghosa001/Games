extends CanvasLayer

# Mobile-first control surface. Keyboard controls remain available for desktop.
var parent: Node
var visible_mobile := true
var active_tab := 0
var root: Control
var tabs: HBoxContainer
var actions: GridContainer
var status_label: Label

var tab_names := ["RESTORE", "BUSINESS", "EMPIRE", "WORLD"]

func _ready() -> void:
    parent = get_parent()
    _build_ui()
    _refresh()

func _process(_delta: float) -> void:
    if parent == null:
        return
    _refresh()

func _build_ui() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(root)

    var top := ColorRect.new()
    top.color = Color("101820")
    top.set_anchors_preset(Control.PRESET_TOP_WIDE)
    top.position.y = 8
    top.size.y = 54
    root.add_child(top)

    tabs = HBoxContainer.new()
    tabs.position = Vector2(12, 12)
    tabs.size = Vector2(720, 46)
    tabs.add_theme_constant_override("separation", 8)
    root.add_child(tabs)
    for i in range(tab_names.size()):
        var button := Button.new()
        button.text = tab_names[i]
        button.custom_minimum_size = Vector2(150, 44)
        button.focus_mode = Control.FOCUS_NONE
        button.pressed.connect(_set_tab.bind(i))
        tabs.add_child(button)

    status_label = Label.new()
    status_label.position = Vector2(760, 17)
    status_label.size = Vector2(500, 44)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    status_label.add_theme_font_size_override("font_size", 15)
    root.add_child(status_label)

    var bottom := ColorRect.new()
    bottom.color = Color("101820")
    bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    bottom.position.y = -138
    bottom.size.y = 138
    root.add_child(bottom)

    actions = GridContainer.new()
    actions.columns = 5
    actions.position = Vector2(18, -126)
    actions.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    actions.size = Vector2(1240, 112)
    actions.add_theme_constant_override("h_separation", 10)
    actions.add_theme_constant_override("v_separation", 8)
    root.add_child(actions)

func _set_tab(index: int) -> void:
    active_tab = index
    _refresh()

func _clear_actions() -> void:
    for child in actions.get_children():
        child.queue_free()

func _button(text: String, callback: Callable) -> void:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(225, 48)
    b.focus_mode = Control.FOCUS_NONE
    b.pressed.connect(callback)
    actions.add_child(b)

func _refresh() -> void:
    if parent == null or actions == null:
        return
    _clear_actions()
    status_label.text = "$%s   |   REP %d   |   DAY %d" % [_money(int(parent.cash)), int(parent.reputation), int(parent.day)]
    match active_tab:
        0:
            _button("INSPECT", parent.inspect_property)
            _button("ACQUIRE", parent.acquire_property)
            _button("RESTORE", parent.restore_property)
            _button("OPEN BUSINESS", parent.open_business)
            _button("END DAY", parent.advance_day)
        1:
            _button("BUY INPUTS", parent.buy_inputs)
            _button("PRODUCE", parent.produce_goods)
            _button("HIRE", parent.hire_employee)
            _button("UPGRADE", parent.upgrade_business)
            _button("MARKETING", parent.marketing_campaign)
            _button("PRICE", parent.change_price)
            _button("SUPPLIER", parent.cycle_supplier)
            _button("CONTRACT", parent.sign_contract)
            _button("END DAY", parent.advance_day)
        2:
            _button("EXPANSION", parent.buy_expansion)
            _button("UPGRADE BUSINESS", parent.upgrade_expansion)
            _button("ALLIANCE", parent.make_alliance_offer)
            _button("SUPPLY DEAL", parent.propose_supply_deal)
            _button("CUSTOMER DEAL", parent.propose_customer_partnership)
            _button("ACQUIRE ASSET", parent.negotiate_selected_acquisition)
            var supply_controller = get_node_or_null("../SupplyChainController")
            if supply_controller != null:
                _button("SUPPLIER CONTRACT", supply_controller.negotiate_supplier_contract)
                _button("SECURE RESOURCE", supply_controller.secure_resource_rights)
            _button("LOAN", parent.take_loan)
            _button("REPAY LOAN", parent.repay_loan)
            _button("END DAY", parent.advance_day)
        3:
            var region_controller = get_node_or_null("../RegionController")
            if region_controller != null:
                _button("NEXT REGION", region_controller.select_region.bind(region_controller.regions.selected + 1))
                _button("PREVIOUS REGION", region_controller.select_region.bind(region_controller.regions.selected - 1))
                _button("ESTABLISH", region_controller.establish_region)
                _button("INFRASTRUCTURE", region_controller.upgrade_infrastructure)
                _button("DISPATCH GOODS", region_controller.dispatch_goods)
            _button("DISTRICT", parent.select_district.bind((int(parent.selected_district) + 1) % parent.districts.districts.size()))
            _button("END DAY", parent.advance_day)

func _money(value: int) -> String:
    return "%,d" % value
