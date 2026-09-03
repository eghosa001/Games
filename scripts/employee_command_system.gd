extends Node
const DomainSystem = preload("res://scripts/domain_system.gd")
const EmployeeSystem = preload("res://scripts/employee_system.gd")

var state_adapter = DomainSystem.new()
var employee_system = EmployeeSystem.new()

func _ready() -> void:
    add_child(state_adapter)
    add_child(employee_system)

func hire_employee() -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("Open the business first."); return
    var day := int(state_adapter.get_value("player", "day", 1))
    var result = employee_system.hire_default(day)
    if not bool(result.get("ok", false)):
        state_adapter.message(str(result.get("message", "Unable to hire employee."))); return
    var count := employee_system.active_count()
    var cost := 1200 + (count - 1) * 250
    var cash := int(state_adapter.get_value("economy", "cash", 25000))
    if cash < cost:
        # Do not keep a hire that the company cannot afford.
        employee_system.fire_employee(str(result["employee"]["id"]), day)
        state_adapter.message("Hiring requires $%s." % state_adapter.money(cost)); return
    state_adapter.set_value("economy", "cash", cash - cost)
    state_adapter.set_value("employees", "employees", count)
    state_adapter.set_value("employees", "roster", employee_system.get_roster())
    state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + 1)
    state_adapter.log_message("HIRING: employee %d joined (-$%s)." % [count, state_adapter.money(cost)])
    state_adapter.message("Employee hired. More capacity, higher daily wages.")

func sync_roster() -> void:
    state_adapter.set_value("employees", "roster", employee_system.get_roster())
    state_adapter.set_value("employees", "employees", employee_system.active_count())
