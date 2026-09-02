extends Node
class_name RenewHistorySystem

## Permanent corporate memory for RENEW.
## Unlike the transient activity log, these records are typed, deduplicated,
## saveable, and intended to remain meaningful for the entire company lifetime.
const SYSTEM_VERSION := 1
const MAX_EVENTS := 5000

const TYPES := [
    "founding", "restoration", "first_sale", "first_profit", "employee_milestone",
    "contract", "property_acquisition", "expansion", "resource_acquisition", "alliance",
    "acquisition", "merger", "crisis", "bankruptcy", "technology", "infrastructure",
    "ranking", "world_event", "investment", "corporate_war", "milestone", "general"
]

var timeline: Array[Dictionary] = []
var legacy: Dictionary = {
    "founder": "",
    "company_name": "RENEW",
    "founded_day": 1,
    "notable_events": 0,
    "properties_acquired": 0,
    "expansions": 0,
    "alliances": 0,
    "acquisitions": 0,
    "contracts": 0,
    "crises": 0,
    "employees_milestones": 0,
    "museum_unlocks": []
}

var _seen_signatures: Dictionary = {}
var _last_state: Dictionary = {}
var _last_log_index := 0

func _ready() -> void:
    if timeline.is_empty():
        record("founding", 1, "RENEW was founded.", {"legacy": true}, "company_founded")

func _process(_delta: float) -> void:
    _observe_game()

func record(event_type: String, day: int, title: String, details: Dictionary = {}, signature: String = "") -> Dictionary:
    var kind := event_type if TYPES.has(event_type) else "general"
    var key := signature if not signature.is_empty() else "%s|%s|%s" % [kind, day, title]
    if _seen_signatures.has(key):
        return _seen_signatures[key]
    var event := {
        "id": "hist_%06d" % (timeline.size() + 1),
        "day": max(1, day),
        "type": kind,
        "title": title,
        "details": details.duplicate(true),
        "importance": _importance(kind),
        "recorded_at": Time.get_datetime_string_from_system(true)
    }
    timeline.append(event)
    if timeline.size() > MAX_EVENTS:
        timeline.pop_front()
    _seen_signatures[key] = event
    _update_legacy(kind)
    return event

func record_employee_milestone(day: int, employee_id: String, employee_name: String, milestone: String, details: Dictionary = {}) -> Dictionary:
    var payload := details.duplicate(true)
    payload["employee_id"] = employee_id
    payload["employee_name"] = employee_name
    payload["milestone"] = milestone
    return record("employee_milestone", day, "%s: %s" % [employee_name, milestone], payload, "employee|%s|%s|%s" % [employee_id, milestone, day])

func ingest_activity_log(lines: Array, day: int) -> int:
    var added := 0
    for line in lines:
        var text := str(line)
        var mapped := _classify_log(text)
        if mapped.is_empty(): continue
        var before := timeline.size()
        record(str(mapped["type"]), day, str(mapped["title"]), {"source_log": text}, str(mapped["signature"]))
        if timeline.size() > before: added += 1
    return added

func get_timeline(filter_type: String = "", limit: int = 100) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var start := max(0, timeline.size() - max(1, limit))
    for i in range(timeline.size() - 1, start - 1, -1):
        var event := timeline[i]
        if filter_type.is_empty() or str(event.get("type", "")) == filter_type:
            result.append(event.duplicate(true))
    return result

func get_chronological_timeline() -> Array[Dictionary]:
    return timeline.duplicate(true)

func get_notable_events(limit: int = 20) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for i in range(timeline.size() - 1, -1, -1):
        if int(timeline[i].get("importance", 1)) >= 3:
            result.append(timeline[i].duplicate(true))
            if result.size() >= limit: break
    return result

func get_museum_collection() -> Array[Dictionary]:
    var collection: Array[Dictionary] = []
    for event in timeline:
        if int(event.get("importance", 1)) >= 3:
            collection.append({
                "id": event.get("id", ""),
                "day": event.get("day", 1),
                "era": _era(int(event.get("day", 1))),
                "title": event.get("title", ""),
                "type": event.get("type", "general"),
                "details": event.get("details", {}).duplicate(true)
            })
    return collection

func get_legacy_summary() -> Dictionary:
    var result := legacy.duplicate(true)
    result["timeline_length"] = timeline.size()
    result["museum_items"] = get_museum_collection().size()
    result["years_recorded"] = max(1, int(ceil(float(_latest_day()) / 365.0)))
    return result

func has_event(event_type: String, title_contains: String = "") -> bool:
    for event in timeline:
        if str(event.get("type", "")) != event_type: continue
        if title_contains.is_empty() or str(event.get("title", "")).to_lower().contains(title_contains.to_lower()): return true
    return false

