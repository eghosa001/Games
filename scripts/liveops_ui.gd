extends CanvasLayer

## Responsive live-operations surface. World events remain authoritative in LiveOpsSystem.
const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56e")
const SUCCESS := Color("62d69a")
const WARNING := Color("e9c56b")
const DANGER := Color("ef7676")
var panel: Panel
var title_label: Label
var season_label: Label
var close_button: Button
var scroll: ScrollContainer
var content: VBoxContainer
var refresh_clock := 0.0
var last_signature := ""

func _ready() -> void:
    layer = 62
    _build_ui()
    _layout()
    _refresh(true)
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)

func _build_ui() -> void:
    panel = Panel.new()
    panel.name = "LiveOpsPanel"
    panel.add_theme_stylebox_override("panel", _style(SURFACE, BORDER, 14))
    add_child(panel)
    title_label = Label.new()
    title_label.text = "LIVE OPERATIONS"
    title_label.add_theme_font_size_override("font_size", 20)
    title_label.add_theme_color_override("font_color", TEXT)
    panel.add_child(title_label)
    season_label = Label.new()
    season_label.add_theme_font_size_override("font_size", 11)
    season_label.add_theme_color_override("font_color", MUTED)
    panel.add_child(season_label)
    close_button = Button.new()
    close_button.text = "CLOSE"
    close_button.custom_minimum_size = Vector2(84, 46)
    close_button.focus_mode = Control.FOCUS_NONE
    close_button.pressed.connect(_close)
    panel.add_child(close_button)
    scroll = ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    panel.add_child(scroll)
    content = VBoxContainer.new()
    content.add_theme_constant_override("separation", 10)
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(content)

func _style(bg: Color, border: Color, radius := 12) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(1)
    s.set_corner_radius_all(radius)
    s.content_margin_left = 12
    s.content_margin_right = 12
    s.content_margin_top = 10
    s.content_margin_bottom = 10
    return s

func _process(delta: float) -> void:
    if panel == null or not panel.visible: return
    refresh_clock += delta
    if refresh_clock >= 1.0:
        refresh_clock = 0.0
        _refresh(false)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_L:
            panel.visible = not panel.visible
            if panel.visible: _refresh(true)
        elif event.keycode == KEY_ESCAPE and panel.visible:
            _close()

func _refresh(force: bool = false) -> void:
    var system = get_node_or_null("/root/RenewLiveOpsSystem")
    if system == null:
        season_label.text = "EVENT SERVICE UNAVAILABLE"
        _clear_content()
        _add_message("Live operations are temporarily unavailable.", DANGER)
        return
    var state: Dictionary = system.get_state()
    var offers: Dictionary = state.get("offers", {})
    var challenges: Dictionary = state.get("challenges", {})
    var goal: Dictionary = state.get("community_goal", {})
    var signature := "%s|%s|%s|%s" % [str(state.get("season", 1)), str(offers), str(challenges), str(goal)]
    if not force and signature == last_signature: return
    last_signature = signature
    season_label.text = "SEASON %d   •   LIVE WORLD PROGRAMME" % int(state.get("season", 1))
    var scroll_value := scroll.scroll_vertical
    _clear_content()
    _add_section("ROTATING OPPORTUNITIES", ACCENT)
    if offers.is_empty():
        _add_message("No rotating offers are active.", MUTED)
    else:
        for item in offers.values():
            var title := str(item.get("title", "Opportunity"))
            var expiry := int(item.get("expires_day", 0))
            _add_card(title, "Expires Day %d" % expiry, ACCENT)
    _add_section("CHALLENGES", ACCENT)
    if challenges.is_empty():
        _add_message("No active challenges.", MUTED)
    else:
        for challenge in challenges.values():
            var title := str(challenge.get("title", "Challenge"))
            var progress := float(challenge.get("progress", 0))
            var target := maxf(1.0, float(challenge.get("target", 1)))
            var pct := clampf(progress / target, 0.0, 1.0)
            var expiry := int(challenge.get("expires_day", 0))
            _add_progress_card(title, progress, target, pct, expiry)
    _add_section("COMMUNITY GOAL", ACCENT)
    var goal_title := str(goal.get("title", "Community Goal"))
    var goal_progress := float(goal.get("progress", 0))
    var goal_target := maxf(1.0, float(goal.get("target", 0)))
    _add_progress_card(goal_title, goal_progress, goal_target, clampf(goal_progress / goal_target, 0.0, 1.0), -1)
    _add_message("Seasonal events and world crises are governed by the authoritative world-event systems.", MUTED)
    _layout()
    scroll.set_deferred("scroll_vertical", scroll_value)

