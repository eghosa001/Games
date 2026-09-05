extends CanvasLayer

## Responsive RENEW DAILY reader. News data remains authoritative in RenewNewsSystem.
const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56e")

var panel: PanelContainer
var issue_label: Label
var archive_label: Label
var content: VBoxContainer
var scroll: ScrollContainer
var open: bool = false
var refresh_clock := 0.0

func _ready() -> void:
    layer = 70
    _build()
    _layout()
    close_screen()
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_D:
            if open: close_screen()
            else: open_screen()
            get_viewport().set_input_as_handled()
        elif event.keycode == KEY_ESCAPE and open:
            close_screen()
            get_viewport().set_input_as_handled()

func open_screen() -> void:
    open = true
    if is_instance_valid(panel): panel.visible = true
    _refresh()
func close_screen() -> void:
    open = false
    if is_instance_valid(panel): panel.visible = false
func toggle() -> void:
    if open: close_screen()
    else: open_screen()
func _news(): return get_node_or_null("/root/RenewNewsSystem")

func _style(bg: Color, border: Color = BORDER, radius := 14) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg; s.border_color = border; s.set_border_width_all(1); s.set_corner_radius_all(radius)
    s.content_margin_left = 12; s.content_margin_right = 12; s.content_margin_top = 10; s.content_margin_bottom = 10
    return s

func _build() -> void:
    panel = PanelContainer.new()
    panel.name = "RenewDaily"
    panel.add_theme_stylebox_override("panel", _style(SURFACE))
    add_child(panel)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 16); margin.add_theme_constant_override("margin_right", 16)
    margin.add_theme_constant_override("margin_top", 14); margin.add_theme_constant_override("margin_bottom", 14)
    panel.add_child(margin)
    var root := VBoxContainer.new(); root.add_theme_constant_override("separation", 9); margin.add_child(root)
    var header := HBoxContainer.new(); header.add_theme_constant_override("separation", 8); root.add_child(header)
    issue_label = Label.new(); issue_label.text = "RENEW DAILY"; issue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    issue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; issue_label.add_theme_font_size_override("font_size", 21); issue_label.add_theme_color_override("font_color", TEXT); header.add_child(issue_label)
    var close := Button.new(); close.text = "CLOSE"; close.custom_minimum_size = Vector2(84, 46); close.focus_mode = Control.FOCUS_NONE; close.pressed.connect(close_screen); header.add_child(close)
    archive_label = Label.new(); archive_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; archive_label.add_theme_font_size_override("font_size", 11); archive_label.add_theme_color_override("font_color", MUTED); root.add_child(archive_label)
    scroll = ScrollContainer.new(); scroll.name = "NewsScroll"; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; root.add_child(scroll)
    content = VBoxContainer.new(); content.name = "NewsContent"; content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation", 9); scroll.add_child(content)

func _process(delta: float) -> void:
    if not open: return
    refresh_clock += delta
    if refresh_clock >= 1.0:
        refresh_clock = 0.0
        _refresh()

func _refresh() -> void:
    var news = _news()
    if news == null:
        issue_label.text = "RENEW DAILY — unavailable"; archive_label.text = "News service unavailable."; return
    var issue: Dictionary = news.get_current_issue()
    issue_label.text = "RENEW DAILY  •  %s" % str(issue.get("date_label", "Today's Edition"))
    archive_label.text = "Verified business intelligence  •  %d archived editions  •  D / Esc" % news.get_archive(999999).size()
    for child in content.get_children(): child.queue_free()
    var stories: Array = issue.get("stories", [])
    if stories.is_empty():
        var empty := Label.new(); empty.text = "The newsroom has no verified developments yet."; empty.add_theme_color_override("font_color", MUTED); content.add_child(empty); return
    var current_section := ""
    for story in stories:
        var section := str(story.get("section", "Your Company"))
        if section != current_section:
            current_section = section
            var section_label := Label.new(); section_label.text = section.to_upper(); section_label.add_theme_font_size_override("font_size", 11); section_label.add_theme_color_override("font_color", ACCENT); content.add_child(section_label)
        var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", _style(SURFACE_2)); content.add_child(card)
        var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 4); card.add_child(box)
        var kicker := Label.new(); kicker.text = str(story.get("kicker", "News desk")).to_upper(); kicker.add_theme_font_size_override("font_size", 10); kicker.add_theme_color_override("font_color", MUTED); box.add_child(kicker)
        var headline := Label.new(); headline.text = str(story.get("headline", "Verified development")); headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; headline.add_theme_font_size_override("font_size", 16); headline.add_theme_color_override("font_color", TEXT); box.add_child(headline)
        var body := Label.new(); body.text = str(story.get("body", "")); body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.add_theme_font_size_override("font_size", 12); body.add_theme_color_override("font_color", TEXT); box.add_child(body)
    _layout()

func _layout() -> void:
    if panel == null: return
    var size := get_viewport().get_visible_rect().size
    var narrow := size.x < 760.0
    var width := maxf(304.0, size.x - 16.0) if narrow else minf(700.0, size.x - 36.0)
    var height := maxf(400.0, size.y - 86.0) if narrow else minf(680.0, size.y - 100.0)
    panel.position = Vector2(8, 70) if narrow else Vector2(maxf(18.0, (size.x - width) * 0.5), 80)
    panel.size = Vector2(width, height)

