extends CanvasLayer

## RESTORA corporation network and late-game acquisition command surface.
## Rival state and transactions remain authoritative in Main/RelationshipCommandSystem.
var dimmer: ColorRect
var panel: Panel
var title_label: Label
var status_label: Label
var scroll: ScrollContainer
var list_label: Label
var detail_label: Label
var next_button: Button
var offer_button: Button
var improve_button: Button
var shares_button: Button
var sell_shares_button: Button
var acquire_button: Button
var battle_button: Button
var raise_bid_button: Button
var walk_button: Button
var close_button: Button
var refresh_clock := 0.0

const SURFACE := Color("0d2028")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("90a8aa")
const ACCENT := Color("d5b56e")
const TEAL := Color("5eead4")
const DANGER := Color("ef8f7f")
const SCRIM := Color(0.02, 0.08, 0.10, 0.76)

func _ready() -> void:
    layer = 67
    _build_ui()
    _refresh(true)
    if not get_viewport().size_changed.is_connected(_layout):
        get_viewport().size_changed.connect(_layout)

func _process(delta: float) -> void:
    if not visible: return
    refresh_clock += delta
    if refresh_clock >= 0.75:
        refresh_clock = 0.0
        _refresh(false)

func _game(): return get_tree().current_scene if get_tree() != null else null

func _progression():
    return get_node_or_null("/root/Renew/Systems/StrategicProgression")

func _has_unlock(feature_id: String) -> bool:
    var progression = _progression()
    if progression == null or not progression.has_method("has_unlock"):
        return true
    return bool(progression.has_unlock(feature_id))

func _rivals():
    var game = _game()
    if game == null: return null
    var commands = game.get_node_or_null("GameplayCommandSystem")
    if commands == null: return null
    var relationships = commands.get("relationship_system")
    if relationships == null: return null
    return relationships.get("rivals")

func _build_ui() -> void:
    dimmer = ColorRect.new()
    dimmer.name = "CorporationsModalScrim"
    dimmer.color = SCRIM
    dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    dimmer.gui_input.connect(_on_scrim_input)
    add_child(dimmer)

    panel = Panel.new()
    panel.name = "CorporationsPanel"
    var style := StyleBoxFlat.new()
    style.bg_color = SURFACE
    style.border_color = BORDER
    style.set_border_width_all(1)
    style.set_corner_radius_all(16)
    style.shadow_color = Color(0,0,0,0.30)
    style.shadow_size = 8
    style.shadow_offset = Vector2(0,4)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)

    title_label = _label("CORPORATE STRATEGY", 22, TEXT)
    status_label = _label("RIVAL INTELLIGENCE", 12, ACCENT)

    scroll = ScrollContainer.new()
    scroll.name = "CorporationRivalScroll"
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    panel.add_child(scroll)

    list_label = _label("", 13, TEXT)
    list_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list_label.custom_minimum_size = Vector2(0, 180)
    panel.remove_child(list_label)
    scroll.add_child(list_label)

    detail_label = _label("", 13, ACCENT)

    next_button = _button("NEXT RIVAL")
    next_button.pressed.connect(_next)
    offer_button = _button("ALLIANCE OFFER")
    offer_button.pressed.connect(_offer)
    improve_button = _button("IMPROVE RELATIONS")
    improve_button.pressed.connect(_improve)
    shares_button = _button("BUY SHARES")
    shares_button.pressed.connect(_shares)
    sell_shares_button = _button("SELL SHARES")
    sell_shares_button.pressed.connect(_sell_shares)

    acquire_button = _button("NEGOTIATE ACQUISITION", true)
    acquire_button.pressed.connect(_acquire)
    battle_button = _button("START BIDDING WAR", true)
    battle_button.pressed.connect(_battle)
    raise_bid_button = _button("RAISE BID", true)
    raise_bid_button.pressed.connect(_raise_bid)
    walk_button = _button("WALK AWAY", false, true)
    walk_button.pressed.connect(_walk)

    close_button = _button("CLOSE")
    close_button.pressed.connect(_close)
    _layout()