func capture_state() -> Dictionary:
    return {"system_version": SYSTEM_VERSION, "timeline": timeline.duplicate(true), "legacy": legacy.duplicate(true)}

func restore_state(snapshot: Dictionary) -> void:
    if snapshot.is_empty():
        timeline.clear()
        legacy = {"founder":"", "company_name":"RENEW", "founded_day":1, "notable_events":0, "properties_acquired":0, "expansions":0, "alliances":0, "acquisitions":0, "contracts":0, "crises":0, "bankruptcy":0, "employees_milestones":0, "museum_unlocks":[]}
        _seen_signatures.clear()
        _ready()
        return
    timeline = snapshot.get("timeline", []).duplicate(true)
    legacy = snapshot.get("legacy", legacy).duplicate(true)
    _seen_signatures.clear()
    for event in timeline:
        var key := "%s|%s|%s" % [event.get("type", "general"), event.get("day", 1), event.get("title", "")]
        _seen_signatures[key] = event
    _ensure_legacy_fields()

func _observe_game() -> void:
    var tree := get_tree()
    if tree == null: return
    var main = tree.current_scene
    if main == null: return
    var day := int(main.get("day"))
    if not _last_state.has("initialized"):
        _last_state = {"initialized": true, "owned": bool(main.get("owned")), "restoration": int(main.get("restoration")), "business_open": bool(main.get("business_open")), "sales": int(main.get("last_sales")), "profit": int(main.get("total_profit")), "acquisitions": int(main.get("acquisition_count")), "contract_days": int(main.get("contract_days")), "cash": int(main.get("cash")), "expansions": _count_owned(main, "properties"), "resources": _count_owned(main, "resource_sites")}
        return
    _detect_transitions(main, day)
    var logs = main.get("log_lines")
    if logs is Array:
        var arr: Array = logs
        if arr.size() > _last_log_index:
            var recent := arr.slice(_last_log_index)
            ingest_activity_log(recent, day)
            _last_log_index = arr.size()

func _detect_transitions(main, day: int) -> void:
    var owned_now := bool(main.get("owned"))
    if owned_now and not bool(_last_state.get("owned", false)):
        record("property_acquisition", day, "Old Warehouse acquired.", {"company": "RENEW"}, "property|old_warehouse")
    var restoration_now := int(main.get("restoration"))
    if restoration_now >= 100 and int(_last_state.get("restoration", 0)) < 100:
        record("restoration", day, "The founding property was fully restored.", {"restoration": 100}, "restoration|100")
    var open_now := bool(main.get("business_open"))
    if open_now and not bool(_last_state.get("business_open", false)):
        record("founding", day, "RENEW Goods opened for business.", {}, "business|opened")
    var sales_now := int(main.get("last_sales"))
    if sales_now > 0 and int(_last_state.get("sales", 0)) <= 0:
        record("first_sale", day, "RENEW recorded its first sale.", {"sales": sales_now}, "financial|first_sale")
    var lifetime_profit := int(main.get("total_profit"))
    if lifetime_profit > 0 and int(_last_state.get("profit", 0)) <= 0:
        record("first_profit", day, "RENEW recorded its first profit.", {"profit": lifetime_profit}, "financial|first_profit")
    var acquisitions := int(main.get("acquisition_count"))
    if acquisitions > int(_last_state.get("acquisitions", 0)):
        record("acquisition", day, "RENEW expanded through a strategic acquisition.", {"count": acquisitions}, "acquisition|%d" % acquisitions)
    var contract_days := int(main.get("contract_days"))
    if contract_days > 0 and int(_last_state.get("contract_days", 0)) <= 0:
        record("contract", day, "A major customer contract was signed.", {"days": contract_days}, "contract|%d" % day)
    var expansions := _count_owned(main, "properties")
    if expansions > int(_last_state.get("expansions", 0)):
        record("expansion", day, "RENEW added an expansion property to its empire.", {"count": expansions}, "expansion|%d" % expansions)
    var resources := _count_owned(main, "resource_sites")
    if resources > int(_last_state.get("resources", 0)):
        record("resource_acquisition", day, "RENEW secured a new strategic resource site.", {"count": resources}, "resource|%d" % resources)
    var cash := int(main.get("cash"))
    if cash <= 0 and int(_last_state.get("cash", 1)) > 0:
        record("crisis", day, "RENEW entered a cash crisis.", {}, "crisis|cash|%d" % day)
    _last_state["owned"] = owned_now
    _last_state["restoration"] = restoration_now
    _last_state["business_open"] = open_now
    _last_state["sales"] = sales_now
    _last_state["profit"] = lifetime_profit
    _last_state["acquisitions"] = acquisitions
    _last_state["contract_days"] = contract_days
    _last_state["cash"] = cash
    _last_state["expansions"] = expansions
    _last_state["resources"] = resources

