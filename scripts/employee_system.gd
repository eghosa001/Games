extends RefCounted
class_name EmployeeSystem

## Individual employees replace the prototype's anonymous employee count.
## The system is intentionally self-contained so it can be integrated into
## GameState/main.gd without forcing a large rewrite of the existing loop.

const STARTER_EMPLOYEES := [
    {"name":"James Carter", "role":"Carpenter", "skill":72, "experience":14, "salary":180, "loyalty":81, "personality":"Steady", "ambition":64},
    {"name":"Amara Okafor", "role":"Sales Associate", "skill":68, "experience":10, "salary":180, "loyalty":76, "personality":"Outgoing", "ambition":72},
    {"name":"Daniel Mensah", "role":"Workshop Assistant", "skill":61, "experience":8, "salary":180, "loyalty":70, "personality":"Reliable", "ambition":55}
]

var employees: Array[Dictionary] = []
var next_employee_id := 1

func _init() -> void:
    reset()

func reset() -> void:
    employees.clear()
    next_employee_id = 1
    for template in STARTER_EMPLOYEES:
        add_employee(template.duplicate(true))

func add_employee(data: Dictionary) -> Dictionary:
    var employee := data.duplicate(true)
    employee["id"] = next_employee_id
    next_employee_id += 1
    employee["skill"] = clampi(int(employee.get("skill", 50)), 1, 100)
    employee["experience"] = maxi(0, int(employee.get("experience", 0)))
    employee["salary"] = maxi(1, int(employee.get("salary", 180)))
    employee["loyalty"] = clampi(int(employee.get("loyalty", 60)), 0, 100)
    employee["ambition"] = clampi(int(employee.get("ambition", 50)), 0, 100)
    employees.append(employee)
    return employee

func hire(name: String, role: String, skill: int = 50, salary: int = 180, personality: String = "Reliable", ambition: int = 50) -> Dictionary:
    return add_employee({
        "name": name,
        "role": role,
        "skill": skill,
        "experience": 0,
        "salary": salary,
        "loyalty": 60,
        "personality": personality,
        "ambition": ambition
    })

func get_employee(id: int) -> Dictionary:
    for employee in employees:
        if int(employee.get("id", -1)) == id:
            return employee
    return {}

func daily_wages() -> int:
    var total := 0
    for employee in employees:
        total += int(employee.get("salary", 0))
    return total

func average_skill() -> float:
    if employees.is_empty():
        return 0.0
    var total := 0
    for employee in employees:
        total += int(employee.get("skill", 0))
    return float(total) / float(employees.size())

func production_capacity_bonus() -> int:
    # Every 25 points above a 50-skill baseline contributes one effective unit.
    return maxi(0, int(floor((average_skill() - 50.0) / 25.0)))

func advance_day(profit: int) -> Array[Dictionary]:
    var stories: Array[Dictionary] = []
    for employee in employees:
        employee["experience"] = int(employee.get("experience", 0)) + 1
        var performance := clampi(int(employee.get("skill", 50)) + randi_range(-3, 3), 1, 100)
        if profit > 0:
            employee["loyalty"] = clampi(int(employee.get("loyalty", 60)) + 1, 0, 100)
        elif profit < 0:
            employee["loyalty"] = clampi(int(employee.get("loyalty", 60)) - 1, 0, 100)
        if int(employee["experience"]) % 30 == 0:
            employee["skill"] = clampi(int(employee.get("skill", 50)) + 1, 1, 100)
            stories.append({"type":"milestone", "employee":employee["name"], "text":"%s gained experience and improved their skill." % employee["name"]})
        if int(employee.get("ambition", 50)) >= 80 and int(employee.get("experience", 0)) % 45 == 0:
            stories.append({"type":"career", "employee":employee["name"], "text":"%s is ready for greater responsibility." % employee["name"]})
        employee["last_performance"] = performance
    return stories

func promote(id: int, new_role: String, salary_increase: int = 75) -> Dictionary:
    var employee := get_employee(id)
    if employee.is_empty():
        return {"ok":false, "message":"Employee not found."}
    employee["role"] = new_role
    employee["salary"] = int(employee.get("salary", 180)) + salary_increase
    employee["loyalty"] = clampi(int(employee.get("loyalty", 60)) + 8, 0, 100)
    return {"ok":true, "employee":employee, "message":"%s promoted to %s." % [employee["name"], new_role]}

func serialize() -> Dictionary:
    return {"employees":employees.duplicate(true), "next_employee_id":next_employee_id}

func deserialize(data: Dictionary) -> void:
    employees.clear()
    next_employee_id = maxi(1, int(data.get("next_employee_id", 1)))
    for employee in data.get("employees", []):
        add_employee(employee)
