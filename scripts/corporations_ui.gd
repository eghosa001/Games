extends CanvasLayer

## Corporation network command surface. Rival intelligence and actions stay authoritative in Main/AI.
var dimmer: ColorRect
var panel: Panel
var title_label: Label
var status_label: Label
var scroll: ScrollContainer
var list_label: Label
var detail_label: Label
var next_button: Button
var offer_button: Button
var improve_button: Button
var shares_button: Button
var close_button: Button
var refresh_clock := 0.0

const SURFACE := Color("0d2028")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const ACCENT := Color("d5b56e")
const SCRIM := Color(0.02, 0.08, 0.10, 0.72)

func _ready() -> void:
    layer = 67
    _build_ui(); _refresh(true)
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)
func _process(delta: float) -> void:
    if not visible: return
    refresh_clock += delta
    if refresh_clock >= 1.0: refresh_clock = 0.0; _refresh(false)
func _game(): return get_tree().current_scene if get_tree() != null else null
func _rivals():
    var game = _game(); if game == null: return null
    var commands = game.get_node_or_null("GameplayCommandSystem"); if commands == null: return null
    var relationships = commands.get("relationship_system"); if relationships == null: return null
    return relationships.get("rivals")

func _build_ui() -> void:
    dimmer = ColorRect.new(); dimmer.name = "CorporationsModalScrim"; dimmer.color = SCRIM; dimmer.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(dimmer)
    panel = Panel.new(); panel.name = "CorporationsPanel"
    var style := StyleBoxFlat.new(); style.bg_color = SURFACE; style.border_color = BORDER; style.set_border_width_all(1); style.set_corner_radius_all(14); panel.add_theme_stylebox_override("panel", style); add_child(panel)
    title_label = _label("CORPORATION NETWORK", 20, TEXT); status_label = _label("RIVAL INTELLIGENCE", 10, ACCENT)
    scroll = ScrollContainer.new(); scroll.name = "CorporationRivalScroll"; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
    list_label = _label("", 12, TEXT); list_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list_label.custom_minimum_size = Vector2(0, 180); panel.remove_child(list_label); scroll.add_child(list_label)
    detail_label = _label("", 11, ACCENT)
    next_button = _button("NEXT"); next_button.pressed.connect(_next); offer_button = _button("OFFER"); offer_button.pressed.connect(_offer); improve_button = _button("IMPROVE"); improve_button.pressed.connect(_improve); shares_button = _button("SHARES"); shares_button.pressed.connect(_shares); close_button = _button("CLOSE"); close_button.pressed.connect(_close)
    _layout()
func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new(); label.text = text; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); panel.add_child(label); return label
func _button(text: String) -> Button:
    var button := Button.new(); button.text = text; button.focus_mode = Control.FOCUS_NONE; button.clip_text = true; button.custom_minimum_size = Vector2(0, 46); panel.add_child(button); return button
func _layout() -> void:
    if get_viewport() == null or panel == null: return
    var viewport: Vector2 = get_viewport().size; var margin := 12.0 if viewport.x < 390.0 else 16.0
    var width := minf(580.0, maxf(280.0, viewport.x - margin * 2.0)); var height := minf(640.0, maxf(430.0, viewport.y - 96.0))
    dimmer.position = Vector2.ZERO; dimmer.size = viewport; panel.position = Vector2((viewport.x - width) / 2.0, maxf(48.0, (viewport.y - height) / 2.0)); panel.size = Vector2(width, minf(height, viewport.y - panel.position.y - 12.0))
    var compact := width < 390.0; var side := 14.0
    title_label.position = Vector2(side, 12); title_label.size = Vector2(width - 150.0, 28); title_label.add_theme_font_size_override("font_size", 18 if compact else 20)
    status_label.position = Vector2(width - 132.0, 14); status_label.size = Vector2(118.0, 20); status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    scroll.position = Vector2(side, 48); scroll.size = Vector2(width - side * 2.0, maxf(120.0, panel.size.y - 300.0))
    detail_label.position = Vector2(side, panel.size.y - 238.0); detail_label.size = Vector2(width - side * 2.0, 70.0)
    var gap := 6.0; var action_width := maxf(58.0, (width - side * 2.0 - gap * 3.0) / 4.0); var y := panel.size.y - 108.0
    next_button.position = Vector2(side, y); next_button.size = Vector2(action_width, 46); offer_button.position = Vector2(side + action_width + gap, y); offer_button.size = Vector2(action_width, 46); improve_button.position = Vector2(side + (action_width + gap) * 2.0, y); improve_button.size = Vector2(action_width, 46); shares_button.position = Vector2(side + (action_width + gap) * 3.0, y); shares_button.size = Vector2(action_width, 46)
    for button in [next_button, offer_button, improve_button, shares_button]: button.add_theme_font_size_override("font_size", 8 if compact else 10)
    close_button.position = Vector2(side, panel.size.y - 56.0); close_button.size = Vector2(width - side * 2.0, 46)