func _count_owned(main, property_name: String) -> int:
    var module = main.get(property_name)
    if module == null: return 0
    var count := 0
    if module is Array:
        for item in module:
            if item is Dictionary and bool(item.get("owned", false)): count += 1
    elif module is Object:
        var values = module.get("properties") if property_name == "properties" else module.get("resource_sites")
        if values is Array:
            for item in values:
                if item is Dictionary and bool(item.get("owned", false)): count += 1
    return count

func _classify_log(text: String) -> Dictionary:
    var upper := text.to_upper()
    if upper.begins_with("ACQUIRED:"): return {"type":"property_acquisition", "title":text, "signature":"log|" + text}
    if upper.begins_with("RESTORATION:") or upper.contains("RESTORATION COMPLETE"): return {"type":"restoration", "title":text, "signature":"log|" + text}
    if upper.begins_with("PRODUCTION:"): return {}
    if upper.begins_with("SUPPLY ORDER:"): return {"type":"resource_acquisition", "title":text, "signature":"log|" + text}
    if upper.begins_with("CONTRACT:"): return {"type":"contract", "title":text, "signature":"log|" + text}
    if upper.begins_with("ALLIANCE:") or upper.begins_with("RELATIONSHIP:"): return {"type":"alliance", "title":text, "signature":"log|" + text}
    if upper.begins_with("ACQUISITION:"): return {"type":"acquisition", "title":text, "signature":"log|" + text}
    if upper.begins_with("EVENT:"): return {"type":"world_event", "title":text, "signature":"log|" + text}
    if upper.begins_with("CORPORATE WAR:"): return {"type":"corporate_war", "title":text, "signature":"log|" + text}
    if upper.begins_with("TAKEOVER ATTEMPT:"): return {"type":"crisis", "title":text, "signature":"log|" + text}
    if upper.begins_with("INVESTMENT:"): return {"type":"investment", "title":text, "signature":"log|" + text}
    if upper.begins_with("UPGRADE:") or upper.begins_with("TRANSPORT:"): return {"type":"infrastructure", "title":text, "signature":"log|" + text}
    if upper.begins_with("MARKETING:") or upper.begins_with("TECHNOLOGY:"): return {"type":"technology", "title":text, "signature":"log|" + text}
    if upper.begins_with("MILESTONE:"): return {"type":"milestone", "title":text, "signature":"log|" + text}
    if upper.begins_with("DAY "): return {}
    return {}

func _importance(kind: String) -> int:
    match kind:
        "founding", "first_sale", "first_profit", "bankruptcy", "merger", "acquisition", "corporate_war": return 5
        "restoration", "property_acquisition", "employee_milestone", "expansion", "alliance", "crisis", "ranking", "world_event", "milestone": return 4
        "contract", "resource_acquisition", "technology", "infrastructure", "investment": return 3
    return 1

func _update_legacy(kind: String) -> void:
    legacy["notable_events"] = int(legacy.get("notable_events", 0)) + 1
    match kind:
        "property_acquisition": legacy["properties_acquired"] = int(legacy.get("properties_acquired", 0)) + 1
        "expansion": legacy["expansions"] = int(legacy.get("expansions", 0)) + 1
        "alliance": legacy["alliances"] = int(legacy.get("alliances", 0)) + 1
        "acquisition", "merger": legacy["acquisitions"] = int(legacy.get("acquisitions", 0)) + 1
        "contract": legacy["contracts"] = int(legacy.get("contracts", 0)) + 1
        "crisis", "bankruptcy": legacy["crises"] = int(legacy.get("crises", 0)) + 1
        "employee_milestone": legacy["employees_milestones"] = int(legacy.get("employees_milestones", 0)) + 1

func _latest_day() -> int:
    if timeline.is_empty(): return 1
    return int(timeline.back().get("day", 1))

func _era(day: int) -> String:
    var year := int(floor(float(max(1, day) - 1) / 365.0)) + 1
    return "Year %d" % year

func _ensure_legacy_fields() -> void:
    for key in ["founder","company_name","founded_day","notable_events","properties_acquired","expansions","alliances","acquisitions","contracts","crises","employees_milestones","museum_unlocks"]:
        if not legacy.has(key): legacy[key] = [] if key == "museum_unlocks" else 0
