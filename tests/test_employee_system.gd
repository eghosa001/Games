extends SceneTree

const EmployeeSystem = preload("res://scripts/employee_system.gd")

func _init() -> void:
    call_deferred("run")

func run() -> void:
    var system = EmployeeSystem.new()
    root.add_child(system)
    await process_frame
    var failures: Array[String] = []
    var failed := 0
    var james = system.get_employee(EmployeeSystem.JAMES_ID)
    if james.is_empty() or james["name"] != "James": failed += 1;failures.append("James must exist with stable identity")
    for field in ["id", "name", "role", "level", "skills", "experience", "salary", "loyalty", "morale", "productivity", "specialization", "status", "assignment", "management_capacity", "training_count", "training_until_day"]:
        if not james.has(field): failed += 1;failures.append("Employee missing field: %s" % field)
    for skill in ["production", "logistics", "management"]:
        if not james.get("skills", {}).has(skill): failed += 1;failures.append("Employee skills missing: %s" % skill)
    if not is_equal_approx(float(james.get("productivity", 0.0)), 0.82): failed += 1;failures.append("Productivity should use a normalized 0..1 value")
    if system.get_active_employee_count() != 3: failed += 1;failures.append("Active employee count must be derived from records")
    if system.get_management_capacity() <= 0: failed += 1;failures.append("Roster should expose positive management capacity")

    var original_id = james["id"]
    var snapshot: Dictionary = system.capture_state()
    var restored = EmployeeSystem.new(); root.add_child(restored); restored.restore_state(snapshot)
    if restored.get_employee(original_id).get("name", "") != "James": failed += 1;failures.append("James identity must survive save/load")

    var candidate = restored.candidates[0]
    var hire = restored.hire_candidate(str(candidate["id"]), 2)
    if not hire["ok"]: failed += 1;failures.append("Candidate hiring should create a real employee")
    var hired = hire["employee"]
    var hired_id := str(hired.get("id", ""))
    if hired_id.is_empty() or hired.get("status", "") != "active": failed += 1;failures.append("Hired employee must have persistent active record")
    if not hired.has("skills") or not hired.has("level"): failed += 1;failures.append("Hired employee must use the authoritative record schema")

    var before_logistics := int(restored.get_employee(hired_id).get("skills", {}).get("logistics", 0))
    var before_training_productivity := restored.get_productivity_multiplier(str(restored.get_employee(hired_id).get("assignment", "factory_001")))
    var train = restored.train_employee(hired_id, 2, 900, "logistics")
    var trained = restored.get_employee(hired_id)
    if not train["ok"] or str(train.get("skill", "")) != "logistics": failed += 1;failures.append("Training should accept an explicitly selected skill")
    if int(trained.get("skills", {}).get("logistics", 0)) <= before_logistics: failed += 1;failures.append("Training should improve the selected skill")
    if int(trained.get("training_count", 0)) != 1 or int(trained.get("training_until_day", 0)) != 3: failed += 1;failures.append("Training should consume one workday and record completion state")
    var duplicate_training = restored.train_employee(hired_id, 2, 900, "production")
    if duplicate_training.get("ok", true): failed += 1;failures.append("Employee must not train twice on the same day")
    var during_training_productivity := restored.get_productivity_multiplier(str(trained.get("assignment", "factory_001")))
    if during_training_productivity > before_training_productivity + 0.25: failed += 1;failures.append("Training time must not create impossible same-day production")
    restored.daily_update(3, 1)
    if int(restored.get_employee(hired_id).get("experience", 0)) <= int(hired.get("experience", 0)): failed += 1;failures.append("Employee should return to normal experience progression after training")

    var james_before = restored.get_employee(EmployeeSystem.JAMES_ID).duplicate(true)
    var capacity_before := int(james_before.get("management_capacity", 0))
    var management_before := int(james_before.get("skills", {}).get("management", 0))
    var productivity_before := float(james_before.get("productivity", 0.0))
    var promote = restored.promote_employee(EmployeeSystem.JAMES_ID, 20)
    if not promote["ok"]: failed += 1;failures.append("James should be promotable")
    var promoted_james := restored.get_employee(EmployeeSystem.JAMES_ID)
    if int(promoted_james["level"]) < 2: failed += 1;failures.append("Promotion should increase employee level")
    if float(promoted_james.get("productivity", 0.0)) <= productivity_before: failed += 1;failures.append("Promotion should increase productivity")
    if int(promoted_james.get("skills", {}).get("management", 0)) <= management_before: failed += 1;failures.append("Promotion should improve management skill")
    if int(promoted_james.get("management_capacity", 0)) <= capacity_before: failed += 1;failures.append("Promotion should increase management capacity")
    if int(promoted_james.get("promotion_date", 0)) != 20: failed += 1;failures.append("Promotion date should be recorded")

    restored.daily_update(21, 1)
    if int(restored.get_employee(EmployeeSystem.JAMES_ID)["experience"]) <= 6: failed += 1;failures.append("Daily update should advance employee experience")
    if restored.total_salary() <= 0 or restored.total_productivity() <= 0.0: failed += 1;failures.append("Roster should drive salary and productivity totals")

    var culture = root.get_node_or_null("RenewCompanyCultureSystem")
    if culture != null and culture.has_method("set_dimension"):
        var baseline := system.get_productivity_multiplier("factory_001")
        culture.set_dimension("employee_welfare", 100, 21, "culture integration test")
        var improved := system.get_productivity_multiplier("factory_001")
        if improved <= baseline: failed += 1;failures.append("Employee productivity must respond to company culture")
        culture.set_dimension("employee_welfare", 60, 21, "restore test baseline")

    var legacy = EmployeeSystem.new(); root.add_child(legacy); legacy.employees.clear(); legacy.migrate_legacy_count(5, 1)
    if legacy.get_active_employee_count() < 5: failed += 1;failures.append("Legacy employee count migration must preserve headcount")
    if legacy.get_employee(EmployeeSystem.JAMES_ID).is_empty(): failed += 1;failures.append("Legacy migration must restore James")
    var legacy_james := legacy.get_employee(EmployeeSystem.JAMES_ID)
    if not legacy_james.has("management_capacity") or not legacy_james.has("training_count"): failed += 1;failures.append("Legacy employee records must normalize Phase 12 career fields")

    if failures.is_empty(): print("EMPLOYEE SYSTEM TESTS PASSED")
    else:
        for failure in failures: push_error(failure)
        print("EMPLOYEE SYSTEM TESTS FAILED: %d" % failures.size())
    quit(1 if failed > 0 else 0)
