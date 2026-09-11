extends CanvasLayer

## Responsive corporate museum and legacy gallery. Opens with Y or the History screen.
const RuntimeResolver = preload("res://scripts/runtime_dependency_resolver.gd")
const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d7b86f")
const SCRIM := Color(0.02, 0.08, 0.10, 0.76)

var dimmer: ColorRect
var panel: PanelContainer
var summary_label: Label
var content: VBoxContainer
var tabs: HBoxContainer
var tabs_scroll: ScrollContainer
var close_button: Button
var active_tab: String = "museum"
var visible_archive := false

const TABS := {"museum":"Museum Gallery", "timeline":"Timeline", "people":"Historic People", "business":"Business History", "innovation":"Technology", "legacy":"Legacy"}

func _ready() -> void:
    layer = 100
    _build_ui()
    _set_visible(false)
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)
    _layout()

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
    _set_visible(true); _refresh(); close_button.grab_focus()
func close_screen() -> void:
    _set_visible(false)
func _set_visible(value: bool) -> void:
    visible_archive = value
    if is_instance_valid(dimmer): dimmer.visible = value
    if is_instance_valid(panel): panel.visible = value

func _style(bg: Color, border: Color = BORDER, radius := 12) -> StyleBoxFlat:
    var s := StyleBoxFlat.new(); s.bg_color = bg; s.border_color = border; s.set_border_width_all(1); s.set_corner_radius_all(radius); return s
func _button_style(active := false) -> StyleBoxFlat:
    return _style(ACCENT if active else SURFACE_2, ACCENT if active else BORDER, 8)

func _build_ui() -> void:
    dimmer = ColorRect.new(); dimmer.name = "HistoryModalScrim"; dimmer.color = SCRIM; dimmer.mouse_filter = Control.MOUSE_FILTER_STOP; add_child(dimmer)
    panel = PanelContainer.new(); panel.name = "CorporateMuseum"; panel.add_theme_stylebox_override("panel", _style(SURFACE)); add_child(panel)
    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 14)
    panel.add_child(margin)
    var root := VBoxContainer.new(); root.add_theme_constant_override("separation", 9); margin.add_child(root)
    var header := HBoxContainer.new(); root.add_child(header)
    var title := Label.new(); title.text = "RENEW CORPORATE MUSEUM"; title.add_theme_font_size_override("font_size", 21); title.add_theme_color_override("font_color", TEXT); header.add_child(title)
    var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(spacer)
    close_button = Button.new(); close_button.name = "CloseButton"; close_button.text = "CLOSE"; close_button.custom_minimum_size = Vector2(78, 46); close_button.focus_mode = Control.FOCUS_NONE; close_button.add_theme_font_size_override("font_size", 10); close_button.pressed.connect(close_screen); header.add_child(close_button)
    var status := Label.new(); status.text = "CORPORATE MEMORY  •  HISTORY & LEGACY"; status.add_theme_font_size_override("font_size", 9); status.add_theme_color_override("font_color", ACCENT); root.add_child(status)
    summary_label = Label.new(); summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; summary_label.add_theme_font_size_override("font_size", 11); summary_label.add_theme_color_override("font_color", MUTED); root.add_child(summary_label)
    tabs_scroll = ScrollContainer.new(); tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; tabs_scroll.custom_minimum_size.y = 48; root.add_child(tabs_scroll)
    tabs = HBoxContainer.new(); tabs.add_theme_constant_override("separation", 7); tabs_scroll.add_child(tabs)
    for id in TABS.keys(): _add_tab(id, TABS[id])
    var scroll := ScrollContainer.new(); scroll.name = "HistoryContentScroll"; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(scroll)
    content = VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation", 9); scroll.add_child(content)

func _add_tab(id: String, label_text: String) -> void:
    var button := Button.new(); button.name = "Tab_%s" % id; button.text = label_text; button.custom_minimum_size = Vector2(112, 44); button.focus_mode = Control.FOCUS_NONE; button.pressed.connect(_select_tab.bind(id)); tabs.add_child(button); _style_tab(button, id == active_tab)
func _style_tab(button: Button, active: bool) -> void:
    button.add_theme_stylebox_override("normal", _button_style(active)); button.add_theme_stylebox_override("hover", _button_style(true)); button.add_theme_stylebox_override("pressed", _button_style(true)); button.add_theme_color_override("font_color", SURFACE if active else TEXT); button.add_theme_color_override("font_hover_color", SURFACE); button.add_theme_font_size_override("font_size", 10)
func _select_tab(id: String) -> void:
    active_tab = id
    for child in tabs.get_children():
        if child is Button: _style_tab(child, child.name == "Tab_%s" % id)
    _refresh()

func _legacy(): return RuntimeResolver.resolve("RenewCorporateLegacy", "Systems/RenewCorporateLegacy")
func _hq(): return RuntimeResolver.resolve("RenewHeadquartersSystem", "Systems/RenewHeadquartersSystem")

