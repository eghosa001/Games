extends CanvasLayer

## Responsive live-operations surface. World events remain authoritative in LiveOpsSystem.
const RuntimeResolver = preload("res://scripts/runtime_dependency_resolver.gd")
const SURFACE := Color("0b1630")
const SURFACE_2 := Color("14254d")
const BORDER := Color("5367af")
const TEXT := Color("f7f9ff")
const MUTED := Color("adbbe0")
const ACCENT := Color("f2c65c")
const SUCCESS := Color("62d69a")
const WARNING := Color("e9c56b")
const DANGER := Color("ef7676")
const ICON_ROOT := "res://Assets/Art/Icons/"
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
    close_screen()
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)

func _build_ui() -> void:
    panel = Panel.new(); panel.name = "LiveOpsPanel"; panel.add_theme_stylebox_override("panel", _style(SURFACE, BORDER, 20)); add_child(panel)
    title_label = Label.new(); title_label.text = "LIVE OPERATIONS"; title_label.add_theme_font_size_override("font_size", 20); title_label.add_theme_color_override("font_color", TEXT); panel.add_child(title_label)
    season_label = Label.new(); season_label.add_theme_font_size_override("font_size", 11); season_label.add_theme_color_override("font_color", MUTED); panel.add_child(season_label)
    close_button = Button.new(); close_button.text = "CLOSE"; close_button.custom_minimum_size = Vector2(84, 46); close_button.focus_mode = Control.FOCUS_NONE; close_button.mouse_filter = Control.MOUSE_FILTER_STOP; close_button.pressed.connect(_close); panel.add_child(close_button)
    scroll = ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; panel.add_child(scroll)
    content = VBoxContainer.new(); content.add_theme_constant_override("separation", 10); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(content)

func _style(bg: Color, border: Color, radius := 12) -> StyleBoxFlat:
    var s := StyleBoxFlat.new(); s.bg_color = bg; s.border_color = border; s.set_border_width_all(1); s.set_border_width(SIDE_TOP, 2); s.set_corner_radius_all(radius); s.content_margin_left = 14; s.content_margin_right = 14; s.content_margin_top = 12; s.content_margin_bottom = 12; s.shadow_color = Color(0, 0, 0, 0.36); s.shadow_size = 10; s.shadow_offset = Vector2(0, 4); return s

func _icon(key: String) -> Texture2D:
    var path := ICON_ROOT + key + ".svg"
    return load(path) as Texture2D if ResourceLoader.exists(path) else null

func _make_icon(key: String, size := 30) -> TextureRect:
    var icon := TextureRect.new()
    icon.texture = _icon(key)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.custom_minimum_size = Vector2(size, size)
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return icon

func _progress_style(bg: Color, fill: Color) -> Array[StyleBoxFlat]:
    var track := StyleBoxFlat.new()
    track.bg_color = bg
    track.set_corner_radius_all(6)
    var value := StyleBoxFlat.new()
    value.bg_color = fill
    value.set_corner_radius_all(6)
    value.shadow_color = Color(fill.r, fill.g, fill.b, 0.22)
    value.shadow_size = 5
    return [track, value]

func _process(delta: float) -> void:
    if panel == null or not panel.visible: return
    refresh_clock += delta
    if refresh_clock >= 1.0:
        refresh_clock = 0.0
        _refresh(false)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and panel != null and panel.visible:
        _close()

func open_screen() -> void:
    if panel != null: panel.visible = true
    _refresh(true)

func close_screen() -> void:
    if panel != null: panel.visible = false
    refresh_clock = 0.0

func _refresh(force: bool = false) -> void:
    var system = RuntimeResolver.resolve("RenewLiveOpsSystem", "Systems/RenewLiveOpsSystem")
    if system == null:
        season_label.text = "EVENT SERVICE UNAVAILABLE"
        _clear_content()
        _add_message("Live operations are temporarily unavailable.", DANGER)
        return
    var state: Dictionary = system.get_state(); var offers: Dictionary = state.get("offers", {}); var challenges: Dictionary = state.get("challenges", {}); var goal: Dictionary = state.get("community_goal", {})
    var signature := "%s|%s|%s|%s" % [str(state.get("season", 1)), str(offers), str(challenges), str(goal)]
    if not force and signature == last_signature: return
    last_signature = signature
    season_label.text = "SEASON %d   •   LIVE WORLD PROGRAMME" % int(state.get("season", 1))
    var scroll_value := scroll.scroll_vertical
    _clear_content(); _add_section("ROTATING OPPORTUNITIES", ACCENT)
    if offers.is_empty(): _add_message("No rotating offers are active.", MUTED)
    else:
        for item in offers.values(): _add_card(str(item.get("title", "Opportunity")), "Expires Day %d" % int(item.get("expires_day", 0)), ACCENT)
    _add_section("CHALLENGES", ACCENT)
    if challenges.is_empty(): _add_message("No active challenges.", MUTED)
    else:
        for challenge in challenges.values():
            var progress := float(challenge.get("progress", 0)); var target := maxf(1.0, float(challenge.get("target", 1))); var pct := clampf(progress / target, 0.0, 1.0)
            _add_progress_card(str(challenge.get("title", "Challenge")), progress, target, pct, int(challenge.get("expires_day", 0)))
    _add_section("COMMUNITY GOAL", ACCENT)
    var goal_progress := float(goal.get("progress", 0)); var goal_target := maxf(1.0, float(goal.get("target", 0)))
    _add_progress_card(str(goal.get("title", "Community Goal")), goal_progress, goal_target, clampf(goal_progress / goal_target, 0.0, 1.0), -1)
    _add_message("Seasonal events and world crises are governed by the authoritative world-event systems.", MUTED)
    _layout(); scroll.set_deferred("scroll_vertical", scroll_value)

