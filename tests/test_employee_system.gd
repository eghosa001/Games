extends SceneTree

const EmployeeSystem = preload("res://scripts/employee_system.gd")

func _init() -> void:
    call_deferred("run")

func run() -> void:
    var system = EmployeeSystem.new()
    root.add_child(system)
    await process_frame
    var failures: Array[String] = []
    var james = system.get_employee(EmployeeSystem.JAMES_ID)
    if james.is_empty() or james["name"] != "James": failures.append("James must exist with stable identity")
    for field in ["id", "name", "role", "level", "skills", "experience", "salary", "loyalty", "morale", "productivity", "specialization", "status", "assignment"]:
        if not james.has(field): failures.append("Employee missing field: %s" % field)
    for skill in ["production", "logistics", "management"]:
        if not james.get("skills", {}).has(skill): failures.append("Employee skills missing: %s" % skill)
    if not is_equal_approx(float(james.get("productivity", 0.0)), 0.82): failures.append("Productivity should use a normalized 0..1 value")
    if system.get_active_employee_count() != 3: failures.append("Active employee count must be derived from records")
    var original_id = james["id"]
    var snapshot: Dictionary = system.capture_state()
    var restored = EmployeeSystem.new(); root.add_child(restored); restored.restore_state(snapshot)
    if restored.get_employee(original_id).get("name", "") != "James": failures.append("James identity must survive save/load")
    var candidate = restored.candidates[0]
    var hire = restored.hire_candidate(str(candidate["id"]), 2)
    if not hire["ok"]: failures.append("Candidate hiring should create a real employee")
    var hired = hire["employee"]
    var hired_id := str(hired.get("id", ""))
    if hired_id.is_empty() or hired.get("status", "") != "active": failures.append("Hired employee must have persistent active record")
    if not hired.has("skills") or not hired.has("level"): failures.append("Hired employee must use the authoritative record schema")
    var before_skill := int(restored.get_employee(hired_id).get("skills", {}).get("production", 0))
    var train = restored.train_employee(hired_id, 2)
    var trained = restored.get_employee(hired_id)
    if not train["ok"] or int(trained.get("skills", {}).get("production", 0)) <= before_skill: failures.append("Training should improve employee specialization skill")
    var promote = restored.promote_employee(EmployeeSystem.JAMES_ID, 20)
    if not promote["ok"]: failures.append("James should be promotable")
    if int(restored.get_employee(EmployeeSystem.JAMES_ID)["level"]) < 2: failures.append("Promotion should increase employee level")
    restored.daily_update(21, 1)
    if int(restored.get_employee(EmployeeSystem.JAMES_ID)["experience"]) <= 6: failures.append("Daily update should advance employee experience")
    if restored.total_salary() <= 0 or restored.total_productivity() <= 0.0: failures.append("Roster should drive salary and productivity totals")
    var legacy = EmployeeSystem.new(); root.add_child(legacy); legacy.employees.clear(); legacy.migrate_legacy_count(5, 1)
    if legacy.get_active_employee_count() < 5: failures.append("Legacy employee count migration must preserve headcount")
    if legacy.get_employee(EmployeeSystem.JAMES_ID).is_empty(): failures.append("Legacy migration must restore James")
    if failures.is_empty(): print("EMPLOYEE SYSTEM TESTS PASSED")
    else:
        for failure in failures: push_error(failure)
        print("EMPLOYEE SYSTEM TESTS FAILED: %d" % failures.size())
    quit(0 if failures.is_empty() else 1)
