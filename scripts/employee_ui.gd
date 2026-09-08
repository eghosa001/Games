extends CanvasLayer
class_name RenewEmployeeUI

# Employee presentation reads canonical GameState and delegates mutations to
# EmployeeCommandSystem through GameplayCommandSystem, including training costs.
const PORTRAIT_SHEET := "res://Assets/Art/employee_portraits.svg"
const PORTRAIT_SIZE := Vector2(128, 128)
const SURFACE := Color("0d2028")
const SURFACE_2 := Color("102831")
const BORDER := Color("274852")
const TEXT := Color("e7f2ef")
const MUTED := Color("78949a")
const ACCENT := Color("d5b56e")
const GOOD := Color("5fe08a")
const SCRIM := Color(0.02, 0.08, 0.10, 0.72)
var dimmer: ColorRect
var panel: Panel
var employee_list: VBoxContainer
var detail_label: Label
var detail_row: HBoxContainer
var portrait: TextureRect
var selected_id: Variant = ""
var _refresh_clock: Variant = 0.0
var _list_scroll: ScrollContainer
var _detail_scroll: ScrollContainer
var _actions: GridContainer
var _title: Label
var _status: Label
var _summary: Label

func _ready() -> void:
    layer = 75
    _build_ui()
    _layout_responsive()
    _refresh()

func _process(delta: float) -> void:
    _refresh_clock += delta
    if _refresh_clock >= 0.5:
        _refresh_clock = 0.0
        if panel != null and panel.visible:
            _layout_responsive()
            _refresh()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
        toggle()

func _style(bg: Color, border: Color = BORDER, radius := 12) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    return style

func _build_ui() -> void:
    dimmer = ColorRect.new()
    dimmer.name = "EmployeeModalScrim"
    dimmer.color = SCRIM
    dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
    dimmer.visible = false
    add_child(dimmer)

    panel = Panel.new()
    panel.name = "EmployeesPanel"
    panel.visible = false
    panel.add_theme_stylebox_override("panel", _style(SURFACE))
    add_child(panel)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_bottom", 12)
    panel.add_child(margin)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 8)
    margin.add_child(root)

    var header := HBoxContainer.new()
    header.custom_minimum_size.y = 32
    root.add_child(header)
    _title = Label.new()
    _title.text = "EMPLOYEE COMMAND"
    _title.add_theme_font_size_override("font_size", 21)
    _title.add_theme_color_override("font_color", TEXT)
    _title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(_title)
    _status = Label.new()
    _status.text = "PEOPLE OPERATIONS"
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _status.add_theme_font_size_override("font_size", 10)
    _status.add_theme_color_override("font_color", ACCENT)
    header.add_child(_status)

    _summary = Label.new()
    _summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _summary.add_theme_font_size_override("font_size", 10)
    _summary.add_theme_color_override("font_color", MUTED)
    _summary.custom_minimum_size.y = 30
    root.add_child(_summary)

    _list_scroll = ScrollContainer.new()
    _list_scroll.name = "EmployeeRosterScroll"
    _list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(_list_scroll)
    employee_list = VBoxContainer.new()
    employee_list.add_theme_constant_override("separation", 6)
    employee_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _list_scroll.add_child(employee_list)

    _detail_scroll = ScrollContainer.new()
    _detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _detail_scroll.custom_minimum_size.y = 116
    root.add_child(_detail_scroll)
    detail_row = HBoxContainer.new()
    detail_row.add_theme_constant_override("separation", 10)
    _detail_scroll.add_child(detail_row)
    portrait = TextureRect.new()
    portrait.name = "EmployeePortrait"
    portrait.custom_minimum_size = Vector2(76, 76)
    portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    detail_row.add_child(portrait)
    detail_label = Label.new()
    detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail_label.add_theme_font_size_override("font_size", 11)
    detail_label.add_theme_color_override("font_color", TEXT)
    detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    detail_row.add_child(detail_label)

    _actions = GridContainer.new()
    _actions.columns = 2
    _actions.add_theme_constant_override("h_separation", 6)
    _actions.add_theme_constant_override("v_separation", 6)
    root.add_child(_actions)
    _add_action(_actions, "TRAIN", "train")
    _add_action(_actions, "PROMOTE", "promote")
    _add_action(_actions, "APPOINT", "appoint")
    _add_action(_actions, "ASSIGN", "assign")
    _add_action(_actions, "TRANSFER", "transfer")
    _add_action(_actions, "FIRE", "fire")
    var close_button := Button.new()
    close_button.text = "CLOSE"
    close_button.custom_minimum_size = Vector2(0, 46)
    close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    close_button.focus_mode = Control.FOCUS_NONE
    close_button.pressed.connect(_close)
    _actions.add_child(close_button)

