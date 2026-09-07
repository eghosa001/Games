extends SceneTree

## Phase 29 contract tests for the RENEW Daily news system.
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
    var news = root.get_node_or_null("RenewNewsSystem")
    check(news != null, "NewsSystem autoload is available")
    if news == null:
        quit(1)
        return
    check(news.has_method("generate_daily"), "Daily generation API exists")
    check(news.has_method("get_current_issue"), "Current issue API exists")
    check(news.has_method("capture_state"), "News state snapshot API exists")
    check(news.has_method("restore_state"), "News state restore API exists")
    check(news.SECTIONS.size() == 10, "Daily has ten sections")
    for section in ["Your Company", "People", "Market", "Rivals", "Supply Chain", "Contracts", "Opportunities", "Regions", "World", "Corporate History"]:
        check(news.SECTIONS.has(section), "Daily section present: %s" % section)
    var issue: Dictionary = news.generate_daily(1)
    check(bool(issue.get("verified_only", false)), "Daily contains verified stories only")
    var stories_ok := true
    for story in issue.get("stories", []):
        if str(story.get("source_key", "")).is_empty():
            stories_ok = false
        if str(story.get("headline", "")).is_empty():
            stories_ok = false
        if not news.SECTIONS.has(str(story.get("section", ""))):
            stories_ok = false
    check(stories_ok, "Every story has source, headline and valid section")
    print("PHASE 29 RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
