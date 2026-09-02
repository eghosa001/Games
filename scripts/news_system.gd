extends Node
class_name RenewNewsSystem

## RENEW DAILY: personalized newspaper generated from actual simulation events.
## No random headlines are invented; every story is derived from game state,
## corporate history, employee history, or the live activity log.
const SYSTEM_VERSION := 1
const MAX_ARCHIVE := 2000
const MAX_STORIES_PER_ISSUE := 12
const SECTIONS := ["Your Company", "People", "Market", "Rivals", "Supply Chain", "Contracts", "Opportunities", "Regions", "World", "Corporate History"]

var archive: Array[Dictionary] = []
var current_issue: Dictionary = {}
var _last_day := -1
var _seen_sources: Dictionary = {}

func _ready() -> void:
    call_deferred("_initialize_from_game")

func _process(_delta: float) -> void:
    _watch_day()

func _initialize_from_game() -> void:
    var main = _main()
    if main == null: return
    var day := int(main.get("day"))
    if _last_day < 0:
        _last_day = day
    if current_issue.is_empty():
        generate_daily(day)

func _watch_day() -> void:
    var main = _main()
    if main == null: return
    var day := int(main.get("day"))
    if _last_day < 0:
        _last_day = day
        return
    if day != _last_day:
        _last_day = day
        generate_daily(day)

func generate_daily(day: int) -> Dictionary:
    var candidates := _collect_events(day)
    candidates.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
    var stories: Array[Dictionary] = []
    var used_sections: Dictionary = {}
    for candidate in candidates:
        if stories.size() >= MAX_STORIES_PER_ISSUE: break
        var section := str(candidate.get("section", "Your Company"))
        var section_count := int(used_sections.get(section, 0))
        if section_count >= 3: continue
        var story := candidate.duplicate(true)
        story.erase("score")
        story["day"] = day
        story["story_id"] = "news_%06d" % (archive.size() + stories.size() + 1)
        stories.append(story)
        used_sections[section] = section_count + 1
    if stories.is_empty():
        stories.append(_state_story(day))
    current_issue = {"system_version": SYSTEM_VERSION, "day": day, "date_label": "Day %d" % day, "stories": stories}
    archive.append(current_issue.duplicate(true))
    if archive.size() > MAX_ARCHIVE: archive.pop_front()
    return current_issue.duplicate(true)

func get_current_issue() -> Dictionary:
    return current_issue.duplicate(true)

func get_archive(limit: int = 30) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var start := max(0, archive.size() - max(1, limit))
    for i in range(archive.size() - 1, start - 1, -1):
        result.append(archive[i].duplicate(true))
    return result

func get_issue(day: int) -> Dictionary:
    if int(current_issue.get("day", -1)) == day: return current_issue.duplicate(true)
    for issue in archive:
        if int(issue.get("day", -1)) == day: return issue.duplicate(true)
    return {}

func capture_state() -> Dictionary:
    return {"system_version": SYSTEM_VERSION, "archive": archive.duplicate(true), "current_issue": current_issue.duplicate(true), "last_day": _last_day}

func restore_state(snapshot: Dictionary) -> void:
    archive = snapshot.get("archive", []).duplicate(true)
    current_issue = snapshot.get("current_issue", {}).duplicate(true)
    _last_day = int(snapshot.get("last_day", -1))
    _seen_sources.clear()
    for issue in archive:
        for story in issue.get("stories", []):
            _seen_sources[str(story.get("source_key", ""))] = true
    if current_issue.is_empty() and not archive.is_empty(): current_issue = archive.back().duplicate(true)

func _collect_events(day: int) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var main = _main()
    var history = get_node_or_null("/root/RenewHistorySystem")
    var employees = get_node_or_null("/root/RenewEmployeeSystem")
    if history != null:
        for event in history.get_timeline("", 120):
            var event_day := int(event.get("day", 1))
            if event_day > day: continue
            var age := day - event_day
            if age > 7: continue
            var story := _history_story(event, day, age)
            if not story.is_empty(): result.append(story)
    if employees != null:
        for event in employees.get("history"):
            var event_day := int(event.get("day", 1))
            if event_day > day or day - event_day > 3: continue
            var story := _employee_story(event, day)
            if not story.is_empty(): result.append(story)
    if main != null:
        var logs = main.get("log_lines")
        if logs is Array:
            var start := max(0, logs.size() - 25)
            for i in range(start, logs.size()):
                var story := _log_story(str(logs[i]), day)
                if not story.is_empty(): result.append(story)
        var warnings = main.get("message")
        if warnings != null and not str(warnings).is_empty():
            result.append(_make_story("Your Company", "Company desk", str(warnings), "A live company update from today's operations.", 32, "message|%d|%s" % [day, str(warnings)]))
    return result

