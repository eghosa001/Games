extends CanvasLayer

## Executive identity and standing surface. IdentitySystem and GlobalRankingSystem remain authoritative.
const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const SURFACE_3 := Color("132f38")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56e")
const GREEN := Color("68d391")

var panel: Panel
var title_label: Label
var summary_label: Label
var power_label: Label
var close_button: Button
var scroll: ScrollContainer
var content: VBoxContainer
var refresh_clock := 0.0

func _ready() -> void:
    layer = 76
    _build()
    _layout()
    visible = false
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)

func _process(delta: float) -> void:
    if not visible or panel == null: return
    refresh_clock += delta
    if refresh_clock >= 1.0:
        refresh_clock = 0.0
        _refresh()

func _game() -> Node:
    return get_tree().root.get_node_or_null("Renew")

func _style(bg: Color, border: Color = BORDER, radius := 10) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg; s.border_color = border; s.set_border_width_all(1); s.set_corner_radius_all(radius)
    return s

func _label(text: String, size: int, color: Color) -> Label:
    var l := Label.new(); l.text = text; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", color)
    return l

func _button(text: String, callback: Callable) -> Button:
    var b := Button.new(); b.text = text; b.custom_minimum_size = Vector2(88, 46); b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", 10); b.add_theme_color_override("font_color", TEXT)
    b.add_theme_stylebox_override("normal", _style(SURFACE_2)); b.add_theme_stylebox_override("hover", _style(SURFACE_3, ACCENT)); b.add_theme_stylebox_override("pressed", _style(SURFACE_3, ACCENT))
    b.pressed.connect(callback); return b

func _build() -> void:
    panel = Panel.new(); panel.name = "EmpireIdentitySurface"; panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.add_theme_stylebox_override("panel", _style(SURFACE, BORDER, 14)); add_child(panel)
    title_label = _label("COMPANY IDENTITY & STANDING", 20, TEXT); panel.add_child(title_label)
    summary_label = _label("IDENTITY • LIVE", 10, ACCENT); panel.add_child(summary_label)
    power_label = _label("WORLD POWER", 11, MUTED); panel.add_child(power_label)
    close_button = _button("CLOSE", _close); panel.add_child(close_button)
    scroll = ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
    content = VBoxContainer.new(); content.add_theme_constant_override("separation", 9); scroll.add_child(content)

func _card(heading: String, body: String, tint: Color = TEXT) -> void:
    var card := Panel.new(); card.custom_minimum_size.y = 84; card.add_theme_stylebox_override("panel", _style(SURFACE_3)); content.add_child(card)
    var h := _label(heading, 12, ACCENT); h.position = Vector2(12, 9); h.size = Vector2(520, 22); card.add_child(h)
    var b := _label(body, 11, tint); b.position = Vector2(12, 33); b.size = Vector2(520, 46); card.add_child(b)

