extends CanvasLayer

## Customer / Market Operations surface. Reads canonical state and keeps
## segment intelligence, demand signals and commercial advice usable on touch.
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
var scrim: ColorRect
var panel: Panel
var title_label: Label
var summary_label: Label
var market_status: Label
var segment_scroll: ScrollContainer
var segment_list: VBoxContainer
var detail_panel: Panel
var detail_scroll: ScrollContainer
var detail_label: Label
var close_button: Button
var demand_model := DemandModel.new()
var selected_segment: Variant = "standard"
var refresh_clock := 0.0

func _ready() -> void:
    parent = get_tree().root.get_node_or_null("Renew")
    _build_ui()
    _refresh()
    visible = false

func open_screen() -> void:
    visible = true
    _refresh()
    _layout_responsive()

func close_screen() -> void:
    visible = false

func _process(delta: float) -> void:
    if not visible: return
    refresh_clock -= delta
    if refresh_clock <= 0.0:
        refresh_clock = 0.35
        _refresh()

func _build_ui() -> void:
    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(root)

    scrim = ColorRect.new()
    scrim.color = Color(0.01, 0.06, 0.08, 0.84)
    scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scrim.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(scrim)

    panel = Panel.new()
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.add_theme_stylebox_override("panel", _style(SURFACE, BORDER, 14))
    root.add_child(panel)

    title_label = Label.new()
    title_label.text = "CUSTOMER & MARKET INTELLIGENCE"
    title_label.add_theme_font_size_override("font_size", 20)
    title_label.add_theme_color_override("font_color", TEXT)
    panel.add_child(title_label)

    close_button = Button.new()
    close_button.text = "CLOSE"
    close_button.focus_mode = Control.FOCUS_NONE
    close_button.custom_minimum_size = Vector2(82, 44)
    close_button.add_theme_font_size_override("font_size", 11)
    close_button.add_theme_stylebox_override("normal", _style(SURFACE_2, BORDER, 8))
    close_button.add_theme_stylebox_override("hover", _style(Color("18363a"), ACCENT, 8))
    close_button.pressed.connect(_close)
    panel.add_child(close_button)

    market_status = Label.new()
    market_status.add_theme_font_size_override("font_size", 10)
    market_status.add_theme_color_override("font_color", ACCENT)
    panel.add_child(market_status)

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
    if root == null or panel == null: return
    var size := root.size
    var w := maxf(size.x, 320.0)
    var h := maxf(size.y, 480.0)
    var narrow := w < 760.0
    if narrow:
        panel.position = Vector2(8, 62)
        panel.size = Vector2(w - 16.0, maxf(390.0, h - 70.0))
    else:
        panel.position = Vector2((w - 720.0) * 0.5, 76)
        panel.size = Vector2(720.0, minf(690.0, h - 92.0))

    title_label.position = Vector2(14, 10)
    title_label.size = Vector2(maxf(150.0, panel.size.x - 115.0), 30)
    close_button.position = Vector2(panel.size.x - 94.0, 7)
    market_status.position = Vector2(14, 42)
    market_status.size = Vector2(panel.size.x - 28.0, 20)
    summary_label.position = Vector2(14, 64)
    summary_label.size = Vector2(panel.size.x - 28.0, 44)

    var content_top := 112.0
    var detail_h := 174.0 if narrow else 185.0
    detail_panel.position = Vector2(12, panel.size.y - detail_h - 12.0)
    detail_panel.size = Vector2(panel.size.x - 24.0, detail_h)
    detail_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    detail_label.custom_minimum_size = Vector2(maxf(0.0, detail_panel.size.x - 24.0), 0)

    segment_scroll.position = Vector2(12, content_top)
    segment_scroll.size = Vector2(panel.size.x - 24.0, maxf(120.0, detail_panel.position.y - content_top - 10.0))
    segment_list.custom_minimum_size.x = segment_scroll.size.x
    for child in segment_list.get_children(): child.custom_minimum_size.x = segment_scroll.size.x

