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
    check(history.GAMEPLAY_EVENTS.size() == 17, "Seventeen gameplay events registered")
    for event_name in history.GAMEPLAY_EVENTS:
        var result = history.record_gameplay_event(event_name, 1, event_name, {"test": true}, "phase28_test|" + event_name)
        check(not result.is_empty(), "Gameplay event recorded: %s" % event_name)
        check(str(result.details.get("gameplay_event", "")) == event_name, "Gameplay event round-trips: %s" % event_name)
    check(history.timeline.size() == 18, "Timeline holds founding plus all recorded events")
    check(history.has_event("PROPERTY_ACQUIRED"), "Acquisition milestone queryable")
    check(history.has_event("CONTRACT_FULFILLED"), "Contract milestone queryable")
    check(history.has_event("COMPETITOR_DEFEATED"), "Competition milestone queryable")
    print("PHASE 28 RESULT: %d passed, %d failed" % [passed, failed])
    history.queue_free()
    await process_frame
    quit(1 if failed > 0 else 0)
