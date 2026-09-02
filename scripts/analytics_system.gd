extends Node
class_name RenewAnalyticsSystem

const MAX_EVENTS := 5000
const FUNNEL_STEPS := ["new_game", "first_restoration", "first_business", "first_profit", "first_expansion", "first_major_strategic_decision"]

var events: Array = []
var counters: Dictionary = {}
var funnel: Dictionary = {}
var session_started_day := 1
var session_start_unix := 0
var last_day := 0

func _ready() -> void:
    session_start_unix = Time.get_unix_time_from_system()
    for step in FUNNEL_STEPS: funnel[step] = {"reached": false, "day": -1, "event_id": ""}
    track("new_game", {"day": _day(), "session_start": true}, true)

func _process(_delta: float) -> void:
    var day := _day()
    if day != last_day:
        last_day = day
        _scan_game_state(day)

func track(event_name: String, properties: Dictionary = {}, funnel_event := false) -> Dictionary:
    var day := _day()
    var record := {"id": "%s_%s_%s" % [event_name, day, events.size() + 1], "event": event_name, "day": day, "timestamp": Time.get_unix_time_from_system(), "properties": properties.duplicate(true)}
    events.append(record)
    counters[event_name] = int(counters.get(event_name, 0)) + 1
    if funnel_event: _advance_funnel(event_name, day, record["id"])
    if events.size() > MAX_EVENTS: events.pop_front()
    return record

func record(event_name: String, properties: Dictionary = {}) -> Dictionary:
    return track(event_name, properties, true)

func _advance_funnel(event_name: String, day: int, event_id: String) -> void:
    var index := FUNNEL_STEPS.find(event_name)
    if index < 0: return
    var reached_before := false
    for i in range(index):
        if not bool(funnel[FUNNEL_STEPS[i]].get("reached", false)): return
        reached_before = true
    if index > 0 and not reached_before: return
    if bool(funnel[event_name].get("reached", false)): return
    funnel[event_name] = {"reached": true, "day": day, "event_id": event_id}

func _scan_game_state(day: int) -> void:
    var main = get_tree().current_scene
    if main == null: return
    if bool(main.get("restoration")) or str(main.get("stage", "")) in ["Cleaned", "Repaired", "Rebuilt", "Installed", "Designed", "Operational"]:
        _once("first_restoration", {"stage": main.get("stage", "")})
    if bool(main.get("business_open", false)): _once("business_opening", {})
    if int(main.get("total_profit", 0)) > 0: _once("first_profit", {"total_profit": main.get("total_profit", 0)})
    if int(main.get("acquisition_count", 0)) > 0: _once("acquisition", {"count": main.get("acquisition_count", 0)})
    if int(main.get("employees", 0)) > 3: _once("hiring", {"employees": main.get("employees", 0)})
    if int(main.get("capacity_level", 1)) > 1: _once("expansion", {"capacity_level": main.get("capacity_level", 1)})
    if int(main.get("finished_goods", 0)) > 0: _once("production", {"finished_goods": main.get("finished_goods", 0)})
    if int(main.get("last_sales", 0)) > 0: _once("sales", {"sales": main.get("last_sales", 0)})
    if int(main.get("contract_days", 0)) > 0: _once("contracts", {})
    if int(main.get("debt", 0)) > 0: _once("loans", {"debt": main.get("debt", 0)})
    if int(main.get("acquisition_count", 0)) > 0: _once("acquisition", {"count": main.get("acquisition_count", 0)})
    var decision_count := int(main.get("strategic_decisions", 0))
    if decision_count > 0: _once("first_major_strategic_decision", {"count": decision_count})
    var alliance = get_node_or_null("/root/RenewAllianceSystem")
    if alliance != null and alliance.has_method("get_member_alliance") and alliance.get_member_alliance("founder") != null: _once("alliances", {})
    var research = get_node_or_null("/root/RenewResearchSystem")
    if research != null and research.has_method("list_projects") and research.list_projects().size() > 0: _once("technology", {})
    var bankruptcy = get_node_or_null("/root/RenewBankruptcySystem")
    if bankruptcy != null and bankruptcy.get("recovered", false): _once("bankruptcy_recovery", {})
    if day > 1: track("session_day", {"day": day})

func _once(event_name: String, properties: Dictionary) -> void:
    if int(counters.get(event_name, 0)) == 0: record(event_name, properties)

func session_end(reason := "quit") -> void:
    track("session_end", {"reason": reason, "duration_seconds": Time.get_unix_time_from_system() - session_start_unix, "day": _day()})

func get_event_count(event_name: String) -> int:
    return int(counters.get(event_name, 0))

func get_funnel() -> Dictionary:
    return funnel.duplicate(true)

func get_summary() -> Dictionary:
    return {"events": events.size(), "counters": counters.duplicate(true), "funnel": funnel.duplicate(true), "session_started_day": session_started_day}

func capture_state() -> Dictionary:
    return {"events": events.duplicate(true), "counters": counters.duplicate(true), "funnel": funnel.duplicate(true), "session_started_day": session_started_day, "last_day": last_day}

func restore_state(state: Dictionary) -> void:
    events = state.get("events", []).duplicate(true)
    counters = state.get("counters", {}).duplicate(true)
    funnel = state.get("funnel", funnel).duplicate(true)
    session_started_day = int(state.get("session_started_day", _day()))
    last_day = int(state.get("last_day", 0))

func _day() -> int:
    var scene = get_tree().current_scene if get_tree() != null else null
    return int(scene.get("day", 1)) if scene != null else 1