func _refresh() -> void:
    if parent == null or panel == null: return
    var state = parent.get_node_or_null("/root/RenewGameState")
    if state == null: return

    var product: Variant = "furniture"
    var active_industry := str(state.get_value("businesses", "industry_id", ""))
    if active_industry in ["furniture", "construction_materials", "consumer_electronics"]: product = active_industry
    var player_price := int(state.get_value("businesses", "player_price", 220))
    var rival_price := 120
    var reputation := int(state.get_value("player", "reputation", 0))
    var marketing := int(state.get_value("businesses", "marketing_level", 0))
    var quality := 75
    var employee_productivity := 1.0
    var district_multiplier := 1.0
    var district_pressure := 0.0
    var alliance_sales := 0.0
    var deal_sales := 0.0

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
        if employee_system != null: employee_productivity = float(employee_system.get_productivity_multiplier("factory_001"))
        var rivals = gameplay.relationship_system.rivals if gameplay.relationship_system != null else null
        if rivals != null and not rivals.rivals.is_empty():
            rival_price = int(rivals.rivals[0].get("price", rival_price))
            var selected_rival := int(state.get_value("competitors", "selected_rival", 0))
            var selected_district := int(state.get_value("regions", "selected_district", 0))
            district_pressure = float(rivals.district_pressure(selected_district))
            alliance_sales = float(rivals.alliance_bonus(selected_rival).get("sales", 0))
            deal_sales = float(rivals.deal_bonus(selected_rival).get("sales", 0))
        var districts = gameplay.expansion_system.districts if gameplay.expansion_system != null else null
        if districts != null: district_multiplier = float(districts.business_multiplier("Consumer Goods"))

    var demand_result: Dictionary = demand_model.calculate(product, float(player_price), float(rival_price), reputation, quality, marketing, 0, employee_productivity, district_multiplier, district_pressure, alliance_sales, deal_sales)
    if not bool(demand_result.get("ok", false)): return

    var total := int(demand_result.get("demand", 0))
    var price_delta := player_price - rival_price
    var price_signal := "PRICE ADVANTAGE" if price_delta < 0 else ("PRICE PARITY" if abs(price_delta) <= 5 else "PRICE PREMIUM")
    market_status.text = "LIVE MARKET  •  %s  •  QUALITY %d  •  MARKETING LVL %d  •  %s" % [product.to_upper(), quality, marketing, price_signal]
    summary_label.text = "Your %d vs rival %d  •  Estimated demand %d  •  Reputation %d\nSegment intelligence converts price, quality, reputation and market modifiers into actionable positioning." % [player_price, rival_price, total, reputation]

    for child in segment_list.get_children(): child.queue_free()
    var segment_results: Dictionary = demand_result.get("segments", {})
    for segment in ["budget", "standard", "premium", "industrial", "government"]:
        var segment_detail: Dictionary = segment_results.get(segment, {})
        var demand := int(segment_detail.get("final_demand", segment_detail.get("demand", 0)))
        var base_demand := float(segment_detail.get("base_demand", max(1, demand)))
        var ratio := clampf(float(demand) / maxf(base_demand, 1.0), 0.0, 1.0)
        var button := Button.new()
        button.text = "%s   •   %d demand   %s" % [segment.capitalize(), demand, _demand_bar(ratio)]
        button.custom_minimum_size = Vector2(0, 46)
        button.focus_mode = Control.FOCUS_NONE
        button.mouse_filter = Control.MOUSE_FILTER_STOP
        button.tooltip_text = "Demand strength: %d%%" % int(round(ratio * 100.0))
        button.add_theme_font_size_override("font_size", 11)
        button.add_theme_stylebox_override("normal", _style(SURFACE_2, BORDER, 8))
        button.add_theme_stylebox_override("hover", _style(Color("18363a"), ACCENT, 8))
        button.add_theme_stylebox_override("pressed", _style(Color("18363a"), ACCENT, 8))
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
    var preference := float(modifiers.get("preference", 0.0))
    var price_modifier := float(modifiers.get("price", 1.0))
    var quality_modifier := float(modifiers.get("quality", 1.0))
    var requirement := int(config.get("quality_requirement", 60))
    var advice := _advice(segment, player_price, rival_price, quality, requirement, price_modifier, quality_modifier, preference)
    var preferred: Dictionary = config.get("preferred_products", {})
    var preferred_text := ""
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
    if manager != null and manager.has_method("hide_all_screens"): manager.hide_all_screens()
    else: visible = false
