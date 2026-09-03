extends Node

## Phase 29 contract tests. Run inside Godot's test harness.
func _ready() -> void:
    var news = get_node_or_null("/root/RenewNewsSystem")
    assert(news != null)
    assert(news.has_method("generate_daily"))
    assert(news.has_method("get_current_issue"))
    assert(news.has_method("capture_state"))
    assert(news.has_method("restore_state"))
    assert(news.SECTIONS.size() == 10)
    assert(news.SECTIONS.has("Your Company"))
    assert(news.SECTIONS.has("People"))
    assert(news.SECTIONS.has("Market"))
    assert(news.SECTIONS.has("Rivals"))
    assert(news.SECTIONS.has("Supply Chain"))
    assert(news.SECTIONS.has("Contracts"))
    assert(news.SECTIONS.has("Opportunities"))
    assert(news.SECTIONS.has("Regions"))
    assert(news.SECTIONS.has("World"))
    assert(news.SECTIONS.has("Corporate History"))

    var issue: Dictionary = news.generate_daily(1)
    assert(bool(issue.get("verified_only", false)))
    for story in issue.get("stories", []):
        assert(not str(story.get("source_key", "")).is_empty())
        assert(not str(story.get("headline", "")).is_empty())
        assert(news.SECTIONS.has(str(story.get("section", ""))))

    print("PHASE 29 RENEW DAILY TESTS PASSED")
