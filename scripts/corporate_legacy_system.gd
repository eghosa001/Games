extends Node
class_name RenewCorporateLegacySystem

const CATEGORIES := ["founding", "products", "employees", "contracts", "acquisitions", "failures", "awards", "rankings", "technologies", "alliances", "crisis_recoveries"]
const MAX_ITEMS := 500

var artifacts: Dictionary = {}
var seen: Dictionary = {}
var last_day: Variant = -1

func _ready() -> void:
    for category in CATEGORIES: artifacts[category] = []
    _scan(_day())

func _process(_delta: float) -> void:
    var day: Variant = _day()
    if day != last_day:
        last_day = day
        _scan(day)

func record(category: String, title: String, details: Dictionary = {}, day: int = -1, signature: String = "") -> Dictionary:
    if not CATEGORIES.has(category): return {}
    var actual_day: Variant = _day() if day < 0 else day
    var key: Variant = signature if not signature.is_empty() else "%s|%d|%s" % [category, actual_day, title]
    if seen.has(key): return seen[key]
    var item: Variant = {"id":"legacy_%06d" % _total_count(), "category":category, "day":actual_day, "title":title, "details":details.duplicate(true)}
    artifacts[category].append(item)
    if artifacts[category].size() > MAX_ITEMS: artifacts[category].pop_front()
    seen[key] = item
    return item

func list_category(category: String) -> Array:
    return artifacts.get(category, []).duplicate(true)

func get_collection() -> Array:
    var result: Array = []
    for category in CATEGORIES:
        for item in artifacts.get(category, []): result.append(item.duplicate(true))
    result.sort_custom(func(a, b): return int(a.get("day", 0)) < int(b.get("day", 0)))
    return result

func summary() -> Dictionary:
    var result: Variant = {"total":_total_count()}
    for category in CATEGORIES: result[category] = artifacts[category].size()
    return result

func _scan(day: int) -> void:
    var main = get_tree().current_scene if get_tree() != null else null
    if main == null: return
    if bool(main.get("owned")) if main.get("owned") != null else false:
        record("founding", "First property — Old Warehouse", {"property":"Old Warehouse"}, 1, "first_property")
    if int(main.get("finished_goods")) if main.get("finished_goods") != null else 0 > 0:
        record("products", "First product — RENEW Goods", {"product":"RENEW Goods"}, day, "first_product")
    _scan_employees(day)
    _scan_research(day)
    _scan_rankings(day)
    _scan_alliances(day)
    _scan_history(day)
    _scan_hq(day)

func _scan_employees(day: int) -> void:
    var employees = get_node_or_null("/root/RenewEmployeeSystem")
    if employees == null: return
    for employee in employees.get_roster():
        var id: Variant = str(employee.get("id", ""))
        var name: Variant = str(employee.get("name", id))
        var hire_day: Variant = int(employee.get("hire_date", 1))
        record("employees", "%s — historic employee" % name, {"employee_id":id,"role":employee.get("role", ""),"specialization":employee.get("specialization", ""),"hire_day":hire_day,"status":employee.get("status", "active")}, hire_day, "employee|" + id)
        if int(employee.get("level", 1)) >= 4:
            record("employees", "%s reached executive level" % name, {"employee_id":id,"role":employee.get("role", "")}, day, "employee_exec|%s|%d" % [id, int(employee.get("level", 1))])

func _scan_research(day: int) -> void:
    var research = get_node_or_null("/root/RenewResearchSystem")
    if research == null: return
    for project in research.list_projects():
        var id: Variant = str(project.get("id", ""))
        var status: Variant = str(project.get("status", ""))
        if status == "failed":
            record("failures", "Failed project — %s" % project.get("name", id), {"project_id":id,"cost":project.get("cost", 0),"research_type":project.get("research_type", "")}, int(project.get("end_day", day)), "failed_project|" + id)
        elif status == "completed":
            record("technologies", "Research breakthrough — %s" % project.get("name", id), {"project_id":id,"outcome":project.get("outcome", "successful"),"discoveries":project.get("discoveries", [])}, int(project.get("end_day", day)), "research_complete|" + id)
            for discovery in project.get("discoveries", []):
                record("technologies", "Discovery — %s" % discovery.get("id", "unknown"), {"project_id":id,"discovery":discovery}, int(discovery.get("day", day)), "discovery|%s|%s" % [id, discovery.get("id", "")])

