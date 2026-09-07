extends SceneTree

## V8.4: notification center. Verified stories newer than the seen day
## count as unread; opening the inbox marks them read.
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
    check(news != null, "News system available")
    if news == null:
        quit(1)
        return
    var state = root.get_node_or_null("RenewGameState")
    check(state != null, "GameState is available")
    if state == null:
        quit(1)
        return
    if state.has_method("clear"):
        state.clear()
    var history = root.get_node_or_null("RenewHistorySystem")
    if history != null and history.has_method("restore_state"):
        history.restore_state({})
    state.set_value("player", "day", 10)
    var first: Dictionary = news.read_notifications()
    check(bool(first.get("ok", false)) and int(first.get("unread", -1)) == 0, "First opening sets the watermark")
    history.ingest_activity_log(["CORPORATE WAR: Apex Materials raids Northstar Logistics.", "EVENT: World event — energy_crisis"], 10)
    var issue: Dictionary = news.generate_daily(10)
    check((issue.get("stories", []) as Array).size() >= 2, "Issue carries the developments")
    var second: Dictionary = news.read_notifications()
    print("DEBUG second=" + str(second))
    check(int(second.get("unread", 0)) >= 2, "Fresh stories count as unread")
    check((second.get("sections", {}) as Dictionary).has("Rivals"), "Unread grouped by section")
    var third: Dictionary = news.read_notifications()
    check(int(third.get("unread", -1)) == 0, "Reading marks everything seen")
    state.set_value("player", "day", 11)
    history.ingest_activity_log(["EVENT: World event — supply_disruption"], 11)
    news.generate_daily(11)
    var fourth: Dictionary = news.read_notifications()
    check(int(fourth.get("unread", 0)) >= 1, "Next-day stories reopen the inbox")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for notices wiring")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        await process_frame
        await process_frame
        check(game.has_method("check_notifications"), "Main exposes check_notifications")
        game.command_system.check_notifications()
        check(str(game.command_system._state_value("company", "message", "")).find("NOTICES") >= 0, "Notices command reports")
        game.free()
        await process_frame
    print("V84 NOTIFICATIONS RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
