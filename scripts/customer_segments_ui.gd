extends CanvasLayer

## Responsive customer intelligence surface. Reads canonical state and keeps
## segment selection/detail usable on phones and desktop.
const DemandModel = preload("res://scripts/demand_model.gd")
const BG := Color("071319")
const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56b")

var parent: Node
var root: Control
var panel: Panel
var title_label: Label
var summary_label: Label
var segment_scroll: ScrollContainer
var segment_list: VBoxContainer
var detail_panel: Panel
var detail_scroll: ScrollContainer
var detail_label: Label
var close_button: Button
var demand_model = DemandModel.new()
var selected_segment: Variant = "standard"
var refresh_clock: Variant = 0.0

func _ready() -> void:
    parent = get_tree().root.get_node_or_null("Renew")
    _build_ui()
    _refresh()

func _process(delta: float) -> void:
    refresh_clock -= delta
    if refresh_clock <= 0.0:
        refresh_clock = 0.35
        _refresh()

func _build_ui() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    panel = Panel.new()
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.add_theme_stylebox_override("panel", _style(SURFACE, BORDER, 14))
    root.add_child(panel)

    title_label = Label.new()
    title_label.text = "CUSTOMER INTELLIGENCE"
    title_label.add_theme_font_size_override("font_size", 20)
    title_label.add_theme_color_override("font_color", TEXT)
    panel.add_child(title_label)

    close_button = Button.new()
    close_button.text = "CLOSE"
    close_button.focus_mode = Control.FOCUS_NONE
    close_button.custom_minimum_size = Vector2(72, 44)
    close_button.pressed.connect(_close)
    panel.add_child(close_button)

    summary_label = Label.new()
    summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    summary_label.add_theme_font_size_override("font_size", 11)
    summary_label.add_theme_color_override("font_color", MUTED)
    panel.add_child(summary_label)

    segment_scroll = ScrollContainer.new()
    segment_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    segment_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    segment_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.add_child(segment_scroll)
    segment_list = VBoxContainer.new()
    segment_list.add_theme_constant_override("separation", 6)
    segment_scroll.add_child(segment_list)

    detail_panel = Panel.new()
    detail_panel.add_theme_stylebox_override("panel", _style(SURFACE_2, BORDER, 10))
    panel.add_child(detail_panel)
    detail_scroll = ScrollContainer.new()
    detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    detail_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    detail_panel.add_child(detail_scroll)
    detail_label = Label.new()
    detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail_label.add_theme_font_size_override("font_size", 11)
    detail_label.add_theme_color_override("font_color", TEXT)
    detail_scroll.add_child(detail_label)

    root.resized.connect(_layout_responsive)
    _layout_responsive()

func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 8
    style.content_margin_bottom = 8
    return style

func _layout_responsive() -> void:
    if root == null or panel == null:
        return
    var size := root.size
    var w := maxf(size.x, 320.0)
    var h := maxf(size.y, 480.0)
    var narrow := w < 760.0
    if narrow:
        panel.position = Vector2(8, 70)
        panel.size = Vector2(w - 16.0, maxf(360.0, h - 78.0))
    else:
        panel.position = Vector2(w - 480.0, 110)
        panel.size = Vector2(460.0, minf(600.0, h - 125.0))

    title_label.position = Vector2(14, 12)
    title_label.size = Vector2(maxf(120.0, panel.size.x - 100.0), 30)
    close_button.position = Vector2(panel.size.x - 82.0, 8)
    summary_label.position = Vector2(14, 48)
    summary_label.size = Vector2(panel.size.x - 28.0, 44)

    var content_top := 96.0
    var detail_h := 150.0 if narrow else 165.0
    detail_panel.position = Vector2(12, panel.size.y - detail_h - 12.0)
    detail_panel.size = Vector2(panel.size.x - 24.0, detail_h)
    detail_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    detail_label.custom_minimum_size = Vector2(detail_panel.size.x - 24.0, 0)

    segment_scroll.position = Vector2(12, content_top)
    segment_scroll.size = Vector2(panel.size.x - 24.0, maxf(110.0, detail_panel.position.y - content_top - 10.0))
    segment_list.custom_minimum_size.x = segment_scroll.size.x
    for child in segment_list.get_children():
        child.custom_minimum_size.x = segment_scroll.size.x

