extends Node

const EmployeeSystem = preload("res://scripts/employee_system.gd")

var employees = EmployeeSystem.new()
var parent: Node
var last_day := 0
var initialized := false
var previous_wage_bill := 0
var last_legacy_count := -1

func _ready() -> void:
    parent = get_parent()
    if parent == null: return
    last_day = int(parent.get("day"))
    _restore_or_bootstrap()
    _sync_legacy_projection()
    previous_wage_bill = employees.total_wages()
    initialized = true

func _process(_delta: float) -> void:
    if not initialized or parent == null: return
    _reconcile_legacy_count()
    var current_day := int(parent.get("day"))
    if current_day != last_day:
        _advance_day(current_day)
        last_day = current_day
    _mark_dirty()

func hire(role: String = "Worker") -> Dictionary:
    return hire_for_assignment(role, "renew_goods", "core")

# Hiring for an operating unit creates the real employee record and immediately
# binds that person to the unit. This is the authoritative path for new staffing.
func hire_for_assignment(role: String, assignment_type: String, assignment_id: String) -> Dictionary:
    if parent == null:
        return {"ok": false, "message": "Employee controller is not ready."}
    var employee = employees.create_employee(role, int(parent.get("day")), "renew_goods")
    var employee_id := str(employee["id"])
    var assignment := assign(employee_id, assignment_type, assignment_id)
    if not bool(assignment.get("ok", false)):
        employees.fire_employee(employee_id, int(parent.get("day")), "assignment_failed")
        _sync_legacy_projection()
        return assignment
    _sync_legacy_projection()
    _mark_dirty()
    return {"ok": true, "employee": employees.employees[employee_id].duplicate(true), "wage": int(employee["salary"])}

func fire(employee_id: String, reason: String = "terminated") -> Dictionary:
    var result = employees.fire_employee(employee_id, int(parent.get("day")), reason)
    if result.get("ok", false):
        _sync_legacy_projection()
        _mark_dirty()
    return result

func promote(employee_id: String) -> Dictionary:
    var result = employees.promote(employee_id, int(parent.get("day")))
    if result.get("ok", false): _mark_dirty()
    return result

func train(employee_id: String, cost: int = 600) -> Dictionary:
    var result = employees.train(employee_id, int(parent.get("day")), cost)
    if result.get("ok", false): _mark_dirty()
    return result

func assign(employee_id: String, assignment_type: String, assignment_id: String) -> Dictionary:
    if not employees.employees.has(employee_id):
        return {"ok": false, "message": "Employee not found."}
    var employee: Dictionary = employees.employees[employee_id]
    if employee.get("status", "former") != "active":
        return {"ok": false, "message": "Only active employees can be assigned."}
    var allowed := ["business", "property", "branch", "logistics", "sales", "management"]
    if not allowed.has(assignment_type):
        return {"ok": false, "message": "Unknown assignment type."}
    employee["assignment_type"] = assignment_type
    employee["assignment_id"] = assignment_id
    employee["history_ids"].append({"day": int(parent.get("day")), "event": "assignment", "type": assignment_type, "target": assignment_id})
    employees.employees[employee_id] = employee
    _mark_dirty()
    return {"ok": true, "employee": employee.duplicate(true)}

# Returns only employees actually assigned to the requested operating unit.
# Branch/business systems should use this instead of maintaining staffing counts.
func assigned_employee_ids(assignment_type: String, assignment_id: String) -> Array:
    var result: Array = []
    for employee in employees.active_employees():
        if str(employee.get("assignment_type", "")) == assignment_type and str(employee.get("assignment_id", "")) == assignment_id:
            result.append(str(employee.get("id", "")))
    return result

func assigned_count(assignment_type: String, assignment_id: String) -> int:
    return assigned_employee_ids(assignment_type, assignment_id).size()

func active_count() -> int:
    return employees.active_count()

func total_wages() -> int:
    return employees.total_wages()

func average_productivity() -> float:
    var active := employees.active_employees()
    if active.is_empty(): return 0.0
    var total := 0.0
    for employee in active: total += float(employee.get("productivity", 1.0))
    return total / float(active.size())

func average_morale() -> float:
    var active := employees.active_employees()
    if active.is_empty(): return 0.0
    var total := 0.0
    for employee in active: total += float(employee.get("morale", 50.0))
    return total / float(active.size())

func role_metrics() -> Dictionary:
    var metrics := {}
    for role in employees.ROLES.keys():
        metrics[role] = {"count": 0, "productivity": 0.0}
    for employee in employees.active_employees():
        var role := str(employee.get("role", "Worker"))
        if not metrics.has(role): metrics[role] = {"count": 0, "productivity": 0.0}
        metrics[role]["count"] += 1
        metrics[role]["productivity"] += float(employee.get("productivity", 1.0))
    for role in metrics.keys():
        var count := int(metrics[role]["count"])
        if count > 0: metrics[role]["productivity"] = float(metrics[role]["productivity"]) / float(count)
    return metrics

