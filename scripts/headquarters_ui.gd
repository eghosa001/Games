extends CanvasLayer

## Executive headquarters command surface.
## All financial mutations remain delegated to RenewHeadquartersSystem.
const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56e")
const SUCCESS := Color("72c9a3")
const WARNING := Color("e6b96a")

var system: Node
var finance: Node
var main: Node
var panel: PanelContainer
var content: VBoxContainer
var status_label: Label
var stage_label: Label
var progress_bar: ProgressBar
var area_label: Label
var area_status: Label
var close_button: Button
var upgrade_button: Button
var area_button: Button
var next_area_button: Button
var museum_button: Button
var area_scroll: ScrollContainer
var top_actions: HBoxContainer
var selected_area: String = "executive_offices"
var area_ids: Array[String] = ["executive_offices", "board_room", "research", "training", "archives", "museum", "technology_center"]

func _ready() -> void:
    system = RenewServices.get_service("RenewHeadquartersSystem")
    finance = get_node_or_null("/root/RenewFinanceSystem")
    main = get_tree().current_scene
    _build_ui()
    _layout()
    _refresh()
    close_screen()
    if not get_viewport().size_changed.is_connected(_layout): get_viewport().size_changed.connect(_layout)
    call_deferred("_resolve_main")

func _resolve_main() -> void:
    if main == null: main = get_tree().current_scene
    if system == null: system = RenewServices.get_service("RenewHeadquartersSystem")
    if finance == null: finance = get_node_or_null("/root/RenewFinanceSystem")

func open_screen() -> void:
    if panel == null: return
    panel.visible = true
    _refresh()

func close_screen() -> void:
    if panel != null: panel.visible = false

func _style(bg: Color, border: Color = BORDER, radius := 12) -> StyleBoxFlat:
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

func _button(text: String, min_width := 0.0) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(min_width, 46)
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", 10)
    b.add_theme_color_override("font_color", TEXT)
    b.add_theme_stylebox_override("normal", _style(SURFACE_2, BORDER, 9))
    b.add_theme_stylebox_override("hover", _style(Color("18343b"), ACCENT, 9))
    b.add_theme_stylebox_override("pressed", _style(Color("173139"), ACCENT, 9))
    return b

func _label(text: String, size := 11, color := TEXT) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return l

func _build_ui() -> void:
    panel = PanelContainer.new()
    panel.name = "HeadquartersSurface"
    panel.add_theme_stylebox_override("panel", _style(SURFACE, BORDER, 16))
    add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_bottom", 12)
    panel.add_child(margin)

    content = VBoxContainer.new()
    content.add_theme_constant_override("separation", 8)
    margin.add_child(content)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 8)
    content.add_child(header)
    var title := _label("HEADQUARTERS COMMAND", 20, TEXT)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    close_button = _button("CLOSE", 78)
    close_button.pressed.connect(_close)
    header.add_child(close_button)

    stage_label = _label("EXECUTIVE CAMPUS", 10, ACCENT)
    content.add_child(stage_label)
    status_label = _label("Loading headquarters intelligence...", 11, MUTED)
    content.add_child(status_label)

    progress_bar = ProgressBar.new()
    progress_bar.custom_minimum_size = Vector2(0, 8)
    progress_bar.show_percentage = false
    progress_bar.add_theme_stylebox_override("background", _style(Color("08171d"), BORDER, 4))
    progress_bar.add_theme_stylebox_override("fill", _style(ACCENT, ACCENT, 4))
    content.add_child(progress_bar)

    top_actions = HBoxContainer.new()
    top_actions.add_theme_constant_override("separation", 8)
    content.add_child(top_actions)
    upgrade_button = _button("UPGRADE HQ")
    upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    upgrade_button.pressed.connect(_upgrade_hq)
    top_actions.add_child(upgrade_button)
    museum_button = _button("MUSEUM")
    museum_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    museum_button.pressed.connect(_open_museum)
    top_actions.add_child(museum_button)

    content.add_child(_label("FUNCTIONAL AREAS", 10, ACCENT))
    area_scroll = ScrollContainer.new()
    area_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    area_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    area_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(area_scroll)

    var area_box := VBoxContainer.new()
    area_box.add_theme_constant_override("separation", 7)
    area_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    area_scroll.add_child(area_box)

    area_label = _label("", 14, TEXT)
    area_box.add_child(area_label)
    area_status = _label("", 11, MUTED)
    area_box.add_child(area_status)
    area_button = _button("BUILD AREA")
    area_button.pressed.connect(_build_area)
    area_box.add_child(area_button)
    next_area_button = _button("NEXT AREA")
    next_area_button.pressed.connect(_next_area)
    area_box.add_child(next_area_button)

func _game() -> Node:
    return get_tree().current_scene

func _message(text: String) -> void:
    var game := _game()
    if game != null: game.message = text
    _refresh()