func _clear_content() -> void:
    if content == null: return
    for child in content.get_children(): child.queue_free()

func _add_section(text: String, tint: Color) -> void:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", 11)
    label.add_theme_color_override("font_color", tint)
    content.add_child(label)

func _add_message(text: String, tint: Color) -> void:
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 11)
    label.add_theme_color_override("font_color", tint)
    content.add_child(label)

func _add_card(title: String, meta: String, tint: Color) -> void:
    var card := PanelContainer.new()
    card.add_theme_stylebox_override("panel", _style(SURFACE_2, BORDER, 10))
    card.custom_minimum_size = Vector2(0, 68)
    content.add_child(card)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 4)
    card.add_child(box)
    var heading := Label.new()
    heading.text = title
    heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    heading.add_theme_font_size_override("font_size", 14)
    heading.add_theme_color_override("font_color", TEXT)
    box.add_child(heading)
    var detail := Label.new()
    detail.text = meta
    detail.add_theme_font_size_override("font_size", 10)
    detail.add_theme_color_override("font_color", tint)
    box.add_child(detail)

func _add_progress_card(title: String, progress: float, target: float, pct: float, expiry: int) -> void:
    var card := PanelContainer.new()
    card.add_theme_stylebox_override("panel", _style(SURFACE_2, BORDER, 10))
    card.custom_minimum_size = Vector2(0, 86)
    content.add_child(card)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 5)
    card.add_child(box)
    var heading := Label.new()
    heading.text = title
    heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    heading.add_theme_font_size_override("font_size", 14)
    heading.add_theme_color_override("font_color", TEXT)
    box.add_child(heading)
    var progress_label := Label.new()
    progress_label.text = "%.0f / %.0f   •   %d%%" % [progress, target, roundi(pct * 100.0)]
    progress_label.add_theme_font_size_override("font_size", 10)
    progress_label.add_theme_color_override("font_color", SUCCESS if pct >= 1.0 else (WARNING if pct >= 0.7 else MUTED))
    box.add_child(progress_label)
    var bar := ProgressBar.new()
    bar.min_value = 0.0
    bar.max_value = 1.0
    bar.value = pct
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(0, 8)
    box.add_child(bar)
    if expiry >= 0:
        var expiry_label := Label.new()
        expiry_label.text = "Expires Day %d" % expiry
        expiry_label.add_theme_font_size_override("font_size", 9)
        expiry_label.add_theme_color_override("font_color", MUTED)
        box.add_child(expiry_label)

func _close() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"):
        manager.hide_all_screens()
    elif panel != null:
        panel.visible = false

func _layout() -> void:
    if panel == null: return
    var size := get_viewport().get_visible_rect().size
    var narrow := size.x < 760.0
    var width := maxf(304.0, size.x - 16.0) if narrow else minf(520.0, size.x - 36.0)
    var height := maxf(400.0, size.y - 86.0) if narrow else minf(600.0, size.y - 110.0)
    panel.position = Vector2(8, 70) if narrow else Vector2(maxf(18.0, size.x - width - 18.0), 88)
    panel.size = Vector2(width, height)
    title_label.position = Vector2(14, 9)
    title_label.size = Vector2(width - 112, 30)
    season_label.position = Vector2(14, 38)
    season_label.size = Vector2(width - 112, 24)
    close_button.position = Vector2(width - 96, 7)
    close_button.size = Vector2(84, 46)
    scroll.position = Vector2(12, 68)
    scroll.size = Vector2(width - 24, height - 80)
    content.custom_minimum_size = Vector2(width - 48, 0)
