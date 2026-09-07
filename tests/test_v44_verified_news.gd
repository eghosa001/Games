extends SceneTree

## V4.4: verified news only. Tagged log lines ingest into history and reach
## the newspaper under the right sections, never twice.
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
    check(history != null and news != null, "History and news systems available")
    if history == null or news == null:
        quit(1)
        return
    var lines := [
        "CORPORATE WAR: Apex Materials raids Northstar Logistics in a hostile takeover bid.",
        "EVENT: World event — energy_crisis",
        "EVENT: VICTORY — Monopolist! The market answers to one name now.",
        "RIVAL: Apex Materials cuts prices to chase market share."
    ]
    var added: int = int(history.ingest_activity_log(lines, 60))
    check(added == 3, "Tagged lines ingest; noise ignored")
    check(int(history.ingest_activity_log(lines, 60)) == 0, "Re-ingest adds nothing")
    var wars: Array = history.get_timeline("corporate_war", 10)
    check(wars.size() == 1, "War reaches the timeline")
    var world: Array = history.get_timeline("world_event", 10)
    check(world.size() == 2, "World events reach the timeline")
    var issue: Dictionary = news.generate_daily(60)
    check(bool(issue.get("verified_only", false)), "Issue stays verified-only")
    var sections := {}
    var headlines := {}
    var dupes := 0
    for story in (issue.get("stories", []) as Array):
        if not story is Dictionary:
            continue
        sections[str((story as Dictionary).get("section", ""))] = true
        var head := str((story as Dictionary).get("headline", ""))
        if headlines.has(head):
            dupes += 1
        headlines[head] = true
    check(sections.has("Rivals"), "War reported in Rivals")
    check(sections.has("World"), "Crisis reported in World")
    check(dupes == 0, "No story printed twice")
    var again: Dictionary = news.generate_daily(60)
    var total := (issue.get("stories", []) as Array).size() + (again.get("stories", []) as Array).size()
    check(total > 0, "Issues regenerate")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads with verified news")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        game.free()
        await process_frame
    print("V44 VERIFIED NEWS RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
