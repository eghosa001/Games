extends CanvasLayer

## Property portfolio: every catalog asset with status and value.
## Select, sell and lease route through Main into property_system.
var panel: Panel
var title_label: Label
var list_label: Label
var detail_label: Label
var next_button: Button
var sell_button: Button
var lease_button: Button
var close_button: Button
var refresh_clock := 0.0

const SURFACE := Color("0d2028")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56e")

func _ready() -> void:
    layer = 66
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

func _state():
    return get_node_or_null("/root/RenewGameState")

func _game():
    return get_tree().current_scene if get_tree() != null else null

func _build_ui() -> void:
    panel = Panel.new()
    panel.name = "PortfolioPanel"
    var style := StyleBoxFlat.new()
    style.bg_color = SURFACE
    style.border_color = BORDER
    style.set_border_width_all(1)
    style.set_corner_radius_all(14)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)
    title_label = _label("PROPERTY PORTFOLIO", 20, TEXT)
    list_label = _label("", 12, TEXT)
    detail_label = _label("", 11, ACCENT)
    next_button = _button("NEXT")
    next_button.pressed.connect(_next)
    sell_button = _button("SELL")
    sell_button.pressed.connect(_sell)
    lease_button = _button("LEASE")
    lease_button.pressed.connect(_lease)
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
    next_button.position = Vector2(14, y)
    next_button.size = Vector2((width - 42) / 3.0, 46)
    sell_button.position = Vector2(20 + (width - 42) / 3.0, y)
    sell_button.size = Vector2((width - 42) / 3.0, 46)
    lease_button.position = Vector2(26 + (width - 42) * 2.0 / 3.0, y)
    lease_button.size = Vector2((width - 42) / 3.0, 46)
    close_button.position = Vector2(14, height - 56)
    close_button.size = Vector2(width - 28, 46)

func _catalog() -> Array:
    var state = _state()
    if state == null:
        return []
    var raw: Variant = state.get_value("properties", "catalog", [])
    return raw if raw is Array else []

func _refresh(_force: bool) -> void:
    var state = _state()
    if state == null:
        return
    var catalog := _catalog()
    var owned := bool(state.get_value("properties", "owned", false))
    var selected := int(state.get_value("properties", "selected_property", 0))
    var rows: Array = []
    for i in range(catalog.size()):
        if not (catalog[i] is Dictionary):
            continue
        var entry: Dictionary = catalog[i]
        var marker := ">" if i == selected else " "
        var status := "available"
        if owned and i == selected:
            status = str(state.get_value("properties", "stage", "Neglected"))
        var lease := ""
        if int(entry.get("lease_until", 0)) > int(state.get_value("player", "day", 1)):
            lease = " (leased)"
        rows.append("%s %s — %s, $%s%s" % [marker, str(entry.get("name", "?")), status, _money(int(entry.get("value", 0))), lease])
    list_label.text = "\n".join(rows) if not rows.is_empty() else "No properties surveyed."
    if selected >= 0 and selected < catalog.size() and catalog[selected] is Dictionary:
        var entry: Dictionary = catalog[selected]
        detail_label.text = "%s (%s) — condition %d%%, capacity %d." % [str(entry.get("name", "?")), str(entry.get("type", "?")), int(entry.get("condition", 0)), int(entry.get("capacity", 0))]
    else:
        detail_label.text = ""

func _next() -> void:
    var catalog := _catalog()
    if catalog.is_empty():
        return
    var state = _state()
    if state == null:
        return
    state.set_value("properties", "selected_property", (int(state.get_value("properties", "selected_property", 0)) + 1) % catalog.size())
    _refresh(true)

func _sell() -> void:
    var game = _game()
    if game != null and game.has_method("sell_property"):
        game.sell_property()

func _lease() -> void:
    var game = _game()
    if game != null and game.has_method("lease_property"):
        game.lease_property()

func _close() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"):
        manager.hide_all_screens()

func _money(amount: int) -> String:
    if amount >= 1000:
        return "%.1fK" % (float(amount) / 1000.0)
    return str(amount)