func _refresh() -> void:
    var g := _game(); if g == null: return
    for child in content.get_children(): child.queue_free()
    var identity := get_node_or_null("/root/RenewIdentitySystem")
    var ranking := get_node_or_null("/root/RenewGlobalRankingSystem")
    var name := str(g.get("company_name")) if "company_name" in g else "RENEW COMPANY"
    if name == "<null>" or name.is_empty(): name = "RENEW COMPANY"
    var day := int(g.get("day")) if "day" in g else 0
    var rep := int(g.get("reputation")) if "reputation" in g else 0
    summary_label.text = "%s  •  DAY %d  •  REP %d" % [name, day, rep]
    if ranking != null and ranking.has_method("world_power"):
        var power: Dictionary = ranking.world_power()
        power_label.text = "WORLD POWER  %.0f / 100   •   ECON %.0f   TECH %.0f   LOG %.0f   DIP %.0f" % [float(power.get("total", 0.0)), float(power.get("economic", 0.0)), float(power.get("technology", 0.0)), float(power.get("logistics", 0.0)), float(power.get("diplomatic", 0.0))]
        _card("WORLD STANDING", "Overall power %.0f/100\nEconomic %.0f  •  Resource %.0f  •  Industrial %.0f  •  Technology %.0f" % [float(power.get("total", 0.0)), float(power.get("economic", 0.0)), float(power.get("resource", 0.0)), float(power.get("industrial", 0.0)), float(power.get("technology", 0.0))])
        _card("INFLUENCE PROFILE", "Logistics %.0f  •  Diplomatic %.0f  •  Alliance %.0f  •  Cultural %.0f" % [float(power.get("logistics", 0.0)), float(power.get("diplomatic", 0.0)), float(power.get("alliance", 0.0)), float(power.get("cultural", 0.0))])
    else:
        power_label.text = "WORLD POWER • UNAVAILABLE"
    if identity != null and identity.has_method("progress"):
        var rows: Array = identity.progress()
        var completed := 0
        for row in rows:
            completed += int(row.get("claimed", 0))
        _card("IDENTITY PORTFOLIO", "%d identity tiers achieved across %d strategic paths.\nReach new tiers to unlock cash and reputation rewards." % [completed, rows.size()])
        for row in rows:
            var reached := int(row.get("claimed", 0)); var total := int(row.get("total", 0)); var next = row.get("next", null)
            var state := "COMPLETE" if reached >= total else "IN PROGRESS"
            var next_text := "All tiers achieved." if next == null else "Next threshold: %s" % _format_value(float(next))
            _card("%s  •  %s  •  %d/%d" % [str(row.get("title", "Identity")), state, reached, total], "%s\n%s" % [_identity_description(str(row.get("id", ""))), next_text], GREEN if state == "COMPLETE" else TEXT)
    else:
        _card("IDENTITY SERVICE", "Identity progression is not currently available.", MUTED)
    var message := str(g.get("message")) if "message" in g else "No current company notice."
    if message.is_empty(): message = "No current company notice."
    _card("LATEST COMPANY NOTICE", message)

func _identity_description(id: String) -> String:
    var descriptions := {"builder":"Restoration and property mastery.","tycoon":"Valuation and financial scale.","industrialist":"Business creation and operating scale.","diplomat":"Alliance building and international relationships.","innovator":"Technology research and advancement.","collector":"Asset acquisition and portfolio breadth.","magnate":"Control across multiple industries.","competitor":"Takeovers, ownership and competitive control."}
    return str(descriptions.get(id, "Strategic company identity."))

func _format_value(value: float) -> String:
    if value >= 1000000.0: return "%.1fM" % (value / 1000000.0)
    if value >= 1000.0: return "%.1fK" % (value / 1000.0)
    return "%.0f" % value

func _close() -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"): manager.hide_all_screens()
    else: visible = false

func _layout() -> void:
    if panel == null: return
    var size := get_viewport().get_visible_rect().size; var narrow := size.x < 760.0
    var width := maxf(304.0, size.x - 16.0) if narrow else minf(660.0, size.x - 36.0)
    var height := maxf(430.0, size.y - 90.0) if narrow else minf(720.0, size.y - 110.0)
    panel.position = Vector2(8, 70) if narrow else Vector2(maxf(18.0, (size.x - width) * 0.5), 82)
    panel.size = Vector2(width, height)
    title_label.position = Vector2(14, 10); title_label.size = Vector2(width - 130, 30)
    summary_label.position = Vector2(14, 40); summary_label.size = Vector2(width - 28, 20)
    power_label.position = Vector2(14, 61); power_label.size = Vector2(width - 28, 36)
    close_button.position = Vector2(width - 94, 7); close_button.size = Vector2(86, 46)
    scroll.position = Vector2(12, 100); scroll.size = Vector2(width - 24, height - 108); content.custom_minimum_size.x = width - 24
    for child in content.get_children():
        child.custom_minimum_size.y = 94 if narrow else 86
        for sub in child.get_children():
            if sub is Label: sub.size.x = width - 48