func _clear_content() -> void:
    if content == null: return
    for child in content.get_children(): child.queue_free()

func _add_section(text: String, tint: Color) -> void:
    var label := Label.new(); label.text = text; label.add_theme_font_size_override("font_size", 11); label.add_theme_color_override("font_color", tint); content.add_child(label)

func _add_message(text: String, tint: Color) -> void:
    var label := Label.new(); label.text = text; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; label.add_theme_font_size_override("font_size", 11); label.add_theme_color_override("font_color", tint); content.add_child(label)

func _add_card(title: String, meta: String, tint: Color) -> void:
    var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", _style(SURFACE_2, Color(BORDER.r, BORDER.g, BORDER.b, 0.72), 14)); card.custom_minimum_size = Vector2(0, 82); content.add_child(card)
    var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); card.add_child(row)
    row.add_child(_make_icon("opportunities", 34))
    var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation", 4); row.add_child(box)
    var heading := Label.new(); heading.text = title; heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; heading.add_theme_font_size_override("font_size", 14); heading.add_theme_color_override("font_color", TEXT); box.add_child(heading)
    var detail := Label.new(); detail.text = meta; detail.add_theme_font_size_override("font_size", 10); detail.add_theme_color_override("font_color", tint); box.add_child(detail)

func _add_progress_card(title: String, progress: float, target: float, pct: float, expiry: int) -> void:
    var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", _style(SURFACE_2, Color(BORDER.r, BORDER.g, BORDER.b, 0.72), 14)); card.custom_minimum_size = Vector2(0, 104); content.add_child(card)
    var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); card.add_child(row)
    row.add_child(_make_icon("intelligence", 34))
    var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation", 5); row.add_child(box)
    var heading := Label.new(); heading.text = title; heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; heading.add_theme_font_size_override("font_size", 14); heading.add_theme_color_override("font_color", TEXT); box.add_child(heading)
    var progress_label := Label.new(); progress_label.text = "%.0f / %.0f   •   %d%%" % [progress, target, roundi(pct * 100.0)]; progress_label.add_theme_font_size_override("font_size", 10); progress_label.add_theme_color_override("font_color", SUCCESS if pct >= 1.0 else (WARNING if pct >= 0.7 else MUTED)); box.add_child(progress_label)
    var bar := ProgressBar.new(); bar.min_value = 0.0; bar.max_value = 1.0; bar.value = pct; bar.show_percentage = false; bar.custom_minimum_size = Vector2(0, 9)
    var styles := _progress_style(Color(MUTED.r, MUTED.g, MUTED.b, 0.14), SUCCESS if pct >= 1.0 else ACCENT)
    bar.add_theme_stylebox_override("background", styles[0])
    bar.add_theme_stylebox_override("fill", styles[1])
    box.add_child(bar)
    if expiry >= 0:
        var expiry_label := Label.new(); expiry_label.text = "Expires Day %d" % expiry; expiry_label.add_theme_font_size_override("font_size", 9); expiry_label.add_theme_color_override("font_color", MUTED); box.add_child(expiry_label)

func _close() -> void:
    close_screen()
    var manager = RuntimeResolver.resolve("RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"): manager.hide_all_screens()
    if get_viewport() != null: get_viewport().set_input_as_handled()

func _layout() -> void:
    if panel == null: return
    var size := get_viewport().get_visible_rect().size; var narrow := size.x < 760.0
    var width := maxf(304.0, size.x - 16.0) if narrow else minf(520.0, size.x - 36.0); var height := maxf(400.0, size.y - 86.0) if narrow else minf(600.0, size.y - 110.0)
    panel.position = Vector2(8, 70) if narrow else Vector2(maxf(18.0, size.x - width - 18.0), 88); panel.size = Vector2(width, height)
    title_label.position = Vector2(14, 9); title_label.size = Vector2(width - 112, 30)
    season_label.position = Vector2(14, 38); season_label.size = Vector2(width - 112, 24)
    close_button.position = Vector2(width - 96, 7); close_button.size = Vector2(84, 46)
    scroll.position = Vector2(12, 68); scroll.size = Vector2(width - 24, height - 80); content.custom_minimum_size = Vector2(width - 48, 0)
