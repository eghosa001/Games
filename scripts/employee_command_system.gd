extends Node
const DomainSystem = preload("res://scripts/domain_system.gd")
const EmployeeSystem = preload("res://scripts/employee_system.gd")

var state_adapter = DomainSystem.new()
var employee_system = EmployeeSystem.new()

func _ready() -> void:
    add_child(state_adapter)
    add_child(employee_system)
    sync_roster()

func get_active_employee_count() -> int:
    return employee_system.get_active_employee_count()

func get_roster() -> Array[Dictionary]:
    return employee_system.get_roster()

func hire_employee() -> void:
    if not bool(state_adapter.get_value("businesses", "business_open", false)):
        state_adapter.message("Open the business first."); return
    var day := int(state_adapter.get_value("player", "day", 1))
    var current_count := employee_system.get_active_employee_count()
    var cost := 1200 + current_count * 250
    var cash := int(state_adapter.get_value("economy", "cash", 25000))
    if cash < cost:
        state_adapter.message("Hiring requires $%s." % state_adapter.money(cost)); return
    var result = employee_system.hire_default(day)
    if not bool(result.get("ok", false)):
        state_adapter.message(str(result.get("message", "Unable to hire employee."))); return
    state_adapter.set_value("economy", "cash", cash - cost)
    sync_roster()
    state_adapter.set_value("player", "reputation", int(state_adapter.get_value("player", "reputation", 0)) + 1)
    state_adapter.log_message("HIRING: employee %d joined (-$%s)." % [employee_system.get_active_employee_count(), state_adapter.money(cost)])
    state_adapter.message("Employee hired. More capacity, higher daily wages.")

func train_employee(employee_id: String) -> void:
    var day := int(state_adapter.get_value("player", "day", 1))
    var cost := 900
    var cash := int(state_adapter.get_value("economy", "cash", 25000))
    if cash < cost:
        state_adapter.message("Training requires $%s." % state_adapter.money(cost)); return
    var result = employee_system.train_employee(employee_id, day, cost)
    if not bool(result.get("ok", false)):
        state_adapter.message(str(result.get("message", "Training failed."))); return
    state_adapter.set_value("economy", "cash", cash - cost)
    sync_roster()
    state_adapter.message("Employee training completed.")

func promote_employee(employee_id: String) -> void:
    var day := int(state_adapter.get_value("player", "day", 1))
    var result = employee_system.promote_employee(employee_id, day)
    if not bool(result.get("ok", false)):
        state_adapter.message(str(result.get("message", "Promotion failed."))); return
    sync_roster()
    state_adapter.message(str(result.get("message", "Employee promoted.")))

func assign_employee(employee_id: String, assignment: String) -> void:
    var day := int(state_adapter.get_value("player", "day", 1))
    var result = employee_system.assign_employee(employee_id, assignment, day)
    if not bool(result.get("ok", false)):
        state_adapter.message(str(result.get("message", "Assignment failed."))); return
    sync_roster()
    state_adapter.message("Employee assignment updated.")

func fire_employee(employee_id: String) -> void:
    var day := int(state_adapter.get_value("player", "day", 1))
    var result = employee_system.fire_employee(employee_id, day)
    if not bool(result.get("ok", false)):
        state_adapter.message(str(result.get("message", "Dismissal failed."))); return
    sync_roster()
    state_adapter.message(str(result.get("message", "Employee dismissed.")))

func daily_update(company_performance: int = 0) -> Dictionary:
    var day := int(state_adapter.get_value("player", "day", 1))
    var result := employee_system.daily_update(day, company_performance)
    sync_roster()
    return result

func sync_roster() -> void:
    state_adapter.set_value("employees", "roster", employee_system.get_roster())
