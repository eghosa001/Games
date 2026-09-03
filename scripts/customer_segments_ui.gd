extends CanvasLayer

## V1 customer visibility layer. Shows the five customer segments and explains
## demand using the same DemandModel that drives sales.
const DemandModel = preload("res://scripts/demand_model.gd")

var parent: Node
var root: Control
var panel: Panel
var title_label: Label
var summary_label: Label
var segment_list: VBoxContainer
var demand_model = DemandModel.new()
var refresh_clock := 0.0

func _ready() -> void:
    parent = get_parent()
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
    panel.position = Vector2(800, 238)
    panel.size = Vector2(462, 320)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(panel)

    title_label = Label.new()
    title_label.position = Vector2(16, 12)
    title_label.size = Vector2(430, 30)
    title_label.add_theme_font_size_override("font_size", 18)
    title_label.add_theme_color_override("font_color", Color("dce8e8"))
    title_label.text = "CUSTOMERS"
    panel.add_child(title_label)

    summary_label = Label.new()
    summary_label.position = Vector2(16, 44)
    summary_label.size = Vector2(430, 48)
    summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    summary_label.add_theme_font_size_override("font_size", 12)
    summary_label.add_theme_color_override("font_color", Color("a9c2bd"))
    panel.add_child(summary_label)

    segment_list = VBoxContainer.new()
    segment_list.position = Vector2(16, 98)
    segment_list.size = Vector2(430, 205)
    segment_list.add_theme_constant_override("separation", 4)
    panel.add_child(segment_list)

func _refresh() -> void:
    if parent == null or panel == null: return
    var state = parent.get_node_or_null("/root/RenewGameState")
    if state == null: return

    var product := "furniture"
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
        var result: Dictionary = simulation.last_result
        product = str(result.get("product_id", product))
        player_price = int(result.get("player_price", player_price))
        rival_price = int(result.get("competitor_price", rival_price))
        quality = int(result.get("quality", quality))

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
            if not rivals.rivals.is_empty(): rival_price = int(rivals.rivals[0].get("price", rival_price))
            var selected_rival := int(state.get_value("competitors", "selected_rival", 0))
            var selected_district := int(state.get_value("regions", "selected_district", 0))
            district_pressure = float(rivals.district_pressure(selected_district))
            var alliance: Dictionary = rivals.alliance_bonus(selected_rival)
            var deal: Dictionary = rivals.deal_bonus(selected_rival)
            alliance_sales = float(alliance.get("sales", 0))
            deal_sales = float(deal.get("sales", 0))
        var districts = gameplay.expansion_system.districts if gameplay.expansion_system != null else null
        if districts != null:
            district_multiplier = float(districts.business_multiplier("Consumer Goods"))

    var demand_result: Dictionary = demand_model.calculate(
        product, float(player_price), float(rival_price), reputation, quality,
        marketing, 0, employee_productivity, district_multiplier,
        district_pressure, alliance_sales, deal_sales
    )
    if not bool(demand_result.get("ok", false)): return

    var total := int(demand_result.get("demand", 0))
    var relative := float(demand_result.get("relative_price", 1.0))
    summary_label.text = "%s  |  Your $%d vs rival $%d  |  Demand %d" % [product.capitalize(), player_price, rival_price, total]

    for child in segment_list.get_children(): child.queue_free()
    var segments: Dictionary = demand_result.get("segments", {})
    for segment in ["budget", "standard", "premium", "industrial", "government"]:
        var detail: Dictionary = segments.get(segment, {})
        var demand := int(detail.get("final_demand", detail.get("demand", 0)))
        var preference := float(detail.get("modifiers", {}).get("preference", 0.0))
        var price_modifier := float(detail.get("modifiers", {}).get("price", 1.0))
        var quality_modifier := float(detail.get("modifiers", {}).get("quality", 1.0))
        var reason := _reason(price_modifier, quality_modifier, preference, relative)
        var row := Label.new()
        row.custom_minimum_size = Vector2(430, 34)
        row.text = "%s  %2d units\n   %s" % [segment.capitalize(), demand, reason]
        row.add_theme_font_size_override("font_size", 11)
        row.add_theme_color_override("font_color", Color("d8e5e6"))
        row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        segment_list.add_child(row)

func _reason(price_modifier: float, quality_modifier: float, preference: float, relative: float) -> String:
    var price_text := "price helps" if price_modifier > 1.05 else ("price hurts" if price_modifier < 0.95 else "price is competitive")
    var quality_text := "quality helps" if quality_modifier > 1.05 else ("quality is below requirement" if quality_modifier < 0.95 else "quality meets requirement")
    var preference_text := "strong product fit" if preference >= 1.15 else ("weak product fit" if preference < 0.70 else "normal product fit")
    var relative_text := "below rival" if relative < 1.0 else ("above rival" if relative > 1.0 else "matches rival")
    return "%s; %s; %s; %s" % [price_text, quality_text, preference_text, relative_text]
