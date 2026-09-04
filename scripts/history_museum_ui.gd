extends CanvasLayer

## Visual corporate museum and legacy gallery. Opens with Y or the History screen.
var panel: PanelContainer
var summary_label: Label
var content: VBoxContainer
var tabs: HBoxContainer
var active_tab: Variant = "museum"
var visible_archive: Variant = false

const TABS := {"museum":"Museum Gallery", "timeline":"Timeline", "people":"Historic People", "business":"Business History", "innovation":"Technology", "legacy":"Legacy"}

func _ready() -> void:
    layer = 60
    _build_ui()
    _set_visible(false)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_Y:
            toggle_archive(); get_viewport().set_input_as_handled()
        elif event.keycode == KEY_ESCAPE and visible_archive:
            close_screen(); get_viewport().set_input_as_handled()

func toggle_archive() -> void:
    if visible_archive: close_screen()
    else: open_screen()

func open_screen() -> void:
    _set_visible(true)
    _refresh()

func close_screen() -> void:
    _set_visible(false)

func _set_visible(value: bool) -> void:
    visible_archive = value
    if is_instance_valid(panel): panel.visible = value

func _build_ui() -> void:
    panel = PanelContainer.new(); panel.name = "CorporateMuseum"; panel.position = Vector2(90, 45); panel.size = Vector2(1100, 630); panel.custom_minimum_size = Vector2(1100, 630); add_child(panel)
    var margin: Variant = MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 20)
    panel.add_child(margin)
    var root: Variant = VBoxContainer.new(); root.add_theme_constant_override("separation", 10); margin.add_child(root)
    var header: Variant = HBoxContainer.new(); root.add_child(header)
    var title: Variant = Label.new(); title.text = "RENEW CORPORATE MUSEUM"; title.add_theme_font_size_override("font_size", 28); header.add_child(title)
    var spacer: Variant = Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(spacer)
    var close: Variant = Button.new(); close.text = "Close [Esc]"; close.pressed.connect(close_screen); header.add_child(close)
    summary_label = Label.new(); summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; root.add_child(summary_label)
    tabs = HBoxContainer.new(); root.add_child(tabs)
    for id in TABS.keys(): _add_tab(id, TABS[id])
    var scroll: Variant = ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(scroll)
    content = VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation", 9); scroll.add_child(content)

func _add_tab(id: String, label_text: String) -> void:
    var button: Variant = Button.new(); button.text = label_text; button.toggle_mode = true; button.button_pressed = id == active_tab; button.pressed.connect(_select_tab.bind(id)); tabs.add_child(button)

func _select_tab(id: String) -> void:
    active_tab = id
    for child in tabs.get_children():
        if child is Button: child.button_pressed = child.text == TABS[id]
    _refresh()

func _legacy(): return get_node_or_null("/root/RenewCorporateLegacy")
func _hq(): return get_node_or_null("/root/RenewHeadquartersSystem")

func _refresh() -> void:
    var legacy = _legacy()
    if legacy == null: summary_label.text = "Corporate Museum system unavailable."; return
    var s: Dictionary = legacy.summary(); var hq = _hq(); var hq_text := "HQ: unavailable"
    if hq != null: hq_text = "HQ: %s" % hq.get_stage()
    summary_label.text = "%s  •  %s  •  %d preserved artifacts\nThe museum permanently records the company's decisions, people, victories and failures." % [hq_text, "Museum open" if (hq != null and hq.museum_available()) else "Museum requires Corporate Center", int(s.get("total", 0))]
    for child in content.get_children(): child.queue_free()
    match active_tab:
        "museum": _render_gallery(legacy)
        "timeline": _render_items(legacy.get_collection(), "Corporate Timeline")
        "people": _render_items(legacy.list_category("employees"), "Historic Employees")
        "business": _render_business(legacy)
        "innovation": _render_items(legacy.list_category("technologies"), "Technologies & Discoveries")
        "legacy": _render_legacy(s)

func _render_gallery(legacy) -> void:
    var hq = _hq()
    if hq != null and not hq.museum_available():
        _empty("The Corporate Museum unlocks when the Headquarters reaches Corporate Center and the Museum area is constructed.")
        _render_items(legacy.list_category("founding"), "Founding & Headquarters")
        return
    for category in ["founding", "products", "employees", "contracts", "acquisitions", "failures", "awards", "rankings", "technologies", "alliances", "crisis_recoveries"]:
        var items: Array = legacy.list_category(category)
        if items.is_empty(): continue
        var heading: Variant = Label.new(); heading.text = _category_title(category); heading.add_theme_font_size_override("font_size", 19); content.add_child(heading); _render_items(items, "")

func _render_business(legacy) -> void:
    for category in ["founding", "products", "contracts", "acquisitions", "failures", "alliances", "crisis_recoveries"]:
        var items: Array = legacy.list_category(category)
        if not items.is_empty():
            var heading: Variant = Label.new(); heading.text = _category_title(category); heading.add_theme_font_size_override("font_size", 19); content.add_child(heading); _render_items(items, "")

func _render_items(items: Array, heading_text: String) -> void:
    if heading_text != "":
        var heading: Variant = Label.new(); heading.text = heading_text; heading.add_theme_font_size_override("font_size", 20); content.add_child(heading)
    if items.is_empty(): _empty("No records yet. Major decisions will be preserved here."); return
    for item in items:
        var card: Variant = PanelContainer.new(); card.custom_minimum_size = Vector2(0, 74); content.add_child(card)
        var box: Variant = VBoxContainer.new(); card.add_child(box)
        var top: Variant = Label.new(); top.text = "Day %d  •  %s" % [int(item.get("day", 1)), _category_title(str(item.get("category", "general")))]; top.add_theme_font_size_override("font_size", 14); box.add_child(top)
        var title: Variant = Label.new(); title.text = str(item.get("title", "Historic artifact")); title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; title.add_theme_font_size_override("font_size", 17); box.add_child(title)
        var details: Dictionary = item.get("details", {})
        if not details.is_empty():
            var detail: Variant = Label.new(); detail.text = _details(details); detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(detail)

func _render_legacy(s: Dictionary) -> void:
    var title: Variant = Label.new(); title.text = "THE RENEW LEGACY"; title.add_theme_font_size_override("font_size", 24); content.add_child(title)
    var text: Variant = Label.new(); text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; text.add_theme_font_size_override("font_size", 17)
    text.text = "A company is remembered for what it built, who built it, the risks it took, the crises it survived and the partnerships it created.\n\nArtifacts: %d\nEmployees remembered: %d\nContracts: %d\nAcquisitions / mergers: %d\nFailed projects: %d\nAwards: %d\nRankings: %d\nTechnologies: %d\nAlliance milestones: %d\nCrisis recoveries: %d" % [int(s.get("total",0)), int(s.get("employees",0)), int(s.get("contracts",0)), int(s.get("acquisitions",0)), int(s.get("failures",0)), int(s.get("awards",0)), int(s.get("rankings",0)), int(s.get("technologies",0)), int(s.get("alliances",0)), int(s.get("crisis_recoveries",0))]
    content.add_child(text)

func _empty(text: String) -> void:
    var label: Variant = Label.new(); label.text = text; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; content.add_child(label)

func _category_title(category: String) -> String:
    return category.replace("_", " ").capitalize()

func _details(details: Dictionary) -> String:
    var parts: Array[String] = []
    for key in details.keys(): parts.append("%s: %s" % [str(key).replace("_", " ").capitalize(), str(details[key])])
    return "  •  ".join(parts)
