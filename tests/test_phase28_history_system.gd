extends Node

func _ready()->void:
    var history=load("res://scripts/history_system.gd").new()
    add_child(history)
    assert(history.GAMEPLAY_EVENTS.size()==16)
    for event_name in history.GAMEPLAY_EVENTS:
        var result=history.record_gameplay_event(event_name,1,event_name,{"test":true},"phase28_test|"+event_name)
        assert(not result.is_empty())
        assert(str(result.details.get("gameplay_event",""))==event_name)
    assert(history.timeline.size()==16)
    assert(history.has_event("PROPERTY_ACQUIRED"))
    assert(history.has_event("CONTRACT_FULFILLED"))
    assert(history.has_event("COMPETITOR_DEFEATED"))
    print("Phase 28 history event checks passed.")
