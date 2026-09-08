extends CanvasLayer

## Executive notification center. NewsSystem remains authoritative for notification state.
const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56e")
var panel: PanelContainer
var summary_label: Label
var content: VBoxContainer
var scroll: ScrollContainer
var open := false

func _ready() -> void:
    layer = 75
    _build(); _layout(); close_screen()
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and open:
        close_screen(); get_viewport().set_input_as_handled()
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
    var s := StyleBoxFlat.new(); s.bg_color = bg; s.border_color = border; s.set_border_width_all(1); s.set_corner_radius_all(radius)
    s.content_margin_left = 12; s.content_margin_right = 12; s.content_margin_top = 10; s.content_margin_bottom = 10; return s
func _build() -> void:
    panel = PanelContainer.new(); panel.name = "NotificationsCenterPanel"; panel.add_theme_stylebox_override("panel", _style(SURFACE)); add_child(panel)
    var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left", 16); margin.add_theme_constant_override("margin_right", 16); margin.add_theme_constant_override("margin_top", 14); margin.add_theme_constant_override("margin_bottom", 14); panel.add_child(margin)
    var root := VBoxContainer.new(); root.add_theme_constant_override("separation", 9); margin.add_child(root)
    var header := HBoxContainer.new(); header.add_theme_constant_override("separation", 8); root.add_child(header)
    var title := Label.new(); title.text = "NOTIFICATION CENTER"; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title.add_theme_font_size_override("font_size", 21); title.add_theme_color_override("font_color", TEXT); header.add_child(title)
    var close := Button.new(); close.text = "CLOSE"; close.custom_minimum_size = Vector2(84, 46); close.focus_mode = Control.FOCUS_NONE; close.pressed.connect(close_screen); header.add_child(close)
    summary_label = Label.new(); summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; summary_label.add_theme_font_size_override("font_size", 11); summary_label.add_theme_color_override("font_color", MUTED); root.add_child(summary_label)
    var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation", 8); root.add_child(actions)
    var refresh := Button.new(); refresh.text = "REFRESH"; refresh.custom_minimum_size = Vector2(110, 46); refresh.pressed.connect(_refresh); actions.add_child(refresh)
    var mark := Button.new(); mark.text = "MARK READ"; mark.custom_minimum_size = Vector2(120, 46); mark.pressed.connect(_mark_read); actions.add_child(mark)
    var daily := Button.new(); daily.text = "DAILY"; daily.custom_minimum_size = Vector2(100, 46); daily.pressed.connect(_open_daily); actions.add_child(daily)
    scroll = ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(scroll)
    content = VBoxContainer.new(); content.add_theme_constant_override("separation", 9); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(content)
func _refresh() -> void:
    var news = _news()
    for child in content.get_children(): child.queue_free()
    if news == null: summary_label.text = "Notification service unavailable."; return
    var unread: Dictionary = news.unread_notifications() if news.has_method("unread_notifications") else {"unread":0,"sections":{}}
    var count := int(unread.get("unread", 0)); var sections: Dictionary = unread.get("sections", {})
    summary_label.text = "%d unread notification%s  •  %d active sections  •  verified intelligence" % [count, "" if count == 1 else "s", sections.size()]
    _card("ATTENTION REQUIRED" if count > 0 else "ALL CLEAR", "You have %d unread developments across the corporate network." % count if count > 0 else "No unread notifications. Continue monitoring the daily intelligence feed.", ACCENT if count > 0 else MUTED)
    var archive: Array = news.get_archive(12) if news.has_method("get_archive") else []
    var heading := Label.new(); heading.text = "RECENT VERIFIED DEVELOPMENTS"; heading.add_theme_font_size_override("font_size", 11); heading.add_theme_color_override("font_color", ACCENT); content.add_child(heading)
    for issue in archive:
        var day := int(issue.get("day", 0)); var stories: Array = issue.get("stories", [])
        var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", _style(SURFACE_2)); content.add_child(card)
        var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 5); card.add_child(box)
        var day_label := Label.new(); day_label.text = "DAY %d  •  %d VERIFIED ITEMS" % [day, stories.size()]; day_label.add_theme_font_size_override("font_size", 11); day_label.add_theme_color_override("font_color", ACCENT); box.add_child(day_label)
        for story in stories.slice(0, 4):
            var line := Label.new(); line.text = "• %s" % str(story.get("headline", "Development")); line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; line.add_theme_font_size_override("font_size", 12); line.add_theme_color_override("font_color", TEXT); box.add_child(line)
func _card(kicker: String, body: String, tint: Color) -> void:
    var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", _style(SURFACE_2)); content.add_child(card)
    var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 5); card.add_child(box)
    var k := Label.new(); k.text = kicker; k.add_theme_font_size_override("font_size", 11); k.add_theme_color_override("font_color", tint); box.add_child(k)
    var b := Label.new(); b.text = body; b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; b.add_theme_font_size_override("font_size", 13); b.add_theme_color_override("font_color", TEXT); box.add_child(b)
func _mark_read() -> void:
    var news = _news(); if news != null and news.has_method("read_notifications"): news.read_notifications()
    var game = get_tree().current_scene; if game != null and game.has_method("check_notifications"): game.check_notifications()
    _refresh()
func _open_daily() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager"); if manager != null and manager.has_method("show_screen"): manager.show_screen("NewsPanel")
func _layout() -> void:
    if panel == null: return
    var size := get_viewport().get_visible_rect().size; var narrow := size.x < 760.0
    var width := maxf(304.0, size.x - 16.0) if narrow else minf(720.0, size.x - 36.0)
    var height := maxf(420.0, size.y - 86.0) if narrow else minf(700.0, size.y - 100.0)
    panel.position = Vector2(8, 70) if narrow else Vector2(maxf(18.0, (size.x - width) * 0.5), 80); panel.size = Vector2(width, height)
