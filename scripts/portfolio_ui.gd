extends CanvasLayer

## Property portfolio command surface. The portfolio is a playable restoration
## register: every catalog property exposes its own inspection, ownership,
## restoration progress, lease state and disposition actions.
var dimmer: ColorRect
var panel: Panel
var title_label: Label
var status_label: Label
var scroll: ScrollContainer
var list_label: Label
var detail_label: Label
var next_button: Button
var action_button: Button
var sell_button: Button
var lease_button: Button
var close_button: Button
var refresh_clock := 0.0

const SURFACE := Color("0d1917")
const SURFACE_2 := Color("10251f")
const BORDER := Color("1e3934")
const TEXT := Color("effbf7")
const MUTED := Color("8fa7a1")
const ACCENT := Color("5eead4")
const WARN := Color("fbbf24")
const SCRIM := Color(0.01, 0.04, 0.04, 0.78)
const STEPS := ["cleaning", "repair", "painting", "furnishing"]

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
    if refresh_clock >= 0.5:
        refresh_clock = 0.0
        _refresh(false)

func _state():
    return get_node_or_null("/root/RenewGameState")

func _game():
    return get_tree().current_scene if get_tree() != null else null

func _property_system():
    var game = _game()
    if game != null:
        var commands = game.get_node_or_null("GameplayCommandSystem")
        if commands != null:
            return commands.get("property_system")
    return null

func _build_ui() -> void:
    dimmer = ColorRect.new()
    dimmer.name = "PortfolioModalScrim"
    dimmer.color = SCRIM
    dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dimmer)

    panel = Panel.new()
    panel.name = "PortfolioPanel"
    var style := StyleBoxFlat.new()
    style.bg_color = SURFACE
    style.border_color = BORDER
    style.set_border_width_all(1)
    style.set_corner_radius_all(18)
    style.shadow_color = Color(0, 0, 0, 0.34)
    style.shadow_size = 8
    style.shadow_offset = Vector2(0, 4)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)

    title_label = _label("RESTORATION PORTFOLIO", 20, TEXT)
    status_label = _label("0 / 9 RESTORED", 10, ACCENT)
    scroll = ScrollContainer.new()
    scroll.name = "PortfolioAssetScroll"
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    panel.add_child(scroll)
    list_label = _label("", 12, TEXT)
    list_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list_label.custom_minimum_size = Vector2(0, 180)
    panel.remove_child(list_label)
    scroll.add_child(list_label)
    detail_label = _label("", 11, MUTED)

    next_button = _button("NEXT PROPERTY")
    next_button.pressed.connect(_next)
    action_button = _button("INSPECT")
    action_button.pressed.connect(_primary_action)
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
    label.clip_text = true
    label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    panel.add_child(label)
    return label

func _button(text: String) -> Button:
    var button := Button.new()
    button.text = text
    button.focus_mode = Control.FOCUS_NONE
    button.clip_text = true
    button.custom_minimum_size = Vector2(44, 46)
    var normal := StyleBoxFlat.new()
    normal.bg_color = SURFACE_2
    normal.border_color = BORDER
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(12)
    var hover := normal.duplicate()
    hover.bg_color = Color("16342d")
    hover.border_color = ACCENT
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    button.add_theme_color_override("font_color", TEXT)
    button.add_theme_color_override("font_hover_color", TEXT)
    panel.add_child(button)
    return button