func _history_story(event: Dictionary, day: int, age: int) -> Dictionary:
    var kind := str(event.get("type", "general"))
    var title := str(event.get("title", "Historic event"))
    var details: Dictionary = event.get("details", {})
    var section := "Corporate History"
    var score := int(event.get("importance", 1)) * 15 + (25 if age == 0 else 10)
    match kind:
        "employee_milestone": section = "People"
        "contract": section = "Contracts"
        "resource_acquisition": section = "Supply Chain"
        "alliance", "acquisition", "merger", "corporate_war": section = "Rivals"
        "world_event": section = "World"
        "ranking": section = "Market"
        "expansion", "property_acquisition": section = "Regions"
        "investment", "technology", "infrastructure", "first_sale", "first_profit", "restoration", "founding": section = "Your Company"
        "crisis", "bankruptcy": section = "Your Company"
    var kicker := _kicker(kind)
    return _make_story(section, kicker, title, _details(details), score, "history|%s" % str(event.get("id", title)))

func _employee_story(event: Dictionary, _day: int) -> Dictionary:
    var employee_id := str(event.get("employee_id", ""))
    var employee = _employee_by_id(employee_id)
    var name := str(event.get("employee_name", employee.get("name", "Employee")))
    var action := str(event.get("action", event.get("type", "milestone")))
    var role := str(employee.get("role", "team member"))
    var title := "%s — %s" % [name, action.replace("_", " ").capitalize()]
    var body := "%s, RENEW %s, had a notable personnel event: %s." % [name, role, _details(event)]
    var score := 52
    if action == "promoted": score = 90
    return _make_story("People", "People desk", title, body, score, "employee|%s|%s|%s" % [employee_id, action, str(event.get("day", 1))])

func _log_story(text: String, day: int) -> Dictionary:
    var upper := text.to_upper()
    var section := "Your Company"
    var kicker := "Company desk"
    var score := 28
    if upper.begins_with("CONTRACT:"): section = "Contracts"; kicker = "Contracts desk"; score = 70
    elif upper.begins_with("SUPPLY ORDER:"): section = "Supply Chain"; kicker = "Supply desk"; score = 60
    elif upper.begins_with("ALLIANCE:") or upper.begins_with("RELATIONSHIP:"): section = "Rivals"; kicker = "Corporate desk"; score = 58
    elif upper.begins_with("ACQUISITION:") or upper.begins_with("CORPORATE WAR:"): section = "Rivals"; kicker = "Competitive desk"; score = 88
    elif upper.begins_with("EVENT:"): section = "World"; kicker = "World desk"; score = 64
    elif upper.begins_with("TAKEOVER ATTEMPT:"): section = "Rivals"; kicker = "Breaking"; score = 96
    elif upper.begins_with("TECHNOLOGY:") or upper.begins_with("UPGRADE:"): section = "Market"; kicker = "Industry desk"; score = 55
    elif upper.begins_with("TRANSPORT:"): section = "Supply Chain"; kicker = "Logistics desk"; score = 55
    elif upper.begins_with("MARKETING:"): section = "Market"; kicker = "Market desk"; score = 45
    else: return {}
    return _make_story(section, kicker, text, "Reported from the live RENEW simulation log.", score, "log|%d|%s" % [day, text])

func _state_story(day: int) -> Dictionary:
    var main = _main()
    if main == null: return _make_story("Your Company", "Edition note", "No new major events today.", "The newsroom is watching the simulation for developments.", 1, "empty|%d" % day)
    var cash := int(main.get("cash"))
    var reputation := int(main.get("reputation"))
    return _make_story("Your Company", "Daily snapshot", "RENEW closes Day %d with $%d cash and %d reputation." % [day, cash, reputation], "A factual snapshot of the company at the close of the day.", 12, "snapshot|%d" % day)

func _make_story(section: String, kicker: String, headline: String, body: String, score: int, source_key: String) -> Dictionary:
    if source_key.is_empty() or _seen_sources.has(source_key): return {}
    _seen_sources[source_key] = true
    return {"section": section, "kicker": kicker, "headline": headline, "body": body, "source_key": source_key, "score": score}

func _kicker(kind: String) -> String:
    match kind:
        "founding": return "Company desk"
        "restoration": return "Restoration desk"
        "first_sale", "first_profit": return "Business desk"
        "employee_milestone": return "People desk"
        "contract": return "Contracts desk"
        "resource_acquisition": return "Supply desk"
        "alliance", "acquisition", "merger", "corporate_war": return "Competitive desk"
        "crisis", "bankruptcy": return "Breaking"
        "technology", "infrastructure": return "Industry desk"
        "ranking": return "Markets desk"
        "world_event": return "World desk"
    return "Corporate desk"

func _details(details: Dictionary) -> String:
    if details.is_empty(): return ""
    var parts: Array[String] = []
    for key in details.keys():
        if str(key) in ["source_log", "employee_id", "employee_name"]: continue
        parts.append("%s: %s" % [str(key).replace("_", " ").capitalize(), str(details[key])])
    return "; ".join(parts)

func _employee_by_id(employee_id: String) -> Dictionary:
    var employees = get_node_or_null("/root/RenewEmployeeSystem")
    if employees == null: return {}
    return employees.get_employee(employee_id)

func _main():
    var tree := get_tree()
    if tree == null: return null
    return tree.current_scene
