extends CanvasLayer

var panel: Panel
var title_label: Label
var summary_label: Label
var contract_list: VBoxContainer
var detail_label: Label
var empty_label: Label
var cancel_button: Button
var selected_contract_id: Variant = ""

const STATUS_GREEN := Color(0.25, 0.85, 0.45)
const STATUS_YELLOW := Color(0.95, 0.75, 0.20)
const STATUS_RED := Color(0.95, 0.30, 0.30)

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
    panel.size = Vector2(430, 360)
    add_child(panel)
    var margin: Variant = MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_bottom", 10)
    panel.add_child(margin)
    var root: Variant = VBoxContainer.new()
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
    cancel_button = Button.new()
    cancel_button.text = "CANCEL ACTIVE CONTRACT"
    cancel_button.custom_minimum_size = Vector2(0, 30)
    cancel_button.pressed.connect(_cancel_selected_contract)
    root.add_child(cancel_button)

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
    cancel_button.visible = not active.is_empty()
    cancel_button.disabled = active.is_empty()
    if active.is_empty():
        detail_label.text = "Sign a contract to turn customer demand into scheduled production and delivery."
        return
    if selected_contract_id.is_empty() or not _contains_contract(active, selected_contract_id):
        selected_contract_id = str(active[0].get("id", ""))
    for contract in active:
        _add_contract_row(contract)
    _show_detail(_find_contract(active, selected_contract_id))

func _add_contract_row(contract: Dictionary) -> void:
    var id: Variant = str(contract.get("id", ""))
    var customer: Variant = str(contract.get("customer_id", "Customer"))
    var product: Variant = str(contract.get("resource_product", "product")).replace("_", " ").capitalize()
    var delivered: Variant = int(contract.get("quantity_delivered", 0))
    var quantity: Variant = max(1, int(contract.get("quantity", 0)))
    var days_elapsed: Variant = int(contract.get("days_elapsed", 0))
    var schedule: Dictionary = contract.get("delivery_schedule", {})
    var duration: Variant = max(1, int(schedule.get("duration_days", 1)))
    var days_left: Variant = max(0, duration - days_elapsed)
    var expected: Variant = quantity * minf(1.0, float(days_elapsed) / float(duration))
    var progress: Variant = clampf(float(delivered) / float(quantity), 0.0, 1.0)
    var status: Variant = _delivery_status(delivered, expected, days_left, quantity)
    var status_color: Color = status[1]

    var row: Variant = VBoxContainer.new()
    row.add_theme_constant_override("separation", 2)
    contract_list.add_child(row)

    var button: Variant = Button.new()
    button.text = "%s  •  %s  •  %d/%d" % [customer, product, delivered, quantity]
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.custom_minimum_size = Vector2(0, 32)
    if id == selected_contract_id: button.text += "  ◀"
    button.pressed.connect(_select_contract.bind(id))
    row.add_child(button)

    var progress_bar: Variant = ProgressBar.new()
    progress_bar.min_value = 0.0
    progress_bar.max_value = 1.0
    progress_bar.value = progress
    progress_bar.show_percentage = false
    progress_bar.custom_minimum_size = Vector2(0, 9)
    progress_bar.modulate = status_color
    row.add_child(progress_bar)

    var status_label: Variant = Label.new()
    status_label.text = "%s  •  %d day%s left" % [status[0], days_left, "" if days_left == 1 else "s"]
    status_label.add_theme_font_size_override("font_size", 11)
    status_label.modulate = status_color
    row.add_child(status_label)

func _delivery_status(delivered: int, expected: float, days_left: int, quantity: int) -> Array:
    if days_left <= 0:
        if delivered >= quantity:
            return ["ON TRACK • COMPLETE", STATUS_GREEN]
        return ["OVERDUE • ACTION NEEDED", STATUS_RED]
    if delivered >= quantity:
        return ["ON TRACK • COMPLETE", STATUS_GREEN]
    if float(delivered) >= expected:
        return ["ON TRACK", STATUS_GREEN]
    var gap_ratio: Variant = 1.0
    if expected > 0.0:
        gap_ratio = float(delivered) / expected
    if gap_ratio >= 0.70:
        return ["AT RISK", STATUS_YELLOW]
    return ["BEHIND • ACTION NEEDED", STATUS_RED]

func _contains_contract(contracts: Array, id: String) -> bool:
    return not _find_contract(contracts, id).is_empty()

func _find_contract(contracts: Array, id: String) -> Dictionary:
    for contract in contracts:
        if str(contract.get("id", "")) == id: return contract
    return {}

func _select_contract(id: String) -> void:
    selected_contract_id = id
    _refresh()

func _cancel_selected_contract() -> void:
    var main = get_tree().current_scene
    if main != null and main.has_method("cancel_active_contract"):
        main.cancel_active_contract("player cancelled")
    _refresh()

func _show_detail(contract: Dictionary) -> void:
    if contract.is_empty():
        detail_label.text = ""
        return
    var customer: Variant = str(contract.get("customer_id", "Customer"))
    var product: Variant = str(contract.get("resource_product", "product")).replace("_", " ").capitalize()
    var quantity: Variant = int(contract.get("quantity", 0))
    var delivered: Variant = int(contract.get("quantity_delivered", 0))
    var due: Variant = int(contract.get("quantity_due", 0))
    var price: Variant = int(contract.get("price", 0))
    var penalty: Variant = int(contract.get("penalty", 0))
    var penalties_paid: Variant = int(contract.get("penalties_paid", 0))
    var quality: Variant = int(contract.get("quality_requirement", 0))
    var days_elapsed: Variant = int(contract.get("days_elapsed", 0))
    var schedule: Dictionary = contract.get("delivery_schedule", {})
    var duration: Variant = max(1, int(schedule.get("duration_days", 1)))
    var days_left: Variant = max(0, duration - days_elapsed)
    var expected: Variant = quantity * minf(1.0, float(days_elapsed) / float(duration))
    var status: Variant = _delivery_status(delivered, expected, days_left, max(1, quantity))
    var relationship: Variant = 50
    var contracts = _contracts()
    if contracts != null and contracts.has_method("get_customer_relationship"):
        relationship = int(contracts.get_customer_relationship(customer))
    var fulfillment_ratio: Variant = float(delivered) / float(max(1, quantity))
    var renewal: Variant = "Likely" if relationship >= 70 and fulfillment_ratio >= 0.80 else ("Possible" if relationship >= 50 else "Unlikely")
    detail_label.text = "%s  |  %s\nDelivery: %d / %d   •   Progress: %d%%   •   Due: %d\nStatus: %s\nDeadline: %d day%s left   •   Price: $%d/unit\nPenalty: $%d/unit   •   Paid: $%d   •   Quality ≥ %d\nCustomer relationship: %d/100   •   Renewal: %s" % [customer, product, delivered, quantity, roundi(fulfillment_ratio * 100.0), due, status[0], days_left, "" if days_left == 1 else "s", price, penalty, penalties_paid, quality, relationship, renewal]

func _layout() -> void:
    var size: Variant = get_viewport().get_visible_rect().size
    if size.x < 900.0:
        panel.position = Vector2(10, maxf(300.0, size.y - 365.0))
        panel.size = Vector2(size.x - 20.0, 350.0)
    else:
        panel.position = Vector2(12, 12)
        panel.size = Vector2(430, 360)
