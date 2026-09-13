extends CanvasLayer

## Responsive presentation for the World Opportunity system.
## All decisions remain delegated to WorldMissions.

var game: Node
var missions: Node
var scrim: ColorRect
var panel: Panel
var title: Label
var kicker: Label
var mission_title: Label
var body: Label
var reward: Label
var expiry: Label
var status: Label
var accept_button: Button
var decline_button: Button
var close_button: Button
var opened := false
var _last_active := false

const BG := Color("08141bf5")
const CARD := Color("10232b")
const BORDER := Color("31515b")
const TEXT := Color("edf5f4")
const MUTED := Color("91a8ad")
const ACCENT := Color("d8b76d")
const POSITIVE := Color("86c9a9")
const WARNING := Color("f0ad88")

func _ready() -> void:
    game = get_tree().root.get_node_or_null("Renew")
    missions = game.get_node_or_null("World/WorldMissions") if game != null else null
    _build()
    visible = false
    _layout()
    get_viewport().size_changed.connect(_layout)

func _build() -> void:
    scrim = ColorRect.new()
    scrim.color = Color(0.01, 0.04, 0.06, 0.80)
    scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scrim.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(scrim)

    panel = Panel.new()
    panel.add_theme_stylebox_override("panel", _style(BG, BORDER, 18))
    add_child(panel)

    title = _label("WORLD OPPORTUNITY", 19, TEXT)
    kicker = _label("LIVE DECISION  •  ECONOMIC EVENT", 9, MUTED)
    mission_title = _label("No active opportunity", 15, ACCENT)
    mission_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body = _label("", 11, TEXT)
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    reward = _label("", 10, POSITIVE)
    reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    expiry = _label("", 10, WARNING)
    status = _label("", 9, MUTED)
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    for node in [title, kicker, mission_title, body, reward, expiry, status]: panel.add_child(node)

    close_button = _button("CLOSE", Callable(self, "_close"), 44)
    accept_button = _button("TAKE OPPORTUNITY", Callable(self, "_choose_a"), 46)
    decline_button = _button("DECLINE", Callable(self, "_choose_b"), 46)
    panel.add_child(close_button); panel.add_child(accept_button); panel.add_child(decline_button)

func _label(text: String, size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg; s.border_color = border
    s.set_border_width_all(1); s.set_corner_radius_all(radius)
    s.content_margin_left = 14; s.content_margin_right = 14
    s.content_margin_top = 10; s.content_margin_bottom = 10
    return s

func _button(text: String, callback: Callable, height := 44) -> Button:
    var b := Button.new()
    b.text = text; b.custom_minimum_size = Vector2(0, height)
    b.focus_mode = Control.FOCUS_NONE
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.pressed.connect(callback)
    b.add_theme_font_size_override("font_size", 10)
    b.add_theme_stylebox_override("normal", _style(Color("142c33"), BORDER, 9))
    b.add_theme_stylebox_override("hover", _style(Color("1b3b40"), ACCENT, 9))
    b.add_theme_stylebox_override("pressed", _style(Color("1b3b40"), ACCENT, 9))
    b.add_theme_color_override("font_color", TEXT)
    return b

func _layout() -> void:
    if panel == null: return
    var size: Vector2 = Vector2(get_viewport().size)
    var w := maxf(size.x, 320.0)
    var h := maxf(size.y, 480.0)
    var narrow := w < 720.0
    var pw := minf(w - (20.0 if narrow else 56.0), 760.0)
    var ph := minf(h - (24.0 if narrow else 56.0), 510.0)
    panel.size = Vector2(pw, ph)
    panel.position = Vector2((w - pw) * 0.5, (h - ph) * 0.5)
    title.position = Vector2(14, 10); title.size = Vector2(pw - 112, 28)
    kicker.position = Vector2(14, 39); kicker.size = Vector2(pw - 112, 18)
    close_button.position = Vector2(pw - 88, 10); close_button.size = Vector2(76, 44)
    mission_title.position = Vector2(14, 70); mission_title.size = Vector2(pw - 28, 48)
    body.position = Vector2(14, 124); body.size = Vector2(pw - 28, 110 if narrow else 96)
    reward.position = Vector2(14, 242); reward.size = Vector2(pw - 28, 40)
    expiry.position = Vector2(14, 286); expiry.size = Vector2(pw - 28, 22)
    var by := ph - 106.0
    accept_button.position = Vector2(14, by); accept_button.size = Vector2((pw - 36) * 0.65, 46)
    decline_button.position = Vector2(22 + (pw - 36) * 0.65, by); decline_button.size = Vector2((pw - 36) * 0.35, 46)
    status.position = Vector2(14, ph - 54); status.size = Vector2(pw - 28, 42)

func _process(_delta: float) -> void:
    if missions == null and game != null:
        missions = game.get_node_or_null("World/WorldMissions")
    if missions == null:
        return
    var active := bool(missions.active)
    if active and not _last_active and not opened:
        var manager := get_node_or_null("/root/RenewUIScreenManager")
        if manager != null and manager.has_method("show_screen"):
            manager.show_screen("WorldOpportunitiesPanel")
        else:
            open_screen()
    _last_active = active

func open_screen() -> void:
    opened = true; visible = true
    _layout()
    if missions == null and game != null: missions = game.get_node_or_null("World/WorldMissions")
    _refresh()

func close_screen() -> void:
    opened = false; visible = false

func _close() -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"): manager.hide_all_screens()
    else: close_screen()

func _refresh() -> void:
    if missions == null:
        mission_title.text = "WORLD SYSTEM UNAVAILABLE"
        body.text = "The opportunity service is not connected to the active world."
        accept_button.disabled = true; decline_button.disabled = true
        return
    var active := bool(missions.active)
    accept_button.disabled = not active; decline_button.disabled = not active
    if not active:
        mission_title.text = "NO ACTIVE OPPORTUNITY"
        body.text = "No decision is waiting. New opportunities appear as the world develops."
        reward.text = "COMPLETED  •  %d" % int(missions.completed)
        expiry.text = "Stand by for the next market event."
        status.text = "WORLD EVENTS remain day-based and do not depend on frame rate."
        return
    mission_title.text = str(missions.title)
    body.text = str(missions.text)
    reward.text = "POTENTIAL OUTCOME  •  %s" % str(missions.reward_preview)
    expiry.text = "DECISION WINDOW  •  EXPIRES AFTER DAY %d" % int(missions.expires_day)
    status.text = "Choose deliberately. Your reputation, relationships and cash can change."

func _choose_a() -> void:
    if missions == null: return
    missions.choose_a(); _refresh(); _surface_result()

func _choose_b() -> void:
    if missions == null: return
    missions.choose_b(); _refresh(); _surface_result()

func _surface_result() -> void:
    if game != null and status != null: status.text = str(game.message)
