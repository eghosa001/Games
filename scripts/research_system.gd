extends Node
class_name RenewResearchSystem

const STATUS_PROPOSED := "proposed"
const STATUS_ACTIVE := "active"
const STATUS_COMPLETED := "completed"
const STATUS_CANCELLED := "cancelled"
const STATUS_FAILED := "failed"

const TYPE_COMPANY := "company_rd"
const TYPE_UNIVERSITY := "university_partnership"
const TYPE_ALLIANCE := "alliance_research"
const TYPE_JOINT := "joint_research"

var projects: Dictionary = {}
var facilities: Dictionary = {}
var university_partners: Dictionary = {}
var next_project_id: Variant = 1
var next_facility_id: Variant = 1
var events: Array = []

var project_catalog: Variant = {
    "process_automation": {"name":"Process Automation", "duration":4, "cost":12000.0, "skills":["engineering","operations"], "uncertainty":0.12, "discovery":"automation_process"},
    "advanced_materials": {"name":"Advanced Materials", "duration":6, "cost":22000.0, "skills":["engineering","materials"], "uncertainty":0.20, "discovery":"new_material"},
    "energy_storage": {"name":"Energy Storage", "duration":7, "cost":30000.0, "skills":["energy","engineering"], "uncertainty":0.24, "discovery":"storage_chemistry"},
    "ai_optimization": {"name":"AI Optimization", "duration":8, "cost":40000.0, "skills":["computing","data"], "uncertainty":0.28, "discovery":"ai_method"},
    "mega_infrastructure": {"name":"Mega Infrastructure Research", "duration":10, "cost":65000.0, "skills":["engineering","construction"], "uncertainty":0.32, "discovery":"construction_method"}
}

func register_facility(owner_id: String, name: String, capacity: int = 1, level: int = 1, cost: float = 0.0) -> Dictionary:
    var id: Variant = "research_facility:%d" % next_facility_id
    next_facility_id += 1
    facilities[id] = {"id":id,"owner_id":owner_id,"name":name,"capacity":max(1,capacity),"level":max(1,level),"cost":cost,"utilization":0}
    return facilities[id].duplicate(true)

func register_university(partner_id: String, name: String, skill_bonus: Dictionary = {}) -> Dictionary:
    university_partners[partner_id] = {"id":partner_id,"name":name,"skill_bonus":skill_bonus,"trust":50.0,"projects":0}
    return university_partners[partner_id].duplicate(true)

func start_research(project_type: String, sponsor_id: String, research_type: String = TYPE_COMPANY, skills: Array = [], duration: int = 0, cost: float = -1.0, facility_id: String = "", partners: Array = []) -> Dictionary:
    if not project_catalog.has(project_type): return {"ok":false,"error":"unknown_research_project"}
    var spec: Dictionary = project_catalog[project_type]
    var project_id: Variant = "research:%d" % next_project_id
    next_project_id += 1
    var required_skills: Array = spec["skills"].duplicate()
    var provided: Array = skills.duplicate()
    var skill_match: Variant = _skill_match(required_skills, provided)
    var actual_cost: Variant = spec["cost"] if cost < 0.0 else cost
    var actual_duration: Variant = spec["duration"] if duration <= 0 else duration
    if facility_id != "" and facilities.has(facility_id):
        var facility: Dictionary = facilities[facility_id]
        actual_duration = max(1, int(ceil(float(actual_duration) / (1.0 + 0.15 * max(0, int(facility["level"]) - 1)))))
    projects[project_id] = {"id":project_id,"type":project_type,"name":spec["name"],"sponsor_id":sponsor_id,"research_type":research_type,"status":STATUS_ACTIVE,"start_day":_day(),"end_day":_day()+actual_duration,"duration":actual_duration,"cost":actual_cost,"spent":0.0,"required_skills":required_skills,"provided_skills":provided,"skill_match":skill_match,"uncertainty":float(spec["uncertainty"]),"discovery":spec["discovery"],"facility_id":facility_id,"partners":partners.duplicate(),"progress":0.0,"outcome":"pending","discoveries":[]}
    if facility_id != "" and facilities.has(facility_id): facilities[facility_id]["utilization"] = int(facilities[facility_id]["utilization"]) + 1
    for partner in partners:
        if university_partners.has(str(partner)): university_partners[str(partner)]["projects"] = int(university_partners[str(partner)]["projects"]) + 1
    _event("Research started: %s" % spec["name"])
    return {"ok":true,"project":projects[project_id].duplicate(true)}