func _refresh() -> void:
    var legacy = _legacy()
    if legacy == null:
        summary_label.text = "Corporate Museum system unavailable."
        for child in content.get_children(): child.queue_free()
        _empty("History records cannot be displayed until the corporate memory system is available.")
        return
    var s: Dictionary = legacy.summary(); var hq = _hq(); var hq_text := "HQ: unavailable"
    if hq != null: hq_text = "HQ: %s" % hq.get_stage()
    var museum_state := "MUSEUM ACTIVE" if (hq != null and hq.museum_available()) else "MUSEUM LOCKED"
    summary_label.text = "%s  •  %s  •  %d preserved artifacts\nYour decisions, people, victories and failures are permanently recorded here." % [hq_text, museum_state, int(s.get("total", 0))]
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
    var found := false
    for category in ["founding", "products", "employees", "contracts", "acquisitions", "failures", "awards", "rankings", "technologies", "alliances", "crisis_recoveries"]:
        var items: Array = legacy.list_category(category)
        if items.is_empty(): continue
        found = true; _section(_category_title(category)); _render_items(items, "")
    if not found: _empty("No museum artifacts yet. Major decisions will be preserved here as your company grows.")

func _render_business(legacy) -> void:
    var found := false
    for category in ["founding", "products", "contracts", "acquisitions", "failures", "alliances", "crisis_recoveries"]:
        var items: Array = legacy.list_category(category)
        if items.is_empty(): continue
        found = true; _section(_category_title(category)); _render_items(items, "")
    if not found: _empty("No business-history records yet.")

func _render_items(items: Array, heading_text: String) -> void:
    if heading_text != "": _section(heading_text)
    if items.is_empty(): _empty("No records yet. Major decisions will be preserved here."); return
    for item in items:
        var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", _style(SURFACE_2)); card.custom_minimum_size = Vector2(0, 82); content.add_child(card)
        var margin := MarginContainer.new()
        for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 10)
        card.add_child(margin)
        var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 3); margin.add_child(box)
        var top := Label.new(); top.text = "DAY %d  •  %s" % [int(item.get("day", 1)), _category_title(str(item.get("category", "general")))]; top.add_theme_font_size_override("font_size", 9); top.add_theme_color_override("font_color", ACCENT); box.add_child(top)
        var title := Label.new(); title.text = str(item.get("title", "Historic artifact")); title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; title.add_theme_font_size_override("font_size", 15); title.add_theme_color_override("font_color", TEXT); box.add_child(title)
        var details: Dictionary = item.get("details", {})
        if not details.is_empty():
            var detail := Label.new(); detail.text = _details(details); detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; detail.add_theme_font_size_override("font_size", 10); detail.add_theme_color_override("font_color", MUTED); box.add_child(detail)

func _render_legacy(s: Dictionary) -> void:
    _section("THE RENEW LEGACY")
    var text := Label.new(); text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; text.add_theme_font_size_override("font_size", 14); text.add_theme_color_override("font_color", TEXT)
    text.text = "A company is remembered for what it built, who built it, the risks it took, the crises it survived and the partnerships it created.\n\nArtifacts: %d\nEmployees remembered: %d\nContracts: %d\nAcquisitions / mergers: %d\nFailed projects: %d\nAwards: %d\nRankings: %d\nTechnologies: %d\nAlliance milestones: %d\nCrisis recoveries: %d" % [int(s.get("total",0)), int(s.get("employees",0)), int(s.get("contracts",0)), int(s.get("acquisitions",0)), int(s.get("failures",0)), int(s.get("awards",0)), int(s.get("rankings",0)), int(s.get("technologies",0)), int(s.get("alliances",0)), int(s.get("crisis_recoveries",0))]
    content.add_child(text)
func _section(text: String) -> void:
    var heading := Label.new(); heading.text = text.to_upper(); heading.add_theme_font_size_override("font_size", 13); heading.add_theme_color_override("font_color", ACCENT); content.add_child(heading)
func _empty(text: String) -> void:
    var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", _style(SURFACE_2)); card.custom_minimum_size = Vector2(0, 88); content.add_child(card)
    var label := Label.new(); label.text = text; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size", 11); label.add_theme_color_override("font_color", MUTED); card.add_child(label)
func _category_title(category: String) -> String: return category.replace("_", " ").capitalize()
func _details(details: Dictionary) -> String:
    var parts: Array[String] = []
    for key in details.keys(): parts.append("%s: %s" % [str(key).replace("_", " ").capitalize(), str(details[key])])
    return "  •  ".join(parts)

func _layout() -> void:
    if not is_instance_valid(panel) or get_viewport() == null: return
    var size := get_viewport().get_visible_rect().size; var phone := size.x < 430.0; var margin := 8.0 if phone else 14.0; var w := minf(720.0, maxf(280.0, size.x - margin * 2.0)); var top := 36.0 if phone else 46.0; var h := minf(720.0, maxf(360.0, size.y - top - 10.0))
    dimmer.position = Vector2.ZERO; dimmer.size = size; panel.position = Vector2((size.x - w) / 2.0, top); panel.size = Vector2(w, minf(h, size.y - top - 10.0))
    var compact := w < 420.0
    if close_button != null: close_button.custom_minimum_size = Vector2(72 if compact else 82, 46)
    if summary_label != null: summary_label.add_theme_font_size_override("font_size", 10 if compact else 11)
    for child in tabs.get_children():
        if child is Button: child.custom_minimum_size = Vector2(108 if compact else 118, 44)
