extends CanvasLayer

## Customer contract and commercial-deal command center.
## Presentation only: all signing, haggling and cancellation remain authoritative.
var panel: Panel
var title_label: Label
var status_label: Label
var summary_label: Label
var offer_panel: Panel
var offer_title: Label
var offer_detail: Label
var offer_grid: GridContainer
var contract_scroll: ScrollContainer
var contract_list: VBoxContainer
var detail_panel: Panel
var detail_label: Label
var empty_label: Label
var action_row: HBoxContainer
var haggle_button: Button
var cancel_button: Button
var close_button: Button
var selected_contract_id: Variant = ""
var refresh_clock := 0.0
var last_signature := ""

const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const SURFACE_3 := Color("132f38")
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

func _main(): return get_tree().current_scene

func _style(bg: Color, border: Color, radius := 10) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    return style

func _button_style(bg: Color) -> StyleBoxFlat:
    var style := _style(bg, BORDER, 8)
    style.content_margin_left = 10
    style.content_margin_right = 10
    style.content_margin_top = 6
    style.content_margin_bottom = 6
    return style

func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _build_ui() -> void:
    panel = Panel.new()
    panel.name = "ContractsPanel"
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.add_theme_stylebox_override("panel", _style(SURFACE, BORDER, 14))
    add_child(panel)

    title_label = _label("CONTRACTS & COMMERCIAL DEALS", 20, TEXT)
    panel.add_child(title_label)
    status_label = _label("COMMERCIAL DESK  •  LIVE", 10, ACCENT)
    panel.add_child(status_label)
    close_button = Button.new()
    close_button.text = "CLOSE"
    close_button.focus_mode = Control.FOCUS_NONE
    close_button.custom_minimum_size = Vector2(80, 46)
    close_button.pressed.connect(_close)
    panel.add_child(close_button)

    summary_label = _label("", 11, MUTED)
    panel.add_child(summary_label)

    offer_panel = Panel.new()
    offer_panel.add_theme_stylebox_override("panel", _style(SURFACE_2, BORDER, 10))
    panel.add_child(offer_panel)
    offer_title = _label("AVAILABLE COMMERCIAL DEALS", 13, TEXT)
    offer_panel.add_child(offer_title)
    offer_detail = _label("", 10, MUTED)
    offer_panel.add_child(offer_detail)
    offer_grid = GridContainer.new()
    offer_grid.columns = 2
    offer_grid.add_theme_constant_override("h_separation", 7)
    offer_grid.add_theme_constant_override("v_separation", 7)
    offer_panel.add_child(offer_grid)

    contract_scroll = ScrollContainer.new()
    contract_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    contract_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    panel.add_child(contract_scroll)
    contract_list = VBoxContainer.new()
    contract_list.add_theme_constant_override("separation", 7)
    contract_scroll.add_child(contract_list)

    empty_label = _label("No active customer contracts. Review an offer above to turn demand into scheduled production and delivery.", 11, MUTED)
    panel.add_child(empty_label)

    detail_panel = Panel.new()
    detail_panel.add_theme_stylebox_override("panel", _style(SURFACE_3, BORDER, 10))
    panel.add_child(detail_panel)
    detail_label = _label("", 11, TEXT)
    detail_panel.add_child(detail_label)

    action_row = HBoxContainer.new()
    action_row.add_theme_constant_override("separation", 7)
    panel.add_child(action_row)
    haggle_button = _make_action("HAGGLE TERMS", _haggle)
    cancel_button = _make_action("CANCEL CONTRACT", _cancel_selected_contract)
    action_row.add_child(haggle_button)
    action_row.add_child(cancel_button)

