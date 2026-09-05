extends CanvasLayer

## Responsive technology command surface. Reads GameState and routes research through Main.
const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56e")
var panel: Panel
var title_label: Label
var summary_label: Label
var scroll: ScrollContainer
var list: VBoxContainer
var close_button: Button
var refresh_clock := 0.0

func _ready() -> void:
    layer = 100
    _build_ui(); _layout(); _refresh()
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)
func _process(delta: float) -> void:
    refresh_clock += delta
    if refresh_clock >= 0.75:
        refresh_clock = 0.0; _refresh()
func _style(bg: Color, border: Color = BORDER, radius := 12) -> StyleBoxFlat:
    var s := StyleBoxFlat.new(); s.bg_color = bg; s.border_color = border; s.set_border_width_all(1); s.set_corner_radius_all(radius); return s
func _build_ui() -> void:
    panel = Panel.new(); panel.name = "TechnologyCommandPanel"; panel.add_theme_stylebox_override("panel", _style(SURFACE)); add_child(panel)
    title_label = Label.new(); title_label.text = "TECHNOLOGY COUNCIL"; title_label.add_theme_font_size_override("font_size", 21); title_label.add_theme_color_override("font_color", TEXT); panel.add_child(title_label)
    close_button = Button.new(); close_button.text = "CLOSE"; close_button.custom_minimum_size = Vector2(72,44); close_button.focus_mode = Control.FOCUS_NONE; close_button.pressed.connect(_close); panel.add_child(close_button)
    summary_label = Label.new(); summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; summary_label.add_theme_font_size_override("font_size", 11); summary_label.add_theme_color_override("font_color", MUTED); panel.add_child(summary_label)
    scroll = ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; panel.add_child(scroll)
    list = VBoxContainer.new(); list.add_theme_constant_override("separation", 8); scroll.add_child(list)
func _refresh() -> void:
    var state := get_node_or_null("/root/RenewGameState"); var tech := get_node_or_null("/root/RenewTechnologySystem")
    if panel == null or state == null or tech == null: return
    var rp := int(state.get_value("technology", "research_points", 20)); var cash := int(state.get_value("economy", "cash", 25000))
    summary_label.text = "RESEARCH %d RP   •   CASH $%s\nTap RESEARCH on a READY technology. All research is routed through the authoritative command system." % [rp, "%,d" % cash]
    for child in list.get_children(): child.queue_free()
    for item in tech.get_technologies():
        var id := str(item.id); var unlocked := bool(tech.is_unlocked(id)); var can := tech.can_research(id) as Dictionary
        var status := "RESEARCHED" if unlocked else ("READY" if bool(can.get("ok", false)) else "LOCKED")
        var card := Panel.new(); card.custom_minimum_size = Vector2(0, 94); card.add_theme_stylebox_override("panel", _style(SURFACE_2)); list.add_child(card)
        var name := Label.new(); name.text = str(item.name); name.position = Vector2(12,8); name.add_theme_font_size_override("font_size",15); name.add_theme_color_override("font_color", TEXT); card.add_child(name)
        var meta := Label.new(); meta.text = "Tier %d  •  $%d  •  %d RP  •  %d day%s  •  %s" % [int(item.tier), int(item.cost_money), int(item.cost_points), int(item.time_days), "" if int(item.time_days) == 1 else "s", status]; meta.position = Vector2(12,36); meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; meta.add_theme_font_size_override("font_size",10); meta.add_theme_color_override("font_color", Color("70d58a") if unlocked else MUTED); card.add_child(meta)
        var button := Button.new(); button.text = "DONE" if unlocked else "RESEARCH"; button.disabled = unlocked or not bool(can.get("ok", false)); button.custom_minimum_size = Vector2(92,44); button.focus_mode = Control.FOCUS_NONE; button.pressed.connect(_research.bind(id)); card.add_child(button)
    _layout()
func _research(id: String) -> void:
    var main := get_tree().current_scene
    if main != null and main.has_method("research_technology"): main.research_technology(id)
    _refresh()
func _close() -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"): manager.hide_all_screens()
    else: visible = false
func _layout() -> void:
    if panel == null: return
    var size := get_viewport().get_visible_rect().size; var narrow := size.x < 760.0
    var w := maxf(304.0, size.x - 16.0) if narrow else minf(560.0, size.x - 36.0); var h := maxf(430.0, size.y - 82.0) if narrow else minf(660.0, size.y - 100.0)
    panel.position = Vector2(8,70) if narrow else Vector2(size.x - w - 18.0, 80); panel.size = Vector2(w,h)
    title_label.position = Vector2(14,10); title_label.size = Vector2(w - 100,30); close_button.position = Vector2(w - 84,7); close_button.size = Vector2(72,44)
    summary_label.position = Vector2(14,48); summary_label.size = Vector2(w - 28,48); scroll.position = Vector2(12,100); scroll.size = Vector2(w - 24,h - 112); list.custom_minimum_size.x = w - 24
    for card in list.get_children():
        if card is Panel:
            var name := card.get_child(0) as Label; var meta := card.get_child(1) as Label; var button := card.get_child(2) as Button
            if name != null: name.position = Vector2(12,8); name.size = Vector2(maxf(110,w-132),24)
            if meta != null: meta.position = Vector2(12,36); meta.size = Vector2(maxf(110,w-132),48)
            if button != null: button.position = Vector2(w-120,25); button.size = Vector2(96,44)