func _refresh() -> void:
    if parent == null or panel == null:
        return
    var state = parent.get_node_or_null("/root/RenewGameState")
    if state == null:
        return

    var product: Variant = "furniture"
    var player_price: Variant = int(state.get_value("businesses", "player_price", 220))
    var rival_price: Variant = 120
    var reputation: Variant = int(state.get_value("player", "reputation", 0))
    var marketing: Variant = int(state.get_value("businesses", "marketing_level", 0))
    var quality: Variant = 75
    var employee_productivity: Variant = 1.0
    var district_multiplier: Variant = 1.0
    var district_pressure: Variant = 0.0
    var alliance_sales: Variant = 0.0
    var deal_sales: Variant = 0.0

    var simulation = get_node_or_null("/root/RenewSimulationSystem")
    if simulation != null and simulation.last_result is Dictionary:
        var sim_result: Dictionary = simulation.last_result
        product = str(sim_result.get("product_id", product))
        player_price = int(sim_result.get("player_price", player_price))
        rival_price = int(sim_result.get("competitor_price", rival_price))
        quality = int(sim_result.get("quality", quality))

    var production = get_node_or_null("/root/RenewProductionSystem")
    if production != null:
        var last_run: Dictionary = production.last_run.duplicate(true)
        if not last_run.is_empty():
            product = str(last_run.get("product", product))
            quality = int(last_run.get("quality", quality))

    var gameplay = parent.get_node_or_null("GameplayCommandSystem")
    if gameplay != null:
        var employee_system = gameplay.employee_system
        if employee_system != null:
            employee_productivity = float(employee_system.get_productivity_multiplier("factory_001"))
        var rivals = gameplay.relationship_system.rivals if gameplay.relationship_system != null else null
        if rivals != null:
            if not rivals.rivals.is_empty():
                rival_price = int(rivals.rivals[0].get("price", rival_price))
            var selected_rival: Variant = int(state.get_value("competitors", "selected_rival", 0))
            var selected_district: Variant = int(state.get_value("regions", "selected_district", 0))
            district_pressure = float(rivals.district_pressure(selected_district))
            var alliance: Dictionary = rivals.alliance_bonus(selected_rival)
            var deal: Dictionary = rivals.deal_bonus(selected_rival)
            alliance_sales = float(alliance.get("sales", 0))
            deal_sales = float(deal.get("sales", 0))
        var districts = gameplay.expansion_system.districts if gameplay.expansion_system != null else null
        if districts != null:
            district_multiplier = float(districts.business_multiplier("Consumer Goods"))

    var demand_result: Dictionary = demand_model.calculate(product, float(player_price), float(rival_price), reputation, quality, marketing, 0, employee_productivity, district_multiplier, district_pressure, alliance_sales, deal_sales)
    if not bool(demand_result.get("ok", false)):
        return

    var total: Variant = int(demand_result.get("demand", 0))
    summary_label.text = "%s  •  Your $%d vs rival $%d  •  Total demand %d\nSelect a segment to see requirements, demand strength and pricing advice." % [product.capitalize(), player_price, rival_price, total]

    for child in segment_list.get_children():
        child.queue_free()
    var segment_results: Dictionary = demand_result.get("segments", {})
    for segment in ["budget", "standard", "premium", "industrial", "government"]:
        var segment_detail: Dictionary = segment_results.get(segment, {})
        var demand: Variant = int(segment_detail.get("final_demand", segment_detail.get("demand", 0)))
        var base_demand: Variant = float(segment_detail.get("base_demand", max(1, demand)))
        var ratio: Variant = clampf(float(demand) / maxf(base_demand, 1.0), 0.0, 1.0)
        var button := Button.new()
        button.text = "%s   •   %d demand   %s" % [segment.capitalize(), demand, _demand_bar(ratio)]
        button.custom_minimum_size = Vector2(0, 46)
        button.focus_mode = Control.FOCUS_NONE
        button.mouse_filter = Control.MOUSE_FILTER_STOP
        button.tooltip_text = "Demand strength: %d%%" % int(round(ratio * 100.0))
        button.pressed.connect(_select_segment.bind(segment, product, player_price, rival_price, quality, reputation, marketing, district_multiplier))
        segment_list.add_child(button)

    call_deferred("_layout_responsive")
    _show_selected(segment_results, product, player_price, rival_price, quality, reputation, marketing, district_multiplier)

