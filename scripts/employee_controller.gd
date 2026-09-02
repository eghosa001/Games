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
    if parent == null:
        return {"ok": false, "message": "Employee controller is not ready."}
    var employee = employees.create_employee(role, int(parent.get("day")), "renew_goods")
    _sync_legacy_projection()
    _mark_dirty()
    return {"ok": true, "employee": employee, "wage": int(employee["salary"])}

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

# Converts individual employee productivity into the staffing value expected by
# the current prototype ProductionSystem. This keeps the bridge explicit while
# the production system is being refactored to consume employee records directly.
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

# The scalar employee value is now a legacy projection, not a second roster.
# Only a change made externally by legacy gameplay code is interpreted as a
# requested headcount change. Natural resignations are allowed to reduce the
# projection instead of being immediately replaced.
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
    # Reconcile the prototype's fixed $180 payroll with the real employee
    # salaries. This is transitional until FinanceSystem owns payroll directly.
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

func _game_state():
    var tree = Engine.get_main_loop()
    if tree == null: return null
    var root = tree.get_root()
    if root == null: return null
    return root.get_node_or_null("RenewGameState")
