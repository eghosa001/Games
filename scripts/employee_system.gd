extends Node
class_name RenewEmployeeSystem

const SYSTEM_VERSION := 1
const JAMES_ID := "emp_james_001"
var employees: Array[Dictionary] = []
var candidates: Array[Dictionary] = []
var next_id := 2
var history: Array[Dictionary] = []
var _day := 1
var _syncing_legacy := false
var _last_legacy_count := -1
var _last_game_day := -1
const FIRST_NAMES := ["David", "Sarah", "Michael", "Grace", "Daniel", "Amaka", "Victor", "Esther", "Samuel", "Ada"]
const ROLES := ["Technician", "Sales Associate", "Logistics Coordinator", "Craft Worker", "Operations Assistant"]
const SPECIALIZATIONS := ["Restoration", "Sales", "Logistics", "Production", "Operations"]

func _ready() -> void:
    if employees.is_empty(): _create_initial_roster()
    refresh_candidates()

func _process(_delta: float) -> void:
    _sync_legacy_gameplay()

func _create_initial_roster() -> void:
    employees.clear()
    employees.append(_make_employee(JAMES_ID, "James", "Worker", "Restoration", 58, 6, 450, 82, 78, 76, 82, 1, "Restoration", "Property & Workshop", 1))
    employees.append(_make_employee("emp_0002", "David", "Craft Worker", "Production", 48, 10, 420, 68, 72, 55, 70, 1, "Production", "Goods Factory", 1))
    employees.append(_make_employee("emp_0003", "Sarah", "Sales Associate", "Sales", 52, 8, 400, 71, 74, 66, 73, 1, "Sales", "Retail & Customers", 1))
    next_id = 4
    _record(JAMES_ID, "hired", {"reason": "founding roster"})
    _record("emp_0002", "hired", {"reason": "founding roster"})
    _record("emp_0003", "hired", {"reason": "founding roster"})

func _make_employee(id: String, name: String, role: String, specialization: String, skill: int, experience: int, salary: int, loyalty: int, morale: int, ambition: int, productivity: int, career_level: int, assignment: String, _unused: String, hire_date: int) -> Dictionary:
    return {"id": id, "name": name, "role": role, "skill": skill, "experience": experience, "career_level": career_level, "salary": salary, "loyalty": loyalty, "morale": morale, "ambition": ambition, "personality": _personality_for(name), "productivity": productivity, "specialization": specialization, "assignment": assignment, "hire_date": hire_date, "promotion_date": 0, "status": "active", "relationships": {}, "history": []}

func _personality_for(name: String) -> String:
    match name:
        "James": return "Loyal, ambitious, dependable"
        "David": return "Steady, practical, patient"
        "Sarah": return "Social, competitive, optimistic"
    return "Adaptable, hardworking, curious"

func refresh_candidates() -> void:
    candidates.clear()
    for i in range(4):
        var n := FIRST_NAMES[(i + _day) % FIRST_NAMES.size()]
        var role := ROLES[(i + _day) % ROLES.size()]
        var spec := SPECIALIZATIONS[(i + _day) % SPECIALIZATIONS.size()]
        candidates.append({"id": "candidate_%d_%d" % [_day, i], "name": n, "role": role, "skill": 40 + ((i * 9 + _day * 3) % 31), "experience": 3 + i * 4, "salary": 360 + i * 55, "loyalty": 50 + i * 4, "morale": 70, "ambition": 50 + i * 7, "personality": "Professional, motivated", "productivity": 55 + i * 5, "specialization": spec})

func active_count() -> int:
    var count := 0
    for employee in employees:
        if employee.get("status", "active") == "active": count += 1
    return count

func total_salary() -> int:
    var total := 0
    for employee in employees:
        if employee.get("status", "active") == "active": total += int(employee.get("salary", 0))
    return total

func total_productivity() -> float:
    var total := 0.0
    for employee in employees:
        if employee.get("status", "active") == "active": total += float(employee.get("productivity", 0)) / 100.0
    return total

func get_employee(employee_id: String) -> Dictionary:
    for employee in employees:
        if employee.get("id", "") == employee_id: return employee
    return {}

func get_roster() -> Array[Dictionary]: return employees.duplicate(true)
func get_candidates() -> Array[Dictionary]: return candidates.duplicate(true)

func hire_candidate(candidate_id: String, day: int) -> Dictionary:
    for candidate in candidates:
        if candidate.get("id", "") != candidate_id: continue
        var id := "emp_%04d" % next_id
        next_id += 1
        var employee := _make_employee(id, str(candidate["name"]), str(candidate["role"]), str(candidate["specialization"]), int(candidate["skill"]), int(candidate["experience"]), int(candidate["salary"]), int(candidate["loyalty"]), int(candidate["morale"]), int(candidate["ambition"]), int(candidate["productivity"]), 1, "Unassigned", "", day)
        employees.append(employee)
        _record(id, "hired", {"candidate_id": candidate_id})
        refresh_candidates()
        return {"ok": true, "employee": employee.duplicate(true), "cost": 1200 + active_count() * 250}
    return {"ok": false, "message": "Candidate is no longer available."}

