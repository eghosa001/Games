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
    var script = load("res://scripts/news_system.gd")
    check(script != null, "NewsSystem script must load")
    if script == null:
        _finish()
        return
    var news = script.new()
    root.add_child(news)
    check(news.SECTIONS.size() == 10, "RENEW Daily must expose all ten sections")
    for section in ["Your Company", "People", "Market", "Rivals", "Supply Chain", "Contracts", "Opportunities", "Regions", "World", "Corporate History"]:
        check(news.SECTIONS.has(section), "News section exists: " + section)
    var snapshot: Dictionary = news.capture_state()
    check(snapshot.has("archive"), "News archive must be persisted")
    check(snapshot.has("current_issue"), "Current newspaper must be persisted")
    news.restore_state(snapshot)
    check(news.get_archive(10) is Array, "News archive API must return an array")
    news.free()
    await process_frame
    print("NEWS SYSTEM RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)

func _finish() -> void:
    print("NEWS SYSTEM RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
