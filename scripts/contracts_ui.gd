extends CanvasLayer

## Responsive customer-contract management surface.
## Reads authoritative contract state and routes cancellation through Main.
var panel: Panel
var title_label: Label
var summary_label: Label
var contract_scroll: ScrollContainer
var contract_list: VBoxContainer
var detail_panel: Panel
var detail_scroll: ScrollContainer
var detail_label: Label
var empty_label: Label
var cancel_button: Button
var close_button: Button
var selected_contract_id: Variant = ""
var refresh_clock := 0.0
var last_signature := ""

const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56e")
const STATUS_GREEN := Color(0.25, 0.85, 0.45)
const STATUS_YELLOW := Color(0.95, 0.75, 0.20)
const STATUS_RED := Color(0.95, 0.30, 0.30)

func _ready() -> void:
    layer = 57
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

func _contracts(): return get_node_or_null("/root/RenewContractSystem")

func _style(bg: Color, border: Color, radius := 10) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg; style.border_color = border
    style.set_border_width_all(1); style.set_corner_radius_all(radius)
    return style

func _button_style(bg: Color) -> StyleBoxFlat:
    var style := _style(bg, BORDER, 8)
    style.content_margin_left = 10; style.content_margin_right = 10
    style.content_margin_top = 6; style.content_margin_bottom = 6
    return style

func _build_ui() -> void:
    panel = Panel.new(); panel.name = "ContractsPanel"
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.add_theme_stylebox_override("panel", _style(SURFACE, BORDER, 14)); add_child(panel)
    title_label = Label.new(); title_label.text = "CUSTOMER CONTRACTS"
    title_label.add_theme_font_size_override("font_size", 20); title_label.add_theme_color_override("font_color", TEXT); panel.add_child(title_label)
    close_button = Button.new(); close_button.text = "CLOSE"; close_button.focus_mode = Control.FOCUS_NONE; close_button.custom_minimum_size = Vector2(80, 46); close_button.pressed.connect(_close); panel.add_child(close_button)
    summary_label = Label.new(); summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; summary_label.add_theme_font_size_override("font_size", 11); summary_label.add_theme_color_override("font_color", MUTED); panel.add_child(summary_label)
    contract_scroll = ScrollContainer.new(); contract_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; contract_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; panel.add_child(contract_scroll)
    contract_list = VBoxContainer.new(); contract_list.add_theme_constant_override("separation", 7); contract_scroll.add_child(contract_list)
    empty_label = Label.new(); empty_label.text = "No active customer contracts."; empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; empty_label.add_theme_color_override("font_color", MUTED); panel.add_child(empty_label)
    detail_panel = Panel.new(); detail_panel.add_theme_stylebox_override("panel", _style(SURFACE_2, BORDER, 10)); panel.add_child(detail_panel)
    detail_scroll = ScrollContainer.new(); detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; detail_panel.add_child(detail_scroll)
    detail_label = Label.new(); detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; detail_label.add_theme_font_size_override("font_size", 11); detail_label.add_theme_color_override("font_color", TEXT); detail_scroll.add_child(detail_label)
    cancel_button = Button.new(); cancel_button.text = "CANCEL ACTIVE CONTRACT"; cancel_button.focus_mode = Control.FOCUS_NONE; cancel_button.custom_minimum_size = Vector2(0, 46); cancel_button.pressed.connect(_cancel_selected_contract); panel.add_child(cancel_button)

func _refresh(force: bool = false) -> void:
    if panel == null: return
    var contracts = _contracts(); var active: Array = []
    if contracts != null and contracts.has_method("list_active_contracts"): active = contracts.list_active_contracts()
    summary_label.text = "%d active contract%s  •  Select a contract to inspect delivery, pricing, quality and renewal risk." % [active.size(), "" if active.size() == 1 else "s"]
    empty_label.visible = active.is_empty(); cancel_button.visible = not active.is_empty(); cancel_button.disabled = active.is_empty()
    var signature := "%d" % active.size()
    for contract in active:
        signature += ":%s:%d:%d:%d" % [str(contract.get("id", "")), int(contract.get("quantity_delivered", 0)), int(contract.get("days_elapsed", 0)), int(contract.get("penalties_paid", 0))]
    if not force and signature == last_signature:
        if not selected_contract_id.is_empty(): _show_detail(_find_contract(active, selected_contract_id))
        return
    last_signature = signature
    var scroll_value := contract_scroll.scroll_vertical
    if active.is_empty():
        selected_contract_id = ""
        detail_label.text = "Sign a customer contract to turn demand into scheduled production and delivery."
        _layout(); return
    if selected_contract_id.is_empty() or not _contains_contract(active, selected_contract_id): selected_contract_id = str(active[0].get("id", ""))
    for child in contract_list.get_children(): child.queue_free()
    for contract in active: _add_contract_row(contract)
    _show_detail(_find_contract(active, selected_contract_id)); _layout()
    contract_scroll.set_deferred("scroll_vertical", scroll_value)

