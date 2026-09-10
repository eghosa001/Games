extends SceneTree

var failures: Array[String] = []

func _init() -> void:
    var system = load("res://scripts/employee_system.gd").new()
    root.add_child(system)
    system._create_initial_roster()
    var result: Dictionary = system.fire_employee("emp_0002", 10)
    if not bool(result.get("ok", false)):
        failures.append("Employee dismissal should succeed for a normal active employee")
    var coworker: Dictionary = system.get_employee("emp_james_001")
    if int(coworker.get("morale", 78)) != 74:
        failures.append("Dismissal must reduce morale of coworkers sharing the affected assignment")
    if int(result.get("affected_coworkers", 0)) != 1:
        failures.append("Dismissal should report the number of affected coworkers")
    if not failures.is_empty():
        for failure in failures:
            push_error(failure)
        quit(1)
        return
    print("EMPLOYEE DISMISSAL CASCADE TEST PASSED")
    quit(0)