func _demand_bar(ratio: float) -> String:
    var filled := clampi(int(round(ratio * 8.0)), 0, 8)
    return "[" + "█".repeat(filled) + "░".repeat(8 - filled) + "]"

func _select_segment(segment: String, product: String, player_price: int, rival_price: int, quality: int, reputation: int, marketing: int, district: float) -> void:
    selected_segment = segment
    var result: Dictionary = demand_model.customer_segments.calculate_segment_demand(segment, product, float(player_price), float(rival_price), quality, reputation, marketing, district)
    _show_detail(segment, result, product, player_price, rival_price, quality)

func _show_selected(segment_results: Dictionary, product: String, player_price: int, rival_price: int, quality: int, reputation: int, marketing: int, district: float) -> void:
    var result: Dictionary = segment_results.get(selected_segment, {})
    if result.is_empty():
        selected_segment = "standard"
        result = segment_results.get("standard", {})
    _show_detail(selected_segment, result, product, player_price, rival_price, quality)

func _show_detail(segment: String, result: Dictionary, product: String, player_price: int, rival_price: int, quality: int) -> void:
    var config: Dictionary = demand_model.customer_segments.get_segment_config(segment)
    var modifiers: Dictionary = result.get("modifiers", {})
    var preference: Variant = float(modifiers.get("preference", 0.0))
    var price_modifier: Variant = float(modifiers.get("price", 1.0))
    var quality_modifier: Variant = float(modifiers.get("quality", 1.0))
    var requirement: Variant = int(config.get("quality_requirement", 60))
    var advice: Variant = _advice(segment, player_price, rival_price, quality, requirement, price_modifier, quality_modifier, preference)
    var preferred: Dictionary = config.get("preferred_products", {})
    var preferred_text: Variant = ""
    for product_id in preferred.keys():
        if float(preferred[product_id]) > 0.0:
            if not preferred_text.is_empty(): preferred_text += ", "
            preferred_text += "%s %.2fx" % [str(product_id).capitalize(), float(preferred[product_id])]
    detail_label.text = "%s  |  %s\nDemand: %d   •   Price sensitivity: %.2f   •   Quality required: %d\nPreferred: %s\nPrice effect %.2fx   •   Quality effect %.2fx\n%s" % [segment.capitalize(), product.capitalize(), int(result.get("demand", result.get("final_demand", 0))), float(config.get("price_sensitivity", 1.0)), requirement, preferred_text, price_modifier, quality_modifier, advice]

func _advice(segment: String, player_price: int, rival_price: int, quality: int, requirement: int, price_modifier: float, quality_modifier: float, preference: float) -> String:
    if preference <= 0.0: return "Advice: this product is not a fit for this segment."
    if quality < requirement: return "Advice: improve quality to at least %d to win more %s customers." % [requirement, segment]
    if player_price > rival_price * 1.05: return "Advice: lower price; this segment currently sees your offer as expensive."
    if player_price < rival_price * 0.95: return "Advice: price is helping demand; consider raising price carefully to improve margin."
    if price_modifier < 0.95: return "Advice: price is reducing demand."
    if quality_modifier > 1.05: return "Advice: quality is a strength. Marketing can convert more of this segment."
    return "Advice: price and quality are competitive. Improve reputation or marketing for more demand."

func _close() -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"):
        manager.hide_all_screens()
    else:
        visible = false