func _close() -> void:
    var manager = get_node_or_null("/root/RenewUIScreenManager")
    if manager != null and manager.has_method("hide_all_screens"):
        manager.hide_all_screens()
    else:
        panel.visible = false
        dimmer.visible = false

func _add_action(parent_node: GridContainer, text: String, action: String) -> void:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(0, 46)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.focus_mode = Control.FOCUS_NONE
    button.tooltip_text = _action_hint(action)
    parent_node.add_child(button)
    button.pressed.connect(_action.bind(action))

func _action_hint(action: String) -> String:
    match action:
        "train": return "Improve the selected employee's capabilities."
        "promote": return "Increase the selected employee's career level."
        "appoint": return "Place the employee in an executive seat when eligible."
        "assign": return "Assign the employee to factory operations."
        "transfer": return "Transfer the employee to regional operations."
        "fire": return "Remove the selected employee from the company."
        _: return "Manage the selected employee."

func _layout_responsive() -> void:
    if panel == null or get_viewport() == null:
        return
    var size := get_viewport().get_visible_rect().size
    var phone := size.x < 430.0
    var mobile := size.x < 760.0
    var margin := 8.0 if phone else 12.0
    var panel_w := minf(760.0, maxf(280.0, size.x - margin * 2.0))
    var panel_h := minf(650.0, maxf(420.0, size.y - 82.0))
    panel.position = Vector2((size.x - panel_w) / 2.0, maxf(42.0, (size.y - panel_h) / 2.0))
    panel.size = Vector2(panel_w, minf(panel_h, size.y - panel.position.y - 10.0))
    dimmer.position = Vector2.ZERO
    dimmer.size = size
    _title.add_theme_font_size_override("font_size", 18 if phone else 21)
    _status.add_theme_font_size_override("font_size", 9 if phone else 10)
    _summary.add_theme_font_size_override("font_size", 9 if phone else 10)
    _list_scroll.custom_minimum_size.y = 128 if mobile else 0
    _detail_scroll.custom_minimum_size.y = 126 if mobile else 116
    _actions.columns = 2
    for child in _actions.get_children():
        if child is Button:
            child.custom_minimum_size = Vector2(0, 44 if phone else 46)
            child.add_theme_font_size_override("font_size", 9 if phone else 10)

func _refresh() -> void:
    if panel == null:
        return
    var roster: Array = _roster()
    if selected_id.is_empty() and not roster.is_empty():
        selected_id = str(roster[0].get("id", ""))
    if not selected_id.is_empty() and _find_employee(roster, selected_id).is_empty():
        selected_id = str(roster[0].get("id", "")) if not roster.is_empty() else ""
    var active_count := 0
    for employee in roster:
        if str(employee.get("status", "active")) == "active":
            active_count += 1
    _summary.text = "%d ACTIVE EMPLOYEES   •   SELECT A PERSON TO MANAGE THEIR CAREER, ROLE AND ASSIGNMENT." % active_count
    _rebuild_list(roster)
    _update_details(roster)