func _refresh(_force: bool) -> void:
    var model = _rivals()
    if model == null or not model.has_method("ai_status"):
        status_label.text = "NETWORK OFFLINE"; list_label.text = "Rival data unavailable."; detail_label.text = "Reconnect to the corporate intelligence feed."; return
    var state = get_node_or_null("/root/RenewGameState"); var selected := int(state.get_value("competitors", "selected_rival", 0)) if state != null else 0
    var rival_array: Array = model.get("rivals") if model.get("rivals") is Array else []; var rows: Array = []
    for i in range(rival_array.size()):
        var status: Dictionary = model.ai_status(i); if status.is_empty(): continue
        var marker := "›" if i == selected else "·"; var gone := " • ABSORBED" if bool(status.get("eliminated", false)) else ""; var sale := " • FIRE SALE" if bool(status.get("war_sale", false)) else ""
        rows.append("%s %s — %s | %.0f%% share%s%s" % [marker, str(status.get("name", "?")), str(status.get("tier", "?")), float(status.get("market_share", 0.0)) * 100.0, gone, sale])
    list_label.text = "\n".join(rows) if not rows.is_empty() else "No corporations tracked."; list_label.custom_minimum_size.y = maxf(180.0, float(maxi(1, rows.size())) * 30.0); status_label.text = "%d RIVAL%s" % [rival_array.size(), "" if rival_array.size() == 1 else "S"]
    if selected >= 0 and selected < rival_array.size():
        var status: Dictionary = model.ai_status(selected); detail_label.text = "%s\nRelationship %d  •  Share price $%s" % [str(status.get("name", "?")), int(status.get("relationship", 0)), _money(int(model.share_price(selected)) if model.has_method("share_price") else 0)]
    else: detail_label.text = "Select a corporation to inspect its relationship and share price."
func _next() -> void:
    var game = _game(); if game == null or not game.has_method("select_rival"): return
    var state = get_node_or_null("/root/RenewGameState"); var model = _rivals(); var count := 1
    if model != null and model.get("rivals") is Array: count = maxi(1, (model.get("rivals") as Array).size())
    var selected := int(state.get_value("competitors", "selected_rival", 0)) if state != null else 0; game.select_rival((selected + 1) % count); _refresh(true)
func _offer() -> void:
    var game = _game(); if game != null and game.has_method("make_alliance_offer"): game.make_alliance_offer(); _refresh(true)
func _improve() -> void:
    var game = _game(); if game != null and game.has_method("improve_alliance"): game.improve_alliance(); _refresh(true)
func _shares() -> void:
    var game = _game(); if game != null and game.has_method("buy_rival_shares"): game.buy_rival_shares(); _refresh(true)
func _close() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager"); if manager != null and manager.has_method("hide_all_screens"): manager.hide_all_screens()
func _money(amount: int) -> String:
    if amount >= 1000000: return "%.2fM" % (float(amount) / 1000000.0)
    if amount >= 1000: return "%.1fK" % (float(amount) / 1000.0)
    return str(amount)