func _make_action(text: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.focus_mode = Control.FOCUS_NONE
    button.custom_minimum_size = Vector2(0, 46)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_stylebox_override("normal", _button_style(SURFACE_2))
    button.add_theme_stylebox_override("hover", _button_style(Color("17343d")))
    button.add_theme_stylebox_override("pressed", _button_style(Color("1b3d46")))
    button.add_theme_color_override("font_color", TEXT)
    button.pressed.connect(callback)
    return button

func _add_offer(text: String, method_name: String) -> void:
    var button := _make_action(text, Callable(self, "_sign_offer").bind(method_name))
    button.tooltip_text = "Open the authoritative %s commercial contract flow." % text.to_lower()
    offer_grid.add_child(button)

func _refresh(force: bool = false) -> void:
    if panel == null: return
    var contracts = _contracts()
    var active: Array = []
    if contracts != null and contracts.has_method("list_active_contracts"):
        active = contracts.list_active_contracts()
    var reputation := 0
    var game_state = get_node_or_null("/root/RenewGameState")
    if game_state != null:
        reputation = int(game_state.get_value("player", "reputation", 0))
    summary_label.text = "%d ACTIVE  •  REP %d  •  Select a contract for execution status, economics and renewal outlook." % [active.size(), reputation]
    var offer: Dictionary = {}
    if contracts != null and contracts.has_method("get_future_contract_offer"):
        offer = contracts.get_future_contract_offer(reputation)
    offer_detail.text = _offer_summary(offer)
    _rebuild_offers(offer)
    empty_label.visible = active.is_empty()
    var signature := "%d:%d" % [active.size(), reputation]
    for contract in active:
        signature += ":%s:%d:%d:%d:%d:%d:%d" % [str(contract.get("id", "")), int(contract.get("quantity_delivered", 0)), int(contract.get("quantity_due", 0)), int(contract.get("days_elapsed", 0)), int(contract.get("penalties_paid", 0)), int(contract.get("price", 0)), int(contract.get("quality_delivered", 0))]
    if not force and signature == last_signature:
        if not selected_contract_id.is_empty(): _show_detail(_find_contract(active, selected_contract_id))
        return
    last_signature = signature
    if active.is_empty():
        selected_contract_id = ""
        detail_label.text = "No active contract selected. Commercial offers remain available while eligibility conditions are met."
        haggle_button.disabled = true
        cancel_button.disabled = true
        _layout()
        return
    if selected_contract_id.is_empty() or not _contains_contract(active, selected_contract_id): selected_contract_id = str(active[0].get("id", ""))
    for child in contract_list.get_children(): child.queue_free()
    for contract in active: _add_contract_row(contract)
    _show_detail(_find_contract(active, selected_contract_id))
    _layout()

func _offer_summary(offer: Dictionary) -> String:
    if offer.is_empty(): return "Contract engine unavailable — commercial actions are temporarily offline."
    if not bool(offer.get("eligible", false)): return "NOT ELIGIBLE  •  %s" % str(offer.get("message", "Eligibility requirements not met."))
    var quantity := int(offer.get("quantity", 0))
    var price := int(offer.get("price", 0))
    var duration := int(offer.get("duration_days", 0))
    var pressure := float(offer.get("competitor_bid_pressure", 0.0))
    return "STANDARD OFFER  •  %d units  •  $%d/unit  •  %d days  •  competitor pressure %.0f%%" % [quantity, price, duration, pressure * 100.0]

func _rebuild_offers(offer: Dictionary) -> void:
    for child in offer_grid.get_children(): child.queue_free()
    var eligible := bool(offer.get("eligible", false))
    _add_offer("STANDARD", "sign_contract")
    _add_offer("EXCLUSIVE +25%", "sign_exclusive_contract")
    _add_offer("CONSTRUCTION +10%", "sign_construction_contract")
    _add_offer("GOVERNMENT +15%", "sign_government_contract")
    _add_offer("EXPORT +35%", "sign_export_contract")
    for child in offer_grid.get_children(): child.disabled = not eligible

func _add_contract_row(contract: Dictionary) -> void:
    var id := str(contract.get("id", ""))
    var customer := str(contract.get("customer_id", "Customer"))
    var product := str(contract.get("resource_product", "product")).replace("_", " ").capitalize()
    var delivered := int(contract.get("quantity_delivered", 0))
    var quantity := max(1, int(contract.get("quantity", 0)))
    var days_elapsed := int(contract.get("days_elapsed", 0))
    var schedule: Dictionary = contract.get("delivery_schedule", {})
    var duration := max(1, int(schedule.get("duration_days", 1)))
    var days_left := max(0, duration - days_elapsed)
    var expected: float = float(quantity) * minf(1.0, float(days_elapsed) / float(duration))
    var progress := clampf(float(delivered) / float(quantity), 0.0, 1.0)
    var status: Array = _delivery_status(delivered, expected, days_left, quantity)
    var kind := str(contract.get("kind", "standard"))
    var kind_tag := "" if kind == "standard" else (" [%s]" % kind.to_upper())
    var button := Button.new()
    button.text = "%s  •  %s%s\n%d / %d  •  %d%%  •  %s  •  %dd left" % [customer, product, kind_tag, delivered, quantity, roundi(progress * 100.0), status[0], days_left]
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.custom_minimum_size = Vector2(0, 60)
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_stylebox_override("normal", _button_style(SURFACE_2))
    button.add_theme_stylebox_override("hover", _button_style(Color("17343d")))
    button.add_theme_stylebox_override("pressed", _button_style(Color("1b3d46")))
    button.add_theme_color_override("font_color", TEXT)
    button.pressed.connect(_select_contract.bind(id))
    contract_list.add_child(button)

func _delivery_status(delivered: int, expected: float, days_left: int, quantity: int) -> Array:
    if days_left <= 0: return ["COMPLETE", STATUS_GREEN] if delivered >= quantity else ["OVERDUE", STATUS_RED]
    if delivered >= quantity or float(delivered) >= expected: return ["ON TRACK", STATUS_GREEN]
    var gap_ratio := float(delivered) / expected if expected > 0.0 else 0.0
    return ["AT RISK", STATUS_YELLOW] if gap_ratio >= 0.70 else ["BEHIND", STATUS_RED]

func _contains_contract(contracts: Array, id: String) -> bool: return not _find_contract(contracts, id).is_empty()

func _find_contract(contracts: Array, id: String) -> Dictionary:
    for contract in contracts:
        if str(contract.get("id", "")) == id: return contract
    return {}

func _select_contract(id: String) -> void:
    selected_contract_id = id
    _refresh(true)

func _sign_offer(method_name: String) -> void:
    var main = _main()
    if main == null or not main.has_method(method_name): return
    main.call(method_name)
    last_signature = ""
    _refresh(true)

func _haggle() -> void:
    var main = _main()
    if main != null and main.has_method("haggle_contract"):
        main.haggle_contract()
    last_signature = ""
    _refresh(true)

func _cancel_selected_contract() -> void:
    if selected_contract_id.is_empty(): return
    var main = _main()
    if main != null and main.has_method("cancel_active_contract"):
        main.cancel_active_contract("player cancelled")
    last_signature = ""
    _refresh(true)

func _show_detail(contract: Dictionary) -> void:
    if contract.is_empty():
        detail_label.text = ""
        haggle_button.disabled = true
        cancel_button.disabled = true
        return
    var customer := str(contract.get("customer_id", "Customer"))
    var kind := str(contract.get("kind", "standard"))
    var kind_tag := "" if kind == "standard" else (" [%s]" % kind.to_upper())
    var product := str(contract.get("resource_product", "product")).replace("_", " ").capitalize() + kind_tag
    var quantity := max(1, int(contract.get("quantity", 0)))
    var delivered := int(contract.get("quantity_delivered", 0))
    var due := int(contract.get("quantity_due", 0))
    var price := int(contract.get("price", 0))
    var penalty := int(contract.get("penalty", 0))
    var penalties_paid := int(contract.get("penalties_paid", 0))
    var quality := int(contract.get("quality_requirement", 0))
    var quality_delivered := int(contract.get("quality_delivered", 0))
    var days_elapsed := int(contract.get("days_elapsed", 0))
    var schedule: Dictionary = contract.get("delivery_schedule", {})
    var duration := max(1, int(schedule.get("duration_days", 1)))
    var days_left := max(0, duration - days_elapsed)
    var fulfillment_ratio := clampf(float(delivered) / float(quantity), 0.0, 1.0)
    var expected: float = float(quantity) * minf(1.0, float(days_elapsed) / float(duration))
    var status: Array = _delivery_status(delivered, expected, days_left, quantity)
    var contracts = _contracts()
    var relationship := 50
    if contracts != null and contracts.has_method("get_customer_relationship"):
        relationship = int(contracts.get_customer_relationship(customer))
    var renewal := "Likely" if relationship >= 70 and fulfillment_ratio >= 0.80 else ("Possible" if relationship >= 50 else "Unlikely")
    var last_execution: Dictionary = contract.get("last_execution", {})
    var last_line := "No delivery execution recorded yet."
    if not last_execution.is_empty():
        last_line = "Last delivery: %d delivered / %d due  •  revenue $%d  •  penalty $%d  •  quality %s" % [int(last_execution.get("delivered", 0)), int(last_execution.get("due", 0)), int(last_execution.get("revenue", 0)), int(last_execution.get("penalty", 0)), "PASS" if bool(last_execution.get("quality_ok", false)) else "FAIL"]
    detail_label.text = "%s  |  %s\nDELIVERY  %d / %d   •   %d%% fulfilled   •   %s\nDEADLINE  %d day%s left   •   elapsed %d / %d\nECONOMICS  $%d/unit   •   earned $%d   •   penalties $%d\nQUALITY  ≥ %d required   •   latest %d   •   %s\nCUSTOMER  relationship %d/100   •   renewal %s\n%s" % [customer, product, delivered, quantity, roundi(fulfillment_ratio * 100.0), status[0], days_left, "" if days_left == 1 else "s", days_elapsed, duration, price, int(contract.get("revenue_earned", 0)), penalties_paid, quality, quality_delivered, "PASS" if quality_delivered >= quality else "AT RISK", relationship, renewal, last_line]
    haggle_button.disabled = false
    cancel_button.disabled = false

func _layout() -> void:
    if panel == null: return
    var size := get_viewport().get_visible_rect().size
    var narrow := size.x < 760.0
    var phone := size.x < 430.0
    var width := maxf(304.0, size.x - 16.0) if narrow else minf(560.0, size.x - 36.0)
    var height := maxf(500.0, size.y - 84.0) if narrow else minf(720.0, size.y - 110.0)
    panel.position = Vector2(8, 62) if narrow else Vector2(maxf(18.0, size.x - width - 18.0), 72)
    panel.size = Vector2(width, height)
    title_label.position = Vector2(14, 9)
    title_label.size = Vector2(width - 110.0, 30)
    status_label.position = Vector2(14, 36)
    status_label.size = Vector2(width - 110.0, 18)
    close_button.position = Vector2(width - 90.0, 7)
    close_button.size = Vector2(80, 46)
    summary_label.position = Vector2(14, 56)
    summary_label.size = Vector2(width - 28.0, 34)
    var offer_height := 154.0 if phone else 146.0
    offer_panel.position = Vector2(12, 92)
    offer_panel.size = Vector2(width - 24.0, offer_height)
    offer_title.position = Vector2(10, 8)
    offer_title.size = Vector2(width - 44.0, 22)
    offer_detail.position = Vector2(10, 31)
    offer_detail.size = Vector2(width - 44.0, 35)
    offer_grid.position = Vector2(10, 69)
    offer_grid.size = Vector2(width - 44.0, offer_height - 78.0)
    for child in offer_grid.get_children(): child.custom_minimum_size = Vector2(maxf(120.0, (width - 54.0) / 2.0), 42.0)
    var detail_height := 190.0 if phone else 180.0
    detail_panel.position = Vector2(12, height - detail_height - 62.0)
    detail_panel.size = Vector2(width - 24.0, detail_height)
    detail_label.position = Vector2(10, 8)
    detail_label.size = Vector2(width - 44.0, detail_height - 16.0)
    detail_label.custom_minimum_size = Vector2(width - 48.0, 0)
    action_row.position = Vector2(12, height - 56.0)
    action_row.size = Vector2(width - 24.0, 46)
    contract_scroll.position = Vector2(12, 236 if phone else 232)
    contract_scroll.size = Vector2(width - 24.0, maxf(92.0, detail_panel.position.y - contract_scroll.position.y - 8.0))
    contract_list.custom_minimum_size.x = width - 24.0
    empty_label.position = Vector2(18, contract_scroll.position.y + 8.0)
    empty_label.size = Vector2(width - 36.0, 76)

func _close() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"):
        manager.hide_all_screens()
    else:
        visible = false