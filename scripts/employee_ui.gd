extends CanvasLayer
class_name RenewEmployeeUI

# Phase 38: employee presentation reads canonical GameState and delegates all
# mutations to the EmployeeCommandSystem through GameplayCommandSystem.
var panel: Panel
var employee_list: VBoxContainer
var detail_label: Label
var selected_id: Variant = ""
var _refresh_clock: Variant = 0.0

func _ready() -> void:
    layer = 75
    _build_ui()
    _refresh()

func _process(delta: float) -> void:
    _refresh_clock += delta
    if _refresh_clock >= 0.5:
        _refresh_clock = 0.0
        _refresh()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
        toggle()

func _build_ui() -> void:
    panel = Panel.new()
    panel.position = Vector2(860, 70)
    panel.size = Vector2(380, 590)
    panel.visible = false
    add_child(panel)
    var margin: Variant = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_top", 14)
    margin.add_theme_constant_override("margin_bottom", 14)
    panel.add_child(margin)
    var root: Variant = VBoxContainer.new()
    root.add_theme_constant_override("separation", 8)
    margin.add_child(root)
    var title: Variant = Label.new()
    title.text = "EMPLOYEES"
    title.add_theme_font_size_override("font_size", 24)
    root.add_child(title)
    var hint: Variant = Label.new()
    hint.text = "F: close/open • Select a person to view their career."
    root.add_child(hint)
    var split: Variant = HSplitContainer.new()
    split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(split)
    employee_list = VBoxContainer.new()
    employee_list.custom_minimum_size.x = 145
    split.add_child(employee_list)
    var detail_scroll: Variant = ScrollContainer.new()
    detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    split.add_child(detail_scroll)
    detail_label = Label.new()
    detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail_scroll.add_child(detail_label)
    var actions: Variant = GridContainer.new()
    actions.columns = 2
    root.add_child(actions)
    _add_action(actions, "Train", "train")
    _add_action(actions, "Promote", "promote")
    _add_action(actions, "Assign", "assign")
    _add_action(actions, "Transfer", "transfer")
    _add_action(actions, "Fire", "fire")

func _add_action(parent: GridContainer, text: String, action: String) -> void:
    var button: Variant = Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(150, 38)
    button.pressed.connect(_action.bind(action))
    parent.add_child(button)

func _refresh() -> void:
    if panel == null:
        return
    var roster: Variant = _roster()
    if selected_id.is_empty() and not roster.is_empty():
        selected_id = str(roster[0].get("id", ""))
    _rebuild_list(roster)
    _update_details(roster)

func _rebuild_list(roster: Array) -> void:
    for child in employee_list.get_children():
        child.queue_free()
    for employee in roster:
        if str(employee.get("status", "active")) != "active":
            continue
        var button: Variant = Button.new()
        button.text = "%s\n%s" % [str(employee.get("name", "Employee")), str(employee.get("role", "Worker"))]
        button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        button.custom_minimum_size.y = 54
        button.pressed.connect(_select.bind(str(employee.get("id", ""))))
        employee_list.add_child(button)

func _update_details(roster: Array) -> void:
    var employee: Variant = {}
    for candidate in roster:
        if str(candidate.get("id", "")) == selected_id:
            employee = candidate
            break
    if employee.is_empty():
        detail_label.text = "No employee selected."
        return
    var productivity: Variant = int(round(float(employee.get("productivity", 0.0)) * 100.0))
    detail_label.text = "%s\n%s\n────────────────\nProductivity %d%%\nExperience %d\nMorale %d\nLoyalty %d\nSalary $%d/day\nSpecialization: %s" % [str(employee.get("name", "Employee")), str(employee.get("role", "Worker")), productivity, int(employee.get("experience", 0)), int(employee.get("morale", 0)), int(employee.get("loyalty", 0)), int(employee.get("salary", 0)), str(employee.get("specialization", "general")).capitalize()]

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
        "train": command.employee_system.train_employee(selected_id, int(_state_value("player", "day", 1)), 900)
        "promote": command.promote_employee(selected_id)
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
    if panel.visible:
        _refresh()