func hire_default(day: int) -> Dictionary:
    if candidates.is_empty(): refresh_candidates()
    return hire_candidate(str(candidates[0]["id"]), day)

func fire_employee(employee_id: String, day: int) -> Dictionary:
    var employee := get_employee(employee_id)
    if employee.is_empty(): return {"ok": false, "message": "Employee not found."}
    if employee_id == JAMES_ID: return {"ok": false, "message": "James is a core story character and cannot be casually dismissed."}
    if employee.get("status", "active") != "active": return {"ok": false, "message": "Employee is not active."}
    employee["status"] = "fired"
    employee["morale"] = max(0, int(employee["morale"]) - 20)
    employee["loyalty"] = max(0, int(employee["loyalty"]) - 30)
    _record(employee_id, "fired", {"day": day})
    return {"ok": true, "message": "%s was dismissed. Remaining staff morale took a hit." % employee["name"]}

func train_employee(employee_id: String, day: int, cost: int = 900) -> Dictionary:
    var employee := get_employee(employee_id)
    if employee.is_empty() or employee.get("status", "active") != "active": return {"ok": false, "message": "Employee is not active."}
    employee["skill"] = min(100, int(employee["skill"]) + 6)
    employee["experience"] = int(employee["experience"]) + 2
    employee["productivity"] = min(100, int(employee["productivity"]) + 5)
    employee["morale"] = min(100, int(employee["morale"]) + 5)
    employee["loyalty"] = min(100, int(employee["loyalty"]) + 4)
    _record(employee_id, "trained", {"day": day, "cost": cost})
    return {"ok": true, "cost": cost, "employee": employee.duplicate(true)}

func promote_employee(employee_id: String, day: int) -> Dictionary:
    var employee := get_employee(employee_id)
    if employee.is_empty() or employee.get("status", "active") != "active": return {"ok": false, "message": "Employee is not active."}
    var level := int(employee["career_level"])
    if level >= 4: return {"ok": false, "message": "%s is already at the highest career level." % employee["name"]}
    if int(employee["experience"]) < level * 10 and employee_id != JAMES_ID: return {"ok": false, "message": "More experience is needed before promotion."}
    level += 1
    employee["career_level"] = level
    employee["promotion_date"] = day
    employee["salary"] = int(employee["salary"]) + 140 + level * 30
    employee["morale"] = min(100, int(employee["morale"]) + 12)
    employee["loyalty"] = min(100, int(employee["loyalty"]) + 8)
    if employee_id == JAMES_ID and level >= 4:
        employee["role"] = "COO"
        employee["specialization"] = "Executive Operations"
        employee["assignment"] = "Company Headquarters"
    elif level == 2: employee["role"] = "Senior " + str(employee["role"])
    elif level == 3: employee["role"] = "Supervisor"
    _record(employee_id, "promoted", {"day": day, "career_level": level})
    return {"ok": true, "employee": employee.duplicate(true), "message": "%s promoted to %s." % [employee["name"], employee["role"]]}

func assign_employee(employee_id: String, assignment: String, day: int) -> Dictionary:
    var employee := get_employee(employee_id)
    if employee.is_empty() or employee.get("status", "active") != "active": return {"ok": false, "message": "Employee is not active."}
    employee["assignment"] = assignment
    _record(employee_id, "assigned", {"day": day, "assignment": assignment})
    return {"ok": true, "employee": employee.duplicate(true)}

func change_relationship(employee_a: String, employee_b: String, amount: int, day: int) -> void:
    var a := get_employee(employee_a)
    var b := get_employee(employee_b)
    if a.is_empty() or b.is_empty(): return
    var relationships: Dictionary = a.get("relationships", {})
    relationships[employee_b] = clamp(int(relationships.get(employee_b, 50)) + amount, 0, 100)
    a["relationships"] = relationships
    _record(employee_a, "relationship_changed", {"day": day, "other": employee_b, "amount": amount})

