extends SceneTree

## V8.7: five-dimension reputation. Hiring, firing, marketing, contracts,
## investment, dividends and green restoration move their own dimension and
## nudge the headline at half rate.
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
    var Reputation = load("res://scripts/reputation_system.gd")
    check(Reputation != null, "Reputation system loads")
    if Reputation == null:
        quit(1)
        return
    var state = root.get_node_or_null("RenewGameState")
    check(state != null, "GameState is available")
    if state == null:
        quit(1)
        return
    if state.has_method("clear"):
        state.clear()
    state.set_value("player", "reputation", 40)
    var rep: Node = Reputation.new()
    root.add_child(rep)
    await process_frame

    var dims: Dictionary = rep.dimensions()
    check(dims.size() == 5, "Five dimensions tracked")
    check(int(dims.get("public", -1)) == 40, "Dimensions seed from the headline")
    check(not bool(rep.adjust("unknown", 5).get("ok", false)), "Unknown dimensions rejected")
    var up: Dictionary = rep.adjust("public", 10)
    check(int(up.get("value", 0)) == 50, "Public dimension moves")
    check(int(state.get_value("player", "reputation", 0)) == 45, "Headline nudged at half rate")
    rep.adjust("employee", -200)
    check(int(rep.dimensions().get("employee", -1)) == 0, "Dimensions floor at zero")
    check(int(state.get_value("player", "reputation", 0)) >= 0, "Headline never negative")
    rep.adjust("investor", 500)
    check(int(rep.dimensions().get("investor", -1)) == 100, "Dimensions cap at one hundred")
    check(str(rep.status_text()).find("REPUTE") >= 0, "Status renders")

    var scene = load("res://scenes/Main.tscn")
    check(scene != null, "Main scene loads for reputation wiring")
    if scene != null:
        var game = scene.instantiate()
        root.add_child(game)
        current_scene = game
        await process_frame
        await process_frame
        check(game.has_method("reputation_status"), "Main exposes reputation_status")
        game.cash = 250000
        game.day = 1
        game.inspect_property()
        game.acquire_property()
        var guard := 0
        while str(state.get_value("properties", "stage", "")) != "Operational" and guard < 20:
            game.restore_property()
            guard += 1
            await process_frame
        var auto = root.get_node_or_null("RenewReputationSystem")
        check(float(auto.dimensions().get("environmental", 0.0)) > 40.0, "Green restoration lifts the Green dimension")
        var emp_before := float(auto.dimensions().get("employee", 0.0))
        game.choose_business_purpose(0)
        game.open_business()
        game.hire_employee()
        check(float(auto.dimensions().get("employee", 0.0)) > emp_before, "Hiring lifts the Workplace dimension")
        game.command_system.reputation_status()
        check(str(game.command_system._state_value("company", "message", "")).find("REPUTE") >= 0, "Repute command reports")
        game.free()
        await process_frame
    rep.queue_free()
    await process_frame
    print("V87 REPUTATION RESULT: %d passed, %d failed" % [passed, failed])
    quit(1 if failed > 0 else 0)
