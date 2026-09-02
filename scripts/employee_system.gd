extends RefCounted
class_name RenewEmployeeSystem

const MIN_STAT := 0.0
const MAX_STAT := 100.0
const BASE_WAGE := 180

var employees: Dictionary = {}
var next_id := 1

const ROLES := {
    "Worker": {"skill": 35.0, "wage": 180},
    "Technician": {"skill": 55.0, "wage": 260},
    "Sales": {"skill": 45.0, "wage": 230},
    "Logistics": {"skill": 45.0, "wage": 240},
    "Accountant": {"skill": 50.0, "wage": 280},
    "Supervisor": {"skill": 65.0, "wage": 360},
    "Manager": {"skill": 70.0, "wage": 450}
}

const PERSONALITIES := ["Builder", "Optimizer", "Diplomat", "Ambitious", "Loyal", "Pragmatist"]

func bootstrap(count: int, day: int, company_id: String = "renew_goods") -> void:
    if not employees.is_empty():
        return
    for i in range(max(0, count)):
        create_employee("Worker", day, company_id, "Starter %d" % (i + 1))

func create_employee(role: String, day: int, company_id: String, forced_name: String = "") -> Dictionary:
    var role_name := role if ROLES.has(role) else "Worker"
    var role_data: Dictionary = ROLES[role_name]
    var employee_id := "emp_%04d" % next_id
    next_id += 1
    var employee := {
        "id": employee_id,
        "name": forced_name if not forced_name.is_empty() else _generate_name(),
        "role": role_name,
        "skill": clampf(float(role_data["skill"]) + randf_range(-10.0, 10.0), MIN_STAT, MAX_STAT),
        "experience": 0.0,
        "career_level": 1,
        "salary": int(role_data["wage"]),
        "loyalty": 65.0,
        "morale": 70.0,
        "ambition": randf_range(25.0, 85.0),
        "personality": PERSONALITIES[randi() % PERSONALITIES.size()],
        "productivity": 1.0,
        "specialization": "general",
        "assignment_type": "business",
        "assignment_id": company_id,
        "hire_day": day,
        "promotion_day": 0,
        "status": "active",
        "relationship_ids": [],
        "history_ids": []
    }
    employees[employee_id] = employee
    return employee.duplicate(true)

func fire_employee(employee_id: String, day: int, reason: String = "terminated") -> Dictionary:
    if not employees.has(employee_id):
        return {"ok": false, "message": "Employee not found."}
    var employee: Dictionary = employees[employee_id]
    if employee["status"] != "active":
        return {"ok": false, "message": "Employee is already inactive."}
    employee["status"] = "former"
    employee["assignment_id"] = ""
    employee["history_ids"].append({"day": day, "event": "left_company", "reason": reason})
    employees[employee_id] = employee
    return {"ok": true, "employee": employee.duplicate(true)}

func promote(employee_id: String, day: int) -> Dictionary:
    if not employees.has(employee_id):
        return {"ok": false, "message": "Employee not found."}
    var employee: Dictionary = employees[employee_id]
    if employee["status"] != "active":
        return {"ok": false, "message": "Only active employees can be promoted."}
    var role_order := ["Worker", "Technician", "Supervisor", "Manager"]
    var current_index := role_order.find(str(employee["role"]))
    if current_index < 0 or current_index >= role_order.size() - 1:
        return {"ok": false, "message": "No promotion available for this role."}
    var new_role: String = role_order[current_index + 1]
    var role_data: Dictionary = ROLES[new_role]
    employee["role"] = new_role
    employee["career_level"] = int(employee["career_level"]) + 1
    employee["salary"] = int(role_data["wage"]) + int(employee["career_level"]) * 25
    employee["morale"] = _clamp_stat(float(employee["morale"]) + 12.0)
    employee["loyalty"] = _clamp_stat(float(employee["loyalty"]) + 8.0)
    employee["promotion_day"] = day
    employee["history_ids"].append({"day": day, "event": "promotion", "role": new_role})
    employees[employee_id] = employee
    return {"ok": true, "employee": employee.duplicate(true)}

func train(employee_id: String, day: int, cost: int = 600) -> Dictionary:
    if not employees.has(employee_id):
        return {"ok": false, "message": "Employee not found.", "cost": 0}
    var employee: Dictionary = employees[employee_id]
    if employee["status"] != "active":
        return {"ok": false, "message": "Former employees cannot be trained.", "cost": 0}
    employee["skill"] = _clamp_stat(float(employee["skill"]) + 5.0)
    employee["experience"] = maxf(0.0, float(employee["experience"]) + 0.25)
    employee["morale"] = _clamp_stat(float(employee["morale"]) + 4.0)
    employee["loyalty"] = _clamp_stat(float(employee["loyalty"]) + 2.0)
    employee["history_ids"].append({"day": day, "event": "training", "cost": cost})
    employees[employee_id] = employee
    return {"ok": true, "employee": employee.duplicate(true), "cost": cost}

