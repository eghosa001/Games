extends CanvasLayer

## Responsive headquarters management surface.
## Financial mutations are delegated to atomic HeadquartersSystem transactions.
var system = null
var finance = null
var main = null
var panel: PanelContainer
var status_label: Label
var area_label: Label
var title_label: Label
var close_button: Button
var upgrade_button: Button
var area_button: Button
var next_area_button: Button
var museum_button: Button
var area_scroll: ScrollContainer
var selected_area: Variant = "executive_offices"
var area_ids: Array = ["executive_offices", "board_room", "research", "training", "archives", "museum", "technology_center"]

func _ready() -> void:
    system = get_node_or_null("/root/RenewHeadquartersSystem")
    finance = get_node_or_null("/root/RenewFinanceSystem")
    main = get_tree().current_scene
    _build_ui(); _layout(); _refresh()
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)
func _style(bg: Color, border: Color, radius := 12) -> StyleBoxFlat:
    var s := StyleBoxFlat.new(); s.bg_color = bg; s.border_color = border; s.set_border_width_all(1); s.set_corner_radius_all(radius); return s
func _build_ui() -> void:
    panel = PanelContainer.new(); panel.name = "HeadquartersSurface"; panel.add_theme_stylebox_override("panel", _style(Color("0d2028"), Color("274852"))); add_child(panel)
    var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 7); panel.add_child(box)
    var header := HBoxContainer.new(); box.add_child(header)
    title_label = Label.new(); title_label.text = "HEADQUARTERS"; title_label.add_theme_font_size_override("font_size", 20); title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(title_label)
    close_button = Button.new(); close_button.text = "CLOSE"; close_button.custom_minimum_size = Vector2(72, 44); close_button.focus_mode = Control.FOCUS_NONE; close_button.pressed.connect(_close); header.add_child(close_button)
    status_label = Label.new(); status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; status_label.add_theme_font_size_override("font_size", 11); box.add_child(status_label)
    upgrade_button = Button.new(); upgrade_button.text = "UPGRADE HEADQUARTERS"; upgrade_button.custom_minimum_size = Vector2(0, 46); upgrade_button.focus_mode = Control.FOCUS_NONE; upgrade_button.pressed.connect(_upgrade_hq); box.add_child(upgrade_button)
    var area_title := Label.new(); area_title.text = "FUNCTIONAL AREAS"; area_title.add_theme_font_size_override("font_size", 10); box.add_child(area_title)
    area_scroll = ScrollContainer.new(); area_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; area_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; area_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; box.add_child(area_scroll)
    var area_box := VBoxContainer.new(); area_box.add_theme_constant_override("separation", 6); area_scroll.add_child(area_box)
    area_label = Label.new(); area_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; area_label.add_theme_font_size_override("font_size", 12); area_box.add_child(area_label)
    area_button = Button.new(); area_button.custom_minimum_size = Vector2(0, 46); area_button.focus_mode = Control.FOCUS_NONE; area_button.pressed.connect(_build_area); area_box.add_child(area_button)
    next_area_button = Button.new(); next_area_button.text = "NEXT AREA"; next_area_button.custom_minimum_size = Vector2(0, 46); next_area_button.focus_mode = Control.FOCUS_NONE; next_area_button.pressed.connect(_next_area); area_box.add_child(next_area_button)
    museum_button = Button.new(); museum_button.text = "OPEN CORPORATE MUSEUM"; museum_button.custom_minimum_size = Vector2(0, 46); museum_button.focus_mode = Control.FOCUS_NONE; museum_button.pressed.connect(_open_museum); area_box.add_child(museum_button)
func _game() -> Node: return get_tree().current_scene
func _message(text: String) -> void:
    var game := _game(); if game != null: game.message = text
    _refresh()