func _add_contract_row(contract: Dictionary) -> void:
    var id := str(contract.get("id", "")); var customer := str(contract.get("customer_id", "Customer")); var product := str(contract.get("resource_product", "product")).replace("_", " ").capitalize()
    var delivered := int(contract.get("quantity_delivered", 0)); var quantity := max(1, int(contract.get("quantity", 0))); var days_elapsed := int(contract.get("days_elapsed", 0))
    var schedule: Dictionary = contract.get("delivery_schedule", {}); var duration := max(1, int(schedule.get("duration_days", 1))); var days_left := max(0, duration - days_elapsed)
    var expected := quantity * minf(1.0, float(days_elapsed) / float(duration)); var progress := clampf(float(delivered) / float(quantity), 0.0, 1.0); var status: Array = _delivery_status(delivered, expected, days_left, quantity)
    var button := Button.new(); button.text = "%s  •  %s\n%d / %d  •  %d%%  •  %s" % [customer, product, delivered, quantity, roundi(progress * 100.0), status[0]]; button.alignment = HORIZONTAL_ALIGNMENT_LEFT; button.custom_minimum_size = Vector2(0, 58); button.focus_mode = Control.FOCUS_NONE
    button.add_theme_stylebox_override("normal", _button_style(SURFACE_2)); button.add_theme_stylebox_override("hover", _button_style(Color("17343d"))); button.add_theme_stylebox_override("pressed", _button_style(Color("1b3d46"))); button.add_theme_color_override("font_color", TEXT); button.pressed.connect(_select_contract.bind(id)); contract_list.add_child(button)

func _delivery_status(delivered: int, expected: float, days_left: int, quantity: int) -> Array:
    if days_left <= 0: return ["ON TRACK • COMPLETE", STATUS_GREEN] if delivered >= quantity else ["OVERDUE • ACTION NEEDED", STATUS_RED]
    if delivered >= quantity or float(delivered) >= expected: return ["ON TRACK", STATUS_GREEN]
    var gap_ratio := float(delivered) / expected if expected > 0.0 else 0.0
    return ["AT RISK", STATUS_YELLOW] if gap_ratio >= 0.70 else ["BEHIND • ACTION NEEDED", STATUS_RED]

func _contains_contract(contracts: Array, id: String) -> bool: return not _find_contract(contracts, id).is_empty()
func _find_contract(contracts: Array, id: String) -> Dictionary:
    for contract in contracts:
        if str(contract.get("id", "")) == id: return contract
    return {}
func _select_contract(id: String) -> void: selected_contract_id = id; _refresh(true)
func _cancel_selected_contract() -> void:
    var main = get_tree().current_scene
    if main != null and main.has_method("cancel_active_contract"): main.cancel_active_contract("player cancelled")
    last_signature = ""; _refresh(true)
func _close() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"): manager.hide_all_screens()
    else: visible = false

func _show_detail(contract: Dictionary) -> void:
    if contract.is_empty(): detail_label.text = ""; return
    var customer := str(contract.get("customer_id", "Customer")); var product := str(contract.get("resource_product", "product")).replace("_", " ").capitalize(); var quantity := max(1, int(contract.get("quantity", 0))); var delivered := int(contract.get("quantity_delivered", 0)); var due := int(contract.get("quantity_due", 0)); var price := int(contract.get("price", 0)); var penalty := int(contract.get("penalty", 0)); var penalties_paid := int(contract.get("penalties_paid", 0)); var quality := int(contract.get("quality_requirement", 0)); var days_elapsed := int(contract.get("days_elapsed", 0))
    var schedule: Dictionary = contract.get("delivery_schedule", {}); var duration := max(1, int(schedule.get("duration_days", 1))); var days_left := max(0, duration - days_elapsed); var expected := quantity * minf(1.0, float(days_elapsed) / float(duration)); var status: Array = _delivery_status(delivered, expected, days_left, quantity)
    var relationship := 50; var contracts = _contracts(); if contracts != null and contracts.has_method("get_customer_relationship"): relationship = int(contracts.get_customer_relationship(customer))
    var fulfillment_ratio := float(delivered) / float(quantity); var renewal := "Likely" if relationship >= 70 and fulfillment_ratio >= 0.80 else ("Possible" if relationship >= 50 else "Unlikely")
    detail_label.text = "%s  |  %s\nDelivery %d / %d   •   Progress %d%%   •   Due %d\nStatus  %s\nDeadline  %d day%s left   •   Price  $%d/unit\nPenalty  $%d/unit   •   Paid  $%d   •   Quality ≥ %d\nCustomer relationship  %d/100   •   Renewal  %s" % [customer, product, delivered, quantity, roundi(fulfillment_ratio * 100.0), due, status[0], days_left, "" if days_left == 1 else "s", price, penalty, penalties_paid, quality, relationship, renewal]

func _layout() -> void:
    if panel == null: return
    var size := get_viewport().get_visible_rect().size; var narrow := size.x < 760.0; var phone := size.x < 430.0; var width := maxf(304.0, size.x - 16.0) if narrow else minf(520.0, size.x - 36.0); var height := maxf(400.0, size.y - 92.0) if narrow else minf(650.0, size.y - 120.0)
    panel.position = Vector2(8, 70) if narrow else Vector2(maxf(18.0, size.x - width - 18.0), 90); panel.size = Vector2(width, height)
    title_label.position = Vector2(14, 10); title_label.size = Vector2(width - 100.0, 30); close_button.position = Vector2(width - 90.0, 7); close_button.size = Vector2(80, 46); summary_label.position = Vector2(14, 46); summary_label.size = Vector2(width - 28.0, 44)
    var detail_height := 150.0 if phone else 158.0
    detail_panel.position = Vector2(12, height - detail_height - 70.0); detail_panel.size = Vector2(width - 24.0, detail_height); detail_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); detail_label.custom_minimum_size = Vector2(width - 48.0, 0)
    cancel_button.position = Vector2(12, height - 58.0); cancel_button.size = Vector2(width - 24.0, 46)
    contract_scroll.position = Vector2(12, 96); contract_scroll.size = Vector2(width - 24.0, maxf(96.0, detail_panel.position.y - 106.0)); contract_list.custom_minimum_size.x = width - 24.0; empty_label.position = Vector2(18, 120); empty_label.size = Vector2(width - 36.0, 70)