func process_day(day: int) -> void:
    for id in projects.keys():
        var p: Dictionary = projects[id]
        if p["status"] != STATUS_ACTIVE: continue
        var total: Variant = max(1, int(p["duration"]))
        p["progress"] = clamp(float(day - int(p["start_day"])) / float(total), 0.0, 1.0)
        p["spent"] = min(float(p["cost"]), float(p["cost"]) * p["progress"])
        if day >= int(p["end_day"]): _complete_project(p)
        projects[id] = p

func _complete_project(p: Dictionary) -> void:
    var roll: Variant = randf()
    var skill_bonus: Variant = 0.15 * float(p["skill_match"])
    var partner_bonus: Variant = min(0.25, 0.05 * p["partners"].size())
    var success_threshold: Variant = clamp(0.72 + skill_bonus + partner_bonus - float(p["uncertainty"]), 0.15, 0.95)
    var discovery_chance: Variant = clamp(0.08 + 0.12 * float(p["skill_match"]) + partner_bonus, 0.05, 0.65)
    if roll <= success_threshold:
        p["status"] = STATUS_COMPLETED
        p["outcome"] = "successful"
        if randf() <= discovery_chance:
            p["discoveries"].append({"id":p["discovery"],"day":_day(),"novel":true})
            _event("Research discovery: %s" % p["name"])
    else:
        p["status"] = STATUS_FAILED
        p["outcome"] = "failed"
    if facilities.has(p["facility_id"]): facilities[p["facility_id"]]["utilization"] = max(0, int(facilities[p["facility_id"]]["utilization"]) - 1)
    projects[p["id"]] = p

func has_discovery(discovery_id: String) -> bool:
    for p in projects.values():
        for d in p.get("discoveries", []):
            if str(d.get("id", "")) == discovery_id: return true
    return false

func get_project(project_id: String) -> Dictionary: return projects.get(project_id, {}).duplicate(true)
func list_projects(owner_id: String = "") -> Array:
    var out: Array = []
    for p in projects.values():
        if owner_id == "" or str(p["sponsor_id"]) == owner_id: out.append(p.duplicate(true))
    return out
func list_facilities(owner_id: String = "") -> Array:
    var out: Array = []
    for f in facilities.values():
        if owner_id == "" or str(f["owner_id"]) == owner_id: out.append(f.duplicate(true))
    return out

func _skill_match(required: Array, provided: Array) -> float:
    if required.is_empty(): return 1.0
    var hits: Variant = 0
    for skill in required:
        if provided.has(skill): hits += 1
    return float(hits) / float(required.size())

func _day() -> int:
    var scene: Variant = get_tree().current_scene if get_tree() != null else null
    return int(scene.get("day")) if scene != null else 1

func _event(text: String) -> void:
    events.append({"day":_day(),"text":text})
    if events.size() > 100: events.pop_front()

func capture_state() -> Dictionary:
    return {"projects":projects.duplicate(true),"facilities":facilities.duplicate(true),"university_partners":university_partners.duplicate(true),"next_project_id":next_project_id,"next_facility_id":next_facility_id,"events":events.duplicate(true)}

func restore_state(state: Dictionary) -> void:
    projects = state.get("projects", {}).duplicate(true)
    facilities = state.get("facilities", {}).duplicate(true)
    university_partners = state.get("university_partners", {}).duplicate(true)
    next_project_id = int(state.get("next_project_id", 1))
    next_facility_id = int(state.get("next_facility_id", 1))
    events = state.get("events", []).duplicate(true)

func _process(_delta: float) -> void:
    var scene: Variant = get_tree().current_scene if get_tree() != null else null
    if scene == null: return
    var day: Variant = int(scene.get("day"))
    if day <= 0: return
    if day != _last_day:
        _last_day = day
        process_day(day)

var _last_day: Variant = -1
