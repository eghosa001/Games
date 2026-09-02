extends CanvasLayer

## In-game corporate archives / museum UI for RENEW.
## Opens with Y and exposes the permanent HistorySystem as a readable timeline.

var panel: PanelContainer
var summary_label: Label
var content: VBoxContainer
var tabs: HBoxContainer
var active_tab := "timeline"
var visible_archive := false

func _ready() -> void:
    layer = 60
    _build_ui()
    _set_visible(false)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_Y:
            toggle_archive()
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_ESCAPE and visible_archive:
            toggle_archive()
            get_viewport().set_input_as_handled()

func toggle_archive() -> void:
    _set_visible(not visible_archive)
    if visible_archive:
        _refresh()

func _set_visible(value: bool) -> void:
    visible_archive = value
    if is_instance_valid(panel):
        panel.visible = value

func _build_ui() -> void:
    panel = PanelContainer.new()
    panel.name = "CorporateArchives"
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.position = Vector2(140, 70)
    panel.size = Vector2(1000, 580)
    panel.custom_minimum_size = Vector2(1000, 580)
    add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 24)
    margin.add_theme_constant_override("margin_right", 24)
    margin.add_theme_constant_override("margin_top", 20)
    margin.add_theme_constant_override("margin_bottom", 20)
    panel.add_child(margin)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 12)
    margin.add_child(root)

    var header := HBoxContainer.new()
    root.add_child(header)
    var title := Label.new()
    title.text = "RENEW CORPORATE ARCHIVES"
    title.add_theme_font_size_override("font_size", 26)
    header.add_child(title)
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(spacer)
    var close := Button.new()
    close.text = "Close  [Esc]"
    close.pressed.connect(toggle_archive)
    header.add_child(close)

    summary_label = Label.new()
    summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    root.add_child(summary_label)

    tabs = HBoxContainer.new()
    root.add_child(tabs)
    _add_tab("timeline", "Corporate Timeline")
    _add_tab("notable", "Historic Events")
    _add_tab("museum", "Museum Collection")
    _add_tab("legacy", "Company Legacy")

    var scroll := ScrollContainer.new()
    scroll.name = "ArchiveScroll"
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(scroll)

    content = VBoxContainer.new()
    content.name = "ArchiveContent"
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 8)
    scroll.add_child(content)

func _add_tab(id: String, label_text: String) -> void:
    var button := Button.new()
    button.text = label_text
    button.toggle_mode = true
    button.button_pressed = id == active_tab
    button.pressed.connect(_select_tab.bind(id))
    tabs.add_child(button)

func _select_tab(id: String) -> void:
    active_tab = id
    for child in tabs.get_children():
        if child is Button:
            child.button_pressed = child.text == _tab_label(id)
    _refresh()

func _tab_label(id: String) -> String:
    match id:
        "timeline": return "Corporate Timeline"
        "notable": return "Historic Events"
        "museum": return "Museum Collection"
        "legacy": return "Company Legacy"
    return ""

func _history():
    return get_node_or_null("/root/RenewHistorySystem")

func _refresh() -> void:
    var history = _history()
    if history == null:
        summary_label.text = "Corporate archives are unavailable."
        return
    var summary: Dictionary = history.get_legacy_summary()
    summary_label.text = "Founded Day %d  •  %d historic records  •  %d museum pieces  •  %d years recorded\nPress Y to close the archives." % [int(summary.get("founded_day", 1)), int(summary.get("timeline_length", 0)), int(summary.get("museum_items", 0)), int(summary.get("years_recorded", 1))]

    for child in content.get_children():
        child.queue_free()

    match active_tab:
        "timeline": _render_events(history.get_chronological_timeline(), false)
        "notable": _render_events(history.get_notable_events(100), false)
        "museum": _render_events(history.get_museum_collection(), true)
        "legacy": _render_legacy(summary)

func _render_events(events: Array, museum_mode: bool) -> void:
    if events.is_empty():
        var empty := Label.new()
        empty.text = "No historic records yet. Your next major decision will become part of the company's story."
        empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        content.add_child(empty)
        return

    for event in events:
        var card := PanelContainer.new()
        card.custom_minimum_size = Vector2(0, 86 if museum_mode else 72)
        content.add_child(card)
        var box := VBoxContainer.new()
        box.add_theme_constant_override("separation", 3)
        card.add_child(box)

        var heading := Label.new()
        var day := int(event.get("day", 1))
        var event_type := str(event.get("type", "general")).replace("_", " ").capitalize()
        var era := str(event.get("era", ""))
        heading.text = ("Day %d  •  %s  •  %s" % [day, event_type, era]) if museum_mode else ("Day %d  •  %s" % [day, event_type])
        heading.add_theme_font_size_override("font_size", 15)
        box.add_child(heading)

        var title := Label.new()
        title.text = str(event.get("title", "Historic event"))
        title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        box.add_child(title)

        var details: Dictionary = event.get("details", {})
        if not details.is_empty():
            var detail := Label.new()
            detail.text = _details_text(details)
            detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            detail.modulate = Color(0.75, 0.75, 0.75)
            box.add_child(detail)

func _render_legacy(summary: Dictionary) -> void:
    var rows := [
        ["Company", str(summary.get("company_name", "RENEW"))],
        ["Founder", str(summary.get("founder", "Founder"))],
        ["Founded", "Day %d" % int(summary.get("founded_day", 1))],
        ["Historic records", str(summary.get("timeline_length", 0))],
        ["Properties acquired", str(summary.get("properties_acquired", 0))],
        ["Expansions", str(summary.get("expansions", 0))],
        ["Strategic alliances", str(summary.get("alliances", 0))],
        ["Acquisitions / mergers", str(summary.get("acquisitions", 0))],
        ["Contracts", str(summary.get("contracts", 0))],
        ["Crises", str(summary.get("crises", 0))],
        ["Employee milestones", str(summary.get("employees_milestones", 0))]
    ]
    for row in rows:
        var line := HBoxContainer.new()
        line.custom_minimum_size = Vector2(0, 34)
        content.add_child(line)
        var key := Label.new()
        key.text = str(row[0])
        key.custom_minimum_size = Vector2(300, 0)
        line.add_child(key)
        var value := Label.new()
        value.text = str(row[1])
        value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        line.add_child(value)

    var note := Label.new()
    note.text = "LEGACY\nEvery major acquisition, alliance, crisis, breakthrough and employee milestone becomes part of RENEW's permanent corporate memory."
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.add_theme_font_size_override("font_size", 16)
    content.add_child(note)

func _details_text(details: Dictionary) -> String:
    var parts: Array[String] = []
    for key in details.keys():
        if key == "source_log": continue
        parts.append("%s: %s" % [str(key).replace("_", " ").capitalize(), str(details[key])])
    return "  •  ".join(parts)