func tick_day(day: int, company_reputation: float, management_quality: float = 50.0, safe_conditions: float = 50.0) -> Dictionary:
    var wages := 0
    var active_count := 0
    var average_morale := 0.0
    var average_productivity := 0.0
    var events: Array = []
    for employee_id in employees.keys():
        var employee: Dictionary = employees[employee_id]
        if employee["status"] != "active":
            continue
        active_count += 1
        wages += int(employee["salary"])
        employee["experience"] = float(employee["experience"]) + 0.02
        var morale_delta := (company_reputation - 50.0) * 0.03 + (management_quality - 50.0) * 0.025 + (safe_conditions - 50.0) * 0.02
        employee["morale"] = _clamp_stat(float(employee["morale"]) + morale_delta)
        employee["productivity"] = calculate_productivity(employee, management_quality, safe_conditions)
        if float(employee["morale"]) < 30.0:
            employee["loyalty"] = _clamp_stat(float(employee["loyalty"]) - 0.6)
        elif float(employee["morale"]) > 75.0:
            employee["loyalty"] = _clamp_stat(float(employee["loyalty"]) + 0.2)
        if float(employee["loyalty"]) < 25.0 and randf() < 0.02:
            employee["status"] = "resigned"
            employee["assignment_id"] = ""
            employee["history_ids"].append({"day": day, "event": "resignation"})
            events.append({"type": "resignation", "employee_id": employee_id, "name": employee["name"]})
        average_morale += float(employee["morale"])
        average_productivity += float(employee["productivity"])
        employees[employee_id] = employee
    if active_count > 0:
        average_morale /= float(active_count)
        average_productivity /= float(active_count)
    return {"wages": wages, "active_count": active_count, "average_morale": average_morale, "average_productivity": average_productivity, "events": events}

func calculate_productivity(employee: Dictionary, management_quality: float = 50.0, equipment_quality: float = 50.0) -> float:
    var skill := clampf(float(employee.get("skill", 0.0)) / 100.0, 0.0, 1.0)
    var experience := clampf(0.75 + float(employee.get("experience", 0.0)) * 0.03, 0.75, 1.25)
    var morale := clampf(float(employee.get("morale", 50.0)) / 100.0, 0.5, 1.1)
    var management := clampf(0.7 + float(management_quality) / 200.0, 0.7, 1.2)
    var equipment := clampf(0.7 + float(equipment_quality) / 200.0, 0.7, 1.2)
    return clampf((0.55 + skill * 0.65) * experience * morale * management * equipment, 0.25, 2.5)

func active_employees() -> Array:
    var result: Array = []
    for employee in employees.values():
        if employee["status"] == "active":
            result.append(employee.duplicate(true))
    return result

func active_count() -> int:
    var count := 0
    for employee in employees.values():
        if employee["status"] == "active":
            count += 1
    return count

func total_wages() -> int:
    var total := 0
    for employee in employees.values():
        if employee["status"] == "active":
            total += int(employee["salary"])
    return total

func snapshot() -> Dictionary:
    # Canonical GameState uses `records`; keep the internal dictionary private.
    return {"next_id": next_id, "records": employees.duplicate(true)}

func restore(snapshot_data: Dictionary) -> void:
    var records = snapshot_data.get("records", snapshot_data.get("employees", {}))
    employees = records.duplicate(true) if records is Dictionary else {}
    next_id = max(1, int(snapshot_data.get("next_id", 1)))
    for employee_id in employees.keys():
        employees[employee_id] = _normalize_employee(employees[employee_id])

func _normalize_employee(raw: Dictionary) -> Dictionary:
    var employee := create_default_record()
    for key in raw.keys():
        employee[key] = raw[key]
    return employee

func create_default_record() -> Dictionary:
    return {
        "id": "", "name": "Unknown", "role": "Worker", "skill": 35.0,
        "experience": 0.0, "career_level": 1, "salary": BASE_WAGE,
        "loyalty": 65.0, "morale": 70.0, "ambition": 50.0,
        "personality": "Pragmatist", "productivity": 1.0,
        "specialization": "general", "assignment_type": "business",
        "assignment_id": "", "hire_day": 1, "promotion_day": 0,
        "status": "active", "relationship_ids": [], "history_ids": []
    }

func _generate_name() -> String:
    var first := ["Ayo", "Mina", "David", "Grace", "Tari", "Emeka", "Zainab", "Kelechi", "Ada", "Sam"]
    var last := ["Okoro", "James", "Cole", "Mensah", "Bello", "Ibrahim", "Eze", "Morgan"]
    return "%s %s" % [first[randi() % first.size()], last[randi() % last.size()]]

func _clamp_stat(value: float) -> float:
    return clampf(value, MIN_STAT, MAX_STAT)