func _layout() -> void:
    if get_viewport() == null or panel == null:
        return
    var viewport: Vector2 = get_viewport().size
    var margin := 12.0 if viewport.x < 390.0 else 16.0
    var width := minf(620.0, maxf(240.0, viewport.x - margin * 2.0))
    width = minf(width, maxf(1.0, viewport.x - margin * 2.0))
    var height := minf(660.0, maxf(320.0, viewport.y - 24.0))
    height = minf(height, maxf(1.0, viewport.y - 24.0))
    dimmer.position = Vector2.ZERO
    dimmer.size = viewport
    panel.position = Vector2((viewport.x - width) / 2.0, maxf(36.0, (viewport.y - height) / 2.0))
    panel.size = Vector2(width, minf(height, viewport.y - panel.position.y - 10.0))
    panel.clip_contents = true
    var compact := width < 420.0
    var phone := viewport.x < 430.0
    var side := 14.0
    title_label.position = Vector2(side, 14)
    title_label.size = Vector2(width - (28.0 if phone else 170.0), 28)
    title_label.add_theme_font_size_override("font_size", 18 if compact else 20)
    status_label.position = Vector2(side if phone else width - 160.0, 48 if phone else 17)
    status_label.size = Vector2(width - side * 2.0 if phone else 144.0, 20)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if phone else HORIZONTAL_ALIGNMENT_RIGHT
    status_label.add_theme_font_size_override("font_size", 9 if phone else 10)

    var controls_height := 184.0 if compact else 132.0
    scroll.position = Vector2(side, 76 if phone else 52)
    scroll.size = Vector2(width - side * 2.0, maxf(120.0, panel.size.y - controls_height - (150.0 if phone else 126.0)))
    detail_label.position = Vector2(side, scroll.position.y + scroll.size.y + 10.0)
    detail_label.size = Vector2(width - side * 2.0, 64.0)
    detail_label.add_theme_font_size_override("font_size", 10 if compact else 11)

    var gap := 7.0
    if compact:
        var half := (width - side * 2.0 - gap) / 2.0
        var row_one_y := panel.size.y - 162.0
        var row_two_y := panel.size.y - 109.0
        next_button.position = Vector2(side, row_one_y)
        next_button.size = Vector2(half, 46)
        action_button.position = Vector2(side + half + gap, row_one_y)
        action_button.size = Vector2(half, 46)
        lease_button.position = Vector2(side, row_two_y)
        lease_button.size = Vector2(half, 46)
        sell_button.position = Vector2(side + half + gap, row_two_y)
        sell_button.size = Vector2(half, 46)
    else:
        var y := panel.size.y - 109.0
        var action_width := (width - side * 2.0 - gap * 3.0) / 4.0
        next_button.position = Vector2(side, y)
        next_button.size = Vector2(action_width, 46)
        action_button.position = Vector2(side + (action_width + gap), y)
        action_button.size = Vector2(action_width, 46)
        lease_button.position = Vector2(side + (action_width + gap) * 2.0, y)
        lease_button.size = Vector2(action_width, 46)
        sell_button.position = Vector2(side + (action_width + gap) * 3.0, y)
        sell_button.size = Vector2(action_width, 46)
    for button in [next_button, action_button, sell_button, lease_button]:
        button.add_theme_font_size_override("font_size", 9 if compact else 10)
    close_button.position = Vector2(side, panel.size.y - 56.0)
    close_button.size = Vector2(width - side * 2.0, 46)

func _catalog() -> Array:
    var state = _state()
    if state == null:
        return []
    var raw: Variant = state.get_value("properties", "catalog", [])
    return raw if raw is Array else []

func _restoration_percent(entry: Dictionary) -> int:
    var sum := 0
    for step in STEPS:
        sum += int(entry.get(step, 0))
    return int(round(float(sum) / float(STEPS.size())))

func _is_restored(entry: Dictionary) -> bool:
    return _restoration_percent(entry) >= 100

func _state_text(entry: Dictionary) -> String:
    if not bool(entry.get("inspected", false)):
        return "UNSURVEYED"
    if not bool(entry.get("owned", false)):
        return "AVAILABLE"
    var progress := _restoration_percent(entry)
    if progress >= 100:
        return "RESTORED"
    if progress >= 75:
        return "FURNISHING"
    if progress >= 50:
        return "PAINTING"
    if progress >= 25:
        return "REPAIRING"
    return "CLEANING"

