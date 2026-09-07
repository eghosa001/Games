extends CanvasLayer

## Corporation network: live rival standings from the authoritative AI.
## Select, offer, improve and buy shares route through Main.
var panel: Panel
var title_label: Label
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
const MUTED := Color("78949a")
const ACCENT := Color("d5b56e")

func _ready() -> void:
    layer = 67
    _build_ui()
    _refresh(true)
    if not get_viewport().size_changed.is_connected(_layout):
        get_viewport().size_changed.connect(_layout)

func _process(delta: float) -> void:
    if not visible:
        return
    refresh_clock += delta
    if refresh_clock >= 1.0:
        refresh_clock = 0.0
        _refresh(false)

func _game():
    return get_tree().current_scene if get_tree() != null else null

func _rivals():
    var game = _game()
    if game == null:
        return null
    var commands = game.get_node_or_null("GameplayCommandSystem")
    if commands == null:
        return null
    var relationships = commands.get("relationship_system")
    if relationships == null:
        return null
    return relationships.get("rivals")

func _build_ui() -> void:
    panel = Panel.new()
    panel.name = "CorporationsPanel"
    var style := StyleBoxFlat.new()
    style.bg_color = SURFACE
    style.border_color = BORDER
    style.set_border_width_all(1)
    style.set_corner_radius_all(14)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)
    title_label = _label("CORPORATION NETWORK", 20, TEXT)
    list_label = _label("", 12, TEXT)
    detail_label = _label("", 11, ACCENT)
    next_button = _button("NEXT")
    next_button.pressed.connect(_next)
    offer_button = _button("OFFER")
    offer_button.pressed.connect(_offer)
    improve_button = _button("IMPROVE")
    improve_button.pressed.connect(_improve)
    shares_button = _button("SHARES")
    shares_button.pressed.connect(_shares)
    close_button = _button("CLOSE")
    close_button.pressed.connect(_close)
    _layout()

func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    panel.add_child(label)
    return label

func _button(text: String) -> Button:
    var button := Button.new()
    button.text = text
    button.focus_mode = Control.FOCUS_NONE
    button.custom_minimum_size = Vector2(0, 46)
    panel.add_child(button)
    return button

func _layout() -> void:
    var viewport: Vector2 = get_viewport().size
    var margin := 16.0
    var width := minf(560.0, viewport.x - margin * 2.0)
    var height := minf(560.0, viewport.y - 140.0)
    panel.position = Vector2((viewport.x - width) / 2.0, 70.0)
    panel.size = Vector2(width, height)
    title_label.position = Vector2(14, 12)
    title_label.size = Vector2(width - 28, 28)
    list_label.position = Vector2(14, 44)
    list_label.size = Vector2(width - 28, maxf(40.0, height - 224.0))
    detail_label.position = Vector2(14, height - 176)
    detail_label.size = Vector2(width - 28, 60)
    var y := height - 108.0
    var w := (width - 56) / 4.0
    next_button.position = Vector2(14, y)
    next_button.size = Vector2(w, 46)
    offer_button.position = Vector2(20 + w, y)
    offer_button.size = Vector2(w, 46)
    improve_button.position = Vector2(26 + w * 2.0, y)
    improve_button.size = Vector2(w, 46)
    shares_button.position = Vector2(32 + w * 3.0, y)
    shares_button.size = Vector2(w, 46)
    close_button.position = Vector2(14, height - 56)
    close_button.size = Vector2(width - 28, 46)

func _refresh(_force: bool) -> void:
    var model = _rivals()
    if model == null or not model.has_method("ai_status"):
        list_label.text = "Rival data unavailable."
        return
    var state = get_node_or_null("/root/RenewGameState")
    var selected := int(state.get_value("competitors", "selected_rival", 0)) if state != null else 0
    var rows: Array = []
    var count := int((model.get("rivals") as Array).size()) if model.get("rivals") is Array else 0
    for i in range(count):
        var status: Dictionary = model.ai_status(i)
        if status.is_empty():
            continue
        var marker := ">" if i == selected else " "
        var gone := " (absorbed)" if bool(status.get("eliminated", false)) else ""
        var sale := " [FIRE SALE]" if bool(status.get("war_sale", false)) else ""
        rows.append("%s %s — %s, share %.0f%%%s%s" % [marker, str(status.get("name", "?")), str(status.get("tier", "?")), float(status.get("market_share", 0.0)) * 100.0, gone, sale])
    list_label.text = "\n".join(rows) if not rows.is_empty() else "No corporations tracked."
    if selected >= 0 and selected < count:
        var status: Dictionary = model.ai_status(selected)
        detail_label.text = "%s — rel %d, price $%s." % [str(status.get("name", "?")), int(status.get("relationship", 0)), _money(int(model.share_price(selected)) if model.has_method("share_price") else 0)]
    else:
        detail_label.text = ""

func _next() -> void:
    var game = _game()
    if game != null and game.has_method("select_rival"):
        var state = get_node_or_null("/root/RenewGameState")
        var count := 3
        var model = _rivals()
        if model != null and model.get("rivals") is Array:
            count = maxi(1, (model.get("rivals") as Array).size())
        var selected := int(state.get_value("competitors", "selected_rival", 0)) if state != null else 0
        game.select_rival((selected + 1) % count)

func _offer() -> void:
    var game = _game()
    if game != null and game.has_method("make_alliance_offer"):
        game.make_alliance_offer()

func _improve() -> void:
    var game = _game()
    if game != null and game.has_method("improve_alliance"):
        game.improve_alliance()

func _shares() -> void:
    var game = _game()
    if game != null and game.has_method("buy_rival_shares"):
        game.buy_rival_shares()

func _close() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"):
        manager.hide_all_screens()

func _money(amount: int) -> String:
    if amount >= 1000:
        return "%.1fK" % (float(amount) / 1000.0)
    return str(amount)
