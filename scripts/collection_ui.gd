extends CanvasLayer

## Player-facing restoration / collection surface.
## Presentation only: all collection state and rewards come from the authoritative system.
var system
var main
var panel: PanelContainer
var summary: Label
var content: VBoxContainer
var filter_scroll: ScrollContainer
var selected_type: Variant = "all"
var close_button: Button
var count_label: Label
var empty_label: Label

const TYPES := ["all", "historic_properties", "rare_machinery", "landmark_businesses", "unique_technologies", "special_contracts", "famous_employees", "world_event_artifacts"]
const BG := Color("071319")
const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56b")

func _ready() -> void:
    layer = 61
    system = get_node_or_null("/root/RenewCollectionSystem")
    main = get_tree().current_scene
    _build_ui()
    _set_visible(false)
    if get_viewport() != null and not get_viewport().size_changed.is_connected(_layout_responsive):
        get_viewport().size_changed.connect(_layout_responsive)
    call_deferred("_layout_responsive")

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_C:
            _set_visible(not panel.visible)
            if panel.visible:
                _refresh()
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_ESCAPE and panel.visible:
            _set_visible(false)
            get_viewport().set_input_as_handled()

func _build_ui() -> void:
    panel = PanelContainer.new()
    panel.name = "RestorationCollectionPanel"
    panel.add_theme_stylebox_override("panel", _style(SURFACE, BORDER, 14))
    add_child(panel)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 10)
    panel.add_child(root)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 10)
    root.add_child(header)

    var title_box := VBoxContainer.new()
    title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title_box)

    var title := Label.new()
    title.text = "RESTORATION ARCHIVE"
    title.add_theme_font_size_override("font_size", 22)
    title.add_theme_color_override("font_color", TEXT)
    title_box.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Recovered assets, heritage properties and strategic restoration rewards"
    subtitle.add_theme_font_size_override("font_size", 10)
    subtitle.add_theme_color_override("font_color", MUTED)
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title_box.add_child(subtitle)

    count_label = Label.new()
    count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    count_label.add_theme_font_size_override("font_size", 11)
    count_label.add_theme_color_override("font_color", ACCENT)
    header.add_child(count_label)

    close_button = Button.new()
    close_button.text = "CLOSE"
    close_button.custom_minimum_size = Vector2(76, 44)
    close_button.focus_mode = Control.FOCUS_NONE
    close_button.pressed.connect(func(): _set_visible(false))
    header.add_child(close_button)

    summary = Label.new()
    summary.add_theme_font_size_override("font_size", 11)
    summary.add_theme_color_override("font_color", MUTED)
    summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(summary)

    filter_scroll = ScrollContainer.new()
    filter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    filter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    filter_scroll.custom_minimum_size.y = 48
    root.add_child(filter_scroll)

    var filters := HBoxContainer.new()
    filters.name = "Filters"
    filters.add_theme_constant_override("separation", 6)
    filter_scroll.add_child(filters)
    for type in TYPES:
        var b := Button.new()
        b.text = "ALL" if type == "all" else type.replace("_", " ").to_upper()
        b.custom_minimum_size = Vector2(110 if type == "all" else 150, 44)
        b.focus_mode = Control.FOCUS_NONE
        b.pressed.connect(_select.bind(type))
        filters.add_child(b)

    var divider := HSeparator.new()
    divider.add_theme_constant_override("separation", 0)
    root.add_child(divider)

    var scroll := ScrollContainer.new()
    scroll.name = "ArchiveScroll"
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    root.add_child(scroll)

    content = VBoxContainer.new()
    content.add_theme_constant_override("separation", 8)
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(content)

func _set_visible(value: bool) -> void:
    if is_instance_valid(panel):
        panel.visible = value
        if value:
            _layout_responsive()

func _select(type: String) -> void:
    selected_type = type
    _refresh()

func _refresh() -> void:
    if system == null or content == null:
        return
    var status: Dictionary = system.get_status()
    var bonuses: Dictionary = status.get("bonuses", {})
    var total := int(status.get("total", 0))
    var value := int(status.get("value", 0))
    summary.text = "COLLECTION VALUE  $%s    •    ITEMS  %d    •    ACTIVE REWARDS  %s" % [_money(value), total, _bonus_text(bonuses)]
    count_label.text = "%d ITEMS" % total

    for child in content.get_children():
        child.queue_free()

    var items: Array = system.get_all() if selected_type == "all" else system.list_collection(selected_type)
    if items.is_empty():
        empty_label = Label.new()
        empty_label.text = "NO RECOVERED ASSETS\n\nThis archive category is empty. Continue the restoration loop to unlock new historical assets, machinery, businesses and strategic rewards."
        empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        empty_label.add_theme_font_size_override("font_size", 13)
        empty_label.add_theme_color_override("font_color", MUTED)
        empty_label.custom_minimum_size.y = 180
        content.add_child(empty_label)
        return

    for item in items:
        content.add_child(_make_item_card(item))

func _make_item_card(item: Dictionary) -> Control:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(0, 104)
    card.add_theme_stylebox_override("panel", _style(SURFACE_2, BORDER, 10))

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    card.add_child(row)

    var accent := ColorRect.new()
    accent.custom_minimum_size = Vector2(4, 76)
    accent.color = ACCENT
    row.add_child(accent)

    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.add_theme_constant_override("separation", 4)
    row.add_child(box)

    var head := Label.new()
    head.text = str(item.get("title", "Recovered Asset"))
    head.add_theme_font_size_override("font_size", 15)
    head.add_theme_color_override("font_color", TEXT)
    head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    box.add_child(head)

    var meta := Label.new()
    meta.text = "%s    •    RECOVERED DAY %d" % [str(item.get("type", "")).replace("_", " ").to_upper(), int(item.get("day", 1))]
    meta.add_theme_font_size_override("font_size", 9)
    meta.add_theme_color_override("font_color", MUTED)
    box.add_child(meta)

    var details: Dictionary = item.get("details", {})
    var reward: Dictionary = item.get("reward", {})
    var detail := Label.new()
    detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail.text = "%s\nREWARD  %s" % [_dict_text(details), _dict_text(reward)]
    detail.add_theme_font_size_override("font_size", 10)
    detail.add_theme_color_override("font_color", MUTED)
    box.add_child(detail)

    return card

func _layout_responsive() -> void:
    if panel == null:
        return
    var viewport := get_viewport().get_visible_rect().size
    var w := maxf(320.0, viewport.x)
    var h := maxf(480.0, viewport.y)
    var mobile := w < 760.0
    if mobile:
        panel.position = Vector2(8, 8)
        panel.size = Vector2(w - 16, h - 16)
    else:
        panel.position = Vector2(70, 40)
        panel.size = Vector2(minf(1120, w - 140), minf(720, h - 80))

func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    return style

func _bonus_text(bonuses: Dictionary) -> String:
    var parts: Array[String] = []
    for key in bonuses.keys():
        parts.append("%s %s" % [str(key).replace("_", " "), _format_bonus(bonuses[key])])
    return ", ".join(parts) if not parts.is_empty() else "NONE"

func _format_bonus(value) -> String:
    var number: Variant = float(value)
    return "+%.0f%%" % (number * 100.0) if abs(number) < 1.0 else "+%d" % int(number)

func _dict_text(data: Dictionary) -> String:
    var parts: Array[String] = []
    for key in data.keys():
        parts.append("%s: %s" % [str(key).replace("_", " ").capitalize(), str(data[key])])
    return " • ".join(parts) if not parts.is_empty() else "No additional details"

func _money(value: int) -> String:
    return "%,d" % value
