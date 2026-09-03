extends CanvasLayer

var panel: Panel
var title_label: Label
var summary_label: Label
var contract_list: VBoxContainer
var detail_label: Label
var empty_label: Label
var selected_contract_id := ""

func _ready() -> void:
    layer = 57
    _build_ui()
    _refresh()

func _process(_delta: float) -> void:
    _refresh()

func _contracts():
    return get_node_or_null("/root/RenewContractSystem")

func _build_ui() -> void:
    panel = Panel.new()
    panel.name = "ContractsPanel"
    panel.position = Vector2(12, 12)
    panel.size = Vector2(430, 265)
    add_child(panel)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_bottom", 10)
    panel.add_child(margin)
    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 5)
    margin.add_child(root)
    title_label = Label.new()
    title_label.text = "CUSTOMER CONTRACTS"
    title_label.add_theme_font_size_override("font_size", 18)
    root.add_child(title_label)
    summary_label = Label.new()
    root.add_child(summary_label)
    contract_list = VBoxContainer.new()
    contract_list.add_theme_constant_override("separation", 4)
    root.add_child(contract_list)
    empty_label = Label.new()
    empty_label.text = "No active customer contracts."
    root.add_child(empty_label)
    detail_label = Label.new()
    detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail_label.custom_minimum_size = Vector2(0, 100)
    root.add_child(detail_label)

func _refresh() -> void:
    if panel == null: return
    _layout()
    for child in contract_list.get_children(): child.queue_free()
    var contracts = _contracts()
    var active: Array = []
    if contracts != null and contracts.has_method("list_active_contracts"):
        active = contracts.list_active_contracts()
    summary_label.text = "%d active contract%s" % [active.size(), "" if active.size() == 1 else "s"]
    empty_label.visible = active.is_empty()
    if active.is_empty():
        detail_label.text = "Sign a contract to turn customer demand into scheduled production and delivery."
        return
    if selected_contract_id.is_empty() or not _contains_contract(active, selected_contract_id):
        selected_contract_id = str(active[0].get("id", ""))
    for contract in active:
        var id := str(contract.get("id", ""))
        var customer := str(contract.get("customer_id", "Customer"))
        var product := str(contract.get("resource_product", "product")).replace("_", " ").capitalize()
        var delivered := int(contract.get("quantity_delivered", 0))
        var quantity := int(contract.get("quantity", 0))
        var missed := int(contract.get("missed_deliveries", 0))
        var button := Button.new()
        button.text = "%s  •  %s  •  %d/%d  •  missed %d" % [customer, product, delivered, quantity, missed]
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.custom_minimum_size = Vector2(0, 34)
        if id == selected_contract_id: button.text += "  ◀"
        button.pressed.connect(_select_contract.bind(id))
        contract_list.add_child(button)
    _show_detail(_find_contract(active, selected_contract_id))

func _contains_contract(contracts: Array, id: String) -> bool:
    return not _find_contract(contracts, id).is_empty()

func _find_contract(contracts: Array, id: String) -> Dictionary:
    for contract in contracts:
        if str(contract.get("id", "")) == id: return contract
    return {}

func _select_contract(id: String) -> void:
    selected_contract_id = id
    _refresh()

func _show_detail(contract: Dictionary) -> void:
    if contract.is_empty():
        detail_label.text = ""
        return
    var customer := str(contract.get("customer_id", "Customer"))
    var product := str(contract.get("resource_product", "product")).replace("_", " ").capitalize()
    var quantity := int(contract.get("quantity", 0))
    var delivered := int(contract.get("quantity_delivered", 0))
    var due := int(contract.get("quantity_due", 0))
    var price := int(contract.get("price", 0))
    var penalty := int(contract.get("penalty", 0))
    var penalties_paid := int(contract.get("penalties_paid", 0))
    var quality := int(contract.get("quality_requirement", 0))
    var days_elapsed := int(contract.get("days_elapsed", 0))
    var schedule: Dictionary = contract.get("delivery_schedule", {})
    var duration := max(1, int(schedule.get("duration_days", 1)))
    var days_left := max(0, duration - days_elapsed)
    var relationship := 50
    var contracts = _contracts()
    if contracts != null and contracts.has_method("get_customer_relationship"):
        relationship = int(contracts.get_customer_relationship(customer))
    var renewal := "Likely" if relationship >= 60 and delivered >= due and due > 0 else ("Possible" if relationship >= 50 else "Unlikely")
    detail_label.text = "%s  |  %s\nDelivered: %d / %d   •   Due: %d\nDeadline: %d day%s left   •   Price: $%d/unit\nPenalty: $%d/unit   •   Paid: $%d   •   Quality ≥ %d\nCustomer relationship: %d/100   •   Renewal: %s" % [customer, product, delivered, quantity, due, days_left, "" if days_left == 1 else "s", price, penalty, penalties_paid, quality, relationship, renewal]

func _layout() -> void:
    var size := get_viewport().get_visible_rect().size
    if size.x < 900.0:
        panel.position = Vector2(10, maxf(300.0, size.y - 365.0))
        panel.size = Vector2(size.x - 20.0, 350.0)
    else:
        panel.position = Vector2(12, 12)
        panel.size = Vector2(430, 265)