func _refresh(_force: bool) -> void:
    var state = _state()
    if state == null:
        return
    var catalog := _catalog()
    var selected := clampi(int(state.get_value("properties", "selected_property", 0)), 0, maxi(0, catalog.size() - 1))
    var owned_count := 0
    var restored_count := 0
    var inspected_count := 0
    var rows: Array = []
    var day := int(state.get_value("player", "day", 1))

    for i in range(catalog.size()):
        if not (catalog[i] is Dictionary):
            continue
        var entry: Dictionary = catalog[i]
        if bool(entry.get("owned", false)):
            owned_count += 1
        if bool(entry.get("inspected", false)):
            inspected_count += 1
        if bool(entry.get("owned", false)) and _is_restored(entry):
            restored_count += 1
        var marker := "▶" if i == selected else " "
        var lease := " • LEASED" if int(entry.get("lease_until", 0)) > day else ""
        var progress := _restoration_percent(entry)
        var progress_text := " • %d%%" % progress if bool(entry.get("owned", false)) else ""
        rows.append("%s %s\n   %s • %s%s%s" % [marker, str(entry.get("name", "?")), str(entry.get("type", "?")), _state_text(entry), progress_text, lease])

    status_label.text = "%d/%d RESTORED" % [restored_count, catalog.size()]
    list_label.text = "\n\n".join(rows) if not rows.is_empty() else "No properties surveyed."
    list_label.custom_minimum_size.y = maxf(200.0, float(maxi(1, rows.size())) * 54.0)

    if selected >= 0 and selected < catalog.size() and catalog[selected] is Dictionary:
        var entry: Dictionary = catalog[selected]
        var progress := _restoration_percent(entry)
        detail_label.text = "%s • %s\nCondition %d%% • Capacity %d • Restoration %d%%\nPortfolio: %d owned • %d inspected • %d restored" % [str(entry.get("name", "?")), str(entry.get("type", "?")), int(entry.get("condition", 0)), int(entry.get("capacity", 0)), progress, owned_count, inspected_count, restored_count]
        _configure_actions(entry)
    else:
        detail_label.text = "Select an asset to inspect its condition and restoration potential."
        action_button.disabled = true
        sell_button.disabled = true
        lease_button.disabled = true

func _configure_actions(entry: Dictionary) -> void:
    var inspected := bool(entry.get("inspected", false))
    var owned := bool(entry.get("owned", false))
    var restored := _is_restored(entry)
    action_button.disabled = false
    if not inspected:
        action_button.text = "INSPECT"
    elif not owned:
        action_button.text = "ACQUIRE"
    elif not restored:
        action_button.text = "RESTORE"
    else:
        action_button.text = "RESTORED"
        action_button.disabled = true
    sell_button.disabled = not owned
    lease_button.disabled = not owned

func _next() -> void:
    var catalog := _catalog()
    if catalog.is_empty():
        return
    var state = _state()
    if state == null:
        return
    var next_index := (int(state.get_value("properties", "selected_property", 0)) + 1) % catalog.size()
    var property_system = _property_system()
    if property_system != null and property_system.has_method("select_property"):
        property_system.select_property(str(catalog[next_index].get("id", "")))
    else:
        state.set_value("properties", "selected_property", next_index)
    _refresh(true)

func _primary_action() -> void:
    var game = _game()
    if game == null:
        return
    var catalog := _catalog()
    var state = _state()
    if state == null or catalog.is_empty():
        return
    var selected := clampi(int(state.get_value("properties", "selected_property", 0)), 0, catalog.size() - 1)
    var entry: Dictionary = catalog[selected]
    if not bool(entry.get("inspected", false)) and game.has_method("inspect_property"):
        game.inspect_property()
    elif not bool(entry.get("owned", false)) and game.has_method("acquire_property"):
        game.acquire_property()
    elif not _is_restored(entry) and game.has_method("restore_property"):
        game.restore_property()
    _refresh(true)

func _sell() -> void:
    var game = _game()
    if game != null and game.has_method("sell_property"):
        game.sell_property()
    _refresh(true)

func _lease() -> void:
    var game = _game()
    if game != null and game.has_method("lease_property"):
        game.lease_property()
    _refresh(true)

func _close() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"):
        manager.hide_all_screens()

func _money(amount: int) -> String:
    if amount >= 1000000:
        return "%.2fM" % (float(amount) / 1000000.0)
    if amount >= 1000:
        return "%.1fK" % (float(amount) / 1000.0)
    return str(amount)
