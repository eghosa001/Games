extends CanvasLayer

## Property portfolio command surface. Gameplay actions remain delegated to Main.
var dimmer: ColorRect
var panel: Panel
var title_label: Label
var status_label: Label
var scroll: ScrollContainer
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
const SCRIM := Color(0.02, 0.08, 0.10, 0.72)

func _ready() -> void:
    layer = 66
    _build_ui()
    _refresh(true)
    if not get_viewport().size_changed.is_connected(_layout):
        get_viewport().size_changed.connect(_layout)

func _process(delta: float) -> void:
    if not visible: return
    refresh_clock += delta
    if refresh_clock >= 1.0:
        refresh_clock = 0.0
        _refresh(false)

func _state(): return get_node_or_null("/root/RenewGameState")
func _game(): return get_tree().current_scene if get_tree() != null else null

func _build_ui() -> void:
    dimmer = ColorRect.new(); dimmer.name = "PortfolioModalScrim"; dimmer.color = SCRIM; dimmer.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(dimmer)
    panel = Panel.new(); panel.name = "PortfolioPanel"
    var style := StyleBoxFlat.new(); style.bg_color = SURFACE; style.border_color = BORDER; style.set_border_width_all(1); style.set_corner_radius_all(14); panel.add_theme_stylebox_override("panel", style); add_child(panel)
    title_label = _label("PROPERTY PORTFOLIO", 20, TEXT)
    status_label = _label("ASSET REGISTER", 10, ACCENT)
    scroll = ScrollContainer.new(); scroll.name = "PortfolioAssetScroll"; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
    list_label = _label("", 12, TEXT); list_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list_label.custom_minimum_size = Vector2(0, 180); panel.remove_child(list_label); scroll.add_child(list_label)
    detail_label = _label("", 11, ACCENT)
    next_button = _button("NEXT"); next_button.pressed.connect(_next)
    sell_button = _button("SELL"); sell_button.pressed.connect(_sell)
    lease_button = _button("LEASE"); lease_button.pressed.connect(_lease)
    close_button = _button("CLOSE"); close_button.pressed.connect(_close)
    _layout()

func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new(); label.text = text; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.add_theme_font_size_override("font_size", size); label.add_theme_color_override("font_color", color); panel.add_child(label); return label

func _button(text: String) -> Button:
    var button := Button.new(); button.text = text; button.focus_mode = Control.FOCUS_NONE; button.clip_text = true; button.custom_minimum_size = Vector2(0, 46); panel.add_child(button); return button

func _layout() -> void:
    if get_viewport() == null or panel == null: return
    var viewport: Vector2 = get_viewport().size
    var margin := 12.0 if viewport.x < 390.0 else 16.0
    var width := minf(560.0, maxf(280.0, viewport.x - margin * 2.0))
    var height := minf(620.0, maxf(380.0, viewport.y - 96.0))
    dimmer.position = Vector2.ZERO; dimmer.size = viewport
    panel.position = Vector2((viewport.x - width) / 2.0, maxf(48.0, (viewport.y - height) / 2.0)); panel.size = Vector2(width, minf(height, viewport.y - panel.position.y - 12.0))
    var compact := width < 390.0; var side := 14.0
    title_label.position = Vector2(side, 12); title_label.size = Vector2(width - 140.0, 28); title_label.add_theme_font_size_override("font_size", 18 if compact else 20)
    status_label.position = Vector2(width - 112.0, 14); status_label.size = Vector2(98.0, 20); status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    scroll.position = Vector2(side, 48); scroll.size = Vector2(width - side * 2.0, maxf(110.0, panel.size.y - 300.0))
    detail_label.position = Vector2(side, panel.size.y - 238.0); detail_label.size = Vector2(width - side * 2.0, 70.0); detail_label.add_theme_font_size_override("font_size", 10 if compact else 11)
    var y := panel.size.y - 164.0; var gap := 7.0; var action_width := maxf(72.0, (width - side * 2.0 - gap * 2.0) / 3.0)
    next_button.position = Vector2(side, y); next_button.size = Vector2(action_width, 46); sell_button.position = Vector2(side + action_width + gap, y); sell_button.size = Vector2(action_width, 46); lease_button.position = Vector2(side + (action_width + gap) * 2.0, y); lease_button.size = Vector2(action_width, 46)
    for button in [next_button, sell_button, lease_button]: button.add_theme_font_size_override("font_size", 9 if compact else 11)
    close_button.position = Vector2(side, panel.size.y - 56.0); close_button.size = Vector2(width - side * 2.0, 46)

func _catalog() -> Array:
    var state = _state(); if state == null: return []
    var raw: Variant = state.get_value("properties", "catalog", []); return raw if raw is Array else []

func _refresh(_force: bool) -> void:
    var state = _state(); if state == null: return
    var catalog := _catalog(); var owned := bool(state.get_value("properties", "owned", false)); var selected := int(state.get_value("properties", "selected_property", 0))
    status_label.text = "%d ASSET%s" % [catalog.size(), "" if catalog.size() == 1 else "S"]
    var rows: Array = []
    for i in range(catalog.size()):
        if not (catalog[i] is Dictionary): continue
        var entry: Dictionary = catalog[i]; var marker := "›" if i == selected else " "
        var state_text := "AVAILABLE"
        if owned and i == selected: state_text = str(state.get_value("properties", "stage", "Neglected")).to_upper()
        var lease := ""
        if int(entry.get("lease_until", 0)) > int(state.get_value("player", "day", 1)): lease = " • LEASED"
        rows.append("%s %s  ·  %s  ·  $%s%s" % [marker, str(entry.get("name", "?")), state_text, _money(int(entry.get("value", 0))), lease])
    list_label.text = "\n".join(rows) if not rows.is_empty() else "No properties surveyed.\n\nYour property register is currently empty."
    list_label.custom_minimum_size.y = maxf(180.0, float(maxi(1, rows.size())) * 28.0)
    if selected >= 0 and selected < catalog.size() and catalog[selected] is Dictionary:
        var entry: Dictionary = catalog[selected]; detail_label.text = "%s  •  %s\nCondition %d%%  •  Capacity %d" % [str(entry.get("name", "?")), str(entry.get("type", "?")), int(entry.get("condition", 0)), int(entry.get("capacity", 0))]
    else: detail_label.text = "Select an asset to inspect its condition and capacity."

func _next() -> void:
    var catalog := _catalog(); if catalog.is_empty(): return
    var state = _state(); if state == null: return
    state.set_value("properties", "selected_property", (int(state.get_value("properties", "selected_property", 0)) + 1) % catalog.size()); _refresh(true)

func _sell() -> void:
    var game = _game(); if game != null and game.has_method("sell_property"): game.sell_property()
func _lease() -> void:
    var game = _game(); if game != null and game.has_method("lease_property"): game.lease_property()
func _close() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager"); if manager != null and manager.has_method("hide_all_screens"): manager.hide_all_screens()
func _money(amount: int) -> String:
    if amount >= 1000000: return "%.2fM" % (float(amount) / 1000000.0)
    if amount >= 1000: return "%.1fK" % (float(amount) / 1000.0)
    return str(amount)