func _upgrade_hq() -> void:
    if system == null or finance == null: return
    if not system.has_method("upgrade_with_finance"):
        _message("HQ finance transaction is unavailable.")
        return
    var day := int(main.get("day")) if main != null else 0
    var result: Dictionary = system.upgrade_with_finance(finance, day)
    if bool(result.get("ok", false)):
        _message("Headquarters advanced to %s for $%s." % [result.get("stage", "next stage"), _money(int(result.get("cost", 0)))])
        if main != null and main.has_method("_log"): main._log("HEADQUARTERS: upgraded to %s (-$%s)." % [result.get("stage", "next stage"), _money(int(result.get("cost", 0)))])
    else:
        _message(str(result.get("reason", "HQ upgrade unavailable.")))

func _build_area() -> void:
    if system == null or finance == null: return
    if not system.has_method("build_area_with_finance"):
        _message("HQ area finance transaction is unavailable.")
        return
    var result: Dictionary = system.build_area_with_finance(finance, selected_area)
    if bool(result.get("ok", false)):
        _message("%s is now level %d." % [result.get("area", "Area"), int(result.get("level", 1))])
        if main != null and main.has_method("_log"): main._log("HQ AREA: %s level %d (-$%s)." % [result.get("area", "Area"), int(result.get("level", 1)), _money(int(result.get("cost", 0)))])
    else:
        _message(str(result.get("reason", "Area unavailable.")))

func _next_area() -> void:
    var index := area_ids.find(selected_area)
    if index < 0: index = 0
    selected_area = area_ids[(index + 1) % area_ids.size()]
    _refresh()

func _open_museum() -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("show_screen") and system != null and system.museum_available():
        manager.show_screen("HistoryPanel")
    else:
        _message("Build the Museum at Corporate Center to unlock the visual legacy gallery.")

func _close() -> void:
    var manager := get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"): manager.hide_all_screens()

func _refresh() -> void:
    if system == null or finance == null or status_label == null: return
    var cash := int(finance.cash)
    var stage_index: int = int(system.get_stage_index())
    var check: Dictionary = system.can_upgrade(cash)
    var next_text := "FINAL STAGE"
    if bool(check.get("ok", false)): next_text = "%s • $%s" % [check.get("stage", "Next"), _money(int(check.get("cost", 0)))]
    elif stage_index < 4: next_text = str(check.get("reason", "Locked"))
    stage_label.text = "%s  •  %s" % [str(system.get_stage()).to_upper(), str(system.headquarters_region) if not str(system.headquarters_region).is_empty() else "CORPORATE COMMAND"]
    status_label.text = "INVESTED  $%s   •   CASH  $%s\nNEXT  %s   •   AREAS  %d/%d" % [_money(int(system.headquarters_value)), _money(cash), next_text, _built_count(), area_ids.size()]
    upgrade_button.disabled = stage_index >= 4 or not bool(check.get("ok", false))
    museum_button.disabled = not system.museum_available()
    progress_bar.max_value = 4.0
    progress_bar.value = float(stage_index)

    var spec: Dictionary = system.AREA_SPECS.get(selected_area, {})
    if spec.is_empty(): return
    var built: bool = bool(system.has_area(selected_area))
    var level: int = int(system.area_level(selected_area))
    var unlocked: bool = stage_index >= int(spec.get("min_stage", 0))
    var state := "OPERATIONAL" if built else ("AVAILABLE" if unlocked else "LOCKED")
    area_label.text = "%s   •   %s" % [str(spec.get("name", "Area")).to_upper(), state]
    area_status.text = "Requires %s  •  Level %d  •  %s $%s" % [system.STAGES[int(spec.get("min_stage", 0))], level, "Upgrade" if built else "Build", _money(int(spec.get("cost", 0)) * max(1, level))]
    area_button.text = ("UPGRADE " if built else "BUILD ") + str(spec.get("name", "AREA")).to_upper()
    area_button.disabled = not unlocked

func _built_count() -> int:
    var count := 0
    for area_id in area_ids:
        if system.has_area(area_id): count += 1
    return count

func _money(value: int) -> String:
    var negative := value < 0
    var digits := str(absi(value))
    var out := ""
    while digits.length() > 3:
        out = "," + digits.substr(digits.length() - 3, 3) + out
        digits = digits.substr(0, digits.length() - 3)
    return ("-" if negative else "") + digits + out

func _layout() -> void:
    if panel == null: return
    var size := get_viewport().get_visible_rect().size
    var narrow := size.x < 760.0
    var width := maxf(304.0, size.x - 16.0) if narrow else minf(560.0, size.x - 36.0)
    var height := maxf(430.0, size.y - 86.0) if narrow else minf(680.0, size.y - 110.0)
    panel.position = Vector2(8, 70) if narrow else Vector2(maxf(18.0, (size.x - width) * 0.5), 82)
    panel.size = Vector2(width, height)
    if top_actions != null:
        top_actions.alignment = BoxContainer.ALIGNMENT_BEGIN
        if narrow:
            top_actions.set("theme_override_constants/separation", 6)
            upgrade_button.custom_minimum_size = Vector2(0, 46)
            museum_button.custom_minimum_size = Vector2(0, 46)
            top_actions.add_theme_constant_override("separation", 6)
            if upgrade_button.get_parent() == top_actions:
                top_actions.remove_child(upgrade_button)
                top_actions.remove_child(museum_button)
                top_actions.add_child(upgrade_button)
                top_actions.add_child(museum_button)
                upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                museum_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        else:
            upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            museum_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