func _scan_rankings(day: int) -> void:
    var ranking = get_node_or_null("/root/RenewGlobalRankingSystem")
    if ranking == null: return
    for category in ["valuation", "revenue", "profit", "assets", "market_share", "employees", "technology", "infrastructure", "regional_presence", "reputation", "resource_control", "alliance_influence"]:
        var rows: Variant = ranking.get_ranking(category, 3)
        for row in rows:
            if str(row.get("id", "")) != "founder": continue
            var rank: Variant = int(row.get("rank", 99))
            if rank <= 3:
                record("rankings", "Top %d — %s ranking" % [rank, category.replace("_", " ").capitalize()], {"category":category,"rank":rank,"score":row.get("score", 0)}, day, "ranking|%s|%d|%d" % [category, day, rank])

func _scan_alliances(day: int) -> void:
    var alliance = get_node_or_null("/root/RenewAllianceSystem")
    if alliance == null: return
    for org in alliance.list_alliances():
        var id: Variant = str(org.get("id", ""))
        if not org.get("members", {}).has("founder") and not org.get("members", {}).has("player"): continue
        record("alliances", "Alliance milestone — %s" % org.get("name", id), {"alliance_id":id,"members":org.get("members", {}).size(),"treasury":org.get("treasury", 0),"reputation":org.get("reputation", 0)}, int(org.get("created_day", day)), "alliance|" + id)
        for project in org.get("projects", []):
            record("alliances", "Alliance project — %s" % project.get("name", "Project"), {"alliance_id":id,"type":project.get("type", "")}, int(project.get("started_day", day)), "alliance_project|%s|%s" % [id, project.get("name", "")])

func _scan_history(day: int) -> void:
    var history = get_node_or_null("/root/RenewHistorySystem")
    if history == null: return
    for event in history.get_chronological_timeline():
        var type: Variant = str(event.get("type", ""))
        var event_day: Variant = int(event.get("day", day))
        var title: Variant = str(event.get("title", "Historic event"))
        if type == "contract": record("contracts", title, event.get("details", {}), event_day, "history_contract|" + str(event.get("id", title)))
        elif type == "acquisition" or type == "merger": record("acquisitions", title, event.get("details", {}), event_day, "history_acquisition|" + str(event.get("id", title)))
        elif type == "ranking": record("rankings", title, event.get("details", {}), event_day, "history_ranking|" + str(event.get("id", title)))
        elif type == "technology": record("technologies", title, event.get("details", {}), event_day, "history_technology|" + str(event.get("id", title)))
        elif type == "alliance": record("alliances", title, event.get("details", {}), event_day, "history_alliance|" + str(event.get("id", title)))
        elif type == "bankruptcy": record("crisis_recoveries", title, event.get("details", {}), event_day, "history_bankruptcy|" + str(event.get("id", title)))

func _scan_hq(day: int) -> void:
    var hq = get_node_or_null("/root/RenewHeadquartersSystem")
    if hq == null: return
    for entry in hq.expansion_history:
        record("founding", "Headquarters milestone — %s" % entry.get("stage", "HQ"), entry, int(entry.get("day", day)), "hq_stage|%s" % entry.get("stage", ""))
    if hq.museum_available():
        record("founding", "Corporate Museum opened", {"hq_stage":hq.get_stage()}, day, "museum_opened")

func record_award(title: String, details: Dictionary = {}, day: int = -1) -> Dictionary:
    return record("awards", title, details, day, "award|%s|%d" % [title, _day() if day < 0 else day])

func record_crisis_recovery(title: String, details: Dictionary = {}, day: int = -1) -> Dictionary:
    return record("crisis_recoveries", title, details, day, "recovery|%s|%d" % [title, _day() if day < 0 else day])

func capture_state() -> Dictionary:
    return {"artifacts":artifacts.duplicate(true),"seen":seen.duplicate(true),"last_day":last_day}

func restore_state(state: Dictionary) -> void:
    for category in CATEGORIES: artifacts[category] = []
    var saved: Variant = state.get("artifacts", {})
    if saved is Dictionary:
        for category in CATEGORIES:
            if saved.get(category, []) is Array: artifacts[category] = saved[category].duplicate(true)
    seen = state.get("seen", {}).duplicate(true)
    last_day = int(state.get("last_day", -1))

func _total_count() -> int:
    var total: Variant = 0
    for category in CATEGORIES: total += artifacts[category].size()
    return total

func _day() -> int:
    var scene: Variant = get_tree().current_scene if get_tree() != null else null
    return int(scene.get("day")) if scene != null else 1
