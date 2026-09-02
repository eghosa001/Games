extends Node

const EmployeeSystem = preload("res://scripts/employee_system.gd")

func _ready() -> void:
    var system = EmployeeSystem.new()
    add_child(system)
    await get_tree().process_frame
    var failures: Array[String] = []

    var james = system.get_employee(EmployeeSystem.JAMES_ID)
    if james.is_empty() or james["name"] != "James": failures.append("James must exist with stable identity")
    for field in ["id", "name", "role", "skill", "experience", "career_level", "salary", "loyalty", "morale", "ambition", "personality", "productivity", "specialization", "assignment", "hire_date", "promotion_date", "status", "relationships", "history"]:
        if not james.has(field): failures.append("Employee missing field: %s" % field)

    var original_id = james["id"]
    var snapshot = system.capture_state()
    var restored = EmployeeSystem.new()
    add_child(restored)
    restored.restore_state(snapshot)
    if restored.get_employee(original_id).get("name", "") != "James": failures.append("James identity must survive save/load")

    var candidate = restored.candidates[0]
    var hire = restored.hire_candidate(str(candidate["id"]), 2)
    if not hire["ok"]: failures.append("Candidate hiring should create a real employee")
    var hired = hire["employee"]
    if hired.get("id", "").is_empty() or hired.get("status", "") != "active": failures.append("Hired employee must have persistent active record")

    var before_skill = int(hired["skill"])
    var train = restored.train_employee(str(hired["id"]), 2)
    if not train["ok"] or int(hired["skill"]) <= before_skill: failures.append("Training should improve employee skill")

    var promote = restored.promote_employee(EmployeeSystem.JAMES_ID, 20)
    if not promote["ok"]: failures.append("James should be promotable")
    if int(restored.get_employee(EmployeeSystem.JAMES_ID)["career_level"]) < 2: failures.append("Promotion should increase James career level")

    restored.daily_update(21, 1)
    if int(restored.get_employee(EmployeeSystem.JAMES_ID)["experience"]) <= 6: failures.append("Daily update should advance employee experience")
    if restored.total_salary() <= 0 or restored.total_productivity() <= 0.0: failures.append("Roster should drive salary and productivity totals")

    var legacy = EmployeeSystem.new()
    add_child(legacy)
    legacy.employees.clear()
    legacy.migrate_legacy_count(5, 1)
    if legacy.active_count() < 5: failures.append("Legacy employee count migration must preserve headcount")
    if legacy.get_employee(EmployeeSystem.JAMES_ID).is_empty(): failures.append("Legacy migration must restore James")

    if failures.is_empty():
        print("EMPLOYEE SYSTEM TESTS PASSED")
    else:
        for failure in failures: push_error(failure)
        print("EMPLOYEE SYSTEM TESTS FAILED: %d" % failures.size())
    get_tree().quit(0 if failures.is_empty() else 1)