func _label(text: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    panel.add_child(label)
    return label

func _button(text: String, emphasis := false, danger := false) -> Button:
    var button := Button.new()
    button.text = text
    button.focus_mode = Control.FOCUS_NONE
    button.clip_text = true
    button.custom_minimum_size = Vector2(48, 50)
    button.add_theme_font_size_override("font_size", 12)
    if emphasis:
        button.add_theme_color_override("font_color", ACCENT)
    elif danger:
        button.add_theme_color_override("font_color", DANGER)
    panel.add_child(button)
    return button

func _layout() -> void:
    if get_viewport() == null or panel == null: return
    var viewport: Vector2 = get_viewport().size
    var margin := 10.0 if viewport.x < 390.0 else 16.0
    var width := minf(640.0, maxf(300.0, viewport.x - margin * 2.0))
    var height := minf(700.0, maxf(500.0, viewport.y - 40.0))
    dimmer.position = Vector2.ZERO
    dimmer.size = viewport
    panel.position = Vector2((viewport.x - width) / 2.0, maxf(12.0, (viewport.y - height) / 2.0))
    panel.size = Vector2(width, minf(height, viewport.y - panel.position.y - 12.0))

    var compact := width < 430.0
    var side := 14.0
    title_label.position = Vector2(side, 12)
    title_label.size = Vector2(width - side * 2.0, 30)
    title_label.add_theme_font_size_override("font_size", 20 if compact else 22)
    status_label.position = Vector2(side, 43)
    status_label.size = Vector2(width - side * 2.0, 22)

    var acquisition_unlocked := _has_unlock("acquisitions")
    var action_rows := 5 if acquisition_unlocked else 3
    var row_h := 52.0
    var gap := 7.0
    var footer_h := float(action_rows) * row_h + float(action_rows - 1) * gap + 66.0
    scroll.position = Vector2(side, 72)
    scroll.size = Vector2(width - side * 2.0, maxf(100.0, panel.size.y - footer_h - 170.0))
    detail_label.position = Vector2(side, scroll.position.y + scroll.size.y + 8.0)
    detail_label.size = Vector2(width - side * 2.0, 70.0)

    var y := detail_label.position.y + detail_label.size.y + 8.0
    var half := (width - side * 2.0 - gap) / 2.0
    _place_pair(next_button, offer_button, side, y, half, row_h, gap)
    y += row_h + gap
    _place_pair(improve_button, shares_button, side, y, half, row_h, gap)
    y += row_h + gap
    sell_shares_button.position = Vector2(side, y)
    sell_shares_button.size = Vector2(width - side * 2.0, row_h)
    y += row_h + gap

    for button in [acquire_button, battle_button, raise_bid_button, walk_button]:
        button.visible = acquisition_unlocked
        button.process_mode = Node.PROCESS_MODE_INHERIT if acquisition_unlocked else Node.PROCESS_MODE_DISABLED

    if acquisition_unlocked:
        _place_pair(acquire_button, battle_button, side, y, half, row_h, gap)
        y += row_h + gap
        _place_pair(raise_bid_button, walk_button, side, y, half, row_h, gap)
        y += row_h + gap

    close_button.position = Vector2(side, minf(y, panel.size.y - 58.0))
    close_button.size = Vector2(width - side * 2.0, 50)

func _place_pair(left: Button, right: Button, side: float, y: float, half: float, height: float, gap: float) -> void:
    left.position = Vector2(side, y)
    left.size = Vector2(half, height)
    right.position = Vector2(side + half + gap, y)
    right.size = Vector2(half, height)

func _refresh(_force: bool) -> void:
    var model = _rivals()
    if model == null or not model.has_method("ai_status"):
        status_label.text = "NETWORK OFFLINE"
        list_label.text = "Rival data unavailable."
        detail_label.text = "Reconnect to the corporate intelligence feed."
        return

    var state = get_node_or_null("/root/RenewGameState")
    var selected := int(state.get_value("competitors", "selected_rival", 0)) if state != null else 0
    var rival_array: Array = model.get("rivals") if model.get("rivals") is Array else []
    var rows: Array = []
    for i in range(rival_array.size()):
        var status: Dictionary = model.ai_status(i)
        if status.is_empty(): continue
        var marker := "›" if i == selected else "·"
        var gone := " • ABSORBED" if bool(status.get("eliminated", false)) else ""
        var sale := " • FIRE SALE" if bool(status.get("war_sale", false)) else ""
        rows.append("%s %s — %s | %.0f%% share%s%s" % [marker, str(status.get("name", "?")), str(status.get("tier", "?")), float(status.get("market_share", 0.0)) * 100.0, gone, sale])
    list_label.text = "\n".join(rows) if not rows.is_empty() else "No corporations tracked."
    list_label.custom_minimum_size.y = maxf(180.0, float(maxi(1, rows.size())) * 32.0)

    var level_text := " • ACQUISITIONS UNLOCKED" if _has_unlock("acquisitions") else " • STRATEGY LEVEL"
    status_label.text = "%d RIVAL%s%s" % [rival_array.size(), "" if rival_array.size() == 1 else "S", level_text]

    if selected >= 0 and selected < rival_array.size():
        var status: Dictionary = model.ai_status(selected)
        var holding_text := _selected_holding_text(str(rival_array[selected].get("id", "")), str(rival_array[selected].get("name", "rival")))
        detail_label.text = "%s\nRelationship %d  •  Share price $%s%s" % [str(status.get("name", "?")), int(status.get("relationship", 0)), _money(int(model.share_price(selected)) if model.has_method("share_price") else 0), holding_text]
    else:
        detail_label.text = "Select a corporation to inspect its relationship, shares and acquisition options."
    _layout()

func _selected_holding_text(rival_id: String, _rival_name: String) -> String:
    var state = get_node_or_null("/root/RenewGameState")
    if state == null: return ""
    var holdings = state.get_value("ownership", "holdings", [])
    if not holdings is Array: return ""
    for holding in holdings:
        if holding is Dictionary and str(holding.get("rival_id", "")) == rival_id:
            return "  •  You own %d shares" % int(holding.get("shares", 0))
    return ""

func _invoke(method_name: String) -> void:
    var game = _game()
    if game == null or not game.has_method(method_name):
        return
    game.call(method_name)
    _refresh(true)

func _next() -> void:
    var game = _game()
    if game == null or not game.has_method("select_rival"): return
    var state = get_node_or_null("/root/RenewGameState")
    var model = _rivals()
    var count := 1
    if model != null and model.get("rivals") is Array: count = maxi(1, (model.get("rivals") as Array).size())
    var selected := int(state.get_value("competitors", "selected_rival", 0)) if state != null else 0
    game.select_rival((selected + 1) % count)
    _refresh(true)
func _offer() -> void: _invoke("make_alliance_offer")
func _improve() -> void: _invoke("improve_alliance")
func _shares() -> void: _invoke("buy_rival_shares")
func _sell_shares() -> void: _invoke("sell_rival_shares")
func _acquire() -> void: _invoke("negotiate_selected_acquisition")
func _battle() -> void: _invoke("start_acquisition_battle")
func _raise_bid() -> void: _invoke("raise_acquisition_bid")
func _walk() -> void: _invoke("walk_away_acquisition")

func _on_scrim_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _close()
        get_viewport().set_input_as_handled()
    elif event is InputEventScreenTouch and event.pressed:
        _close()
        get_viewport().set_input_as_handled()

func _close() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"):
        manager.hide_all_screens()

func _money(amount: int) -> String:
    if amount >= 1000000: return "%.2fM" % (float(amount) / 1000000.0)
    if amount >= 1000: return "%.1fK" % (float(amount) / 1000.0)
    return str(amount)