func operating_metrics() -> Dictionary:
    var production_score := 0.0
    var sales_score := 0.0
    var logistics_score := 0.0
    var management_score := 0.0
    var production_people := 0
    var sales_people := 0
    var logistics_people := 0
    var management_people := 0
    var role_weights := {
        "Worker": {"production": 1.00, "sales": 0.55, "logistics": 0.70, "management": 0.40},
        "Technician": {"production": 1.35, "sales": 0.45, "logistics": 0.65, "management": 0.55},
        "Sales": {"production": 0.45, "sales": 1.35, "logistics": 0.55, "management": 0.60},
        "Logistics": {"production": 0.60, "sales": 0.55, "logistics": 1.35, "management": 0.65},
        "Accountant": {"production": 0.45, "sales": 0.65, "logistics": 0.55, "management": 1.15},
        "Supervisor": {"production": 1.20, "sales": 0.80, "logistics": 0.85, "management": 1.20},
        "Manager": {"production": 1.10, "sales": 0.95, "logistics": 0.90, "management": 1.35}
    }
    for employee in employees.active_employees():
        var role := str(employee.get("role", "Worker"))
        var weight: Dictionary = role_weights.get(role, role_weights["Worker"])
        var productivity := float(employee.get("productivity", 1.0))
        production_score += productivity * float(weight["production"])
        sales_score += productivity * float(weight["sales"])
        logistics_score += productivity * float(weight["logistics"])
        management_score += productivity * float(weight["management"])
        production_people += 1 if float(weight["production"]) >= 1.0 else 0
        sales_people += 1 if float(weight["sales"]) >= 1.0 else 0
        logistics_people += 1 if float(weight["logistics"]) >= 1.0 else 0
        management_people += 1 if float(weight["management"]) >= 1.0 else 0
    var count := max(1, active_count())
    return {
        "production_efficiency": clampf(production_score / float(count), 0.25, 2.5),
        "sales_efficiency": clampf(sales_score / float(count), 0.25, 2.5),
        "logistics_efficiency": clampf(logistics_score / float(count), 0.25, 2.5),
        "management_efficiency": clampf(management_score / float(count), 0.25, 2.5),
        "production_people": production_people,
        "sales_people": sales_people,
        "logistics_people": logistics_people,
        "management_people": management_people
    }

func effective_staffing() -> int:
    var count := active_count()
    if count <= 0: return 0
    return max(1, int(round(float(count) * average_productivity())))

func snapshot() -> Dictionary:
    return employees.snapshot()

func _restore_or_bootstrap() -> void:
    var game_state = _game_state()
    if game_state != null and game_state.has_state():
        var saved = game_state.get_value(["employees"], {})
        if saved is Dictionary and not saved.is_empty(): employees.restore(saved)
    if employees.active_count() == 0:
        employees.bootstrap(max(1, int(parent.get("employees"))), int(parent.get("day")), "renew_goods")
    last_legacy_count = int(parent.get("employees"))

func _reconcile_legacy_count() -> void:
    if parent == null: return
    var requested := max(0, int(parent.get("employees")))
    var actual := employees.active_count()
    if requested != last_legacy_count:
        if actual < requested:
            for _i in range(requested - actual):
                employees.create_employee("Worker", int(parent.get("day")), "renew_goods")
        elif actual > requested:
            var active := employees.active_employees()
            for i in range(requested, active.size()):
                employees.fire_employee(str(active[i]["id"]), int(parent.get("day")), "legacy_count_sync")
        actual = employees.active_count()
    if int(parent.get("employees")) != actual:
        parent.set("employees", actual)
    last_legacy_count = actual

func _sync_legacy_projection() -> void:
    if parent == null: return
    var actual := employees.active_count()
    parent.set("employees", actual)
    last_legacy_count = actual

func _advance_day(current_day: int) -> void:
    var reputation := float(parent.get("reputation"))
    var result := employees.tick_day(current_day, reputation, 50.0, 50.0)
    var legacy_bill := employees.active_count() * 180
    var real_bill := int(result["wages"])
    var payroll_delta := real_bill - legacy_bill
    if payroll_delta > 0:
        parent.set("cash", int(parent.get("cash")) - payroll_delta)
    elif payroll_delta < 0:
        parent.set("cash", int(parent.get("cash")) + abs(payroll_delta))
    _sync_legacy_projection()
    for event in result["events"]:
        if parent.has_method("_log"):
            parent.call("_log", "EMPLOYEE: %s resigned." % str(event["name"]))
    previous_wage_bill = real_bill

func _mark_dirty() -> void:
    var game_state = _game_state()
    if game_state == null: return
    game_state.set_value(["employees"], employees.snapshot())
    game_state.set_value(["analytics", "employee_average_morale"], average_morale())
    game_state.set_value(["analytics", "employee_average_productivity"], average_productivity())
    game_state.set_value(["analytics", "employee_wage_bill"], employees.total_wages())
    var operations := operating_metrics()
    for key in operations.keys():
        game_state.set_value(["analytics", "employee_%s" % key], operations[key])

func _game_state():
    var tree = Engine.get_main_loop()
    if tree == null: return null
    var root = tree.get_root()
    if root == null: return null
    return root.get_node_or_null("RenewGameState")
