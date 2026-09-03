extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
    call_deferred("run")

func check(ok: bool, label: String) -> void:
    if ok:
        passed += 1
        print("PASS: " + label)
    else:
        failed += 1
        push_error("FAIL: " + label)

func run() -> void:
    var History = load("res://scripts/history_system.gd")
    check(History != null, "HistorySystem script loads")
    if History == null:
        quit(1)
        return
    var history = History.new()
    root.add_child(history)
    await process_frame
    check(history.has_event("founding"), "History records founding")
    history.record("restoration", 4, "Warehouse fully restored.", {"percent": 100}, "test|restoration")
    history.record("first_sale", 5, "First sale completed.", {"value": 1000}, "test|sale")
    history.record("first_profit", 5, "First profit recorded.", {"value": 250}, "test|profit")
    history.record("contract", 8, "Major customer contract signed.", {}, "test|contract")
    history.record("property_acquisition", 2, "Second property acquired.", {}, "test|property")
    history.record("expansion", 10, "New branch opened.", {}, "test|expansion")
    history.record("resource_acquisition", 11, "Resource site secured.", {}, "test|resource")
    history.record("alliance", 12, "Strategic alliance formed.", {}, "test|alliance")
    history.record("acquisition", 15, "Rival asset acquired.", {}, "test|acquisition")
    history.record("merger", 20, "Historic merger completed.", {}, "test|merger")
    history.record("crisis", 21, "Liquidity crisis survived.", {}, "test|crisis")
    history.record("bankruptcy", 30, "Bankruptcy event recorded.", {}, "test|bankruptcy")
    history.record("technology", 31, "Technology breakthrough.", {}, "test|technology")
    history.record("infrastructure", 32, "Infrastructure upgraded.", {}, "test|infrastructure")
    history.record("ranking", 33, "Company entered top ten.", {}, "test|ranking")
    history.record("world_event", 34, "Global market shock.", {}, "test|world")
    history.record_employee_milestone(18, "emp_james_001", "James", "Promoted to Senior Worker")
    check(history.timeline.size() >= 18, "Timeline stores permanent typed events")
    check(history.has_event("employee_milestone", "James"), "Employee milestones enter corporate history")
    check(history.get_notable_events().size() > 0, "Notable history is queryable")
    check(history.get_museum_collection().size() > 0, "Museum collection is generated from history")
    var snapshot: Dictionary = history.capture_state()
    var restored = History.new()
    root.add_child(restored)
    restored.restore_state(snapshot)
    check(restored.timeline.size() == history.timeline.size(), "History survives save/load snapshot")
    check(restored.has_event("merger"), "Historic merger survives save/load")
    check(restored.has_event("employee_milestone", "James"), "Employee milestone survives save/load")
    check(restored.get_legacy_summary().get("museum_items", 0) > 0, "Legacy summary exposes museum records")
    var duplicate_before: int = restored.timeline.size()
    restored.record("first_sale", 5, "First sale completed.", {}, "test|sale")
    check(restored.timeline.size() == duplicate_before, "Duplicate historical events are deduplicated")
    print("HISTORY SYSTEM RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
