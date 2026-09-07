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
    var history = root.get_node_or_null("RenewHistorySystem")
    var news = root.get_node_or_null("RenewNewsSystem")
    check(history != null, "HistorySystem autoload present")
    check(news != null, "NewsSystem autoload present")
    if history == null or news == null:
        quit(1)
        return
    check(history.has_signal("gameplay_event_recorded"), "History event bus signal present")
    check(history.has_method("record"), "HistorySystem record() present")
    check(news.has_method("get_current_issue"), "NewsSystem issue API present")
    var received: Array = []
    var callable := func(event: Dictionary): received.append(event)
    history.gameplay_event_recorded.connect(callable)
    var day := 1
    history.record("employee_promotion", day, "James Carter promoted to Factory Manager", {"employee_name": "James Carter", "new_role": "Factory Manager"}, "employee|emp_001|promotion")
    check(not received.is_empty(), "History event was emitted")
    await process_frame
    var issue: Dictionary = news.get_current_issue()
    var found := false
    var first: Dictionary = received[0] if not received.is_empty() else {}
    for story in issue.get("stories", []):
        if str(story.get("source_key", "")) == "history|%s" % str(first.get("id", "")):
            found = true
            check(str(story.get("section", "")) == "People", "Promotion enters PEOPLE section")
            check(str(story.get("body", "")) == "James Carter has been promoted to Factory Manager.", "Promotion copy is correct")
    check(found, "NewsSystem received the HistorySystem event")
    check(bool(issue.get("verified_only", false)), "News issue is verified-only")
    print("PHASE 30 RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