func _rebuild_list(roster: Array) -> void:
    for child in employee_list.get_children():
        child.queue_free()
    var active_found := false
    for employee in roster:
        if str(employee.get("status", "active")) != "active":
            continue
        active_found = true
        var button := Button.new()
        var employee_id := str(employee.get("id", ""))
        var selected := employee_id == str(selected_id)
        button.text = ("●  " if selected else "○  ") + "%s  •  %s" % [str(employee.get("name", "Employee")), str(employee.get("role", "Worker"))]
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.custom_minimum_size.y = 52
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.focus_mode = Control.FOCUS_NONE
        button.add_theme_font_size_override("font_size", 11)
        button.add_theme_color_override("font_color", TEXT if selected else MUTED)
        button.add_theme_color_override("font_hover_color", TEXT)
        button.add_theme_stylebox_override("normal", _style(SURFACE_2 if selected else SURFACE, ACCENT if selected else BORDER, 9))
        button.add_theme_stylebox_override("hover", _style(Color("183b43"), ACCENT, 9))
        button.pressed.connect(_select.bind(employee_id))
        employee_list.add_child(button)
    if not active_found:
        var empty := Label.new()
        empty.text = "NO ACTIVE EMPLOYEES\nRecruit or restore the workforce before using people operations."
        empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        empty.add_theme_color_override("font_color", MUTED)
        empty.add_theme_font_size_override("font_size", 11)
        empty.custom_minimum_size.y = 70
        employee_list.add_child(empty)

func _find_employee(roster: Array, employee_id: String) -> Dictionary:
    for employee in roster:
        if str(employee.get("id", "")) == employee_id:
            return employee
    return {}

func _update_details(roster: Array) -> void:
    var employee: Dictionary = _find_employee(roster, selected_id)
    if employee.is_empty():
        detail_label.text = "No employee selected."
        portrait.texture = null
        return
    _set_portrait(str(employee.get("id", selected_id)))
    var productivity: Variant = int(round(float(employee.get("productivity", 0.0)) * 100.0))
    var seat := str(employee.get("executive_seat", ""))
    var seat_line := ("C-suite: %s" % seat) if seat != "" else ("Level %d" % int(employee.get("level", 1)))
    detail_label.text = "%s\n%s  •  %s\nProductivity %d%%  •  Experience %d\nMorale %d  •  Loyalty %d\nSalary $%d/day\nSpecialization: %s" % [str(employee.get("name", "Employee")), str(employee.get("role", "Worker")), seat_line, productivity, int(employee.get("experience", 0)), int(employee.get("morale", 0)), int(employee.get("loyalty", 0)), int(employee.get("salary", 0)), str(employee.get("specialization", "general")).capitalize()]

func _set_portrait(employee_id: String) -> void:
    var sheet := load(PORTRAIT_SHEET) as Texture2D
    if sheet == null:
        portrait.texture = null
        return
    var atlas := AtlasTexture.new()
    atlas.atlas = sheet
    var variant := absi(employee_id.hash()) % 5
    atlas.region = Rect2(float(variant) * PORTRAIT_SIZE.x, 0.0, PORTRAIT_SIZE.x, PORTRAIT_SIZE.y)
    portrait.texture = atlas

func _select(employee_id: String) -> void:
    selected_id = employee_id
    _refresh()

func _action(action: String) -> void:
    if selected_id.is_empty():
        return
    var command = _command_system()
    if command == null:
        return
    match action:
        "train": command.train_employee(selected_id)
        "promote": command.promote_employee(selected_id)
        "appoint": command.appoint_executive(selected_id)
        "assign": command.assign_employee(selected_id, "factory_001")
        "transfer": command.assign_employee(selected_id, "regional_001")
        "fire": command.fire_employee(selected_id)
    command.employee_system.sync_roster()
    _refresh()

func _command_system():
    var main: Variant = get_node_or_null("/root/Renew")
    if main != null:
        var command = main.get_node_or_null("GameplayCommandSystem")
        if command != null:
            return command
    return get_tree().get_first_node_in_group("gameplay_command_system")

func _state_value(domain: String, key: String, default_value):
    var state: Variant = get_node_or_null("/root/RenewGameState")
    return default_value if state == null else state.get_value(domain, key, default_value)

func _roster() -> Array:
    var roster = _state_value("employees", "roster", [])
    return roster if roster is Array else []

func toggle() -> void:
    panel.visible = not panel.visible
    dimmer.visible = panel.visible
    if panel.visible:
        _layout_responsive()
        _refresh()