func _upgrade_hq() -> void:
    if system == null or main == null: return
    if not system.has_method("upgrade_with_finance"):
        _message("HQ finance transaction is unavailable."); return
    var result: Dictionary = system.upgrade_with_finance(finance, int(main.get("day")))
    if bool(result.get("ok", false)):
        _message("HQ upgraded to %s for $%s." % [result["stage"], _money(int(result.get("cost", 0)))])
        if main.has_method("_log"): main._log("HEADQUARTERS: upgraded to %s (-$%s)." % [result["stage"], _money(int(result["cost"])))])
    else: _message(str(result.get("reason", "HQ upgrade unavailable.")))
func _build_area() -> void:
    if system == null or main == null: return
    if not system.has_method("build_area_with_finance"):
        _message("HQ area finance transaction is unavailable."); return
    var result: Dictionary = system.build_area_with_finance(finance, selected_area)
    if bool(result.get("ok", false)):
        _message("%s is now operational (level %d) for $%s." % [result["area"], int(result.get("level", 1)), _money(int(result.get("cost", 0)))])
        if main.has_method("_log"): main._log("HQ AREA: %s level %d (-$%s)." % [result["area"], int(result.get("level", 1)), _money(int(result["cost"])))])
    else: _message(str(result.get("reason", "Area unavailable.")))
func _next_area() -> void:
    var index := area_ids.find(selected_area); if index < 0: index = 0
    selected_area = area_ids[(index + 1) % area_ids.size()]; _refresh()
func _open_museum() -> void:
    var museum = get_tree().root.get_node_or_null("Renew/HistoryPanel")
    if museum != null and museum.has_method("toggle_archive"): museum.toggle_archive()
    elif main != null: main.message = "Build the Museum at Corporate Center to open the visual legacy gallery."
func _close() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager"); if manager != null and manager.has_method("hide_all_screens"): manager.hide_all_screens()
func _refresh() -> void:
    if system == null or main == null or status_label == null: return
    var cash := int(finance.cash) if finance != null else int(main.get("cash")); var check: Dictionary = system.can_upgrade(cash); var next_text := "MAX LEVEL"
    if bool(check.get("ok", false)): next_text = "%s ($%s)" % [check["stage"], _money(int(check["cost"]))]
    elif system.get_stage_index() < 4: next_text = str(check.get("reason", "Locked"))
    status_label.text = "Stage  %s\nValue invested  $%s   •   Cash  $%s\nNext  %s   •   Areas  %d/%d" % [system.get_stage(), _money(system.headquarters_value), _money(cash), next_text, _built_count(), area_ids.size()]
    upgrade_button.disabled = system.get_stage_index() >= 4
    var spec = system.AREA_SPECS[selected_area]; var built := system.has_area(selected_area); var level := system.area_level(selected_area)
    area_label.text = "%s\nRequired stage  %s\nStatus  %s\nLevel  %d\nBase cost  $%s" % [spec["name"], system.STAGES[int(spec["min_stage"])], "Operational" if built else ("Unlocked" if system.get_stage_index() >= int(spec["min_stage"]) else "Locked"), level, _money(int(spec["cost"]) * max(1, level))]
    area_button.text = ("UPGRADE " if built else "BUILD ") + str(spec["name"]).to_upper(); area_button.disabled = system.get_stage_index() < int(spec["min_stage"])
    museum_button.disabled = not system.museum_available()
func _built_count() -> int:
    var count := 0
    for area_id in area_ids:
        if system.has_area(area_id): count += 1
    return count
func _money(value: int) -> String: return "%,d" % value
func _layout() -> void:
    if panel == null: return
    var size := get_viewport().get_visible_rect().size; var narrow := size.x < 760.0; var width := maxf(304.0, size.x - 16.0) if narrow else 460.0; var height := maxf(390.0, size.y - 90.0) if narrow else minf(610.0, size.y - 120.0)
    panel.position = Vector2(8, 70) if narrow else Vector2(maxf(18.0, size.x - width - 18.0), 92); panel.size = Vector2(width, height)
