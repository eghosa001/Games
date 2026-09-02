extends Node

const EmployeeSystem = preload("res://scripts/employee_system.gd")

var employees = EmployeeSystem.new()
var parent: Node
var last_day := 0
var initialized := false

func _ready() -> void:
    parent = get_parent()
    if parent == null:
        return
    last_day = int(parent.get("day"))
    _restore_or_bootstrap()
    initialized = true

func _process(_delta: float) -> void:
    if not initialized or parent == null:
        return
    _sync_legacy_count()
    var current_day := int(parent.get("day"))
    if current_day != last_day:
        _advance_day(current_day)
        last_day = current_day

func hire(role: String = "Worker") -> Dictionary:
    if parent == null:
        return {"ok": false, "message": "Employee controller is not ready."}
    var employee = employees.create_employee(role, int(parent.get("day")), "renew_goods")
    _sync_legacy_count()
    _mark_dirty()
    return {"ok": true, "employee": employee}

func fire(employee_id: String, reason: String = "terminated") -> Dictionary:
    var result = employees.fire_employee(employee_id, int(parent.get("day")), reason)
    _sync_legacy_count()
    _mark_dirty()
    return result

func promote(employee_id: String) -> Dictionary:
    var result = employees.promote(employee_id, int(parent.get("day")))
    if result.get("ok", false):
        _mark_dirty()
    return result

func train(employee_id: String, cost: int = 600) -> Dictionary:
    var result = employees.train(employee_id, int(parent.get("day")), cost)
    if result.get("ok", false):
        _mark_dirty()
    return result

func active_count() -> int:
    return employees.active_count()

func total_wages() -> int:
    return employees.total_wages()

func snapshot() -> Dictionary:
    return employees.snapshot()

func _restore_or_bootstrap() -> void:
    var game_state = _game_state()
    if game_state != null and game_state.has_state():
        var saved = game_state.get_value(["employees"], {})
        if saved is Dictionary and not saved.is_empty() and saved.has("records"):
            employees.restore(saved)
    if employees.active_count() == 0:
        employees.bootstrap(max(1, int(parent.get("employees"))), int(parent.get("day")), "renew_goods")
    _sync_legacy_count()

func _sync_legacy_count() -> void:
    if parent == null:
        return
    var target := max(0, int(parent.get("employees")))
    var actual := employees.active_count()
    if actual < target:
        for _i in range(target - actual):
            employees.create_employee("Worker", int(parent.get("day")), "renew_goods")
    elif actual > target:
        var active := employees.active_employees()
        for i in range(target, active.size()):
            employees.fire_employee(str(active[i]["id"]), int(parent.get("day")), "legacy_count_sync")

func _advance_day(current_day: int) -> void:
    var reputation := float(parent.get("reputation"))
    var result := employees.tick_day(current_day, reputation, 50.0, 50.0)
    _sync_legacy_count()
    _mark_dirty()
    for event in result["events"]:
        if parent.has_method("_log"):
            parent.call("_log", "EMPLOYEE: %s resigned." % str(event["name"]))

func _mark_dirty() -> void:
    var game_state = _game_state()
    if game_state == null:
        return
    game_state.set_value(["employees"], employees.snapshot())

func _game_state():
    var tree = Engine.get_main_loop()
    if tree == null:
        return null
    var root = tree.get_root()
    if root == null:
        return null
    return root.get_node_or_null("RenewGameState")
