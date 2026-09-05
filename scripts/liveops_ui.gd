extends CanvasLayer

## Responsive live-operations surface. World events remain authoritative in LiveOpsSystem.
const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56e")

var panel: Panel
var title_label: Label
var close_button: Button
var scroll: ScrollContainer
var label: Label
var refresh_clock := 0.0

func _ready() -> void:
    layer = 62
    _build_ui()
    _layout()
    _refresh()
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
    close_button = Button.new()
    close_button.text = "CLOSE"
    close_button.custom_minimum_size = Vector2(80, 46)
    close_button.focus_mode = Control.FOCUS_NONE
    close_button.pressed.connect(_close)
    panel.add_child(close_button)
    scroll = ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    panel.add_child(scroll)
    label = Label.new()
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", TEXT)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(label)

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
    if not panel.visible: return
    refresh_clock += delta
    if refresh_clock >= 1.0:
        refresh_clock = 0.0
        _refresh()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_L:
        panel.visible = not panel.visible
        if panel.visible: _refresh()

func _refresh() -> void:
    var system = get_node_or_null("/root/RenewLiveOpsSystem")
    if system == null:
        label.text = "LIVE OPERATIONS\n\nSystem unavailable."
        return
    var state: Dictionary = system.get_state()
    var text := "SEASON %d\n\nROTATING CONTENT\n" % int(state.get("season", 1))
    var offers: Dictionary = state.get("offers", {})
    if offers.is_empty(): text += "No rotating offers are active.\n"
    else:
        for item in offers.values():
            text += "• %s\n  Expires Day %d\n" % [str(item.get("title", "Opportunity")), int(item.get("expires_day", 0))]
    text += "\nCHALLENGES\n"
    var challenges: Dictionary = state.get("challenges", {})
    if challenges.is_empty(): text += "No active challenges.\n"
    else:
        for challenge in challenges.values():
            text += "• %s\n  %d / %d   •   Expires Day %d\n" % [str(challenge.get("title", "Challenge")), int(challenge.get("progress", 0)), int(challenge.get("target", 1)), int(challenge.get("expires_day", 0))]
    var goal: Dictionary = state.get("community_goal", {})
    text += "\nCOMMUNITY GOAL\n%s\nProgress: %.0f / %.0f\n" % [str(goal.get("title", "Community Goal")), float(goal.get("progress", 0)), float(goal.get("target", 0))]
    text += "\nSeasonal events and world crises are governed by the authoritative world-event systems."
    label.text = text
    _layout()

func _close() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"):
        manager.hide_all_screens()
    else:
        panel.visible = false

func _layout() -> void:
    if panel == null: return
    var size := get_viewport().get_visible_rect().size
    var narrow := size.x < 760.0
    var width := maxf(304.0, size.x - 16.0) if narrow else minf(520.0, size.x - 36.0)
    var height := maxf(400.0, size.y - 86.0) if narrow else minf(600.0, size.y - 110.0)
    panel.position = Vector2(8, 70) if narrow else Vector2(maxf(18.0, size.x - width - 18.0), 88)
    panel.size = Vector2(width, height)
    title_label.position = Vector2(14, 10)
    title_label.size = Vector2(width - 110.0, 30)
    close_button.position = Vector2(width - 90.0, 7)
    close_button.size = Vector2(80, 46)
    scroll.position = Vector2(12, 58)
    scroll.size = Vector2(width - 24.0, height - 70.0)
    label.custom_minimum_size = Vector2(width - 48.0, 0)