func daily_update(day: int, company_performance: int = 0) -> Dictionary:
    _day = day
    var warnings: Array[String] = []
    for employee in employees:
        if employee.get("status", "active") != "active": continue
        employee["experience"] = int(employee["experience"]) + 1
        var morale_delta := 1 if company_performance >= 0 else -2
        employee["morale"] = clamp(int(employee["morale"]) + morale_delta, 0, 100)
        if int(employee["morale"]) < 35:
            employee["loyalty"] = max(0, int(employee["loyalty"]) - 2)
            warnings.append("%s is becoming unhappy." % employee["name"])
        var performance := int(employee["skill"]) + int(employee["morale"]) / 2 + int(employee["loyalty"]) / 2
        employee["productivity"] = clamp(int(round(float(performance) / 2.0)), 20, 100)
        if int(employee["ambition"]) >= 80 and int(employee["career_level"]) < 4 and int(employee["experience"]) % 12 == 0:
            warnings.append("%s is ready for a career conversation." % employee["name"])
    refresh_candidates()
    return {"warnings": warnings, "salary": total_salary(), "productivity": total_productivity()}

func poach_candidate(employee_id: String, rival_name: String, day: int) -> Dictionary:
    var employee := get_employee(employee_id)
    if employee.is_empty() or employee.get("status", "active") != "active": return {"ok": false}
    var risk := int(employee["ambition"]) + (100 - int(employee["loyalty"]))
    if risk < 100: return {"ok": false, "message": "%s resisted a poaching attempt by %s." % [employee["name"], rival_name]}
    employee["loyalty"] = max(0, int(employee["loyalty"]) - 12)
    employee["morale"] = max(0, int(employee["morale"]) - 8)
    _record(employee_id, "poaching_attempt", {"day": day, "rival": rival_name})
    return {"ok": true, "message": "%s is considering an offer from %s." % [employee["name"], rival_name]}

func counter_offer(employee_id: String, day: int) -> Dictionary:
    var employee := get_employee(employee_id)
    if employee.is_empty() or employee.get("status", "active") != "active": return {"ok": false}
    employee["salary"] = int(employee["salary"]) + 100
    employee["loyalty"] = min(100, int(employee["loyalty"]) + 15)
    employee["morale"] = min(100, int(employee["morale"]) + 10)
    _record(employee_id, "counter_offer", {"day": day})
    return {"ok": true, "salary": employee["salary"]}

func capture_state() -> Dictionary:
    return {"system_version": SYSTEM_VERSION, "employees": employees.duplicate(true), "candidates": candidates.duplicate(true), "next_id": next_id, "history": history.duplicate(true), "day": _day}

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty():
        _create_initial_roster()
        refresh_candidates()
        return
    employees = snapshot.get("employees", []).duplicate(true)
    candidates = snapshot.get("candidates", []).duplicate(true)
    next_id = int(snapshot.get("next_id", employees.size() + 1))
    history = snapshot.get("history", []).duplicate(true)
    _day = int(snapshot.get("day", 1))
    if employees.is_empty(): _create_initial_roster()
    _ensure_james()
    refresh_candidates()

func migrate_legacy_count(count: int, day: int = 1) -> void:
    if not employees.is_empty(): return
    _create_initial_roster()
    while active_count() < max(3, count): hire_default(day)

func _ensure_james() -> void:
    if not get_employee(JAMES_ID).is_empty(): return
    var james := _make_employee(JAMES_ID, "James", "Worker", "Restoration", 58, 6, 450, 82, 78, 76, 82, 1, "Restoration", "", 1)
    employees.push_front(james)
    _record(JAMES_ID, "restored_identity", {})

func _sync_legacy_gameplay() -> void:
    if _syncing_legacy: return
    var tree := get_tree()
    if tree == null: return
    var main = tree.current_scene
    if main == null: return
    var legacy_value = main.get("employees")
    var game_day_value = main.get("day")
    if legacy_value == null: return
    var legacy_count := int(legacy_value)
    var game_day := int(game_day_value) if game_day_value != null else _day
    if _last_game_day < 0:
        _last_game_day = game_day
    elif game_day != _last_game_day:
        daily_update(game_day, int(main.get("last_profit")))
        _last_game_day = game_day
    var active := active_count()
    if _last_legacy_count < 0:
        _last_legacy_count = legacy_count
        _syncing_legacy = true
        main.set("employees", active)
        _syncing_legacy = false
        return
    if legacy_count > active:
        while active_count() < legacy_count:
            var result := hire_default(game_day)
            if not result.get("ok", false): break
    active = active_count()
    if int(main.get("employees")) != active:
        _syncing_legacy = true
        main.set("employees", active)
        _syncing_legacy = false
    _last_legacy_count = active

func _record(employee_id: String, event_type: String, details: Dictionary) -> void:
    var entry := {"employee_id": employee_id, "type": event_type, "details": details}
    history.append(entry)
    var employee := get_employee(employee_id)
    if not employee.is_empty():
        var employee_history: Array = employee.get("history", [])
        employee_history.append(entry.duplicate(true))
        employee["history"] = employee_history
